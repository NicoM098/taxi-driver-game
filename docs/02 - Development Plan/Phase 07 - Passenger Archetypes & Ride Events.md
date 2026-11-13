---
tags: [plan, phase]
phase: 7
status: playtested-fixes-pending-retest
---
# Phase 07 — Passenger Archetypes & Ride Events

**Goal:** passengers with real backgrounds and consequences, built from reusable ride-event blocks. **Vertical slice milestone (M5).**
**Depends on:** [[Phase 04 - Dossier & Decisions]], [[Phase 06 - Damage & Enemy Pursuers]]
**Design refs:** [[Passengers & Encounters]] §4–5

## Tasks
### Event framework (`src/events/`)
- [x] `RideEvent` base resource: `trigger` (on_start, after_seconds, after_distance, after_progress, on_arrival, on_kicked_out), `chance`, action / flag conditions, `start / tick / on_kick`. *(on_damage / on_examined triggers not needed yet.)*
- [x] `RideContext`: access to ride, taxi, GameState, EnemyDirector, HUD message API.
- [x] `RideEventRunner` in RideManager: evaluates triggers each frame/signal.
- [x] **Strategic spawns** for `SpawnPursuersEvent` (user request 2026-11-11): `EnemyDirector.spawn_on_route(destination, pattern)` using `City.get_route()` — `ambush_ahead` (block an intersection on the route, car parked across the road), `pincer` (ahead + behind), `tail` (current behaviour). Always out of sight. Autotest: hitmen end up between the taxi and the destination.
- [x] Implement blocks: `SpawnPursuersEvent`, `StealCashEvent` (counter-window: kick out within N seconds), `ForceDetourEvent`, `RewardEvent` (= `DropItemEvent` stand-in until Phase 08), `PassengerAttackEvent`, `TimerModifierEvent`, `DialogueEvent`, `HeatChangeEvent`.
- [ ] ➡️ deferred: `ScreenEffectEvent` (no archetype needs it yet).
- [x] Passenger barks (subtitle lines) via `DialogueEvent`.

### Archetypes (data in `data/passengers/`)
- [x] **Old lady** — low/no fare; `DropItemEvent` on arrival; examine: knitting bag.
- [x] **Businessman** — high fare; `SpawnPursuersEvent` after 10–20 s; examine: briefcase/contract → unlock "Kill for bounty".
- [x] **Burglar** — `StealCashEvent` mid-ride; examine: pockets/ID mismatch → unlock "Kick out"/"Shoot".
- [x] **Hijacker** — `ForceDetourEvent` + `PassengerAttackEvent`; examine reveals gun → "Kill on the spot".
- [x] 1–2 more from the list: **expectant mother** done; mystery courier deferred.
- [x] `PassengerSpawner` uses weighted random by district + shift number (`min_shift`).

## Definition of done
- A shift mixes ≥5 archetypes; each archetype's twist works and is readable; outcomes recorded in shift summary.

## User test checklist
- [ ] Is each passenger's twist understandable from the dossier (fair but not obvious)?
- [ ] Which archetype is most/least fun?

## Notes
- 2026-11-12 (Iteration 07): built, see D-047…D-050 and [[Iteration 07 - Archetypes & Ride Events]].
  - `src/events/`: `ride_event.gd` (base), `ride_context.gd`, `ride_event_runner.gd`, blocks `dialogue / spawn_pursuers / steal_cash / force_detour / passenger_attack / timer_modifier / heat_change / reward _event.gd`.
  - New passenger = a `.tres` in `data/passengers/` with `ride_events` sub-resources (see `hijacker.tres` for chaining with flags). Trigger enum ints: 0 start, 1 seconds, 2 distance, 3 progress, 4 arrival, 5 kicked out.
  - Mid-ride kick (`kick_out`), `RideManager.change_destination / fail_ride / pick_destination_in`, `EnemyDirector.spawn_on_route`, AI `AMBUSH` mode.
  - Test: `tests/events_autotest.tscn`; data check: `tools/check_profiles.tscn`; debug: F8 next archetype.
- 2026-11-12 playtest → fixes (D-051…D-054): no shift clock; mid-ride kick only while an event allows it (`RideContext.kick_window / kick_unlocked`, `RideManager.can_kick_mid_ride()`); pursuers keep hunting after the delivery (`EnemyDirector.release_ambushes`, relocation of outrun cars); `RewardEvent` lost its `time` kind.
