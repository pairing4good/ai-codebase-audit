#!/usr/bin/env node

/**
 * Static Analysis Results Formatter
 *
 * Unifies outputs from multiple static analysis tools into a standardized JSON format
 * for easy consumption by the reconciliation agent.
 */

const fs = require('fs');
const path = require('path');

// Standardized finding schema
const createFinding = (source, rule, severity, file, line, message, category) => ({
  source,
  rule,
  severity: normalizeSeverity(severity),
  location: `${file}:${line}`,
  file,
  line,
  message,
  category,
  timestamp: new Date().toISOString()
});

// Normalize severity across different tools
const normalizeSeverity = (severity) => {
  const s = String(severity).toLowerCase();
  if (['critical', 'blocker', 'error', '2'].includes(s)) return 'critical';
  if (['high', 'major', 'warning', '1'].includes(s)) return 'high';
  if (['medium', 'minor', 'info', '0'].includes(s)) return 'medium';
  return 'low';
};

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
          msg.ruleId ? categorizeEslintRule(msg.ruleId) : 'syntax'
        ));
      });
    });

    return findings;
  } catch (error) {
    console.error('Error parsing ESLint results:', error.message);
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
          issue.type || 'code_smell'
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
          'dependency-vulnerability'
        ));
      });
    }

    return findings;
  } catch (error) {
    console.error('Error parsing npm audit results:', error.message);
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
      const branchCoverage = coverage.b; // Branch coverage

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
          'testing'
        ));
      }
    });

    return findings;
  } catch (error) {
    console.error('Error parsing coverage results:', error.message);
    return [];
  }
};

// Categorize ESLint rules
const categorizeEslintRule = (ruleId) => {
  if (ruleId.includes('security')) return 'security';
  if (ruleId.includes('promise') || ruleId.includes('async')) return 'async-patterns';
  if (ruleId.includes('complexity')) return 'complexity';
  if (ruleId.includes('import')) return 'imports';
  return 'code-quality';
};

// Main execution
const main = () => {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: node format-static-results.js <output-dir> [--eslint=path] [--sonar=path] [--npm-audit=path] [--coverage=path]');
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
  if (options.eslint && fs.existsSync(options.eslint)) {
    const eslintFindings = parseEslint(options.eslint);
    allFindings.push(...eslintFindings);
    toolResults.eslint = {
      findings_count: eslintFindings.length,
      file: options.eslint,
      status: 'success'
    };
  }

  if (options.sonar && fs.existsSync(options.sonar)) {
    const sonarFindings = parseSonarQube(options.sonar);
    allFindings.push(...sonarFindings);
    toolResults.sonarqube = {
      findings_count: sonarFindings.length,
      file: options.sonar,
      status: 'success'
    };
  }

  if (options['npm-audit'] && fs.existsSync(options['npm-audit'])) {
    const npmFindings = parseNpmAudit(options['npm-audit']);
    allFindings.push(...npmFindings);
    toolResults.npm_audit = {
      findings_count: npmFindings.length,
      file: options['npm-audit'],
      status: 'success'
    };
  }

  if (options.coverage && fs.existsSync(options.coverage)) {
    const coverageFindings = parseCoverage(options.coverage);
    allFindings.push(...coverageFindings);
    toolResults.coverage = {
      findings_count: coverageFindings.length,
      file: options.coverage,
      status: 'success'
    };
  }

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
    findings: allFindings
  };

  // Write unified results
  const outputPath = path.join(outputDir, 'unified-results.json');
  fs.writeFileSync(outputPath, JSON.stringify(unifiedResults, null, 2));
  console.log(`Unified results written to: ${outputPath}`);
  console.log(`Total findings: ${allFindings.length}`);
  console.log(`  Critical: ${unifiedResults.findings_by_severity.critical}`);
  console.log(`  High: ${unifiedResults.findings_by_severity.high}`);
  console.log(`  Medium: ${unifiedResults.findings_by_severity.medium}`);
  console.log(`  Low: ${unifiedResults.findings_by_severity.low}`);
};

if (require.main === module) {
  main();
}

module.exports = { parseEslint, parseSonarQube, parseNpmAudit, parseCoverage };
