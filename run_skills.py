"""
run_skills.py — Parallel Claude skill runner.

Reads config.yml for api key, model, targets, and runner settings.
Skills run directly against configured project directories — no sandboxes.

entrypoint.sh has already copied CLAUDE.md and .claude/ into each project
directory, so Claude finds everything it needs at the project root.

Skills write output to .analysis/<language>/ inside each project directory.
This namespace prevents parallel skill runs from conflicting with each other.

Duplicate skills listed for the same directory are skipped — each (dir, skill)
pair runs exactly once.

All logs and results are written to <workdir>/logs/.
"""

import asyncio
import json
import logging
import os
import sys
import time
import uuid
from argparse import ArgumentParser
from datetime import datetime
from pathlib import Path

import yaml
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

def _make_logger(name: str, log_file: Path) -> logging.Logger:
    log_file.parent.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    logger.propagate = False

    fh = logging.FileHandler(log_file)
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(logging.Formatter(
        "%(asctime)s [%(levelname)-5s] %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%SZ",
    ))
    logger.addHandler(fh)

    sh = logging.StreamHandler(sys.stdout)
    sh.setLevel(logging.INFO)
    sh.setFormatter(logging.Formatter(
        f"[%(asctime)s] [{name}] %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(sh)
    return logger


def orchestrator_logger(log_dir: Path) -> logging.Logger:
    """
    Create orchestrator logger that only writes to stdout (not to a separate file).

    Rationale: The orchestrator output is already captured by docker logs via stdout,
    so creating a separate python_{ts}.log file would be redundant. Task-specific
    logs are still written to individual task_{name}_{ts}_{uid}.log files.
    """
    logger = logging.getLogger("orchestrator")
    logger.setLevel(logging.DEBUG)
    logger.propagate = False

    # Only add stdout handler (no file handler)
    sh = logging.StreamHandler(sys.stdout)
    sh.setLevel(logging.INFO)
    sh.setFormatter(logging.Formatter(
        "[%(asctime)s] [orchestrator] %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(sh)

    return logger


def task_logger(log_dir: Path, dir_name: str, skill: str) -> logging.Logger:
    safe = skill.lstrip("/").replace("/", "_")
    ts   = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    uid  = uuid.uuid4().hex[:8]  # Short UUID to prevent collisions
    name = f"{dir_name}__{safe}"
    return _make_logger(name, log_dir / f"task_{name}_{ts}_{uid}.log")


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config(config_path: Path, workdir: Path,
                orch: logging.Logger) -> tuple[str, dict, bool, list[tuple[Path, str]]]:
    if not config_path.exists():
        sys.exit(f"ERROR: config file not found: {config_path}")

    with config_path.open() as f:
        cfg = yaml.safe_load(f)

    if not isinstance(cfg, dict):
        sys.exit("ERROR: config.yml must be a YAML mapping.")

    # Load API key from environment
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        sys.exit("ERROR: ANTHROPIC_API_KEY environment variable is not set. "
                 "Please set it in your .env file (see .env.example).")

    runner      = cfg.get("runner", {})
    debug_cfg   = cfg.get("debug", {})
    debug_mode  = bool(debug_cfg.get("enabled", False))
    targets     = cfg.get("targets", [])
    if not targets:
        sys.exit("ERROR: targets missing or empty in config.yml.")

    # Build a structure: {project_dir: [skill1, skill2, ...]}
    project_skills: dict[Path, list[str]] = {}
    errors: list[str] = []

    for entry in targets:
        dir_name = str(entry.get("dir", "")).strip()
        skills   = entry.get("skills", [])

        if not dir_name:
            errors.append("A target entry is missing 'dir'.")
            continue

        project_dir = workdir / dir_name
        if not project_dir.is_dir():
            errors.append(f"Directory not found: {project_dir}")
            continue

        if not skills:
            errors.append(f"Target '{dir_name}' has no skills listed.")
            continue

        # Deduplicate skills for this directory, preserving order
        seen: set[str] = set()
        validated_skills: list[str] = []
        for skill in skills:
            skill = str(skill).strip()
            if not skill.startswith("/"):
                errors.append(f"Skill '{skill}' in '{dir_name}' must start with '/'.")
                continue
            if skill in seen:
                errors.append(f"Duplicate skill '{skill}' in '{dir_name}'. Remove duplicate entries from config.yml.")
                continue
            seen.add(skill)
            validated_skills.append(skill)

        if validated_skills:
            project_skills[project_dir] = validated_skills

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    # =========================================================================
    # Breadth-First Task Ordering
    # =========================================================================
    # Rationale: Breadth-first execution ensures fair resource sharing across
    # all projects when running with concurrency > 1.
    #
    # Example with 3 projects and concurrency=3:
    #   Breadth-first (current):
    #     1. proj-A skill-1 | proj-B skill-1 | proj-C skill-1  (all start together)
    #     2. proj-A skill-2 | proj-B skill-2 | proj-C skill-2
    #
    #   Depth-first (alternative):
    #     1. proj-A skill-1 | proj-A skill-2 | proj-A skill-3  (proj-B/C wait)
    #     2. proj-B skill-1 | proj-B skill-2 | proj-C skill-1
    #
    # Benefits:
    # - Better resource utilization when some skills are slower than others
    # - All projects get attention early in the run (better UX)
    # - Prevents one large project from monopolizing all worker slots
    # =========================================================================
    tasks: list[tuple[Path, str]] = []

    # Find the maximum number of skills across all projects
    max_skills = max(len(skills) for skills in project_skills.values()) if project_skills else 0

    # Sort projects by name for deterministic, consistent ordering
    sorted_projects = sorted(project_skills.items(), key=lambda x: x[0].name)

    # Iterate skill-by-skill (breadth-first): all projects run skill 1, then all run skill 2, etc.
    for skill_index in range(max_skills):
        for project_dir, skills in sorted_projects:
            if skill_index < len(skills):
                tasks.append((project_dir, skills[skill_index]))

    orch.info(f"Task ordering: breadth-first (all projects run skill 1, then skill 2, etc.)")

    return api_key, runner, debug_mode, tasks


# ---------------------------------------------------------------------------
# SDK streaming
# ---------------------------------------------------------------------------

class RateLimitError(Exception):
    pass


def _is_rate_limit(exc: Exception) -> bool:
    msg = str(exc).lower()
    return "rate_limit" in msg or "429" in msg or "too many requests" in msg


async def stream_skill(skill: str, project_dir: Path, model: str,
                       max_turns: int, max_budget_usd: float,
                       logger: logging.Logger, debug_mode: bool = False) -> str:
    try:
        from claude_agent_sdk import query, ClaudeAgentOptions
    except ImportError:
        raise RuntimeError("claude_agent_sdk not installed — pip install claude-agent-sdk")

    # Prepare environment variables for skills/agents
    # DEBUG_MODE allows skills and agents to enable verbose logging conditionally
    debug_env = {
        "DEBUG_MODE": "true" if debug_mode else "false",
    }

    # SDK stderr callback - always capture
    def handle_sdk_stderr(line: str) -> None:
        logger.error(f"[SDK] {line}")

    options = ClaudeAgentOptions(
        model=model,
        max_turns=max_turns,
        setting_sources=["project"],  # Loads skills from .claude/ directory
        cwd=str(project_dir),
        env=debug_env,  # Pass debug environment to skills/agents
        stderr=handle_sdk_stderr,  # Capture SDK diagnostics
        allowed_tools=[
            "Skill",        # CRITICAL: Required to invoke skills
            "Task",         # For launching specialized agents
            "Read",         # File reading
            "Write",        # File writing
            "Edit",         # File editing
            "Bash",         # Shell commands
            "Grep",         # Code search
            "Glob",         # File pattern matching
            "TodoWrite",    # Task tracking
            "WebFetch",     # Web content fetching
            "WebSearch",    # Web searching
            "NotebookEdit", # Jupyter notebook editing
        ],
        permission_mode='bypassPermissions',  # Hardcoded for autonomous Docker operation
        max_budget_usd=max_budget_usd,
    )

    result_text = ""
    try:
        # Pass the skill invocation command (e.g., "/audit-java")
        # Claude will recognize the slash command and load the skill from .claude/skills/
        async for msg in query(prompt=skill, options=options):
            t = getattr(msg, "type", "")
            if t == "system" and getattr(msg, "subtype", "") == "init":
                logger.info(f"Session started  id={getattr(msg, 'session_id', '')}")
            elif t == "assistant":
                content = getattr(msg, "message", "") or getattr(msg, "content", "")
                if content:
                    # Debug mode: log full message. Normal mode: truncate to 500 chars
                    if debug_mode:
                        logger.info(f"[assistant] {str(content)}")
                    else:
                        logger.info(f"[assistant] {str(content)[:500]}")
            elif t == "tool_use":
                # Debug mode: log full input. Normal mode: truncate to 200 chars
                tool_input = json.dumps(getattr(msg, 'input', {}))
                if debug_mode:
                    logger.debug(f"[tool] {getattr(msg, 'name', '')}  {tool_input}")
                else:
                    logger.debug(f"[tool] {getattr(msg, 'name', '')}  {tool_input[:200]}")
            elif t == "tool_result":
                # Debug mode: log full result. Normal mode: truncate to 200 chars
                tool_result = str(getattr(msg, 'content', ''))
                if debug_mode:
                    logger.debug(f"[tool_result] {tool_result}")
                else:
                    logger.debug(f"[tool_result] {tool_result[:200]}")
            elif t == "result":
                result_text = getattr(msg, "result", "")
                # Debug mode: log full result. Normal mode: truncate to 800 chars
                if debug_mode:
                    logger.info(f"[result] {str(result_text)}")
                else:
                    logger.info(f"[result] {str(result_text)[:800]}")
            elif t == "error":
                # ALWAYS log full error message (never truncate errors)
                error_msg = getattr(msg, "error", str(msg))
                logger.error(f"SDK Error: {error_msg}")
                raise RuntimeError(error_msg)
    except Exception as exc:
        if _is_rate_limit(exc):
            raise RateLimitError(str(exc)) from exc
        raise

    return result_text


# ---------------------------------------------------------------------------
# Single task
# ---------------------------------------------------------------------------

async def run_one(*, project_dir: Path, skill: str, model: str, max_turns: int,
                  timeout: int, max_budget_usd: float,
                  semaphore: asyncio.Semaphore, log_dir: Path,
                  orch: logging.Logger, debug_mode: bool = False) -> dict:

    dir_name   = project_dir.name
    safe_skill = skill.lstrip("/").replace("/", "_")
    task_id    = f"{dir_name}:{skill}"
    logger     = task_logger(log_dir, dir_name, skill)
    start      = time.monotonic()

    result = {
        "dir": dir_name, "skill": skill,
        "status": "pending", "duration_s": 0.0,
        "result_file": None, "error": None,
    }

    async with semaphore:
        orch.info(f"START    {task_id}")
        logger.info(f"=== START  dir={project_dir}  skill={skill}  model={model} ===")

        try:
            @retry(
                retry=retry_if_exception_type(RateLimitError),
                wait=wait_exponential(multiplier=2, min=10, max=120),
                stop=stop_after_attempt(6),
                before_sleep=before_sleep_log(logger, logging.WARNING),
                reraise=True,
            )
            async def _run():
                return await stream_skill(skill, project_dir, model, max_turns,
                                         max_budget_usd, logger, debug_mode)

            result_text = await asyncio.wait_for(_run(), timeout=timeout)

            ts          = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            uid         = uuid.uuid4().hex[:8]  # Short UUID to prevent collisions
            result_file = log_dir / f"result_{dir_name}__{safe_skill}_{ts}_{uid}.txt"
            result_file.write_text(result_text or "(no result text returned)")
            result.update(status="success", result_file=str(result_file))

            elapsed = round(time.monotonic() - start, 1)
            logger.info(f"=== DONE  → {result_file.name} ===")
            orch.info(f"OK       {task_id}  ({elapsed}s)  → {result_file.name}")

        except asyncio.TimeoutError:
            result.update(status="timeout", error=f"Exceeded {timeout}s")
            logger.error(f"Timed out after {timeout}s")
            orch.warning(f"TIMEOUT  {task_id}")

        except Exception as exc:
            # ALWAYS log full error with context (never truncate)
            error_context = f"Task: {task_id}, Project: {project_dir}, Skill: {skill}"
            result.update(status="error", error=str(exc))
            logger.error(f"Failed: {exc}\nContext: {error_context}", exc_info=True)
            orch.error(f"FAIL     {task_id}  {exc}")

        finally:
            result["duration_s"] = round(time.monotonic() - start, 2)

    return result


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

async def run_all(*, tasks: list[tuple[Path, str]], model: str, max_turns: int,
                  timeout: int, max_budget_usd: float,
                  concurrency: int, log_dir: Path, orch: logging.Logger,
                  debug_mode: bool = False) -> list[dict]:

    semaphore = asyncio.Semaphore(concurrency)
    orch.info(f"Tasks: {len(tasks)}  concurrency: {concurrency}  model: {model}")
    for d, s in tasks:
        orch.info(f"  QUEUED  {d.name}:{s}")

    return list(await asyncio.gather(*[
        run_one(
            project_dir=d,
            skill=s,
            model=model,
            max_turns=max_turns,
            timeout=timeout,
            max_budget_usd=max_budget_usd,
            semaphore=semaphore,
            log_dir=log_dir,
            orch=orch,
            debug_mode=debug_mode,
        )
        for d, s in tasks
    ]))


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

def write_summary(results: list[dict], log_dir: Path, orch: logging.Logger) -> None:
    total   = len(results)
    success = sum(1 for r in results if r["status"] == "success")
    failed  = total - success

    lines = ["", "=" * 64,
             f"  RESULTS   total={total}   success={success}   failed={failed}",
             "=" * 64]
    for r in results:
        icon  = {"success": "OK     ", "error": "FAIL   ", "timeout": "TIMEOUT"}.get(r["status"], "?      ")
        extra = f"  → {r['error']}" if r["error"] else \
                f"  → {Path(r['result_file']).name}" if r["result_file"] else ""
        lines.append(f"  {icon}  {r['dir']}:{r['skill']}  ({r['duration_s']}s){extra}")
    lines += ["=" * 64, ""]
    text = "\n".join(lines)
    print(text)

    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    (log_dir / f"summary_{ts}.txt").write_text(text)
    (log_dir / f"summary_{ts}.json").write_text(json.dumps(results, indent=2))
    orch.info(f"Summary → {log_dir}/summary_{ts}.[txt|json]")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    p = ArgumentParser()
    p.add_argument("--audit-base-dir", default="/workdir",
                   help="Parent directory containing config.yml, CLAUDE.md, .claude/, and project directories")
    p.add_argument("--config",  default=None)
    args = p.parse_args()

    workdir     = Path(args.audit_base_dir)
    config_path = Path(args.config) if args.config else workdir / "config.yml"
    log_dir     = workdir / "logs"

    log_dir.mkdir(parents=True, exist_ok=True)
    orch = orchestrator_logger(log_dir)

    orch.info(f"config          = {config_path}")
    orch.info(f"audit_base_dir  = {workdir}")

    api_key, runner, debug_mode, tasks = load_config(config_path, workdir, orch)
    os.environ["ANTHROPIC_API_KEY"] = api_key

    model           = str(runner.get("model",           "claude-sonnet-4-6"))
    concurrency     = int(runner.get("concurrency",     3))
    max_turns       = int(runner.get("max_turns",       20))
    timeout         = int(runner.get("timeout",         300))
    max_budget_usd  = float(runner.get("max_budget_usd", 10.0))

    orch.info(f"model           = {model}")
    orch.info(f"concurrency     = {concurrency}")
    orch.info(f"max_turns       = {max_turns}")
    orch.info(f"timeout         = {timeout}s")
    orch.info(f"max_budget_usd  = ${max_budget_usd}")
    orch.info(f"permission_mode = bypassPermissions (hardcoded)")
    orch.info(f"debug_mode      = {debug_mode}")

    results = asyncio.run(run_all(
        tasks=tasks, model=model, max_turns=max_turns, timeout=timeout,
        max_budget_usd=max_budget_usd, concurrency=concurrency,
        log_dir=log_dir, orch=orch, debug_mode=debug_mode,
    ))

    write_summary(results, log_dir, orch)

    if any(r["status"] != "success" for r in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
