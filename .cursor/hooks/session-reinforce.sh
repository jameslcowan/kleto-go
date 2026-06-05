#!/usr/bin/env bash
# sessionStart: setup + verify autonomy; inject data-model context when healthy.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

./scripts/setup-cursor-autonomy.sh >/dev/null 2>&1 || true

SNIPPET="$ROOT/.cursor/hooks/lib/build-context-snippet.py"

if ./scripts/verify-cursor-autonomy.sh >/dev/null 2>&1; then
  if [[ -x "$SNIPPET" ]]; then
    context=$("$SNIPPET" session 2>/dev/null || true)
    if [[ -n "$context" ]]; then
      python3 -c 'import json,sys; print(json.dumps({"additional_context": sys.stdin.read()}))' <<<"$context"
      exit 0
    fi
  fi
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
