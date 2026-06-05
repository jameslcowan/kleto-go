#!/usr/bin/env bash
# Exit 1 if app-layer files changed but data model not confirmed (data-first gate).
set -euo pipefail

MODEL="${1:-.cursor/data-model.json}"
[[ -f "$MODEL" ]] || { echo "missing $MODEL"; exit 1; }

status=$(python3 - "$MODEL" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("status", "pending"))
PY
)

if [[ "$status" == "confirmed" || "$status" == "waived" ]]; then
  exit 0
fi

# App-layer paths (adjust per project)
APP_PATTERN='^(src/|app/|api/|server/|internal/|cmd/|prisma/|migrations/|supabase/|drizzle/)'
changed=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; git status --porcelain | awk '{print $NF}')
if echo "$changed" | grep -qE "$APP_PATTERN"; then
  echo "data-first: application files present but .cursor/data-model.json status=$status"
  echo "Ask the user how data is modeled, update data-model.json, then continue."
  exit 1
fi

# Also check last commit on stop hook (whole tree snapshot)
if git rev-parse HEAD >/dev/null 2>&1; then
  if git diff-tree --no-commit-id --name-only -r HEAD | grep -qE "$APP_PATTERN"; then
    echo "data-first: last commit touches application paths but status=$status"
    exit 1
  fi
fi

exit 0
