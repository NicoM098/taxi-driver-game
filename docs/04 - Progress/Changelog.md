---
tags: [progress, changelog]
updated: 2026-11-17
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

## 2026-11-17 · DLain47 · `feat/no-papers` · after `fe4fbf0`
**Exports ship the map in use (D-097).**
- New `data/default_map.txt` names the map a build starts on (now `TEST1`) and is packed into
  exports (`export_presets.cfg` include filter). `MapData.active_name()` reads the player's own
  `user://active_map.txt` first, then this file, then the generated city; `--map=` still wins.
- Pressing PLAY in the map editor **while running from the Godot editor** also rewrites
  `data/default_map.txt`, so the next build ships the map you last played. Exported builds never
  write it. Heads-up for Nico: playing a map in the editor changes this tracked file.
- `editor_switch_autotest` restores the shipped file after playing its throw-away map.

---

## 2026-11-17 · DLain47 · `feat/no-papers` · after `4762617`
**Still not on the shared branch** (§6). Played twice by DLain47 for balance only.

**Iteration 21 — Endless weapon upgrades (D-093)**
- Mk I-IV is gone. Each gun has four tracks bought from its shop card: Mag and Ammo (3 levels),
  Damage and Fire rate **endless** (bigger steps every 3 levels, prices ×1.35 a level). Fire rate
  past 3× base (max 30/s) turns into damage. The special switches on after 8 upgrades.
- **Enemy health grows with what the run has earned** (`GameState.earned`,
  `WeaponUpgrades.enemy_hp_mult()`), boss bars included. `WeaponUpgrades.scale_enemies` turns it off.
- `GameState.weapon_levels` is now `id → {track: level}`; `WeaponData.upgrade_prices` became
  `upgrade_cost`. Unlocks need ~15 % fewer fares.

**Iteration 22 — Ammo drops (D-094)**
- **Ammo is not sold any more** and upgrades do not refill (`WeaponData.ammo_price` and
  `WeaponController.refill_ammo` removed). Every destroyed enemy drops a floating ammo box for one
  equipped gun (`src/items/ammo_pickup.gd`; bosses drop up to 5). Drive through it.
- **New visuals / sound that touch Nico's side:** the ammo box (placeholder crate, slot-coloured
  stripe, Label3D, light), a glowing ground circle `PickupRing` under it **and under the Monstrous
  Energy can**, and a new signal `EventBus.ammo_picked_up` that plays the `pickup` sound.

**Balance from DLain47's playtests (D-095, D-096)**
- Fares ×2.5 (`RideManager.FARE_SCALE`), kill bounties ×2 (`EnemyDirector.BOUNTY_SCALE`),
  every price −10 % (guns, car upgrades, upgrade tracks $225).
- Enemy health ×0.85 and a slower curve (`SCALING_SHARE` 0.35): guns out-scale enemies now.

**Tests:** new `ammo_drop_autotest`; `upgrades` rewritten; `arsenal`, `shop`, `shop_menu`,
`enemy` updated. The suite passes.

---

## 2026-11-17 · DLain47 · `feat/no-papers` · after `2c137cc`
**Still not on the shared branch:** unplayed, on its own branch per §6. Merges into
`temp/playtest-merge` only once DLain47 has played it.

**Iteration 17 tuned:** gang rides were "way too hard": more clock, rarer and smaller rival
crews, ordinary fares safe below HARD (numbers in D-089).

**Iteration 18 — Shop menu (D-089)**
- **No shops in the city** while `ShopMenu.enabled` (static, default `true`): gun-shop and garage
  lots become plain buildings (`ShopMenu.build_closed_lot`). Nothing deleted; `false` brings
  them back. City-shop tests (shop, map, minimap, ride) turn it off themselves.
- **Tab** (pad: Back) opens SHOP anywhere and pauses. Car upgrades are data
  (`data/car_upgrades/`, `CarUpgrades`): armor, engine, bulletproof glass, ram bar, nitro tank,
  Monstrous XL. `GameState` gained `car_levels` and `cans`.
- **A wreck now always ends the run** when the menu is on (`taxi_damage.gd`).

**Iteration 19 — Shop polish & nitro (D-090)**
- The shop is three tabs of one-click cards (guns bought / upgraded / equipped from their card).
  It reuses `GunShopUI`'s buy / upgrade / refill / equip, plus a new `said` signal.
- **Input map changed** (`setup_project.gd` → `project.godot`): `shop_menu` = **Tab** / Back,
  **Tab is no longer `interact`** (E / D-pad up still are), `drink` = F / **Y** (Y left
  `weapon_next`), `debug_next_stage` = F11.
- **The boost is a nitro tank now** (`taxi.gd`: `nitro_tank`, drain / refill / relight;
  drift links refill it; `EnemyCar` keeps an endless boost). A new HUD gauge (`NitroGauge`)
  sits left of the minimap. If you have boost sounds or VFX, `taxi.is_boosting` now goes false
  when the tank runs dry.

**Iteration 20 — Escalation stages (D-091)**
- The shop sells **no Monstrous Energy cans and no repair** (`ShopMenu.sells_cans` /
  `sells_repair` = false). Healing = street cans only.
- **The run is three stages** (`src/escalation/`, `Escalation.enabled`, data in
  `data/stages/`): cops + gangs → SWAT + roaming gang bosses → military + cartel. Each stage
  ends in a **boss fight** once its fares, kills and survived time are all reached: the Precinct
  Captain; the three gang bosses; the Army APC + the Kingpin. A stage panel and boss bars sit
  under the cash, and a banner shows for each stage.
- **10 new enemy cars + 4 materials** (`data/enemies/`, `assets/materials/enemy_*`): placeholder
  blockout colours, worth a visual pass from you. `EnemyCarData` gained `size` / `plow` /
  `is_boss`. `EnemyCar.build_body` / `build_wheels` take a size (traffic unchanged).

**Enemy driving (D-092) — shared code, affects every hostile car**
- Enemies take **no crash damage from buildings**, only from cars (`contact_monitor` is on in
  `EnemyCar`).
- `enemy_driver_ai.gd` changes:
  - line of sight (they take the streets instead of driving into a building);
  - tighter waypoints;
  - three-point turns;
  - longer, alternating unstuck reverses;
  - a last-resort out-of-sight rescue (`EnemyDirector.rescue_stuck`).
- Fixed `EnemyDirector._cleanup`: it could never remove a car freed elsewhere.

**Tests:** new `shop_menu`, `escalation`, `enemy_corners` (24 in total, all PASS on this push).

## 2026-11-16 · DLain47 · `feat/no-papers` (new branch) · after `900fc32`
**Not on the shared branch:** an unplayed trial, on its own branch per §6. Merges into
`temp/playtest-merge` only once DLain47 has played it.

**Iteration 17 — Gang Rides: the game without the passenger file (D-088)**
- **The Dossier is switched off, not deleted:** one flag, `GangRides.enabled` (static, default
  `true`, `src/gang_rides/gang_rides.gd`). `false` = the old game exactly.
- **With it on:** fares get in and the ride starts (no file); driving into the green ring delivers
  at any speed; a **ride card** (top left, `RideCard`) announces the passenger, their gang, a
  **random difficulty** (EASY / NORMAL / HARD / DEADLY: clock, pay, gang pressure) and what their
  ride events may do.
- **Three gangs** (`data/gangs/`): Red Fangs (downtown), Purple Hounds (suburbs), Orange Jackals
  (docks), each with its own car (`data/enemies/gang_*.tres`) and material. Members wait in their
  zone; carrying one makes the rival gangs roll to come for you (`EnemyDirector.spawn_on_route`).
- **Shared code touched (small, gated):** `ride_manager.gd` (2 lines behind the flag),
  `event_bus.gd` (new `ride_announced`), `hud.gd` (adds the card, hint text), `tutorial.gd` (no
  FILE step in this mode), `game.tscn` (a `GangRides` node). Your visuals / audio are untouched.
- **Tests:** new `gang_rides_autotest`; dossier / events / heat_passengers / hostiles set the flag
  to `false` themselves; tutorial test covers both modes.

## 2026-11-16 · DLain47 · `temp/playtest-merge` · after `023c105`
**On this branch by the user's choice:** asked under your new branch rule (§6), DLain47 chose to
put all of it here, including **Iteration 16, which nobody has played yet**. Expect it in your
next build.

**Minimap and shops (approved by DLain47 in play)**
- **Bug in the minimap:** every shop was drawn at the world origin. `RepairShop` / `GunShop`
  nodes stay at (0, 0, 0) and build in world space; the minimap now uses `pad_position`
  (`Minimap.shop_points`, covered by `minimap_autotest` part 3).
- **Bigger markers:** shops are lettered squares (R / G), the destination is a pulsing green
  diamond, and everything has an outline. The constants are at the top of `minimap.gd`.
- **Shops (D-084):** every pad gets a ring and a beam (`ShopMarker`, minimap colours). You stop
  and press **E** (`interact`) instead of waiting on the pad. New
  `EventBus.interact_prompt(source, text)` and a prompt label in `hud.gd`.

**Iteration 16 — Weapon Upgrades & Unlocks (built, auto-verified, not played)**
- **D-085:** guns unlock by fares delivered in the run (SMG 5, sawed-off 12, rifle 20) and cost
  about twice as much. Mk I-IV upgrades at the gun shop; Mk IV is a special per gun: deadeye,
  drum, dragon's breath (`Burning`), AP rounds.
- **D-086:** four heavy guns:
  - mines ($1800 / 15 fares),
  - minigun ($2500 / 22),
  - rocket launcher ($3500 / 28),
  - laser ($5000 / 35).

  New `Blast` (explosions never hurt the player's taxi), `Rocket` and `Mine`.
- **D-087:** you can own any number of guns but carry 4 (keys 1-4); the rest are stored at the
  gun shop (EQUIP / UNEQUIP).
- **Touches shared code, worth your time:**
  - `audio.gd`: `_on_weapon_fired` maps the new guns to your bank, pitched. **KI-037**: they need
    real samples in `gen_sfx.py`.
  - `gun_shop_ui.gd`: rewritten as list + detail.
  - `weapon_controller.gd`: `weapons` = equipped upgraded copies, `_arsenal` = everything owned.
    Fire is split into hitscan / rocket / mine, and there is a beam for the laser.
  - `weapon_bar.gd`: shows the loadout.
  - `WeaponData`: new fields (`kind`, `beam`, `spin_up`, `blast_radius`, `projectile_speed`,
    `unlock_rides`, `upgrade_prices`, `special*`).
  - `GameState`: `weapon_levels` and `loadout`.
- **Tests:** two new ones, `upgrades_autotest` and `arsenal_autotest` (20 now); `shop`, `ride`,
  `minimap` updated. All PASS. `events` (KI-031) and `enemy_city` (KI-029) each failed once and
  passed 3/3 on re-run.

## 2026-11-16 · Nico · `temp/playtest-merge` · `9dd5a8c`
**A branch rule, for both of us** ([[CLAUDE]] §6). Iteration 15 went straight onto this shared
branch because it was simply the one open at the time, and that is the branch you pull and build
from — an unplaytested feature landing here turns up in your build without warning. From now on:
- **Ask which branch before pushing**, never inherit the checked-out one.
- **A new iteration or an unproven idea gets its own `feat/<thing>` branch**, and merges here only
  once it has been played. Fixes and tuning to approved work can come straight here.
- **If something lands on the wrong branch and you have already pulled it, it stays** — rewriting
  a branch you have breaks your next pull. (Which is exactly what happened with the minimap, so it
  stays where it is.)

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
