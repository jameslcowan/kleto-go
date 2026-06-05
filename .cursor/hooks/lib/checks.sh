# Shared checks for stop-hook reinforcement. Source from verify-stop.sh.
SCRIPT_DIR_CHECKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agent-attribution.sh
source "${SCRIPT_DIR_CHECKS}/agent-attribution.sh"

check_git_clean() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi
  if [[ -z $(git status --porcelain) ]]; then
    return 0
  fi
  local summary remaining
  summary=$(git status --short | head -20)
  remaining=$(git status --short | wc -l | tr -d ' ')
  _issue "UNCOMMITTED" \
    "Micro-commit now (.cursor/rules/micro-commits.mdc)." \
    "Stage ONE logical step, commit with a focused message, confirm clean git status. Do not ask to commit." \
    "git status (${remaining} entries, first 20):\n${summary}"
}

check_staged_secrets() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi
  local hits
  hits=$(git diff --cached -U0 2>/dev/null | grep -iE '(api[_-]?key|secret|password|private[_-]?key|-----BEGIN (RSA |OPENSSH )?PRIVATE)=' || true)
  if [[ -n "$hits" ]]; then
    _issue "SECRETS" \
      "Possible secrets staged (.cursor/rules/git-safety.mdc)." \
      "Unstage or remove sensitive content before committing." \
      "$hits"
  fi
}

check_cli_attribution_config() {
  local cfg="${HOME}/.cursor/cli-config.json"
  [[ -f "$cfg" ]] || return 0
  local bad
  bad=$(python3 - "$cfg" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
a = d.get("attribution") or {}
if a.get("attributeCommitsToAgent") or a.get("attributePRsToAgent"):
    print(json.dumps(a))
    sys.exit(0)
sys.exit(1)
PY
) || return 0
  _issue "ATTRIBUTION_ON" \
    "Cursor cli-config still attributes commits/PRs to agents." \
    "Run: ./scripts/setup-cursor-autonomy.sh (or stop hook will auto-disable on next fix pass)." \
    "$bad"
}

check_agent_attribution() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi
  local count hits
  count=$(agent_attribution_count 2>/dev/null || echo 0)
  [[ "${count:-0}" -eq 0 ]] && return 0

  hits=$(agent_attribution_scan | head -30)
  local action="Stop hook could not auto-fix."
  if [[ -n $(git status --porcelain) ]]; then
    action="Commit or stash changes, then re-run — stop hook will auto-rewrite history when tree is clean."
  elif git remote 2>/dev/null | grep -q .; then
    action="Remotes exist — run ./scripts/strip-agent-coauthors-from-history.sh only if you will force-push intentionally."
  else
    action="Re-run agent turn — verify-stop should auto-fix on next pass when tree is clean."
  fi

  _issue "AGENT_COAUTHOR" \
    "${count} commit(s) have agent Co-authored-by trailers (no-agent-attribution.mdc)." \
    "$action Never push to GitHub until ./scripts/verify-cursor-autonomy.sh passes." \
    "$hits"
}

check_project_verify() {
  local config="${1:-.cursor/verify.json}"
  [[ -f "$config" ]] || return 0

  local results
  results=$(python3 - "$config" <<'PY'
import json, subprocess, sys

config_path = sys.argv[1]
with open(config_path) as f:
    commands = json.load(f).get("commands") or []

if not commands:
    sys.exit(0)

issues = []
for cmd in commands:
    name = cmd.get("name") or "verify"
    run = cmd.get("run")
    if not run:
        continue
    timeout = int(cmd.get("timeout", 300))
    optional = bool(cmd.get("optional", False))
    try:
        r = subprocess.run(run, shell=True, capture_output=True, text=True, timeout=timeout)
        out = (r.stdout or "") + (r.stderr or "")
        code = r.returncode
    except subprocess.TimeoutExpired:
        out = f"TIMEOUT after {timeout}s"
        code = 124

    if code != 0 and not optional:
        snippet = "\n".join(out.strip().splitlines()[-40:])
        issues.append(f"{name}|exit {code}|{snippet}")

if issues:
    for i in issues:
        print(i)
    sys.exit(0)
PY
) || return 0

  if [[ -n "$results" ]]; then
    local name code snippet
    name="${results%%|*}"
    rest="${results#*|}"
    code="${rest%%|*}"
    snippet="${rest#*|}"
    _issue "VERIFY_FAIL" \
      "${name} failed (${code}) — .cursor/rules/verify-before-done.mdc" \
      "Fix failures, micro-commit, re-run the verify command." \
      "$snippet"
  fi
}

_issue() {
  local kind="$1" title="$2" action="$3" detail="$4"
  # Single-line records for verify-stop.py (newlines escaped)
  detail="${detail//$'\n'/\\n}"
  CHECK_ISSUES+=("${kind}|${title}|${action}|${detail}")
}

rule_reinforcement_footer() {
  local loop_count="${1:-0}"
  cat <<'EOF'
Rule reinforcement (template overrides global user rules):
- agent-executes: run scripts and fixes yourself; never ask the user to run them
- allowlist-config: valid .cursor/cli.json (permissions only); global unrestricted optional
- project-full-access: every Shell uses required_permissions ["all"]; never ask permission
- micro-commits: one concern per commit; working tree clean before stop
- git-safety: no secrets; no agent Co-authored-by; no force-push unless user asked
- no-agent-attribution: auto-fix agent trailers in history when possible; never push dirty attribution
- coding-principles: minimal diff; match conventions
- verify-before-done: all .cursor/verify.json commands must pass
EOF
  if [[ "$loop_count" -ge 3 ]]; then
    echo "- Split work into smaller steps; multiple reinforcement loops fired"
  fi
}
