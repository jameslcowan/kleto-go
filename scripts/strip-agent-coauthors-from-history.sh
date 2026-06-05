#!/usr/bin/env bash
# Remove agent Co-authored-by trailers from all commits (local repo only).
set -euo pipefail

if [[ -n $(git status --porcelain) ]]; then
  echo "Working tree must be clean before rewriting history." >&2
  exit 1
fi

if git remote | grep -q .; then
  echo "Remotes configured — aborting to avoid rewriting pushed history." >&2
  echo "If intentional, remove remotes or use a fresh clone." >&2
  exit 1
fi

FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter '
python3 -c "
import sys, re
msg = sys.stdin.read()
lines = []
for line in msg.splitlines():
    if re.match(r\"^Co-authored-by:\", line, re.I):
        low = line.lower()
        if any(x in low for x in (
            \"cursor\", \"cursoragent\", \"copilot\", \"claude\", \"anthropic\",
            \"openai\", \"github-actions\", \"dependabot\", \"[bot]\"
        )):
            continue
    lines.append(line)
# trim trailing blank lines from removed trailers
while lines and not lines[-1].strip():
    lines.pop()
print(chr(10).join(lines))
print()
"
' -- --all

echo "Done. Verify with: git log --grep='Co-authored-by' --oneline"
