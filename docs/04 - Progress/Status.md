---
tags: [progress, status]
updated: 2026-11-14
---
# Status

> **Read this first every session.** Claude updates it at the end of every session.

## Where we left off (2026-11-15, session 15)
- **Iteration 11 (audio) is CLOSED**, accepted on the third listen: "por ahora está bien", with the
  bank expected to be revisited later (`tools/gen_sfx.py`).
- **Everything is committed and pushed**: branch `feat/visuals-and-audio`, commit `5789037`,
  270 files, covering iterations 09, 10 and 11. `main` is still at the initial commit and **no pull
  request has been opened**.
- **No iteration is active.** Iteration 08 is still out with the user's friend.
- **What is left of [[Phase 11 - Audio, VFX & Juice]] is the juice**: skid marks, speed lines /
  FOV kick on boost, hit-stop on kills, style-point popups, glass shatter, and music / radio.
  Camera shake, muzzle flash, tracers, impacts, explosions and damage smoke already exist.

## Previously (2026-11-14, session 15)
- **Active iteration:** [[Iteration 11 - Audio]] — built, **nobody has heard it**. The game had no
  sound at all; it now has 21 generated sounds (D-066), an `Audio` autoload owning six buses and
  pooled players, a three-layer engine pitched by revs, tyre screech, per-weapon gunfire with
  reload and dry click, impacts, explosions, cash, pickups and dossier paper.
- **The sounds are generated, not downloaded** (`tools/gen_sfx.py`): there is no clean CC0 car
  engine loop in existence, and generating makes the loops seamless, the licence a non-question and
  the whole bank reproducible. Regenerate with `python -I tools/gen_sfx.py`, then re-import and
  check the four loop flags survived.
- **First listen (user, 2026-11-14): everything worked except the car itself** — no engine, no tyre
  screech, and no engine on the NPC cars. **D-067** fixed both: the loops were playing once and
  stopping (Godot's importer loop flag never reached the resource, because the bank was imported
  before the flag was written), so looping is now forced in code; and enemy cars got a positional
  engine pitched by speed.
- **Second listen: too shrill, no gear changes, and the tyres did not sound like rubber.** **D-068**
  gave the engine a five-speed gearbox (18 / 37 / 58 / 84 / 119 km/h) with a throttle-cut dip on
  each shift, narrowed the pitch range and regenerated the samples lower, rebuilt the screech from
  four rubber resonances, and made braking screech at all (it only ever reacted to sideways slip).
  **Awaiting a third listen.**
- **What Claude cannot check: how it sounds.** Everything objective is green.

## Previously (2026-11-14, session 14)
- **Iterations 09 (textures) and 10 (lights & night) are CLOSED** — both approved in play by the
  user on 2026-11-14.
- **Iteration 08 is being playtested by a friend of the user** (its 7 open points). While that is
  out there, work should stay away from what they are testing: the map editor, the piece kit, map
  data, and the wreck → limp → repair loop — changing those under a tester invalidates the feedback.

- **Active iteration:** [[Iteration 10 - Lights & Night]] — built, **nobody has played it**. D-064:
  three time-of-day moods (day / dusk / night) in `src/world/lighting.gd` with **dusk as the
  default**, **F6** to cycle them in play, 311 shadowless street lamps along the kerbs (visual only,
  no collision), taxi headlights, and the PS1 shader moved to per-pixel lighting so lamp pools are
  not faceted. The lit windows from D-061 finally mean something.
- **Played and approved the same day: all three moods stay** ("se ven y sienten bien"), so the game
  keeps the variety rather than picking one. **D-065** fixed what the playtest caught: in daylight
  the lamp glass, the lit windows and the headlights all kept burning. Everything that emits light
  now follows `EventBus.mood_changed`.
- **Deferred to [[Phase 10 - Game Flow, UI & Save]]:** choosing the time of day when starting a
  game, from the main menu. F6 stays as the development key.
- [[Iteration 09 - Texture Pass]] is **ready to close** (approved in play).

## Previously (2026-11-14, session 13)
- **Active iteration:** [[Iteration 09 - Texture Pass]] — the visual pass started. **D-061**: the PS1
  shader now has world-space UVs (a tiling texture keeps its real-world size on generated boxes of
  any dimension) and **procedural facade windows** with randomly lit ones. The city reads as a city
  in the view-shot screenshots; **nobody has seen it in play yet**.
- **The texture pack is in and wired (D-062).** The user dropped **A_classic** (90 textures) into
  `assets/textures/A_classic/`. 10 materials are textured — brick, plaster and concrete facades,
  asphalt road, concrete sidewalks, metal containers — with each material's flat colour rebalanced
  against its texture's mean so the palette survives, and all 90 `.import` files forced to
  lossless / no mipmaps / no 3D auto-compression (that last one would have destroyed the dither).
  `prop`, `ramp` and `lane_marking` stay flat on purpose.
- **First playtest of the textures (user, 2026-11-14): "efecto psicodélico", the road textures
  stretch and swim in motion.** That was affine mapping becoming visible for the first time (flat
  colours had nothing to warp). **D-063**: road tessellated to 6 m quads, ground strips subdivided
  at 12 m (they were single huge quads), `affine_multiplier` 0.25 on road / ground and 0.5 on
  sidewalk, and the road texture swapped to isotropic gravel at 3 m so there are no directional
  streaks to smear. **Re-tested by the user the same day: approved ("me gusta").** The dials are
  written up in [[Art Direction]] > "Tuning the PS1 look" so this balance can be moved again later.
- **Iteration 09 is ready to close** — its acceptance list is ticked. What is left in it was
  deferred on purpose: lighting / night palette, and the 80 unused textures.
- **Claude tooling (session 13):** no Godot MCP installed on purpose (none is official, the popular
  one is 7 months stale, and all of them need a third-party addon inside `res://`). Installed the
  knowledge-only skills plugin `godot@awesome-gamedev-agent-skills`. The root `CLAUDE.md` was
  missing and now exists; the old absolute paths from the previous machine and the `Crazytaxi/`
  vault name are fixed; there is no `_console.exe` build and none is needed.
- **Iteration 08 is still open** and still waiting on the same re-test (7 points in its note).

## Previously (2026-11-13, session 12)
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
| Audio | ✅ closed 2026-11-15 | Iteration 11: D-066 generated bank, Audio autoload, engine by revs |
| Art: lights & night | ✅ closed 2026-11-14 | Iteration 10: D-064 moods, lamps, headlights, per-pixel lighting; D-065 day switches them off |
| Art: texture pass | ✅ closed 2026-11-14 | Iteration 09: D-061 world UVs + windows, D-062 pack wired, D-063 affine tuned |
| 09–12 | ⬜ | to be re-planned around the open world (neighbourhoods, shops in the world, save) |

## ✅ Done (built, tested, approved)
Iterations 01–05 — closed 2026-11-11. Iterations 06 and 07 — closed 2026-11-12 (07: archetypes confirmed working by the user; its fixes D-051…D-054 closed without a user re-test).

## 🟨 Built, not yet tested by the user
- **Iteration 08:** map editor (M in the game, P back), all map pieces in the game (building shapes, plazas, low stairs, ramps, containers, repair shops), driving on a user-made map, AI routing around user buildings, wreck → limp → repair shop.
- **Iteration 07 fixes (iteration closed, never seen by the user):** no shift clock (D-051), kick only when an event allows it (D-052), relentless pursuers (D-053), red countdown under the arrow + bold subtitles (D-054). Expectant mother.
- Still unconfirmed from before: file gamepad focus (D-046), asphalt z-fighting (KI-017), enemy balance (KI-015), ride / money balance (KI-007), gamepad (KI-002).

## ❌ Missing
- Neighbourhood content + storylines, shops / upgrades (next iterations). Map streaming for huge maps (KI-023), decoration props, traffic, a home for the run summary (KI-025). Phase 07 leftovers: screen effects, mystery courier, real item drops. Smaller: GPS line, projectile weapons, windshield holes, multi-page files, aim assist, `VehicleStats` (KI-006).

## 🧪 Automated checks — all PASS on 2026-11-14 (session 14: the 9 vehicle scenarios + 11 tests + profiles, nothing failed)
**hostiles** (new), **jump** (new), editor switch (windowed), map, 9 vehicle scenarios, ride (now incl. wreck → limp → repair), dossier, events, weapon, enemy, enemy-city, pickup tests, profile data check; import clean. Session 12, after D-060: **curb** (new), 9 vehicle scenarios, jump, map, ride, enemy, enemy-city, hostiles, events PASS (the rest not re-run). Session 13, after D-061: map, ride, hostiles, enemy, enemy-city, weapon, dossier, pickup, curb, jump, 9 vehicle scenarios PASS; `check_profiles` OK; import clean, and all of it again after the textures were wired. **`events_autotest` failed twice in ~30 runs — KI-026.** Commands in [[CLAUDE]] §5.

## 📌 Decisions in force
TaxiDriver · no git (backups in `new-game-project/_backup/`) · controller supported · open world, no shift clock (D-051) · **maps are data made in the in-game editor (D-055)** · **wreck = limp until a repair shop (D-056)** · blockout + PS1 look · Claude decides tech choices (D-011). **enemies spawn only where they can drive out (D-057)** · **3 m kickers clear one level of containers (D-058)** · **street encounters (D-059)** · **chassis clears curbs (D-060)** · **world-space UVs + procedural facade windows (D-061)** · **textures: CC0 only, PSX Textures Vol. 1 — A_classic, albedo rebalanced, no mipmaps (D-062)** · See [[Decisions Log]] D-001…D-068.

## 🚧 Waiting on user
- Re-test of the 2026-11-13 changes (7 points in the Iteration 08 note); wreck / repair feel and stairs / plazas were not mentioned in the playtest.
- **The Iteration 08 re-test is with a friend of the user** (7 of its 10 points): editor pieces,
  playing a user map, stairs / plazas / kicker ramps, and the wreck → limp → repair loop including
  whether $60 feels right. Collect their feedback into the Iteration 08 note when it comes.
