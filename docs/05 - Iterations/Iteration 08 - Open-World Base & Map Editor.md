---
tags: [iteration]
iteration: 8
status: playtested-additions-awaiting-retest
started: 2026-11-12
finished:
---
# Iteration 08 — Open-World Base: Map Editor & Repair Shops

## Scope (from user, verbatim)
> then we will build the bases for an open world map, then we will add different neighborhoods that will have different storylines and people inside. We will also have shops to upgrade stuff with our money, armory, bodyparts, items for the dashboard, perks, etc

> i want a map editor, different building sizes and shapes, plazas, low stairs, ramps and such. Wreck makes the car work like shit until you go to the repair shop

## Interpretation
- **The map is data, made in an in-game map editor** (Claude's call, D-055: "map editor" = a tool inside the game, not Godot scenes). Grid of 8 m cells; everything not covered by a solid piece is road.
- **Piece kit:** buildings in any footprint / height with 6 shapes, plazas (stepped all round or sheer platforms), low stairs, ramps (jump kicker / solid wedge), sidewalks, containers, pillars, taxi stops, energy drinks, repair shops, player start, **neighbourhood zones** (the hook for the next iteration: a zone id = the district of the stops inside).
- **Wreck = limp mode** until a **repair shop** (D-056).
**Out of scope:** neighbourhood content / storylines / people, shops with upgrades (next iterations), map streaming for very large maps, traffic, decoration props.

## Checklist
- [x] `MapData` (JSON in `data/maps/`, validation, built-in starter city generator)
- [x] `MapBuilder` (all pieces + shapes; smooth collision under stairs / stepped plazas)
- [x] `City` builds from a map: ground / walls sized to the map, automatic lane dashes, cell-based road graph for the AI, stop names per zone, player start
- [x] `RepairShop` + limp mode (`Taxi.limp`), arrow / beacon to the nearest shop, fare bails out, pursuers leave
- [x] Map editor scene (`src/editor/map_editor.tscn`): tools, properties, move, undo / redo, save / load, resize, starter city, validation, PLAY; **M** in the game opens it (was F9)
- [x] `tests/map_autotest` PASS; every older test PASS on the new city
- [x] User playtest (2026-11-13: editor and own map work)
- [x] Playtest fixes / additions built & auto-verified (D-057, D-058, D-059)
- [x] "Sidewalks are damaging the car" fixed & auto-verified (D-060)
- [ ] User re-test

## Acceptance (how the user will judge it)
- [ ] I can build a small district of my own and drive it within a few minutes.
- [ ] The pieces are enough to make interesting places (sizes, shapes, plazas, stairs, ramps).
- [ ] A wrecked car feels bad enough to want the repair shop, without being unplayable.

## User test checklist
**Editor** — in the game press **M** (or run `src/editor/map_editor.tscn` with F6 in Godot).
1. [ ] It opens on the starter city. Wheel = zoom, WASD or right-drag = pan, **T** = top-down / tilted.
2. [ ] Left panel → **Building**, drag a rectangle on empty ground. Right panel: try every **Shape** (box, tower, stepped, l_shape, round, house), **Material**, **Height** (`[` `]`), **R** to rotate.
3. [ ] **Plaza / platform**: shape *steps* (stairs all round) and *flat* (sheer). **Low stairs** and **Ramp** (*kicker* = jump, *wedge* = solid) against a flat platform.
4. [ ] **Select / move**: click a piece, change it in the right panel, drag it, **Del**, **Ctrl+Z / Ctrl+Y**, Duplicate (Ctrl+D).
5. [ ] **Taxi stop** on a street cell next to a sidewalk (R = which side the passenger stands), **Repair shop**, **Player start**, a **Neighbourhood zone** with your own id + name.
6. [ ] The bottom line tells you what is missing (stops, repair shop...). Type a map name → **Save**. **New empty** with another size (up to 160 x 160 cells = 1280 m).
7. [ ] **PLAY THIS MAP (P)** → you drive your map. M → back to the editor. Do passengers appear and rides work? Do hitmen (F7) find their way around your buildings?
8. [ ] In the game: drive up a stepped plaza, up low stairs, over a kicker ramp. Bumpy? Stuck anywhere?
**Wreck** (crash a lot, or let F7 hitmen finish you):
9. [ ] "WRECKED! Limp to a repair shop": top speed ~30 km/h, the engine cuts out, the steering wanders, no boost; the arrow and a red beacon lead to the nearest garage; passengers will not board; the hitmen leave.
10. [ ] Stop on the yellow pad → repaired for $60 (or all you have if less). With a damaged but not wrecked taxi the pad repairs for a smaller fee. Too punishing / too mild? Price?

## Feedback from user
- **2026-11-12 (verbatim):** "Cannot call method 'set_input_as_handled' on a null value" → F9 (game) and F5 (editor) changed scene and then called `get_viewport()` on a node already out of the tree. Fixed: mark the input handled first, then change scene.
- **2026-11-12 (verbatim):** "nothing works on the editor, i cant click anything nor move" → Claude's reading: the error above stopped the game in Godot's debugger, so the editor that had just opened was frozen. Not reproducible after the fix: new `tests/editor_switch_autotest` (windowed, real input events) PASS both through F9 and opening the editor directly — pan, wheel, tool button, place, select, Del, F5. Wrong reading, see next.
- **2026-11-12 (verbatim):** "is still frozen, nothing on the debugg" → Claude's diagnosis (not reproducible outside Godot's editor): F9 is the *Suspend* shortcut of Godot's embedded game view, so the same key press opened the map editor and suspended the game. Keys changed: **M** opens the editor from the game, **P** (or the button; F5 still bound) plays the map. Awaiting retry.
- **2026-11-13 playtest (verbatim):** "i created a map and played it for a while, it works. the enemies can appear inside the buildings with no way out. Also we need more hostiles situations. And then i want the ramps to be able to get me to jump above the containers"
  - Editor + own map work (map `test1`: 50 x 50, 266 pieces, 13 stops, 3 repair shops, courtyards, ramps in front of containers). Checklist items 1-7 taken as passed; nothing said about stairs / plazas (8) or the wreck (9-10).
  - Enemies walled in → D-057. Ramps over containers → D-058. More hostile situations → D-059 (Claude chose what: street encounters, 2 enemy types, 3 passengers).
- **2026-11-13, later (verbatim):** "i think the sidewalks are damaging the car" → reproduced only after a landing / hard bump: the chassis box dropped under curb height and hit the slab side (dead stop, big crash value). Chassis box raised, D-060. Where / how it happened in play was not said.

## Re-test checklist (after the 2026-11-13 changes)
1. [ ] Your map: enemies (F7, or just play) never show up inside the walled courtyards any more.
2. [ ] Your ramps in front of containers: with a few cells of run-up you fly over. They are now 3 m high and the containers one level (your file is untouched until you save it in the editor). Stacks you set to 2-3 levels are not meant to be jumpable.
3. [ ] Drive around with no fare for a couple of minutes: a street encounter starts (red message). **H** forces the next one: gang drive-by, cash robbery crew, payback, roadblock, turf war. Too often / too rare? Too hard?
4. [ ] New enemies: dark **Bruiser** (no gun, rams hard, tough) and green **Street Gang** coupe (fast, fragile, shoots a lot). Fair? Does the bruiser pin you against walls?
5. [ ] New passengers (F8 cycles): **Bank Robber** (police), **Key Witness** (bruisers ahead, hitmen behind), **Gang Courier** (gang cars at once). Read their files: are the choices interesting?
6. [ ] Is this what you meant by "more hostile situations", or did you mean something else (enemies on foot, roaming gangs, passengers attacking...)?
7. [ ] Sidewalks: drive over them, land jumps next to them, clip building corners' curbs. No more damage or sudden stops from a curb? If it still happens: where, how fast, after a jump or not.

## Discovered / Deferred
- Very large maps are built whole (no streaming): fine up to the 160 x 160 limit as far as tested headless, real frame rate untested → KI-023.
- AI cars treat stairs / ramps / stepped plazas as normal ground (higher cost only) → may get stuck on steep ones → KI-024.
- No lane dashes on streets that are not exactly 2 cells wide; no decoration props, trees, lamps, traffic.
- The summary screen (rides, cash, kills) is no longer shown anywhere (it was the end-of-shift screen) → needs a new home (pause menu / garage).
- The old `tests/view_shots` camera positions still work but frame different buildings.

## Result summary (fill when done)
Built & auto-verified 2026-11-12: `map_autotest` PASS (built-in city valid, save / load identical, 152 piece variants build, route goes round a building wall through the gap, sheer platform solid / stepped plaza drivable, stop districts + names from zones, taxi rests on plaza 0.80 m / platform 2.00 m / stairs, editor place / edit / undo / redo / delete / save). All 18 older test runs PASS on the map-built city; editor + city screenshots checked. Pending user playtest.
