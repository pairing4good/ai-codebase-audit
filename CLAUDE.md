# Claude Skill Runner — Environment Guide

You are running inside a Docker container purpose-built for automated code
analysis and skill execution. This file tells you everything you need to know
about your environment, how to switch language versions, and how to behave.

---

## Your Working Environment

- Your working directory is a project directory containing source code,
  this CLAUDE.md, and a `.claude/` directory with all skills and agents
  needed to complete your task.
- Skills write output to `.analysis/<language>/` inside this directory.
  This keeps parallel skill runs isolated from each other.
- Do not navigate above your working directory root.

### Directory Structure

```
/workdir/
  CLAUDE.md                         ← this file (authoritative for all projects)
  config.yml
  .claude/                          ← source, copied into each project at startup
    settings.json
    agents/
      architecture-analyzer.md
      dependency-analyzer.md
      maintainability-analyzer.md
      security-analyzer.md
      reconciliation-agent.md
      adversarial-agent.md
      artifact-generator.md
    skills/
      audit-java/
        SKILL.md
        tools/
          auto-install-tools.sh
          checkstyle-runner.sh
          dependency-check-runner.sh
          pmd-runner.sh
          semgrep-runner.sh
          snyk-runner.sh
          sonarqube-runner.sh
          spotbugs-runner.sh
          trivy-runner.sh
          ...
      audit-javascript/
        SKILL.md
        tools/ ...
      audit-dotnet/
        SKILL.md
        tools/ ...
      audit-python/
        SKILL.md
        tools/ ...
  project-one/                      ← your working directory (cwd)
    CLAUDE.md                       ← copied from workdir root
    .claude/                        ← copied from workdir root
      settings.json
      agents/ ...
      skills/ ...
    .git/
    src/
    pom.xml
    .analysis/                      ← skill output written here
      java/
  project-two/
    CLAUDE.md                       ← copied from workdir root
    .claude/                        ← copied from workdir root
      ...
    .git/
    src/
    package.json
    .analysis/
      javascript/
  project-three/
    ...
  logs/
```

---

## Language Runtimes

Four language runtimes are available. Each has a dedicated version manager.
Use the commands below to check versions, install new ones, and switch between
them. Changes made with `use` or `global` apply to the current session.
Changes made with `default` or `alias default` persist across sessions.

---

### Java — managed by SDKMAN

```bash
# Check active version
java -version
sdk current java

# List installed versions
sdk list java | grep -E "installed|local"

# List all available versions (Temurin = Eclipse open-source JDK, most common)
sdk list java

# Install a version
sdk install java 17.0.13-tem
sdk install java 11.0.25-tem

# Switch for this session only
sdk use java 17.0.13-tem

# Switch permanently
sdk default java 17.0.13-tem
```

Version identifier format: `<version>-<vendor>`
Common vendors: `tem` (Eclipse Temurin), `open` (OpenJDK), `graal` (GraalVM)

Pre-installed: `21.0.5-tem` (default), `17.0.13-tem`

---

### Node.js — managed by nvm

```bash
# Check active version
node --version
npm --version

# List installed versions (* = active)
nvm list

# List available LTS versions
nvm ls-remote --lts

# Install a version
nvm install 18
nvm install 16

# Switch for this session only
nvm use 18

# Switch permanently (sets the default alias)
nvm alias default 18
```

npm switches automatically when the Node version changes.

Pre-installed: `20` (default), `18`

---

### Python — managed by pyenv

```bash
# Check active version
python --version
which python

# List installed versions (* = active)
pyenv versions

# List all installable versions
pyenv install --list | grep -E "^\s+3\."

# Install a version
pyenv install 3.11
pyenv install 3.10

# Switch globally (all sessions)
pyenv global 3.11

# Switch for current directory only (writes .python-version)
pyenv local 3.11
```

After switching Python versions, reinstall any required packages:
```bash
pip install claude-agent-sdk pyyaml tenacity
```

Pre-installed: `3.12` (default), `3.11`

---

### .NET — side-by-side SDKs

.NET does not use a version switcher. Multiple SDK versions coexist under
`/opt/dotnet`. The dotnet CLI selects the version automatically based on
`global.json` if one is present in the project directory, otherwise it uses
the latest installed SDK.

```bash
# Check active version
dotnet --version

# List all installed SDKs
dotnet --list-sdks

# List all installed runtimes
dotnet --list-runtimes

# Install an additional SDK version
/opt/dotnet-install.sh --channel 7.0 --install-dir /opt/dotnet
/opt/dotnet-install.sh --channel 9.0 --install-dir /opt/dotnet

# Pin a specific SDK version for this project
dotnet new globaljson --sdk-version 6.0.428 --roll-forward latestPatch

# Or write global.json manually
echo '{ "sdk": { "version": "6.0.428", "rollForward": "latestPatch" } }' > global.json
```

Pre-installed: `8` (default), `6`

---

## Checking All Active Versions at Once

```bash
echo "Java:    $(java -version 2>&1 | head -1)"
echo "Node:    $(node --version)"
echo "Python:  $(python --version)"
echo "dotnet:  $(dotnet --version)"
```

---

## Skills

All skills are in `.claude/skills/` at the root of your working directory.
Always run skills from your working directory root — never from a subdirectory.
Output is written to `.analysis/<language>/` within your working directory.

When executing a skill:
1. Read `.claude/skills/<skill-name>/SKILL.md` first
2. Follow its instructions precisely
3. Write output to `.analysis/<language>/` as the skill specifies
4. Report clearly if something cannot be completed and why

---

## Important Constraints

- **Do not navigate above your working directory root.**
- **Do not install system packages with apt** unless a skill explicitly requires it.
- **Do not commit or push** any git changes unless a skill explicitly instructs you to.
- **Do not delete or overwrite source files.** Write output only to `.analysis/`.
- **Write results clearly.** Be explicit about what was found, changed, and skipped.

---

## If Something Goes Wrong

- If the required language version is not installed, install it using the
  commands above and continue.
- If a build fails due to a version mismatch, check `global.json` (.NET),
  `.nvmrc` (Node), `.python-version` (Python), or `.sdkmanrc` (Java) in the
  project root and switch to the specified version.
- If a tool is missing, install it via the language's package manager
  (`npm install -g`, `pip install`, `sdk install`, etc.) before escalating.
- Always report what version you ended up using in your final output.
