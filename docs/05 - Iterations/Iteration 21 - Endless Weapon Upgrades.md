---
tags: [iteration]
iteration: 21
status: active
started: 2026-11-17
finished:
---
# Iteration 21 — Endless Weapon Upgrades

Same branch as Iterations 17-20 (`feat/no-papers`). Replaces the Mk I-IV track of
[[Iteration 16 - Weapon Upgrades & Unlocks]] (D-085). Decision: D-093.

## Scope (from user, verbatim)
> "i want the upgrade system for the guns to be infinite but exponential, lets take for example
> the pistol, lets say that you have the mag, ammo capacity, damage and rate of fire upgrades,
> aftera certain amount of upgrades they just cycle trough damage and rate of fire with higher
> increments every 3 levels of each, mathematically the weapon should hold on to the current
> health of the enemies, but it would require spending only on that weapon, if you start spending
> money on something else it should fall off, also i want to lower the fares needed to unlock
> weapons by 10 to 15% to what it is now, i get to the second phase 3 bosses with only the mines
> most of the time"

**Answers to Claude's three questions (2026-11-17):**
- Buying: **separate stat tracks** (four buttons per gun).
- Enemy health: **keeps growing**, tuned so a gun with all the money in it keeps pace.
- The Mk IV specials: **kept, as a milestone** after a number of upgrades.

## What was built
- **Four tracks per gun**, each its own button on the gun's shop card:

  | Track | Per level | Levels | First price | Growth |
  |---|---|---|---|---|
  | Mag | +25 % of the base magazine | 3, then MAXED | $150 | ×1.6 |
  | Ammo (spare) | +40 % of the base reserve | 3, then MAXED | $125 | ×1.6 |
  | Damage | +10 % (lv 1-3), +15 % (4-6), +20 % (7-9), +25 % … | endless | $250 | ×1.35 |
  | Fire rate | +6 % (lv 1-3), +9 % (4-6), +12 % (7-9), +15 % … | endless | $275 | ×1.35 |

  Steps compound. Same prices for every gun (see D-093 for why). Every purchase refills ammo.
- **Fire-rate cap:** a gun never fires faster than 3× its base or 30 shots/s (whichever is lower);
  levels past that add the same % as **damage** instead ("+12% as dmg" on the button). DPS
  keeps the curve; the rocket launcher stays a rocket launcher.
- **Special = milestone:** after **8 upgrades** on a gun (any tracks) its special switches on
  (Deadeye, drum mag, Dragon's breath, AP rounds, heavy charge, hot barrels, twin tubes, piercing
  beam). The card's pips count down to it; the hotbar shows `+N` (yellow once the special is on).
  Dragon's breath burn now scales with the gun's damage upgrades.
- **Enemy health grows with the run's earnings** (`GameState.earned`: every dollar earned,
  spending not taken off). Each enemy spawns with `hp × WeaponUpgrades.enemy_hp_mult()` = the DPS
  multiplier a gun would have if **75 %** of everything earned had gone into its damage and fire
  rate (cheapest level first). Boss bars use the scaled health.

  | Earned this run | Enemy health | Same gun, half the money |
  |---|---|---|
  | $1 000 | ×1.24 | ×1.13 |
  | $3 000 | ×1.61 | ×1.34 |
  | $6 000 | ×2.33 | ×1.61 |
  | $10 000 | ×3.10 | ×2.08 |
  | $25 000 | ×7.0 | ×3.8 |
  | $60 000 | ×18.9 | ×8.4 |

  All in on one gun → its time-to-kill stays what it is at the start of the run. Money into
  other guns, the cab or ammo → that gun falls behind (buying a new gun is worth it only if its
  base damage makes up for it).
- **Unlocks −15 %:** SMG 5→4, sawed-off 12→10, mines 15→13, rifle 20→17, minigun 22→19,
  rocket 28→24, laser 35→30 fares.

## Files
`src/combat/weapon_upgrades.gd` (rewritten), `src/combat/weapon_controller.gd` (`upgrade(id, track)`),
`src/autoload/game_state.gd` (`weapon_levels` per track, `earned`), `src/core/resources/weapon_data.gd`
(`upgrade_cost` replaces `upgrade_prices`), `data/weapons/*.tres`, `src/enemies/enemy_car.gd`,
`src/escalation/escalation.gd` (boss bars), `src/shop_menu/shop_menu.gd` (gun cards: BUY / AMMO,
EQUIP, four track buttons), `src/ui/shop/gun_shop_ui.gd` (old in-city gun shop: four track buttons),
`src/ui/hud/weapon_bar.gd`; tests `upgrades` (rewritten + parts H, I), `arsenal`, `shop`, `shop_menu`.

## Checklist
- [x] Four tracks, mag / ammo capped at 3, damage / rate endless with bigger steps every 3 levels
- [x] Exponential prices
- [x] Fire rate past its cap → damage
- [x] Special after 8 upgrades
- [x] Enemy health follows the curve of an all-in gun
- [x] Unlocks −15 %
- [x] Shop menu cards + old gun shop screen + hotbar tag
- [x] Tests updated (upgrades A-I, arsenal, shop, shop_menu)
- [x] Shop screenshot at 720p: the taller gun cards read, the grid scrolls to the last row
- [ ] **User playtest**

## What to test (user)
1. Pick one gun and put everything into Damage / Fire rate. Do fights feel about the same
   speed from stage 1 to stage 3? (They should.)
2. Spread money over several guns and the cab. Do enemies start to feel spongy? (They should.)
3. Is the 8-upgrade special milestone reached at a good moment?
4. Do you get a second / third gun before the stage-2 boss now (mines at 13, minigun at 19)?
5. Late in a run, are enemy health numbers too high? Tuning knobs: `SCALING_SHARE` (0.75),
   `PRICE_GROWTH` (1.35), the step sizes, all in `WeaponUpgrades`.

## Discovered / Deferred
- Ammo refill prices stay flat while magazines grow; with enemies tougher late, ammo may run out
  faster. Watch in the playtest.
- `arsenal_autotest` relied on the minigun's old Mk III recoil cut: part of every shot's recoil
  stays in the aim, so the rocket could sail over its boards. The test now levels the aim first.

## Playtest feedback
- **2026-11-17, first run (with Iteration 22 ammo drops):** "game is kinda hard, not because the
  bullets but the dmg is too low ... lowering the prices a little bit and making the fares give you
  substantially more, lowering the difficulty by 10 to 15%". → D-095: fares ×1.5, every price
  −10 % (guns, car upgrades, upgrade tracks $250 → $225), enemy health ×0.9 and the curve re-tuned
  (`SCALING_SHARE` 0.8) so the net is 10 % easier at the start and ~15 % late. The tables above
  are the pre-D-095 numbers. Not played yet.
- **2026-11-17, second run (after D-095):** at the stage-2 third boss with the revolver +14, mines
  unlevelled and $440: "at this stage i would like to have at least 4 guns and some upgrades, not
  even mention the car upgrades ... it would feel more rewarding if i felt like my guns were over
  powered". → D-096: fares ×2.5 (was ×1.5), bounties ×2, enemy curve `SCALING_SHARE` 0.35 and
  ×0.85: a gun with 40 % of the money is ~1.3-1.5× the enemies, all in 1.4-3×. Not played yet.
