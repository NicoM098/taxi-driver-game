---
tags: [iteration]
iteration: 19
status: active
started: 2026-11-17
finished:
---
# Iteration 19 — Shop Polish & Nitro

Same branch as [[Iteration 17 - Gang Rides]] and [[Iteration 18 - Shop Menu & Car Upgrades]] (`feat/no-papers`).

## Scope (from user, verbatim)
> "we need to better the ui of the shop, first im not able to enter the sub menus like the aromry
> from the list, but instead i ahve to click the armory button and then click on the right the
> button to open the armory, same with the upgrades of each gun, also just make it preattier
> overall, more polished finish. Then before i forget i want the shops menu to be open with tab,
> and i want a nitro bar that is in a easy to see zone and looks cool"

## Interpretation
- **No sub-menus, one click** → the list + detail panel is gone. The shop is three **tabs of
  cards** (GUNS, THE CAB, MONSTROUS ENERGY) and every card carries its own buttons. The gun rack
  is no longer a second screen: each gun's card has BUY / UPGRADE, AMMO and EQUIP right on it.
- **Prettier** → rounded cards with an accent stripe (green = equipped, blue = stored, yellow =
  for sale, grey = locked), drawn icons (gun silhouettes, shield, bolt, cracked glass, ram bar,
  nitro bottle, cans), level pips, money buttons filled with the tab colour, cards light up on
  hover / focus, slide-in on open, a flash on purchase, cash flashes when it changes.
- **Tab** opens / closes it (pad: Back). Tab is no longer an interact key (E / D-pad up still are).
- **"A nitro bar"** → there was no nitro: the boost was endless. Now the boost burns a **tank**
  (a full one lasts 4 s), it refills after 1 s off the boost, drift-chain links top it up, and an
  emptied tank must refill to 20 % before it lights again. Enemy cars keep an endless boost.
  The gauge sits **left of the minimap and the speed** — the corner you already look at for speed.

## Design (D-090)
| Thing | Value |
|---|---|
| Tank | 100, drain 25 / s, refill 8 / s after 1.0 s, relight at 20 |
| Drift link | +8 × chain multiplier |
| Nitro Tank upgrade (THE CAB) | +35 % tank and refill per level, $300 / 700 / 1400 |
| Tabs | Q / E or LB / RB, or click |
| Repair | always in the header: cab / driver HP and REPAIR $x |

## Checklist
- [x] `ShopMenu` rewritten: tabs, cards, buttons on the cards, `gun_action(id, main|ammo|equip)`
- [x] `GunShopUI.said` signal: the menu shows the gun shop's messages (its rules are reused)
- [x] Tab = `shop_menu` (`setup_project.gd`, `project.godot` regenerated); CanHolder, main menu, weapon bar texts
- [x] Taxi nitro (`nitro_tank`, `_update_nitro`, `add_nitro`); EnemyCar off; DriftChain links refill
- [x] `NitroGauge` HUD (segmented, glow + chevrons when boosting, red blinking EMPTY)
- [x] `data/car_upgrades/nitro.tres`, `CarUpgrades.apply` (new bottle comes full)
- [x] `shop_menu_autotest` F (cards, tabs) and H (nitro) — PASS; screenshots of the three tabs and the gauge
- [ ] **User playtest:** does the tank feel right (too short? refill too slow?), is the shop clear

## Notes
- The old `GunShopUI` screen is still there for `ShopMenu.enabled = false` (city gun shops).
