<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
name: coding-agent-orchestration
description: "Pick coding-agent execution mode and recover from failures."
version: 0.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [orchestration, agents, delegation, automation]
---

# Coding Agent Orchestration

Use this skill whenever you launch a background coding or automation agent and must interact with it while it runs, or when you are choosing between running a coding agent directly versus delegating the work.

## When to Use

- You started a background coding-agent session and need to send input, monitor progress, or recover if it stops responding.
- A bounded non-coding or host-setup task was incorrectly routed through a coding agent.
- You need to decide between `opencode`, `delegate_task`, or direct `terminal` commands for a given job.

## Decision Rules

| Task shape | Preferred path |
|---|---|
| Bounded, non-interactive, code-focused | `opencode run '...'` from `terminal` |
| Iterative, needs multiple exchanges | Background TUI + `process_manage` or `delegate_task` |
| Non-coding host/setup/install | `terminal` commands or `delegate_task` unless the user explicitly requests the coding agent |
| Long task with defined end | `terminal(background=true, notify=true)` or `delegate_task` |

## Host Setup / Diagnostic Task Routing

For host-level setup and diagnosis—Waydroid, LXC, firewall, kernel config, package install—prefer **direct `terminal` commands** or **`delegate_task` with a required output schema**. Do **not** route these through an interactive OpenCode TUI unless the user explicitly asks for it; TUI sessions have no reliable non-interactive input path and will stall on prompts.

Use `delegate_task` when:
- The task needs verifiable artifacts (reports, config patches, status summaries).
- You want parallel tracks (A/B/C/D) with independent deliverables.
- The work involves sudo/service restarts and you need bounded execution.

Use direct `terminal` when:
- You need immediate verification after each command.
- The task is a small number of deterministic steps.
- You need to inspect live state (`status`, `journalctl`, `nft`, `lxc-info`) between steps.

## Recovery Pattern

If a background coding agent:
- cannot complete because input is required,
- shows an agent selector instead of accepting your input,
- times out while waiting for you to interact,

Then:
1. Stop forcing raw TUI input.
2. Prefer `delegate_task` with an explicit self-contained goal, required output schema, and verification instructions.
3. If you must keep the original process, use the live control surface instead of reissuing assumed commands (`process_manage poll/log/write/submit/kill`).

## Tool Discovery Fallback

If a needed tool is not in the directly listed tool set:
1. Use `tool_search` to locate it.
2. Use `tool_describe` to load its parameter schema.
3. Use `tool_call` to invoke it.
Do not claim a tool is unavailable after only one failed lookup.

## Pitfalls

- Do not start an interactive background coding agent for a task that has no clear interactive input path; it will stall.
- Do not assume commands from one Hermes surface work on another; verify available tools before relying on them.
- Do not retry the same control path after it fails; switch representation or execution mode instead.
- `/exit` is not a valid OpenCode command and will open an agent selector dialog instead; use Ctrl+C (`\x03`) or `process_manage(action='kill')` to exit.
- For non-coding host setup tasks, prefer `delegate_task` with a required output schema over interactive TUI; it yields verifiable artifacts and avoids TUI input dead ends.
- When a direct tool call fails with "Tool 'X' does not exist", search for the tool before switching strategies; many deferred tools are discoverable via `tool_search`.
- **Empty response after tool calls** — if the assistant returns nothing after tool results, the results were not processed. Re-check the tool output and respond to it explicitly; do not re-execute the same tool calls hoping for different output. This is the most common stall pattern in session logs.
- **Subagent HTTP 429 rate limits** — when subagents fail with rate-limit errors, check `manifest.json` for per-task status, re-dispatch only the failed tasks (not the full batch), and wait ~60s before retrying. Batch re-dispatch of all tasks wastes the rate-limit budget.
- **search_files intermittent failures** — when `search_files` fails more than twice with the same error on a broad search (especially above the user home), fall back to `terminal` with `find` / `grep` instead of retrying. `search_files` uses ripgrep and can fail on broad globs or permission-denied cascades; `terminal find` is deterministic.
- **Verify paths before dispatching subagents** — before spawning subagents to a directory, verify it exists with `ls` or `terminal find`. Subagents dispatched to non-existent paths waste tokens and return misleading 'file not found' errors that look like the task failed rather than a bad path.