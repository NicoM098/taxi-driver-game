---
tags: [iteration]
iteration: 16
status: active
started: 2026-11-16
finished:
---
# Iteration 16 — Weapon Upgrades & Unlocks

## Scope (from user, verbatim)
> "Ahora lo que quiero implementar es... un sistema de mejoras para las armas y que las armas no
> sean tan fáciles de conseguir, porque ahora mismo es muy aburrido porque las conseguís a todas
> muy rápidamente."

Follow-up the same day:
> "Quiero también que agregues mucha variedad de armas. Minas, Rocket Launcher, Minigun, que sean
> carísimos, y rayo láser también."

> "Mi idea era que solamente se pudiera equipar hasta un máximo de 4 armas a la vez."

Design calls asked and answered the same day:
- How guns get harder to get → **"Reputación + precio"**: each gun unlocks after N fares delivered in the run, and costs about twice as much.
- How upgrades work → **"Mejoras con efecto especial"**: stat levels, and the last level unlocks something unique per gun.
- On GAME OVER → **"Se pierde todo"**: guns and upgrades belong to the run, like before. No save system.

## Interpretation
- "Fares delivered" = `ShiftManager.rides_completed` of the current run (resets with the run).
- One upgrade track per gun, Mk I (as bought) → Mk IV; II and III are stats, IV is the special.
- Upgrades are bought at the gun shop, which also refills that gun.
- OUT of scope: a save system, new guns, upgrade shops other than the gun shop, upgrades for the taxi.

## Design (D-085)
| Gun | Price | Unlock | Mk II / III / IV | Mk IV special |
|---|---|---|---|---|
| Revolver | start | — | $150 / $300 / $650 | **Deadeye**: aimed shots ×2 damage |
| SMG | $400 (was 180) | 5 fares | $250 / $500 / $950 | **Drum magazine**: 75-round mag, reserve ×2 |
| Sawed-off | $600 (was 260) | 12 fares | $300 / $650 / $1100 | **Dragon's breath**: pellets set the target on fire, 9 dmg/s for 4 s |
| Rifle | $850 (was 380) | 20 fares | $400 / $800 / $1400 | **AP rounds**: goes through up to 3 cars in a line |

Mk II: damage +25 %. Mk III: magazine +50 %, reload −25 %, spread and recoil −30 %. Levels stack.

### Heavy weapons (D-086)
Keys below were the first pass; with the loadout (D-087) every gun goes on keys 1-4.

| Gun | Key | Price | Unlock | How it works | Mk IV special |
|---|---|---|---|---|---|
| Mines | 5 | $1800 | 15 fares | dropped 3.4 m behind the taxi, arm in 0.8 s, any enemy / civilian car within 3.2 m sets them off; 220 dmg, 5 m blast; max 8 on the map | **Heavy charge**: blast radius ×1.6 |
| Minigun | 6 | $2500 | 22 fares | hitscan, 20 rounds/s, 200-round belt, 0.6 s spin-up before the first shot | **Hot barrels**: no spin-up |
| Rocket launcher | 7 | $3500 | 28 fares | a visible rocket at 55 m/s, explodes on the first thing it touches; 180 dmg, 6 m blast | **Twin tubes**: two rockets a shot |
| Laser | 8 | $5000 | 35 fares | continuous beam while held (25 ticks/s × 6 dmg ≈ 150 dps), no spread, no recoil | **Piercing beam**: through up to 3 cars |

Explosions (`Blast`) hit each target once, fall off to 35 % at the edge, shove cars, and **never hurt the player's taxi**. Upgrade prices: mines 600/1200/2200, minigun 800/1500/2800, rocket 1000/1900/3500, laser 1400/2600/4500.

## Checklist
- [x] `WeaponData`: `unlock_rides`, `upgrade_prices`, `special`, `special_name`, `special_text`; values in `data/weapons/*.tres`
- [x] `GameState.weapon_levels` (reset with the run)
- [x] `WeaponUpgrades` (stats per level, prices, unlock check); `WeaponController` fires upgraded copies, `upgrade(id)`
- [x] Specials: deadeye, drum, dragon's breath (`Burning`), AP rounds (piercing ray)
- [x] Gun shop: LOCKED x / N fares, Mk level, next upgrade, UPGRADE button; hotbar: Mk tag, "N MORE FARES"
- [x] New `tests/upgrades_autotest` (A-F); `shop_autotest` updated (locks, prices, upgrade)
- [x] Heavy weapons (D-086): `WeaponData.kind` / `beam` / `spin_up` / `blast_radius` / `projectile_speed`; `Blast`, `Rocket`, `Mine`; laser beam; minigun spin-up; keys 5-8
- [x] Gun shop rebuilt as list + detail (eight guns do not fit as cards); hotbar shows owned guns + the next one on sale, two rows past four
- [x] New `tests/arsenal_autotest` (A-F, 18 checks)
- [x] Loadout of four (D-087): guns bought are owned, at most 4 equipped on keys 1-4, the rest stored at the gun shop (EQUIP / UNEQUIP there); keys 5-8 removed again; `upgrades_autotest` part G, `shop_autotest` equip checks

## User test checklist
- [ ] Is the pace right? SMG after 5 fares, sawed-off after 12, rifle after 20 — and the prices on top.
- [ ] Upgrades: does Mk II / III feel stronger? Are the prices worth it?
- [ ] Each special: revolver aimed double damage, SMG drum, sawed-off fire, rifle through cars in a line.
- [ ] Gun shop screen: readable? Locked guns obvious?
- [ ] Loadout: is choosing 4 at the gun shop fun, or a chore? Is buying a 5th (it gets stored) clear?
- [ ] Heavy weapons: mines behind you when chased, minigun spin-up, rockets on a group of cars, laser. Too strong / too weak for the price?

## Feedback from user
-

## Discovered / Deferred
- AP rounds are tested against boards, not real `EnemyCar`s (the exclusion of the whole car body is written for them but only exercised in play).
- Rockets, minigun, mines and laser reuse the generated shot sounds, pitched (KI-037). Explosions use the existing boom.
- Explosions do not hurt pedestrians: they have no hitboxes (same as KI-030).
- Burning damage does not show a hit marker or credit "kills" to the hit marker (the bounty is still paid when the car dies).

## Result summary (fill when done)
