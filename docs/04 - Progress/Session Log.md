---
tags: [progress, log]
---
# Session Log

Append-only. **Newest entry at the bottom.** One entry per working session.

Format:
```
## YYYY-MM-DD — Session N — <short title>
**Iteration:** [[Iteration NN - ...]] · **Phases touched:** 0X
**Goal:** what this session set out to do
**Done:**
- ...
**Files changed:** `res://...`
**Tested:** what was verified and how (headless check / user playtest / not tested)
**Problems / notes:** ...
**Next session should:** concrete first step
```

---

## 2026-11-10 — Session 1 — Project documentation setup
**Iteration:** none (pre-production) · **Phases touched:** —
**Goal:** create the Obsidian vault structure, CLAUDE.md, Getting Started, design docs and development plan.
**Done:**
- Created vault structure: Home, CLAUDE.md, Getting Started, `01 - Design` (GDD, Passengers & Encounters, Combat & Weapons, Economy & Upgrades), `02 - Development Plan` (overview + Phases 00–12), `03 - Architecture` (Architecture, Conventions), `04 - Progress` (Status, Session Log, Decisions Log, Known Issues), `05 - Iterations` (template), `Templates/`.
- Root `TaxiDriver/CLAUDE.md` pointer so Claude Code loads the vault instructions.
**Files changed:** vault only; Godot project untouched.
**Tested:** n/a (docs)
**Problems / notes:** Godot project still named "New Game Project". Godot 4.6.1 exe located in Downloads folder.
**Next session should:** get Iteration 01 scope from the user, create the iteration note, begin Phase 00.

### Session 1 (cont.) — Project decisions
- User answered open questions: title **TaxiDriver**, **no git**, **controller supported**, **endless shifts** (D-006…D-009).
- User asked for an opinion on art direction → proposed blockout + PS1 render pipeline; wrote [[Art Direction]] (D-010, awaiting confirmation).
- Updated: Getting Started §7, CLAUDE.md (no-git safety rules §6), GDD (controller bindings, endless shifts, art), Architecture (§8 gamepad input, §9 render pipeline), Phase 00 & Phase 10 tasks, Decisions Log, Status, Home.
- User **accepted PS1 direction** and wants fast blockout iteration → **no textures from day 1**; flat-colour material presets, textures from Phase 02+ only where useful. Added texture roadmap to [[Art Direction]]; D-010 accepted.

## 2026-11-10 — Session 2 — Iteration 01 "It Drives" (Phase 00 + 01)
**Iteration:** [[Iteration 01 - It Drives]] · **Phases touched:** 00, 01
**Goal:** project setup + PS1 pipeline + drivable first-person arcade taxi on a test course, KB+M and gamepad.
**Done:**
- User instruction recorded: Claude decides tech choices without asking (D-011; also in CLAUDE.md and Claude memory).
- `tools/setup_project.gd` writes project settings (name TaxiDriver, main scene, display, 6 autoloads, layers, shader globals, full input map) — D-012.
- Autoloads: EventBus (signals), GameState, PlayerStats, SaveManager, SceneLoader (stubs), InputDevice (device tracking + mouse-look accumulator, D-013).
- PS1: `ps1_world.gdshader` (vertex snap, affine UV, flat colour/texture, world checker, emission), `ps1_post.gdshader` (Bayer dither, 5-bit), 17 material presets.
- `main.tscn`: low-res SubViewport (auto shrink to ~240 px tall), UI layer, pause (Esc/Start), F1/F2/F4 debug toggles, screenshot cmdline for automated checks.
- Vehicle: `taxi.gd` raycast RigidBody3D (suspension, grip-limited lateral friction, engine curve, brakes/reverse, handbrake, boost, downforce, drag, air control, flip recovery, crash signal) + arcade assists (D-016); `taxi_wheel.gd`; `VehicleInput` + `PlayerVehicleInput` provider (D-015).
- Camera: `cab_camera.gd` free look (mouse + stick), recentre (stick only by default), look-behind, g-force lean/roll, speed FOV, crash shake.
- `taxi.tscn` blockout with interior; roof raised + headliner after first screenshot showed roof filling the view.
- `test_drive.gd/.tscn` procedural course; `tests/vehicle_autotest` (drive + `--jump`).
**Files changed:** `project.godot` (backup in `_backup/2026-11-10/`), `src/**`, `assets/materials/*.tres`, `tools/setup_project.gd`, `tests/*`.
**Tested:** headless `--import` clean (no errors/warnings); autotest PASS both scenarios; windowed screenshots (PS1 on/off) checked visually. NOT tested by a human: feel, gamepad, camera comfort.
**Problems / notes:** first autotest showed turn speed scrub (80→19 km/h) and later a full-lock spin-out → fixed with assists (D-016). Handbrake held at speed = 180° (KI-003). Open unverified items KI-001…KI-004.
**Next session should:** collect the user's playtest feedback (checklist in the iteration note), tune, re-run autotests, close Iteration 01, then get Iteration 02 scope.


## 2026-11-11 — Session 3 — Iteration 01 playtest feedback
**Iteration:** [[Iteration 01 - It Drives]] · **Phases touched:** 01
**Goal:** apply user playtest feedback.
**Done:**
- Feedback logged in the iteration note (driving, turns, city/bumps, steering wheel approved).
- Jumps: removed throttle→nose-down air pitch; added air self-levelling (pitch+roll PD) and a landing bounce fired at suspension bottom-out + pitch damping (D-018). Measured: touchdown pitch -22°/-37° → ~0°; hop 9–11 cm.
- Handbrake: effect scaled by speed 3→12 m/s (D-019). 35 km/h handbrake turn: 178° spin → 98° controlled.
- Autotest gained metrics (landing pitch, rebound, hop) and scenarios `--handbrake-low` (+`--hb-legacy`), `--flip`.
- Kept F4 interpolation toggle (KI-001); resolved KI-003, KI-004.
**Files changed:** `src/vehicle/taxi.gd`, `tests/vehicle_autotest.gd`.
**Tested:** all 4 autotest scenarios PASS. Feel of the changes not yet rechecked by user.
**Problems / notes:** first bounce attempt (kick at first contact) was absorbed by the springs — delayed it to suspension bottom-out.
**Next session should:** get user recheck of jump/handbrake → close Iteration 01 → Iteration 02 scope.


## 2026-11-11 — Session 3 (cont.) — Arcade landing + drift chain design
**Iteration:** [[Iteration 01 - It Drives]] · **Phases touched:** 01 (+ design for 03)
**Goal:** much more noticeable arcade landing bumps; document drift-chain multiplier.
**Done:**
- Landing bounce reworked (D-020): velocity set at suspension bottom-out + suspension off while rising → hops 0.46 m / 0.69 m, nose level, no pogo. Tried and rejected: bigger impulse (absorbed), free rebound damping (erratic).
- Camera: `Taxi.landed(fall_speed)` signal → shake + springy head dip (`CabCamera` "Landing" exports).
- `--jump` autotest now logs every air phase (duration, apex, pitch).
- Design: drift chain multiplier in GDD §3b, economy tip formula, "Drift king" perk idea, implementation tasks + autotest plan in Phase 03 (D-021).
**Files changed:** `src/vehicle/taxi.gd`, `src/camera/cab_camera.gd`, `tests/vehicle_autotest.gd`; vault design/plan/progress notes.
**Tested:** drive, jump, handbrake-low, flip autotests PASS; import clean. Camera landing kick and hop feel need user recheck.
**Next session should:** user recheck (landing + handbrake) → close Iteration 01 → Iteration 02 scope.


## 2026-11-11 — Session 4 — Close Iteration 01, build Iteration 02 (City & Ride Loop)
**Iteration:** [[Iteration 01 - It Drives]] closed → [[Iteration 02 - City & Ride Loop]] · **Phases touched:** 02, 03 (+06 plan)
**Goal:** user: "close it 01 and move on to the next one" → city + core ride loop + drift chain.
**Done:**
- Closed Iteration 01 (phases 00/01 ✅).
- City (`src/world/city.gd`, `blockout.gd`, `taxi_stop.gd`): 8×8 blocks, 3 districts, plaza, 6 street ramps, lane dashes (MultiMesh), 128 named TaxiStops with beacon/ring.
- Passengers: `PassengerProfile` + 3 `.tres`, `PassengerVisual`, `WaitingPassenger` (yellow beam), `PassengerSpawner` (auto-loads profiles).
- Ride loop: `Ride`, `RideManager` (IDLE/ENTERING/RIDING/EXITING, fares, rating, time bonus, drift tips), `ShiftManager` (endless, summary, next shift).
- `DriftChain` + taxi hooks (`add_speed_boost`, `rear_slip_signed`, `teleport`, speed-gated drift assist D-025).
- HUD (`src/ui/hud/hud.gd`) + dashboard `GuideArrow`; Main now starts `game.tscn`; debug overlay hidden by default (F2).
- Tests: `tests/ride_autotest` (integration, optional screenshots), `--drift-chain` scenario, handbrake-low guard (≤130°).
**Files changed:** `src/world/*`, `src/passengers/*`, `src/ride/*`, `src/vehicle/{taxi.gd,taxi.tscn,drift_chain.gd,guide_arrow.gd}`, `src/ui/hud/hud.gd`, `src/main/{game.tscn,main.tscn}`, `src/core/resources/passenger_profile.gd`, `src/autoload/event_bus.gd`, `data/passengers/*.tres`, 9 new materials, `tests/*`.
**Tested:** import clean; vehicle autotests (drive, jump, handbrake-low, flip, drift-chain) PASS; ride autotest PASS; Main smoke 10 s clean; screenshots (start, ride started, arriving) checked.
**Problems / notes:** drift chain first lost momentum (76→28 km/h) → drift assist; that regressed the low-speed handbrake → speed-gated it (D-025). Road z-fighting fixed. Stop names now fall back to street addresses.
**Next session should:** collect Iteration 02 playtest feedback → tune → close → Iteration 03 scope.


## 2026-11-11 — Session 4 (cont.) — Handbrake 180° fix
**Iteration:** [[Iteration 02 - City & Ride Loop]] · **Phases touched:** 01 (vehicle)
**Goal:** user: "as soon as you hit the space bar the car does a 180".
**Done:** new autotest scenarios `--handbrake-high` / `--handbrake-straight` reproduced it (180° drift angle with steer; fine without). Added drift angle limiter (D-027): 40° target, peak 50°. Tried stiffness 40000/8000 (peak 63°), 60000/20000 (50°, chosen), 80000/30000 (47°).
**Files changed:** `src/vehicle/taxi.gd`, `tests/vehicle_autotest.gd`.
**Tested:** all 7 vehicle scenarios + ride test PASS.
**Next session should:** user rechecks handbrake feel + continues Iteration 02 playtest.


## 2026-11-11 — Session 4 (cont.) — Arrow + ride length
**Iteration:** [[Iteration 02 - City & Ride Loop]] · **Phases touched:** 02, 03
**Goal:** user: arrow mispositioned, wants classic top-centre; rides too short.
**Done:**
- Arrow: moved under the camera (top centre), new overlay shader (no depth test, transparent pass), compass-style orientation (tilted plate, rotates in-plane). First attempt (world yaw) was a thin sliver when the target was to the side — caught by screenshot. Final: scale 1.15, 1.3 m ahead, 0.5 up (D-028).
- Rides: profile distances roughly doubled; destination fallback no longer picks short rides (found a 122 m tourist ride in a screenshot run); ride test asserts the minimum (D-029).
**Files changed:** `src/vehicle/guide_arrow.gd`, `src/vehicle/taxi.tscn`, `src/core/shaders/ps1_overlay.gdshader` (new), `assets/materials/guide_{green,yellow}.tres`, `data/passengers/*.tres`, `src/ride/ride_manager.gd`, `tests/ride_autotest.gd`.
**Tested:** import clean; 7 vehicle scenarios + ride test PASS; screenshots checked (arrow left / ahead / up-left, destination ring).
**Next session should:** continue the Iteration 02 playtest.


## 2026-11-11 — Session 4 (cont.) — "Undriveable" drift settings
**Iteration:** [[Iteration 02 - City & Ride Loop]] · **Phases touched:** 01, 03
**Goal:** user: "car is undriveable with the current drift chain settings".
**Done:**
- New `--weave` autotest (normal S-curves, no handbrake): normal driving was fine → problem isolated to handbrake/drift assist + chain kicks.
- Reverted D-025 assist values (retention 0.7, handbrake braking 4000 N at all speeds) → Iteration 01 handling; kept D-027 limiter.
- DriftChain: handbrake-initiated drifts, own slip thresholds, smooth reward (push 0.8 m/s, +4 m/s top speed 2 s).
- Numbers: chain 5 links 76→96 km/h; weave 0 links; handbrake-low 98°; handbrake-high peak 47°.
**Files changed:** `src/vehicle/taxi.gd`, `src/vehicle/drift_chain.gd`, `tests/vehicle_autotest.gd` (backups in `_backup/2026-11-10/`).
**Tested:** 8 vehicle scenarios + ride test PASS; import clean.
**Next session should:** user rechecks driving + drift chain; ask what exactly felt undriveable if it persists.


## 2026-11-11 — Session 5 — Close Iteration 02, build Iteration 03 (Shooting)
**Iteration:** [[Iteration 02 - City & Ride Loop]] closed → [[Iteration 03 - Shooting From the Cab]] · **Phases touched:** 05
**Goal:** user: driving manageable; shooting before mechanics to polish the basics.
**Done:**
- Closed Iteration 02 (phases 02/03 ✅, balance items carried over).
- Combat foundation: `HealthComponent`, `Hitbox`, `WeaponData` + 3 weapons, `WeaponController` (viewmodel, raise/aim/hip fire, hitscan, pellets, spread, recoil, reload, switching), `CombatFx`, crosshair/hit marker/ammo HUD, `CabCamera` recoil + aim zoom + hold_look.
- Shooting range world (boards + circling target cars), F3 world switch, `--world=` / `--hold=` debug args.
- `tests/weapon_autotest` (7 checks). Fixed: auto-reload needed a re-press (now reloads on empty); flash light too strong.
**Files changed:** `src/combat/*` (new), `src/core/components/*`, `src/core/resources/weapon_data.gd`, `data/weapons/*`, `src/camera/cab_camera.gd`, `src/vehicle/taxi.tscn`, `src/ui/hud/{hud.gd,crosshair.gd}`, `src/main/main.gd`, `src/autoload/{event_bus,game_state}.gd`, `src/ui/debug/debug_overlay.gd`, `tools/setup_project.gd` (+F3; project.godot regenerated, backup `_backup/2026-11-10/project_before_it03.godot`), 10 new materials, `tests/weapon_autotest*`.
**Tested:** import clean; weapon test PASS; 8 vehicle scenarios + ride test PASS; city smoke clean; screenshots checked.
**Next session should:** collect Iteration 03 playtest feedback and tune.


## 2026-11-11 — Session 5 (cont.) — Arrow readability
**Iteration:** [[Iteration 03 - Shooting From the Cab]]
**Done:** arrow forward/backward ambiguity → tilt 40°, bright head + dark shaft (new `guide_*_dark` overlay materials), scale 1.35, lower; new `tests/arrow_shots` visual tool. Tried 30° (blob at 240p) before settling (D-034).
**Files changed:** `src/vehicle/guide_arrow.gd`, `src/vehicle/taxi.tscn`, `assets/materials/guide_{green,yellow}_dark.tres`, `tests/arrow_shots*`.
**Tested:** import clean; ride + weapon tests PASS; arrow screenshots at 0/45/90/180/-135° checked.


## 2026-11-11 — Session 6 — Close Iteration 03, build Iteration 04 (Enemies & Damage)
**Iteration:** [[Iteration 03 - Shooting From the Cab]] closed → [[Iteration 04 - Enemies & Damage]] · **Phases touched:** 06
**Goal:** user: "next logical iteration" → Claude chose Phase 06 (enemies + damage) as the next step building on driving + shooting.
**Done:**
- Player damage model (`TaxiDamage`), Hitbox `hit` signal + source, own-hitbox exclusion for player shots.
- City road graph (D-035). `EnemyCarData` + 2 enemies, `EnemyCar extends Taxi`, `EnemyDriverAI`, `EnemyGunner`, `EnemyDirector` (bounty, heat, police, F7).
- HUD: HP bars, heat, damage direction wedges, hit flash, wreck summary. Shift ends on wreck; ride fails if the passenger is shot.
- Tests: `enemy_autotest`, `enemy_city_autotest` (+ screenshot mode).
- Found & fixed via tests: crowding a parked taxi → standoff/early braking/ram-ends-on-contact (D-036); a test bug inflating damage; duplicate spawn points; damage wedges overlapping the arrow.
**Files changed:** `src/enemies/*` (new), `src/vehicle/{taxi_damage.gd,taxi.tscn}`, `src/core/components/hitbox.gd`, `src/core/resources/enemy_car_data.gd`, `data/enemies/*`, `src/world/city.gd`, `src/combat/{weapon_controller,combat_fx,shooting_range}.gd`, `src/ride/{ride_manager,shift_manager}.gd`, `src/ui/hud/{hud,status_bars,damage_indicator}.gd`, `src/autoload/event_bus.gd`, `src/main/game.tscn`, `tools/setup_project.gd` (+F7), 5 new materials, `tests/enemy_*`.
**Tested:** import clean; 8 vehicle scenarios, ride, weapon, enemy, enemy-city (5 runs) PASS; screenshots checked.
**Next session should:** collect Iteration 04 playtest feedback, tune, close; then Phase 04 dossier.


## 2026-11-11 — Session 6 (cont.) — Damage, explosions, watching your back
**Iteration:** [[Iteration 04 - Enemies & Damage]]
**Goal:** user: damage too high; crashing into hitmen gets you stuck (explode + disappear on kill); need to watch our backs.
**Done:**
- Damage: hitman 3 dmg / 4.5° spread, body hits ×0.6, cabin→body ×0.15, gentler crash damage (D-038). Survival next to two hitmen ~30 s.
- Kill → `CombatFx.explosion` + instant removal; `EventBus.explosion` camera shake; enemy mass 800 kg.
- AI: no rams on a parked taxi, locked standoff side, stopping-distance braking (D-039) — 8/8 city runs clean.
- Rear-view mirror (SubViewport) + HUD threat markers (D-040).
**Files changed:** `data/enemies/*.tres`, `src/vehicle/{taxi_damage.gd,rear_mirror.gd,taxi.tscn}`, `src/enemies/{enemy_car,enemy_driver_ai,enemy_director}.gd`, `src/combat/combat_fx.gd`, `src/camera/cab_camera.gd`, `src/ui/hud/{hud,threat_markers}.gd`, `src/autoload/event_bus.gd`, `tests/enemy_*`.
**Tested:** all 12 test runs PASS (8 vehicle scenarios, ride, weapon, enemy, enemy-city); screenshots: mirror + threat markers, hitmen standoff.
**Next session should:** user recheck of Iteration 04 → close → Phase 04 dossier.


## 2026-11-11 — Session 7 — Close Iteration 04, Iteration 05 (instant turn, energy drink)
**Iteration:** [[Iteration 04 - Enemies & Damage]] closed → [[Iteration 05 - Energy Drink & Fixes]]
**Goal:** user: "instant turn" with some key combo (then: "awful, should be removed"); add a drive-through healing energy drink.
**Done:**
- Reproduced the instant turn with new `--reverse-throttle` autotest (177°, 532°/s); cause: drift limiter on backward travel; fixed (D-041).
- `HealthComponent.heal`, `TaxiDamage.drink`, `EnergyDrinkPickup` (fictional "Monstrous Energy"), `DrinkViewmodel`, green heal flash; 12 cans in the city, 3 in the range (D-042).
- `tests/pickup_autotest` (+ screenshot mode).
**Files changed:** `src/vehicle/{taxi.gd,taxi_damage.gd,taxi.tscn}`, `src/core/components/health_component.gd`, `src/items/*` (new), `src/world/city.gd`, `src/combat/shooting_range.gd`, `src/ui/hud/damage_indicator.gd`, `src/autoload/event_bus.gd`, 5 can materials, `tests/{vehicle_autotest,pickup_autotest}*`.
**Tested:** 14 test runs PASS; screenshots of the floating can and the drink animation checked.
**Next session should:** user recheck → close Iteration 05 → Phase 04 dossier.


## 2026-11-11 — Session 7 (cont.) — Asphalt z-fighting, strategic spawn note
**Iteration:** [[Iteration 05 - Energy Drink & Fixes]]
**Done:**
- New `tests/view_shots` (screenshots down long streets). Found most lane dashes missing; root cause analysis: PS1 vertex snapping + overlapping flat planes (ground 30 cm under the road, dashes 2 cm above).
- Fix (D-043): no snapping on road/ground/lane/beacon materials, ground as 4 strips around the city, dashes 6 cm high and 0.5 m wide.
- Design note (D-044): strategic hitman spawns on the route to the objective — GDD/encounters/combat docs, Phase 07 task, TODO in `enemy_director.gd`.
**Tested:** ride, enemy, enemy-city, pickup, drive tests PASS; before/after view screenshots compared (flicker was intermittent — needs user confirmation).


## 2026-11-11 — Session 8 — Close Iteration 05, build Iteration 06 (Passenger File)
**Iteration:** [[Iteration 05 - Energy Drink & Fixes]] closed → [[Iteration 06 - Passenger File & Decisions]] · **Phases touched:** 04
**Goal:** user: "close it 05 and start with the next one" → Phase 04, the Papers, Please layer.
**Done:**
- Data: `Examinable`, `PassengerAction`, profile file fields, `PassengerInstance`; 3 passenger files (commuter, tourist w/ scenic route, executive w/ kill-for-bounty + hush money). Verified with `tools/check_profiles.gd`.
- `RideManager` DOSSIER state + outcomes (drive with modifiers / kick with reactions / kill sequence).
- Dossier UI (paper file, portrait, clickable clues, examine/action buttons, focus nav, time drain, pause handling); camera look-back + red flash on execution; HUD hint.
- Tests: new `dossier_autotest`; `ride_autotest` updated (choose Drive; runs while paused).
- Fixed via screenshot: 4th action button covered the clock.
**Files changed:** `src/dossier/*` (new), `src/core/resources/{examinable,passenger_action,passenger_profile}.gd`, `src/passengers/{passenger_instance,waiting_passenger,passenger_spawner}.gd`, `src/ride/{ride_manager,ride}.gd` (backup `_backup/2026-11-10/ride_manager_before_dossier.gd`), `src/main/{main.gd,main.tscn}`, `src/camera/cab_camera.gd`, `src/ui/hud/{hud,damage_indicator}.gd`, `src/autoload/event_bus.gd`, `data/passengers/*.tres` (commuter backup in `_backup/`), `tools/check_profiles.gd`, `tests/{dossier_autotest,ride_autotest}*`.
**Tested:** import clean; 15 test runs PASS; smoke 10 s clean; file screenshots checked.
**Next session should:** collect Iteration 06 playtest feedback → close → Phase 07 archetypes & ride events.


## 2026-11-11 — End of day handoff
**State:** Iteration 06 (passenger file) built & all automated checks PASS, **not yet playtested** by the user. Iterations 01–05 closed.
**Docs refreshed:** Status rewritten (where we left off, done table, untested items, missing, automated checks), Getting Started (project layout, controls, debug keys), Home (iteration list), Development Plan (Phase 07 next, Phase 08 started early), Iteration 06 note.
**Next session should:** 1) ask for Iteration 06 playtest feedback (checklist in the note), 2) fix/tune + re-run all tests, 3) close Iteration 06, 4) propose Iteration 07 = Phase 07 (ride events + archetypes + strategic hitman spawns, D-044).


## 2026-11-12 — Session 9 — Iteration 06 playtest feedback: passenger file UI pass
**Iteration:** [[Iteration 06 - Passenger File & Decisions]] · **Phases touched:** 04
**Goal:** user playtested Iteration 06: "UI could be improved. Everything else works as intended, tried all mechanics, none of them spawn a hostile yet."
**Done:**
- Feedback logged. Mechanics approved. "No hostile yet" is expected: hostile reactions / strategic spawns are Phase 07 (D-044).
- Rebuilt the passenger file UI (D-046): container layout, folder frame, key/value fields, clock badge + "-Ns" pop, "Look closer" chips, findings slip, two-line action buttons showing consequences, slide-in, gamepad focus flow. Public API unchanged (`open/close/examine/choose/available_action_ids/is_open`).
- `dossier_autotest` screenshot mode: 3 shots timed from the moment the file opens (`file_open`, `file_one_clue`, `file_examined`); it no longer reports a false "kill available before examining" in screenshot mode.
**Files changed:** `src/dossier/dossier.gd` (rewrite; backup `_backup/2026-11-11/dossier_before_ui_pass.gd`), `tests/dossier_autotest.gd` (backup next to it).
**Tested:** import clean; dossier, ride, weapon, enemy, enemy-city, pickup + 9 vehicle scenarios PASS; `check_profiles` output OK; 3 file screenshots checked (found and fixed: effects text overlapping long action labels → two-line buttons). NOT yet seen by the user; mouse hover states and gamepad focus not verifiable headless.
**Problems / notes:** the user did not say what exactly about the UI bothered them — the pass is Claude's interpretation and covers only the passenger file, not the driving HUD.
**Next session should:** get the user's verdict on the new file (and whether "UI" also meant the HUD) → close Iteration 06 → propose Iteration 07 = Phase 07.


## 2026-11-12 — Session 9 (cont.) — Close Iteration 06, build Iteration 07 (Archetypes & Ride Events)
**Iteration:** [[Iteration 06 - Passenger File & Decisions]] closed -> [[Iteration 07 - Archetypes & Ride Events]] · **Phases touched:** 04 (closed), 07
**Goal:** user: "Okay looks good enough for now. Close it 06 and we can move to 07."
**Done:**
- Closed Iteration 06; Phase 04 ✅.
- Ride-event framework (D-047): `src/events/` - `RideEvent`, `RideContext`, `RideEventRunner` + 8 blocks.
- Strategic spawns (D-048): `EnemyDirector.spawn_on_route` (ambush ahead / pincer / tail, line-of-sight check), AI `AMBUSH` mode.
- Mid-ride kick (D-049), `change_destination`, `fail_ride`, completion text in `RideManager`.
- 5 new archetypes + executive event (D-050); profile fields `ride_events`, `min_shift`, `kick_damage`; action field `shift_time_delta`.
- HUD: passenger subtitles, flashing alert with countdown, kick hint, bigger shift summary (kicked / shot / hitmen down / stolen). `ShiftManager` counters.
- Spawner: `min_shift`, **F8** debug (next archetype at the nearest stop).
- Tests: new `events_autotest`; `ride_autotest` boards a commuter; `check_profiles` validates every file and is now a scene.
**Files changed:** `src/events/*` (new), `src/ride/{ride_manager,ride,shift_manager}.gd`, `src/enemies/{enemy_director,enemy_driver_ai}.gd`, `src/passengers/passenger_spawner.gd`, `src/ui/hud/hud.gd`, `src/dossier/dossier.gd`, `src/core/resources/{passenger_profile,passenger_action}.gd`, `src/autoload/event_bus.gd`, `data/passengers/{businessman,burglar,hijacker,old_lady,expectant_mother}.tres` (new), `rushed_executive.tres`, `tools/{check_profiles.gd,check_profiles.tscn,setup_project.gd}`, `project.godot` (regenerated: +F8), `tests/{events_autotest.gd,events_autotest.tscn,ride_autotest.gd}`. Backups of every changed file in `_backup/2026-11-12/`.
**Tested:** import clean; `events_autotest` PASS x4; dossier, ride, weapon, enemy, enemy-city, pickup + 9 vehicle scenarios PASS; `check_profiles` OK (8 files); Main smoke 12 s clean; HUD screenshots (thief alert, hijack, gift) checked. NOT tested by a human: all feel/balance, the ambush in real driving, gamepad.
**Problems / notes:** typed `Array[RideEvent]` holding subclasses loads fine in the game but not under `--script` (autoloads missing -> scripts fail to compile) -> `check_profiles` moved to a scene. Two hijack HUD lines raced each other -> the robbery is merged into the delivery line.
**Next session should:** collect the Iteration 07 playtest (checklist in the note; F8 cycles archetypes), tune numbers (D-050), close; then likely Phase 08 items (real drops for the old lady) or Phase 09 shop.


## 2026-11-12 — End of day handoff
**State:** Iteration 07 (archetypes & ride events) built, all automated checks PASS, **not yet playtested**. User: "document where we left off and I test tomorrow". Iterations 01–06 closed.
**Nothing in progress / half-done:** no open edits; backups of today's changed files in `new-game-project/_backup/2026-11-12/` (and the pre-UI-pass dossier in `_backup/2026-11-11/`).
**Next session should:** 1) ask for the Iteration 07 playtest feedback (checklist in [[Iteration 07 - Archetypes & Ride Events]]; F8 = next archetype at the nearest stop, Q = kick out mid-ride), 2) tune D-050 numbers / fix, re-run all tests, 3) close Iteration 07, 4) ask the scope of Iteration 08 (candidates: Phase 08 items = real drops for the old lady, or Phase 09 shop).


## 2026-11-12 — Session 10 — Iteration 07 playtest feedback: no shift clock, relentless hitmen, HUD
**Iteration:** [[Iteration 07 - Archetypes & Ride Events]] · **Phases touched:** 03, 04, 06, 07
**Goal:** user playtested Iteration 07 (all archetypes work) and asked for: hitmen that keep chasing after the drop-off, no ending a fare, bolder subtitles, the passenger countdown in bold red under the arrow, **the game timer removed**; then announced the direction: open-world map base → neighbourhoods with storylines and people → shops (armory, body parts, dashboard items, perks).
**Done:**
- D-051: shift clock removed (`ShiftManager` rewritten: run ends only on a wreck; level +1 every 4 deliveries), no time bonus, examine cost moved to the passenger's ride clock (`PassengerInstance.time_spent`, `RideManager.planned_time`), file badge = RIDE TIME, `shift_time_delta` → `ride_time_delta`, `RewardEvent` `time` kind removed.
- D-052: mid-ride kick only while an event allows it (`RideContext.kick_window / kick_unlocked`, `RideManager.can_kick_mid_ride`), HUD hint follows.
- D-053: `EnemyDirector.release_ambushes()` on ride end, ambush bypass detection, relocation of outrun cars (2×, 210 m).
- D-054: HUD — red bold countdown under the arrow, destination line above it, bold subtitles, popups moved to the roof lining, alert lower.
- Tests updated: `ride_autotest` (no clock; wreck → restart), `dossier_autotest` (examine costs ride time), `events_autotest` (hitmen survive the delivery + come back when outrun; normal fare cannot be kicked; hijack unlocks the kick; bags cost ride time).
- Vault: GDD run structure, roadmap section in Development Plan, Architecture, Phase 04/07/10 notes, Known Issues (KI-019 resolved, KI-021/022 new), Decisions D-051…D-054.
**Files changed:** `src/ride/{shift_manager,ride_manager}.gd`, `src/ui/hud/hud.gd`, `src/dossier/dossier.gd`, `src/enemies/{enemy_director,enemy_driver_ai,enemy_car}.gd`, `src/events/{ride_context,steal_cash_event,force_detour_event,reward_event,spawn_pursuers_event}.gd`, `src/passengers/passenger_instance.gd`, `src/core/resources/{passenger_action,examinable}.gd`, `src/autoload/{event_bus,game_state}.gd`, `data/passengers/{old_lady,expectant_mother}.tres`, `tests/{ride,dossier,events}_autotest.gd`. Backups of the pre-change files in `_backup/2026-11-12-playtest/` (`enemy_car.gd`, `examinable.gd`, `expectant_mother.tres` were not backed up: one-line changes).
**Tested:** import clean; ride, dossier, events, weapon, enemy, enemy-city, pickup + 9 vehicle scenarios PASS; `check_profiles` OK (8 files); HUD (thief alert, hijack) and file screenshots checked. NOT tested by a human: everything above (feel of the pursuit, HUD positions, the game without a clock).
**Problems / notes:** bash heredocs with code broke again → edits were applied with small Python scripts from the scratchpad. `for car in enemies.duplicate()` loses the element type → explicit types needed. Open-world work was **not started**: it needs scope (see Status "Open questions").
**Next session should:** 1) collect the re-test (checklist in the iteration note) and close Iteration 07; 2) get the Iteration 08 scope answers and build the open-world map base.


## 2026-11-12 — Session 10 (cont.) — Iteration 08: map editor, piece kit, wreck → repair shop
**Iteration:** [[Iteration 08 - Open-World Base & Map Editor]] (new) · **Phases touched:** 01, 02, 06
**Goal:** user's scope answer: "i want a map editor, different building sizes and shapes, plazas, low stairs, ramps and such. Wreck makes the car work like shit until you go to the repair shop".
**Done:**
- D-055: `MapData` (8 m cell grid, pieces, zones, JSON in `data/maps/`, validation, built-in starter city), `MapBuilder` (buildings box / tower / stepped / l_shape / round / house, plazas steps / flat, low stairs, ramps kicker / wedge, sidewalk, containers, pillar, repair shop, editor markers), `City` rewritten to build from a map (cell road graph, automatic lane dashes, stop names per zone, player start).
- In-game **map editor** `src/editor/` (tools, properties panel, drag-rectangle placing, select / move, undo / redo, duplicate, save / load, resize, new, starter city, validation line, PLAY); **F9** in the game opens it.
- D-056: wreck → `Taxi.limp` until a `RepairShop` pad ($60); arrow + red beacon to the nearest shop; fare bails; pursuers leave; nobody boards a wreck. `ShiftManager` no longer ends the run.
- `EnemyDirector`: dense routes for ambush spots, side-street probing without the old graph, spawn clamp from the map size. `PassengerSpawner`: district restrictions only if the map has that district.
- Tests: new `map_autotest`; every test forces the built-in city; `ride_autotest` covers wreck → limp → repair; `enemy_autotest` road-graph check adapted.
**Files changed:** new `src/world/{map_data,map_builder,repair_shop}.gd`, `src/editor/{map_editor.gd,map_editor.tscn}`, `tests/map_autotest.{gd,tscn}`; rewritten `src/world/city.gd`; edited `src/vehicle/{taxi,taxi_damage}.gd`, `src/ride/{ride_manager,shift_manager}.gd`, `src/enemies/enemy_director.gd`, `src/passengers/passenger_spawner.gd`, `src/ui/hud/hud.gd`, `src/main/main.gd`, all `tests/*.gd` (one line), `tests/{ride,enemy}_autotest.gd`. Backups in `_backup/2026-11-12-openworld/`.
**Tested:** import clean; map, ride, dossier, events, weapon, enemy, enemy-city, pickup + 9 vehicle scenarios PASS; `check_profiles` OK; screenshots of the editor (starter city, small map) and of the game on the rebuilt city checked (found and fixed: sidewalk slab hiding the repair pad, roof z-fight, loud roof material). NOT tested by a human: the editor's mouse / keyboard handling in real use, driving feel on stairs / plazas, limp feel, prices, frame rate on big maps.
**Problems / notes:** the starter city changed size (384 → 400 m, 30 → 32 m blocks) to fit the 8 m grid. Editor input was exercised only through its functions (place / edit / undo), not through real mouse events. Iteration 07 is still formally open (fixes not re-tested).
**Next session should:** 1) collect the Iteration 08 playtest (editor + wreck) and the Iteration 07 re-test, fix, close both; 2) ask the scope of the neighbourhoods iteration (which neighbourhoods, what differs in each).


## 2026-11-12 — Session 10 (cont.) — Close Iteration 07
**Iteration:** [[Iteration 07 - Archetypes & Ride Events]] closed · active: [[Iteration 08 - Open-World Base & Map Editor]] · **Phases touched:** 07 (closed)
**Goal:** user: "close it07 and give me the it 08hecklist" (earlier: asked how many iterations are left → estimate 6–8 after 07 / 08, depends on the number of neighbourhoods).
**Done:** Iteration 07 marked closed (note, Home, Status, Development Plan). Iteration 08 checklist handed to the user. No code changed.
**Tested:** nothing new.
**Problems / notes:** the Iteration 07 fixes (D-051…D-054) were closed without a user re-test; they are in play in the Iteration 08 playtest.
**Next session should:** 1) collect the Iteration 08 playtest, fix, close; 2) ask the scope of the neighbourhoods iteration.


## 2026-11-12 — Session 10 (cont.) — Iteration 08 first playtest: F9 / F5 crash
**Iteration:** [[Iteration 08 - Open-World Base & Map Editor]] · **Phases touched:** 02
**Goal:** user hit "Cannot call method 'set_input_as_handled' on a null value", then "nothing works on the editor, i cant click anything nor move".
**Done:** `main.gd` (F9) and `map_editor.gd` (F5) mark the input handled BEFORE changing scene (the node leaves the tree at once). New `tests/editor_switch_autotest.{gd,tscn}`: game → F9 → editor → real key / mouse events → F5 → game.
**Tested:** import clean; ride, dossier, events, map PASS; editor switch test PASS (F9 path and `--direct`).
**Problems / notes:** the frozen editor is explained by the debugger break on that error (Claude's reading, not confirmed by the user). The switch test is sensitive to the real mouse being inside the window (one false FAIL seen).
**Next session should:** get the user's retry of the editor; continue the Iteration 08 checklist; fix; close; then the neighbourhoods scope.
- **Later, same session:** user: "is still frozen, nothing on the debugg". Diagnosis: F9 = *Suspend* in Godot's embedded game view (the key opened the editor and suspended the game at once; the debugger-break reading above was wrong). Map editor key F9 → **M**; play key **P** added next to F5. Switch test updated (M / P) and PASS. Not confirmed by the user yet.


## 2026-11-13 — Session 11 — Iteration 08 playtest: walled-in enemies, jumpable containers, more hostile situations
**Iteration:** [[Iteration 08 - Open-World Base & Map Editor]] · **Phases touched:** 02, 06, 07
**Goal:** user: "i created a map and played it for a while, it works. the enemies can appear inside the buildings with no way out. Also we need more hostiles situations. And then i want the ramps to be able to get me to jump above the containers".
**Done:**
- D-057: `City` connected regions; `EnemyDirector` spawns / relocates / ambushes only in the taxi's region, with reachable fallbacks.
- D-058: kicker default 3.0 m, containers default 1 level, map format 2 with a load-time upgrade of pieces still at the old defaults; editor help texts.
- D-059: `StreetEncounter` resource + `StreetEncounters` node (5 encounters in `data/events/`, debug key H), `EnemyDirector.point_ahead()`, `EnemyCarData.mass`, enemies `bruiser` and `gang_coupe` (+ 2 materials), passengers `bank_robber`, `key_witness`, `gang_courier`.
- New tests `tests/hostiles_autotest` and `tests/jump_autotest`.
**Files changed:** `src/world/{city,map_data}.gd`, `src/enemies/{enemy_director,enemy_car}.gd`, `src/core/resources/enemy_car_data.gd`, `src/editor/map_editor.gd` (help texts), `src/main/game.tscn`; new `src/enemies/street_encounters.gd`, `src/core/resources/street_encounter.gd`, `data/events/*.tres` (5), `data/enemies/{bruiser,gang_coupe}.tres`, `data/passengers/{bank_robber,key_witness,gang_courier}.tres`, `assets/materials/{enemy_bruiser,enemy_gang}.tres`, the two tests. Backups in `_backup/2026-11-13-hostiles/`. The user's `data/maps/test1.json` was read, not written.
**Tested:** import clean; hostiles, jump, map, ride, dossier, events, weapon, enemy, enemy-city, pickup, 9 vehicle scenarios PASS; `check_profiles` OK (11 files); the game loads the user's map `test1` headless without errors. NOT tested by a human: all of the above in play; the new cars and passengers were never looked at on screen.
**Problems / notes:** "more hostile situations" was not specified; D-059 is Claude's reading. The earlier M / P key change was never explicitly confirmed, but the user reached the editor and played their map.
**Next session should:** 1) collect the re-test (6 points in the iteration note), tune; 2) close Iteration 08; 3) ask the scope of the neighbourhoods iteration.


## 2026-11-13 — Session 12 — Sidewalks damaging the car
**Iteration:** [[Iteration 08 - Open-World Base & Map Editor]] · **Phases touched:** 01, 06
**Goal:** user: "i think the sidewalks are damaging the car".
**Done:**
- New `tests/curb_autotest.{gd,tscn}`: drives onto / across / off a sidewalk slab at several speeds and angles, braking, handbraking, boosting, and landing a jump just before the edge.
- Found: flat-ground driving over a 0.2 m sidewalk is harmless; after a landing the compressed suspension let the chassis box hit the curb's side (dead stop, dv 24 m/s).
- D-060: chassis collision box raised (taxi + enemy cars) so it clears curbs at full compression.
**Files changed:** `src/vehicle/taxi.tscn` (CollisionBody shape / offset), `src/enemies/enemy_car.gd` (`_build_body`), new `tests/curb_autotest.{gd,tscn}`. Backups in `_backup/2026-11-13-curbs/`.
**Tested:** import clean; curb, 9 vehicle scenarios, jump, map, ride, enemy, enemy-city, hostiles, events PASS. Not re-run (untouched systems): dossier, weapon, pickup, editor switch, profile check. NOT tested by a human.
**Problems / notes:** the user did not say where or how it happened; the landing case is what the probe reproduced. If damage still shows up on sidewalks, ask for the spot (which piece, speed, after a jump or not). The first probe run was invalid (the city moves the taxi to the player start; tests must `teleport()` after that).
**Next session should:** 1) get the re-test (now 7 points in the iteration note); 2) close Iteration 08; 3) ask the scope of the neighbourhoods iteration.
