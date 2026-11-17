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


## 2026-11-15 — Session 13 — Docs match the repo; main menu, tutorial, polish, local build
**Iteration:** [[Iteration 09 - Menu, Tutorial & Build]] (new) · [[Iteration 08 - Open-World Base & Map Editor]] still open · **Phases touched:** 10, 12 (export)
**Goal:** user: "update the docs to match, the goal for this session will be to create a very simple main menu and tutorial (really short) and to polish some small stuff and then compile a complete build for local testing".
**Done:**
- Docs: the project is now the git repo `taxi-driver-game/` (project at the root, vault in `docs/`): [[CLAUDE]] §1 / §5 / §6 (git rules replace "no git"), [[Getting Started]] (tech table, layout, running, controls, map paths), [[Architecture]]. New root `CLAUDE.md` pointer. `.gitignore` += `/build/`.
- D-061: `src/ui/menu/main_menu.{gd,tscn}` = main scene; pause menu in `main.gd` (resume / skip tutorial / main menu / quit + run stats → KI-025 resolved); F11 fullscreen in `InputDevice`; editor "Main menu" button.
- D-062: `src/ui/tutorial/tutorial.gd` (Main/UI/Tutorial), `GameState.tutorial_active`, `PassengerSpawner.tutorial_profiles` / `tutorial_profile()`, `StreetEncounters` off during it.
- D-063: `export_presets.cfg`, `MapData.save_dir()` / `find_path()` (user://maps/ in builds), `config/version` 0.9.0. Build exported to `build/windows/`.
- Fix: `tests/editor_switch_autotest` deleted `user://active_map.txt` at the end (the user's `TEST1` choice was lost after every run); it now restores the previous choice and removes the throw-away map file.
**Files changed:** `project.godot` (via `tools/setup_project.gd`), `src/main/{main.gd,main.tscn}`, `src/autoload/{game_state,input_device}.gd`, `src/passengers/passenger_spawner.gd`, `src/enemies/street_encounters.gd`, `src/world/map_data.gd`, `src/editor/map_editor.gd`, `tests/editor_switch_autotest.gd`; new `src/ui/menu/*`, `src/ui/tutorial/tutorial.gd`, `tests/{tutorial_autotest,ui_shots}.{gd,tscn}`, `export_presets.cfg`, `CLAUDE.md`. The user's `data/maps/test1.json` was not touched (it was already modified in git before the session). Nothing committed.
**Tested:** import clean; tutorial (new), ride, dossier, events, map, hostiles, enemy, enemy-city, pickup, weapon, jump, curb, vehicle, editor switch PASS; profiles OK; menu / controls / tutorial / pause screenshots looked at (pause overlay darkened after the first look); exe: headless boot to the menu, `--map=test1` and `--map=builtin` load without errors, windowed screenshot renders (D3D12). NOT tested by a human: anything in the build, gamepad navigation of the menus, fullscreen toggle.
**Problems / notes:** a shell heredoc ate a `\a` in a Windows path in Getting Started (fixed). The polish items were Claude's pick — the user did not list any.
**Next session should:** 1) collect the build playtest (Iteration 09, 7 points) and the Iteration 08 re-test; 2) close both; 3) ask the scope of the neighbourhoods iteration.


## 2026-11-15 — Session 14 — Street life, new fares, gun shop, weapon hotbar
**Iteration:** [[Iteration 10 - Street Life, Gun Shop & Weapon Bar]] (new) · 08 and 09 still await playtests · **Phases touched:** 02, 05, 07, 09
**Goal:** user: "i want to add a little variety of npcs and drives, the weapon shop witha couple of options and a better ui for weapon selection that is more visually clear". Asked what "npcs and drives" meant → "Both" (street life + new passengers).
**Done:**
- D-064: `WeaponData` slot / blurb / prices, `data/weapons/rifle.tres`, start with the revolver, `WeaponController` add / refill / catalogue / slot keys; `gunshop` map piece (`MapData`, `MapBuilder._gunshop`, `City`, editor), `src/world/gun_shop.gd`, `src/ui/shop/gun_shop_ui.gd` in Main/UI; Main ignores Esc while the shop is open; two gun shops in the built-in city.
- D-067: `src/ui/hud/weapon_bar.gd` replaces the weapon text in `hud.gd`; bottom hint moved right.
- D-065: `src/world/{street_life,pedestrian,traffic_car,traffic_ai}.gd`, StreetLife node in `game.tscn`, `EnemyCar.build_body / build_wheels` static, `City.is_plain_street`, `EventBus.pedestrian_hit`, "Pedestrians hit" in `ShiftManager` + pause stats.
- D-066: `data/passengers/{dog_in_a_suit,night_nurse,future_man,street_musician}.tres`.
- Tests: new `tests/shop_autotest`, `tests/streetlife_autotest`; `weapon_autotest` now sets all four guns owned; `enemy_city_autotest` prints where a stuck hitman is.
- Version 0.10.0, build re-exported.
**Files changed:** see above + `src/autoload/{game_state,event_bus}.gd`, `src/main/{main.gd,main.tscn,game.tscn}`, `src/enemies/enemy_car.gd`, `src/world/{city,map_data,map_builder}.gd`, `src/editor/map_editor.gd`, `src/ride/shift_manager.gd`, `src/ui/hud/hud.gd`, `data/weapons/*.tres`, `tools/setup_project.gd`, `project.godot`. User maps untouched. Nothing committed.
**Tested:** listed in [[Status]]. First street-life run found half the traffic frozen: the look-ahead ray hit building walls while cars approached a corner → vehicles-only ray (all 8 drive since). The street-life test also tripped on recycled cars (test fix). `enemy_city` failures checked against a clean worktree of the last commit: same flakiness there (KI-029). NOT tested by a human: everything.
**Problems / notes:** the editor-switch test passed 2 of 5 windowed runs, failing on its select click (real mouse suspected, editor input untouched). `TEST1` has no gun shop.
**Next session should:** 1) playtest of build 0.10.0 (Iterations 08-10); 2) fix, close; 3) next scope (neighbourhoods or more shops).


## 2026-11-15 — Session 14 (cont.) — Money carried over into a new run
**Iteration:** [[Iteration 10 - Street Life, Gun Shop & Weapon Bar]] · **Phases touched:** 10
**Goal:** user: "I THINK THE MONEY IS SAVING even when you start a new run".
**Done:** D-068 — the map editor's PLAY now resets the run (it was the only entry to the game without `GameState.reset_run()`; nothing is ever written to a save file). Regression check added to `tests/editor_switch_autotest`. Build re-exported.
**Tested:** tutorial, map PASS; editor switch: the new cash / guns check passes (cash $0, revolver only after P) but the run FAILED on its mouse-click steps both times — the user was using the PC (they saved `TEST1` at 01:37 with three new 1x1 gun shops while the test ran). The test never wrote `test1.json` (no test pillar in it).
**Problems / notes:** don't run windowed tests while the user is working. The user's gun shops are 1x1 (tiny store, still works; 3x3+ looks right).
**Next session should:** as before — playtest of the build (Iterations 08-10).


<!-- Sessions below were logged on Nico's branch in parallel (same session numbers, different machine). Merged 2026-11-15; his decision ids renamed D-06x -> DV-06x. -->

## 2026-11-14 — Session 13 (Nico, branch `feat/visuals-and-audio`) — Claude tooling, doc paths, and the start of the texture pass
**Iteration:** [[Iteration 09V - Texture Pass]] (new) · **Phases touched:** 00 (art pipeline)
**Goal:** user: set up the best AI tooling first; then "Vamos por texturas primero" / "Solo CC0".
**Done:**
- **Tooling research.** No official Godot MCP exists (neither Anthropic nor the Godot Foundation);
  every one is community-made. Checked the main ones against the GitHub API: Coding-Solo/godot-mcp
  (6.6k stars but last push 2026-04-16, 75 open issues), tugcantopaloglu (512, active, MIT),
  3ddelano/gdai (no license file), mkdevkit (4 commits), NPGameDev (15 stars). **Verdict: no MCP for
  now** — the headless autotests already cover running the game and reading errors, and an MCP would
  mean a third-party addon inside `res://` (CLAUDE.md §4). Installed instead the skills plugin
  `godot@awesome-gamedev-agent-skills` (Apache-2.0, 8.8k stars, 16 Godot skills, knowledge only, no
  addon in the project).
- **Doc paths fixed.** Created the missing root `CLAUDE.md` (it was referenced but did not exist, so
  the vault rules were never auto-loaded). Replaced the `C:\Users\DLain\...` paths and the
  `Crazytaxi/` vault name in `docs/CLAUDE.md` and `docs/Getting Started.md` with this machine's; the
  14 `<console exe>` commands are now `<godot exe>` (**there is no `_console.exe` build installed and
  it is not needed — the normal exe prints to stdout from the shell, verified**). §6 "no version
  control" updated: the project is a git repo on `main` now.
- **Texture pack chosen** (user: CC0 only): PSX Textures Vol. 1 by Francisco Cidade, CC0, 90 seamless
  textures x 5 looks, already 32-128 px and 16-32 colours with dither. **Not downloaded yet — the
  user has to do that** (itch.io). `assets/textures/README.md` has the drop-in instructions,
  the material-to-family mapping and the import settings.
- **DV-061 implemented:** `ps1_world.gdshader` rewritten — single `base_uv` so affine mapping works
  for any UV source, `uv_mode` 1 = world-space planar UVs, and a procedural facade window grid with
  randomly lit windows driving `EMISSION`. 13 materials patched (3 buildings with windows + varied
  grids, 10 surfaces moved to world UVs, ready for the pack).
**Files changed:** `src/core/shaders/ps1_world.gdshader` (rewritten, 150 lines);
`assets/materials/{building_a,building_b,building_c,road,sidewalk,ground,wall,container_blue,container_green,container_red,prop,ramp,lane_marking}.tres`;
new `assets/textures/README.md`, new `CLAUDE.md` (root), new
`docs/05 - Iterations/Iteration 09V - Texture Pass.md`; `docs/CLAUDE.md`, `docs/Getting Started.md`.
No backup folder this time: everything is committed in git (DV-061 is the first change to rely on it).
**Tested:** import clean. map, ride, hostiles, enemy, enemy-city, weapon, dossier, pickup, curb, jump
and the 9 vehicle scenarios PASS; `check_profiles` OK (11 files). Before/after/tuned screenshots from
`tests/view_shots.tscn` — the city now reads as a city: window grids on every facade, some lit.
NOT tested by a human: everything above in play.
**Problems / notes:** `events_autotest` **failed once and then passed 9 times in a row** with no
change in between — logged as KI-026. A shader/material change cannot affect headless gameplay
logic, so this looks like pre-existing flakiness, not a regression; worth watching.
First tuning pass was needed: the initial 3.0-3.4 m cells with a 4.5-6 m ground floor gave short
buildings a single clipped row of windows that read as a black stripe, and pure-dark glass made
facades look punched through. Cells are smaller now and unlit glass only replaces 72 % of the wall.
**Next session should:** 1) get the user's eye on the windows (size, density, how many lit);
2) the user drops the CC0 pack in `assets/textures/` → wire the textures material by material;
3) still pending from before: the Iteration 08 re-test (7 points) and closing it.

### Session 13 (cont.) — the pack is in
The user downloaded **A_classic** and copied it to `assets/textures/A_classic/` (90 PNGs, 64x64,
9 families). Wired that same session:
- **Import settings fixed before first use:** all 90 `.import` files now have
  `detect_3d/compress_to=0`. Godot's default is 1, which silently re-imports a texture as
  VRAM-compressed **with mipmaps** the first time it is used in 3D — that would have smeared the
  pack's ordered dither into mush. `mipmaps/generate=false` and `compress/mode=0` (lossless) kept.
- **Albedo rebalanced, not replaced (DV-062).** The shader does `albedo * texture`, so pasting a
  texture whose mean is 0.25 onto a material would have darkened the whole city. Each textured
  material's flat colour is now divided by its texture's mean RGB (clamped at 1.6), so the average
  surface brightness stays exactly where the blockout had it and the texture only adds grain. The
  palette from [[Art Direction]] survives.
- **10 materials textured:** `road` Concrete042A 6 m, `ground` Concrete031 8 m, `sidewalk`
  Concrete034 2 m, `wall` Concrete034 2.5 m, `building_a` Bricks074, `building_b` Plaster003,
  `building_c` Plaster001 (all 2.5 m), `container_blue/green/red` Metal032 2 m.
- **Three corrections after looking at the screenshots:** PaintedPlaster010 read as camouflage
  blobs on the facades (-> Plaster001); Concrete030's vertical streaks read as marble on `wall`
  (-> Concrete034); buildings at 4 m per tile made every brick ~50 cm wide (-> 2.5 m).
  `prop` and `ramp` were textured and reverted to flat colour: a metal texture turned the repair
  shop into speckled noise, and a ramp has to read as a ramp at speed ([[Art Direction]]: texture
  only where it helps readability).
**Tested:** import clean; map, ride, hostiles, enemy, enemy-city, weapon, dossier, pickup, curb,
jump PASS. **`events_autotest` failed a second time** (KI-026) and then passed 10 runs in a row,
including 2 forced right after a re-import to test a "first run after import" hypothesis — not
reproduced, not diagnosed. NOT tested by a human.
**Next session should:** 1) the user's eye on the textures in motion (tiling, scale, shimmer) and on
the windows; 2) lighting + night palette is the obvious next multiplier (lit windows already emit);
3) still pending: the Iteration 08 re-test (7 points) and closing it.

### Session 13 (cont. 2) — first playtest of the textures: the road was swimming
**User:** *"hay como un efecto psicodelico con las texturas... se nota sobre todo con las calles, es
como que se estiran y se mueven"*, with a screenshot of smeared road.
**Diagnosis:** affine texture mapping (D-010), visible for the first time. It has been at full
strength since Phase 00, but a flat colour has no detail to warp — Iteration 09 gave it something
to warp. Worst case by construction: the road is the largest surface and is always seen at a
grazing angle, and the four ground strips had no subdivision at all.
**Done (DV-063):** road tessellated 12 m -> 6 m quads; ground strips subdivided at 12 m;
`affine_multiplier` 0.25 on `road` / `ground`, 0.5 on `sidewalk`, 1.0 everywhere else;
road texture `Concrete042A` -> `Gravel023` at 3 m (its vertical streaks were being stretched into
long smears — isotropic grain gives the eye nothing to track). Albedo rebalanced (DV-062).
**Files changed:** `src/world/city.gd` (road + ground subdivision), `assets/materials/{road,ground,sidewalk}.tres`.
**Tested:** import clean; map, ride, curb, jump, hostiles, enemy-city, events, enemy, weapon,
dossier, pickup PASS (this time with stdout captured to files per KI-026 — no FAIL lines).
**NOT tested:** in motion, which is the only place the artefact exists. That re-test is the next thing.
**Note:** the road went from ~2.2k to ~8.7k triangles on a 400 x 400 m map — irrelevant.

### Session 13 (cont. 3) — DV-063 approved, dials documented
User re-tested the road after DV-063: **"me gusta!"**, and asked for the decision to be left written
down in case it needs adjusting again. Added [[Art Direction]] > **"Tuning the PS1 look"**: the
three global settings, the four per-material parameters, the window parameters, and a
"if someone complains about X, reach for Y" list (swimming road → `affine_multiplier`, then
tessellation, then whether the texture has a direction; wobble → `snap_multiplier`; too dark →
`albedo`, never the texture). DV-063 marked confirmed in play. Iteration 09 acceptance list ticked
and the note marked **ready to close**; its Result summary is written.
**Next session should:** 1) close Iteration 09; 2) **the Iteration 08 re-test is now the oldest open
item (7 of 10 points, since 2026-11-13)** — editor, user map, stairs / plazas / ramps, wreck →
limp → repair; 3) then lighting + night palette, which is the next big visual multiplier now that
lit windows already emit.


## 2026-11-14 — Session 14 (Nico, branch `feat/visuals-and-audio`) — Iteration 10: lights and night
**Iteration:** [[Iteration 10V - Lights & Night]] (new) · **Phases touched:** 11 (the lighting half of juice)
**Goal:** user: "Luces y noche", chosen over the Iteration 08 re-test.
**Done (DV-064):**
- **`src/world/lighting.gd`** (new): day / dusk / night moods — sky, ambient, sun, fog, lamp energy,
  window emission. **Dusk is the default**, as [[Art Direction]] specified back in Phase 00.
  `Blockout.add_environment()` now takes a mood and returns `{env, sun}`; `City.set_mood()` applies
  one live; **F6** cycles in play (new action `debug_cycle_mood` in `tools/setup_project.gd`).
- **Street lamps**: `City._build_street_lamps()` puts one on every kerb cell every 4 cells (32 m),
  capped at 420 — 311 on the starter city. Two MultiMeshes + shadowless omni lights, **no collision**.
- **Taxi headlights** in `taxi.gd`, always on, plus emissive lenses and `assets/materials/headlight.tres`.
- **`ps1_world.gdshader` lit per pixel** (`vertex_lighting` dropped): with 6 m road quads (DV-063) a
  vertex-lit lamp pool would be a faceted blob.
- Dusk and night lifted after the first screenshots — the first pass was atmospheric and unplayable.
**The headlight dead end, written down because it looked like a bug:** at energy 3.2 the headlights
lit nothing, and at 20 still nothing. Isolated it with a temporary green omni probe on the taxi —
the road lit up fine, so the surface receives light and spots were not broken. The cause is geometry:
a headlight 0.6 m above a flat road grazes it (`N·L ≈ sin(4°) ≈ 0.07`) against an albedo of ~0.17,
and aiming it steeply down instead buries the pool under the car's own bodywork. Settled at y +0.35,
-6°, energy 45, which lands the pool 5-25 m ahead and catches the kerbs.
**Files changed:** new `src/world/lighting.gd`, `assets/materials/{lamp_post,lamp_head,headlight}.tres`,
`docs/05 - Iterations/Iteration 10V - Lights & Night.md`; edited `src/world/{blockout,city}.gd`,
`src/vehicle/taxi.gd`, `src/main/main.gd`, `src/core/shaders/ps1_world.gdshader`,
`tools/setup_project.gd` + `project.godot` (the F6 action).
**Tested:** import clean; **the 9 vehicle scenarios** (taxi.gd changed), map, ride, events, hostiles,
enemy, enemy-city, weapon, dossier, pickup, curb, jump PASS; `check_profiles` OK (11 files). Output
captured to files per KI-026 — no FAIL lines anywhere, `events_autotest` included.
**Performance:** 165 FPS / 6.06 ms with 311 lamps — pinned to this machine's vsync cap (RTX 4070 Ti
SUPER). No shadows anywhere. One GPU is not a floor.
**NOT tested by a human:** all of it. The mood has to be chosen by playing (F6).
**Next session should:** 1) the user picks the mood and says whether it is drivable; 2) close
Iteration 10 and then 09; 3) **the Iteration 08 re-test is now two sessions old** (7 of 10 points).

### Session 14 (cont.) — the user played all three moods
**Feedback:** *"Muy bueno! Y lo ideal sería tener variedad. Probe todas y se ven y sienten bien."*
All three moods stay. Two things came out of it:
1. **Bug (fixed, DV-065):** in daylight the street lamps' glass, the lit windows and the taxi's
   headlights all kept burning. DV-064 had only switched off the lamps' omni lights. Added
   `EventBus.mood_changed`, three per-mood values in `Lighting` (`lamp_glow`, `window_lit`,
   `headlights_on()`), a `window_lit_amount` shader uniform and an unlit headlight-lens material.
   Verified headless by forcing each mood: `headlights OFF` at day, `ON` at dusk.
2. **Request (deferred, written into [[Phase 10 - Game Flow, UI & Save]]):** choosing the time of
   day when starting a game, from the main menu. F6 stays as the development key. Not built — the
   menu does not exist yet, and the moods are already data, so it will be one menu option.
**Tested:** import clean; map, ride, events, hostiles, enemy, enemy-city, weapon, dossier, pickup,
curb, jump, vehicle PASS, output captured to files (KI-026), no FAIL lines.
**Next session should:** 1) close Iterations 10 and 09; 2) **the Iteration 08 re-test**, now the
oldest open item by two sessions.


## 2026-11-14 — Session 15 (Nico, branch `feat/visuals-and-audio`) — Iteration 11: audio
**Iteration:** [[Iteration 11V - Audio]] (new) · **Phases touched:** 11 (the audio half)
**Goal:** user: "Audio", with Iteration 08 out being playtested by a friend — so nothing was
touched in the editor, the piece kit, map data or the wreck → repair loop.
**Done (DV-066):**
- **Closed Iterations 09 and 10** first, both approved in play.
- **`tools/gen_sfx.py`**: generates all 21 sounds into `assets/audio/` (22050 Hz mono 16-bit,
  numpy, fixed seed). Loops are seamless by construction — whole numbers of cycles, and noise built
  by random-phasing a shaped spectrum, which is periodic by definition (measured wrap discontinuity
  0.003-0.006 on the engine layers). Chosen over sampling because **no clean CC0 car-engine loop
  exists**: Kenney has no vehicle audio, and the Freesound CC0 candidates are a truck idle, a
  sci-fi hover vehicle and a 1:48 Mini recording with no loop point.
- **`src/autoload/audio.gd`**: six buses (created idempotently in code, not a `.tres`), pooled
  one-shot players flat (10) and positional (16), `make_loop()` for continuous sources, volume API,
  and **it connects to the EventBus itself** — 14 sounds wired without a single gameplay script
  learning about audio. Silent whenever `DisplayServer` is headless.
- **Taxi engine**: three loops crossfaded by a lagging `_revs` and pitched 0.72-1.65, lifted by the
  throttle at a standstill, pushed by boost, held low and flat by `limp`. Tyre screech driven by the
  `rear_slip_signed` the drift logic already computed.
- **Two new EventBus signals**, `weapon_reloading` and `weapon_empty`, emitted by
  `weapon_controller.gd` — the only gameplay file touched, and only to announce what it already did.
**Files changed:** new `tools/gen_sfx.py`, `src/autoload/audio.gd`, `assets/audio/` (21 wav + imports),
`docs/05 - Iterations/Iteration 11V - Audio.md`; edited `src/autoload/event_bus.gd`,
`src/combat/weapon_controller.gd`, `src/vehicle/taxi.gd`, `tools/setup_project.gd` + `project.godot`
(the `Audio` autoload), `docs/03 - Architecture/Architecture.md`, Phase 11.
**Tested:** import clean; map, ride, events, hostiles, enemy, enemy-city, weapon, dossier, pickup,
curb, jump, vehicle PASS; `check_profiles` OK. Cross-checked every generated file against the names
referenced in code (that is how `reload` and `empty_click` were found unwired). Windowed run: all
four loops report `playing = true`, no warnings, no missing sounds.
**NOT verified: how it sounds.** Loop continuity, levels, name resolution and playback are objective
and were checked. Pleasant / too loud / grating is the user's call.
**Next session should:** 1) the user listens and says what is wrong; 2) the friend's Iteration 08
feedback when it arrives; 3) deferred from here: music and radio, reverb, enemy engines, volume UI.

### Session 15 (cont.) — the car was the one thing with no sound
**User:** everything worked except the taxi itself (no engine, no tyres) and the NPC cars.
**Bug (DV-067):** the loops played once and stopped. Diagnosed by printing player state once a
second in a windowed run — `playing=false`, `loop=0`, volume and bus fine. Godot's `edit/loop_mode`
was written into the `.import` files after the bank had already been imported, and `--import`
reused the cached `.sample`. **My earlier verification was worthless**: it printed `playing = true`
in the same frame as `play()`, which a one-shot also does. Looping is now forced on the resource in
`Audio._force_loop()`, where regenerating the bank cannot lose it.
**Gap (DV-067):** enemy cars never had an engine — scoped out of Iteration 11, but the user expected
it. New `Audio.make_loop_3d()`, one positional layer per car pitched by speed, 80 m, -14 dB,
silenced on death. Also lifted the taxi's idle (-9 → -6 dB, floor 0.35 → 0.45).
**Files changed:** `src/autoload/audio.gd`, `src/vehicle/taxi.gd`, `src/enemies/enemy_car.gd`.
**Tested:** import clean; the 12 autotests PASS; windowed: the taxi's four loops still playing
seconds later with `loop=1`, enemy cars starting their own.
**Next session should:** 1) the user's second listen; 2) the friend's Iteration 08 feedback.

### Session 15 (cont. 2) — the engine gets a gearbox
**User, second listen:** engine too shrill at high revs; a constant tone with no gear changes is
unrealistic and annoying; sliding and braking do not sound like rubber on a road.
**Done (DV-068):**
- **Five-speed gearbox** (18 / 37 / 58 / 84 / 119 km/h), revs running up inside a gear and dropping
  on the shift, 0.16 s throttle-cut dip, hysteresis against flutter.
- **Pitch from revs, timbre from road speed** — so shifting does not reset the engine to an idle note.
- **Less shrill:** pitch range 0.72-1.65 → 0.80-1.24, and the samples regenerated lower with fewer
  partials (fundamentals 42/78/132 → 38/64/96 Hz, harmonics 14/18/22 → 12/14/15).
- **Screech rebuilt**: four resonances (690/1180/1760/2550 Hz) each wobbling at its own rate over
  broadband scrub and contact rumble, instead of one band of noise with a warble.
- **Braking now screeches at all** — it was driven only by lateral slip, so straight-line stops were
  silent. Pitched 0.76 for locked wheels against 0.84-1.16 for a drift.
**Verified in a windowed drive:** upshifts at 18/37/58/84 km/h (revs 0.82-0.98), downshifts at
81/55/33/14 km/h (revs 0.04-0.13), and both tyre modes firing with the expected pitches.
**Tested:** import clean; the 9 vehicle scenarios + map, ride, events, hostiles, enemy, enemy-city,
weapon, dossier, pickup, curb, jump PASS.
**Next session should:** the user's third listen; then the friend's Iteration 08 feedback.

## 2026-11-15 — Session 16 — Branches, playtest merge, heat / fares / game over (Iteration 12)
**Iteration:** [[Iteration 12 - Heat, Fares & Game Over]] (new) · **Phases touched:** 03, 05, 06, 07, 10, 11
**Goal:** read the project, put the uncommitted Iterations 09-10 work on a branch, try Nico's branch, merge both for a friend's playtest, then a batch of user requests (heat, ammo, music + options, procedural passengers, drop-offs, destructible traffic, hostile markers, death).
**Done:**
- Git: `feature/iterations-09-10` created, Iterations 09-10 committed (`ac1b810`). Fetched Nico's `feat/visuals-and-audio` (one commit `5789037`: textures, lights, audio). Throw-away `temp/playtest-merge` with both (D-069, `aa8be56`); Iteration 12 committed on it (`8e36cf3`). Push refused: 403 (solved 2026-11-16, session 17).
- Answered license questions: Sonniss GDC bundle (commercial OK, no attribution, no redistribution of raw files — careful in a public repo) and CC0 (fully free).
- D-070 heat + price on your head; D-071 music + OPTIONS; D-072 ammo; D-073 procedural passengers; D-074 curbside drop-offs; D-075 destructible traffic + civilian crimes; D-076 hostile marker; D-077 death = game over. Difficulty pulled back "in between" after the user found the first pass really hard.
- Docs: Nico's dropped notes restored (DV-061…DV-068), this entry, [[Status]], [[Known Issues]], new iteration note.
- Builds: 0.10.0 (yours only), then 0.10.1 … 0.10.5 full; 0.10.5 also as `build/TaxiDriver-0.10.5-windows.7z` (28.7 MB; the zip was 42.6 MB, over the 30 MB upload limit) sent to the user for a friend.
**Files changed:** `src/enemies/{enemy_director,enemy_car,hostile_marker}.gd`, `src/autoload/{audio,event_bus}.gd`, `src/main/main.gd`, `src/ui/menu/{main_menu,options_menu}.gd`, `src/ui/hud/hud.gd`, `src/passengers/{passenger_generator,passenger_spawner}.gd`, `src/ride/ride_manager.gd`, `src/world/{city,taxi_stop,traffic_car}.gd`, `src/vehicle/taxi_damage.gd`, `data/weapons/*.tres`, `assets/audio/Model & HLS - H Funck.mp3`, tests `heat_passengers_autotest` (new), `ride`, `weapon`, `shop`, `map`. User map `test1.json` committed as-is in `ac1b810`, never edited.
**Tested:** all 16 autotests PASS on the final code (new `heat_passengers` A-H); `hostiles` flaky ~1/5 — also on a clean worktree of the merge (1/8), KI-032; `enemy_city` flaky as before (KI-029); `weapon` failed once on shotgun pellets, then 4/4. Screenshots: hostile marker vs civilian, game-over screen. Build smoke-tested on `TEST1`. The user played 0.10.4 (reported the wreck bug → fixed). NOT tested by a human: music, options, generated passengers, curbside stops, bounty waves, final difficulty.
**Problems / notes:** both branches numbered decisions D-061…D-068 and iterations 09-11 independently — reconciled in docs only (D-069). The song is a third-party track; the user chose to push it to a public repo (KI-034). Script export mode 2 hides strings in the exe, so build contents can't be grepped.
**Next session should:** 1) get the playtest of 0.10.5 (user + friend + Nico) against the Iteration 12 checklist; 2) sort out repo access with Nico and push; 3) decide whether `temp/playtest-merge` becomes the integration branch.

## 2026-11-16 — Session 17 — Push the playtest branch
**Iteration:** [[Iteration 12 - Heat, Fares & Game Over]] · **Phases touched:** —
**Goal:** push `temp/playtest-merge` now that DLain47 is a collaborator on Nico's repo.
**Done:**
- First push still 403: the collaborator invite was pending. The user accepted it; `temp/playtest-merge` pushed to `origin` with upstream tracking.
- KI-033 removed from [[Known Issues]] (user request); references updated in [[Status]], D-069, Iteration 12 note.
**Files changed:** docs only.
**Tested:** n/a (git / docs)
**Problems / notes:** `feature/iterations-09-10` is still local only.
**Next session should:** get the playtest of 0.10.5 against the Iteration 12 checklist; decide whether `temp/playtest-merge` becomes the integration branch.


## 2026-11-16 — Session 17 — Iteration 13: closing the seams of the merge
**Iteration:** [[Iteration 13 - Merge Integration]] (new) · **Phases touched:** 11
**Goal:** user: "hagamos una iteración corta de integración", with the music track explicitly left
in stand-by (KI-034).
**Review of the merge first:** all 16 autotests pass on `temp/playtest-merge`, the visuals survived
intact, and DLain47 **extended** the `Audio` autoload (volume sliders, saved settings, music bus)
rather than forking it. The merge is healthy.
**Done (D-078):**
- **The real integration bug:** `TrafficCar extends Taxi`, so every civilian car inherited the
  player's **non-positional** engine rig — 13 cars x 4 loops = 52 flat loops at the driver's own
  volume regardless of distance. `Taxi.engine_audio_local` now gates it; civilians run one
  positional layer at -21 dB over 55 m, like the enemy cars. Measured before and after.
- **Tail lights** on `Taxi`, inherited by every civilian: emissive lenses, dim red at dusk/night,
  bright under brake or handbrake, off in daylight except when braking. No extra `Light3D`.
- **D-079:** Nico's iteration notes renamed `09V` / `10V` / `11V` (`git mv`), matching the `DV-`
  decisions; numbering shared again from 13. References updated; convention recorded in
  [[CLAUDE]] §8 and [[Status]].
**A correction worth keeping:** the first review claimed traffic and pedestrians had no lights.
Wrong — grepping `traffic_car.gd` missed what it inherits. Measuring found the opposite problem.
**Files changed:** `src/vehicle/taxi.gd`, `src/world/traffic_car.gd`, new
`assets/materials/taillight{,_brake,_off}.tres`, new `docs/05 - Iterations/Iteration 13 - Merge
Integration.md`, renamed Nico's three iteration notes, `docs/CLAUDE.md`, [[Status]], [[00 - Home]].
**Tested:** import clean; all 16 autotests PASS. Night screenshot taken; tail lamps verified by
state at both moods on both car types. NOT seen by a human in motion.
**Problems / notes:** `streetlife_autotest` failed once windowed, passed every headless run.
**Next session should:** 1) the user drives a night street with traffic; 2) the playtest feedback
on 0.10.5 (Iterations 08-12); 3) the juice, still pending from Phase 11.

### Session 17 (cont.) — approved, and the audio map checked
**User:** drove it at night with traffic — works. Confirmed the fix from the inside ("en tus
primeras pruebas se sentía demasiado ruido de motores"), and asked whether police, enemies and
civilians are all positional so the mix cannot deafen. **Checked: they are** — police are
`EnemyCar` with `police_cruiser.tres` (80 m / -14 dB), civilians 55 m / -21 dB, only the player's
own car is non-positional, which is correct. Table in the Iteration 13 note. **Nothing changed.**
**Found while checking:** `enemy_gunner.gd` has 3 `CombatFx` calls and zero `Audio` — enemy
gunfire is completely silent. Reported, not fixed.
**Iteration 13 closed.**

### Session 17 (cont. 2) — enemy gunfire (D-080)
User: "Dale". `enemy_gunner.gd` now plays one positional shot per bullet from the muzzle at -4 dB,
under the player's own. The gun is derived from `car.data.fire_rate` rather than a new field, so
DLain47's `EnemyCarData` is untouched and a new enemy sorts itself: police (5/s) get
`shot_revolver`, hitmen (6/s) and gang coupes (8/s) get `shot_smg`, pitched a little snappier as
the cadence rises. A pistol now means police and an SMG means gangs.
**Tested:** import clean, all 16 autotests PASS; the hitman's shot observed at runtime
(`shot_smg`, pitch 1.04). The police and gang rows are arithmetic from the same code, not observed
— neither fires in any current test. Not heard by a human.


## 2026-11-16 — Session 18 — Iteration 14: juice
**Iteration:** [[Iteration 14 - Juice]] (new) · **Phases touched:** 11
**Goal:** user: "ahora si podemos seguir con el juice. Lo planifiquemos primero antes de
implementar" → plan presented → "Core + near miss".
**Planning found the plan was wrong:** camera shake (with trauma), speed FOV kick, muzzle flash,
tracers, impacts, explosions, damage smoke — and a **complete drift-chain system** with multiplier,
speed reward, cash payout and HUD bar — all already existed. Rebuilding "style points" from scratch
would have duplicated `drift_chain.gd`.
**Done (D-081):** `EventBus.style_earned` + a bigger HUD popup; `RideManager` pays style exactly
like a drift chain (one currency); `StyleMeter` (air time + near miss) and `SkidMarks` as children
of `taxi.tscn` — **never on `Taxi` itself**, because `TrafficCar extends Taxi` and thirteen
civilians would score; hit-stop of 70 real ms at `time_scale` 0.15 plus camera trauma, off in
headless; 480-slot MultiMesh ring buffer for the rubber, lifted 3.5 cm over the asphalt.
**New test:** `tests/style_autotest` (17th). The near-miss rule could not be covered otherwise —
the closest another car gets to the player in any existing test is **58 m**. Three cases: fast and
close (exactly one popup), slow and close (none), fast and wide (none). The slow case first passed
for the wrong reason, which the logged closest distance exposed.
**Bug only the real game could show:** `SkidMarks` added its MultiMesh while the world scene was
still setting up its children, which Godot refuses. Every test builds its world by hand, so none
hit it. Fixed with `call_deferred`.
**Tested:** import clean; 17 autotests PASS; air time observed at 1.38-1.97 s; 556 skid stamps on a
drift run against 142 driving normally. `hostiles` failed once (its known KI-032 rate) and
`weapon_autotest` ~1 in 5 — root cause found (unseeded pellet spread), logged as **KI-036**, not
fixed because it is not this iteration's code.
**Next session should:** the user drives it; near-miss frequency is the first number to move.

### Session 18 (cont.) — the Changelog (D-082)
User asked for a changelog to share with DLain47, so his Claude session can see what changed here.
Created [[Changelog]], back-filled with every push on this branch from **both** lines of work
(mine `5789037`, `a2c6309`, `24cd7b0`, `8364a41`; his `ac1b810`, `8e36cf3..addcaac`), each entry
flagging what touches the other person's code. Added the rule to [[CLAUDE]] §6 and made reading it
step 2 of the session protocol in §2.
**Found while back-filling:** `dbbd221` — the commit that closed Iteration 11V after the audio was
approved — is on `feat/visuals-and-audio` only; the playtest merge was taken at `5789037`, one
commit earlier, so this branch still had the note as "awaiting playtest". Re-applied by hand and
recorded under "Known gaps between the branches".


## 2026-11-16 — Session 19 — Iteration 15: minimap
**Iteration:** [[Iteration 15 - Minimap]] (new, planned first at the user's request)
**Goal:** a GTA-style minimap that **adapts to any map**, marking enemies, police, fares, the
repair shop and the gun shop. User's calls: rotates with the car, square, radius only, flat.
**The design decision (D-083):** no second camera. It would render the city again every frame and
still not distinguish a repair shop from a gun shop at 150 px — markers are needed over it either
way, at which point the 3D pass only supplies a background. **And that background is already
data**: `MapData.flags()` is one byte per cell (`F_SOLID` / `F_COVERED`), baked once per map load
into a one-pixel-per-cell `ImageTexture` and drawn rotated. One cell is 8 m, so it is blocky, which
suits the PS1 look and keeps the bake at 2.5k-25.6k pixels.
**Done:** `src/ui/hud/minimap.gd` (bake, rotated draw, blips, clamped destination, centre arrow);
the HUD builds it bottom-right above the speed — the only free corner.
**Tested:** import clean, **all 18 autotests PASS**, screenshot taken in the running game (city
grid, fares, gun shop and the arrow all read). New `tests/minimap_autotest` checks the bake against
the flags on a **non-square 40×24** map so a swapped width/depth cannot pass, and the world→minimap
mapping at **three yaws** — the rotation is the part that would be silently wrong.
**Notes:** the rotation needed no correction factor (the taxi's forward is -Z, already "up" on the
texture). The test's first run failed on its own colour comparison: `Color.is_equal_approx` cannot
survive an RGBA8 round trip, so it compares with a 0.01 tolerance now.
**Next session should:** the user drives it; whether the rotating blocks read or shimmer is the
open question.

## 2026-11-16 — Session 20 (DLain47) — Pull Nico's work, minimap markers, shops, weapon upgrades
**Iteration:** [[Iteration 15 - Minimap]] (closed), [[Iteration 16 - Weapon Upgrades & Unlocks]] (new) · **Phases touched:** 05, 11
**Goal:** pull Nico's pushes and report what changed; minimap markers; shop rings / beams / E; weapon upgrades and slower unlocks.
**Done:**
- Pulled `temp/playtest-merge` up to `a749f5d` (Nico's Iterations 13, 14, 15, D-078…D-083, [[Changelog]]). His changelog entry for the minimap names `1b38641`; the pushed commit is `a749f5d`.
- Minimap: shop blips used `global_position`, which is (0, 0, 0) for every shop → now `pad_position`. Destination was a small yellow dot like the player arrow → pulsing green diamond. Shops drawn as outlined squares.
- Shops (D-084): ring + beam on every shop pad in the minimap colours; repair / gun shop used with E (prompt on the HUD) instead of waiting on the pad.
**Files changed:** `src/ui/hud/{minimap,hud}.gd`, `src/world/{shop_marker (new),repair_shop,gun_shop}.gd`, `src/autoload/event_bus.gd`, `src/editor/map_editor.gd` (tooltips), tests `minimap`, `shop`, `ride`.
**Tested:** import clean; `minimap_autotest` PASS (new part 3: the shop blip lands on its piece); windowed probe on `TEST1` with a forced ride: repair, gun shop and destination all visible. After D-084: shop, ride, minimap, map, tutorial, heat_passengers, style, events PASS; screenshots of the rings, beams and prompts. Not re-run: vehicle, enemy, enemy_city, hostiles, weapon, dossier, pickup, jump, curb, streetlife (untouched systems).
- Minimap markers made big (lettered shop squares, 22 px destination). **User approved the minimap work → [[Iteration 15 - Minimap]] closed.**
- New [[Iteration 16 - Weapon Upgrades & Unlocks]] (D-085): guns unlock by fares delivered and cost ~2x; Mk I-IV upgrades at the gun shop, Mk IV = a special per gun (deadeye, drum, dragon's breath, AP rounds). New `WeaponUpgrades`, `Burning`, `tests/upgrades_autotest`.
**Files changed (Iteration 16):** `src/core/resources/weapon_data.gd`, `src/autoload/game_state.gd`, `src/combat/{weapon_controller,weapon_upgrades (new),burning (new)}.gd`, `src/ui/shop/gun_shop_ui.gd`, `src/ui/hud/weapon_bar.gd`, `data/weapons/*.tres`, tests `upgrades` (new), `shop`.
**Tested (Iteration 16):** import clean; upgrades 16/16, shop, weapon, ride, tutorial, heat_passengers, enemy, enemy_city, hostiles, streetlife, pickup, dossier PASS; events failed once (KI-031) then 3/3. Gun shop + hotbar screenshots checked.
- Heavy weapons (D-086): mines, minigun, rocket launcher, laser — $1800-5000, unlocked at 15-35 fares, each with a Mk IV special. New `Blast`, `Rocket`, `Mine`; laser beam, minigun spin-up; keys 5-8. Gun shop rebuilt as list + detail; hotbar in rows of four.
**Files changed (heavy weapons):** `src/core/resources/weapon_data.gd`, `src/combat/{weapon_controller,weapon_upgrades,blast (new),rocket (new),mine (new)}.gd`, `src/ui/shop/gun_shop_ui.gd` (rewritten), `src/ui/hud/weapon_bar.gd`, `src/autoload/audio.gd` (sound mapping — Nico's file), `tools/setup_project.gd` (keys 5-8), `data/weapons/{mines,minigun,rocket,laser}.tres` (new), tests `arsenal` (new), `shop`.
**Tested (heavy weapons):** arsenal 18/18, upgrades, shop, weapon, ride, events, tutorial, heat_passengers, enemy, hostiles, streetlife, pickup, dossier, minimap, map, style, jump, curb, vehicle PASS; enemy_city failed once (KI-029) then 3/3. Screenshots: laser beam, rocket in flight, the new shop, an 8-gun hotbar.
- Loadout of four (D-087): own any number of guns, carry four on keys 1-4; swap at the gun shop (EQUIP / UNEQUIP). Keys 5-8 removed again.
**Tested (loadout):** upgrades (new part G), arsenal, shop, weapon, ride, events, tutorial, heat_passengers, enemy, enemy_city, hostiles, pickup, dossier, streetlife PASS.
- Pulled Nico's branch rule (`023c105`, [[CLAUDE]] §6). Asked which branch: the user chose `temp/playtest-merge` for everything, Iteration 16 included. Changelog entry written, committed and pushed.
**Next session should:** playtest Iteration 16 (unlock pace, prices, specials, the heavy weapons) (`audio.gd` and the shop rewrite flagged for Nico in the Changelog).
