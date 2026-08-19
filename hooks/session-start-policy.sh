#!/usr/bin/env bash
# SessionStart hook: injects the cross-repo worktree policy into context,
# but only when the session's cwd looks like a multi-repo workspace root
# (its immediate children include 2+ git repos). This keeps the hook silent
# in ordinary single-repo sessions even if the plugin is later installed
# more broadly than just the multi-repo root it was built for.
#
# Output here is plain text (not JSON) -- for SessionStart, stdout is added
# directly to Claude's context.
set -euo pipefail

input="$(cat || true)"
cwd="$(printf '%s' "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed -E 's/.*:[[:space:]]*"//; s/"$//')"
[ -n "$cwd" ] || cwd="$PWD"

repo_count=0
for d in "$cwd"/*/; do
  d="${d%/}"
  [ -d "$d" ] || continue
  # Only count directories that are themselves a repo ROOT (have their own
  # .git entry) -- git rev-parse succeeds inside any subdirectory of a repo,
  # not just at its root, so that alone would misclassify e.g. abodo-rails's
  # own app/, engines/, etc. as separate nested repos.
  if [ -e "$d/.git" ]; then
    repo_count=$((repo_count + 1))
    [ "$repo_count" -ge 2 ] && break
  fi
done

[ "$repo_count" -ge 2 ] || exit 0

cat <<'POLICY'
## Cross-repo worktree policy (claude-worktree-tools plugin)

You are in a multi-repo workspace root (a folder containing several git
repos as direct children, not a repo itself). If a task requires editing
files in a nested repo you have not yet prepared an isolated worktree for,
do the following automatically -- no need to ask first:

1. Run: wt-new <repo> <slug>  (reuse this session's task slug/branch name --
   e.g. the same slug used for the worktree you're already in, if any).
2. Work inside the resulting <repo>/.claude/worktrees/<slug> directory
   instead of that repo's shared main checkout -- editing the main checkout
   directly would collide with other parallel sessions working on it.
3. Only call the EnterWorktree tool for the FIRST repo you touch in a
   session (it switches your own working directory/context). For every
   additional repo, just work directly inside its .claude/worktrees/<slug>
   dir via Bash/Edit -- a second EnterWorktree call is rejected once you're
   already inside another repo's worktree.
4. Tell the user which worktree(s) you created and why.
5. Before ending the session, remind the user which worktrees are still
   around -- run wt-list -- so they can be cleaned up with wt-cleanup once
   the task is done.
POLICY
