---
name: fix-agent-attribution
description: >-
  Detect and remove agent Co-authored-by trailers from git history; disable Cursor
  attribution. Use when commits have Cursor/agent co-authors, before push, or when
  verify-stop reports AGENT_COAUTHOR.
---
# Fix agent attribution

Human-only commits. No `Co-authored-by: Cursor`, Copilot, Claude, bots, etc.

## Automatic (preferred)

The **verify-stop** hook runs `fix_agent_attribution_history` before each check pass:

1. Disables `attributeCommitsToAgent` / `attributePRsToAgent` in `~/.cursor/cli-config.json`
2. If agent trailers exist and tree is clean with no remotes → **amends HEAD** or **filter-branch** entire history
3. If fix cannot run (dirty tree / remotes) → follow-up loop tells the agent what to do

## Manual

```bash
./scripts/setup-cursor-autonomy.sh
./scripts/verify-cursor-autonomy.sh
./scripts/strip-agent-coauthors-from-history.sh   # only if verify still fails
```

## Agent duties

- Never `git commit --trailer` for agents
- After any commit, if verify reports `AGENT_COAUTHOR`: run fix script; do not push until clean
- Before first push to GitHub: `./scripts/verify-cursor-autonomy.sh` must pass

## Rules

- `no-agent-attribution.mdc` (always on)
- `git-safety.mdc` (bans trailers)
