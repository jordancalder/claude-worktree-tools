# claude-worktree-tools

Native Claude Code worktrees, across multiple repos at once, from a
multi-repo workspace root.

## The problem

Claude Code's native worktree flow (`claude --worktree <name>`, and the
`EnterWorktree` tool) gives a session its own isolated git checkout — but the
shortcut form only works launched from *inside* a single git repo. If your
day-to-day work lives in a folder containing several sibling repos
(`~/code/repo-a`, `~/code/repo-b`, ...) and a given task often touches more
than one of them, there's no single native command to spin up matching,
isolated worktrees across all of them and land one session inside them.

This toolkit closes that gap using Claude Code's own primitives — it doesn't
work around anything, it just automates the setup `EnterWorktree` already
supports (attaching to a worktree of a repo nested inside your launch
directory), plus a policy/guard so Claude creates the same isolation for any
*additional* repo it discovers it needs mid-task, without you having to know
that up front.

## Install

```bash
# from your multi-repo workspace root, e.g. ~/code
claude plugin marketplace add jordancalder/claude-worktree-tools
claude plugin install claude-worktree-tools@claude-worktree-tools --scope project
```

This enables the plugin's hooks and slash commands for that workspace root
(writes to `.claude/settings.json` there — works even though the root itself
isn't a git repo; plugin scoping is directory-based, not git-based).

Also add `bin/` to your `PATH` so `claude-wt`, `wt-new`, `wt-list`, and
`wt-cleanup` are available as plain shell commands (not just from inside a
running session):

```bash
git clone git@github.com:jordancalder/claude-worktree-tools.git ~/tools/claude-worktree-tools
echo 'export PATH="$HOME/tools/claude-worktree-tools/bin:$PATH"' >> ~/.zshrc
```

## Use

From your workspace root, start a task that's already known to touch two
(or more) repos:

```bash
cd ~/code
claude-wt app-4100-sync-billing abodo-rails apartmentiq-js-app
```

This creates `abodo-rails/.claude/worktrees/app-4100-sync-billing` and
`apartmentiq-js-app/.claude/worktrees/app-4100-sync-billing`, then launches a
`claude` session named `app-4100-sync-billing`, seeded to enter the first
worktree immediately. The second repo's worktree is already there, ready to
work in directly.

If the task turns out to need a repo you didn't list, you don't need to do
anything — the plugin's injected policy has Claude create that repo's
worktree on the fly, and a guard hook blocks any attempt to edit that repo's
shared main checkout directly instead.

### Resuming a crashed or ended session

Sessions launched by `claude-wt` are named after the slug you gave them, so
they're resumable from anywhere, unambiguously, even with several other
`claude-wt` sessions running in parallel:

```bash
claude --resume app-4100-sync-billing
```

### Housekeeping

```bash
wt-list          # every claude-worktree-tools worktree under the current root, across all repos
wt-cleanup        # dry run: which worktrees are merged + clean and safe to remove
wt-cleanup --yes  # actually remove them
```

Both are also available as slash commands inside a running session:
`/wt-list`, `/wt-cleanup`, `/wt-new`.

## How it works

- `wt-new <repo> <slug> [branch]` — thin wrapper around
  `git -C <repo> worktree add .claude/worktrees/<slug> -b <branch>`, i.e. the
  exact location Claude Code's own `--worktree`/`EnterWorktree` use. Branch
  defaults to `<your-git-email-local-part>/<slug>`.
- `claude-wt <slug> <repo...>` — calls `wt-new` for each repo, then launches
  `claude --name <slug> "<seed prompt telling it to EnterWorktree the first
  repo's worktree>"`.
- A `SessionStart` hook injects the cross-repo worktree policy into context
  automatically (only when the session's launch directory looks like a
  multi-repo workspace root — 2+ nested git repos as direct children), so no
  project's `CLAUDE.md` needs to carry this text by hand.
- A `PreToolUse` hook (matching `Edit`/`Write`/`Bash`) is a safety net: once a
  session is already working inside one repo's `.claude/worktrees/<slug>`,
  it denies any tool call that targets a *different* nested repo's plain
  checkout instead of that repo's own matching worktree, with a reason
  telling Claude exactly what to run instead.

Worktrees deliberately live at the native `<repo>/.claude/worktrees/<slug>`
location rather than as sibling directories at the workspace root. Sibling
directories break two things: crash-resume only re-attaches correctly if you
resume from the repo's main checkout (not from inside the sibling worktree
itself), and every `EnterWorktree` into a path outside `.claude/worktrees/`
prompts for approval each time. `wt-list` exists to give back the
"see everything at a glance" visibility that sibling directories used to
provide for free.

## Layout

```
.claude-plugin/plugin.json   plugin manifest
bin/                         claude-wt, wt-new, wt-list, wt-cleanup (plain shell, no deps)
commands/                    /wt-new, /wt-list, /wt-cleanup slash commands
hooks/                       SessionStart policy injection + PreToolUse guard
```
