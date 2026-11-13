---
tags: [plan, phase]
phase: 2
status: done
---
# Phase 02 — City Graybox & Navigation

**Goal:** a small, dense blockout city to drive around, with pickup and drop-off zones and a HUD arrow pointing to the destination.
**Depends on:** [[Phase 01 - Taxi Driving & Cab Camera]]
**Design refs:** [[Game Design Document]] §9

## Tasks
### City (`src/world/`)
- [x] Blockout city using CSG or `GridMap` (modular road/building tiles). ~6×6 blocks to start, with a few jumps/shortcuts.
- [x] 3 districts tagged (Downtown, Suburbs, Docks) via `Area3D` regions or metadata (`district: StringName`).
- [x] Static collisions on layer `world`.
- [x] `DropOffZone` scene: `Area3D` + visible beacon/pillar of light; has `zone_id`, `district`, `tags`.
- [x] `PickupZone` / pickup spots (curb markers) where passengers can appear.
- [x] `ZoneRegistry` (node in World or autoload): lists zones, query by tag/district, random pick.

### Navigation
- [ ] ➡️ deferred to Phase 06 (D-022): `NavigationRegion3D` baked on roads (needed for enemy AI in Phase 06 and for GPS path).
- [x] HUD destination arrow (3D arrow above dashboard or 2D compass) pointing toward the target; distance readout.
- [ ] ➡️ deferred (D-022): (Optional) GPS line using `NavigationServer3D.map_get_path`.

### Traffic (basic, optional in this phase)
- [ ] ➡️ deferred (D-022): Simple traffic cars following path loops (`Path3D` + `PathFollow3D`), collide-able. Full AI not needed.

### Environment
- [x] WorldEnvironment: sky, fog for distance, sun. Day lighting first.

## Definition of done
- Drive from any district to any zone; arrow always points correctly; navmesh covers all roads.
- Stable 60 FPS while driving across the city.

## User test checklist
- [ ] City size feels right (not too big/empty)?
- [ ] Arrow readability.
- [ ] Shortcuts/jumps fun?

## Notes
- 2026-11-11 (Iteration 02): built procedurally in `src/world/city.gd` (`Blockout` helpers in `src/world/blockout.gd`). 8×8 blocks of 30 m, 16 m streets (city 384 m square), districts by column: 0-2 suburbs (houses), 3-5 downtown (towers), 6-7 docks (warehouses + containers). Plaza with kicker at block (4,3), 6 street ramps, lane dashes in one MultiMesh.
- Zones = 128 `TaxiStop`s (north + east side of every block), named per district (landmarks, then street addresses). Each stop: street arrival point + sidewalk point + hidden beacon pillar/ring. "ZoneRegistry" = `City.stops` + `get_district_at()`.
- Destination arrow = 3D `GuideArrow` on the dashboard (yellow → nearest passenger, green → destination); distance in the HUD.
- Navmesh/GPS/traffic deferred (D-022).
- 2026-11-11 playtest: arrow moved to classic top-centre compass (camera-attached, overlay shader) — D-028.
