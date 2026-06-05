#!/usr/bin/env bash
# postToolUse: inject data-model + notes after Write/Shell (tier B).
set -euo pipefail

payload=$(cat)

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SNIPPET="$ROOT/.cursor/hooks/lib/build-context-snippet.py"

should_inject=$(PAYLOAD="$payload" ROOT="$ROOT" python3 <<'PY' 2>/dev/null || echo "0"
import json, os, re, sys

raw = os.environ.get("PAYLOAD", "")
root = os.environ.get("ROOT", "")
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

tool = data.get("tool_name", "")
if tool not in ("Write", "Shell"):
    sys.exit(0)

if not root:
    sys.exit(0)
model_path = os.path.join(root, ".cursor", "data-model.json")
status = "pending"
if os.path.isfile(model_path):
    try:
        status = json.load(open(model_path)).get("status", "pending")
    except json.JSONDecodeError:
        pass

if status == "pending":
    print("1")
    sys.exit(0)

if tool == "Write":
    ti = data.get("tool_input") or {}
    path = str(
        ti.get("path") or ti.get("file_path") or ti.get("target_file") or ""
    ).replace("\\", "/").lstrip("./")
    if re.match(r"^(src/|app/|api/|server/|internal/|cmd/)", path):
        print("1")
        sys.exit(0)

notes = os.path.join(root, ".cursor", "implementation-notes.md")
if os.path.isfile(notes):
    print("1")
    sys.exit(0)

sys.exit(0)
PY
)

if [[ "$should_inject" != "1" ]] || [[ ! -x "$SNIPPET" ]]; then
  echo '{}'
  exit 0
fi

context=$("$SNIPPET" tool 2>/dev/null || true)
if [[ -z "$context" ]]; then
  echo '{}'
  exit 0
fi

python3 -c 'import json,sys; print(json.dumps({"additional_context": sys.stdin.read()}))' <<<"$context"
