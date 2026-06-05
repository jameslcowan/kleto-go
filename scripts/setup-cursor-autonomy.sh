#!/usr/bin/env bash
# Fix Cursor allowlist prompts: CLI config + IDE permissions.json + composer Run Everything.
set -euo pipefail

CURSOR_DIR="${HOME}/.cursor"
CLI_CONFIG="${CURSOR_DIR}/cli-config.json"
PERMISSIONS_JSON="${CURSOR_DIR}/permissions.json"
STATE_DB="${HOME}/.config/Cursor/User/globalStorage/state.vscdb"
STAMP="$(date +%Y%m%d%H%M%S)"

mkdir -p "$CURSOR_DIR"

# --- 1. IDE permissions.json (Composer reads ~/.cursor/permissions.json, NOT project cli.json) ---
if [[ -f "$PERMISSIONS_JSON" ]]; then
  cp "$PERMISSIONS_JSON" "${PERMISSIONS_JSON}.bak.${STAMP}"
fi
cat > "$PERMISSIONS_JSON" <<'EOF'
{
  "approvalMode": "unrestricted",
  "terminalAllowlist": [],
  "mcpAllowlist": []
}
EOF
echo "Wrote ${PERMISSIONS_JSON} (approvalMode: unrestricted)"

# --- 2. CLI config ---
if [[ -f "$CLI_CONFIG" ]]; then
  cp "$CLI_CONFIG" "${CLI_CONFIG}.bak.${STAMP}"
  python3 <<'PY'
import json, pathlib
path = pathlib.Path.home() / ".cursor" / "cli-config.json"
data = json.loads(path.read_text())
data["approvalMode"] = "unrestricted"
perms = data.setdefault("permissions", {})
allow = set(perms.get("allow") or [])
allow.update([
    "Shell(**)", "Read(**)", "Write(**)", "StrReplace(**)", "Delete(**)",
    "Grep(**)", "Glob(**)", "EditNotebook(**)", "TodoWrite(**)",
    "WebFetch(**)", "WebSearch(**)", "Task(**)", "GenerateImage(**)",
    "ReadLints(**)", "SwitchMode(**)", "AskQuestion(**)", "Mcp(**)",
])
perms["allow"] = sorted(allow)
perms["deny"] = perms.get("deny") or []
sandbox = data.setdefault("sandbox", {})
sandbox["mode"] = "disabled"
sandbox["networkAccess"] = "allow_all"
data["attribution"] = {
    "attributeCommitsToAgent": False,
    "attributePRsToAgent": False,
}
path.write_text(json.dumps(data, indent=2) + "\n")
print(f"Updated {path} (attribution disabled)")
PY
else
  echo "Skip cli-config.json (missing — open Cursor once to create it)" >&2
fi

# --- 3. IDE composer: enable Run Everything in application storage ---
if [[ -f "$STATE_DB" ]]; then
  cp "$STATE_DB" "${STATE_DB}.bak.${STAMP}"
  python3 <<'PY'
import json, sqlite3, pathlib

db = pathlib.Path.home() / ".config/Cursor/User/globalStorage/state.vscdb"
key = "src.vs.platform.reactivestorage.browser.reactiveStorageServiceImpl.persistentStorage.applicationUser"

conn = sqlite3.connect(db)
row = conn.execute("SELECT value FROM ItemTable WHERE key=?", (key,)).fetchone()
if not row:
    print("Skip state.vscdb patch (applicationUser key not found)")
    conn.close()
    raise SystemExit(0)

data = json.loads(row[0])
cs = data.setdefault("composerState", {})
cs["yoloEnableRunEverything"] = True
cs["doNotShowFullYoloModeWarningAgain"] = True
cs["doNotShowYoloModeWarningAgain"] = True

for mode in cs.get("modes4") or []:
    if mode.get("id") in ("agent", "triage", "multitask"):
        mode["autoRun"] = True
        mode["fullAutoRun"] = True

conn.execute("UPDATE ItemTable SET value=? WHERE key=?", (json.dumps(data), key))
conn.commit()
conn.close()
print(f"Patched {db}: yoloEnableRunEverything=true, agent.fullAutoRun=true")
PY
else
  echo "Skip state.vscdb (open Cursor once first)" >&2
fi

echo ""
echo "Done. Fully quit and restart Cursor (not just reload window)."
echo "Then run: ./scripts/verify-cursor-autonomy.sh"
