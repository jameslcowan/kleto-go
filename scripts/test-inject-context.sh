#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL="$ROOT/.cursor/data-model.json"

python3 - "$ROOT" "$MODEL" <<'PY'
import json, os, shutil, subprocess, sys

root, model = sys.argv[1], sys.argv[2]
snippet = os.path.join(root, ".cursor/hooks/lib/build-context-snippet.py")
inject = os.path.join(root, ".cursor/hooks/inject-context.sh")
pre = os.path.join(root, ".cursor/hooks/data-first-pre-tool.sh")

bak = model + ".testbak"
shutil.copy(model, bak)
try:
    with open(model) as f:
        data = json.load(f)

    text = subprocess.check_output([snippet, "session"], text=True)
    assert "data-model status" in text, text

    data["status"] = "pending"
    with open(model, "w") as f:
        json.dump(data, f)

    payload = json.dumps({
        "tool_name": "Write",
        "tool_input": {"path": "src/main.go"},
    })
    p = subprocess.run([pre], input=payload, capture_output=True, text=True)
    assert p.returncode == 2, (p.returncode, p.stdout, p.stderr)

    data["status"] = "confirmed"
    with open(model, "w") as f:
        json.dump(data, f)
    p2 = subprocess.run([pre], input=payload, capture_output=True, text=True)
    assert p2.returncode == 0, (p2.returncode, p2.stdout)

    data["status"] = "pending"
    with open(model, "w") as f:
        json.dump(data, f)
    out = subprocess.check_output(
        [inject],
        input=json.dumps({"tool_name": "Write", "tool_input": {"path": "README.md"}}),
        text=True,
    )
    assert "additional_context" in out, out
finally:
    shutil.move(bak, model)

print("inject-context tests passed")
PY
