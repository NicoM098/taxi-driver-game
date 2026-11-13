---
tags: [plan, phase]
phase: 0
status: done
---
# Phase 00 — Project Setup

**Goal:** a clean, organised Godot project that boots into an empty main scene, with input map, physics layers and autoload stubs ready.
**Depends on:** —
**Design refs:** [[Architecture]], [[Conventions]]

## Tasks
- [x] Rename project: `config/name="TaxiDriver"` in `project.godot` (decided; no git — D-007).
- [x] Create folder structure from [[Architecture]] §1.
- [x] Create autoload stubs: `EventBus`, `GameState`, `PlayerStats`, `SaveManager`, `SceneLoader` (empty but valid, typed). Register them in `project.godot`.
- [x] Define all signals listed in [[Architecture]] §3 in `EventBus` (use placeholder types until classes exist — or define classes first in `src/core/resources/` as empty `Resource` subclasses).
- [x] Input map: add all actions from [[Architecture]] §8 with **both KB+M and gamepad** bindings (controller is supported — D-008).
- [x] `InputDevice` helper: track last-used device (keyboard/mouse vs gamepad).
- [x] Physics layer names (3D) from [[Architecture]] §7.
- [x] `src/main/main.tscn` (boot) set as main scene, built per the render pipeline in [[Architecture]] §9: SubViewportContainer → SubViewport → world scene (for now `src/vehicle/test_drive.tscn`, set via Main's `start_scene` export; `game.tscn` arrives in Phase 02/03), plus a UI CanvasLayer.
- [x] PS1 pipeline (D-010 accepted): `ps1_world.gdshader` (vertex snap + affine UV + albedo colour + optional texture + vertex colour), `ps1_post.gdshader` (Bayer dither + 5-bit quantise), global shader uniforms for strength, debug key to toggle the effect. See [[Art Direction]].
- [x] Flat-colour material presets in `res://assets/materials/` (road, sidewalk, building_a/b/c, taxi_yellow, enemy_red, glass, interior, prop). No texture files.
- [x] Display settings: 1280×720 base window (changed from 1920×1080 — fits any monitor), `canvas_items`/`expand` stretch for UI, vsync on (default).
- [x] Mouse capture handling on game start/pause (`Input.mouse_mode`).
- [x] Run headless import check — no errors.

## Implementation notes
- Edit `project.godot` carefully (it's text). Input actions are `[input]` entries with `InputEventKey` objects — easier to add via editor if editing by hand gets messy; if so, give the user step-by-step editor instructions.
- Keep Jolt Physics + Forward+ as they are.

## Definition of done
- F5 opens a 3D scene with a lit ground plane, no errors/warnings in Output.
- Autoloads visible in Project Settings → Globals.
- Input map and layer names present.

## User test checklist
- [ ] Open project in Godot 4.6.1, press F5 → scene appears, Esc releases mouse.
- [ ] PS1 look visible (chunky pixels, dithering, wobble on test objects); toggle key switches it off/on.
- [ ] Gamepad detected (Start pauses / releases).

## Notes
- 2026-11-10 (Iteration 01): done. Project settings are written by `res://tools/setup_project.gd` (re-runnable) instead of hand-editing `project.godot`. Window default is 1280×720 (canvas_items/expand), not 1920×1080 — UI scales, 3D renders at ~426×240 in PS1 mode.
- Extra autoload `InputDevice` (last-used device + mouse-look accumulator). Debug keys: F1 PS1, F2 overlay, F4 physics interpolation.
- Original `project.godot` backed up in `_backup/2026-11-10/`.
