---
tags: [progress, changelog]
updated: 2026-11-16
---
# Changelog

> **What this is for.** Two people build this game, each on their own branch with their own Claude
> session. This file is how the other one finds out what changed **without reading a diff or
> replaying someone else's session**. Newest first.
>
> **The rule: every push adds an entry here, in the same commit or the one before it.**
> See [[CLAUDE]] §6.
>
> One block per push: date · who · branch · commit range, then what changed in plain language and
> the decision ids to read for the *why*. Short on purpose — [[Session Log]] holds the detail,
> [[Decisions Log]] holds the reasoning, [[Status]] holds the present.
>
> Decision ids: `D-0xx` is the shared sequence (DLain47's line), `DV-0xx` is Nico's visual & audio
> line, from when the two ran in parallel. Iteration notes work the same way: `09V` / `10V` / `11V`
> are Nico's, plain numbers are DLain47's, shared again from 13 on (D-079).

---

## 2026-11-16 · Nico · `temp/playtest-merge` · `1b38641`
**Iteration 15 — Minimap** (D-083). Square, rotates with the car, shows a radius, flat.
- **Drawn from `MapData.flags()`, not from a second camera.** The flags grid is already one byte
  per cell (`F_SOLID` / `F_COVERED`), so it bakes into a one-pixel-per-cell `ImageTexture` on map
  load and the minimap draws a rotated slice of it. **A second `Camera3D` would have rendered the
  whole city again every frame** and still not told you a repair shop from a gun shop at 150 px.
- **It works on any map for free**, the editor's included, because it comes from the same data the
  world is built from.
- Blips reuse registries that already exist: `EnemyDirector.enemies` (police told apart by their
  `EnemyCarData`, like the gunfire in D-080), `City.stops` where `occupied`, `City.repair_shops`,
  `City.gun_shops`, and the ride destination, clamped to the border when out of range.
- **Touches your code only in `hud.gd`**: the minimap is a `Control` the HUD builds, bottom-right
  above the speed — the one corner that was free. It inherits the HUD's visibility, so the file and
  the menus hide it with no extra wiring.
- New `tests/minimap_autotest` (the 18th): checks the bake against the flags on a **non-square**
  40×24 map so a swapped width/depth cannot pass, and the world→minimap mapping at three yaws.

## 2026-11-16 · Nico · `temp/playtest-merge` · `d9be080`
**This file** (D-082), plus the rule that fills it: reading it is step 2 of the session protocol
([[CLAUDE]] §2), writing it is a rule in §6. Back-filled with every push on this branch from both
lines of work.
- **Fixed while back-filling:** [[Iteration 11V - Audio]] still read "awaiting playtest" here. The
  commit that closed it (`dbbd221`) is on `feat/visuals-and-audio` only — the playtest merge was
  taken one commit earlier. Re-applied by hand; see "Known gaps" at the bottom.

## 2026-11-16 · Nico · `temp/playtest-merge` · `8364a41`
**Iteration 14 — Juice** (D-081). The last of Phase 11.
- **Air time**: jumps pay on landing, "CRAZY JUMP" / "HUGE AIR"; `best_air_time` joins the run stats.
- **Hit-stop**: a kill freezes the world 70 real ms with a camera kick. **Off in headless**, because
  `Engine.time_scale` is global and the suite runs at `--fixed-fps 60`.
- **Skid marks**: 480-slot MultiMesh ring buffer, stamped under sliding rear wheels.
- **Near miss**: close + fast + no contact, 2.5 s cooldown per car.
- All of it pays through the **drift chain's existing economy** — one style currency, not three.
- New `tests/style_autotest` (the 17th): the near-miss rule could not be covered otherwise, since
  the closest another car gets to the player in any existing test is 58 m.
- **Heads-up for your code:** `StyleMeter` and `SkidMarks` are children of `taxi.tscn`, never on
  `Taxi` itself — `TrafficCar extends Taxi`, so anything on the parent script fires for every
  civilian car.
- **New known issue, not mine to fix: KI-036.** `weapon_autotest` is flaky ~1 in 5 because
  `weapon_controller` calls `_rng.randomize()` and the shotgun's 8 pellets scatter differently every
  run. One-line fix available (seed it when headless).

## 2026-11-16 · Nico · `temp/playtest-merge` · `24cd7b0`
**Enemy gunfire is audible** (D-080). `enemy_gunner.gd` drew tracers and muzzle flashes and played
no sound at all. Now one positional shot per bullet at -4 dB, and **the gun is derived from the
car's own `fire_rate`**, so `EnemyCarData` is untouched and a new enemy sorts itself out: police
(5/s) get the revolver, hitmen (6/s) and gang coupes (8/s) get the SMG. A pistol means police and an
SMG means gangs.

## 2026-11-16 · Nico · `temp/playtest-merge` · `a2c6309`
**Iteration 13 — Merge Integration** (D-078, D-079). Closing the seams the merge left.
- **A bug in my own code, found in yours:** `TrafficCar extends Taxi`, so every civilian car was
  inheriting the player's **non-positional** engine rig — 13 cars × 4 loops = 52 flat loops at the
  driver's own volume whatever the distance. `Taxi.engine_audio_local` now gates it; civilians run
  one positional layer at -21 dB over 55 m, like your enemy cars already did.
- **Tail lights** on `Taxi`, so every civilian inherits them: dim red at dusk, bright under braking,
  off in daylight. Emissive only, no extra `Light3D`.
- **Iteration numbering untangled** (D-079): the merge had left two 09s and two 10s, so every
  wikilink to them was ambiguous. Mine became `09V` / `10V` / `11V`, matching the `DV-` decisions;
  yours keep the plain numbers; shared again from 13.
- Reviewed the merge before touching it: 16/16 autotests, visuals intact, and you had **extended**
  the `Audio` autoload rather than forking it — thank you, that made all of this easy.

## 2026-11-15 → 11-16 · DLain47 · `temp/playtest-merge` · `8e36cf3..addcaac`
**Iteration 12 — Heat, Fares & Game Over** (D-069…D-077), plus the docs that restored my decisions
as `DV-061…DV-068`. Heat with police from 2★ and a bounty from 4★, music + an OPTIONS menu with
saved volumes, smaller ammo reserves, procedurally generated passengers, curbside drop-offs,
destructible civilian cars where crimes raise heat, a red marker over hostiles, and **death
replacing limp mode** (D-077 supersedes D-056). Build 0.10.5.

## 2026-11-15 · DLain47 · `feature/iterations-09-10` → merged in `aa8be56`
**Iterations 09 (Menu, Tutorial & Build) and 10 (Street Life, Gun Shop & Weapon Bar)** (D-061…D-068
in the shared sequence). Title screen as the main scene, six-step tutorial, pause menu with run
stats, Windows export; gun shops and the rifle, pedestrians and traffic, four new passengers, the
weapon hotbar.

## 2026-11-14 · Nico · `feat/visuals-and-audio` · `5789037`
**Iterations 09V (textures), 10V (lights & night) and 11V (audio)** (DV-061…DV-068). What this put
into the shared world, in case it surprises you:
- **World-space UVs** on the city materials, so a tiling texture keeps its real size on a generated
  box of any dimension, and **procedural facade windows** with randomly lit ones.
- The CC0 **A_classic** texture pack on 10 materials, each flat colour rebalanced against its
  texture's mean so the palette survives the multiply. **All texture imports need
  `detect_3d/compress_to=0`** — Godot's default re-imports to VRAM with mipmaps on first 3D use and
  destroys the dither.
- **Three times of day** in `src/world/lighting.gd` (day / dusk / night, **F6** cycles), 311 street
  lamps, taxi headlights, and the PS1 shader moved to per-pixel lighting.
- **The whole sound bank is generated** by `tools/gen_sfx.py` — there is no clean CC0 car-engine
  loop in existence — with an `Audio` autoload that owns the buses and **listens on the EventBus
  itself**, so no gameplay script knows about audio. Engine = three layers through a five-speed
  gearbox.

---

## Known gaps between the branches
- **`feat/visuals-and-audio` has one commit this branch does not**: `dbbd221`, which closed
  Iteration 11V after the audio was approved in play. The merge was taken at `5789037`, one commit
  earlier. The closure was re-applied here by hand on 2026-11-16, so the notes now agree; nothing
  else from that branch is missing.
- `main` still holds only the initial commit. `temp/playtest-merge` is explicitly not for `main`
  (D-069), so how all of this lands is still an open question.
