# Audio Parity Plan

This document inventories the audio content that ships with the legacy pygame client and describes the behaviour we need to reach feature parity inside the Godot project.

## High-level goals

- Preserve the same set of background music (BGM), ambient loops, and sound effects that the pygame build exposes.
- Mirror pygame runtime behaviour: menu state changes, atmospheric effects, weapon usage, bursts, and missiles should trigger the same cues.
- Keep asset layout compatible with the existing Godot `assets/` tree so `.import` metadata continues to work.
- Route playback through the `Music` and `SFX` audio buses so user volume preferences (`master`, `music`, `sfx`) continue to apply.

## Asset inventory

| Category | Source folder | Notes |
| --- | --- | --- |
| Main menu music | `assets/sounds/music/main-menu.mp3` | Loops on the main menu. |
| Character select music | `assets/sounds/music/character-select.mp3` | Loops while on the roster screen. |
| Battle music pool | `assets/sounds/music/battle/` | Random pick per match: `battle.mp3`, `MARIAN TIME TRAVEL (Remix)` variants. |
| Victory / defeat jingles | `assets/sounds/music/victory.mp3`, `assets/sounds/music/defeat.mp3` | Triggered when result screens display. |
| Ambient rain | `assets/sounds/sfx/environment/rain/rain_bkg.ogg` | Loop while rain weather active. |
| Thunder stingers | `assets/sounds/sfx/environment/rain/Thunder_[A-C].ogg` | Randomized on lightning events. |
| Ambient snow | `assets/sounds/sfx/environment/snow/snow_wind.mp3` | Loop while snow weather active. |
| Enemy growl SFX | `assets/sounds/sfx/growl.mp3` | Reserved for enemy telegraphing (currently unused in pygame but kept for parity). |
| Weapon fire / reload SFX | `assets/sounds/sfx/weapons/<type>/` | See table below for per-weapon files. |
| Rocket loop / explosion | `assets/sounds/sfx/weapons/rocket/rocket_fly.mp3`, `rocket_explosion.mp3` | Loop during flight, play once on detonation. |
| Burst voice lines | `assets/images/Characters/<name>/burst.(wav/mp3)` | Per-character clip, prefer `.wav` if available. Fallback folder: `assets/sounds/voices/<name>_burst.wav` (legacy). |

### Weapon audio details

| Weapon type | Directory | Fire variants | Reload clip | Specials |
| --- | --- | --- | --- | --- |
| Assault Rifle | `assets/sounds/sfx/weapons/AR/` | `fire_AR.mp3` | `reload_AR.mp3` | — |
| SMG | `assets/sounds/sfx/weapons/SMG/` | `fire1_SMG.mp3` … `fire4_SMG.mp3` | `reload_SMG.mp3` | — |
| Shotgun | `assets/sounds/sfx/weapons/shotgun/` | `fire_shotgun.mp3` | `reload_shotgun.mp3` | — |
| Sniper | `assets/sounds/sfx/weapons/sniper/` | `fire_sniper.mp3` | `reload_sniper.mp3` | — |
| Rocket Launcher | `assets/sounds/sfx/weapons/rocket/` | `fire_rocket.mp3` | `reload_rocket.mp3` | `rocket_fly.mp3` loop, `rocket_explosion.mp3` impact |
| Sword | `assets/sounds/sfx/weapons/sword/` | `fire1_sword.mp3` … `fire4_sword.mp3` | — | `special_sword.mp3` |
| Minigun | `assets/sounds/sfx/weapons/minigun/` | `fire1_minigun.mp3` … `fire3_minigun.mp3` (legacy `old.mp3`) | `reload_minigun.mp3` | — |

## Behavioural requirements from pygame

- **Menu flow**: `MenuMusicManager` calls `play_music()` with main-menu, character-select, and random battle tracks depending on the active menu. Godot needs an equivalent `MenuMusicController` or reuse of `AudioDirector` to switch playlists.
- **Battle start**: when gameplay begins, select a random `battle/*.mp3` track. When combat ends, transition into victory/defeat stingers before returning to menu music.
- **Atmospheric effects**: the pygame `AtmosphericEffects` system swaps ambient loops (`rain_bkg`, `snow_wind`) and sprinkles thunder stingers via `play_sound()`. Godot’s weather controller must trigger the same assets.
- **Weapon handling**: firing and reloading call into `audio_manager.play_weapon_*` with weapon names. Godot needs a mapping from weapon resource names to the same directories, including cycling through multiple fire clips and respecting special attack variants.
- **Rocket projectiles**: missiles request a looping flight channel (stopped when the missile exits) and an explosion clip. Grenades skip the loop but still use explosions.
- **Burst abilities**: triggering a burst plays the associated character voice line. Prefer `.wav` assets for accurate duration; fall back to `.mp3` if `wav` is missing.

## Godot implementation plan

1. **Extend `AudioDirector`** to cache `AudioStream`s, support cross-fades, and expose helper methods (`play_music_by_path`, `play_sfx_by_path`, `play_loop_with_handle` for rockets).
2. **Asset registration** by adding `AudioStream` resources or using `AudioStreamRandomizer` for weapon fire rotations, mirroring pygame’s cycling behaviour.
3. **Menu hooks**: update menu scenes (`MainMenu`, `CharacterSelectMenu`, world intro) to notify `AudioDirector` when state changes.
4. **Gameplay hooks**: integrate with weapon fire/reload signals, rocket controller, burst system, and weather service to request appropriate streams.
5. **Configuration**: surface master/music/sfx bus sliders in settings, persisting values via `ConfigService` (already stubbed in `GameManager`).
6. **Testing**: add sanity checks (Godot unit tests or debug outputs) verifying that each gameplay event produces the expected bus activity, plus a simple runtime diagnostics overlay for missing streams.

## Current status

- All pygame audio assets already exist under `assets/sounds/` and have corresponding `.import` metadata.
- Godot `AudioDirector` stub handles basic playback but lacks caching, cross-fading, and loop controls needed for rocket flight and ambience.
- No gameplay scripts currently request audio playback; wiring remains to be implemented.

## Next steps

1. Implement audio stream loaders and caching inside `AudioDirector`.
2. Create helper methods for menu/gameplay systems to request named clips without hardcoding file paths in multiple scripts.
3. Start wiring menu scenes and the world controller to trigger music and ambience changes.
4. Extend weapon, burst, and projectile scripts to emit audio events routed through `AudioDirector`.
5. Document usage patterns and add regression checks once playback is functional.
