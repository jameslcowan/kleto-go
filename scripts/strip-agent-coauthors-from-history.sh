#!/usr/bin/env bash
# Remove agent Co-authored-by trailers from all commits (local repo only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../.cursor/hooks/lib/agent-attribution.sh
source "${ROOT}/.cursor/hooks/lib/agent-attribution.sh"

if [[ -n $(git status --porcelain) ]]; then
  echo "Working tree must be clean before rewriting history." >&2
  exit 1
fi

if git remote 2>/dev/null | grep -q .; then
  echo "Remotes configured — aborting to avoid rewriting pushed history." >&2
  exit 1
fi

count=$(agent_attribution_count)
if [[ "${count:-0}" -eq 0 ]]; then
  echo "No agent Co-authored-by trailers found."
  exit 0
fi

ensure_cli_attribution_disabled
fix_agent_attribution_history
echo "Rewrote ${count} commit(s) with agent trailers. Verify: ./scripts/verify-cursor-autonomy.sh"
