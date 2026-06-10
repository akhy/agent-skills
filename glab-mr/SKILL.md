---
name: glab-mr
description: >-
  Reviews a GitLab Merge Request using glab CLI. Fetches MR metadata, checks
  out the branch, diffs the changes, and performs a thorough code review
  covering correctness, edge cases, and interaction bugs. Use when the user
  asks to review a GitLab MR or provides an MR number.
---


# GitLab MR Review

Review a GitLab Merge Request end-to-end using the `glab` CLI.

The goal is to give human reviewers a quick, structured read of what changed
and — more importantly — surface insights that are easy to miss at first
glance: interaction bugs, untested combinations, silent regressions, and
implicit breaking changes that aren't obvious from the diff alone.

## Trigger

Use this skill when the user says things like:
- "review MR 92"
- "check MR !42"
- "look at merge request 15"
- provides a GitLab MR URL

## Workflow

### 1. Fetch MR metadata

```bash
glab mr show <MR_NUMBER>
```

Note: title, author, pipeline status, approval state, number of changed files.

### 2. Check for uncommitted changes before switching branches

```bash
git status --short
```

If any uncommitted or untracked files are present, **warn the user** before
proceeding:

> ⚠️ Your working tree has uncommitted changes. Checking out the MR branch may
> mix your local changes into the review context. Consider stashing or
> committing them first (`git stash`) before continuing.

Ask the user whether to proceed or abort.

### 3. Checkout the branch

```bash
glab mr checkout <MR_NUMBER>
```

This puts the working tree on the MR branch so files can be read in full context.

### 4. Diff the changes

For large MRs or MRs containing generated files, first identify which files are handwritten versus auto-generated (e.g. lockfiles like `yarn.lock`, compiled JS/CSS bundles, mocks like `*_mock.go`, protobuf files `*.pb.go`, generated documentation, or Helm templates generated from charts). 

Use `git diff --name-only` or view the MR file list to identify the files.

Then diff the changes:

```bash
glab mr diff <MR_NUMBER>
```

Read every hunk in the handwritten files carefully. Skip generated or vendor files. Build a mental model of:
- What the MR intends to do
- Which files are changed and how they relate to each other

### 5. Read changed files in full context

After reviewing the diff, read the **complete** versions of the changed handwritten files
(not just the diff hunks) using the `view` tool. This reveals:
- Logic that surrounds the change
- Other code paths that interact with the modified sections
- Existing patterns the change should be consistent with

Do not spend time reading or opening generated files in full context.

Also read closely related files (e.g. interfaces, types, tests, configs,
schemas, sibling modules) even if they were not changed, to understand the
full picture of how the touched code fits into the system.

### 6. Identify issues at multiple levels

Look for issues at each level, roughly in priority order:

**Functional / correctness**
- Does the changed code produce correct behaviour for all input combinations?
- Are there interaction bugs between new and existing code paths?
  (e.g., a new feature sharing state or a shared data structure with an
  existing feature in a way that corrupts one or both)
- Are default values, fallbacks, and null/zero cases safe and intentional?
- Are error paths handled correctly?

**Edge cases**
- What happens when optional inputs are omitted or empty?
- What happens when a flag or toggle is explicitly set to its off/false value?
- What happens when the new feature is combined with every existing feature
  that touches the same data or code path?

**Validation / contracts**
- Are inputs validated before use?
- Are type constraints, range checks, and required-field checks correct?
- Are conditional requirements (e.g., field A required only when flag B is
  true) enforced at the right layer?

**Tests**
- Are the new test cases sufficient to cover the happy path?
- Are there missing negative tests (disabled flag, empty input, invalid input)?
- Are there missing combination/integration tests (new feature + existing
  feature exercised together)?

**Breaking changes**
- Does the MR rename, restructure, or remove existing public interfaces,
  API fields, config keys, or file formats?
- Is there more than one breaking change bundled together?
- Is there a migration guide, deprecation notice, or changelog entry?

**Documentation**
- Are comments, docstrings, README, or CHANGELOG updated where relevant?
- Are version numbers bumped appropriately (patch / minor / major)?

### 7. Write the review

Structure the output as:

```
## Summary
One paragraph: what the MR does and its overall quality.

## Changes Breakdown
Per-file notes with ✅ / 🟡 / 🔴 indicators.

## Issues / Concerns
Each issue with:
- Severity emoji (🔴 bug, 🟡 concern, 🔵 suggestion)
- Clear description of the problem
- Concrete example showing the bad behaviour where possible
- Suggested fix (brief)
```

Only surface issues that genuinely matter — bugs, edge-case failures, silent
regressions, or missing validation. Do not comment on style, formatting, or
trivial matters.

## Notes

- `glab` must be authenticated and the remote must be reachable.
- After `glab mr checkout`, the repo is on the MR branch. Remind the user to
  switch back (`git checkout main` or similar) when done if needed.
- **Handling Large MRs & Generated Files:**
  - For very large MRs (50+ files), focus the full-context reads on the files most central to the change rather than every touched file.
  - If the diff output of `glab mr diff` is too large or cluttered, run native git commands to exclude generated files, e.g.:
    `git diff origin/main...HEAD -- . ':(exclude)*.lock' ':(exclude)*.pb.go' ':(exclude)*_mock.go'`
  - Completely ignore lockfiles, generated mock files, and compiled assets during code review.
