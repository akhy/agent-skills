---
name: agent-friendly-cli
description: Author or audit AI agent-friendly CLI tools. Use when creating a new CLI, reviewing an existing CLI for agent compatibility, or deciding between CLI and MCP. Keywords: cli, command-line, agent, ai, structured output, json, exit codes, idempotent, dry-run, audit, review.
metadata:
  {
    "author": "akhy",
    "version": "1.0.0",
    "openclaw":
      {
        "emoji": "🤖",
        "homepage": "https://github.com/akhy/agent-skills",
        "requires": { "bins": [] },
        "install": [],
      },
  }
---

# Agent-Friendly CLI Skill

Two modes: **Create** (new CLI) and **Audit** (existing CLI).

---

## Mode: Audit

When given an existing CLI, evaluate it against each requirement below. For each item report: ✅ pass, ❌ fail, or ⚠️ partial — and give a concrete fix for every non-pass.

Present findings as a prioritized list (blockers first, then improvements).

---

## Mode: Create

When asked to build a new CLI, apply all requirements below from the start. Remind the user of the CLI vs. MCP decision before writing code.

---

## CLI vs. MCP Decision

**Choose CLI when:**
- Fewer than ~15 commands
- Stateless operations
- Agent has shell access
- Token budget matters (MCP adds ambient cost in system prompt)

**Choose MCP when:**
- 50+ tools behind one server
- Stateful sessions needed
- No shell access for agent
- Multi-agent systems

---

## Requirements

### 1. Structured Output

- `--json` flag outputs machine-readable JSON to **stdout**
- In `--json` mode: all warnings, progress, and human text go to **stderr** so stdout stays parseable
- In normal (human) mode: output goes to **stdout** as usual
- Keep output flat over nested — easier to parse reliably
- Consistent field types across all commands: timestamps in ISO 8601, durations in seconds

```
# Human mode — rich output to stdout
$ mytool list
┌─────┬──────┐
│ ID  │ Name │
└─────┴──────┘

# Machine mode — clean JSON to stdout, any warnings to stderr
$ mytool list --json
[{"id":"abc","name":"foo","created_at":"2025-01-01T00:00:00Z"}]
```

### 2. Exit Codes

Agents use `$?` for control flow. Use meaningful codes:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General failure |
| 2 | Usage error (bad arguments) |
| 3 | Resource not found |
| 4 | Permission denied |
| 5 | Conflict (resource already exists) |

### 3. Idempotency

- Design commands safe to retry: prefer `ensure`/`upsert` semantics over `create`
- Or support `--if-not-exists` to turn conflict into a no-op
- If idempotency isn't possible, return exit code `5` on conflict so agents can handle it

### 4. Self-Documenting Help

- `--help` includes realistic examples for every command
- Required vs. optional flags are clearly marked
- `--json` is documented prominently
- Use hierarchical `noun verb` pattern: `tool resource action` (e.g. `docker container ls`, not `docker-container-ls`)

### 5. Composability & Piping

- `--quiet` / `-q` for bare output (one item per line, no decoration) — pipe-friendly
- `--output json` with optional `--fields id,name` to limit response size
- Batch operations via `--selector` or repeated args instead of requiring 50 individual calls

### 6. Dry-Run & No-Prompt Modes

- `--dry-run` produces structured output showing what *would* change — nothing is mutated
- `--yes` / `--force` bypasses all interactive prompts (agents cannot type "y")
- Detect non-TTY (`!isatty(stdin)`) and either skip prompts automatically or fail fast with a clear message pointing to `--yes`

### 7. Actionable Error Messages

Include in structured error output:
- `error_code` / `error_type` (not just `"Error: deployment failed"`)
- The failing input echoed back, so agents can construct a fix
- Suggested next step where applicable
- Whether the error is **transient** (safe to retry) or **permanent** (give up)

```json
{
  "error": "resource_not_found",
  "message": "Project 'staging' does not exist",
  "input": {"project": "staging"},
  "suggestion": "Run 'mytool project list' to see available projects",
  "retryable": false
}
```

### 8. Input Hardening

Agents hallucinate in ways humans don't:

- Validate file paths — reject traversals (`../../.ssh`)
- Reject control characters and shell-special characters in IDs/names
- Validate resource IDs — reject `?`, `#`, `%`, URL-encoded sequences
- Guard against double-encoding (`%2520` → `%20` → ` `)

---

## Checklist (quick reference)

```
[ ] --json flag outputs to stdout; warnings/progress to stderr only in --json mode
[ ] Meaningful exit codes (0–5 minimum)
[ ] Idempotent operations or clear conflict handling (exit 5)
[ ] --help with realistic examples per command
[ ] --dry-run for destructive/mutating commands
[ ] --yes/--force to bypass all prompts
[ ] Non-TTY detection (auto-skip prompts or fail + hint)
[ ] --quiet/-q for bare pipe-friendly output
[ ] Consistent field names and types across commands
[ ] Noun-verb command hierarchy
[ ] Structured error with error_code, input, suggestion, retryable
[ ] Batch operations for bulk work
[ ] Input validation (paths, IDs, encoding)
```

---

## Note on Design Philosophy

Most CLIs are subtly hostile to agents. The goal isn't a rewrite — it's layering agent-friendly patterns on top of human-friendly ones. Support both paths in the same binary: rich tables for humans when stdout is a TTY, clean JSON when it isn't.
