---
tags: [iteration]
iteration: 24
status: active
started: 2026-11-17
finished:
---
# Iteration 24 — Currencies & Slots

Same branch as [[Iteration 23 - Dev Notes]] (`feat/no-papers`), pushed after `7084e03` (not played yet). Decisions: D-106, D-107.

## Scope (from user, verbatim)
> "we need to implement different currencies, lets say that when you defeat a boss you win a slot ticket, the slot ticket gives you acces to the slot machine that can give you a random perk (we will replace the perk shop) It can also give you +5 levels in the damage or rate of fire of you 1st and 2nd most upgraded weapon as well. Besides that i want the enemies that we kill to drop another currency with which we will upgrade the car so it doesnt feel like a waste of potential damage when we do it, lets say that currency is a nut or spareparts, make the mathematic so if you kill the exact number of enemies before the boss arrives, you can afford the amount of upgrades required to still not be super tanky, but if you take the time to kill more of the enmies before the boss that you could squeeze 2 or 3 levels extra and be way more strong"

## What was built
- **Three currencies.** Cash: guns and gun upgrades. **Spare parts**: every cab upgrade. **Slot tickets**: the slot machine.
- **Spare parts** come from every enemy you destroy, straight into your wallet ("HITMAN DOWN +$80 +1 PART"): 1 per car, 2 for elites and bosses. Cab prices: 4-6 parts for a first level, 6-9 for a second, 9-13 for a third.
- **The math** (kills only): at the stage-1 boss, the 10 kills buy 2 cab levels (20 kills: 4); stage 2: 5 levels (8 if you kill 15 more); stage 3: 8 of 18 (11). Elites, bosses and escorts add a little.
- **Slot tickets:** one for every boss beaten in a boss fight (stage 1: 1, stage 2: 3, stage 3: 2). The stage-2 gang bosses now get the gold boss marker in their fight too.
- **SLOTS tab** (was PERKS): the slot machine. Spin = 1 ticket, always wins: half the time a random perk level (Double Tap, Quick Hands, Rolling Pickup; no longer sold), half the time +5 Damage or +5 Fire rate on your most or second most upgraded gun. Three reels roll and land on the prize.
- HUD: parts and tickets left of the cash.

## Files
New: `src/shop_menu/slot_machine.gd`, `tests/currencies_autotest.{gd,tscn}`. Changed: `src/autoload/{game_state,event_bus}.gd`,
`src/core/resources/enemy_car_data.gd`, `data/enemies/{gang_boss_*,cartel_lieutenant,boss_*}.tres` (parts),
`src/shop_menu/{car_upgrade_data,car_upgrades,shop_menu}.gd`, `data/car_upgrades/*.tres` (prices in parts),
`src/enemies/{enemy_director,enemy_car,hostile_marker}.gd`, `src/escalation/escalation.gd`,
`src/ui/hud/{hud,threat_markers,minimap}.gd`; tests `shop_menu` (pays in parts, slot screenshots), `dev_notes` (perks granted, not bought).

## Checklist
- [x] Spare parts from kills, cab upgrades in parts
- [x] Slot tickets from bosses
- [x] Slot machine replaces the perk shop (perk or +5 gun levels)
- [x] Parts math against the stage kill targets (printed by the test)
- [x] `currencies_autotest` (new) + the suite
- [x] Screenshots: THE CAB in parts, SLOTS rolling / won
- [ ] **User playtest**

## What to test (user)
1. Play stage 1 killing about the target: can you afford ~2 cab levels at the boss? Farm more: ~4?
2. Is the slot machine exciting enough? (Odds: `SlotMachine.PERK_SHARE`; prize size: `GUN_LEVELS`.)
3. With cash now only for guns: do guns get too strong too fast? (Enemy health still follows cash.)

## Discovered / Deferred
- Parts are paid on the kill instead of dropping as a pickup (the ammo boxes already need chasing); easy to turn into a floating pickup like the ammo if wanted.
- Only three perks (6 levels): after ~6 perk wins the machine pays gun levels only. More perks = new `perk_*.tres` + their effect.

## Playtest feedback
- **"you misunderstood my slot machine request ... approximately 6 to 7 tickets, so they need to be fairly strong ... you CAN'T buy the other perks ... a full animation slot machine where you insert the ticket and pull down the lever"**, then **"also want a guardian angel as a perk, that recharges every 5 minutes. and lets have a devastation weapon that is insanely op but cant be upgraded"** → D-107:
  - Perks are one strong level each, slots only: Double Tap +50 % fire rate, Quick Hands −50 % reload, Rolling Pickup, **Juggernaut** +50 % health, **Road Vampire** (kills heal 10 %), **Deep Pockets** (+50 % ammo, refilled), **Guardian Angel** (cheat death, 5 min recharge).
  - The **slot machine** is a full-screen animated machine: insert the ticket, pull the lever, three reels roll and stop on the prize, then a prize card with confetti. `src/shop_menu/slot_machine_screen.gd`.
  - **The Devastator**: $9500 at 26 fares, 4000 damage rockets with a 13 m blast, cannot be upgraded (`WeaponData.upgradable`).
  - What to test: does a spin feel like a big moment? Is the Devastator too much (or not enough) when you get it?
