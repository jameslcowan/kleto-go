#!/usr/bin/env bash
# Verify Cursor autonomy layers; exit 1 if allowlist prompts will likely persist.
set -euo pipefail

FAIL=0
ok() { echo "OK  $*"; }
bad() { echo "FAIL $*"; FAIL=1; }

echo "=== Cursor autonomy verification ==="

# Project cli.json (schema: permissions only)
if [[ -f .cursor/cli.json ]]; then
  if cursor-agent about 2>&1 | grep -qi "Invalid project config"; then
    bad ".cursor/cli.json rejected by cursor-agent (invalid schema)"
  else
    ok ".cursor/cli.json valid"
  fi
else
  bad "missing .cursor/cli.json"
fi

# Global IDE permissions file
PJ="${HOME}/.cursor/permissions.json"
if [[ -f "$PJ" ]]; then
  python3 - "$PJ" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
mode = p.get("approvalMode")
if mode != "unrestricted":
    print(f"FAIL ~/.cursor/permissions.json approvalMode={mode!r} (need unrestricted)")
    sys.exit(1)
print("OK  ~/.cursor/permissions.json approvalMode=unrestricted")
PY
  [[ $? -eq 0 ]] || FAIL=1
else
  bad "missing ~/.cursor/permissions.json (IDE uses this for Auto-Run mode)"
fi

# CLI config
CJ="${HOME}/.cursor/cli-config.json"
if [[ -f "$CJ" ]]; then
  python3 - "$CJ" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("approvalMode") != "unrestricted":
    print(f"FAIL cli-config approvalMode={d.get('approvalMode')!r}")
    sys.exit(1)
allow = d.get("permissions", {}).get("allow") or []
if not any("Shell(**)" in a for a in allow):
    print("FAIL cli-config missing Shell(**) in permissions.allow")
    sys.exit(1)
print("OK  ~/.cursor/cli-config.json unrestricted + Shell(**)")
PY
  [[ $? -eq 0 ]] || FAIL=1
else
  bad "missing ~/.cursor/cli-config.json"
fi

# Composer Run Everything flag
DB="${HOME}/.config/Cursor/User/globalStorage/state.vscdb"
if [[ -f "$DB" ]]; then
  python3 - "$DB" <<'PY'
import json, sqlite3, sys
key = "src.vs.platform.reactivestorage.browser.reactiveStorageServiceImpl.persistentStorage.applicationUser"
conn = sqlite3.connect(sys.argv[1])
row = conn.execute("SELECT value FROM ItemTable WHERE key=?", (key,)).fetchone()
conn.close()
if not row:
    print("FAIL state.vscdb missing applicationUser storage")
    sys.exit(1)
data = json.loads(row[0])
cs = data.get("composerState", {})
if not cs.get("yoloEnableRunEverything"):
    print("FAIL composerState.yoloEnableRunEverything is false (IDE allowlist UI)")
    sys.exit(1)
agent = next((m for m in (cs.get("modes4") or []) if m.get("id") == "agent"), None)
if not agent or not agent.get("fullAutoRun"):
    print("FAIL agent mode fullAutoRun is false")
    sys.exit(1)
print("OK  IDE composer Run Everything enabled in state.vscdb")
PY
  [[ $? -eq 0 ]] || FAIL=1
else
  bad "missing state.vscdb"
fi

# Hooks
for f in .cursor/hooks.json .cursor/hooks/allow-execution.sh .cursor/hooks/verify-stop.sh; do
  [[ -e "$f" ]] && ok "$f present" || { bad "missing $f"; }
done
[[ -x .cursor/hooks/allow-execution.sh ]] && ok "allow-execution.sh executable" || bad "allow-execution.sh not executable"
[[ -x .cursor/hooks/verify-stop.sh ]] && ok "verify-stop.sh executable" || bad "verify-stop.sh not executable"

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "All checks passed."
else
  echo "Some checks failed. Run: ./scripts/setup-cursor-autonomy.sh"
  exit 1
fi
