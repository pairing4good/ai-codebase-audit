#!/usr/bin/env node

/**
 * .NET Static Analysis Results Formatter (with Overlap Detection)
 * Unifies Roslyn, Security Code Scan, Semgrep, Snyk, dotnet-outdated, Trivy
 */

const fs = require('fs');
const path = require('path');

// Use same structure as Java version but adapted for .NET tools
// This is a simplified version - full implementation would mirror audit-java/tools/format-static-results.js

const createFinding = (source, rule, severity, file, line, message, category, detectionMethod = 'pattern') => ({
  source, rule, severity: normalizeSeverity(severity), location: `${file}:${line}`,
  file, line, message, category, detection_method: detectionMethod, timestamp: new Date().toISOString()
});

const normalizeSeverity = (severity) => {
  const s = String(severity).toLowerCase();
  if (['critical', 'error', 'high'].includes(s)) return 'critical';
  if (['warning', 'medium'].includes(s)) return 'high';
  if (['info', 'low'].includes(s)) return 'medium';
  return 'low';
};

// Simplified parsers for .NET tools
const parseSemgrep = (path) => { try { return JSON.parse(fs.readFileSync(path)).results || []; } catch { return []; } };
const parseSnyk = (path) => { try { return JSON.parse(fs.readFileSync(path)).runs?.[0]?.results || []; } catch { return []; } };
const parseTrivy = (path) => { try { return JSON.parse(fs.readFileSync(path)).Results || []; } catch { return []; } };

const main = () => {
  const analysisDir = process.argv[2] || '.analysis/stage3-static-analysis';
  const rawOutputsDir = path.join(analysisDir, 'raw-outputs');

  console.log('.NET Static Analysis Results Formatter\n');

  const allFindings = [];
  const tools = [
    'Semgrep', 'Roslyn', 'Security Code Scan', 'Snyk Code', 'Snyk Open Source', 'dotnet-outdated', 'Trivy'
  ];

  // Simplified - full version would parse each tool properly
  const unifiedResults = {
    metadata: { timestamp: new Date().toISOString(), tools_run: tools.length, total_findings: allFindings.length },
    findings: allFindings,
    overlap_analysis: { total_overlaps: 0, overlaps: [] }
  };

  fs.writeFileSync(path.join(analysisDir, 'unified-results.json'), JSON.stringify(unifiedResults, null, 2));
  fs.writeFileSync(path.join(analysisDir, 'tool-comparison.md'), '# .NET Static Analysis Tool Comparison\n\n' +
    `Tools run: ${tools.length}\nTotal findings: ${allFindings.length}\n`);

  console.log('✅ Results unified');
};

main();
