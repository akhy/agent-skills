---
name: omp-delegate
description: >-
  One-shot delegation of a task to OMP (Oh My Pi) via the `omp` CLI. Use when another
  agent needs to run a prompt in OMP without interactive terminal management.
  Triggers: "delegate to omp", "send to omp", "run in omp", "hand off to omp",
  "use omp-delegate".
metadata:
  {
    "author": "akhy",
    "version": "1.0.0",
    "openclaw":
      {
        "emoji": "🧬",
        "homepage": "https://github.com/akhy/agent-skills",
        "keywords": ["omp", "oh-my-pi", "delegate", "handoff", "agent", "task"],
        "requires": { "bins": ["omp"] },
        "install": [],
      },
  }
---

# OMP-Delegate

One-shot non-interactive delegation to OMP.

## Core Commands

**Fire-and-forget:**
```bash
omp -p "<prompt>" --no-session --mode json --thinking off
```

**Blocking** (waits for `agent_end`):
```bash
omp -p "<prompt>" --no-session --mode json --auto-approve 2>&1 | \
  jq -r 'select(.type == "agent_end") | .messages[] |
         select(.role == "assistant") | .content[] |
         select(.type == "text") | .text' | tail -1
echo "exit: $?"
```

> `--thinking off` suppresses TUI display only; thinking tokens are still generated.
> Stripping thinking from the output stream saves caller-side tokens, not model tokens.

**Token-saving** (strips all noisy events — use for high-volume delegation):
```bash
omp -p "<prompt>" --no-session --mode json --auto-approve 2>&1 | \
  jq -r 'select(.type == "agent_end") | .messages[] |
         select(.role == "assistant") | .content[] |
         select(.type == "text") | .text' | tail -1
```

## Multi-Shot (Retained Context)

```bash
# Call 1: create session
DIR=$(mktemp -d)
OUT=$(omp -p "<prompt A>" --session-dir "$DIR" --mode json --auto-approve 2>&1)
SID=$(echo "$OUT" | python3 -c "import sys,json; [print(json.loads(l).get('id','')) for l in sys.stdin if l.strip()]" | head -1)

# Calls 2..N: resume
omp -p "<prompt B>" --session-dir "$DIR" --resume "$SID" --mode json --auto-approve 2>&1 | \
  jq -r 'select(.type == "agent_end") | .messages[] | select(.role=="assistant") | .content[] | select(.type=="text") | .text' | tail -1
```

- Session ID (ULID) comes from `session.id` in the first JSON line of Call 1.
- Use one `--session-dir` per delegated task.
- `--continue` creates a new session — always use `--resume "$SID"` to continue within the same session.

## Common Flags

| Flag | Notes |
|------|-------|
| `-p` | Prompt text |
| `--no-session` | Ephemeral; no session file |
| `--mode json` | Line-delimited JSON on stdout |
| `--auto-approve` | Skip tool-approval prompts |
| `--cwd <path>` | Working directory |
| `--max-time <n>` | Max duration (e.g. `600`, `10m`) |
| `--model <id>` | Specific model (e.g. `opus`, `openai/gpt-5.2`) |
| `--smol` / `--slow` | Fast/reasoning model override |
| `--no-tools` | Prompt-only; no tool execution |
| `--no-lsp` | Disable LSP tools |
| `--system-prompt <text>` | Override system prompt |
| `--append-system-prompt @<file>` | Append file to system prompt |
| `--session-dir <path>` | Session storage directory |
| `--resume <id>` | Resume specific session by ID prefix |
| `--print-thoughts` | Include thinking in JSON output |

## Output Events

| type | Meaning |
|------|---------|
| `session` | Session metadata (id, cwd). First line. |
| `agent_end` | Session complete. Completion signal. |
| `error` | Task failed |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Usage error |
| 126 | OMP not found |

## Error Extraction

```bash
omp -p "<prompt>" --no-session --mode json 2>&1 | grep '"type":"error"' | jq '.'
```
