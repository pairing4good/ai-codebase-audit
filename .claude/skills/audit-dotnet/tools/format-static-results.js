#!/usr/bin/env node

/**
 * .NET Static Analysis Results Formatter (with Overlap Detection)
 *
 * Unifies outputs from multiple .NET static analysis tools into standardized JSON
 * with overlap detection for high-confidence finding identification.
 *
 * Supported .NET tools:
 * - Semgrep (OWASP/CWE for C#)
 * - Roslyn Analyzers (built-in .NET code analysis)
 * - Security Code Scan (OWASP Top 10 for ASP.NET Core)
 * - Snyk Code (SAST)
 * - Snyk Open Source (NuGet dependencies/CVE)
 * - dotnet-outdated (dependency version checking)
 * - Trivy (containers/IaC)
 * - SonarQube (if configured)
 */

const fs = require('fs');
const path = require('path');

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
  if (['critical', 'blocker', 'error', 'high'].includes(s)) return 'critical';
  if (['major', 'warning', 'medium'].includes(s)) return 'high';
  if (['minor', 'info', 'low'].includes(s)) return 'medium';
  return 'low';
};

// ==================== .NET TOOL PARSERS ====================

// Parse Semgrep JSON (OWASP/CWE for C#)
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

// Parse Roslyn Analyzers output (SARIF or custom JSON)
const parseRoslyn = (roslynJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(roslynJsonPath, 'utf8'));
    const findings = [];

    // Roslyn outputs can be SARIF format or custom
    if (data.runs && data.runs[0] && data.runs[0].results) {
      // SARIF format
      data.runs[0].results.forEach(result => {
        const location = result.locations?.[0]?.physicalLocation;
        findings.push(createFinding(
          'roslyn',
          result.ruleId || 'roslyn-rule',
          result.level || 'warning',
          location?.artifactLocation?.uri || 'unknown.cs',
          location?.region?.startLine || 1,
          result.message?.text || 'Roslyn analyzer finding',
          categorizeRoslynRule(result.ruleId),
          'pattern'
        ));
      });
    } else if (data.analyzers || data.findings) {
      // Custom format (fallback)
      const items = data.findings || data.analyzers || [];
      items.forEach(item => {
        findings.push(createFinding(
          'roslyn',
          item.code || item.id || 'roslyn-rule',
          item.severity || 'warning',
          item.file || item.path || 'unknown.cs',
          item.line || 1,
          item.message || 'Roslyn analyzer finding',
          categorizeRoslynRule(item.code || item.id),
          'pattern'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing Roslyn results:', error.message);
    return [];
  }
};

// Parse Security Code Scan output
const parseSecurityCodeScan = (scsJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(scsJsonPath, 'utf8'));
    const findings = [];

    if (data.findings) {
      data.findings.forEach(finding => {
        findings.push(createFinding(
          'security-code-scan',
          finding.rule || finding.id || 'SCS-rule',
          finding.severity || 'high',
          finding.file || finding.path || 'unknown.cs',
          finding.line || 1,
          finding.message || 'Security Code Scan finding',
          categorizeSecurityCodeScanRule(finding.rule || finding.id),
          'pattern'
        ));
      });
    } else if (data.runs && data.runs[0]?.results) {
      // SARIF format
      data.runs[0].results.forEach(result => {
        const location = result.locations?.[0]?.physicalLocation;
        findings.push(createFinding(
          'security-code-scan',
          result.ruleId || 'SCS-rule',
          result.level || 'warning',
          location?.artifactLocation?.uri || 'unknown.cs',
          location?.region?.startLine || 1,
          result.message?.text || 'Security Code Scan finding',
          categorizeSecurityCodeScanRule(result.ruleId),
          'pattern'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing Security Code Scan results:', error.message);
    return [];
  }
};

// Parse Snyk Code JSON (SAST)
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
          location?.artifactLocation?.uri || 'unknown.cs',
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

// Parse Snyk Open Source JSON (NuGet dependencies/CVE)
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
          vuln.from?.[0] || 'packages.config',
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

// Parse dotnet-outdated JSON
const parseDotnetOutdated = (dotnetOutdatedJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(dotnetOutdatedJsonPath, 'utf8'));
    const findings = [];

    if (data.projects) {
      data.projects.forEach(project => {
        if (project.frameworks) {
          project.frameworks.forEach(framework => {
            if (framework.dependencies) {
              framework.dependencies.forEach(dep => {
                if (dep.resolvedVersion !== dep.latestVersion) {
                  const severity = calculateOutdatedSeverity(dep.resolvedVersion, dep.latestVersion);
                  findings.push(createFinding(
                    'dotnet-outdated',
                    'outdated-dependency',
                    severity,
                    project.filePath || '*.csproj',
                    1,
                    `${dep.name} is outdated: ${dep.resolvedVersion} → ${dep.latestVersion}`,
                    'outdated-dependency',
                    'version-check'
                  ));
                }
              });
            }
          });
        }
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing dotnet-outdated results:', error.message);
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

// Parse SonarQube JSON (if configured)
const parseSonarQube = (sonarJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(sonarJsonPath, 'utf8'));
    const findings = [];

    if (data.issues) {
      data.issues.forEach(issue => {
        findings.push(createFinding(
          'sonarqube',
          issue.rule || 'sonar-rule',
          issue.severity || 'medium',
          issue.component || 'unknown.cs',
          issue.line || 1,
          issue.message || 'SonarQube finding',
          categorizeSonarRule(issue.rule),
          'heuristic'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing SonarQube results:', error.message);
    return [];
  }
};

// ==================== CATEGORIZATION FUNCTIONS ====================

const categorizeSemgrepRule = (ruleId) => {
  const id = String(ruleId).toLowerCase();
  if (id.includes('sql-injection')) return 'sql-injection';
  if (id.includes('xss')) return 'xss';
  if (id.includes('csrf')) return 'csrf';
  if (id.includes('auth')) return 'authentication';
  if (id.includes('xxe')) return 'xxe';
  if (id.includes('deserialization')) return 'deserialization';
  if (id.includes('path-traversal')) return 'path-traversal';
  if (id.includes('command-injection')) return 'command-injection';
  if (id.includes('ldap-injection')) return 'ldap-injection';
  if (id.includes('ssrf')) return 'ssrf';
  return 'security';
};

const categorizeRoslynRule = (ruleId) => {
  const id = String(ruleId).toUpperCase();
  if (id.startsWith('CA') && id.includes('SECURITY')) return 'security';
  if (id.startsWith('CA1') || id.startsWith('CA2')) return 'code-quality';
  if (id.startsWith('CA3')) return 'security';
  if (id.includes('ASYNC') || id.includes('AWAIT')) return 'async-patterns';
  if (id.includes('DISPOSE')) return 'resource-management';
  return 'code-quality';
};

const categorizeSecurityCodeScanRule = (ruleId) => {
  const id = String(ruleId).toUpperCase();
  if (id.includes('SCS0001')) return 'command-injection';
  if (id.includes('SCS0002')) return 'sql-injection';
  if (id.includes('SCS0003')) return 'path-traversal';
  if (id.includes('SCS0004')) return 'csrf';
  if (id.includes('SCS0005')) return 'weak-cryptography';
  if (id.includes('SCS0006')) return 'weak-random';
  if (id.includes('SCS0007')) return 'xxe';
  if (id.includes('SCS0008')) return 'cookie-security';
  if (id.includes('SCS0009')) return 'ldap-injection';
  if (id.includes('SCS0010')) return 'redirect-injection';
  if (id.includes('SQL')) return 'sql-injection';
  if (id.includes('XSS')) return 'xss';
  return 'security';
};

const categorizeSnykCodeRule = (ruleId) => {
  const id = String(ruleId).toLowerCase();
  if (id.includes('sql')) return 'sql-injection';
  if (id.includes('xss')) return 'xss';
  if (id.includes('auth')) return 'authentication';
  if (id.includes('crypto')) return 'cryptography';
  if (id.includes('csrf')) return 'csrf';
  return 'security';
};

const categorizeSonarRule = (ruleId) => {
  const id = String(ruleId).toLowerCase();
  if (id.includes('security')) return 'security';
  if (id.includes('bug')) return 'bug';
  if (id.includes('vulnerability')) return 'security';
  if (id.includes('sql')) return 'sql-injection';
  return 'code-quality';
};

const calculateOutdatedSeverity = (current, latest) => {
  try {
    const currentParts = current.split('.').map(Number);
    const latestParts = latest.split('.').map(Number);

    // Major version difference = critical
    if (latestParts[0] > currentParts[0]) return 'critical';
    // Minor version difference = high
    if (latestParts[1] > currentParts[1]) return 'high';
    // Patch version difference = medium
    return 'medium';
  } catch {
    return 'medium';
  }
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

  console.log('.NET Static Analysis Results Formatter');
  console.log('========================================\n');

  let allFindings = [];
  let toolsRun = 0;

  // Parse each tool's output
  const tools = [
    { name: 'Semgrep', path: path.join(rawOutputsDir, 'semgrep-report.json'), parser: parseSemgrep },
    { name: 'Roslyn', path: path.join(rawOutputsDir, 'roslyn-report.json'), parser: parseRoslyn },
    { name: 'Security Code Scan', path: path.join(rawOutputsDir, 'security-code-scan-report.json'), parser: parseSecurityCodeScan },
    { name: 'Snyk Code', path: path.join(rawOutputsDir, 'snyk-code.json'), parser: parseSnykCode },
    { name: 'Snyk Open Source', path: path.join(rawOutputsDir, 'snyk-open-source.json'), parser: parseSnykOpenSource },
    { name: 'dotnet-outdated', path: path.join(rawOutputsDir, 'dotnet-outdated-report.json'), parser: parseDotnetOutdated },
    { name: 'Trivy', path: path.join(rawOutputsDir, 'trivy-report.json'), parser: parseTrivy },
    { name: 'SonarQube', path: path.join(rawOutputsDir, 'sonarqube-report.json'), parser: parseSonarQube }
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

  // Write overlap analysis JSON
  fs.writeFileSync(
    path.join(analysisDir, 'overlap-analysis.json'),
    JSON.stringify({ overlaps }, null, 2)
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
  console.log(`  ${path.join(analysisDir, 'overlap-analysis.json')}`);
};

const generateToolComparison = (tools, allFindings, overlaps) => {
  let md = '# .NET Static Analysis Tool Comparison\n\n';
  md += `**Generated**: ${new Date().toISOString()}\n\n`;

  md += '## Tools Run\n\n';
  tools.forEach(tool => {
    const findings = allFindings.filter(f => f.source.toLowerCase().includes(tool.name.toLowerCase().replace(/\s+/g, '-')));
    md += `- **${tool.name}**: ${findings.length} findings\n`;
  });

  md += '\n## Category Breakdown\n\n';
  const categories = {};
  allFindings.forEach(f => {
    categories[f.category] = (categories[f.category] || 0) + 1;
  });
  Object.entries(categories)
    .sort((a, b) => b[1] - a[1])
    .forEach(([cat, count]) => {
      md += `- **${cat}**: ${count} findings\n`;
    });

  md += '\n## Overlap Analysis\n\n';
  md += `Total overlapping findings: ${overlaps.length}\n\n`;
  md += '### High Confidence Findings (Multiple Tools)\n\n';

  const highConfOverlaps = overlaps.filter(o => o.confidence === 'high').slice(0, 10);
  if (highConfOverlaps.length > 0) {
    highConfOverlaps.forEach(overlap => {
      md += `**${overlap.location}** (Tools: ${overlap.tools.join(', ')})\n`;
      md += `- Severity: ${overlap.severity}\n`;
      md += `- Category: ${overlap.category}\n`;
      md += `- Convergence Score: ${overlap.convergence_score.toFixed(2)}\n`;
      md += `- Detection Methods: ${overlap.detection_methods.join(', ')}\n\n`;
    });
  } else {
    md += '*No high-confidence overlaps detected. This may indicate limited tool coverage or few severe issues.*\n\n';
  }

  md += '### Medium Confidence Findings\n\n';
  const medConfOverlaps = overlaps.filter(o => o.confidence === 'medium').slice(0, 5);
  if (medConfOverlaps.length > 0) {
    medConfOverlaps.forEach(overlap => {
      md += `- ${overlap.location} (${overlap.tools.join(', ')})\n`;
    });
  } else {
    md += '*No medium-confidence overlaps detected.*\n';
  }

  md += '\n## Interpretation Guide\n\n';
  md += '- **High Confidence (≥0.8)**: Finding detected by multiple independent tools with different detection methods\n';
  md += '- **Medium Confidence (0.5-0.79)**: Finding detected by 2+ tools OR 2+ different detection methods\n';
  md += '- **Low Confidence (<0.5)**: Finding detected by single tool only\n\n';
  md += '*Prioritize high-confidence findings for immediate remediation.*\n';

  return md;
};

// Run
main();
