#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|Bash): safety net for the cross-repo worktree
# policy. Only fires once a session has already opted into the worktree
# flow -- i.e. its cwd matches <repo>/.claude/worktrees/<slug> -- and only
# denies a tool call when it targets a *different* nested repo's shared main
# checkout instead of that repo's own matching worktree.
#
# Never affects ordinary single-repo sessions, and never affects edits
# within the current worktree itself.
set -euo pipefail

input="$(cat || true)"

json_string() {
  # Extracts a top-level, single-line string field's value from the hook's
  # input JSON. Best-effort (no jq dependency); fields we read here
  # (cwd, tool_name, file_path, command) are always flat strings in the
  # documented hook payload.
  local key="$1"
  printf '%s' "$input" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n1 \
    | sed -E "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"//; s/\"\$//"
}

escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  printf '%s' "$s"
}

allow() { exit 0; }

cwd="$(json_string cwd)"
[ -n "$cwd" ] || cwd="$PWD"

# Only guard sessions already inside a native claude-wt worktree.
[[ "$cwd" == *"/.claude/worktrees/"* ]] || allow

slug="${cwd#*/.claude/worktrees/}"
slug="${slug%%/*}"
repo_dir="${cwd%%/.claude/worktrees/*}"
repo_dir="${repo_dir%/}"
root_dir="$(dirname "$repo_dir")"
repo_name="$(basename "$repo_dir")"

deny() {
  local target="$1"
  local reason="You're already working inside the isolated worktree for '$slug' in $repo_name. This action targets '$target', which is outside that worktree. Run: wt-new <repo> $slug -- then work inside <repo>/.claude/worktrees/$slug instead of the shared main checkout."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$(escape_json "$reason")"
  exit 0
}

is_other_nested_repo() {
  local d="$1"
  [ -d "$d" ] || return 1
  [ "$(basename "$d")" != "$repo_name" ] || return 1
  # Only a repo ROOT counts (has its own .git entry) -- git rev-parse would
  # also succeed for any ordinary subdirectory of a repo, which isn't what
  # we want here.
  [ -e "$d/.git" ]
}

tool_name="$(json_string tool_name)"

case "$tool_name" in
  Edit|Write)
    file_path="$(json_string file_path)"
    [ -n "$file_path" ] || allow
    case "$file_path" in
      "$root_dir"/*)
        other_repo="${file_path#"$root_dir"/}"
        other_repo="${other_repo%%/*}"
        other_dir="$root_dir/$other_repo"
        if is_other_nested_repo "$other_dir" && [[ "$file_path" != *"/.claude/worktrees/"* ]]; then
          deny "$file_path"
        fi
        ;;
    esac
    ;;
  Bash)
    command_str="$(json_string command)"
    [ -n "$command_str" ] || allow
    for d in "$root_dir"/*/; do
      d="${d%/}"
      is_other_nested_repo "$d" || continue
      if [[ "$command_str" == *"$d"* ]] && [[ "$command_str" != *"$d/.claude/worktrees"* ]]; then
        deny "$d"
      fi
    done
    ;;
esac

allow
