# Kingdom (Godot Edition)

A fast-paced twin-stick shooter rebuilt in Godot using the original Pygame release as a gameplay reference. Fight escalating waves of enemies, leverage character-specific burst abilities, and swap between a full arsenal of distinct weapons while exploring the enhanced Godot toolchain.

## Quick Start

### Play In-Editor (Recommended)
1. Install [Godot 4.2](https://godotengine.org).
2. Clone this repository and open the root folder (`NIKKE-GODOT`) in Godot.
3. Press `F5` to run the game directly from the editor.

### Export a Standalone Build
1. Install export templates that match your Godot version.
2. Open **Project > Export...**, choose the desired platform preset (e.g., Windows Desktop), and configure the output path.
3. Click **Export Project** to generate a runnable build.

## Gameplay Overview

- **Twin-stick controls**: Move with keyboard (WASD/Arrows) and aim with the mouse.
- **Wave-based survival**: Each wave increases enemy count, variety, and aggression.
- **Weapon variety**: Seven primary weapon classes with unique fire patterns and secondary specials.
- **Character bursts**: Every operator has a signature burst ability (activate with `Space`).
- **Boss encounters**: Major waves culminate in powerful boss fights.
- **Local multiplayer ready**: Core systems are structured for deterministic sync and future multiplayer parity.

### Default Controls

| Action | Input |
| --- | --- |
| Move | WASD / Arrow Keys |
| Aim | Mouse |
| Fire | Left Mouse Button |
| Weapon Special | Right Mouse Button |
| Dash | Shift |
| Burst Ability | Space |
| Pause | P or ESC |

## Arsenal & Burst Abilities

The Godot port preserves the weapon roster and burst kit from the Pygame CE build:

- **Assault Rifle** – Balanced automatic rifle with grenade launcher special.
- **SMG** – High rate of fire with ricochet special rounds.
- **Sniper** – Piercing beam shots; burning trail special.
- **Shotgun** – Close-range spread; penetrating V-blast on hit.
- **Rocket Launcher** – Heavy explosives with lingering inferno bursts.
- **Minigun** – Spin-up beam with chaining lightning special.
- **Sword** – Melee sweeps with beam thrust burst.

Character bursts include crowd control (Cecil, Commander), raw damage (Crown, Snow-White), sustain (Rapunzel, Sin), and utility (Wells, Trony). Full ability descriptions mirror the original release in `kingdom-pygame/docs/README.md`.

## Project Layout

```
assets/          Art, audio, data imported from the legacy build
scenes/          Godot scenes (levels, UI, actors, projectiles)
src/             Core gameplay scripts
  actors/        Player and enemy controllers
  effects/       Procedural VFX (including Snow-White beam implementation)
  services/      Global services (audio, save data, achievements)
resources/       Scriptable data assets (characters, weapons, achievements)
docs/            Design notes and migration documentation
kingdom-pygame/  Reference project (original Pygame implementation)
```

## Development Setup

1. Install Godot 4.2 and ensure it can access this repository folder.
2. (Optional) For code editing, install the GDScript language server plugin for your IDE/Editor.
3. To work with achievements or save data, inspect the JSON files under `assets/data/` and `resources/`.
4. Use the built-in Godot debugger, performance profiler, and remote inspector to diagnose runtime behavior.

### Coding Style

- Scripts use typed GDScript where possible.
- Effects leverage Godot's immediate-mode drawing (see `src/effects/`).
- Configuration is data-driven via resources (`CharacterRoster`, `WeaponCatalog`).

## Testing & Troubleshooting

- Launch the project from the editor to verify gameplay changes.
- Inspect the Godot output console for warnings related to resources or script execution.
- Ensure asset paths remain lowercase to avoid casing conflicts on case-sensitive systems.
- When porting features from the Pygame project, cross-reference logic in `kingdom-pygame/src/` and update matching Godot systems under `src/`.

## Contributing

1. Fork or create a branch from `master`.
2. Make your gameplay, content, or tooling changes in the Godot project.
3. Run and test locally via Godot (`F5`).
4. Submit a pull request describing the feature and linking to any reference material from the Pygame build.

## Credits & License

- **Original Game**: [kingdom-pygame](https://github.com/exporterrormusic/kingdom-pygame) by the same team.
- **Engine**: Godot 4
- **Assets**: Ported/remastered from the original Pygame release.

Refer to individual asset folders for licensing specifics. Contributions are welcome—open an issue or PR to discuss new features, visual improvements, or parity fixes with the Pygame version.
