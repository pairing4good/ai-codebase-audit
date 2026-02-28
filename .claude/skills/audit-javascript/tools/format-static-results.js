#!/usr/bin/env node

/**
 * Static Analysis Results Formatter (Enhanced with Overlap Detection)
 *
 * Unifies outputs from multiple static analysis tools into a standardized JSON format
 * with overlap detection for high-confidence finding identification.
 *
 * Supported tools:
 * - ESLint + security plugins
 * - Semgrep (OWASP/CWE/JWT/API)
 * - Snyk Code (SAST)
 * - Snyk Open Source (dependencies)
 * - SonarQube
 * - npm audit
 * - Trivy (IaC/containers)
 * - Coverage (istanbul/nyc)
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
  detection_method: detectionMethod, // 'pattern', 'dataflow', 'heuristic', 'version-check'
  timestamp: new Date().toISOString()
});

// Normalize severity across different tools
const normalizeSeverity = (severity) => {
  const s = String(severity).toLowerCase();
  if (['critical', 'blocker', 'error', '2'].includes(s)) return 'critical';
  if (['high', 'major', 'warning', '1'].includes(s)) return 'high';
  if (['medium', 'minor', 'info', '0', 'note'].includes(s)) return 'medium';
  return 'low';
};

// ==================== PARSER FUNCTIONS ====================

// Parse ESLint JSON output
const parseEslint = (eslintJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(eslintJsonPath, 'utf8'));
    const findings = [];

    data.forEach(fileResult => {
      fileResult.messages.forEach(msg => {
        findings.push(createFinding(
          'eslint',
          msg.ruleId || 'eslint-error',
          msg.severity === 2 ? 'error' : msg.severity === 1 ? 'warning' : 'info',
          fileResult.filePath,
          msg.line,
          msg.message,
          msg.ruleId ? categorizeEslintRule(msg.ruleId) : 'syntax',
          'pattern'
        ));
      });
    });

    return findings;
  } catch (error) {
    console.error('Error parsing ESLint results:', error.message);
    return [];
  }
};

// Parse Semgrep JSON output
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

// Parse Snyk Code (SAST) SARIF output
const parseSnykCode = (snykCodeJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(snykCodeJsonPath, 'utf8'));
    const findings = [];

    if (data.runs && data.runs[0]?.results) {
      data.runs[0].results.forEach(result => {
        const location = result.locations?.[0]?.physicalLocation;
        const filePath = location?.artifactLocation?.uri || 'unknown';
        const line = location?.region?.startLine || 1;

        findings.push(createFinding(
          'snyk-code',
          result.ruleId || 'snyk-code-rule',
          result.level || 'warning',
          filePath,
          line,
          result.message?.text || 'Snyk Code finding',
          categorizeSnykRule(result.ruleId),
          'dataflow' // Snyk Code uses dataflow analysis
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing Snyk Code results:', error.message);
    return [];
  }
};

// Parse Snyk Open Source (dependencies) JSON output
const parseSnykOpenSource = (snykOSJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(snykOSJsonPath, 'utf8'));
    const findings = [];

    if (data.vulnerabilities) {
      data.vulnerabilities.forEach(vuln => {
        findings.push(createFinding(
          'snyk-open-source',
          vuln.id || vuln.cve || 'snyk-vuln',
          vuln.severity || 'medium',
          vuln.from?.[0] || 'package.json',
          1,
          `${vuln.packageName}@${vuln.version}: ${vuln.title || 'Vulnerability'}`,
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

// Parse SonarQube JSON output
const parseSonarQube = (sonarJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(sonarJsonPath, 'utf8'));
    const findings = [];

    if (data.issues) {
      data.issues.forEach(issue => {
        findings.push(createFinding(
          'sonarqube',
          issue.rule,
          issue.severity,
          issue.component.replace(/^.*:/, ''), // Remove project prefix
          issue.line || 1,
          issue.message,
          issue.type || 'code_smell',
          'heuristic' // SonarQube uses various heuristics
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing SonarQube results:', error.message);
    return [];
  }
};

// Parse npm audit JSON output
const parseNpmAudit = (npmAuditJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(npmAuditJsonPath, 'utf8'));
    const findings = [];

    if (data.vulnerabilities) {
      Object.entries(data.vulnerabilities).forEach(([pkg, vuln]) => {
        findings.push(createFinding(
          'npm-audit',
          `${pkg}-${vuln.via[0]?.cve || 'unknown'}`,
          vuln.severity,
          'package.json',
          1,
          `${pkg}: ${vuln.via[0]?.title || 'Vulnerability detected'}`,
          'dependency-vulnerability',
          'version-check'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing npm audit results:', error.message);
    return [];
  }
};

// Parse Trivy JSON output
const parseTrivy = (trivyJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(trivyJsonPath, 'utf8'));
    const findings = [];

    if (data.results) {
      data.results.forEach(result => {
        // Parse vulnerabilities
        if (result.Vulnerabilities) {
          result.Vulnerabilities.forEach(vuln => {
            findings.push(createFinding(
              'trivy',
              vuln.VulnerabilityID || 'trivy-vuln',
              vuln.Severity || 'medium',
              result.Target || 'package.json',
              1,
              `${vuln.PkgName}: ${vuln.Title || vuln.VulnerabilityID}`,
              'dependency-vulnerability',
              'version-check'
            ));
          });
        }

        // Parse misconfigurations
        if (result.Misconfigurations) {
          result.Misconfigurations.forEach(misconfig => {
            findings.push(createFinding(
              'trivy',
              misconfig.ID || 'trivy-misconfig',
              misconfig.Severity || 'medium',
              result.Target || 'Dockerfile',
              misconfig.CauseMetadata?.StartLine || 1,
              misconfig.Title || misconfig.Description || 'Misconfiguration detected',
              'iac-security',
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

// Parse Istanbul/nyc coverage JSON output
const parseCoverage = (coverageJsonPath) => {
  try {
    const data = JSON.parse(fs.readFileSync(coverageJsonPath, 'utf8'));
    const findings = [];

    Object.entries(data).forEach(([filePath, coverage]) => {
      const lineCoverage = coverage.s; // Statement coverage
      const totalStatements = Object.keys(lineCoverage).length;
      const coveredStatements = Object.values(lineCoverage).filter(v => v > 0).length;
      const coveragePercent = totalStatements > 0 ? (coveredStatements / totalStatements) * 100 : 100;

      if (coveragePercent < 50) {
        findings.push(createFinding(
          'coverage',
          'low-coverage',
          coveragePercent < 25 ? 'high' : 'medium',
          filePath,
          1,
          `Low test coverage: ${coveragePercent.toFixed(1)}%`,
          'testing',
          'heuristic'
        ));
      }
    });

    return findings;
  } catch (error) {
    console.error('Error parsing coverage results:', error.message);
    return [];
  }
};

// ==================== CATEGORIZATION FUNCTIONS ====================

const categorizeEslintRule = (ruleId) => {
  if (ruleId.includes('security')) return 'security';
  if (ruleId.includes('promise') || ruleId.includes('async')) return 'async-patterns';
  if (ruleId.includes('complexity')) return 'complexity';
  if (ruleId.includes('import')) return 'imports';
  return 'code-quality';
};

const categorizeSemgrepRule = (ruleId) => {
  if (!ruleId) return 'security';
  if (ruleId.includes('jwt') || ruleId.includes('oauth')) return 'authentication';
  if (ruleId.includes('sql') || ruleId.includes('injection')) return 'injection';
  if (ruleId.includes('xss')) return 'xss';
  if (ruleId.includes('api')) return 'api-security';
  if (ruleId.includes('crypto')) return 'cryptography';
  return 'security';
};

const categorizeSnykRule = (ruleId) => {
  if (!ruleId) return 'security';
  if (ruleId.includes('sql') || ruleId.includes('injection')) return 'injection';
  if (ruleId.includes('xss')) return 'xss';
  if (ruleId.includes('auth')) return 'authentication';
  if (ruleId.includes('crypto')) return 'cryptography';
  return 'security';
};

// ==================== OVERLAP DETECTION ====================

/**
 * Detect overlapping findings (same location flagged by multiple tools)
 * @param {Array} findings - All findings from all tools
 * @returns {Array} Overlap analysis results
 */
const detectOverlap = (findings) => {
  const locationMap = new Map(); // file:line -> [findings]

  findings.forEach(finding => {
    const key = `${finding.file}:${finding.line}`;
    if (!locationMap.has(key)) {
      locationMap.set(key, []);
    }
    locationMap.get(key).push(finding);
  });

  const overlaps = [];
  locationMap.forEach((findings, location) => {
    if (findings.length >= 2) {
      overlaps.push({
        location,
        tool_count: findings.length,
        tools: findings.map(f => f.source),
        rules: findings.map(f => f.rule),
        messages: findings.map(f => f.message),
        severities: findings.map(f => f.severity),
        categories: [...new Set(findings.map(f => f.category))],
        detection_methods: [...new Set(findings.map(f => f.detection_method))],
        convergence_score: calculateConvergenceScore(findings),
        confidence: getConfidenceLevel(calculateConvergenceScore(findings)),
        representative_finding: findings[0] // Use first finding as representative
      });
    }
  });

  // Sort by convergence score (highest confidence first)
  overlaps.sort((a, b) => b.convergence_score - a.convergence_score);

  return overlaps;
};

/**
 * Calculate convergence score based on number of tools and detection method diversity
 * @param {Array} findings - Findings at the same location
 * @returns {number} Convergence score (0.0 - 1.0)
 */
const calculateConvergenceScore = (findings) => {
  // Base score: 0.3 per tool, capped at 0.9
  const baseScore = Math.min(findings.length * 0.3, 0.9);

  let bonus = 0;

  // Bonus for different detection methods (+0.1)
  const methods = new Set(findings.map(f => f.detection_method));
  const hasPatternMatcher = methods.has('pattern');
  const hasDataflow = methods.has('dataflow');
  if (hasPatternMatcher && hasDataflow) {
    bonus += 0.1;
  }

  // Cap at 1.0
  return Math.min(baseScore + bonus, 1.0);
};

/**
 * Get confidence level based on convergence score
 * @param {number} score - Convergence score
 * @returns {string} 'high', 'medium', or 'low'
 */
const getConfidenceLevel = (score) => {
  if (score >= 0.8) return 'high';
  if (score >= 0.5) return 'medium';
  return 'low';
};

// ==================== MAIN EXECUTION ====================

const main = () => {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: node format-static-results.js <output-dir> [options]');
    console.error('');
    console.error('Options:');
    console.error('  --eslint=<path>           ESLint JSON output');
    console.error('  --semgrep=<path>          Semgrep JSON output');
    console.error('  --snyk-code=<path>        Snyk Code SARIF output');
    console.error('  --snyk-open-source=<path> Snyk Open Source JSON output');
    console.error('  --sonar=<path>            SonarQube JSON output');
    console.error('  --npm-audit=<path>        npm audit JSON output');
    console.error('  --trivy=<path>            Trivy JSON output');
    console.error('  --coverage=<path>         Coverage JSON output');
    process.exit(1);
  }

  const outputDir = args[0];
  const options = {};

  args.slice(1).forEach(arg => {
    const [key, value] = arg.replace('--', '').split('=');
    options[key] = value;
  });

  const allFindings = [];
  const toolResults = {};

  // Process each tool's output
  console.log('📊 Processing static analysis results...\n');

  if (options.eslint && fs.existsSync(options.eslint)) {
    const findings = parseEslint(options.eslint);
    allFindings.push(...findings);
    toolResults.eslint = { findings_count: findings.length, status: 'success', detection_method: 'pattern' };
    console.log(`✅ ESLint: ${findings.length} findings`);
  }

  if (options.semgrep && fs.existsSync(options.semgrep)) {
    const findings = parseSemgrep(options.semgrep);
    allFindings.push(...findings);
    toolResults.semgrep = { findings_count: findings.length, status: 'success', detection_method: 'pattern' };
    console.log(`✅ Semgrep: ${findings.length} findings`);
  }

  if (options['snyk-code'] && fs.existsSync(options['snyk-code'])) {
    const findings = parseSnykCode(options['snyk-code']);
    allFindings.push(...findings);
    toolResults.snyk_code = { findings_count: findings.length, status: 'success', detection_method: 'dataflow' };
    console.log(`✅ Snyk Code: ${findings.length} findings`);
  }

  if (options['snyk-open-source'] && fs.existsSync(options['snyk-open-source'])) {
    const findings = parseSnykOpenSource(options['snyk-open-source']);
    allFindings.push(...findings);
    toolResults.snyk_open_source = { findings_count: findings.length, status: 'success', detection_method: 'version-check' };
    console.log(`✅ Snyk Open Source: ${findings.length} findings`);
  }

  if (options.sonar && fs.existsSync(options.sonar)) {
    const findings = parseSonarQube(options.sonar);
    allFindings.push(...findings);
    toolResults.sonarqube = { findings_count: findings.length, status: 'success', detection_method: 'heuristic' };
    console.log(`✅ SonarQube: ${findings.length} findings`);
  }

  if (options['npm-audit'] && fs.existsSync(options['npm-audit'])) {
    const findings = parseNpmAudit(options['npm-audit']);
    allFindings.push(...findings);
    toolResults.npm_audit = { findings_count: findings.length, status: 'success', detection_method: 'version-check' };
    console.log(`✅ npm audit: ${findings.length} findings`);
  }

  if (options.trivy && fs.existsSync(options.trivy)) {
    const findings = parseTrivy(options.trivy);
    allFindings.push(...findings);
    toolResults.trivy = { findings_count: findings.length, status: 'success', detection_method: 'version-check + pattern' };
    console.log(`✅ Trivy: ${findings.length} findings`);
  }

  if (options.coverage && fs.existsSync(options.coverage)) {
    const findings = parseCoverage(options.coverage);
    allFindings.push(...findings);
    toolResults.coverage = { findings_count: findings.length, status: 'success', detection_method: 'heuristic' };
    console.log(`✅ Coverage: ${findings.length} findings`);
  }

  console.log('');

  // Detect overlaps
  console.log('🔍 Detecting overlapping findings...\n');
  const overlaps = detectOverlap(allFindings);

  console.log(`📍 Overlap Analysis:`);
  console.log(`   - Total findings: ${allFindings.length}`);
  console.log(`   - Locations with 2+ tools: ${overlaps.length}`);
  console.log(`   - High confidence overlaps (3+ tools): ${overlaps.filter(o => o.tool_count >= 3).length}`);
  console.log('');

  // Generate unified output
  const unifiedResults = {
    timestamp: new Date().toISOString(),
    tech_stack: 'javascript',
    tool_results: toolResults,
    total_findings: allFindings.length,
    findings_by_severity: {
      critical: allFindings.filter(f => f.severity === 'critical').length,
      high: allFindings.filter(f => f.severity === 'high').length,
      medium: allFindings.filter(f => f.severity === 'medium').length,
      low: allFindings.filter(f => f.severity === 'low').length
    },
    findings_by_category: Object.entries(
      allFindings.reduce((acc, f) => {
        acc[f.category] = (acc[f.category] || 0) + 1;
        return acc;
      }, {})
    ).map(([category, count]) => ({ category, count })),
    findings_by_detection_method: Object.entries(
      allFindings.reduce((acc, f) => {
        acc[f.detection_method] = (acc[f.detection_method] || 0) + 1;
        return acc;
      }, {})
    ).map(([method, count]) => ({ method, count })),
    overlap_analysis: {
      total_overlaps: overlaps.length,
      high_confidence: overlaps.filter(o => o.confidence === 'high').length,
      medium_confidence: overlaps.filter(o => o.confidence === 'medium').length,
      low_confidence: overlaps.filter(o => o.confidence === 'low').length,
      overlaps: overlaps
    },
    findings: allFindings
  };

  // Write unified results
  const outputPath = path.join(outputDir, 'unified-results.json');
  fs.writeFileSync(outputPath, JSON.stringify(unifiedResults, null, 2));

  console.log(`✅ Unified results written to: ${outputPath}`);
  console.log(`\n📊 Summary:`);
  console.log(`   Total findings: ${allFindings.length}`);
  console.log(`   - Critical: ${unifiedResults.findings_by_severity.critical}`);
  console.log(`   - High: ${unifiedResults.findings_by_severity.high}`);
  console.log(`   - Medium: ${unifiedResults.findings_by_severity.medium}`);
  console.log(`   - Low: ${unifiedResults.findings_by_severity.low}`);
  console.log(`\n🎯 Overlap Confidence:`);
  console.log(`   - High confidence (3+ tools): ${unifiedResults.overlap_analysis.high_confidence}`);
  console.log(`   - Medium confidence (2 tools): ${unifiedResults.overlap_analysis.medium_confidence}`);
  console.log('');
};

if (require.main === module) {
  main();
}

module.exports = {
  parseEslint,
  parseSemgrep,
  parseSnykCode,
  parseSnykOpenSource,
  parseSonarQube,
  parseNpmAudit,
  parseTrivy,
  parseCoverage,
  detectOverlap,
  calculateConvergenceScore
};
