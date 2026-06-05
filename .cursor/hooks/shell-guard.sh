#!/usr/bin/env bash
# Deny destructive shell commands before allow-execution runs. Exit 0 = allow hook chain to continue.
set -euo pipefail

payload=$(cat)

result=$(PAYLOAD="$payload" python3 <<'PY' 2>/dev/null || true
import json, os, re, sys

raw = os.environ.get("PAYLOAD", "")
if not raw.strip():
    sys.exit(0)
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

cmd = (data.get("command") or data.get("cmd") or "").strip()
if not cmd:
    sys.exit(0)

patterns = [
    (r"rm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+)*(/|\s+/\s|/\s*$)", "rm -rf on system root"),
    (r"git\s+push\b[^\n]*(--force|-f)\b[^\n]*\b(main|master)\b", "force-push to main/master"),
    (r"git\s+push\b[^\n]*\b(main|master)\b[^\n]*(--force|-f)\b", "force-push to main/master"),
    (r"git\s+reset\s+--hard\b", "git reset --hard"),
    (r"git\s+filter-branch\b", "git filter-branch"),
    (r"git\s+config\s+", "git config write"),
    (r":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;", "fork bomb"),
    (r"curl\s+[^\n|]*\|\s*(ba)?sh\b", "curl pipe to shell"),
    (r"wget\s+[^\n|]*\|\s*(ba)?sh\b", "wget pipe to shell"),
    (r"curl\s+[^\n|]*\|\s*sudo\s+(ba)?sh\b", "curl pipe to sudo shell"),
]

for regex, label in patterns:
    if re.search(regex, cmd, re.IGNORECASE):
        print(json.dumps({
            "permission": "deny",
            "user_message": f"Blocked by kleto-go shell-guard: {label}",
            "agent_message": f"Shell command blocked ({label}). Use a safer approach per .cursor/rules/git-safety.mdc.",
        }))
        sys.exit(0)

sys.exit(0)
PY
)

if [[ -n "${result:-}" ]]; then
  printf '%s\n' "$result"
  exit 2
fi

exit 0
