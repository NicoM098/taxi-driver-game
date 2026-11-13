---
tags: [plan]
---
# Development Plan

Systems in **implementation order**. Each phase builds on the previous ones and ends with something **playable/testable**. Iterations (user-scoped, in `05 - Iterations/`) pull tasks from these phases.

Legend: ⬜ not started · 🟨 in progress · ✅ done

| # | Phase | Goal (playable result) | Depends on | Status |
|---|---|---|---|---|
| 00 | [[Phase 00 - Project Setup]] | Folder structure, input map, layers, autoload stubs, main scene boots | — | ✅ |
| 01 | [[Phase 01 - Taxi Driving & Cab Camera]] | Drive an arcade taxi in first person on a test plane | 00 | ✅ |
| 02 | [[Phase 02 - City Graybox & Navigation]] | Drive around a blockout city with zones and a destination arrow | 01 | ✅ (navmesh/GPS → Phase 06, traffic later) |
| 03 | [[Phase 03 - Core Ride Loop]] | Passenger enters → drive to destination → get paid ~~; shift timer~~ (shift clock removed 2026-11-12, D-051) | 02 | ✅ |
| 04 | [[Phase 04 - Dossier & Decisions]] | File opens on entry; drive / kick / examine / kill actions work | 03 | ✅ |
| 05 | [[Phase 05 - Shooting From the Cab]] | Raise a gun, aim freely and shoot while driving | 01 | ✅ |
| 06 | [[Phase 06 - Damage & Enemy Pursuers]] | Hitmen cars chase, ram and shoot; you can destroy them | 05 | ✅ |
| 07 | [[Phase 07 - Passenger Archetypes & Ride Events]] | Old lady, businessman, burglar + others with real consequences | 04, 06 | ✅ closed 2026-11-12 (playtest fixes D-051…D-054 auto-verified only; screen effects, courier, item drops deferred) |
| 08 | [[Phase 08 - Items & Inventory]] | Passengers drop items; use/passive effects | 07 | 🟨 started early (energy drink pickup) |
| 09 | [[Phase 09 - Economy, Shop & Upgrades]] | Garage between shifts: buy guns, perks, upgrades | 05, 08 | ⬜ |
| 10 | [[Phase 10 - Game Flow, UI & Save]] | Menus, shift summary, pause, settings, save/load | 09 | ⬜ |
| 11 | [[Phase 11 - Audio, VFX & Juice]] | It sounds and feels great | 10 | ⬜ |
| 12 | [[Phase 12 - Content, Balancing & Release]] | More passengers, tuning, export build | 11 | ⬜ |

## Why this order
1. **Driving first** — it's what you do 90% of the time; everything else sits on the taxi and the camera.
2. **City + navigation** before rides — rides need destinations.
3. **Ride loop before dossier** — get the Crazy Taxi skeleton fun, then add the Papers, Please layer on top.
4. **Shooting (05) only depends on driving** — can be pulled earlier into an iteration if desired.
5. **Enemies** need shooting + damage. **Archetypes** need both dossier and enemies to deliver their twists.
6. **Items → Economy → Flow** — the meta loop comes after the core loop is fun.
7. **Polish & content** last, but small juice can be added anytime.

## Milestones
- **M1 "It drives"** — end of Phase 01–02.
- **M2 "Crazy Taxi skeleton"** — end of Phase 03.
- **M3 "Papers, please, driver"** — end of Phase 04.
- **M4 "Guns out"** — end of Phase 05–06.
- **M5 "Vertical slice"** — end of Phase 07 (3 archetypes, full ride loop with combat). ← first build worth showing
- **M6 "Full loop"** — end of Phase 10.
- **M7 "Release candidate"** — end of Phase 12.

## Direction change — 2026-11-12 (user)
The shift timer is gone ("was never part of the game", D-051). The game becomes an **open world**. Order given by the user:
1. **Open-world map base** — [[Iteration 08 - Open-World Base & Map Editor]]: in-game map editor + piece kit + repair shops (built 2026-11-12, awaiting playtest).
2. **Neighbourhoods** — each with its own storylines and its own people.
3. **Shops** — spend money on upgrades: **armory, body parts, items for the dashboard, perks**, etc.

How this maps onto the phases (to be re-planned when Iteration 08 is scoped — do not treat the table above as fixed any more):
- Phase 02 (city) gets a successor: the open-world map + neighbourhood data.
- Phase 07/12 content (passengers) becomes per-neighbourhood people and storylines.
- Phase 09 (shop) changes from a "garage between shifts" to **shops in the world**; Phase 08 items feed "items for the dashboard".
- Phase 10 "endless shifts" task is obsolete; save/load must cover the open world (position, story progress, owned upgrades).
