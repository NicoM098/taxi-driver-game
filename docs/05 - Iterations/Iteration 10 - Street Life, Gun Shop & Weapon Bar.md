---
tags: [iteration]
iteration: 10
status: built-awaiting-playtest
started: 2026-11-15
finished:
---
# Iteration 10 — Street Life, New Fares, Gun Shop & Weapon Bar

## Scope (from user, verbatim)
> i want to add a little variety of npcs and drives, the weapon shop witha  couple of options and a better ui for weapon selection that is more visually clear

Clarified (question in session 14): "npcs and drives" = **both** street life (pedestrians + traffic) **and** a few new passenger types.

## Interpretation
- **Street life (D-065):** pedestrians walking the curbs (dodge fast cars, run from gunfire, can be knocked down) and civilian traffic driving in the right-hand lane. Spawned out of sight around the player, recycled far away.
- **New fares (D-066):** four passengers built only from existing ride-event blocks — no new code.
- **Gun shop (D-064):** a new map piece like the repair shop; stop on its green pad → shop screen: buy SMG / Sawed-off / new **Rifle**, refill ammo. A run now starts with the revolver only.
- **Weapon selection UI (D-067):** a hotbar of four slot cards with gun silhouettes instead of the text line.
**Out of scope:** consequences for running people over (heat, police), destructible traffic, pedestrians as shooting targets, shop upgrades other than guns (body parts, dashboard items, perks), traffic lights / intersection rules.

## Phase tasks covered
- [[Phase 09 - Economy, Shop & Upgrades]] → gun shop (as a place in the world), weapon prices, ammo.
- [[Phase 07 - Passenger Archetypes & Ride Events]] / [[Phase 12 - Content, Balancing & Release]] → 4 new passengers.
- [[Phase 02 - City Graybox & Navigation]] → traffic + pedestrians (deferred there in D-022).

## Checklist
- [x] `WeaponData.slot / blurb / price / ammo_price`; rifle; start with the revolver; `WeaponController.add_weapon / refill_ammo / catalogue / index_of_slot`
- [x] `WeaponBar` hotbar in the HUD
- [x] `gunshop` map piece (editor tool, geometry, validation warning), `GunShop` pad, `GunShopUI` screen; two shops in the built-in city
- [x] `StreetLife` + `Pedestrian` + `TrafficCar` / `TrafficAI`
- [x] 4 passengers: Dog in a Suit, Night-Shift Nurse, Man From the Future (level 2+), Street Musician
- [x] Tests: new `shop_autotest`, `streetlife_autotest`; weapon test owns all four guns; all others PASS (see Result)
- [x] Build exported (0.10.0)
- [ ] User playtest

## Acceptance (how the user will judge it)
- [ ] The city feels alive: people on the sidewalks, cars on the road, and they react to me.
- [ ] The new passengers are fun and different from the old ones.
- [ ] The gun shop is easy to find and use; the prices feel right.
- [ ] I can tell at a glance which gun I have, which I own, and how much ammo is left.

## User test checklist
1. [ ] **Hotbar** (bottom-left): 4 cards with gun shapes. The one in your hand is raised with a yellow frame; locked ones show the price. Keys 1-4 / wheel / Y switch, and the name pops when you switch. Is it clear enough? Too big / too small?
2. [ ] **Gun shop** — on the built-in city there are two (green awning + pistol sign on the roof, green pad in front). **Your map `TEST1` has none:** add one in the editor (left panel → *Gun shop*, drag a 3x3+ rectangle, R to face the street) — the bottom line now warns when a map has no gun shop. Stop on the pad → the shop opens. Buy, refill, LEAVE (Esc / B). Prices: SMG $180, Sawed-off $260, Rifle $380, ammo $15-40.
3. [ ] **Rifle**: 75 damage, pin-point when aimed, slow. Fun?
4. [ ] **Pedestrians**: they walk around blocks; drive at one fast and they jump aside; fire a shot and everyone nearby runs; you *can* run them over (they fly, then lie there). Nothing happens to you for it yet — should it (heat / police / a fine)?
5. [ ] **Traffic**: cars drive the streets on the right, slow down behind each other and you, stop for a few seconds when hit. Too many / too few (8 around you)? Do they get in the way in a bad way?
6. [ ] **New passengers** (F8 cycles all archetypes): Dog in a Suit (examine the collar), Night-Shift Nurse (examine the bag → she patches you up), Man From the Future (from level 2; predicts the ambush), Street Musician (examine the guitar case: gang cars or keep the cash).
7. [ ] Frame rate with the new street life on a real GPU.

## Feedback from user
- ...

## Discovered / Deferred
- Running people over has no consequence yet (only a "Pedestrians hit" stat in the pause menu) → KI-030.
- Traffic cars cannot be destroyed; bullets only shove them → KI-030.
- `enemy_city_autotest` fails about 1 run in 4 — also on the code from before this iteration (checked on a clean worktree of the last commit) → KI-029.
- The windowed `editor_switch_autotest` passed 2 of 5 runs (fails at "click the same cell to select"); editor input was not changed this iteration and the test is documented as sensitive to the real mouse → inconclusive, re-run with the mouse out of the window.
- The user's `TEST1` map has no gun shop (not edited: the user's maps are theirs).

## Result summary (fill when done)
Built & auto-verified 2026-11-15: shop (new), streetlife (new: 28 pedestrians, 8 cars, all cars driving ~250 m / 30 s, right lane ~95 %, everyone in range flees gunfire, dodge + knock-down), weapon, tutorial, ride, dossier, events, map, hostiles, enemy, pickup, jump, curb, vehicle PASS; profiles OK (15); enemy-city flaky (pre-existing); editor-switch inconclusive. Screenshots of the shop, the hotbar and a street checked. Build 0.10.0 exported and smoke-tested headless (built-in city, `TEST1`).
