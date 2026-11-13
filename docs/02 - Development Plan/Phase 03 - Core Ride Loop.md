---
tags: [plan, phase]
phase: 3
status: done
---
# Phase 03 — Core Ride Loop

**Goal:** the Crazy Taxi skeleton — a passenger gets in, you drive them to a destination before time runs out, you get paid; shift timer with time bonuses.
**Depends on:** [[Phase 02 - City Graybox & Navigation]]
**Design refs:** [[Game Design Document]] §3, §5 · [[Architecture]] §5

## Tasks
### Data
- [x] `PassengerProfile` resource (minimal fields now: `id`, `display_name`, `fare_base`, `destination_tags`, `time_limit`). Extended in Phase 04.
- [x] 3 placeholder profiles in `data/passengers/`.

### Passenger in world (`src/passengers/`)
- [x] `PassengerSpawner`: spawns a waiting passenger at a random pickup spot near the player (distance window).
- [x] Passenger actor: capsule placeholder; when taxi stops (speed < threshold) inside their `Area3D` → walks/teleports into `PassengerSeat`. (Later: door animation.)
- [x] Passenger visible in the back seat (look behind with head-look).

### Ride (`src/ride/`)
- [x] `Ride` object (RefCounted): profile, origin, destination zone, start time, time limit, damage taken, style points.
- [x] `RideManager` state machine per [[Architecture]] §5 (without dossier states for now: entering → riding → arrived/failed).
- [x] Arrival: stop inside drop-off zone → passenger exits → payout.
- [x] Fare calc: `fare_base × distance_factor × speed_bonus` (+ tip placeholder).
- [x] `ShiftManager`: shift countdown; time bonus on successful ride; `shift_ended` when 0.
- [x] Emit EventBus signals: `passenger_entered`, `ride_started`, `ride_completed`, `ride_failed`, `cash_changed`, `shift_*`.
- [x] `GameState.cash` updated.

### Drift chain (GDD §3b) (`src/vehicle/drift_chain.gd` + `src/ride/`)
- [x] `DriftChain` node on the taxi: detects drift start/end + direction (sign of rear lateral slip), chain window, link count, multiplier, banked points; signals `chain_link(multiplier)`, `chain_banked(points)`, `chain_broken`.
- [x] Speed reward: on each link apply forward impulse + temporary top-speed bonus on `Taxi` (new `speed_bonus` hook; keep autotests passing).
- [x] Break on crash (`Taxi.crashed`), stop, or straight-line timeout; keep through jumps.
- [x] Money: banked points → current `Ride` tip (or shift style bonus if empty cab).
- [x] HUD: `DRIFT ×N` + window bar + "+$X" when banked.
- [x] Autotest scenario `--drift-chain`: scripted left/right handbrake flicks → assert links ≥ 3 and speed not lower at the end than at the start.
- Note: the speed part only needs the vehicle; it can be pulled into an earlier iteration if wanted.

### HUD (`src/ui/hud/`)
- [x] Shift timer, ride timer, cash, speed, destination arrow & distance, "+$X" popup on payout.

## Definition of done
- A full shift is playable: several rides in a row, timer bonuses, shift ends with a simple summary (rides done, cash earned).

## User test checklist
- [ ] Is the time pressure fun (too easy/hard)?
- [ ] Pickup stop threshold feels natural?

## Notes
- 2026-11-11 (Iteration 02): built. `PassengerProfile` (`src/core/resources/`), 3 profiles (commuter, tourist, rushed_executive) auto-loaded from `data/passengers/`. `PassengerSpawner` keeps 8 waiting (yellow beams). `RideManager` (IDLE→ENTERING→RIDING→EXITING), `Ride`, `ShiftManager` (150 s shifts, endless, summary, E/Enter/D-pad↑ for next), `HUD` (`src/ui/hud/hud.gd`, built in code), `DriftChain` (`src/vehicle/drift_chain.gd`).
- Pickup: stop (<9 km/h) within 7 m of a waiting passenger. Delivery: stop (<11 km/h) inside the 8 m ring. Ride clock = (8 s + straight distance / 11 m/s) × profile time multiplier.
- Payout = (fare_base + fare_per_100m × distance/100) × rating (SPEEDY ×1.5 if ≥50% time left, GOOD ×1.2 if ≥25%) + drift tip × tip_multiplier. Shift time bonus = 4 s + 8 s × time-left ratio.
- Drift chain: links on opposite-direction drifts within 1 s, ×0.25 per link (cap ×3), 10 pts/s × multiplier, $0.5/pt; kick 2.5 m/s × (1 + 0.5 × (mult−1)) + top speed +5 m/s for 1.5 s; crash ≥6 m/s/tick breaks it. Banked into ride tip (or STYLE cash when the cab is empty).
- Drift tuning found by autotest (D-025): drift speed retention 0.95 and handbrake braking 1500 N **only at speed** (blend 36→58 km/h) — otherwise the low-speed handbrake regressed (98°→159°).
- 2026-11-11 playtest: rides lengthened (commuter 160–380 m, executive 180–380 m, tourist 260–520 m) + destination fallback fix (D-029).
- 2026-11-11 playtest: drift chain reworked (D-030): handbrake-initiated, push 0.8 m/s + top speed +4 m/s for 2 s per link; at-speed drift assist reverted.
