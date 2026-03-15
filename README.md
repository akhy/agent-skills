# agent-skills

[![Skills Validation](https://github.com/akhy/agent-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/akhy/agent-skills/actions/workflows/validate.yml)

LLM agent skills collection by [@akhy](https://github.com/akhy).

## Usage

Install all skills:

```bash
npx skills add akhy/agent-skills
```

Install a specific skill:

```bash
npx skills add akhy/agent-skills --skill fizzy-workflow
```

List available skills without installing:

```bash
npx skills add akhy/agent-skills --list
```

## Skills

| Skill | Description |
|-------|-------------|
| [buffer](./buffer/SKILL.md) | Manage Buffer social media posts and ideas — create, schedule, and queue posts across all connected channels |
| [fizzy-workflow](./fizzy-workflow/SKILL.md) | High-level workflows for managing work using Fizzy cards (start, work on, complete, delegate) |
| [mdq](./mdq/SKILL.md) | Query and filter Markdown documents using jq-like selector syntax |
| [memos](./memos/SKILL.md) | Create, list, update, delete memos and manage comments, reactions, attachments, and relations via the Memos REST API |
| [plurk](./plurk/SKILL.md) | Read and respond to Plurk social network content — timeline, plurks, responses, and posting |
| [plurk-trend](./plurk-trend/SKILL.md) | Show trending plurks from the last 24 hours ranked by number of responses |
| [go-release](./go-release/SKILL.md) | Set up automated releases for Go CLI apps using GoReleaser, GitHub Actions, GHCR, and Homebrew tap |
