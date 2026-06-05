#!/usr/bin/env bash
# Unit test shell-guard without putting deny payloads in the parent shell command (IDE hook would match).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT/.cursor/hooks/shell-guard.sh" <<'PY'
import json, os, subprocess, sys

guard = sys.argv[1]
deny_cmd = "git push -f origin main"
allow_cmd = "ls -la"

def run(payload: dict) -> int:
    p = subprocess.run(
        [guard],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
    )
    return p.returncode

code = run({"command": deny_cmd})
if code != 2:
    print(f"FAIL: deny exit={code} want 2", file=sys.stderr)
    sys.exit(1)

code = run({"command": allow_cmd})
if code != 0:
    print(f"FAIL: allow exit={code} want 0", file=sys.stderr)
    sys.exit(1)

print("shell-guard tests passed")
PY
