---
description: Show (and optionally remove) merged, clean claude-worktree-tools worktrees
argument-hint: "[root]"
allowed-tools: "Bash(wt-cleanup *)"
---

Run `wt-cleanup $ARGUMENTS` via Bash (without `--yes`) and show the user the
list of worktrees it finds safe to remove. If the user then confirms they
want them removed, re-run it with `--yes` appended. Never pass `--yes` on
the first run -- always show the dry-run list and get explicit confirmation
first.
