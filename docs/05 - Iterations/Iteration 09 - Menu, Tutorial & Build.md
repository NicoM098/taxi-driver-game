---
tags: [iteration]
iteration: 9
status: built-awaiting-playtest
started: 2026-11-15
finished:
---
# Iteration 09 — Main Menu, Tutorial & Local Build

## Scope (from user, verbatim)
> update the docs to match, the goal for this session will be to create a very simple main menu and tutorial (really short) and to polish some small stuff and then compile a complete build for local testing

## Interpretation
- **Docs:** the vault moved into the git repo (`taxi-driver-game/docs/`, project at the repo root) → paths, layout and the old "no git" rule updated.
- **Main menu:** a title screen as the project's main scene: PLAY, TUTORIAL, MAP EDITOR, CONTROLS, QUIT. Mouse + gamepad (D-061).
- **Tutorial:** six in-game prompts that advance by doing them, about two minutes; calm fares only and no street ambushes while it runs (D-062).
- **Polish (Claude's pick, the user named nothing specific):** a real pause menu with the run stats (KI-025 had no home), F11 fullscreen, a "Main menu" button in the map editor, map saves that work in an exported build, an editor-switch test that no longer drops the user's active map.
- **Build:** Windows export preset, `build/windows/TaxiDriver.exe` (D-063).
**Out of scope:** settings menu (volume / sensitivity / key rebinding), save / continue, audio, a full first-time onboarding flow.

## Phase tasks covered
- [[Phase 10 - Game Flow, UI & Save]] → main menu, pause menu, (a slice of) the summary; export for testing (from [[Phase 12 - Content, Balancing & Release]]).

## Checklist
- [x] Docs match the git repo layout (CLAUDE.md, Getting Started, Architecture; root `CLAUDE.md` pointer)
- [x] Main menu scene (`src/ui/menu/`) = `run/main_scene`; tooling args skip it
- [x] Tutorial (`src/ui/tutorial/tutorial.gd` in Main/UI) + calm-fare / no-encounter hooks
- [x] Pause menu: resume / skip tutorial / main menu / quit + run stats
- [x] F11 fullscreen (InputDevice), editor "Main menu" button, `user://maps/` in exported builds
- [x] `tests/tutorial_autotest` PASS, `tests/ui_shots` screenshots checked, every older test PASS
- [x] Export preset + build; exe smoke-tested (menu boots, user map and built-in city load, renders on D3D12)
- [ ] User playtest of the build

## Acceptance (how the user will judge it)
- [ ] Double-click the exe → a menu that looks like the game's, works with mouse and pad.
- [ ] The tutorial is short and teaches the loop without getting in the way.
- [ ] The build plays like the editor version.

## User test checklist
1. [ ] Run `build/windows/TaxiDriver.exe` (or `TaxiDriver.console.exe` to see a log window). The menu shows; arrow keys / d-pad move between buttons, Enter / A picks, mouse hover highlights.
2. [ ] **CONTROLS** opens the key table on the right (Esc / B closes it).
3. [ ] **TUTORIAL**: panel at top right. 1 drive, 2 drift (Space while turning), 3 shoot (RMB + LMB), 4 a commuter waits under the nearest yellow beam, 5 the file (pick DRIVE), 6 deliver → "you're a cabbie". Too long / too short / unclear text?
4. [ ] **Esc** in the game: pause menu with your run stats, RESUME / SKIP TUTORIAL (only during the tutorial) / MAIN MENU / QUIT GAME. Works with the pad (Start, d-pad, A; B resumes)?
5. [ ] **PLAY** from the menu → normal game on your active map (`TEST1`). **F11** toggles fullscreen anywhere.
6. [ ] **MAP EDITOR** from the menu, and its new **Main menu** button. In the build, saved maps go to `%APPDATA%\Godot\app_userdata\TaxiDriver\maps\` (the repo's `data/maps/` maps are still listed and loadable).
7. [ ] Anything that feels different from playing in the Godot editor (performance, mouse capture, fullscreen).

## Feedback from user
- ...

## Discovered / Deferred
- The debug keys (F1–F4, F7, F8, H, M) are live in the build — handy for local testing, to be gated before any public build.
- No settings screen (mouse sensitivity, volume, rebinding) yet.
- The tutorial does not teach boost, looking back, reloading, examine-to-unlock actions or repair shops — on purpose ("really short").

## Result summary (fill when done)
Built & auto-verified 2026-11-15: tutorial test PASS (real driving, real handbrake drift detected, real aim + fire, calm fare placed, file → DRIVE → delivered → flag cleared, no encounter fired); every older test PASS; menu / controls / tutorial / pause screenshots checked; exported exe boots headless and windowed (D3D12, RX 5500 XT). Pending user playtest.
