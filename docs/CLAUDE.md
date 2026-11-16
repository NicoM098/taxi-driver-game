---
tags: [meta, claude]
---
# CLAUDE.md — Working Instructions for Claude

> This is the **source of truth for how Claude works on this project**. The short `CLAUDE.md` at the repo root just points here.
> Humans: see [[Getting Started]] for the project overview.

## 1. Project at a glance
- **Game:** **TaxiDriver** (final title) — proof-of-concept demo, **open world with no shift clock** (D-051; direction: neighbourhoods with storylines + shops, see [[Development Plan]]), KB+M **and controller**, PS1-style look ([[Art Direction]]). First-person arcade taxi game. *Crazy Taxi* driving × *Papers, Please* passenger screening × *Half Grip*-style first-person shooting from the cab.
- **Engine:** Godot **4.6.1** (stable), **GDScript**, Forward+ renderer, **Jolt Physics** (3D), D3D12 on Windows.
- **Repo = Godot project:** `C:\Users\DLain\Documents\Godot proyects\Txi Driver Repo\taxi-driver-game\` — `project.godot` sits at the repo root (= `res://`). Git repo: `main` (initial commit only), `feature/iterations-09-10`, Nico's `feat/visuals-and-audio`, and the playtest merge of both `temp/playtest-merge` (D-069, where work happens now).
- **Docs vault (Obsidian):** `docs/` inside the repo — everything design/plan/progress lives here (Godot ignores it: no resources inside).
- **Builds:** `build/windows/TaxiDriver.exe` (export preset "Windows Desktop", git-ignored) — see §5.
- **Godot executable:** `C:\Users\DLain\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe`
  (console build for headless checks: `...\Godot_v4.6.1-stable_win64_console.exe`)

## 2. Session protocol (ALWAYS follow)
### At the start of every session
1. Read [[Status]] — current phase, what is done, what is next.
2. Read the top of [[Changelog]] — **what the other person pushed since you last worked**. Two
   people build this on separate branches; this is how you find out without reading a diff.
3. Read the latest entries in [[Session Log]] (bottom of file = newest).
4. Read the active iteration note in `05 - Iterations/` (if one is open) and the phase note it targets in `02 - Development Plan/`.
5. Skim [[Decisions Log]] and [[Known Issues]] if touching a related system.
6. Confirm with the user what this session's goal is if it is not obvious.

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
  "C:\Users\DLain\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --path "C:\Users\DLain\Documents\Godot proyects\Txi Driver Repo\taxi-driver-game" --import
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
- **Map editor**: `res://src/editor/map_editor.tscn` (**M** in the game; P or the PLAY button goes back. Never bind F9 / F10: Godot's embedded game view uses them for suspend / next frame). Maps are JSON in `data/maps/` (an exported build saves its maps to `user://maps/` instead); the user's maps are **their work — never overwrite or delete them** (the test only uses `_autotest_map.json`).
- **Arrow visual check**: `<console exe> --path <project> res://tests/arrow_shots.tscn -- --shot-dir=<scratchpad>` (5 screenshots at fixed angles).
- **Weapon test** (must PASS after any combat change): `<console exe> --headless --path <project> --fixed-fps 60 res://tests/weapon_autotest.tscn`.
- **Screenshot check** (visuals; opens a window briefly; add `--world=res://src/combat/shooting_range.tscn` / `--hold=aim,fire` for combat states): `<console exe> --path <project> -- --screenshot=<scratchpad>/shot.png --screenshot-frame=90 [--no-ps1]`, then view the PNG.
- **Shop test** (must PASS after any gun shop / weapon economy / weapon-controller change): `res://tests/shop_autotest.tscn` (headless, `--fixed-fps 60`; `-- --shot-dir=<dir>` windowed: shop + hotbar screenshots).
- **Street-life test** (must PASS after any pedestrian / traffic / StreetLife change): `res://tests/streetlife_autotest.tscn` (headless, `--fixed-fps 60`; `-- --shot-dir=<dir>` windowed: a street screenshot). Street life is OFF in every other test (`MapData.override`), like street encounters.
- **Heat / passengers test** (must PASS after any heat, bounty, generated passenger, drop-off, civilian-crime, hostile-marker or death change): `res://tests/heat_passengers_autotest.tscn` (headless, `--fixed-fps 60`; parts A-H).
- **Tutorial test** (must PASS after any tutorial / spawner / main-menu → game change): `res://tests/tutorial_autotest.tscn` (headless, `--fixed-fps 60`).
- **Menu screenshots**: `<console exe> --path <project> res://tests/ui_shots.tscn -- --shot-dir=<scratchpad>` (main menu, controls panel, tutorial prompt, pause menu).
- **The game starts on the main menu** (`src/ui/menu/main_menu.tscn` = main scene). Args `--screenshot=`, `--world=`, `--hold=`, `--map=` skip it straight to `main.tscn`.
- **Build** (after a session that changes the game, if the user wants a fresh build): `<console exe> --headless --path <project> --export-release "Windows Desktop" build/windows/TaxiDriver.exe`, then smoke-test `build/windows/TaxiDriver.console.exe --headless --quit-after 900 -- --map=builtin` (look for `[City] map ...` and no errors).
- **Project settings** (input map, autoloads, layers, shader globals) live in `res://tools/setup_project.gd` — edit it and re-run with `--headless --script res://tools/setup_project.gd`, then `--import`.
- Gameplay feel cannot be verified headless — tell the user exactly what to test in-editor and what to look for, and record their feedback in the iteration note.
- Be honest in [[Status]]: "written but untested" ≠ "done".

## 6. Version control (git)
The project is a git repo since 2026-11-15 (before that there was none — that is what `_backup/` is from; it keeps its `.gdignore`).
- **Commit / push only when the user asks.** Uncommitted work is the user's to review.
- **Ask which branch before pushing. Never inherit the checked-out one by default** (2026-11-16:
  Iteration 15 went straight onto the shared `temp/playtest-merge` because that was simply the
  branch open at the time).
  - **A new iteration or an unproven idea gets its own branch** (`feat/<thing>`), and only merges
    into the shared branch **once the user has played it**. The shared branch is what the other
    person pulls and builds from; an unplaytested feature landing there turns up in their build
    without warning.
  - Fixes and tuning to work the user has already approved can go straight onto the shared branch.
  - If something lands on the wrong branch and **the other person has already pulled it, leave it
    there**: rewriting a branch they have breaks their next pull. Say so and carry on.
- **Every push adds an entry to [[Changelog]] first** (same commit, or the one before it). Two
  people build this game on separate branches, each with their own Claude session, and that file is
  how the other one finds out what changed without reading a diff. One block per push: date · who ·
  branch · commit range, then what changed in plain language and the decision ids for the *why*.
  Flag anything that changes shared code or how the other person's systems behave — that is the
  part worth their time.
- Read a file before overwriting it; prefer targeted edits over full rewrites. Git is now the safety net for risky restructures — no more manual copies to `_backup/`.
- Never delete files without the user's OK. **Never touch the user's maps in `data/maps/`** (e.g. `test1.json`), even if git shows them modified.
- `.godot/` and `build/` are git-ignored.

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
- `05 - Iterations/` — user-scoped iterations. **Two parallel lines of work merged on 2026-11-15**: plain numbers are DLain47's (08-12), and `09V` / `10V` / `11V` plus the `DV-0xx` decisions are Nico's visual & audio line. Numbering is shared again from 13 on (D-079). Active: [[Iteration 13 - Merge Integration]]; 08-12 await playtests
- `Templates/` — note templates
