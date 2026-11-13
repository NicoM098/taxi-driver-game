---
tags: [plan, phase]
phase: 4
status: done
---
# Phase 04 — Dossier & Decisions

**Goal:** the Papers, Please layer — when a passenger enters, their file opens; the player reads it, examines details, and chooses an action (drive / kick out / examine / kill / special).
**Depends on:** [[Phase 03 - Core Ride Loop]]
**Design refs:** [[Passengers & Encounters]] §1–3

## Tasks
### Data (`src/core/resources/`)
- [x] Extend `PassengerProfile` with: `portrait`, `archetype`, `dossier_pages`, `actions`, `hidden_traits`, `tip_multiplier`, `spawn_weight`, `districts`, `min_shift`.
- [ ] ➡️ deferred: multi-page files (`DossierPage`) — single page with notes for now (D-045).
- [x] `Examinable` (id, label, reveal_text, time_cost, `unlocks_actions: Array[StringName]`, `reveals_traits`).
- [x] `PassengerAction` (id, label, `requires_examined`, `requires_traits`, `requires_perk`, `outcome` enum/resource).
- [x] Optional: randomised fields (name/age pools) so profiles of the same archetype vary.

### Dossier UI (`src/dossier/`)
- [x] `Dossier` Control: paper/folder look, page tabs, portrait, `RichTextLabel` with clickable highlighted words (`[url=examine_id]`) for examinables.
- [x] Opens on `passenger_entered`; game time slows (`Engine.time_scale`) or taxi is held; mouse cursor visible.
- [x] Examine: reveals text, costs shift time, may unlock actions (buttons appear).
- [x] Action buttons built from `PassengerAction` list filtered by conditions.
- [x] Emits `dossier_action_chosen(profile, action_id)`.

### Outcomes (`src/ride/`)
- [x] `RideManager` handles new states: `DOSSIER_OPEN`, `EJECTING` (kick out: passenger exits/is thrown), `KILL_SEQUENCE` (camera turns, flash, sound, passenger removed), `SPECIAL` (dispatches to outcome handler).
- [x] Outcome handler interface so archetype-specific outcomes can be added in Phase 07 without touching the state machine.
- [x] Record decision in `Ride` (for summary & events).

## Definition of done
- 3 test passengers with different dossiers; examining unlocks a hidden "kill" action on one of them; all actions resolve correctly and return to the ride loop.

## User test checklist
- [x] Dossier readable at a glance? Time slow vs full pause — which feels better? *(user 2026-11-12: works as intended; full pause kept)*
- [x] Examine interaction intuitive?

## Notes
- 2026-11-11 (Iteration 06): built.
  - Data: `Examinable`, `PassengerAction` (Outcome DRIVE / KICK_OUT / KILL + effects: fare_mult, time_mult, destination_district, cash_delta, heat_delta, result_text), `PassengerProfile` file fields (occupation, name_pool, age range, BBCode notes with `[url=id]`, examinables, actions, hidden_traits, kick_reaction/line). `PassengerInstance` (generated name/age, examined, revealed traits, destination). Drive + Kick out are built-in defaults.
  - Flow: `RideManager` IDLE → ENTERING → **DOSSIER** → RIDING; destination reserved when the file opens; outcomes resolved from `EventBus.dossier_action_chosen`.
  - UI: `src/dossier/dossier.gd` (+ `dossier_portrait.gd`) in Main's UI layer: pauses the world, shift clock drains ×0.5 while reading, examine = −time_cost s, clickable red clues + Examine buttons, focus navigation for the pad, Esc ignored while open.
  - Kill: camera forced look-back 0.9 s + recoil + red flash, passenger slumps away. Kick: walker leaves; ANGRY → parting shot (−8 driver HP).
  - Files: commuter (harmless briefcase), tourist (map → big_tipper → scenic ×1.5 fare / ×1.4 time), rushed executive (jacket → armed+wanted → Kill +$120 & heat; phone → liar → hush money +$60).
- 2026-11-12: user playtest OK; file UI rebuilt (D-046); phase ✅ (multi-page files stay deferred).
  - 2026-11-12 (D-051): the shift clock is gone. Examining now costs time on **that passenger's ride clock** (`PassengerInstance.time_spent`, floor = 50 % of the limit); the badge in the file shows "RIDE TIME"; no drain while reading. `PassengerAction.shift_time_delta` was renamed `ride_time_delta`.
