# kleto-go

Cursor app template — reusable starting point for new projects. Ships with **always-on** agent rules so every session gets the same baseline behavior.

## What's included

| Rule | Purpose |
|------|---------|
| `micro-commits` | Atomic commits; one concern, minimal diff, friendly to AI context |
| `git-safety` | Safe git/PR habits; no force-push, secrets, or surprise commits |
| `coding-principles` | Small diffs, match conventions, meaningful tests only |
| `agent-workflow` | Investigate with tools, respect skills and user intent |

Rules live in [`.cursor/rules/`](.cursor/rules/) as `.mdc` files with `alwaysApply: true`.

## Use as a GitHub template

1. Create a new repository from this template (or clone and rename).
2. Add your app code, stack, and CI.
3. Add project-specific rules in `.cursor/rules/` (file globs or extra always-on rules).
4. Optionally copy user-level rules from your Cursor settings into project rules for team consistency.

## Customizing

- **One concern per rule file** — keep each rule short and actionable.
- **Micro-commits** — tighten or relax file-count guidance per team; keep "one logical unit per commit" as the default.
- **Stack rules** — add e.g. `globs: **/*.go` or `**/*.tsx` for language/framework conventions.

## License

Add a license when you publish the template (e.g. MIT).
