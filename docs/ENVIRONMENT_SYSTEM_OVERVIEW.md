# Environment System Overview

This document outlines the shader-driven, procedural world dressing pipeline introduced for the Godot migration. The system replaces the static tile background with dynamic biomes, time-of-day presets, and lightweight decoration spawning that reacts to wind parameters.

## Architecture

- **EnvironmentController (`src/world/environment/environment_controller.gd`)**: A `Node2D` responsible for configuring shaders, ambient lighting, fog overlays, and prop placement. The node is part of `WorldScene.tscn` as `%Environment` and exposes exported arrays for biome and time-of-day resources.
- **BiomeDefinition (`src/world/environment/biome_definition.gd`)**: Resource describing palette values, shader noise characteristics, wind strength, and decoration options for a biome.
- **TimeOfDayDefinition (`src/world/environment/time_of_day_definition.gd`)**: Resource encapsulating ambient tinting, fog color, and light direction/energy for a lighting preset.
- **Procedural Ground Shader (`resources/shaders/procedural_ground.gdshader`)**: Canvas shader authored for `Polygon2D` ground geometry. It blends multiple layers of value noise, patchwork, and animated sine waves to produce terrain variation that drifts subtly over time.

## Runtime Flow

1. `WorldController` calls `_configure_environment()` during `_ready()`. It seeds the controller (randomized per run unless an override is set) and requests the configured biome/time-of-day pair.
2. `EnvironmentController` selects the requested resources (or random fallbacks), applies shader parameters, adjusts ambient lighting via `CanvasModulate`, and spawns decoration sprites around the playfield.
3. Decoration sprites sway based on the biome wind strength while the shader material receives a continuous `time_flow` uniform for animated highlights.
4. Consumers can call `WorldController.set_environment_profile(biome_id, time_of_day_id, seed)` to force a specific look or `WorldController.randomize_environment(seed)` to regenerate the scene mid-run.

## Authoring New Biomes

1. Duplicate one of the sample `.tres` files in `resources/world/biomes/`.
2. Adjust palette fields (`base_color`, `secondary_color`, `accent_color`, etc.) and tune the noise parameters (`noise_scale`, `detail_strength`, `wave_speed`, `patchwork_strength`).
3. Provide one or more decoration textures. These are sampled at runtime with random rotation, scale, and sway.
4. Set spawn density (`decoration_count`) and spawn radius. Decorations are evenly distributed inside the defined radius using a disk sampling routine.

## Authoring Time-of-Day Presets

The project now ships with two lighting presets: **Day** and **Night**. Day keeps colors bright and neutral, while Night shifts the scene toward a cool blue palette with reduced energy for the key light. Future variations can still be added by duplicating one of these `.tres` files if design needs expand.

When crafting a new preset:

1. Duplicate `resources/world/time_of_day/day.tres` or `night.tres`.
2. Update `ambient_tint`/`ambient_intensity` for overall brightness.
3. Configure `sky_tint`, `fog_color`, and `fog_alpha` for the atmospheric wash.
4. Tune directional light values (`light_color`, `light_energy`, `light_angle_degrees`). The controller updates `DirectionalLight2D` to match.

## Editor Configuration

`WorldScene.tscn` now ships with four biomes (`grasslands`, `dunes`, `snowfield`, `sakura_grove`) and two time-of-day presets (`day`, `night`). Designers can reorder or add resources directly from the inspector. When authoring new maps, pick from these IDs or duplicate them to introduce new looks later.

`EnvironmentController` exports the following notable flags:

- `auto_initialize`: Defaults to `false` in the scene so `WorldController` drives seeding. Enable for standalone testing.
- `use_fixed_seed`: When true, the controller reuses `environment_seed` for deterministic runs.
- `ground_extent`: Controls the polygon bounds for ground and fog overlays (default 4096 pixels).

## Future Extensions

- Introduce per-biome prop scenes with physics bodies for true obstacles.
- Add weather emitters (rain, snow) via particle nodes seeded from the same controller.
- Integrate run configuration UI to let players choose biome/time-of-day explicitly before a match.
