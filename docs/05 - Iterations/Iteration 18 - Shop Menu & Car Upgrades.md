---
tags: [iteration]
iteration: 18
status: active
started: 2026-11-17
finished:
---
# Iteration 18 — Shop Menu & Car Upgrades

Same branch as [[Iteration 17 - Gang Rides]] (`feat/no-papers`).

## Scope (from user, verbatim)
> "good but way too hard, what i aslo want to do in this branch is delete the shops and have all
> of the shops in a menu that you can open anytime, and add upgradesfor the car and the monstrous
> energy cans"

## Interpretation
- **"Way too hard"** → the gang-rides numbers are tuned down (D-088 table updated).
- **"Delete the shops"** → isolated, not deleted (like the passenger file): one switch,
  `ShopMenu.enabled` (`src/shop_menu/shop_menu.gd`). While on, the city builds no gun shop and no
  repair garage: their lots become plain buildings. The shop code, the map editor pieces and the
  user's maps are untouched; `false` brings them back.
- **"A menu you can open anytime"** → **B** (pad: Back) opens the SHOP and pauses the world, even
  mid-ride. Not on top of another screen and not once dead.
- **"Upgrades for the car and the monstrous energy cans"** → read as both: taxi upgrades, and
  Monstrous Energy (the game's own fictional drink) cans you **buy, carry and drink with F** (pad:
  Y), plus two upgrades for the cans.

## Design (D-089)
| Entry | Price | Effect |
|---|---|---|
| Gun rack | — | opens the existing gun shop screen (unlocks by fares still apply) |
| Repair the cab | as the old garage: $0.8 / taxi hp + $0.4 / driver hp | full repair, anywhere |
| Armor Plating | 350 / 800 / 1600 | +25 % taxi health per level |
| Engine Tune | 400 / 900 / 1800 | +12 % engine power, +6 % top speed per level |
| Bulletproof Glass | 450 / 1000 / 2000 | −20 % damage to the driver per level |
| Ram Bar | 300 / 700 / 1400 | −25 % crash damage per level |
| Monstrous Energy can | $60 each | heals 50 driver + 30 cab over 1.2 s; carry 2 at the start |
| Monstrous XL | 250 / 600 / 1200 | +35 % healing per can per level (street cans too) |
| Cup Holder Rack | 200 / 450 / 900 | +2 cans carried per level (max 8) |

Everything is lost with the run (like guns, D-085). A wreck still ends the run.

## Checklist
- [x] `ShopMenu` (screen, `enabled` switch, closed lots), `CarUpgrades` (economy), `CarUpgradeData`
      + `data/car_upgrades/*.tres`, `CanHolder` (cans line on the HUD + drink key)
- [x] `GameState.car_levels` / `cans` (reset with the run); input actions `shop_menu` (B / Back),
      `drink` (F / Y — Y no longer cycles guns, D-pad right still does)
- [x] City: no shops while on; TaxiDamage: a wreck still ends the run without garages; street cans
      use Monstrous XL; main menu controls list
- [x] Gang rides tuned down
- [x] New `tests/shop_menu_autotest` (A-G); shop / map / minimap / ride tests run with the switch off

## User test checklist
- [ ] Is the game fair now (gang rides)? Still too hard / now too easy?
- [ ] Shop menu: easy to read? Is opening it mid-chase (the world pauses) too strong?
- [ ] Do the car upgrades feel worth it? Engine Tune: does the cab still handle?
- [ ] Monstrous Energy: are $60 cans + F to drink fun to use in a fight?

## Feedback from user
-

## Discovered / Deferred
- Repair anywhere while paused makes fights forgiving; a price premium or "not while enemies are
  close" would be the first lever if it is too easy.
- The map editor still offers the gun shop / repair pieces; in this mode they build as plain lots.
- The minimap still has the shop-blip code; it simply has no shops to draw.
- The controls list no longer mentions the passenger file (off in this branch).

## Result summary (fill when done)
