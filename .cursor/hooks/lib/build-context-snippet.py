#!/usr/bin/env python3
"""Build short context snippets for sessionStart / postToolUse injection."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def _root() -> Path:
    return Path(__file__).resolve().parents[3]


def load_data_model(root: Path) -> dict:
    path = root / ".cursor" / "data-model.json"
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}


def load_notes_excerpt(root: Path, max_lines: int = 12) -> str:
    path = root / ".cursor" / "implementation-notes.md"
    if not path.is_file():
        return ""
    lines = path.read_text().splitlines()[:max_lines]
    return "\n".join(lines).strip()


def build(mode: str = "session") -> str:
    root = _root()
    model = load_data_model(root)
    status = model.get("status", "pending")
    parts: list[str] = []

    if mode == "session":
        parts.append("kleto-go context (sessionStart):")
    else:
        parts.append("kleto-go context (post-tool):")

    parts.append(f"- data-model status: {status}")
    if model.get("summary"):
        parts.append(f"- summary: {model['summary']}")
    entities = model.get("entities") or []
    if entities:
        parts.append(f"- entities: {', '.join(str(e) for e in entities)}")

    if status == "pending":
        parts.append(
            "- ACTION: Ask user how data is modeled (AskQuestion) before app-layer "
            "code in src/, app/, api/, etc. Update .cursor/data-model.json."
        )
    elif status == "waived":
        parts.append("- data-first waived for this spike; record reason in summary.")

    notes = load_notes_excerpt(root)
    if notes:
        parts.append("- implementation-notes excerpt:")
        parts.append(notes)

    return "\n".join(parts)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "session"
    print(build(mode))
