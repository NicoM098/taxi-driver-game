---
tags: [plan, phase]
phase: 8
status: not-started
---
# Phase 08 — Items & Inventory

**Goal:** passengers (and enemies) drop items; the player holds a small inventory of consumables and passive charms.
**Depends on:** [[Phase 07 - Passenger Archetypes & Ride Events]]
**Design refs:** [[Economy & Upgrades]] §3, [[Passengers & Encounters]]

## Tasks
- [ ] `ItemData` resource: id, name, icon, description, `type` (consumable / passive), `stat_modifiers: Array[StatModifier]`, `use_effect` (resource/callable id), `stack_max`.
- [ ] `StatModifier` resource: stat id, add/mult, value. Used by items, perks, upgrades (shared with Phase 09).
- [ ] `PlayerStats` autoload: `get_stat(id)` = base + modifiers from items/perks/upgrades; `stats_changed` signal.
- [ ] Inventory in `GameState` (consumable slots, e.g. 3; passive charms list).
- [ ] Loot tables (`LootTable` resource: weighted items); `DropItemEvent` uses it.
- [ ] Pickup: item appears on the passenger seat / handed over with a popup; auto-added.
- [ ] Use consumable hotkey (e.g. Z/X/C); effects: repair kit, med kit, smoke screen, ammo box, nitro can.
- [ ] Passive examples: lucky charm (+tips), rosary (old lady; less damage), lockpick (unlock "examine bag" on everyone).
- [ ] HUD inventory strip.

## Definition of done
- Old lady drops an item; using it has a visible effect; passive items change stats via `PlayerStats`.

## User test checklist
- [ ] Item pickups noticeable? Inventory readable?

## Notes
- 2026-11-11 (Iteration 05): first world pickup built ahead of this phase — "Monstrous Energy" heal can (`src/items/energy_drink_pickup.gd`, D-042). Carried consumables should reuse its heal path (`TaxiDamage.drink`).
