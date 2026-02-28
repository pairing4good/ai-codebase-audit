#!/usr/bin/env node
/**
 * Python Static Analysis Results Formatter
 *
 * Unifies outputs from multiple Python static analysis tools into a single format.
 *
 * Tools supported:
 * - Semgrep (OWASP/CWE patterns for Python)
 * - Bandit (Python security scanner)
 * - Pylint (code quality)
 * - mypy (type checking)
 * - Safety (dependency CVEs)
 * - Snyk (SAST + dependencies)
 * - Trivy (filesystem/dependency scanner)
 * - Radon (complexity metrics)
 * - SonarQube (if configured)
 *
 * Usage: node format-static-results.js <analysis_dir>
 */

const fs = require('fs');
const path = require('path');

const ANALYSIS_DIR = process.argv[2] || '.analysis/stage3-static-analysis';
const RAW_OUTPUTS_DIR = path.join(ANALYSIS_DIR, 'raw-outputs');

// Unified finding format
class Finding {
  constructor(data) {
    this.file = data.file;
    this.line = data.line || null;
    this.line_end = data.line_end || data.line;
    this.severity = data.severity; // critical, high, medium, low
    this.category = data.category; // security, quality, complexity, type-safety, dependency
    this.rule_id = data.rule_id;
    this.message = data.message;
    this.tool = data.tool;
    this.cwe = data.cwe || null;
    this.owasp = data.owasp || null;
    this.confidence = data.confidence || null;
  }

  get location_key() {
    return `${this.file}:${this.line}`;
  }
}

// Tool parsers
class ToolParser {
  static parseSemgrep(filePath) {
    if (!fs.existsSync(filePath)) return [];
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const findings = [];

    for (const result of (data.results || [])) {
      findings.push(new Finding({
        file: result.path,
        line: result.start?.line,
        line_end: result.end?.line,
        severity: this.mapSemgrepSeverity(result.extra?.severity),
        category: 'security',
        rule_id: result.check_id,
        message: result.extra?.message || result.extra?.lines,
        tool: 'semgrep',
        cwe: result.extra?.metadata?.cwe?.[0],
        owasp: result.extra?.metadata?.['owasp']?.[0],
        confidence: result.extra?.metadata?.confidence
      }));
    }

    return findings;
  }

  static mapSemgrepSeverity(sev) {
    const map = { ERROR: 'high', WARNING: 'medium', INFO: 'low' };
    return map[sev] || 'medium';
  }

  static parseBandit(filePath) {
    if (!fs.existsSync(filePath)) return [];
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const findings = [];

    for (const result of (data.results || [])) {
      findings.push(new Finding({
        file: result.filename,
        line: result.line_number,
        line_end: result.line_number,
        severity: result.issue_severity?.toLowerCase() || 'medium',
        category: 'security',
        rule_id: result.test_id,
        message: result.issue_text,
        tool: 'bandit',
        cwe: result.issue_cwe?.id ? `CWE-${result.issue_cwe.id}` : null,
        confidence: result.issue_confidence?.toLowerCase()
      }));
    }

    return findings;
  }

  static parsePylint(filePath) {
    if (!fs.existsSync(filePath)) return [];
    try {
      const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      const findings = [];

      for (const result of (Array.isArray(data) ? data : [])) {
        findings.push(new Finding({
          file: result.path,
          line: result.line,
          line_end: result.line,
          severity: this.mapPylintSeverity(result.type),
          category: 'quality',
          rule_id: result.symbol || result['message-id'],
          message: result.message,
          tool: 'pylint'
        }));
      }

      return findings;
    } catch (e) {
      console.error('Error parsing Pylint output:', e.message);
      return [];
    }
  }

  static mapPylintSeverity(type) {
    const map = {
      'error': 'high',
      'warning': 'medium',
      'convention': 'low',
      'refactor': 'low',
      'info': 'low'
    };
    return map[type] || 'low';
  }

  static parseMypy(filePath) {
    if (!fs.existsSync(filePath)) return [];
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const findings = [];

    for (const result of (Array.isArray(data) ? data : [])) {
      findings.push(new Finding({
        file: result.file,
        line: result.line,
        line_end: result.line,
        severity: result.severity === 'error' ? 'medium' : 'low',
        category: 'type-safety',
        rule_id: result.error_code || 'type-error',
        message: result.message,
        tool: 'mypy'
      }));
    }

    return findings;
  }

  static parseSafety(filePath) {
    if (!fs.existsSync(filePath)) return [];
    try {
      const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      const findings = [];

      const vulnerabilities = Array.isArray(data) ? data : (data.vulnerabilities || []);

      for (const vuln of vulnerabilities) {
        findings.push(new Finding({
          file: 'requirements.txt', // Safety scans dependencies
          line: null,
          severity: this.mapSafetySeverity(vuln.severity),
          category: 'dependency',
          rule_id: vuln.vulnerability_id || vuln.id,
          message: `${vuln.package_name} ${vuln.installed_version}: ${vuln.advisory}`,
          tool: 'safety',
          cve: vuln.cve
        }));
      }

      return findings;
    } catch (e) {
      console.error('Error parsing Safety output:', e.message);
      return [];
    }
  }

  static mapSafetySeverity(sev) {
    if (!sev) return 'medium';
    const s = sev.toLowerCase();
    if (s.includes('critical')) return 'critical';
    if (s.includes('high')) return 'high';
    if (s.includes('medium')) return 'medium';
    return 'low';
  }

  static parseRadon(filePath) {
    if (!fs.existsSync(filePath)) return [];
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const findings = [];

    for (const [file, items] of Object.entries(data)) {
      if (!Array.isArray(items)) continue;

      for (const item of items) {
        if (item.complexity > 10) {  // High complexity threshold
          findings.push(new Finding({
            file: file,
            line: item.lineno,
            line_end: item.endline || item.lineno,
            severity: item.complexity > 20 ? 'high' : 'medium',
            category: 'complexity',
            rule_id: 'high-complexity',
            message: `Function '${item.name}' has cyclomatic complexity of ${item.complexity} (threshold: 10)`,
            tool: 'radon'
          }));
        }
      }
    }

    return findings;
  }

  static parseSnykCode(filePath) {
    if (!fs.existsSync(filePath)) return [];
    try {
      const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      const findings = [];

      for (const result of (data.runs?.[0]?.results || [])) {
        const location = result.locations?.[0]?.physicalLocation;
        findings.push(new Finding({
          file: location?.artifactLocation?.uri,
          line: location?.region?.startLine,
          line_end: location?.region?.endLine,
          severity: this.mapSnykSeverity(result.properties?.priorityScore),
          category: 'security',
          rule_id: result.ruleId,
          message: result.message?.text,
          tool: 'snyk-code',
          cwe: result.properties?.cwe?.[0]
        }));
      }

      return findings;
    } catch (e) {
      console.error('Error parsing Snyk Code output:', e.message);
      return [];
    }
  }

  static parseSnykOSS(filePath) {
    if (!fs.existsSync(filePath)) return [];
    try {
      const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      const findings = [];

      for (const vuln of (data.vulnerabilities || [])) {
        findings.push(new Finding({
          file: 'requirements.txt',
          line: null,
          severity: vuln.severity,
          category: 'dependency',
          rule_id: vuln.id,
          message: `${vuln.name} ${vuln.version}: ${vuln.title}`,
          tool: 'snyk-oss',
          cve: vuln.identifiers?.CVE?.[0]
        }));
      }

      return findings;
    } catch (e) {
      console.error('Error parsing Snyk OSS output:', e.message);
      return [];
    }
  }

  static mapSnykSeverity(score) {
    if (score >= 800) return 'critical';
    if (score >= 600) return 'high';
    if (score >= 400) return 'medium';
    return 'low';
  }

  static parseTrivy(filePath) {
    if (!fs.existsSync(filePath)) return [];
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const findings = [];

    for (const result of (data.Results || [])) {
      for (const vuln of (result.Vulnerabilities || [])) {
        findings.push(new Finding({
          file: result.Target || 'dependencies',
          line: null,
          severity: vuln.Severity?.toLowerCase() || 'medium',
          category: 'dependency',
          rule_id: vuln.VulnerabilityID,
          message: `${vuln.PkgName} ${vuln.InstalledVersion}: ${vuln.Title}`,
          tool: 'trivy',
          cve: vuln.VulnerabilityID
        }));
      }

      // Parse secrets
      for (const secret of (result.Secrets || [])) {
        findings.push(new Finding({
          file: result.Target,
          line: secret.StartLine,
          severity: 'critical',
          category: 'security',
          rule_id: secret.RuleID,
          message: `Potential secret detected: ${secret.Title}`,
          tool: 'trivy'
        }));
      }
    }

    return findings;
  }
}

// Main processing
function main() {
  console.log('=== Python Static Analysis Results Formatter ===\n');

  const allFindings = [];
  const toolStats = {};

  // Parse each tool's output
  const tools = [
    { name: 'Semgrep', file: 'semgrep-report.json', parser: ToolParser.parseSemgrep },
    { name: 'Bandit', file: 'bandit-report.json', parser: ToolParser.parseBandit },
    { name: 'Pylint', file: 'pylint-report.json', parser: ToolParser.parsePylint },
    { name: 'mypy', file: 'mypy-report.json', parser: ToolParser.parseMypy },
    { name: 'Safety', file: 'safety-report.json', parser: ToolParser.parseSafety },
    { name: 'Radon', file: 'radon-report.json', parser: ToolParser.parseRadon },
    { name: 'Snyk Code', file: 'snyk-code-report.json', parser: ToolParser.parseSnykCode },
    { name: 'Snyk OSS', file: 'snyk-oss-report.json', parser: ToolParser.parseSnykOSS },
    { name: 'Trivy', file: 'trivy-report.json', parser: ToolParser.parseTrivy }
  ];

  for (const tool of tools) {
    const filePath = path.join(RAW_OUTPUTS_DIR, tool.file);
    console.log(`Processing ${tool.name}...`);

    try {
      const findings = tool.parser(filePath);
      allFindings.push(...findings);
      toolStats[tool.name] = findings.length;
      console.log(`  Found ${findings.length} findings`);
    } catch (error) {
      console.error(`  Error: ${error.message}`);
      toolStats[tool.name] = 0;
    }
  }

  console.log(`\nTotal findings: ${allFindings.length}\n`);

  // Write unified results
  const unifiedPath = path.join(ANALYSIS_DIR, 'unified-results.json');
  fs.writeFileSync(unifiedPath, JSON.stringify(allFindings, null, 2));
  console.log(`✅ Wrote unified results: ${unifiedPath}`);

  // Analyze overlap (same location found by multiple tools)
  const locationMap = new Map();
  for (const finding of allFindings) {
    const key = finding.location_key;
    if (!locationMap.has(key)) {
      locationMap.set(key, []);
    }
    locationMap.get(key).push(finding);
  }

  const overlaps = Array.from(locationMap.entries())
    .filter(([_, findings]) => findings.length > 1)
    .map(([location, findings]) => ({
      location,
      count: findings.length,
      tools: [...new Set(findings.map(f => f.tool))],
      severities: [...new Set(findings.map(f => f.severity))],
      categories: [...new Set(findings.map(f => f.category))]
    }))
    .sort((a, b) => b.count - a.count);

  const overlapPath = path.join(ANALYSIS_DIR, 'overlap-analysis.json');
  fs.writeFileSync(overlapPath, JSON.stringify({
    total_locations_with_overlap: overlaps.length,
    overlaps: overlaps
  }, null, 2));
  console.log(`✅ Wrote overlap analysis: ${overlapPath}`);

  // Generate tool comparison markdown
  let markdown = '# Python Static Analysis Tool Comparison\n\n';
  markdown += '## Findings by Tool\n\n';
  markdown += '| Tool | Findings | Category Focus |\n';
  markdown += '|------|----------|----------------|\n';

  for (const [tool, count] of Object.entries(toolStats)) {
    const categories = [...new Set(allFindings.filter(f => f.tool.toLowerCase().includes(tool.toLowerCase())).map(f => f.category))];
    markdown += `| ${tool} | ${count} | ${categories.join(', ')} |\n`;
  }

  markdown += '\n## High-Confidence Findings (Multiple Tools)\n\n';
  markdown += `Found ${overlaps.length} locations flagged by multiple tools:\n\n`;

  for (const overlap of overlaps.slice(0, 20)) {  // Top 20
    markdown += `- **${overlap.location}** (${overlap.count} tools: ${overlap.tools.join(', ')})\n`;
  }

  markdown += '\n## Coverage by Category\n\n';
  const categories = {};
  for (const finding of allFindings) {
    categories[finding.category] = (categories[finding.category] || 0) + 1;
  }

  markdown += '| Category | Findings |\n';
  markdown += '|----------|----------|\n';
  for (const [cat, count] of Object.entries(categories)) {
    markdown += `| ${cat} | ${count} |\n`;
  }

  const comparisonPath = path.join(ANALYSIS_DIR, 'tool-comparison.md');
  fs.writeFileSync(comparisonPath, markdown);
  console.log(`✅ Wrote tool comparison: ${comparisonPath}`);

  console.log('\n=== Formatting Complete ===');
  console.log(`\nNext: Review ${comparisonPath} for analysis summary`);
}

try {
  main();
} catch (error) {
  console.error('Fatal error:', error);
  process.exit(1);
}
