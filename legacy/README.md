# Legacy Docker Compose Approach

This directory contains the previous Docker Compose-based orchestration.

**Status**: Deprecated as of 2026-03-07

**Migration**: Use `orchestrator_devcontainer.py` in project root instead.

**Removal**: Planned for 2026-06-07 (3 months)

## Files

- `docker-compose.yml` - Old Docker Compose configuration
- `run_skills.py` - Old Python orchestrator (single container, N tasks)
- `entrypoint.sh` - Old container startup script

## Why Deprecated?

The new devcontainer approach provides:

### 1. True Container Isolation
- **Legacy**: 1 container, N tasks running in parallel as Python async tasks
- **DevContainer**: N containers, 1 task each with full process isolation

### 2. Build-from-Source Transparency
- **Legacy**: Pulled prebuilt images from container registry
- **DevContainer**: Builds from committed `.devcontainer/Dockerfile`
- All tool installations visible in plain text
- Complete reproducibility from `git clone`

### 3. Standards Compliance
- **Legacy**: Custom Docker Compose setup
- **DevContainer**: Official devcontainer spec (devcontainer.json)
- Compatible with VS Code Dev Containers, GitHub Codespaces
- Based on Anthropic's official devcontainer base

### 4. Better Security
- **Legacy**: Tasks shared container resources (filesystem, network, processes)
- **DevContainer**: Each task in isolated container with dedicated resources
- Container-level isolation prevents cross-task interference
- Read-only framework config mounts prevent accidental modifications

### 5. Improved Resource Management
- **Legacy**: All tasks competed for shared 4GB memory limit
- **DevContainer**: Each container gets dedicated resources
- Better parallelization with semaphore-based concurrency control
- Cleaner failure isolation (one task fails, others unaffected)

### 6. Enhanced Debugging
- **Legacy**: Logs from all tasks mixed in single container output
- **DevContainer**: Isolated logs per container with unique UIDs
- Centralized log collection to `logs/task_*` files
- Easier to trace execution flow per task

## Migration Guide

### Old Workflow (Docker Compose)

```bash
# Navigate to repo
cd /path/to/ai-codebase-audit

# Set environment variables
cp .env.example .env
# Edit .env with AUDIT_BASE_DIR and ANTHROPIC_API_KEY

# Build and run
docker compose build
docker compose run --rm skills
```

### New Workflow (DevContainer)

```bash
# Navigate to repo
cd /path/to/ai-codebase-audit

# Install Python dependencies (one-time)
pip install aiodocker pyyaml

# Set environment variables (same as before)
cp .env.example .env
# Edit .env with AUDIT_BASE_DIR and ANTHROPIC_API_KEY

# Run orchestrator (builds image automatically on first run)
python3 orchestrator_devcontainer.py
```

### Key Differences

1. **No Docker Compose**: Use Python orchestrator directly
2. **First run builds image**: Takes 10-15 minutes (vs instant pull)
3. **Subsequent runs fast**: Docker caching makes builds ~30 seconds
4. **Same workspace structure**: `AUDIT_BASE_DIR` layout unchanged
5. **Same config.yml**: Minor additions (image_tag, rebuild), backward compatible
6. **Same skills**: All `.claude/skills/` work identically

### What Stayed the Same

- Workspace directory structure (`AUDIT_BASE_DIR`)
- Configuration file (`config.yml`)
- Skills and agents (`.claude/` directory)
- Environment variables (`ANTHROPIC_API_KEY`, etc.)
- Output locations (`logs/`, `.analysis/`)
- API key management
- Cost controls (`max_budget_usd`)

### What Changed

| Aspect | Legacy | DevContainer |
|--------|--------|--------------|
| Command | `docker compose run --rm skills` | `python3 orchestrator_devcontainer.py` |
| Image source | Pulled from registry | Built from `.devcontainer/Dockerfile` |
| Container count | 1 container | N containers (one per task) |
| Orchestration | `run_skills.py` inside container | `orchestrator_devcontainer.py` on host |
| Isolation | Task-level (async) | Container-level (processes) |
| Logs | Single container output | Per-task log files |

## Troubleshooting Legacy Approach

If you need to use the legacy approach temporarily:

1. **Restore files to root**:
   ```bash
   cp legacy/docker-compose.yml .
   cp legacy/run_skills.py .
   cp legacy/entrypoint.sh .
   ```

2. **Build and run**:
   ```bash
   docker compose build
   docker compose run --rm skills
   ```

3. **Clean up after**:
   ```bash
   mv docker-compose.yml legacy/
   mv run_skills.py legacy/
   mv entrypoint.sh legacy/
   ```

## Support Timeline

- **2026-03-07**: Deprecated (this date)
- **2026-04-07**: Warning added to legacy files (1 month)
- **2026-05-07**: Legacy approach unsupported (2 months)
- **2026-06-07**: Files removed from repository (3 months)

## Questions?

See the main [README.md](../README.md) or [MIGRATION_PLAN.md](../MIGRATION_PLAN.md) for details on the new DevContainer approach.

For issues with migration, open a GitHub issue with:
- Description of what you're trying to do
- Error messages or unexpected behavior
- Steps to reproduce
