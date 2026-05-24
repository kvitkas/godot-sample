# Starfall Salvage

A complete Godot 4 top-down arcade survival game built from the original prototype. Pilot a neon salvage ship through a collapsing rift, recover Rift Cores, install field upgrades, and defeat **The Anchor** to claim the Star Relic.

## Features

- Full start → play → upgrade → boss → victory/defeat loop
- Smooth top-down ship movement, dash invulnerability, and pulse blast ability
- Auto-targeting plasma blaster with multishot, piercing, damage, and fire-rate upgrades
- Five escalating sectors with procedural enemy spawns
- Four enemy archetypes plus a boss encounter
- Collectible scrap, Rift Cores, repair hearts, and final Star Relic
- Three-choice upgrade draft between sectors
- Generated neon visuals: starfield, grid arena, debris obstacles, shockwave effects, animated entities, and polished HUD
- Health, abilities, boss bar, objectives, status feed, and pause overlay
- Persistent high score saved to `user://starfall_salvage.cfg`
- No external art/audio dependencies; everything is generated with Godot nodes and GDScript drawing

## How to run

1. Open Godot 4.2 or newer.
2. Import/open `project.godot`.
3. Press **Play**.
4. Press **R** on the title screen to launch a run.

## Controls

- **WASD / Arrow keys**: Move
- **Space**: Dash through danger briefly
- **Left click**: Fire plasma blaster
- **C**: Collect coins to increase score
- **1 / 2 / 3**: Choose a field upgrade
- **P**: Pause / resume
- **R**: Restart from title, defeat, victory, or during a run
