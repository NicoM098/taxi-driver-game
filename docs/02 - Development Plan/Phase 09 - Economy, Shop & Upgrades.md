---
tags: [plan, phase]
phase: 9
status: not-started
---
# Phase 09 — Economy, Shop & Upgrades

**Goal:** between shifts, a Garage screen where you spend cash on guns, ammo, taxi upgrades, driver perks and repairs.
**Depends on:** [[Phase 05 - Shooting From the Cab]], [[Phase 08 - Items & Inventory]]
**Design refs:** [[Economy & Upgrades]]

## Tasks
### Data
- [ ] `UpgradeData` (+ `UpgradeLevel`: price, modifiers) — engine, tyres, armour, nitro, ram bumper, bulletproof glass, door locks.
- [ ] `PerkData` — steady hand, quick reload, speed reader, sixth sense, haggler, pickpocket-proof.
- [ ] Prices on `WeaponData` (gun + ammo).
- [ ] Move vehicle tunables into a `VehicleStats` that reads from `PlayerStats` (engine force, grip, max HP…).

### Garage (`src/economy/` + `src/ui/garage/`)
- [ ] Garage scene: tabs Guns / Ammo / Taxi / Perks / Repairs / Items; item cards with price, owned/level, stat preview (before → after).
- [ ] Purchase flow: check cash → deduct → update `GameState` → emit `cash_changed` → refresh UI.
- [ ] Perk hooks wired into systems: e.g. `speed_reader` lowers examine time cost; `sixth_sense` reveals one trait in dossier; `pickpocket_proof` blocks `StealCashEvent`; `door_locks` unlocks a dossier action.
- [ ] "Start next shift" button.

## Definition of done
- Earn cash in a shift → buy SMG + engine upgrade → next shift the SMG is usable and the taxi is faster.

## User test checklist
- [ ] Prices feel fair after 1–2 shifts?
- [ ] Upgrade effects noticeable?

## Notes
