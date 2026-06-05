#!/usr/bin/env bash
# sessionStart: run setup + verify for the user; inject context only on failure.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

./scripts/setup-cursor-autonomy.sh >/dev/null 2>&1 || true

if ./scripts/verify-cursor-autonomy.sh >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

FAILS=$(./scripts/verify-cursor-autonomy.sh 2>&1 | grep '^FAIL' || true)

python3 - "$FAILS" <<'PY'
import json, sys
fails = sys.argv[1].strip()
msg = (
    "Session reinforcement: autonomy/attribution checks failed. "
    "You must fix these yourself now (agent-executes.mdc) — do not ask the user to run scripts.\n"
    "Run: ./scripts/setup-cursor-autonomy.sh && ./scripts/verify-cursor-autonomy.sh\n"
    f"Failures:\n{fails or '(see verify output)'}"
)
print(json.dumps({"additional_context": msg}))
PY
