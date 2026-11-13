---
tags: [design, economy]
---
# Economy & Upgrades

## 1. Currencies
- **Cash ($)** — earned from fares, tips, bounties, loot. Lost to theft, repairs, fines.
- (Optional later) **Reputation** per faction (gangs, police, business) — unlocks passengers/discounts.

## 2. Income
- Fare = `fare_base × distance_factor × speed_bonus`
- Tip = style points (near misses, air time, **drift chain bank × multiplier** — see [[Game Design Document]] §3b, no damage) × passenger `tip_multiplier`
- Bounties for killing marked passengers / pursuers
- Loot drops (items, cash)

## 3. Spending (between shifts — "Garage" screen)
| Category | Examples |
|---|---|
| **Guns** | Buy weapons from [[Combat & Weapons]] |
| **Ammo** | Refill reserves |
| **Taxi upgrades** | Engine (speed), tyres (grip), armour (HP), nitro boost, ram bumper, bulletproof glass, door locks |
| **Driver perks** | Drift king (longer chain window / higher multiplier cap), Steady hand (less spread when moving), quick reload, speed reader (examine is faster), sixth sense (one hidden trait shown for free), haggler (+fares), pickpocket-proof (no theft) |
| **Repairs** | Fix taxi HP |
| **Consumables** | Med kits, smoke screen, spike strips |

## 4. Data
- `UpgradeData` resource: `id`, `name`, `description`, `category`, `levels: Array[UpgradeLevel]` (price + stat modifiers), `requires`.
- `PerkData` resource: same pattern, single or tiered.
- Stat modifiers apply through a central `PlayerStats` (autoload or resource) so systems read final values (e.g. `PlayerStats.get_stat(&"reload_speed")`).

## 5. Persistence
Cash, owned weapons/ammo, upgrade levels, perks, inventory, shift number → saved by `SaveManager` (JSON or `ConfigFile` in `user://`).

## 6. Balancing targets (first pass, tune later)
- Shift 1 should earn enough for 1 cheap gun OR 1 upgrade.
- Businessman fare ≈ 4–6× a normal fare.
- Burglar theft ≈ 20–40% of shift cash if not stopped.
