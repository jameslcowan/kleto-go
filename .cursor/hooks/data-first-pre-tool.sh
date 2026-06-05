#!/usr/bin/env bash
# preToolUse (Write): block app-layer writes when data model not confirmed.
set -euo pipefail

payload=$(cat)
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

result=$(PAYLOAD="$payload" ROOT="$ROOT" python3 <<'PY' 2>/dev/null || true
import json, os, re, sys

raw = os.environ.get("PAYLOAD", "")
if not raw.strip():
    sys.exit(0)
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

if data.get("tool_name") != "Write":
    sys.exit(0)

ti = data.get("tool_input") or {}
path = (
    ti.get("path")
    or ti.get("file_path")
    or ti.get("target_file")
    or ti.get("relative_workspace_path")
    or ""
)
path = str(path).replace("\\", "/").lstrip("./")
if not path:
    sys.exit(0)

app = re.compile(
    r"^(src/|app/|api/|server/|internal/|cmd/|prisma/|migrations/|supabase/|drizzle/)"
)
if not app.match(path):
    sys.exit(0)

root = os.environ.get("ROOT", "")
if not root:
    sys.exit(0)
model_path = os.path.join(root, ".cursor", "data-model.json")
status = "pending"
if os.path.isfile(model_path):
    try:
        status = json.load(open(model_path)).get("status", "pending")
    except json.JSONDecodeError:
        pass

if status in ("confirmed", "waived"):
    sys.exit(0)

print(json.dumps({
    "permission": "deny",
    "user_message": "data-first: confirm .cursor/data-model.json before writing app files",
    "agent_message": (
        f"Write to {path} blocked: data-model status={status}. "
        "Ask the user how data is modeled (AskQuestion), update "
        ".cursor/data-model.json to confirmed, then retry."
    ),
}))
PY
)

if [[ -n "${result:-}" ]]; then
  printf '%s\n' "$result"
  exit 2
fi

exit 0
