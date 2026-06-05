# kleto-go

Cursor app template — reusable starting point for new projects. Ships with **always-on** agent rules and project config so agents micro-commit and run with full access without asking.

## What's included

| Rule / config | Purpose |
|---------------|---------|
| `micro-commits` | Auto-commit each step; one concern; small diffs |
| `git-safety` | Safe git; micro-commit always; push only when asked |
| `project-full-access` | Every `Shell` uses `required_permissions: ["all"]`; never ask |
| `agent-workflow` | Template rules override conflicting global user rules |
| `coding-principles` | Small diffs, match conventions |
| `.cursor/cli.json` | CLI: sandbox off, broad tool allowlist |
| `.cursor/hooks.json` | `stop` hook loops until working tree is clean |

Rules: [`.cursor/rules/`](.cursor/rules/) (`.mdc`, `alwaysApply: true`).

## Why rules + hook + cli.json

| Problem | Fix |
|---------|-----|
| Global user rule “only commit when asked” | `agent-workflow`: template rules win |
| Agent asks “should I commit?” | `micro-commits` + `stop` hook follow-up |
| Agent asks for sandbox permission | `project-full-access`: always pass `all` on `Shell` |
| CLI still prompts every tool | `.cursor/cli.json` allowlist + sandbox disabled |

## One-time setup (IDE)

After clone, in **Cursor Settings → Agent** (wording may vary by version):

1. **Trust this workspace** — required for project hooks.
2. **Auto-run / Run everything** — auto-approve agent tools (complements `.cursor/cli.json` for CLI).

Reload hooks: save `.cursor/hooks.json` or restart Cursor.

## Use as a GitHub template

1. Create a repo from this template.
2. Add app code, stack, CI.
3. Add stack-specific rules (e.g. `globs: **/*.go`).
4. Keep `cli.json`, hooks, and autonomy rules unless you intentionally relax them.

## License

Add a license when you publish (e.g. MIT).
