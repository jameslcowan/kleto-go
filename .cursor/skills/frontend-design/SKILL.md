---
name: frontend-design
description: >-
  Create distinctive, production-grade frontend interfaces. Use when building
  web components, pages, or apps. Avoid generic AI aesthetics. Based on Anthropic
  frontend-design skill (see NOTICE.md).
---
# Frontend design

Guides creation of distinctive, production-grade interfaces. Implement **working code** with intentional aesthetics.

Upstream inspiration: [anthropics/claude-code frontend-design skill](https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md).

## Prerequisites

- **Data-first** — `.cursor/data-model.json` confirmed; UI states map to real entities
- **Systems engineering** — requirements and verification questions answered with the user

## Design thinking (before code)

Understand context; commit to a **bold** direction:

- **Purpose** — problem, users, constraints
- **Tone** — e.g. brutal minimal, maximalist, retro-futuristic, editorial, industrial (pick one; execute precisely)
- **Differentiation** — one memorable idea

Bold maximalism and refined minimalism both work; **intentionality** beats intensity.

## Aesthetics guidelines

- **Typography** — distinctive display + refined body; avoid Arial, Inter, Roboto as defaults
- **Color** — cohesive theme via CSS variables; dominant + accent beats timid evenly-distributed palettes
- **Motion** — high-impact moments (page load, stagger) over noise; CSS-first for static; Motion for React when present
- **Layout** — asymmetry, overlap, grid-breaking, deliberate density or negative space
- **Atmosphere** — gradients, grain, texture, depth — not flat purple-on-white clichés

**Never** converge on the same “AI slop” palette, font, or layout every project.

Match code complexity to the vision: elaborate effects only when the concept demands them.

## Agent duties

- Ask the user about brand/constraints when unknown (`AskQuestion`)
- Run build/lint yourself — do not ask the user to run scripts
- Micro-commit UI changes per `micro-commits.mdc`
