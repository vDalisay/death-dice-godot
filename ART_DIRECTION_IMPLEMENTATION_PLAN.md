# Death Dice Art Direction Implementation Plan

Branch: feat/art-direction-pass-01  
Scope: Establish "old haunted retro machine" visual identity while preserving gameplay logic.

## Vision

Blend Pony Island machine-horror UI language with PS2/Cloverpit low-fi texture and contrast.

Design pillars:
- The game is framed as a physical machine display, not a modern app UI.
- Surfaces should feel worn, electronic, and slightly unstable.
- Reward events must produce stronger visual punctuation.
- Art ingestion should be modular so sprite/model swaps do not require scene rewrites.

## Phase Breakdown

## Phase 1: CRT Pass + Hard-Edge Theme (start now)

Goals:
- Increase CRT legibility (scanline and vignette stronger).
- Add subtle barrel distortion screen pass.
- Move UI panel language from rounded modern cards to hard-edge machine panels.

Implementation:
- Scripts/ScreenOverlay.gd
  - Raise `SCANLINE_INTENSITY` from 0.12 -> 0.24.
  - Raise `VIGNETTE_INTENSITY` from 0.35 -> 0.55.
  - Add distortion pass with new shader `res://Shaders/barrel_distortion.gdshader`.
  - Ensure overlay enable/disable toggles include distortion pass.
- Shaders/scanline.gdshader
  - Lower default `line_density` to thicker scanlines.
- Scripts/UITheme.gd
  - Set card/modal/badge corner radii to 0.
  - Add machine-border token colors and defaults.
  - Keep existing APIs intact.

Acceptance:
- Game boots without script/shader errors.
- Screen treatment is visibly more retro at rest.
- Panels appear hard-edged across HUD/shop/modals.

## Phase 2: Reward Readability & Impact

Goals:
- Improve reward clarity inspired by Vampire Survivors feedback density.

Implementation candidates:
- Add per-die floating score numbers by face type color.
- Add die landing dust puffs and keep-lock flare pulse.
- Add streak aura intensity ramp (3+ and 5+ streak states).
- Add stage-clear tally reveal with staggered count-up.

Acceptance:
- Bank, explode, and streak moments feel visibly more rewarding.
- Each major state change has a distinct visual accent.

## Phase 3: Machine Personality Layer

Goals:
- Sell the haunted-machine fiction.

Implementation candidates:
- Bust text glitch/scramble animation.
- Short static transition between stage/shop flows.
- Optional boot-sequence terminal panel for new runs.
- Rare subtle global flicker pulse.

Acceptance:
- Machine identity is obvious within first minute.
- Effects remain readable and do not hide gameplay info.

## Phase 4: Art Asset Pipeline (Sprite/Model Friendly)

Goals:
- Make replacing code-drawn primitives with hand-authored art easy.

Implementation:
- Establish `res://Art/` directory conventions.
- Add texture access helpers in `UITheme.gd` for panel frames/icons/die faces.
- Introduce sprite fallback logic (texture if present, label/glyph fallback if missing).
- Document naming conventions and 9-slice margins.

Acceptance:
- Artist can drop assets into folder and see replacement without touching scene tree.
- Missing assets gracefully fall back to current visuals.

## Test & Verification Strategy

- Run Godot project and check debug output after each phase.
- Add/adjust tests when gameplay-affecting scripts are touched.
- For visual-only changes, perform screenshot checkpoints per key screen:
  - Main roll screen
  - Bust overlay
  - Stage clear overlay
  - Shop panel
  - Stage map

## Commit Strategy

- Use small commits per phase or sub-phase.
- Suggested commit split:
  1. docs(art): add art direction implementation plan
  2. feat(vfx): crt and barrel distortion pass
  3. feat(ui): hard-edge machine panel theme tokens
  4. feat(vfx): reward readability pass
  5. feat(ui): asset ingestion pipeline scaffolding
