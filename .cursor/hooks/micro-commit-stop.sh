#!/usr/bin/env bash
# stop hook: if the working tree is dirty, auto-continue so the agent micro-commits.
set -euo pipefail

payload=$(cat)

status=$(printf '%s' "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','completed'))" 2>/dev/null || echo "completed")
loop_count=$(printf '%s' "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('loop_count',0))" 2>/dev/null || echo "0")

if [[ "$status" != "completed" ]]; then
  echo '{}'
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

if [[ -z $(git status --porcelain) ]]; then
  echo '{}'
  exit 0
fi

summary=$(git status --short | head -20)
remaining=$(git status --short | wc -l | tr -d ' ')

python3 - <<PY
import json

summary = """$summary""".strip()
remaining = int("$remaining")
loop_count = int("$loop_count")

msg = (
    "Uncommitted changes remain. Micro-commit now per .cursor/rules/micro-commits.mdc: "
    "stage only the files for ONE logical step, commit with a focused message, verify clean status, "
    "then continue. Do not ask whether to commit.\n\n"
    f"git status (first 20 lines, {remaining} total):\n{summary}"
)
if loop_count >= 3:
    msg += "\n\nYou have been reminded multiple times — split into smaller steps if needed."

print(json.dumps({"followup_message": msg}))
PY
