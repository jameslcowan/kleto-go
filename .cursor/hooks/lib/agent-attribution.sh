# Detect and fix agent Co-authored-by trailers. Source from verify-stop.sh and scripts.

AGENT_COAUTHOR_PATTERN='cursor|cursoragent|copilot|claude|anthropic|openai|github-actions|dependabot|\[bot\]'

agent_attribution_python() {
  local mode="${1:-scan}"
  python3 - "$mode" <<'PY'
import re, subprocess, sys

MODE = sys.argv[1]
pat = re.compile(r"^Co-authored-by:", re.I)
agents = re.compile(
    r"cursor|cursoragent|copilot|claude|anthropic|openai|github-actions|dependabot|\[bot\]",
    re.I,
)

def msg_has_agent_trailer(msg: str) -> list[str]:
    return [ln for ln in msg.splitlines() if pat.match(ln) and agents.search(ln)]

def strip_msg(msg: str) -> str:
    bad = set(msg_has_agent_trailer(msg))
    lines = [ln for ln in msg.splitlines() if ln not in bad]
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines) + "\n"

def all_bad_commits():
    bad = []
    log = subprocess.run(
        ["git", "log", "--format=%H"],
        capture_output=True, text=True, check=False,
    )
    for h in log.stdout.split():
        h = h.strip()
        if not h:
            continue
        msg = subprocess.run(
            ["git", "log", "-1", "--format=%B", h],
            capture_output=True, text=True, check=False,
        ).stdout
        trailers = msg_has_agent_trailer(msg)
        if trailers:
            bad.append((h, trailers))
    return bad

if MODE == "scan":
    bad = all_bad_commits()
    for h, trailers in bad:
        print(h)
        for t in trailers:
            print(t)
    sys.exit(0 if not bad else 1)

if MODE == "strip_file":
    print(strip_msg(sys.stdin.read()), end="")
    sys.exit(0)

if MODE == "head_only":
    bad = all_bad_commits()
    if len(bad) == 1:
        print(bad[0][0])
        sys.exit(0)
    sys.exit(1)

if MODE == "count":
    print(len(all_bad_commits()))
    sys.exit(0)
PY
}

agent_attribution_scan() {
  agent_attribution_python scan 2>/dev/null || true
}

agent_attribution_count() {
  agent_attribution_python count 2>/dev/null || echo 0
}

ensure_cli_attribution_disabled() {
  local cfg="${HOME}/.cursor/cli-config.json"
  [[ -f "$cfg" ]] || return 0
  python3 - "$cfg" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
attr = data.setdefault("attribution", {})
changed = False
for key in ("attributeCommitsToAgent", "attributePRsToAgent"):
    if attr.get(key):
        attr[key] = False
        changed = True
if changed:
    path.write_text(json.dumps(data, indent=2) + "\n")
    print("disabled cli-config attribution")
PY
}

fix_agent_attribution_history() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  local count
  count=$(agent_attribution_count)
  [[ "${count:-0}" -eq 0 ]] && return 0

  ensure_cli_attribution_disabled >/dev/null 2>&1 || true

  if [[ -n $(git status --porcelain) ]]; then
    return 1
  fi

  if git remote 2>/dev/null | grep -q .; then
    return 2
  fi

  # Single bad commit at HEAD → amend (faster than filter-branch)
  if [[ "$count" -eq 1 ]] && agent_attribution_python head_only >/dev/null 2>&1; then
    local newmsg
    newmsg=$(git log -1 --format=%B | agent_attribution_python strip_file)
    git commit --amend -m "$newmsg" --no-verify >/dev/null 2>&1
    return 0
  fi

  FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter \
    'python3 -c "
import sys, re
pat = re.compile(r\"^Co-authored-by:\", re.I)
agents = re.compile(r\"cursor|cursoragent|copilot|claude|anthropic|openai|github-actions|dependabot|\[bot\]\", re.I)
msg = sys.stdin.read()
lines = [ln for ln in msg.splitlines() if not (pat.match(ln) and agents.search(ln))]
while lines and not lines[-1].strip():
    lines.pop()
print(chr(10).join(lines))
print()
"' -- --all >/dev/null 2>&1

  git for-each-ref --format='%(refname)' refs/original/ 2>/dev/null \
    | xargs -r git update-ref -d >/dev/null 2>&1 || true

  return 0
}
