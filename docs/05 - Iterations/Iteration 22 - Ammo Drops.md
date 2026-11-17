---
tags: [iteration]
iteration: 22
status: active
started: 2026-11-17
finished:
---
# Iteration 22 — Ammo Drops

Same branch and session as [[Iteration 21 - Endless Weapon Upgrades]] (`feat/no-papers`). Decision: D-094.

## Scope (from user, verbatim)
> "i want to change the ammo system, i want ammo to be dropped by eneemies instead of you buying.
> ammo drops for a specific weapon. make it similar to the monstrous energy, like a floating thing.
> also i would like to add a circle below it as well as the mosnstrous"

## What was built
- **Ammo is no longer sold.** The shop menu's gun card shows OWNED instead of AMMO $x; the old
  in-city gun shop lost its REFILL button; `WeaponData.ammo_price` is gone. Upgrades no longer
  refill either: the rounds you carry stay, an Ammo level (or the SMG's drum) adds its new spare room.
  Buying a gun still comes with a full load.
- **Every destroyed enemy drops an ammo box** (`AmmoPickup`, `src/items/ammo_pickup.gd`) on the road
  where it died: a floating, spinning olive ammo crate with brass rounds on top and a stripe in
  the gun's colour, the gun's name over it ("SMG AMMO"), a coloured light and a **glowing circle**
  on the ground. Drive through it to take the rounds.
  - **For one gun:** picked from the equipped guns at random, weighted to the emptiest (an empty
    gun gets most boxes; a full one still gets ~8 % weight).
  - **Size:** 30 % of that gun's (upgraded) reserve, at least one magazine. Capped at the reserve max.
  - **Bosses drop more:** 1 box + 1 per 400 base HP, at most 5 (gang cars 1, bosses 2-5), in a ring.
  - A box for a full gun **stays** until you have room; untouched boxes go after **30 s**
    (blinking the last 6).
  - Colours by hotbar slot: revolver yellow, SMG cyan, sawed-off orange, rifle green, mines red,
    minigun violet, rocket pink, laser teal.
- **The Monstrous Energy can got the same glowing circle** (cyan) under it (`PickupRing`,
  `src/items/pickup_ring.gd`, shared).
- New signal `EventBus.ammo_picked_up(weapon_id, rounds)`; plays the pickup sound, HUD "+36 SMG AMMO".

## Files
New `src/items/{ammo_pickup,pickup_ring}.gd`, `tests/ammo_drop_autotest.{gd,tscn}`. Changed
`src/enemies/enemy_car.gd` (drop on death), `src/items/energy_drink_pickup.gd` (ring),
`src/combat/weapon_controller.gd` (no `refill_ammo`, upgrades keep ammo), `src/ui/shop/gun_shop_ui.gd`,
`src/shop_menu/shop_menu.gd`, `src/core/resources/weapon_data.gd`, `data/weapons/*.tres`,
`src/autoload/{event_bus,audio}.gd`; tests `shop`, `shop_menu`, `upgrades`, `arsenal` (its twin-rocket
shot relied on the upgrade reloading the one-round tube; it now loads it by hand).

## Checklist
- [x] No ammo for sale; upgrades do not refill
- [x] Enemies drop per-gun ammo boxes (bosses several)
- [x] Floating box + glowing ground circle; the can has the circle too
- [x] `ammo_drop_autotest` (new) + shop / shop_menu / upgrades updated
- [x] Screenshots (720p): boxes and labels read; circles thickened after the first look
- [ ] **User playtest**

## What to test (user)
1. Do you run dry? Ramming still kills, and every kill drops a box, but a long boss fight on an
   empty gun could hurt. Knob: `AmmoPickup.RESERVE_SHARE` (0.3).
2. Are the boxes easy to see and to reach in traffic? (30 s lifetime: `LIFETIME`.)
3. Does the weighting feel right: the gun you are emptying gets most of the boxes?

## Discovered / Deferred
- Passenger "ammo" gifts (`RewardEvent`) still top up every equipped gun; left as is.
- If every equipped gun is full, the box still drops (for a random gun) and waits on the road.

## Playtest feedback
_(pending)_
