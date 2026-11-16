---
tags: [progress, status]
updated: 2026-11-15
---
# Status

> **Read this first every session.** Claude updates it at the end of every session.

## Where we left off (2026-11-16, session 17)
- **[[Iteration 13 - Merge Integration]] is CLOSED** — driven at night with traffic and approved
  ("funciona, perfecto"). The user's own report confirms the diagnosis from the inside: what felt
  like "too much engine noise" was the 52 non-positional loops.
  Closes the seams the merge left: civilian cars no longer inherit the player's non-positional
  engine rig (52 flat audio loops became 4 + one positional layer each at -21 dB), every car that
  extends `Taxi` now has tail lamps that light at dusk and flare under braking (D-078), and the
  iteration numbering is unambiguous again (D-079: `09V` / `10V` / `11V`, shared from 13 on).
- **The merge itself was reviewed and is healthy:** 16/16 autotests, visuals intact, and the
  `Audio` autoload was extended rather than forked.
- **The music track is on hold by the user's instruction** (KI-034) — the repo is public and the
  file is in it; to be dealt with later, deliberately not now.
- **Vehicle audio is positional everywhere it should be** (table in the Iteration 13 note): police
  and enemies 80 m / -14 dB, civilians 55 m / -21 dB, the player's own car non-positional because
  he sits in it. Asked and verified, not changed.
- **Open hole:** `enemy_gunner.gd` fires with tracers and muzzle flash and **no sound**. Being shot
  at is silent.
- **No iteration is active.** The 0.10.5 playtest feedback (Iterations 08-12) is the bigger open
  item; the juice (Phase 11) is still pending.

### Previous: 2026-11-15, session 16
- **Branch:** `temp/playtest-merge` = `feature/iterations-09-10` (yours) + Nico's `feat/visuals-and-audio` (textures, lights, audio) + Iteration 12 (commit `8e36cf3`). **Pushed 2026-11-16** to `origin/temp/playtest-merge` (DLain47 is now a collaborator); `feature/iterations-09-10` is still local only. `main` still has only the initial commit.
- **Active:** [[Iteration 12 - Heat, Fares & Game Over]] — built & auto-verified: heat from 2★ + gang bounty from 4★ (D-070), music + OPTIONS menu (D-071), smaller ammo reserves (D-072), procedural passengers (D-073), curbside drop-offs (D-074), destructible traffic + civilian crimes = heat (D-075), red marker over hostiles (D-076), death = explosion + GAME OVER (D-077). Difficulty re-tuned "in between".
- **Build 0.10.5** (`build/windows/TaxiDriver.exe`, `build/TaxiDriver-0.10.5-windows.7z`) sent to the user for a friend. The user played 0.10.4 once (wreck bug → fixed in 0.10.5).
- **Docs:** Nico's decisions are DV-061…DV-068 in [[Decisions Log]]; his sessions are in [[Session Log]]; his iteration notes are **09V / 10V / 11V** — the `V` suffix (matching the `DV-` decisions) marks the parallel visual/audio line and resolves the two 09s and two 10s the merge created (D-079).
- **Flaky tests:** `hostiles` ~1/5 (KI-032), `enemy_city` ~1/4 (KI-029) — both pre-existing.
- **First thing next session:** playtest feedback on 0.10.5 (Iteration 12 checklist, also covers 08-11); decide the fate of `temp/playtest-merge`.

### Previous: 2026-11-15, session 14
- **Active:** [[Iteration 10 - Street Life, Gun Shop & Weapon Bar]] — built & auto-verified, build **0.10.0** at `build/windows/TaxiDriver.exe`. Gun shops + Rifle, run starts with the revolver (D-064); pedestrians + traffic (D-065); 4 new passengers (D-066); weapon hotbar (D-067). 7-point checklist in the note.
- **The user's `TEST1` map has no gun shop** — they need to place one in the editor to buy guns there.
- **Three iterations await the user:** 08 (re-test), 09 (menu / tutorial / build), 10 (this). One playtest of the 0.10.0 build covers all three.
- **Flaky tests:** `enemy_city_autotest` ~1 in 4 (pre-existing, KI-029); windowed `editor_switch_autotest` 2 / 5 this session (real mouse suspected).
- **First thing next session:** collect the playtest of the build (Iterations 08-10), fix, close them; then the neighbourhoods scope, or more shops (body parts / dashboard / perks).

### Previous: 2026-11-15, session 13
- **Active:** [[Iteration 09 - Menu, Tutorial & Build]] — built & auto-verified, **a Windows build is at `build/windows/TaxiDriver.exe`** for the user to playtest (7 points in the iteration note). Main menu (D-061), six-step tutorial (D-062), pause menu with run stats, F11 fullscreen, editor "Main menu" button, export preset + maps in `user://maps/` for builds (D-063).
- **Docs now match the git repo** (`taxi-driver-game/`, project at the root, vault in `docs/`, git rules in [[CLAUDE]] §6). Nothing has been committed this session — the user commits.
- **Iteration 08 is still open:** its 7-point re-test was not done this session; the build is a good way to do both.
- **First thing next session:** collect the build playtest (Iteration 09) + the Iteration 08 re-test; fix; close both; then ask the scope of the neighbourhoods iteration.

### Previous: 2026-11-13, session 12
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
| 01 Taxi Driving & Cab Camera | ✅ | arcade raycast taxi; wreck = death + game over (D-077, replaces limp mode D-056) |
| 02 City Graybox & Navigation | ✅ → rebuilt | the city is now built from a `MapData` (D-055); cell road graph; starter city generated from pieces |
| 03 Core Ride Loop | ✅ | rides, drift chain; shift clock removed (D-051) |
| 04 Dossier & Decisions | ✅ | passenger file; examine costs ride time (D-051) |
| 05 Shooting From the Cab | ✅ | revolver / SMG / sawed-off, shooting range (F3) |
| 06 Damage & Enemy Pursuers | ✅ | hitmen / police AI; relentless pursuit (D-053); they leave a wreck (D-056) |
| 07 Passenger Archetypes & Ride Events | ✅ closed 2026-11-12 | 8 archetypes, strategic spawns; deferred: screen effects, courier, item drops |
| 08 Items & Inventory | 🟨 started early | Monstrous Energy heal pickup (D-042) |
| Open world: map editor | 🟨 built, awaiting playtest | Iteration 08: editor, piece kit, zones, repair shops |
| Menu / tutorial / build | 🟨 built, awaiting playtest | Iteration 09: title screen, tutorial, pause menu, Windows export |
| Street life / gun shop / hotbar | 🟨 built, awaiting playtest | Iteration 10: pedestrians, traffic, 4 passengers, gun shops + rifle, weapon hotbar |
| Textures / lights / audio (Nico) | ✅ on his branch, merged for playtest | Nico's Iterations 09-11 (DV-061…DV-068) |
| Heat, fares, game over | 🟨 built, awaiting playtest | Iteration 12: bounty, music + options, procedural fares, curbside stops, civilian crimes, hostile marker, death |
| 09–12 | ⬜ | to be re-planned around the open world (neighbourhoods, shops in the world, save) |

## ✅ Done (built, tested, approved)
Iterations 01–05 — closed 2026-11-11. Iterations 06 and 07 — closed 2026-11-12 (07: archetypes confirmed working by the user; its fixes D-051…D-054 closed without a user re-test).

## 🟨 Built, not yet tested by the user
- **Iteration 08:** map editor (M in the game, P back), all map pieces in the game (building shapes, plazas, low stairs, ramps, containers, repair shops), driving on a user-made map, AI routing around user buildings, wreck → limp → repair shop.
- **Iteration 07 fixes (iteration closed, never seen by the user):** no shift clock (D-051), kick only when an event allows it (D-052), relentless pursuers (D-053), red countdown under the arrow + bold subtitles (D-054). Expectant mother.
- Still unconfirmed from before: file gamepad focus (D-046), asphalt z-fighting (KI-017), enemy balance (KI-015), ride / money balance (KI-007), gamepad (KI-002).

## ❌ Missing
- Neighbourhood content + storylines, shops / upgrades (next iterations). Map streaming for huge maps (KI-023), decoration props, traffic, a home for the run summary (KI-025). Phase 07 leftovers: screen effects, mystery courier, real item drops. Smaller: GPS line, projectile weapons, windshield holes, multi-page files, aim assist, `VehicleStats` (KI-006).

## 🧪 Automated checks — 2026-11-15 (session 16)
All 16 PASS on the final code: **heat_passengers** (new, A-H), ride (now repair → destroyed = game over), weapon / shop (new ammo), map (ignores curbside stops), hostiles, enemy, enemy-city, events, dossier, pickup, jump, curb, vehicle, streetlife, tutorial; profiles OK; import clean; build 0.10.5 smoke-tested on `TEST1`. Flaky: hostiles (KI-032), enemy-city (KI-029). Screenshots: hostile marker, game over.

### Session 14
**shop** (new), **streetlife** (new), weapon, tutorial, ride, dossier, events, map, hostiles, enemy, pickup, jump, curb, vehicle PASS; profile check OK (15 files); import clean; build 0.10.0 smoke-tested. **enemy-city flaky** (KI-029, also before this iteration); **editor switch** (windowed) 2 / 5 passes — inconclusive (real mouse).

### Session 13
**tutorial** (new), ride, dossier, events, map, hostiles, enemy, enemy-city, pickup, weapon, jump, curb, vehicle (default scenario), editor switch (windowed), profile check; import clean; `tests/ui_shots` screenshots checked; exported exe smoke-tested (headless: menu, `TEST1`, built-in city; windowed: renders on D3D12). The 8 extra vehicle scenarios were not re-run (vehicle code untouched).

### 2026-11-13
**hostiles** (new), **jump** (new), editor switch (windowed), map, 9 vehicle scenarios, ride (now incl. wreck → limp → repair), dossier, events, weapon, enemy, enemy-city, pickup tests, profile data check; import clean. Session 12, after D-060: **curb** (new), 9 vehicle scenarios, jump, map, ride, enemy, enemy-city, hostiles, events PASS (the rest not re-run). Commands in [[CLAUDE]] §5.

## 📌 Decisions in force
TaxiDriver · git repo (since 2026-11-15) · controller supported · open world, no shift clock (D-051) · **maps are data made in the in-game editor (D-055)** · **wreck = death + game over (D-077; D-056 superseded)** · blockout + PS1 look · Claude decides tech choices (D-011). **enemies spawn only where they can drive out (D-057)** · **3 m kickers clear one level of containers (D-058)** · **street encounters (D-059)** · **chassis clears curbs (D-060)** · **title screen is the main scene (D-061)** · **tutorial inside the real game (D-062)** · **Windows build in `build/`, builds save maps to `user://maps/` (D-063)** · git repo, user commits · **gun shops in the world, start with the revolver (D-064)** · **street life (D-065)** · **weapon hotbar (D-067)** · **heat + bounty (D-070)** · **procedural fares (D-073)** · **curbside stops (D-074)** · **civilian crimes = heat (D-075)** · See [[Decisions Log]] D-001…D-077 + DV-061…DV-068 (Nico).

## 🚧 Waiting on user
- Playtest of build 0.10.5 (Iteration 12 note, 8 points) — it also contains everything from 08-11.
- Playtest of build 0.10.0 (Iteration 10 note, 7 points) — add a gun shop to `TEST1` first.
- Playtest of the build `build/windows/TaxiDriver.exe` (Iteration 09 note, 7 points).
- Re-test of the 2026-11-13 changes (7 points in the Iteration 08 note); wreck / repair feel and stairs / plazas were not mentioned in the playtest.
