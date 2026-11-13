---
tags: [progress, status]
updated: 2026-11-13
---
# Status

> **Read this first every session.** Claude updates it at the end of every session.

## Where we left off (2026-11-13, session 12)
- **Active iteration:** [[Iteration 08 - Open-World Base & Map Editor]] — **playtested 2026-11-13: the editor and the user's own map work.** Three requests from that playtest are built & auto-verified, not yet re-tested: enemies never spawn walled in (D-057), kicker ramps jump one level of containers (D-058), more hostile situations (D-059: street encounters, Bruiser + Street Gang cars, Bank Robber / Key Witness / Gang Courier). **Session 12:** "the sidewalks are damaging the car" → the chassis box hit curbs when the suspension was compressed; fixed (D-060), auto-verified, not re-tested.
- **Iteration 07 closed by the user (2026-11-12).** Its playtest fixes (D-051…D-054) were never re-tested separately — auto-verified only; they are in play during the Iteration 08 playtest.
- **Direction (user, 2026-11-12):** open world, no shift clock → map editor (done, this iteration) → neighbourhoods with storylines and people → shops (armory, body parts, dashboard items, perks). Roadmap in [[Development Plan]] ("Direction change").
- **First thing next session:** get the re-test (7 points in the Iteration 08 note), tune encounter frequency / new enemies, close 08; then ask the scope of the neighbourhoods iteration.

- **Playtest started (2026-11-12):** F9 / F5 crashed (`set_input_as_handled` on null) and left the editor frozen → fixed, covered by `tests/editor_switch_autotest`; user retried: still frozen, no error → cause was the key itself: **F9 = "suspend" in Godot's embedded game view**. Editor key is now **M**, play is **P**; waiting for the retry.

## Open questions for the user
1. Confirm three calls Claude made: looking closer at the file costs the passenger's ride time (D-051); Q still throws out the burglar / hijacker (D-052); when you are wrecked the hitmen leave and the fare bails out (D-056).
2. Is D-059 what you meant by "more hostile situations"? Which pieces are still missing in the editor?
3. Neighbourhoods: which ones first, and what makes each different (people, enemies, rules)?

## Phase progress
| Phase | Status | Notes |
|---|---|---|
| 00 Project Setup | ✅ | settings via `tools/setup_project.gd`; PS1 pipeline |
| 01 Taxi Driving & Cab Camera | ✅ | arcade raycast taxi; **limp mode when wrecked (D-056)** |
| 02 City Graybox & Navigation | ✅ → rebuilt | the city is now built from a `MapData` (D-055); cell road graph; starter city generated from pieces |
| 03 Core Ride Loop | ✅ | rides, drift chain; shift clock removed (D-051) |
| 04 Dossier & Decisions | ✅ | passenger file; examine costs ride time (D-051) |
| 05 Shooting From the Cab | ✅ | revolver / SMG / sawed-off, shooting range (F3) |
| 06 Damage & Enemy Pursuers | ✅ | hitmen / police AI; relentless pursuit (D-053); they leave a wreck (D-056) |
| 07 Passenger Archetypes & Ride Events | ✅ closed 2026-11-12 | 8 archetypes, strategic spawns; deferred: screen effects, courier, item drops |
| 08 Items & Inventory | 🟨 started early | Monstrous Energy heal pickup (D-042) |
| Open world: map editor | 🟨 built, awaiting playtest | Iteration 08: editor, piece kit, zones, repair shops |
| 09–12 | ⬜ | to be re-planned around the open world (neighbourhoods, shops in the world, save) |

## ✅ Done (built, tested, approved)
Iterations 01–05 — closed 2026-11-11. Iterations 06 and 07 — closed 2026-11-12 (07: archetypes confirmed working by the user; its fixes D-051…D-054 closed without a user re-test).

## 🟨 Built, not yet tested by the user
- **Iteration 08:** map editor (M in the game, P back), all map pieces in the game (building shapes, plazas, low stairs, ramps, containers, repair shops), driving on a user-made map, AI routing around user buildings, wreck → limp → repair shop.
- **Iteration 07 fixes (iteration closed, never seen by the user):** no shift clock (D-051), kick only when an event allows it (D-052), relentless pursuers (D-053), red countdown under the arrow + bold subtitles (D-054). Expectant mother.
- Still unconfirmed from before: file gamepad focus (D-046), asphalt z-fighting (KI-017), enemy balance (KI-015), ride / money balance (KI-007), gamepad (KI-002).

## ❌ Missing
- Neighbourhood content + storylines, shops / upgrades (next iterations). Map streaming for huge maps (KI-023), decoration props, traffic, a home for the run summary (KI-025). Phase 07 leftovers: screen effects, mystery courier, real item drops. Smaller: GPS line, projectile weapons, windshield holes, multi-page files, aim assist, `VehicleStats` (KI-006).

## 🧪 Automated checks — all PASS on 2026-11-13
**hostiles** (new), **jump** (new), editor switch (windowed), map, 9 vehicle scenarios, ride (now incl. wreck → limp → repair), dossier, events, weapon, enemy, enemy-city, pickup tests, profile data check; import clean. Session 12, after D-060: **curb** (new), 9 vehicle scenarios, jump, map, ride, enemy, enemy-city, hostiles, events PASS (the rest not re-run). Commands in [[CLAUDE]] §5.

## 📌 Decisions in force
TaxiDriver · no git (backups in `new-game-project/_backup/`) · controller supported · open world, no shift clock (D-051) · **maps are data made in the in-game editor (D-055)** · **wreck = limp until a repair shop (D-056)** · blockout + PS1 look · Claude decides tech choices (D-011). **enemies spawn only where they can drive out (D-057)** · **3 m kickers clear one level of containers (D-058)** · **street encounters (D-059)** · **chassis clears curbs (D-060)** · See [[Decisions Log]] D-001…D-060.

## 🚧 Waiting on user
- Re-test of the 2026-11-13 changes (7 points in the Iteration 08 note); wreck / repair feel and stairs / plazas were not mentioned in the playtest.
