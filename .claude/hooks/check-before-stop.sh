#!/usr/bin/env bash
# Stop: if code changed, require full specs, rubocop and zeitwerk green.
set -uo pipefail
cd "$CLAUDE_PROJECT_DIR"

# Already sent back once this turn: let Claude stop, to avoid an endless loop.
[[ $(jq -r '.stop_hook_active // false') == "true" ]] && exit 0

changed=$({ git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u)
grep -qE '\.(rb|rake)$|^Gemfile|^config/|^db/|^\.rubocop' <<<"$changed" || exit 0

# Rubocop only the Ruby files that still exist (skip deleted ones).
rb=$(grep -E '\.(rb|rake)$' <<<"$changed" | while read -r f; do [[ -f "$f" ]] && echo "$f"; done)

failed=0
report() { echo "== $1 failed =="; tail -n 60 <<<"$2"; echo; }

out=$(bin/rspec 2>&1) || { report "bin/rspec" "$out" >&2; failed=1; }
if [[ -n "$rb" ]]; then
  out=$(xargs bin/rubocop --force-exclusion <<<"$rb" 2>&1) || { report "bin/rubocop" "$out" >&2; failed=1; }
fi
out=$(bin/rails zeitwerk:check 2>&1) || { report "zeitwerk:check" "$out" >&2; failed=1; }

if (( failed )); then
  echo "Fix these before finishing (CLAUDE.md > Commands). For style: bin/rubocop -a <files>." >&2
  exit 2
fi
