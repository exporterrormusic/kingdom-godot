# Godot Main Menu Parity Notes

This document captures how the new Godot main menu mirrors the pygame reference implementation.

## Layout
- **Title block**: Central panel with the same bold all-caps title and subtitle treatment. The subtitle and separator mirror the muted blue-gray palette used in pygame.
- **Bottom menu bar**: Horizontal tray that spans most of the width, matching the HoloCure-inspired button rail from the original project. Buttons now default to wide, tall cards with icons in the upper region and labels near the bottom edge.
- **Version + metadata**: Version text anchored to the bottom-right corner so the build stamp never overlaps the menu bar.

## Background treatment
- `VenetianBlindsBackground` reimplements the rotating venetian blind carousel.
  - Loads the original background set (`assets/images/Menu/BKG/*.jpg`).
  - Slices the textures into angled quads sized by screen height, animating them based on elapsed time.
  - Draws thin edge highlights plus a translucent overlay to retain readability, just like pygame.

## Button behaviour
- `MainMenuOptionButton` renders its own `StyleBoxFlat` states to mimic the pygame styling:
  - Non-play buttons use dark metals; the PLAY button is the signature white card with gray typography.
  - Selection toggles inner/outer glows and brightens the text/icon colors.
- `MainMenuIcon` draws icons procedurally (crown, trophy, bag, play triangle, outpost house, cog, quit X) so we stay true to the inline vector art used in pygame without shipping separate textures.
- Keyboard navigation cycles left/right and triggers ENTER/SPACE selections. Hovering with the mouse updates selection in lock-step with keyboard input.

## Signal mapping
- Buttons emit the same semantic actions as pygame: leaderboards, achievements, shop, play, outpost, settings, quit.
- Placeholder actions trigger an `AcceptDialog` so the user sees a clear "not available yet" message while still logging the signal for future wiring.

## Integration hooks
- `MainMenu` keeps the direct `start_game_requested` / `settings_requested` signals used by `GameManager`.
- The root control is set to `PROCESS_MODE_ALWAYS` so `_unhandled_input` still works while paused or overlayed.
- `set_last_selected_character()` updates the caption in the title block, keeping parity with pygame’s last-run character indicator.

## Follow-up ideas
- Swap the procedural icons with SVG textures if art arrives later.
- Drive the title typography from a dedicated theme resource so it can change by locale.
- Replace placeholder dialogs with the actual leaderboards, achievements, and outpost UIs when those screens land.
