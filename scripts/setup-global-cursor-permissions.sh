#!/usr/bin/env bash
# Merge unrestricted approval + broad allowlist into ~/.cursor/cli-config.json
set -euo pipefail

CONFIG="${HOME}/.cursor/cli-config.json"
BACKUP="${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"

if [[ ! -f "$CONFIG" ]]; then
  echo "Missing $CONFIG — open Cursor Agent once to create it, then re-run." >&2
  exit 1
fi

cp "$CONFIG" "$BACKUP"
echo "Backed up to $BACKUP"

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

path.write_text(json.dumps(data, indent=2) + "\n")
print("Updated:", path)
print("  approvalMode: unrestricted")
print("  permissions.allow: %d patterns" % len(perms["allow"]))
PY

echo "Restart Cursor / cursor-agent sessions to pick up changes."
