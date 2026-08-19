---
description: Create an isolated native worktree for one repo and task slug
argument-hint: "<repo> <slug> [branch]"
allowed-tools: "Bash(wt-new *)"
---

Run `wt-new $ARGUMENTS` via Bash and report back the worktree path it created
(or the message that it already existed). Do not attempt to construct the
`git worktree add` command manually -- always go through `wt-new` so the
location, naming, and branch-default conventions stay consistent.
