---
tags: [iteration]
iteration: 23
status: active
started: 2026-11-17
finished:
---
# Iteration 23 — Dev Notes

Same branch as [[Iteration 22 - Ammo Drops]] (`feat/no-papers`), pushed after `7084e03` (not played yet). Decisions: D-098 to D-103.

## Scope (from user)
> "i added a personal note taking md file named dev notes, read trough and implement the features as written"

The note is `Dev Notes.md` in the old vault (`Documents/Godot proyects/TaxiDriver/Crazytaxi/`), verbatim:
> Mines: Different path upgrade. No reloads and only max ammo, make it make sense.
>
> Besides the car upgrade and the armory i want a perks shop, where you can buy perks, like double tap, faster reload speed,  picking up passengers without stopping (just like when you drop them that you have the circle around them)
>
> sacar la vida propia y de auto, tener solo una sola barra de vida.
>
> agregar mecanica para poder disparar para atras?
>
> añadir marker para los bosses que sean mas claros.
>
> pedestrians dissapear and appear

## What was built
- **One health bar (D-098).** The driver and the cab share one bar, "HP", of 130 (1.3x the old
  cab bar; Armor still raises it). Shots through the windows take 45 % off it (Bulletproof Glass
  cuts that), body shots and crashes as before. A Monstrous Energy can heals 50 (XL 67.5).
  `TaxiDamage.single_bar = false` brings the two bars back.
- **Mines, their own path (D-099).** No reloading: you carry one stack of 8 mines, refilled by
  ammo boxes (3 a box). Upgrades: **Capacity** (+2 mines, 4 levels), **Damage** (endless),
  **Blast** (+15 % radius, 3 levels), **Drop rate** (endless). Heavy charge after 8 upgrades.
- **Perks shop (D-100).** A new **PERKS** tab in the shop (Tab):
  - **Double Tap** — +25 % fire rate on every gun, 2 levels ($1200, $3000). Goes past the fire-rate cap.
  - **Quick Hands** — −20 % reload time on every gun, 3 levels ($600, $1400, $2800).
  - **Rolling Pickup** — $1500: a yellow ring on the road at every waiting fare; drive through it
    at any speed and they are in. Like the drop-off ring.
- **Shooting backwards (D-101).** Hold **C** (pad: R3) to look out the back: the mouse / right
  stick now aim around the rear window and the gun comes up; fire as usual. Let go to face forward.
- **Boss markers (D-102).** Bosses: a big gold cone, a gold beam into the sky, and a "BOSS / name"
  tag that shows through buildings. The edge-of-screen arrow is gold, bigger, says "BOSS 85m" at
  any distance; the minimap shows a gold "B", kept on the edge when far.
- **Pedestrians popping (D-103).** Nothing spawns or disappears while it is on screen any more,
  at any distance (pedestrians and traffic). Knocked-down people sink into the ground instead of
  vanishing.

## Files
New: `data/car_upgrades/perk_{double_tap,fast_reload,rolling_pickup}.tres`, `tests/dev_notes_autotest.{gd,tscn}`.
Changed: `src/vehicle/taxi_damage.gd`, `src/ui/hud/status_bars.gd`, `src/shop_menu/{shop_menu,car_upgrades,car_upgrade_data}.gd`,
`src/world/repair_shop.gd`, `data/car_upgrades/glass.tres`, `src/core/resources/weapon_data.gd`,
`src/combat/{weapon_upgrades,weapon_controller}.gd`, `data/weapons/mines.tres`, `src/items/ammo_pickup.gd`,
`src/events/reward_event.gd`, `src/ui/hud/weapon_bar.gd`, `src/ui/shop/gun_shop_ui.gd`,
`src/passengers/waiting_passenger.gd`, `src/ride/ride_manager.gd`, `src/camera/cab_camera.gd`,
`src/ui/menu/main_menu.gd`, `src/enemies/{hostile_marker,enemy_car}.gd`, `src/ui/hud/{threat_markers,minimap}.gd`,
`src/world/{street_life,pedestrian}.gd`; tests `shop_menu` (PERKS tab in the Q / E cycle, repair from a full bar),
`escalation` (a second boss screenshot from 50 m).

## Checklist
- [x] One health bar
- [x] Mines: Capacity / Damage / Blast / Drop rate, no reloads
- [x] Perks tab: Double Tap, Quick Hands, Rolling Pickup
- [x] Look back aims and shoots
- [x] Boss marker, edge arrow, minimap blip
- [x] Pedestrians / traffic never spawn or vanish on screen
- [x] `dev_notes_autotest` (new, 30 checks) + the suite
- [x] Screenshots: PERKS tab, a boss near and at 50 m
- [ ] **User playtest**

## What to test (user)
1. **One bar:** does 130 feel right? Too tanky / too fragile → `TaxiDamage.SINGLE_BAR_HP_MULT`.
2. **Mines:** is 8 to start (+2 a Capacity level) enough with boxes refilling 3? `data/weapons/mines.tres` `mag_size`.
3. **Perks:** prices and strength. Rolling Pickup: is the 6 m ring easy to hit at speed?
4. **Shooting back:** hold C while driving and shoot a chaser. Is 65° each way enough?
5. **Bosses:** can you always tell where the boss is now?
6. **Pedestrians:** any popping left? (Fewer people far down a long straight street is expected.)

## Discovered / Deferred
- The rear-view mirror is not checked by StreetLife: something could still appear in the mirror,
  behind you at 35+ m.
- More perk ideas fit the same data format (e.g. faster nitro refill, bigger ammo boxes): a new
  `.tres` with `section = &"perks"` plus its effect in code.

## Playtest feedback
- **"the boss, more specifically the precinct captain, is teleporting all the time"** → D-104:
  enemies are only ever moved (corner rescue, outrun recall) while off screen, at most every 5 s,
  to a street you are not looking at; every move is logged (`[Director] moved ...`). Not
  reproduced headless, so this needs another look in play.
- **"when i press c to look behind i only see the seats, it should be like you are coming out of the window"** → D-105: holding C leans the head out of the driver's window, facing back along the cab; the dashboard arrow hides meanwhile.
