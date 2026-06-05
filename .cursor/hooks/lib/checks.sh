# Shared checks for stop-hook reinforcement. Source from verify-stop.sh.

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
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local name code snippet
      name="${line%%|*}"
      rest="${line#*|}"
      code="${rest%%|*}"
      snippet="${rest#*|}"
      _issue "VERIFY_FAIL" \
        "${name} failed (${code}) — .cursor/rules/verify-before-done.mdc" \
        "Fix failures, micro-commit, re-run the verify command." \
        "$snippet"
    done <<< "$results"
  fi
}

_issue() {
  local kind="$1" title="$2" action="$3" detail="$4"
  CHECK_ISSUES+=("${kind}|${title}|${action}|${detail}")
}

rule_reinforcement_footer() {
  local loop_count="${1:-0}"
  cat <<'EOF'
Rule reinforcement (template overrides global user rules):
- project-full-access: every Shell uses required_permissions ["all"]; never ask permission
- micro-commits: one concern per commit; working tree clean before stop
- git-safety: no secrets in commits; no force-push unless user asked
- coding-principles: minimal diff; match conventions
- verify-before-done: all .cursor/verify.json commands must pass
EOF
  if [[ "$loop_count" -ge 3 ]]; then
    echo "- Split work into smaller steps; multiple reinforcement loops fired"
  fi
}
