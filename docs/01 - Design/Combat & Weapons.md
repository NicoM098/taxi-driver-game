---
tags: [design, combat]
---
# Combat & Weapons

## 1. Reference: what we take from Half Grip
Only two things:
1. **First-person perspective from inside the vehicle** (you see the cabin, hands, dashboard).
2. **Shooting from the car** — you aim freely with the mouse and fire out of the windows/windshield while the car keeps moving.

What we do **not** take: its complex/simulation controls. Driving stays arcade-simple and is never interrupted by aiming.

> ⚠️ Confirm specifics with the user if any Half Grip detail matters (e.g. which hand holds the gun, whether glass breaks).

## 2. Shooting model
- **Aim:** mouse moves the head/camera within clamped yaw/pitch (approx. ±110° yaw, ±60° pitch). Crosshair at screen centre.
- **Raise gun:** hold RMB → gun comes up in the right hand (hip-fire allowed but less accurate? TBD).
- **Fire:** hitscan raycasts for most guns (cheap, responsive); projectiles for rockets/grenades.
- **Car motion affects accuracy:** spread grows with speed, bumps and turning (perk reduces it).
- **Windows / windshield:** shooting through the windshield cracks it (cosmetic → later reduces visibility?). Side windows can be rolled down/shattered.
- **Ammo:** per-weapon magazine + reserve. Reload takes time (one hand on wheel feel).
- **Feedback:** muzzle flash, recoil kick on camera, hit markers, enemy car damage smoke/fire, tyre shots.

## 3. Weapons (initial list)
| Weapon | Type | Notes | Price tier |
|---|---|---|---|
| Revolver | Hitscan | Starter. 6 shots, strong, slow | Free |
| SMG | Hitscan | High rate, high spread | $ |
| Sawed-off shotgun | Hitscan pellets | Close range, great vs. tyres | $$ |
| Rifle | Hitscan | Accurate, slow, long range — **built 2026-11-15** (slot 4, $380) | $$$ |
| Flare gun | Projectile | Sets cars on fire, blinds pursuers | $$ |
| Grenades | Thrown | Drop out the window behind you | $$$ |
| Mini-rockets | Projectile | Late game | $$$$ |

`WeaponData` resource: `id`, `name`, `mesh`, `damage`, `fire_rate`, `mag_size`, `reserve_max`, `reload_time`, `spread_base`, `spread_speed_mult`, `pellets`, `projectile_scene`, `price`, `ammo_price`.

## 4. Damageables
Common `HealthComponent` (node) used by: player taxi, driver, enemy cars, enemy drivers, passengers (for the "kill" action & stray bullets).
- Enemy car: kill the driver (headshot through glass) OR destroy the car OR shoot tyres → crash.
- Passenger in the back can be hit by enemy fire → ride failed.

## 5. Enemies
- **Pursuer car:** AI that follows the taxi (navmesh/road graph), rams, and a gunman shoots when in range & line of sight.
- Variants: hitman sedan, gang van (2 shooters), police cruiser (heat), armoured SUV (late).
- Difficulty scales with shift number and heat.
- **Spawn placement:** gameplay spawns are strategic — ahead on the route to the objective to block it (ambush / pincer), not just behind (see [[Passengers & Encounters]] §5).

## 6. Melee / special kills
"Kill on the spot" from the dossier plays a short, stylised sequence (turn around, shoot) — no complex animation needed at first (camera turn + flash + sound + passenger ragdoll/fade).

## 7. As built (2026-11-15, D-064 / D-067)
Revolver (free, slot 1) · SMG ($180, slot 2) · Sawed-off ($260, slot 3) · Rifle ($380, slot 4). Bought at **gun shops** in the world (stop on the green pad); ammo refills $15-40. A run starts with the revolver. HUD: weapon hotbar with silhouettes, lock + price on guns you do not own.

## Ammo, death (2026-11-15, Iteration 12)
- Spare rounds cut so the gun shop matters (D-072): revolver 6 | 30, SMG 30 | 120, sawed-off 2 | 20, rifle 5 | 20.
- Civilian cars are destructible (90 HP) but cost heat (D-075).
- **Either bar at 0 = the cab explodes, GAME OVER, back to the main menu** (D-077). Repair shops fix damage for cash before that; limp mode (D-056) is gone in real maps.
