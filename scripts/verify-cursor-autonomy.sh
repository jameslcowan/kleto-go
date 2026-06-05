#!/usr/bin/env bash
# Verify Cursor autonomy layers; exit 1 if allowlist prompts will likely persist.
set -euo pipefail

FAIL=0
ok() { echo "OK  $*" >&2; }
bad() { echo "FAIL $*"; FAIL=1; }

echo "=== Cursor autonomy verification ===" >&2

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
print("OK  ~/.cursor/permissions.json approvalMode=unrestricted", file=sys.stderr)
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
attr = d.get("attribution") or {}
if attr.get("attributeCommitsToAgent") or attr.get("attributePRsToAgent"):
    print(f"FAIL cli-config attribution enabled: {attr}")
    sys.exit(1)
print("OK  ~/.cursor/cli-config.json unrestricted + attribution off", file=sys.stderr)
PY
  [[ $? -eq 0 ]] || FAIL=1
else
  bad "missing ~/.cursor/cli-config.json"
fi

# Git history: no agent Co-authored-by on any commit
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  AGENT_CO=$(git log --format='%H' | python3 -c "
import re, subprocess, sys
pat = re.compile(r'^Co-authored-by:', re.I)
agents = re.compile(r'cursor|cursoragent|copilot|claude|anthropic|openai|\[bot\]', re.I)
bad = []
for h in sys.stdin.read().split():
    msg = subprocess.run(['git','log','-1','--format=%B',h],capture_output=True,text=True).stdout
    for ln in msg.splitlines():
        if pat.match(ln) and agents.search(ln):
            bad.append(f'{h[:7]} {ln.strip()}')
            break
if bad:
    print('Agent Co-authored-by found on', len(bad), 'commit(s):')
    print(chr(10).join(bad[:5]))
    if len(bad) > 5:
        print('...')
    sys.exit(1)
print('OK  git history has no agent Co-authored-by trailers', file=sys.stderr)
" 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    ok "git history clean of agent co-authors"
  else
    echo "$AGENT_CO"
    bad "agent Co-authored-by in git history — run ./scripts/strip-agent-coauthors-from-history.sh"
  fi
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
print("OK  IDE composer Run Everything enabled in state.vscdb", file=sys.stderr)
PY
  [[ $? -eq 0 ]] || FAIL=1
else
  bad "missing state.vscdb"
fi

# Hooks
for f in .cursor/hooks.json .cursor/hooks/shell-guard.sh .cursor/hooks/data-first-pre-tool.sh \
  .cursor/hooks/inject-context.sh .cursor/hooks/allow-execution.sh .cursor/hooks/after-file-edit.sh \
  .cursor/hooks/verify-stop.sh .cursor/hooks/lib/build-context-snippet.py \
  scripts/refresh-auto-context.sh; do
  [[ -e "$f" ]] && ok "$f present" || { bad "missing $f"; }
done
for x in shell-guard.sh data-first-pre-tool.sh inject-context.sh allow-execution.sh \
  after-file-edit.sh verify-stop.sh; do
  [[ -x ".cursor/hooks/$x" ]] && ok "$x executable" || bad "$x not executable"
done
[[ -x scripts/refresh-auto-context.sh ]] && ok "refresh-auto-context.sh executable" || bad "refresh-auto-context.sh not executable"

echo "" >&2
if [[ $FAIL -eq 0 ]]; then
  echo "All checks passed." >&2
  exit 0
else
  echo "Some checks failed. Run: ./scripts/setup-cursor-autonomy.sh" >&2
  exit 1
fi
