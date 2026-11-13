---
tags: [iteration]
iteration: 3
status: done
started: 2026-11-11
finished: 2026-11-11
---
# Iteration 03 — Shooting From the Cab

## Scope (from user, verbatim)
> driving is mangeable now, lets start with the shooting before adding the mechanics so we can polish the basics of driving

= [[Phase 05 - Shooting From the Cab]] before the passenger mechanics (Phase 04 dossier, Phase 07 archetypes). Goal: the two core feels — driving and shooting — are solid before game mechanics stack on top.

## Interpretation
Half Grip-inspired: raise a gun in the first-person cab, aim freely with mouse / right stick, shoot out of the windows while driving with simple arcade controls. Hitscan weapons from data, recoil, spread that grows with speed/turning, reload, weapon switching, crosshair + ammo HUD, hit markers, impacts. A shooting range with static and moving targets to test it.
**Out of scope:** enemies that shoot back / damage to the taxi (Phase 06), buying weapons (Phase 09), projectile weapons (flare/rockets), windshield bullet holes (no glass mesh yet), audio (Phase 11).

## Checklist
- [x] `HealthComponent` + `Hitbox` (Area3D, damage multiplier)
- [x] `WeaponData` resource + revolver / SMG / shotgun
- [x] Weapon controller: viewmodel (arm + gun), raise/lower, hitscan, pellets, spread, recoil, reload, switching
- [x] FX: muzzle flash + light, tracers, impacts, props pushed by bullets
- [x] HUD: crosshair (size = spread), ammo, reload, hit marker
- [x] Shooting range world (static boards + moving target cars, respawning) — F3 switches world
- [x] Weapon autotest
- [x] Driving regression still PASS

## Acceptance (how the user will judge it)
- [x] Can drive and shoot at the same time comfortably (KB+M and pad).
- [x] Hitting moving targets from a moving car feels satisfying.

## User test checklist
F5 → city. **F3** → shooting range (F3 again → back to the city). Controls in F2 overlay.
1. [ ] Hold **RMB / LB**: gun comes up, view zooms a little, crosshair tightens. Release: gun goes down.
2. [ ] **LMB / RB** without aiming: gun pops up and fires (wider crosshair = hip fire).
3. [ ] Range: shoot the red boards (flash white, fall over, stand back up) — hit marker white, red on kill.
4. [ ] Switch weapons **1 / 2 / 3**, mouse wheel, pad Y / D-pad: Revolver (strong, slow), SMG (hold to spray), Sawed-off (close range, pellets).
5. [ ] Empty a mag → reloads by itself; **R / X** reloads early.
6. [ ] Drive at speed and shoot the **circling red cars** (right side, behind the cones). Driver's window = x2.5 damage. Too easy / too hard?
7. [ ] Spread grows when driving fast / turning — fair or frustrating?
8. [ ] Recoil & muzzle flash feel (screen kick, light flash)?
9. [ ] Driving + shooting at the same time comfortable on KB+M? On the pad (triggers drive, bumpers aim/fire)?
10. [ ] Bullets knock the orange cones around.

## Feedback from user
**2026-11-11 (1):** arrow — not clear if it points forward or backward, should be at a slight angle → tilt 40°, two-tone head/tail, bigger (D-034).

**2026-11-11 (2):** "shooting and arrow feels great, let's move on to the next logical iteration" → closed.

## Discovered / Deferred
- Auto-reload only triggered on a *new* trigger press — fixed: reloads as soon as the mag runs dry (found by the weapon autotest).
- Muzzle-flash light flooded the whole cab — reduced (found by screenshot).
- Windshield bullet holes deferred (no glass mesh); projectile weapons (flare/rockets) deferred.
- No aim assist on the pad yet — decide after playtest.

## Result summary (fill when done)
✅ **Closed 2026-11-11** — user: shooting and arrow feel great.
Built & auto-verified 2026-11-11: import clean; weapon autotest PASS (hit + damage + ammo + hit marker, auto reload, reload math, SMG 11 shots/s, shotgun pellets, spread grows 4.0°→4.9° at 77 km/h, no self-hits); 8 vehicle scenarios + ride test still PASS; screenshots (aimed revolver, SMG hip fire) checked. Pending user playtest.
