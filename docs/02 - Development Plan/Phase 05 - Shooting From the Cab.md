---
tags: [plan, phase]
phase: 5
status: done
---
# Phase 05 — Shooting From the Cab

**Goal:** Half Grip-inspired first-person shooting while driving — raise a gun, aim freely with the mouse, fire out of the windows; driving stays fully controllable.
**Depends on:** [[Phase 01 - Taxi Driving & Cab Camera]] (can be pulled earlier than 03/04 if an iteration asks)
**Design refs:** [[Combat & Weapons]]

## Tasks
### Data
- [x] `WeaponData` resource per [[Combat & Weapons]] §3.
- [x] `data/weapons/revolver.tres`, `smg.tres`, `shotgun.tres`.

### Weapon system (`src/combat/`)
- [x] `WeaponHolder` under `HeadPivot`: viewmodel hand + gun (placeholder meshes), raise/lower animation (tween) on `aim`.
- [x] `Weapon` node driven by `WeaponData`: fire rate, mag/reserve ammo, reload with timer.
- [x] Hitscan: `PhysicsRayQueryParameters3D` from camera centre; exclude own taxi; spread = base + speed + turning factors.
- [x] Shotgun pellets (N rays). Projectile base scene for later (flare/rockets). → pellets done; projectile base deferred to the flare/rocket weapons.
- [x] Hit detection via `HitboxComponent` (Area3D or collision layer `hitboxes`) → `HealthComponent.apply_damage()`.
- [x] Feedback: muzzle flash, camera recoil kick, hit marker, bullet decals/impact particles (placeholder).
- [ ] ➡️ deferred (no glass mesh yet): Windshield: bullet-hole decal when shooting forward (cosmetic).
- [x] Weapon switching (1–4, wheel) between owned weapons (`GameState.owned_weapons`).
- [x] Crosshair + ammo counter in HUD.

### Shared components (`src/core/components/`)
- [x] `HealthComponent` (max_hp, hp, `damaged`, `died` signals).
- [x] `HitboxComponent` (forwards hits to a HealthComponent with damage multiplier — e.g. head ×2).

### Test
- [x] Shooting range in test scene: static targets + moving target cars on a path.

## Definition of done
- Can drive at speed and hit moving targets; reload and switch weapons; nothing breaks driving input.

## User test checklist
- [ ] Aiming feel (sensitivity, spread at speed).
- [ ] Gun raise/lower timing.
- [ ] Recoil/feedback satisfying?

## Notes
- 2026-11-11 (Iteration 03): built. `WeaponData` (`src/core/resources/weapon_data.gd`) + revolver / SMG / sawed-off in `data/weapons/`. `WeaponController` (`src/combat/weapon_controller.gd`) under `Taxi/HeadPivot/Camera3D/WeaponHolder`: viewmodel (sleeve + hand + gun box), raise on AIM or FIRE (hip fire lingers 0.8 s), hitscan from screen centre (mask: world, enemies, traffic, characters, hitboxes, props; taxi excluded), pellets, spread = aimed + hip + speed + yaw rate + bloom, recoil (75% springs back, 25% stays), aim zoom −10° FOV, auto-reload on empty, R reload, 1-3 / wheel / Y / D-pad switch.
- `HealthComponent` + `Hitbox` (Area3D, layer 6, damage multiplier) in `src/core/components/`. Physics props get impulses.
- FX: `CombatFx` tracers + impacts, muzzle flash mesh + small light.
- HUD: `crosshair.gd` (gap = projected spread), hit marker (white hit / red kill), ammo + weapon list.
- Range: `src/combat/shooting_range.tscn` (test course + 12 boards + 3 circling target cars with x2.5 driver hitbox); **F3 switches world** (city ↔ range). `GameState.owned_weapons` = all three until the shop.
