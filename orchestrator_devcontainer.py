#!/usr/bin/env python3
"""
orchestrator_devcontainer.py — DevContainer-native parallel skill runner

Replaces run_skills.py with devcontainer-first architecture:
- Builds image from .devcontainer/Dockerfile (or uses cache)
- Spawns N isolated containers (one per project+skill combination)
- Shares framework configs via read-only volume mounts
- Collects outputs to centralized logs directory

Usage:
    python orchestrator_devcontainer.py

Environment variables:
    AUDIT_BASE_DIR       - Path to audit workspace (default: current directory)
    ANTHROPIC_API_KEY    - Claude API key (required)
    FORCE_REBUILD        - Force image rebuild (default: false)
"""

import asyncio
import json
import logging
import os
import signal
import subprocess
import sys
import uuid
from argparse import ArgumentParser
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

import aiodocker
import yaml
from dotenv import load_dotenv

# Load .env file if it exists
load_dotenv()


# =============================================================================
# Configuration
# =============================================================================

def load_config(config_path: Path, audit_base_dir: Path) -> Dict[str, Any]:
    """Load and validate config.yml"""

    if not config_path.exists():
        sys.exit(f"ERROR: config file not found: {config_path}")

    with config_path.open() as f:
        cfg = yaml.safe_load(f)

    # Validate required fields
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        sys.exit("ERROR: ANTHROPIC_API_KEY environment variable is not set.")

    runner = cfg.get("runner", {})
    debug_cfg = cfg.get("debug", {})

    # Debug mode: read from config.yml only
    debug_mode = debug_cfg.get("enabled", False)

    force_rebuild = os.environ.get("FORCE_REBUILD", "false").lower() == "true"
    targets = cfg.get("targets", [])

    if not targets:
        sys.exit("ERROR: targets missing or empty in config.yml.")

    return {
        "api_key": api_key,
        "audit_base_dir": str(audit_base_dir),
        "model": runner.get("model", "claude-sonnet-4-6"),
        "concurrency": int(runner.get("concurrency", 3)),
        "timeout": int(runner.get("timeout", 300)),
        "image_tag": runner.get("image_tag", "audit-runner:local"),
        "debug_mode": debug_mode,
        "force_rebuild": force_rebuild,
        "targets": targets,
    }


# =============================================================================
# Image Building
# =============================================================================

async def ensure_image_built(docker: aiodocker.Docker, config: Dict[str, Any], repo_root: Path, logger: logging.Logger) -> str:
    """Build devcontainer image from Dockerfile if not exists or if force rebuild"""

    image_tag = config['image_tag']
    force_rebuild = config['force_rebuild']

    # Check if image exists (unless force rebuild)
    if not force_rebuild:
        try:
            await docker.images.inspect(image_tag)
            logger.info(f"Image {image_tag} exists (using cache)")
            return image_tag
        except aiodocker.exceptions.DockerError:
            logger.info(f"Image {image_tag} not found, building from Dockerfile...")
    else:
        logger.info(f"Force rebuild requested, building {image_tag} from Dockerfile...")

    # Build from .devcontainer/Dockerfile using Docker CLI
    logger.info(f"Building image from {repo_root}/.devcontainer/Dockerfile")
    logger.info("This may take 10-15 minutes on first build (subsequent builds ~30s)")

    dockerfile_path = repo_root / '.devcontainer' / 'Dockerfile'

    # Build command
    cmd = [
        'docker', 'build',
        '-f', str(dockerfile_path),
        '-t', image_tag,
        '--rm',
        str(repo_root)  # Build context
    ]

    if config['debug_mode']:
        logger.debug(f"  Build command: {' '.join(cmd)}")

    # Run docker build with real-time output streaming
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )

        # Stream output line by line
        try:
            for line in process.stdout:
                line = line.rstrip()
                if line:
                    logger.info(f"  {line}")
        except KeyboardInterrupt:
            logger.warning("Build interrupted by user")
            process.terminate()
            process.wait(timeout=5)
            raise

        # Wait for completion
        returncode = process.wait()

        if returncode == 130:
            # Build was cancelled (Ctrl-C)
            raise KeyboardInterrupt("Build cancelled by user")
        elif returncode != 0:
            sys.exit(f"ERROR: Docker build failed with exit code {returncode}")

        logger.info(f"Image {image_tag} built successfully")

    except FileNotFoundError:
        sys.exit("ERROR: 'docker' command not found. Is Docker installed and in PATH?")
    except KeyboardInterrupt:
        raise  # Re-raise to be caught by main
    except Exception as e:
        sys.exit(f"ERROR: Failed to build image: {e}")

    return image_tag


# =============================================================================
# Container Runner
# =============================================================================

def cleanup_project_claude_configs(project_path: Path, logger: logging.Logger) -> None:
    """
    Rename any existing .claude/, .analysis/ directories and CLAUDE.md files
    in the target project to prevent conflicts.

    This ensures:
    - Claude Code uses the framework's mounted .claude/ directory
    - Each audit run gets a fresh .analysis/ directory

    Renamed files/directories:
    - .claude/          → OLD-.claude/ (or OLD-.claude)
    - CLAUDE.md         → OLD-CLAUDE.md (or OLD-CLAUDE.md)
    - CLAUDE.local.md   → OLD-CLAUDE.local.md (or OLD-CLAUDE.local.md)
    - .analysis/        → .analysis-{timestamp}/
    """

    renamed_items = []
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Check and rename .analysis/ directory (always use timestamp for fresh runs)
    analysis_dir = project_path / ".analysis"
    if analysis_dir.exists() and analysis_dir.is_dir():
        archived_analysis_dir = project_path / f".analysis-{timestamp}"
        analysis_dir.rename(archived_analysis_dir)
        renamed_items.append(f".analysis/ → {archived_analysis_dir.name}")

    # Check and rename .claude/ directory
    claude_dir = project_path / ".claude"
    if claude_dir.exists() and claude_dir.is_dir():
        old_claude_dir = project_path / "OLD-.claude"
        # If OLD-.claude already exists, add timestamp to avoid collision
        if old_claude_dir.exists():
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            old_claude_dir = project_path / f"OLD-.claude.{timestamp}"
        claude_dir.rename(old_claude_dir)
        renamed_items.append(f".claude/ → {old_claude_dir.name}")

    # Check and rename CLAUDE.md
    claude_md = project_path / "CLAUDE.md"
    if claude_md.exists() and claude_md.is_file():
        old_claude_md = project_path / "OLD-CLAUDE.md"
        # If OLD-CLAUDE.md already exists, add timestamp
        if old_claude_md.exists():
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            old_claude_md = project_path / f"OLD-CLAUDE.md.{timestamp}"
        claude_md.rename(old_claude_md)
        renamed_items.append(f"CLAUDE.md → {old_claude_md.name}")

    # Check and rename CLAUDE.local.md
    claude_local_md = project_path / "CLAUDE.local.md"
    if claude_local_md.exists() and claude_local_md.is_file():
        old_claude_local_md = project_path / "OLD-CLAUDE.local.md"
        # If OLD-CLAUDE.local.md already exists, add timestamp
        if old_claude_local_md.exists():
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            old_claude_local_md = project_path / f"OLD-CLAUDE.local.md.{timestamp}"
        claude_local_md.rename(old_claude_local_md)
        renamed_items.append(f"CLAUDE.local.md → {old_claude_local_md.name}")

    if renamed_items:
        logger.info(f"  Renamed existing Claude configs in {project_path.name}:")
        for item in renamed_items:
            logger.info(f"    - {item}")
    else:
        logger.debug(f"  No existing Claude configs found in {project_path.name}")


async def run_skill_container(
    docker: aiodocker.Docker,
    project_dir: str,
    skill: str,
    config: Dict[str, Any],
    repo_root: Path,
    logger: logging.Logger,
) -> Dict[str, Any]:
    """
    Run a single devcontainer for one project+skill combination.

    Each container:
    - Is fully isolated (separate container instance)
    - Shares .claude/ via read-only mount
    - Has exclusive write access to its .analysis/ directory
    - Writes logs to shared /workspace/logs with unique filenames
    """

    task_id = f"{project_dir}:{skill}"
    container_name = f"audit-{project_dir}-{skill.lstrip('/')}".replace("/", "-").replace("_", "-")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    uid = uuid.uuid4().hex[:8]

    logger.info(f"START    {task_id}")

    start_time = asyncio.get_event_loop().time()

    result = {
        "project": project_dir,
        "skill": skill,
        "status": "pending",
        "duration_s": 0.0,
        "exit_code": None,
        "log_file": None,
        "result_file": None,
        "error": None,
    }

    audit_base_dir = Path(config['audit_base_dir'])
    project_path = audit_base_dir / project_dir

    # Validate project directory exists
    if not project_path.exists():
        error_msg = f"Project directory not found: {project_path}"
        logger.error(f"FAIL     {task_id}  {error_msg}")
        result.update(status="error", error=error_msg)
        return result

    # Clean up any existing Claude configs in the target project
    # This prevents conflicts with the framework's mounted .claude/ directory
    if config['debug_mode']:
        logger.debug(f"  Checking for existing Claude configs in: {project_path}")
    cleanup_project_claude_configs(project_path, logger)

    # Create log directory and .analysis directory
    log_dir = audit_base_dir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    analysis_dir = project_path / ".analysis"
    analysis_dir.mkdir(parents=True, exist_ok=True)

    log_file = log_dir / f"task_{project_dir}__{skill.lstrip('/')}_{timestamp}_{uid}.log"
    result_file = log_dir / f"result_{project_dir}__{skill.lstrip('/')}_{timestamp}_{uid}.txt"

    try:
        # Container configuration
        # Note: Using direct Docker SDK (aiodocker) rather than devcontainer CLI
        # because we need programmatic control over N parallel containers
        container_config = {
            "Image": config['image_tag'],
            "Cmd": [skill],  # Pass skill as command-line arg to entrypoint
            "WorkingDir": "/workspace",
            "Env": [
                f"ANTHROPIC_API_KEY={config['api_key']}",
                f"SKILL_NAME={skill}",
                f"ANTHROPIC_MODEL={config['model']}",
                f"DEBUG_MODE={'true' if config['debug_mode'] else 'false'}",
                f"TASK_TIMESTAMP={timestamp}",
                f"TASK_UID={uid}",
                # Devcontainer environment variables
                f"NODE_OPTIONS=--max-old-space-size=4096",
                f"CLAUDE_CONFIG_DIR=/home/node/.claude",
                f"DEVCONTAINER=true",
            ],
            "HostConfig": {
                "Binds": [
                    # Framework configs (read-only, shared across all containers)
                    f"{repo_root}/.claude:/workspace/.claude:ro",

                    # Project source (read-write for now, could be ro later)
                    f"{project_path}:/workspace/{project_dir}:rw",

                    # Output directories (read-write, isolated per project)
                    f"{analysis_dir}:/workspace/{project_dir}/.analysis:rw",
                    f"{log_dir}:/workspace/logs:rw",
                ],
                "Memory": 4 * 1024 * 1024 * 1024,  # 4GB
                "AutoRemove": False,  # We'll remove manually after collecting logs
                "CapAdd": ["NET_ADMIN", "NET_RAW"],  # For firewall
            },
            "name": container_name,
            "User": "node",  # Run as node user (matches Dockerfile)
        }

        logger.info(f"  Creating container: {container_name}")
        if config['debug_mode']:
            logger.debug(f"    Image: {config['image_tag']}")
            logger.debug(f"    Working dir: /workspace")
            logger.debug(f"    Memory limit: 4GB")
            logger.debug(f"    User: node")
            logger.debug(f"    Mounts:")
            for bind in container_config["HostConfig"]["Binds"]:
                logger.debug(f"      - {bind}")
            logger.debug(f"    Environment variables:")
            for env in container_config["Env"]:
                # Mask API key in logs
                if "ANTHROPIC_API_KEY" in env:
                    logger.debug(f"      - ANTHROPIC_API_KEY=***masked***")
                else:
                    logger.debug(f"      - {env}")

        # Create container
        container = await docker.containers.create(
            config=container_config,
            name=container_name
        )

        logger.info(f"  Starting container: {container_name}")

        # Start container
        await container.start()

        # Wait for completion (with timeout)
        try:
            exit_info = await asyncio.wait_for(
                container.wait(),
                timeout=config['timeout']
            )
            exit_code = exit_info['StatusCode']

        except asyncio.TimeoutError:
            logger.warning(f"TIMEOUT  {task_id}")
            await container.kill()
            result.update(status="timeout", error=f"Exceeded {config['timeout']}s")

            # Collect logs even after timeout
            logs = await container.log(stdout=True, stderr=True)
            log_content = ''.join(logs)
            log_file.write_text(log_content)

            # Cleanup
            await container.delete(force=True)

            elapsed = asyncio.get_event_loop().time() - start_time
            result["duration_s"] = round(elapsed, 2)
            result["log_file"] = str(log_file)

            return result

        # Collect logs
        logger.info(f"  Collecting logs from: {container_name}")
        logs = await container.log(stdout=True, stderr=True)
        log_content = ''.join(logs)

        # Write logs to centralized location
        log_file.write_text(log_content)

        # Check for result file (written by skill inside container)
        # Note: The entrypoint writes results, but we capture via logs
        # If skill produces output, it should be in the container logs

        if exit_code == 0:
            # Write a result marker file
            result_file.write_text(f"Skill completed successfully: {skill}\nProject: {project_dir}\nExit code: {exit_code}\n\nSee log file for details: {log_file.name}\n")

            result.update(
                status="success",
                exit_code=exit_code,
                log_file=str(log_file),
                result_file=str(result_file),
            )
            logger.info(f"OK       {task_id}  → {result_file.name}")
        else:
            result.update(
                status="error",
                exit_code=exit_code,
                log_file=str(log_file),
                error=f"Exit code {exit_code}",
            )
            logger.error(f"FAIL     {task_id}  (exit code {exit_code})")

        # Cleanup container
        logger.info(f"  Removing container: {container_name}")
        await container.delete(force=True)

    except Exception as exc:
        logger.error(f"FAIL     {task_id}  {exc}", exc_info=config['debug_mode'])
        result.update(status="error", error=str(exc))

    finally:
        elapsed = asyncio.get_event_loop().time() - start_time
        result["duration_s"] = round(elapsed, 2)

    return result


# =============================================================================
# Main Orchestrator
# =============================================================================

async def run_all(config: Dict[str, Any], repo_root: Path, logger: logging.Logger) -> List[Dict[str, Any]]:
    """Run all project+skill combinations in parallel"""

    docker = aiodocker.Docker()

    try:
        # Ensure image is built
        image_tag = await ensure_image_built(docker, config, repo_root, logger)
        logger.info(f"Using image: {image_tag}")

        # Generate tasks
        tasks = []
        for target in config['targets']:
            project_dir = target['dir']
            for skill in target['skills']:
                tasks.append((project_dir, skill))

        logger.info("")
        logger.info("=" * 64)
        logger.info(f"Tasks: {len(tasks)}  concurrency: {config['concurrency']}")
        logger.info("=" * 64)
        for project_dir, skill in tasks:
            logger.info(f"  QUEUED  {project_dir}:{skill}")
        logger.info("=" * 64)
        logger.info("")

        # Run with concurrency control
        semaphore = asyncio.Semaphore(config['concurrency'])

        async def bounded_task(project_dir: str, skill: str):
            async with semaphore:
                return await run_skill_container(docker, project_dir, skill, config, repo_root, logger)

        results = await asyncio.gather(*[
            bounded_task(project_dir, skill)
            for project_dir, skill in tasks
        ])

        return results

    finally:
        await docker.close()


def write_summary(results: List[Dict[str, Any]], log_dir: Path, logger: logging.Logger) -> None:
    """Write aggregated summary"""

    total = len(results)
    success = sum(1 for r in results if r["status"] == "success")
    failed = total - success

    lines = [
        "",
        "=" * 64,
        f"  RESULTS   total={total}   success={success}   failed={failed}",
        "=" * 64,
    ]

    for r in results:
        icon = {"success": "OK     ", "error": "FAIL   ", "timeout": "TIMEOUT"}.get(r["status"], "?      ")
        extra = f"  → {r['error']}" if r["error"] else \
                f"  → {Path(r['result_file']).name}" if r["result_file"] else ""
        lines.append(f"  {icon}  {r['project']}:{r['skill']}  ({r['duration_s']}s){extra}")

    lines += ["=" * 64, ""]
    text = "\n".join(lines)
    print(text)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    (log_dir / f"summary_{ts}.txt").write_text(text)
    (log_dir / f"summary_{ts}.json").write_text(json.dumps(results, indent=2))
    logger.info(f"Summary → {log_dir}/summary_{ts}.[txt|json]")


def main():
    parser = ArgumentParser(description="DevContainer-native parallel skill runner")
    parser.add_argument("--config", help="Path to config.yml (default: AUDIT_BASE_DIR/config.yml)")
    parser.add_argument("--audit-base-dir", help="Path to audit workspace (default: CWD or AUDIT_BASE_DIR env)")
    args = parser.parse_args()

    # Determine audit base directory
    if args.audit_base_dir:
        audit_base_dir = Path(args.audit_base_dir).resolve()
    elif os.environ.get("AUDIT_BASE_DIR"):
        audit_base_dir = Path(os.environ["AUDIT_BASE_DIR"]).resolve()
    else:
        audit_base_dir = Path.cwd()

    # Determine config path
    if args.config:
        config_path = Path(args.config)
    else:
        config_path = audit_base_dir / "config.yml"

    # Determine repo root (where .devcontainer/ lives)
    repo_root = Path(__file__).parent.resolve()

    # Load configuration
    config = load_config(config_path, audit_base_dir)

    log_dir = audit_base_dir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    # Setup logging (both console and file)
    log_level = logging.DEBUG if config['debug_mode'] else logging.INFO

    # Create orchestrator log file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    orchestrator_log_file = log_dir / f"orchestrator_{timestamp}.log"

    # Configure root logger
    logging.basicConfig(
        level=log_level,
        format="[%(asctime)s] [orchestrator] %(message)s",
        datefmt="%H:%M:%S",
        handlers=[
            logging.StreamHandler(),  # Console output
            logging.FileHandler(orchestrator_log_file, mode='w')  # File output
        ]
    )
    logger = logging.getLogger("orchestrator")

    logger.info(f"Orchestrator logs will be written to: {orchestrator_log_file}")

    logger.info("=" * 64)
    logger.info("DevContainer-Native Parallel Skill Runner")
    logger.info("=" * 64)
    logger.info(f"config          = {config_path}")
    logger.info(f"audit_base_dir  = {audit_base_dir}")
    logger.info(f"repo_root       = {repo_root}")
    logger.info(f"model           = {config['model']}")
    logger.info(f"concurrency     = {config['concurrency']}")
    logger.info(f"image_tag       = {config['image_tag']}")
    logger.info(f"debug_mode      = {config['debug_mode']}")
    logger.info(f"force_rebuild   = {config['force_rebuild']}")
    logger.info("=" * 64)
    logger.info("")

    # Run all tasks with graceful shutdown handling
    try:
        results = asyncio.run(run_all(config, repo_root, logger))

        # Write summary
        write_summary(results, log_dir, logger)

        # Exit with error if any tasks failed
        if any(r["status"] != "success" for r in results):
            sys.exit(1)

    except KeyboardInterrupt:
        logger.info("")
        logger.info("=" * 64)
        logger.info("Received interrupt signal (Ctrl-C)")
        logger.info("Shutting down gracefully...")
        logger.info("=" * 64)
        sys.exit(130)  # Standard exit code for SIGINT


if __name__ == "__main__":
    main()
