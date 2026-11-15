---
tags: [meta, overview]
---
# Getting Started

## 1. The pitch
**TaxiDriver** is a first-person, action-packed arcade taxi game.

You drive a cab through a city against the clock, like *Crazy Taxi* — but you don't pick people up off the street. **Passengers get into your cab**, and when they do, **a file (dossier) on them opens up**, like the documents in *Papers, Please*. You read it, then choose what to do:

- **Drive them** to their destination (earn the fare, deal with the consequences)
- **Kick them out** of the cab
- **Examine** something (their bag, their ID, a detail in the file) to learn more
- **Special/bizarre options** when the situation calls for it — e.g. kill them on the spot, hand them over to someone, take a detour…

Every passenger has a background that changes the ride:
- 👵 **Old lady** — pays nothing, but may drop a useful item.
- 💼 **Businessman** — pays a lot, but hitmen in other cars will try to kill you both.
- 🦹 **Burglar** — if you let him in, he steals from you.
- …and many more (see [[Passengers & Encounters]]).

The camera is **first-person from the driver's seat**, and you can **shoot from the car** while driving — the one thing we borrow from *Half Grip*: its in-cab first-person perspective and shooting. Its complex controls are **not** borrowed; our controls stay arcade-simple.

Between shifts you spend your money in a **shop/upgrade system**: new guns, and perks for you and your taxi.

> Inspirations are for mechanics and genre only. All names, characters, art, music and the city are original.

## 2. Core loop
```
Start shift → drive / cruise → passenger enters → dossier opens
   → decide (drive / kick / examine / special)
   → ride: drive to destination under time pressure, events happen (chases, theft, twists)
   → payout (fare + tip + loot) or consequence
   → repeat until shift ends → shop & upgrades → next shift
```
Full details: [[Game Design Document]].

## 3. Tech
| Item | Value |
|---|---|
| Engine | Godot 4.6.1 stable |
| Language | GDScript (static typing) |
| Renderer | Forward+ (D3D12 on Windows) |
| Physics | Jolt Physics (3D) |
| Godot project | `C:\Users\nikom\OneDrive\Escritorio\DriverProject\new-game-project` |
| Docs vault | `docs/` (this Obsidian vault, inside the Godot project) |
| Godot exe | `C:\Users\nikom\OneDrive\Escritorio\DriverProject\Godot_v4.6.1-stable_win64.exe` |

## 4. Folder layout
```
TaxiDriver/
├── CLAUDE.md                ← pointer to docs/CLAUDE.md
├── new-game-project/        ← Godot project (res://)
│   ├── assets/materials/    ← PS1 ShaderMaterial presets (flat colours)
│   ├── data/                ← content as .tres: passengers/, weapons/, enemies/
│   ├── src/                 ← code by feature: autoload, camera, combat, core, dossier,
│   │                           enemies, items, main, passengers, ride, ui, vehicle, world
│   ├── tests/               ← headless autotests + screenshot tools (see CLAUDE.md §5)
│   ├── tools/               ← setup_project.gd (project settings), check_profiles.gd
│   └── _backup/             ← manual backups (no git; ignored by Godot)
└── docs/                    ← Obsidian vault (all docs)
    ├── 00 - Home.md
    ├── CLAUDE.md            ← Claude's working rules
    ├── Getting Started.md   ← you are here
    ├── 01 - Design/         ← what the game is
    ├── 02 - Development Plan/ ← build order, one note per phase
    ├── 03 - Architecture/   ← code structure & conventions
    ├── 04 - Progress/       ← Status, Session Log, Decisions, Known Issues
    ├── 05 - Iterations/     ← work packages you scope
    └── Templates/           ← note templates
```

## 5. How we work
1. **You define an iteration** (the scope for the next chunk of work).
2. Claude creates `05 - Iterations/Iteration NN - <name>.md` from the [[Iteration Template]], mapping your scope to tasks in the phase notes.
3. Claude implements, then gives you a **test checklist** for the editor (driving feel, shooting feel etc. can only be judged by playing).
4. At the end of every session Claude updates [[Status]] and [[Session Log]] so the next session picks up instantly.

Build order of systems: [[Development Plan]].

## 6. Running the project
- Open Godot 4.6.1 → Import → `new-game-project/project.godot` → **F5**.
- You start in the city; you go on duty after 1 s (there is no shift clock). Current state of the game: [[Status]].

### Controls
| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Throttle / brake-reverse | W / S | RT / LT |
| Steer | A / D | left stick |
| Handbrake (drift) | Space | B |
| Boost | Shift | A |
| Look around / look behind | mouse / C | right stick / R3 |
| Aim (raise gun) / fire | RMB / LMB | LB / RB |
| Reload / switch weapon | R / 1-3, wheel | X / Y, d-pad |
| Reset car | T | L3 |
| (unused: there is no summary screen at the moment) | E / Enter | d-pad ↑ |
| Pause | Esc | Start |
| Passenger file | mouse clicks | d-pad + A |
| Kick the passenger out (mid-ride) | Q | d-pad ↓ |

### Debug keys
F1 PS1 look on/off · F2 debug overlay (FPS, telemetry, controls) · **F3** city ↔ shooting range · F4 physics interpolation · **F7** spawn two hitmen · **F8** put the next passenger archetype at the nearest stop.

### Automated checks
Claude runs headless autotests and screenshot tools after every change — list and commands in [[CLAUDE]] §5.

## 7. Project decisions (answered 2026-11-10)
- [x] **Title:** TaxiDriver (final). Godot `config/name` to be renamed in Phase 00.
- [x] **Version control:** git, since 2026-11-13 (branch `main`). Backups in `_backup/` stay for risky restructures; see [[CLAUDE]] §6.
- [x] **Controller:** supported from the start (KB+M and gamepad).
- [x] **Run structure:** ~~endless shifts~~ → open world, no shift clock (2026-11-12, D-051).
- [x] **Art direction:** primitive blockout + PS1-style render pipeline; flat colours first, no textures from day 1. See [[Art Direction]].

### Still open
- [ ] Target platform: PC (Windows) only? (assumed yes)

## Map editor (since 2026-11-12)
Press **M** in the game (or run `src/editor/map_editor.tscn`). Build with the piece buttons on the left, edit the selected piece on the right, **Save**, then **PLAY THIS MAP (P)**. Maps are JSON files in `new-game-project/data/maps/`. Details and keys: [[Iteration 08 - Open-World Base & Map Editor]].
Wrecked taxi: it limps until you stop on the yellow pad of a repair shop (follow the arrow / red beacon).
