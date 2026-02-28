#!/usr/bin/env node

/**
 * Java Static Analysis Results Formatter (with Overlap Detection)
 *
 * Unifies outputs from multiple Java static analysis tools into standardized JSON
 * with overlap detection for high-confidence finding identification.
 *
 * Supported Java tools:
 * - Semgrep (OWASP/CWE/JWT/Spring)
 * - SpotBugs + Find Security Bugs
 * - PMD
 * - Checkstyle
 * - Snyk Code (SAST)
 * - Snyk Open Source (dependencies/CVE)
 * - OWASP Dependency-Check
 * - Trivy (containers/IaC)
 */

const fs = require('fs');
const path = require('path');
const { XMLParser } = require('fast-xml-parser');

// Standardized finding schema
const createFinding = (source, rule, severity, file, line, message, category, detectionMethod = 'pattern') => ({
  source,
  rule,
  severity: normalizeSeverity(severity),
  location: `${file}:${line}`,
  file,
  line,
  message,
  category,
  detection_method: detectionMethod,
  timestamp: new Date().toISOString()
});

// Normalize severity across different tools
const normalizeSeverity = (severity) => {
  const s = String(severity).toLowerCase();
  if (['critical', 'blocker', 'error', '1', 'high'].includes(s)) return 'critical';
  if (['major', 'warning', '2', 'medium'].includes(s)) return 'high';
  if (['minor', 'info', '3', 'low'].includes(s)) return 'medium';
  return 'low';
};

// ==================== JAVA TOOL PARSERS ====================

// Parse Semgrep JSON (OWASP/CWE/JWT/Spring)
const parseSemgrep = (semgrepJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(semgrepJsonPath, 'utf8'));
    const findings = [];

    if (data.results) {
      data.results.forEach(result => {
        findings.push(createFinding(
          'semgrep',
          result.check_id || result.rule_id || 'semgrep-rule',
          result.extra?.severity || 'medium',
          result.path,
          result.start?.line || 1,
          result.extra?.message || result.message || 'Semgrep finding',
          categorizeSemgrepRule(result.check_id || result.rule_id),
          'pattern'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing Semgrep results:', error.message);
    return [];
  }
};

// Parse SpotBugs XML (with Find Security Bugs)
const parseSpotBugs = (spotbugsXmlPath) => {
  try {
    const xmlParser = new XMLParser({ ignoreAttributes: false });
    const xmlData = fs.readFileSync(spotbugsXmlPath, 'utf8');
    const data = xmlParser.parse(xmlData);
    const findings = [];

    if (data.BugCollection && data.BugCollection.BugInstance) {
      const bugs = Array.isArray(data.BugCollection.BugInstance)
        ? data.BugCollection.BugInstance
        : [data.BugCollection.BugInstance];

      bugs.forEach(bug => {
        const sourceLines = bug.SourceLine || [];
        const firstLine = Array.isArray(sourceLines) ? sourceLines[0] : sourceLines;

        findings.push(createFinding(
          'spotbugs',
          bug['@_type'] || 'unknown',
          bug['@_priority'] || '2', // 1=high, 2=medium, 3=low
          firstLine?.['@_sourcepath'] || 'unknown.java',
          firstLine?.['@_start'] || 1,
          bug.LongMessage || bug.ShortMessage || 'SpotBugs finding',
          categorizeSpotBugsType(bug['@_type']),
          'pattern'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing SpotBugs results:', error.message);
    return [];
  }
};

// Parse PMD XML
const parsePMD = (pmdXmlPath) => {
  try {
    const xmlParser = new XMLParser({ ignoreAttributes: false });
    const xmlData = fs.readFileSync(pmdXmlPath, 'utf8');
    const data = xmlParser.parse(xmlData);
    const findings = [];

    if (data.pmd && data.pmd.file) {
      const files = Array.isArray(data.pmd.file) ? data.pmd.file : [data.pmd.file];

      files.forEach(file => {
        if (file.violation) {
          const violations = Array.isArray(file.violation) ? file.violation : [file.violation];

          violations.forEach(violation => {
            findings.push(createFinding(
              'pmd',
              violation['@_rule'] || 'pmd-rule',
              violation['@_priority'] || '3',
              file['@_name'],
              violation['@_beginline'] || 1,
              violation['#text'] || 'PMD violation',
              violation['@_ruleset'] || 'code-quality',
              'heuristic'
            ));
          });
        }
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing PMD results:', error.message);
    return [];
  }
};

// Parse Checkstyle XML
const parseCheckstyle = (checkstyleXmlPath) => {
  try {
    const xmlParser = new XMLParser({ ignoreAttributes: false });
    const xmlData = fs.readFileSync(checkstyleXmlPath, 'utf8');
    const data = xmlParser.parse(xmlData);
    const findings = [];

    if (data.checkstyle && data.checkstyle.file) {
      const files = Array.isArray(data.checkstyle.file) ? data.checkstyle.file : [data.checkstyle.file];

      files.forEach(file => {
        if (file.error) {
          const errors = Array.isArray(file.error) ? file.error : [file.error];

          errors.forEach(error => {
            findings.push(createFinding(
              'checkstyle',
              error['@_source'] || 'checkstyle-rule',
              error['@_severity'] || 'info',
              file['@_name'],
              error['@_line'] || 1,
              error['@_message'] || 'Checkstyle violation',
              'code-style',
              'pattern'
            ));
          });
        }
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing Checkstyle results:', error.message);
    return [];
  }
};

// Parse Snyk Code JSON
const parseSnykCode = (snykCodeJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(snykCodeJsonPath, 'utf8'));
    const findings = [];

    if (data.runs && data.runs[0] && data.runs[0].results) {
      data.runs[0].results.forEach(result => {
        const location = result.locations?.[0]?.physicalLocation;
        findings.push(createFinding(
          'snyk-code',
          result.ruleId || 'snyk-code-rule',
          result.level || 'warning',
          location?.artifactLocation?.uri || 'unknown.java',
          location?.region?.startLine || 1,
          result.message?.text || 'Snyk Code finding',
          categorizeSnykCodeRule(result.ruleId),
          'dataflow'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing Snyk Code results:', error.message);
    return [];
  }
};

// Parse Snyk Open Source JSON (dependencies/CVE)
const parseSnykOpenSource = (snykOSJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(snykOSJsonPath, 'utf8'));
    const findings = [];

    if (data.vulnerabilities) {
      data.vulnerabilities.forEach(vuln => {
        findings.push(createFinding(
          'snyk-open-source',
          vuln.id || 'CVE-unknown',
          vuln.severity || 'medium',
          vuln.from?.[0] || 'pom.xml',
          1,
          `${vuln.title || 'Dependency vulnerability'} in ${vuln.packageName}@${vuln.version}`,
          'dependency-vulnerability',
          'version-check'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing Snyk Open Source results:', error.message);
    return [];
  }
};

// Parse OWASP Dependency-Check JSON
const parseDependencyCheck = (depCheckJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(depCheckJsonPath, 'utf8'));
    const findings = [];

    if (data.dependencies) {
      data.dependencies.forEach(dep => {
        if (dep.vulnerabilities) {
          dep.vulnerabilities.forEach(vuln => {
            findings.push(createFinding(
              'owasp-dependency-check',
              vuln.name || 'CVE-unknown',
              vuln.severity || 'medium',
              dep.fileName || 'pom.xml',
              1,
              `${vuln.description || 'Vulnerability'} (CVSS: ${vuln.cvssv3?.baseScore || 'N/A'})`,
              'dependency-vulnerability',
              'version-check'
            ));
          });
        }
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing OWASP Dependency-Check results:', error.message);
    return [];
  }
};

// Parse Trivy JSON
const parseTrivy = (trivyJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(trivyJsonPath, 'utf8'));
    const findings = [];

    if (data.Results) {
      data.Results.forEach(result => {
        if (result.Vulnerabilities) {
          result.Vulnerabilities.forEach(vuln => {
            findings.push(createFinding(
              'trivy',
              vuln.VulnerabilityID || 'CVE-unknown',
              vuln.Severity || 'medium',
              result.Target || 'Dockerfile',
              1,
              `${vuln.Title || 'Vulnerability'} in ${vuln.PkgName}@${vuln.InstalledVersion}`,
              'container-vulnerability',
              'version-check'
            ));
          });
        }

        if (result.Misconfigurations) {
          result.Misconfigurations.forEach(misconfig => {
            findings.push(createFinding(
              'trivy',
              misconfig.ID || 'misconfig',
              misconfig.Severity || 'medium',
              result.Target || 'config-file',
              1,
              misconfig.Title || misconfig.Message || 'Misconfiguration detected',
              'iac-misconfiguration',
              'pattern'
            ));
          });
        }
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing Trivy results:', error.message);
    return [];
  }
};

// ==================== CATEGORIZATION FUNCTIONS ====================

const categorizeSemgrepRule = (ruleId) => {
  const id = String(ruleId).toLowerCase();
  if (id.includes('sql-injection')) return 'sql-injection';
  if (id.includes('xxe')) return 'xxe';
  if (id.includes('jwt') || id.includes('auth')) return 'authentication';
  if (id.includes('spring-security')) return 'spring-security';
  if (id.includes('deserialization')) return 'deserialization';
  if (id.includes('path-traversal')) return 'path-traversal';
  if (id.includes('command-injection')) return 'command-injection';
  if (id.includes('ldap-injection')) return 'ldap-injection';
  if (id.includes('ssrf')) return 'ssrf';
  return 'security';
};

const categorizeSpotBugsType = (bugType) => {
  const type = String(bugType).toUpperCase();
  if (type.includes('SQL')) return 'sql-injection';
  if (type.includes('XXE')) return 'xxe';
  if (type.includes('XSS')) return 'xss';
  if (type.includes('PATH_TRAVERSAL')) return 'path-traversal';
  if (type.includes('COMMAND_INJECTION')) return 'command-injection';
  if (type.includes('WEAK_RANDOM')) return 'weak-cryptography';
  if (type.includes('HARD_CODE')) return 'hardcoded-secrets';
  return 'code-quality';
};

const categorizeSnykCodeRule = (ruleId) => {
  const id = String(ruleId).toLowerCase();
  if (id.includes('sql')) return 'sql-injection';
  if (id.includes('xxe')) return 'xxe';
  if (id.includes('auth')) return 'authentication';
  if (id.includes('crypto')) return 'cryptography';
  return 'security';
};

// ==================== OVERLAP DETECTION ====================

const detectOverlap = (allFindings) => {
  const locationMap = {};

  // Group findings by location
  allFindings.forEach(finding => {
    const key = finding.location;
    if (!locationMap[key]) {
      locationMap[key] = [];
    }
    locationMap[key].push(finding);
  });

  // Identify overlaps
  const overlaps = [];
  Object.entries(locationMap).forEach(([location, findings]) => {
    if (findings.length > 1) {
      const tools = [...new Set(findings.map(f => f.source))];
      const detectionMethods = [...new Set(findings.map(f => f.detection_method))];

      // Calculate convergence score
      const baseScore = Math.min(findings.length * 0.3, 0.9);
      let bonus = 0;

      // Bonus for detection method diversity
      const hasPattern = detectionMethods.includes('pattern');
      const hasDataflow = detectionMethods.includes('dataflow');
      if (hasPattern && hasDataflow) bonus += 0.1;

      const convergenceScore = Math.min(baseScore + bonus, 1.0);

      overlaps.push({
        location,
        tool_count: tools.length,
        tools,
        detection_methods: detectionMethods,
        severity: findings[0].severity, // Take first severity
        category: findings[0].category,
        convergence_score: convergenceScore,
        confidence: convergenceScore >= 0.8 ? 'high' : convergenceScore >= 0.5 ? 'medium' : 'low',
        findings: findings.map(f => ({
          source: f.source,
          rule: f.rule,
          message: f.message
        }))
      });
    }
  });

  return overlaps.sort((a, b) => b.convergence_score - a.convergence_score);
};

// ==================== MAIN EXECUTION ====================

const main = () => {
  const analysisDir = process.argv[2] || '.analysis/stage3-static-analysis';
  const rawOutputsDir = path.join(analysisDir, 'raw-outputs');

  console.log('Java Static Analysis Results Formatter');
  console.log('========================================\n');

  let allFindings = [];
  let toolsRun = 0;

  // Parse each tool's output
  const tools = [
    { name: 'Semgrep', path: path.join(rawOutputsDir, 'semgrep-report.json'), parser: parseSemgrep },
    { name: 'SpotBugs', path: path.join(rawOutputsDir, 'spotbugs-report.xml'), parser: parseSpotBugs },
    { name: 'PMD', path: path.join(rawOutputsDir, 'pmd-report.xml'), parser: parsePMD },
    { name: 'Checkstyle', path: path.join(rawOutputsDir, 'checkstyle-report.xml'), parser: parseCheckstyle },
    { name: 'Snyk Code', path: path.join(rawOutputsDir, 'snyk-code.json'), parser: parseSnykCode },
    { name: 'Snyk Open Source', path: path.join(rawOutputsDir, 'snyk-open-source.json'), parser: parseSnykOpenSource },
    { name: 'OWASP Dependency-Check', path: path.join(rawOutputsDir, 'dependency-check-report.json'), parser: parseDependencyCheck },
    { name: 'Trivy', path: path.join(rawOutputsDir, 'trivy-report.json'), parser: parseTrivy }
  ];

  tools.forEach(tool => {
    if (fs.existsSync(tool.path)) {
      console.log(`Parsing ${tool.name}...`);
      const findings = tool.parser(tool.path);
      allFindings = allFindings.concat(findings);
      toolsRun++;
      console.log(`  Found ${findings.length} findings\n`);
    }
  });

  // Detect overlaps
  console.log('Detecting overlaps across tools...');
  const overlaps = detectOverlap(allFindings);
  console.log(`  Found ${overlaps.length} overlapping findings\n`);

  // Calculate statistics
  const highConfidence = overlaps.filter(o => o.confidence === 'high').length;
  const mediumConfidence = overlaps.filter(o => o.confidence === 'medium').length;

  // Write unified results
  const unifiedResults = {
    metadata: {
      timestamp: new Date().toISOString(),
      tools_run: toolsRun,
      total_findings: allFindings.length,
      overlap_count: overlaps.length,
      high_confidence_overlaps: highConfidence,
      medium_confidence_overlaps: mediumConfidence
    },
    findings: allFindings,
    overlap_analysis: {
      total_overlaps: overlaps.length,
      high_confidence: highConfidence,
      medium_confidence: mediumConfidence,
      overlaps: overlaps
    }
  };

  fs.writeFileSync(
    path.join(analysisDir, 'unified-results.json'),
    JSON.stringify(unifiedResults, null, 2)
  );

  // Write tool comparison markdown
  const comparisonMd = generateToolComparison(tools, allFindings, overlaps);
  fs.writeFileSync(
    path.join(analysisDir, 'tool-comparison.md'),
    comparisonMd
  );

  console.log('========================================');
  console.log('Results Summary');
  console.log('========================================');
  console.log(`Tools run: ${toolsRun}`);
  console.log(`Total findings: ${allFindings.length}`);
  console.log(`Overlapping findings: ${overlaps.length}`);
  console.log(`  High confidence: ${highConfidence}`);
  console.log(`  Medium confidence: ${mediumConfidence}`);
  console.log(`\nOutput files:`);
  console.log(`  ${path.join(analysisDir, 'unified-results.json')}`);
  console.log(`  ${path.join(analysisDir, 'tool-comparison.md')}`);
};

const generateToolComparison = (tools, allFindings, overlaps) => {
  let md = '# Java Static Analysis Tool Comparison\n\n';
  md += `**Generated**: ${new Date().toISOString()}\n\n`;

  md += '## Tools Run\n\n';
  tools.forEach(tool => {
    const findings = allFindings.filter(f => f.source.toLowerCase().includes(tool.name.toLowerCase().replace(' ', '-')));
    md += `- **${tool.name}**: ${findings.length} findings\n`;
  });

  md += '\n## Overlap Analysis\n\n';
  md += `Total overlapping findings: ${overlaps.length}\n\n`;
  md += '### High Confidence Findings (Multiple Tools)\n\n';

  overlaps.filter(o => o.confidence === 'high').slice(0, 10).forEach(overlap => {
    md += `**${overlap.location}** (Tools: ${overlap.tools.join(', ')})\n`;
    md += `- Severity: ${overlap.severity}\n`;
    md += `- Category: ${overlap.category}\n`;
    md += `- Convergence Score: ${overlap.convergence_score.toFixed(2)}\n\n`;
  });

  return md;
};

// Run
main();
