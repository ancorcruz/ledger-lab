#!/usr/bin/env bash
# PreToolUse hook (Bash): block `git commit` while on main.
# See the Git section in CLAUDE.md.
set -euo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

# Match `git [global opts] commit`, e.g. `git commit`, `git -C . commit`,
# `cd x && git commit`. Doesn't match `git log --grep commit`.
re='(^|[;&|({[:space:]])git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[A-Za-z-]+(=[^[:space:]]+)?)*[[:space:]]+commit([[:space:]]|$)'
[[ "$cmd" =~ $re ]] || exit 0

branch=$(git -C "${cwd:-$CLAUDE_PROJECT_DIR}" symbolic-ref --short -q HEAD 2>/dev/null || true)

if [[ "$branch" == "main" ]]; then
  cat >&2 <<'MSG'
Blocked: git commit on `main`.
See the "Git" section in CLAUDE.md: never commit on main. Start a new
branch from an up-to-date main, named <type>/<short-slug>
(e.g. `git switch -c feat/ledger-entries`), then commit there.
MSG
  exit 2
fi

exit 0
