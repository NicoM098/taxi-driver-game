---
tags: [plan, phase]
phase: 1
status: done
---
# Phase 01 — Taxi Driving & Cab Camera

**Goal:** an arcade taxi that feels fun to drive, seen from the driver's seat with free head-look.
**Depends on:** [[Phase 00 - Project Setup]]
**Design refs:** [[Game Design Document]] §2

## Key decision (record in [[Decisions Log]])
**Custom raycast-suspension `RigidBody3D`** vs built-in `VehicleBody3D`.
Recommendation: **custom raycast vehicle** — full control over arcade feel (grip, drift, air control, boost), predictable with Jolt, and the standard approach for arcade racers. Fall back to `VehicleBody3D` only if time is critical.

## Tasks
### Vehicle (`src/vehicle/`)
- [x] `taxi.tscn`: `RigidBody3D` root, box collision, placeholder taxi mesh (yellow box + cabin), centre of mass lowered.
- [x] 4× `RayCast3D` wheels: spring/damper suspension force per wheel.
- [x] Engine force along forward axis at driven wheels; top speed cap; reverse.
- [x] Lateral grip: cancel sideways velocity per wheel (tunable grip curve); lower rear grip with handbrake → drift.
- [x] Steering: speed-sensitive steering angle; visual wheel meshes rotate/steer.
- [x] Air control: slight pitch/roll correction when airborne; auto-upright if flipped (after N seconds or button).
- [x] Boost (placeholder, unlimited for testing, later tied to upgrades).
- [x] All tunables as `@export` (later move to a `VehicleStats` resource so upgrades can modify them).
- [x] Expose `get_speed_kmh()`, `is_grounded()`, signals `crashed(impact: float)` (for damage later).

### Cab camera (`src/camera/`)
- [x] `HeadPivot` at driver eye position inside cabin; `Camera3D` child; FOV ~75–80 (speed-based FOV kick).
- [x] Mouse look: yaw ±110°, pitch ±60°, smooth return-to-centre when not aiming (toggleable).
- [x] Subtle head bob/lean from acceleration & cornering (g-forces), camera shake on impacts.
- [x] Simple interior: dashboard, steering wheel that rotates with input, A-pillars, rear-view mirror (SubViewport, optional/low priority). → interior done; mirror is a black placeholder (render deferred).

### Debug
- [x] Test scene `src/vehicle/test_drive.tscn`: big plane, ramps, slopes, cones.
- [x] Debug label: speed, grounded wheels, drift state.

## Definition of done
- Can drive, drift with handbrake, hit a ramp and land without flipping wildly, recover when flipped.
- First-person camera inside the cab with free look; no clipping through the body at normal angles.
- 60 FPS on the test scene.

## User test checklist
- [ ] Driving feel: acceleration, top speed, turning at low/high speed.
- [ ] Handbrake drift — controllable?
- [ ] Ramp jump & landing.
- [ ] Head-look comfort; motion sickness check (bob/shake intensity).

## Notes
- 2026-11-10 (Iteration 01): implemented; headless autotest passes (`res://tests/vehicle_autotest.tscn`, plus `-- --jump`). Awaiting user playtest for feel.
- D-005 accepted: custom raycast `RigidBody3D` (`src/vehicle/taxi.gd`). Arcade assists added after autotest showed problems: `turn_speed_retention` (turns were scrubbing 80→19 km/h) and `yaw_stability` + rear grip > front (full lock at 80 km/h spun the car). Handbrake held at high speed still gives a 180° (by design: tap = drift, hold = spin).
- Driving input goes through `VehicleInput` + an input provider node (`PlayerVehicleInput`) so AI cars can reuse `Taxi` in Phase 06.
- Test course is built in code: `src/vehicle/test_drive.gd`.
- Tuning knobs: all `@export` on the Taxi node (Inspector) and on HeadPivot (`CabCamera`).
- 2026-11-11 playtest: driving, turning, city/bumps, steering wheel approved. Changed: jump nose-dive + landing bounce (D-018), low-speed handbrake (D-019). Autotest scenarios now: default, `--jump` (prints landing pitch/hop), `--handbrake-low` (`--hb-legacy` to compare), `--flip`.
- 2026-11-11 (2): landing bounce reworked to a deterministic hop + camera landing dip/shake (D-020). `--jump` autotest now logs every air phase (duration, apex, pitch).
- 2026-11-11 (Iteration 02 playtest): handbrake spin-out regression fixed with a drift angle limiter (D-027). New autotest scenarios `--handbrake-high`, `--handbrake-straight`.
- 2026-11-11: handling restored to the Iteration 01 tune (D-030); new `--weave` autotest guards normal driving against drift-chain side effects.
