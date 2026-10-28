#!/usr/bin/env bash
# PostToolUse (Edit|MultiEdit|Write): run the spec for the edited Ruby file.
set -euo pipefail
cd "$CLAUDE_PROJECT_DIR"

file=$(jq -r '.tool_input.file_path // empty')
file=${file#"$CLAUDE_PROJECT_DIR/"}
[[ "$file" == *.rb ]] || exit 0

# spec/ mirrors app/; controllers are covered by request specs.
case "$file" in
  spec/*_spec.rb)                  spec="$file" ;;
  app/controllers/*_controller.rb) spec="spec/requests/${file#app/controllers/}"
                                   spec="${spec%_controller.rb}_spec.rb" ;;
  app/*)                           spec="spec/${file#app/}"; spec="${spec%.rb}_spec.rb" ;;
  lib/*)                           spec="spec/${file%.rb}_spec.rb" ;;
  *)                               exit 0 ;;
esac
[[ -f "$spec" ]] || exit 0

if ! out=$(bin/rspec "$spec" 2>&1); then
  { echo "Failing: $spec (after editing $file)"; tail -n 60 <<<"$out"; } >&2
  exit 2
fi
