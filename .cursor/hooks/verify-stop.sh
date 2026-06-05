#!/usr/bin/env bash
# Unified stop hook: loops until git clean, verify commands pass, and no staged secrets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/checks.sh
source "${SCRIPT_DIR}/lib/checks.sh"

payload=$(cat)

status=$(printf '%s' "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','completed'))" 2>/dev/null || echo "completed")
loop_count=$(printf '%s' "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('loop_count',0))" 2>/dev/null || echo "0")

if [[ "$status" != "completed" ]]; then
  echo '{}'
  exit 0
fi

# Auto-repair agent Co-authored-by trailers and disable Cursor attribution (see fix-agent-attribution skill)
fix_agent_attribution_history || true

CHECK_ISSUES=()
check_cli_attribution_config
check_git_clean
check_staged_secrets
check_agent_attribution
check_project_verify ".cursor/verify.json"

if [[ ${#CHECK_ISSUES[@]} -eq 0 ]]; then
  echo '{}'
  exit 0
fi

footer=$(rule_reinforcement_footer "$loop_count")
issues_file=$(mktemp)
trap 'rm -f "$issues_file"' EXIT
printf '%s\n' "${CHECK_ISSUES[@]}" > "$issues_file"

python3 - "$loop_count" "$footer" "$issues_file" <<'PY'
import json, sys

loop_count = int(sys.argv[1])
footer = sys.argv[2]
issues_path = sys.argv[3]
with open(issues_path) as f:
    issues = [line.strip() for line in f if line.strip()]

blocks = []
for line in issues:
    parts = line.split("|", 3)
    kind = parts[0] if parts else "ISSUE"
    title = parts[1] if len(parts) > 1 else line
    action = parts[2] if len(parts) > 2 else ""
    detail = (parts[3] if len(parts) > 3 else "").replace("\\n", "\n")
    blocks.append(f"## {kind}: {title}\n{action}\n\n{detail}".strip())

msg = (
    "Stop-hook reinforcement: resolve ALL sections below before ending the turn. "
    "Do not ask the user for permission — Shell with required_permissions [\"all\"], "
    "micro-commit per .cursor/rules/micro-commits.mdc.\n\n"
    + "\n\n".join(blocks)
    + "\n\n---\n"
    + footer
)
if loop_count >= 2:
    msg += "\n\nPrioritize the first failing check; avoid drive-by refactors."

print(json.dumps({"followup_message": msg}))
PY
