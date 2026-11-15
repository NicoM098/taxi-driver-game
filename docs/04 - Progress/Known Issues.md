---
tags: [progress, bugs]
---
# Known Issues

Bugs and tech debt not fixed yet. Remove (or move to "Resolved") when fixed.

| ID | Severity | System | Description | Found | Repro / notes |
|---|---|---|---|---|---|
| KI-001 | ⚪ | camera / physics | Physics interpolation ON vs OFF: user sees no difference yet (2026-11-11). **Keep the F4 toggle** and decide when textures arrive (fine detail makes jitter visible). | 2026-11-10 | F4 in game. |
| KI-002 | 🟡 | input | **Unverified:** gamepad bindings — no controller was connected during automated tests. | 2026-11-10 | Plug in pad: RT/LT, left stick, right stick look, B handbrake, Start pause. Overlay (F2) shows "Input Gamepad". |
| KI-006 | ⚪ | tech-debt | `Taxi` wheel count/mass split assumes all wheels equal; vehicle tunables are `@export`s, not yet a `VehicleStats` resource (needed for upgrades, Phase 09). | 2026-11-10 | — |

| KI-007 | 🟡 | balance | Ride clock uses straight-line distance; real street routes are longer — time limits may be too tight/loose. Drift money ($0.5/pt) vs fares untested by a human. | 2026-11-11 | Tune `expected_speed`, `ride_base_time` (RideManager), `dollars_per_drift_point`. |
| KI-009 | ⚪ | visuals | Passengers board/exit by sliding (tween), no door/walk animation. | 2026-11-11 | Later polish. |

| KI-012 | ⚪ | combat | Viewmodel can clip into the cab when looking hard left/right with the gun up (normal depth test). | 2026-11-11 | Render viewmodel on top if it bothers in playtest. |
| KI-013 | ⚪ | combat | No aim assist on gamepad; simulated (test) key presses must be held 2+ frames to register as just-pressed (test-only quirk). | 2026-11-11 | Decide aim assist after pad playtest. |

| KI-014 | ⚪ | tech-debt | `Taxi` class is used for enemy cars too (`EnemyCar extends Taxi`) — rename to `Vehicle` when convenient. | 2026-11-11 | — |
| KI-015 | 🟡 | balance | Enemy lethality/accuracy, bounty ($40), heat thresholds and police interval untested by a human. | 2026-11-11 | `data/enemies/*.tres`, `EnemyDirector`, `TaxiDamage` exports. |

| KI-017 | 🟡 | visuals | Intermittent asphalt z-fighting — likely fixed by D-043, needs confirmation while driving. | 2026-11-11 | `tests/view_shots.tscn` for stills. |

| KI-018 | 🟡 | balance | Phase 07 numbers (D-050): the user played all archetypes on 2026-11-12 and reported them working, no number complaints except "hitmen are easy to avoid" (answered by D-053). New untested numbers: `pursuit_relocations` 2, `lose_distance` 210 m, `ambush_bypass` 25 m, examine cost on the ride clock (floor 50 %), `rides_per_level` 4. | 2026-11-12 | `EnemyDirector`, `EnemyDriverAI`, `RideManager`, `ShiftManager` exports. |
| KI-021 | ⚪ | tech-debt | Names left over from the timed shifts: `ShiftManager`, `GameState.shift_number` (now a difficulty level), `PassengerProfile.min_shift`, `EventBus.shift_started / shift_ended`. Rename when the open-world run flow is designed. | 2026-11-12 | — |
| KI-023 | 🟡 | performance | Maps are built whole at load (no streaming / chunking). Untested on a real GPU with a full 160 x 160 map. | 2026-11-12 | `City._ready`; add chunked building + visibility ranges if it stutters. |
| KI-024 | 🟡 | enemies | The AI road graph treats stairs, ramps and stepped plazas as ordinary (more expensive) ground: enemy cars may drive off ramps or struggle on tall stairs. Sheer platforms over 0.45 m are solid for the graph. | 2026-11-12 | `MapData.is_solid`, `City._build_road_graph`. |
| KI-026 | 🟡 | balance | Untested numbers: limp mode (30 km/h, misfire, steering wander), repair prices ($60 wreck, $0.8 / HP). | 2026-11-12 | `Taxi` "Limp mode" exports, `RepairShop` exports. |
| KI-027 | 🟡 | balance | Encounter frequency, the Bruiser / Street Gang cars and the three hostile passengers are untuned first guesses (D-059). Bruisers weigh 1.5 x the taxi: check they do not pin it against walls. | 2026-11-13 | `StreetEncounters` exports, `data/events/`, `data/enemies/`. |
| KI-028 | ⚪ | editor | No warning about walled-in areas: taxi stops placed inside one still get passengers and destinations nobody can reach (enemies no longer spawn there, D-057). | 2026-11-13 | `City.count_cut_off_cells()` exists for it. |
| KI-020 | ⚪ | enemies | An ambusher blocks only part of a 16 m wide intersection and is shown by the threat markers while out of view. | 2026-11-12 | Consider two cars nose to nose / hiding markers for AMBUSH mode. |
| KI-029 | 🟡 | tests | `enemy_city_autotest` fails ~1 run in 4 ("not all hitmen reached the taxi"): one hitman piles up unstuck recoveries and is destroyed before arriving. Also on the code before Iteration 10 (clean worktree of the last commit: 2 of 8 failed). | 2026-11-15 | Random spawn spots; re-run, or seed the spawns. |
| KI-030 | ⚪ | street life | No consequences for running pedestrians over (only a stat); traffic cars cannot be destroyed (bullets shove them); pedestrians cannot be shot; no traffic rules at intersections. | 2026-11-15 | D-065; decide with the user. |

Severity: 🔴 blocker · 🟠 major · 🟡 minor · ⚪ cosmetic/tech-debt

## Resolved
- KI-025 (2026-11-15) — the run stats are shown in the new pause menu (D-061).
- KI-022 (2026-11-12) — a wreck now costs: limp mode until a repair shop, $60 (D-056).
- KI-019 (2026-11-12) — accidental mid-ride kick: a normal fare can no longer be ended by the driver; Q only works while a ride event allows it (D-052).
- KI-016 (2026-11-11) — instant 180° turn when throttling out of a reverse → D-041.
- KI-005 (2026-11-11) — rear-view mirror now renders (D-040).
- KI-011 (2026-11-11) — car undriveable with drift-chain assists/kicks → reverted assist, handbrake-initiated chain, smooth reward (D-030).
- KI-008 (2026-11-11) — guide arrow small/flat/mispositioned → top-centre compass arrow (D-028).
- KI-010 (2026-11-11) — handbrake + steer at speed spun the car 180° (regression from D-025) → drift angle limiter (D-027).
- KI-003 (2026-11-11) — handbrake too aggressive at low speed → effect now speed-scaled (D-019). 35 km/h handbrake turn: 178° spin → 98° controlled turn.
- KI-004 (2026-11-11) — steering wheel direction confirmed correct by user.

## KI-026 — `events_autotest` fails intermittently (2026-11-14)
**Two failures in ~30 runs during session 13** (~7 %), both inside a batch that ran the whole
suite; never reproduced when run on its own (18 consecutive passes across two attempts, including
2 forced immediately after a re-import to test whether a cold first run was to blame — it is not). The only changes in that session were a shader and material edit, which cannot affect
headless gameplay logic, so this is almost certainly pre-existing and random (archetype rolls /
timing). Not reproduced, so not diagnosed. If it shows up again, capture the full output — the test
prints every step and `_finish()` prints one `FAIL: <error>` line per failed check, so redirect
stdout to a file when running the suite (`> out.txt 2>&1`) instead of grepping only for PASS/FAIL.
Suspected cause: something time- or order-dependent in the ride/archetype sequence rather than the
random rolls, since `--fixed-fps 60` should otherwise make the run deterministic.
