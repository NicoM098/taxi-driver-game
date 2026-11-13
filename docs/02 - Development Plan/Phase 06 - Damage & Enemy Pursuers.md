---
tags: [plan, phase]
phase: 6
status: done
---
# Phase 06 — Damage & Enemy Pursuers

**Goal:** enemy cars that chase, ram and shoot at you; the taxi, driver and passenger can be damaged; enemies can be destroyed.
**Depends on:** [[Phase 05 - Shooting From the Cab]], [[Phase 02 - City Graybox & Navigation]] (navmesh)
**Design refs:** [[Combat & Weapons]] §4–5

## Tasks
### Player damage
- [x] Taxi `HealthComponent`: crash damage from impact impulse (`body_entered` / contact monitor), bullet damage.
- [x] Driver HP (bullets through glass) → screen damage vignette; 0 = shift over.
- [x] Passenger HP → can die from enemy fire → ride failed.
- [x] Visual damage states: smoke at <50%, fire at <20% (placeholder particles).
- [x] Emit `taxi_damaged`.

### Navigation (moved here from Phase 02 — D-022)
- [x] ~~`NavigationRegion3D`~~ → replaced by a road graph (AStar3D over the 9×9 intersections) — D-035.
- [ ] ➡️ deferred: Optional GPS line for the player.

### Enemy vehicles (`src/enemies/`)
- [x] Reuse taxi vehicle physics with an AI "driver" input instead of player input (refactor: `VehicleController` reads from an `InputProvider` — player or AI).
- [x] AI driving: follow `NavigationAgent3D` path to target, steer toward next point, brake for sharp turns, unstuck logic (reverse when blocked).
- [x] Behaviours: chase, ram (align & boost), flank (match speed alongside), retreat when heavily damaged.
- [x] Enemy gunman: shoots at player when in range + line of sight; inaccuracy scales with difficulty.
- [x] Destroying: driver killed → car coasts & crashes; car HP 0 → explosion; tyres shot → loses grip.
- [x] `EnemyDirector`: `spawn_pursuers(count, archetype)` off-screen behind the player; despawn far-away enemies.
- [x] `EnemyCarData` resource (hp, speed, aggression, shooters, weapon).

### Heat (basic)
- [x] `GameState.heat` 0–5; kills raise it; police pursuers at heat ≥3 (placeholder, expanded later).

## Definition of done
- Debug key spawns 2 hitmen cars; they chase you around the city, shoot and ram; you can kill them; you can die.

## User test checklist
- [ ] Pursuer difficulty: too aggressive / too dumb?
- [ ] Getting shot is readable (where from?).

## Notes
- 2026-11-11 (Iteration 04): built.
  - `TaxiDamage` (`src/vehicle/taxi_damage.gd`, node on the taxi): taxi body 100 HP, driver 100 HP, passenger 60 HP. Crash damage = (dv − 7) × 3 (no damage within 0.3 s of a jump landing). Body hitbox → taxi; cabin hitbox → driver ×0.45 + body ×0.3 + 35 % chance to hit the passenger. Smoke < 50 %, fire < 20 %. Wreck → `taxi_wrecked` → shift ends ("WRECKED!" / "SHOT DEAD!"); repaired at next shift (range: auto after 4 s).
  - `EnemyCar extends Taxi` (`src/enemies/`), built in code from `EnemyCarData` (hitman sedan, police cruiser in `data/enemies/`): same raycast physics, body + driver hitbox (×2.5), smoke/fire, explosion hop on death, crash damage when ramming.
  - `EnemyDriverAI` modes CHASE (road-graph route > 50 m, direct when closer; early braking + standoff point when the target is parked), FLANK (6 m alongside a moving target / 9 m standoff around a parked one), RAM (aggression-based, ends on contact), RETREAT (< 25 % HP), UNSTUCK.
  - `EnemyGunner`: 4-shot bursts, LOS check, spread grows with relative speed, damage 5.
  - `EnemyDirector` (in `game.tscn` + shooting range): spawn behind the player at distinct road nodes 70–140 m away, despawn > 330 m, bounty + heat on kill, heat decays every 45 s, police every 20 s at heat ≥ 3, clears on new shift, **F7 = 2 hitmen**.
  - HUD: TAXI / YOU / FARE bars + HEAT stars, red damage wedges pointing at shooters, red edge flash, wreck summary title.
- 2026-11-11 playtest: damage lowered, instant explosion on kill, lighter enemies, no rams on a parked taxi (D-038/039); rear-view mirror + threat markers (D-040).
