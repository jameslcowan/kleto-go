---
name: agent-executes
description: >-
  Run all actionable work yourself — scripts, verify, setup, fixes. Never ask
  the user to run commands you can execute. Use when about to say "run this for
  me" or when session/stop reinforcement reports failures.
---
# Agent executes

## Default

Execute with `Shell` + `required_permissions: ["all"]`. Report outcomes.

## Template scripts (run, don't ask)

| Script | When |
|--------|------|
| `setup-cursor-autonomy.sh` | Session start, permission/attribution issues |
| `verify-cursor-autonomy.sh` | After setup, before done, before push |
| `strip-agent-coauthors-from-history.sh` | Agent trailers in history, auto-fix blocked |

## Reinforcement

- **sessionStart** — runs setup + verify automatically
- **stop** — verify-stop loops until checks pass

Rule: `.cursor/rules/agent-executes.mdc`
