# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository is a collection of reusable LLM agent skills managed by @akhy, conforming to the [Agent Skills open standard](https://github.com/agentskills/agentskills).

## Skill Structure

Each skill is a top-level directory. Only `SKILL.md` is required:

```
<skill-name>/
├── SKILL.md        # Required — frontmatter + instructions
├── scripts/        # Optional — self-contained executable scripts
├── references/     # Optional — technical docs loaded on demand
└── assets/         # Optional — templates, images, data files
```

## SKILL.md Format

```markdown
---
name: <skill-name>
description: <purpose and keywords to help agents identify when it applies>
license: <optional>
compatibility: <optional, max 500 chars>
metadata:         # optional key-value pairs
  key: value
allowed-tools: Tool1 Tool2   # optional, experimental
---

# Instructions in Markdown...
```

**Frontmatter rules:**
- `name`: 1–64 chars, lowercase alphanumeric + hyphens, must match the directory name
- `description`: 1–1024 chars; include relevant keywords for agent matching
- Keep `SKILL.md` under 500 lines — supporting files load on demand

## Scripts

Scripts in `scripts/` must be self-contained and non-interactive (agents can't respond to TTY prompts):

- Use inline dependency declarations (PEP 723 for Python, `npm:`/`jsr:` for Deno, Bun auto-install)
- Run Python scripts with `uv run`, Deno scripts with `deno run`, etc.
- Pin versions for reproducibility
- Output data to stdout (structured preferred: JSON/CSV), diagnostics to stderr
- Support `--help`, meaningful exit codes, and idempotency

Reference scripts from `SKILL.md` using relative paths from the skill root (one level deep).

## Validation

Use the `skills-ref` tool to validate skill structure against the spec.
