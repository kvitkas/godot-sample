#!/usr/bin/env python3
"""Lightweight repository validation for this self-contained Godot sample.

This does not replace Godot's importer, but it catches broken resource paths,
missing input actions, duplicate class names, and common text/syntax accidents
before the project is opened in the editor.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_ACTIONS = {
    "move_left",
    "move_right",
    "move_up",
    "move_down",
    "dash",
    "pulse",
    "restart",
    "pause_game",
    "upgrade_1",
    "upgrade_2",
    "upgrade_3",
}


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(1)


def strip_gd_comments_and_strings(text: str) -> str:
    out: list[str] = []
    in_string = False
    quote = ""
    escape = False
    i = 0
    while i < len(text):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                in_string = False
            out.append(" ")
        else:
            if ch in {'"', "'"}:
                in_string = True
                quote = ch
                out.append(" ")
            elif ch == "#":
                while i < len(text) and text[i] != "\n":
                    out.append(" ")
                    i += 1
                continue
            else:
                out.append(ch)
        i += 1
    return "".join(out)


def check_balanced(path: Path, text: str) -> None:
    cleaned = strip_gd_comments_and_strings(text)
    pairs = {"(": ")", "[": "]", "{": "}"}
    closers = {v: k for k, v in pairs.items()}
    stack: list[tuple[str, int]] = []
    line = 1
    for ch in cleaned:
        if ch == "\n":
            line += 1
        elif ch in pairs:
            stack.append((ch, line))
        elif ch in closers:
            if not stack or stack[-1][0] != closers[ch]:
                fail(f"{path}: unmatched {ch!r} near line {line}")
            stack.pop()
    if stack:
        ch, line = stack[-1]
        fail(f"{path}: unclosed {ch!r} from line {line}")


def main() -> int:
    project = ROOT / "project.godot"
    scene = ROOT / "scenes" / "Main.tscn"
    if not project.exists():
        fail("project.godot is missing")
    if not scene.exists():
        fail("scenes/Main.tscn is missing")

    project_text = project.read_text()
    for action in sorted(REQUIRED_ACTIONS):
        if not re.search(rf"^{re.escape(action)}=", project_text, re.MULTILINE):
            fail(f"project.godot missing input action {action}")

    scene_text = scene.read_text()
    for match in re.finditer(r'path="res://([^"]+)"', scene_text):
        rel = match.group(1)
        if not (ROOT / rel).exists():
            fail(f"scene references missing resource res://{rel}")

    class_names: dict[str, Path] = {}
    for path in sorted((ROOT / "scripts").glob("*.gd")):
        text = path.read_text()
        check_balanced(path.relative_to(ROOT), text)
        for preload in re.findall(r'preload\("res://([^"\)]+)"\)', text):
            if not (ROOT / preload).exists():
                fail(f"{path}: missing preload res://{preload}")
        match = re.search(r"^class_name\s+(\w+)", text, re.MULTILINE)
        if match:
            name = match.group(1)
            if name in class_names:
                fail(f"duplicate class_name {name}: {class_names[name]} and {path}")
            class_names[name] = path

    expected_scripts = {
        "scripts/main.gd",
        "scripts/player.gd",
        "scripts/enemy.gd",
        "scripts/coin.gd",
        "scripts/projectile.gd",
        "scripts/hud.gd",
    }
    missing = [p for p in expected_scripts if not (ROOT / p).exists()]
    if missing:
        fail(f"missing scripts: {', '.join(sorted(missing))}")

    print("Static project validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
