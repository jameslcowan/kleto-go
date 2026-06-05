#!/usr/bin/env bash
# afterFileEdit: refresh handoff context (observation — always allow).
set -euo pipefail

cat >/dev/null

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [[ -x "$ROOT/scripts/refresh-auto-context.sh" ]]; then
  "$ROOT/scripts/refresh-auto-context.sh" >/dev/null 2>&1 || true
fi

echo '{}'
exit 0
