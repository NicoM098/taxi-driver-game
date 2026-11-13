---
tags: [meta, claude]
---
# CLAUDE.md — Working Instructions for Claude

> This is the **source of truth for how Claude works on this project**. The short `CLAUDE.md` at the repo root just points here.
> Humans: see [[Getting Started]] for the project overview.

## 1. Project at a glance
- **Game:** **TaxiDriver** (final title) — proof-of-concept demo, **open world with no shift clock** (D-051; direction: neighbourhoods with storylines + shops, see [[Development Plan]]), KB+M **and controller**, PS1-style look ([[Art Direction]]). First-person arcade taxi game. *Crazy Taxi* driving × *Papers, Please* passenger screening × *Half Grip*-style first-person shooting from the cab.
- **Engine:** Godot **4.6.1** (stable), **GDScript**, Forward+ renderer, **Jolt Physics** (3D), D3D12 on Windows.
- **Godot project folder:** `TaxiDriver/new-game-project/` (contains `project.godot`).
- **Docs vault (Obsidian):** `TaxiDriver/Crazytaxi/` — everything design/plan/progress lives here.
- **Godot executable:** `C:\Users\DLain\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe`
  (console build for headless checks: `...\Godot_v4.6.1-stable_win64_console.exe`)

## 2. Session protocol (ALWAYS follow)
### At the start of every session
1. Read [[Status]] — current phase, what is done, what is next.
2. Read the latest entries in [[Session Log]] (bottom of file = newest).
3. Read the active iteration note in `05 - Iterations/` (if one is open) and the phase note it targets in `02 - Development Plan/`.
4. Skim [[Decisions Log]] and [[Known Issues]] if touching a related system.
5. Confirm with the user what this session's goal is if it is not obvious.

### During the session
- **Technology / implementation decisions: decide yourself, don't ask** (user instruction 2026-11-10). Pick the recommended option, log it in [[Decisions Log]], move on. Only ask about iteration scope or creative/game-design calls that change what the game *is*.
- Work **only inside the scope of the active iteration**. If something out of scope is needed, write it in the iteration note under "Discovered / Deferred" and ask.
- Tick checkboxes in the phase note as tasks are completed (`- [x]`).
- Any non-obvious technical choice → add an entry to [[Decisions Log]].
- Any bug you can't fix now → add to [[Known Issues]].

### At the end of every session (mandatory, even if the session was short)
1. Append an entry to [[Session Log]] using the format in that file.
2. Update [[Status]]: phase progress, "Done", "In progress", "Next up", blockers.
3. Update the active iteration note (checklist + notes).
4. If a phase is completed, mark it ✅ in [[Development Plan]] and [[Status]].

## 3. Iterations vs Phases
- **Phases** (`02 - Development Plan/`) = the technical build order of systems. Fixed roadmap.
- **Iterations** (`05 - Iterations/`) = the work packages the **user** defines ("scope"). An iteration may cover part of one phase or slices of several. Create each from [[Iteration Template]] as `Iteration NN - <name>.md`.
- Never start a new iteration without the user giving its scope.

## 4. Code rules
- Follow [[Architecture]] (folder layout, autoloads, signals) and [[Conventions]] (style, naming).
- GDScript with **static typing everywhere** (`var speed: float = 0.0`, typed function signatures).
- **Data-driven content:** passengers, weapons, upgrades, items are custom `Resource` classes saved as `.tres` in `res://data/`. Adding a new passenger must not require new code unless it has a new *mechanic*.
- Systems talk through the `EventBus` autoload signals, not by reaching into each other's nodes.
- Keep scenes small and composable; one responsibility per script.
- Prefer editing `.tscn`/`.tres` text files carefully; if a scene is complex, build it with a script or describe the editor steps for the user.
- No third-party addons without asking (record in [[Decisions Log]] if approved).

## 5. Verifying work
- Headless parse/import check (catches script errors):
  ```
  "C:\Users\DLain\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --path "C:\Users\DLain\Documents\Godot proyects\TaxiDriver\new-game-project" --import
  ```
- Run a specific scene: add `res://path/scene.tscn` after `--path ...` (without `--headless` to see it).
- **Vehicle autotest** (physics regression, must PASS after any vehicle change):
  `<console exe> --headless --path <project> --fixed-fps 60 res://tests/vehicle_autotest.tscn` and again with `-- --jump`, `-- --handbrake-low`, `-- --flip`, `-- --drift-chain`, `-- --handbrake-high`, `-- --handbrake-straight`, `-- --weave`, `-- --reverse-throttle`.
- **View screenshots** (render artifacts): `<console exe> --path <project> --fixed-fps 60 res://tests/view_shots.tscn -- --shot-dir=<dir> --tag=<name>` (3 fixed city views).
- **Dossier test** (must PASS after any passenger/file/ride change): `res://tests/dossier_autotest.tscn` (headless; `-- --shot-dir=<dir>` windowed for file screenshots). Profile data check (every file in `data/passengers/`): `--headless --path <project> res://tools/check_profiles.tscn` (a scene — `--script` cannot compile scripts that use autoloads).
- **Pickup test**: `res://tests/pickup_autotest.tscn` (headless; `-- --shot-dir=<dir>` windowed for drink screenshots).
- **Ride-loop test** (must PASS after any ride/shift/city change): `<console exe> --headless --path <project> --fixed-fps 60 res://tests/ride_autotest.tscn`; windowed with `-- --shot-dir=<scratchpad>` for mid-ride screenshots.
- **Events test** (must PASS after any ride-event / archetype / spawn change): `res://tests/events_autotest.tscn` (headless, `--fixed-fps 60`; `-- --shot-dir=<dir>` windowed for HUD screenshots). Debug in game: **F8** puts the next archetype at the nearest stop, F7 spawns hitmen.
- **Enemy tests** (must PASS after any enemy/damage/AI change): `res://tests/enemy_autotest.tscn` and `res://tests/enemy_city_autotest.tscn` (headless, `--fixed-fps 60`); the city one with `-- --shot-dir=<dir>` (windowed) saves a screenshot of an attack.
- **Map test** (must PASS after any map / city / editor / repair-shop change): `res://tests/map_autotest.tscn` (headless, `--fixed-fps 60`; windowed with `-- --shot-dir=<dir>` saves editor screenshots). Tests always play the built-in city (`MapData.use_builtin()`); `-- --map=<name>` makes the GAME load `data/maps/<name>.json` (`builtin` = generated city).
- **Hostiles test** (must PASS after any enemy-spawn / encounter / new hostile passenger change): `res://tests/hostiles_autotest.tscn` (headless, `--fixed-fps 60`; its own map with walled-in courtyards). Debug in game: **H** fires the next street encounter.
- **Jump test** (must PASS after any ramp / container / vehicle-air change): `res://tests/jump_autotest.tscn` (headless, `--fixed-fps 60`; `-- --explore` prints ramp heights x run-ups).
- **Curb test** (must PASS after any vehicle collision-shape / suspension / sidewalk change): `res://tests/curb_autotest.tscn` (headless, `--fixed-fps 60`; `-- --explore` prints the table without failing). Tests that place the taxi themselves must `teleport()` it after the city has moved it to the player start.
- **Game ↔ editor switch test** (after any change to `main.gd` input or the editor's input): `<console exe> --path <project> res://tests/editor_switch_autotest.tscn` — WINDOWED, sends real key / mouse events (M, pan, wheel, tool button, place, select, Del, P); `-- --direct` opens the editor without going through the game. Keep the real mouse out of the window while it runs (it overrides the simulated position → false FAIL).
- **Map editor**: `res://src/editor/map_editor.tscn` (**M** in the game; P or the PLAY button goes back. Never bind F9 / F10: Godot's embedded game view uses them for suspend / next frame). Maps are JSON in `new-game-project/data/maps/`; the user's maps are **their work — never overwrite or delete them** (the test only uses `_autotest_map.json`).
- **Arrow visual check**: `<console exe> --path <project> res://tests/arrow_shots.tscn -- --shot-dir=<scratchpad>` (5 screenshots at fixed angles).
- **Weapon test** (must PASS after any combat change): `<console exe> --headless --path <project> --fixed-fps 60 res://tests/weapon_autotest.tscn`.
- **Screenshot check** (visuals; opens a window briefly; add `--world=res://src/combat/shooting_range.tscn` / `--hold=aim,fire` for combat states): `<console exe> --path <project> -- --screenshot=<scratchpad>/shot.png --screenshot-frame=90 [--no-ps1]`, then view the PNG.
- **Project settings** (input map, autoloads, layers, shader globals) live in `res://tools/setup_project.gd` — edit it and re-run with `--headless --script res://tools/setup_project.gd`, then `--import`.
- Gameplay feel cannot be verified headless — tell the user exactly what to test in-editor and what to look for, and record their feedback in the iteration note.
- Be honest in [[Status]]: "written but untested" ≠ "done".

## 6. No version control — be careful
The project does **not** use git (quick proof of concept). There is no undo:
- Read a file before overwriting it; prefer targeted edits over full rewrites.
- Before a risky restructure (moving/renaming many files, rewriting a big scene), copy the affected files to `new-game-project/_backup/<date>/` first (add a `.gdignore` file in `_backup/` so Godot ignores it), and mention it in the Session Log.
- Never delete files without the user's OK.

## 7. Don'ts
- Don't copy Crazy Taxi / Papers, Please / Half Grip names, characters, art, music, or levels. We borrow *mechanics/genre* only; all content is original.
- Don't rename/move the Godot project folder or change engine settings (renderer, physics engine) without asking.
- Don't delete vault notes; archive by moving to `99 - Archive/`.

## 8. Vault map
- [[00 - Home]] — index of everything
- [[Getting Started]] — project overview for humans and Claude
- `01 - Design/` — [[Game Design Document]], [[Passengers & Encounters]], [[Combat & Weapons]], [[Economy & Upgrades]], [[Art Direction]]
- `02 - Development Plan/` — [[Development Plan]] + one note per phase
- `03 - Architecture/` — [[Architecture]], [[Conventions]]
- `04 - Progress/` — [[Status]], [[Session Log]], [[Decisions Log]], [[Known Issues]]
- `05 - Iterations/` — user-scoped iterations (active: [[Iteration 08 - Open-World Base & Map Editor]])
- `Templates/` — note templates
