---
tags: [iteration]
iteration: 15
status: closed
started: 2026-11-16
finished: 2026-11-16
---
# Iteration 15 — Minimap

## Scope (from user, verbatim)
> "un minimapa. Tipo que te marque los enemigos, la policía, los pedestrians que podes recoger, el
> taller, gunshop etc. Estilo como todos los juegos de mundo abierto como GTA y demás... **se
> debería adaptar a cualquier mapa no solo a este**"
>
> Decisions, asked and answered: **rotates with the car**, **square**, **shows only a radius around
> the player**, **flat** (no levels).

## The approach, and why not a camera
The user's own instinct was a second top-down camera with a filter, and worried it would cost too
much. It would — the city is 335 pieces, 311 lamps, traffic and pedestrians, and a second
`Camera3D` renders all of it again every frame. But the real argument is different: **a top-down
render does not give what a minimap needs.** At 150 px across, buildings are smudges and a repair
shop is indistinguishable from a gun shop, so markers have to be drawn on top anyway — and once
they are, the 3D pass is only providing a background.

**That background already exists as data.** `MapData.flags()` returns one byte per cell with
`F_SOLID` and `F_COVERED`, which is literally a bitmap of the map:

| Cell | Means | Minimap |
|---|---|---|
| 0 | plain street | dark (drivable) |
| `F_COVERED` | sidewalk, plaza, ramp, stairs | mid |
| `F_SOLID` | building, wall | light |

So the minimap is drawn from the same data the world is built from, which is exactly **why it
works on any map, including one the user makes in the editor** — no special casing, nothing to
keep in sync.

**Resolution: one pixel per cell, scaled up with nearest filtering.** A cell is 8 m, so the map is
blocky — which is the point: it matches the PS1 look and it keeps the bake trivial (2,500 pixels
for the starter city, 25,600 for the largest map the editor allows). Supersampling the bake was
considered and rejected: it would multiply the bake cost by 16 to get a smoothness the game's own
art does not have.

## Design
1. **Bake** (once, when a `City` finishes building): walk `flags()` into an `Image`, keep it as an
   `ImageTexture` with nearest filtering. Rebuilt automatically whenever a map loads, so the
   editor's "PLAY THIS MAP" is covered for free.
2. **Draw** (`src/ui/hud/minimap.gd`, a `Control` the HUD owns): a square with `clip_contents`,
   the baked texture drawn under a transform that puts the taxi at the centre and its heading up.
   Because it rotates inside a square, the region sampled has to reach the **half-diagonal**, or
   the corners come up empty at 45°.
3. **Blips** (per frame, from registries that already exist):

| Blip | Source | Note |
|---|---|---|
| Enemies / police | `EnemyDirector.enemies` | police told apart by their `EnemyCarData`, as the gunfire does (D-080) |
| Waiting passengers | `City.stops` where `occupied` | the fare you can pick up |
| Ride destination | `RideManager.ride` | the one blip worth clamping to the edge when off-map |
| Repair shops | `City.repair_shops` | already a registry |
| Gun shops | `City.gun_shops` | already a registry |
| The player | fixed arrow at the centre | the map rotates, not the arrow |

4. **Flat**, as decided: a raised plaza is just another covered cell. No height, no levels.

## Known risks (named before starting)
- **Rotating a nearest-filtered bitmap shimmers** at block edges while turning. It is honest to the
  look, but it is the thing most likely to feel wrong in motion, and the first thing to show the
  user.
- **Bake cost on a 160 × 160 map**: 25,600 `Image.set_pixel` calls in GDScript. Should be a few ms
  once per map load; if it is not, the fallback is building the `PackedByteArray` in one pass and
  using `Image.create_from_data`.
- **Blip clutter**: enemies, stops, two kinds of shop and a destination can crowd a small square.
  Radius culling plus a cap per category if needed.
- The minimap must not draw over the dossier or the menus — it belongs to the HUD's visibility.

## Checklist
- [x] `MinimapBake`: `flags()` → `ImageTexture`, rebuilt on map load, nearest filtering
- [x] `src/ui/hud/minimap.gd`: square, clipped, rotating with the taxi, radius around the player
- [x] Blips for enemies / police, waiting passengers, ride destination, repair shops, gun shops
- [x] Fixed player arrow at the centre
- [x] Destination clamped to the edge when it is outside the radius
- [x] Hidden with the rest of the HUD when the file or a menu is open
- [x] `tests/minimap_autotest`: the bake matches the flags grid, and world → minimap coordinates
      land where they should (including on a non-square map, so width/depth cannot be swapped)
- [x] Screenshot through `ui_shots`

## Acceptance (how the user will judge it)
- [ ] You can navigate by it without looking at the arrow
- [ ] Enemies and police read instantly as danger
- [ ] You can find a gun shop or a repair shop by it
- [ ] Rotating while turning does not feel sickening or noisy
- [ ] It works on a map made in the editor, not just the built-in city

## User test checklist
- [ ] Drive a lap: is the orientation readable, or does the rotation confuse you?
- [ ] Get chased: do you spot the hostiles on it before you see them out the window?
- [ ] Make a map in the editor and play it: does the minimap match it?
- [ ] Is the size right, and is it in the right corner?
- [ ] Does anything flicker while turning?

## Feedback from user
- 2026-11-16 (DLain47): "i dont see the markers for the repair shops or the gun shops nor the ride
  destination". **Shops: a bug.** `RepairShop` / `GunShop` nodes stay at the world origin and build
  their geometry in world space, so `global_position` put all six shops at (0, 0, 0) and usually
  culled them. Now drawn at `pad_position` (`Minimap.shop_points`), with a regression check in
  `minimap_autotest` (part 3). **Destination: drawn, but unreadable.** It was a 4 px dot in the
  player arrow's yellow. Now a pulsing green diamond with a white outline (green like the
  dashboard arrow and the beacon); shops are outlined squares. Verified with a windowed screenshot
  on `TEST1`. Not yet re-checked by the user.
- 2026-11-16 (DLain47): "i want the markers to be more noticeable on the minimap, quite big".
  Every marker roughly doubled and outlined in black: shops 18 px squares with a letter (**R**
  repair, **G** gun shop), destination a 22 px pulsing diamond, fares 10 px and enemies 12 px dots,
  player arrow 18 px. Sizes are constants at the top of `minimap.gd` (`SHOP_HALF`,
  `DESTINATION_RADIUS`, `blip_radius`). Checked with a screenshot.
- 2026-11-16 (DLain47): "esa parte está correcta y aprobada" — minimap markers (and the shop
  rings / beams / E, D-084) approved. **Iteration closed.**

## Discovered / Deferred
- **The rotation maths needed no correction factor**: the taxi's forward is -Z, which is already
  "up" on a texture whose +Y is world +Z, so rotating the offset by the yaw is the whole of it.
  Verified at three yaws rather than assumed.
- **The test caught itself being wrong first**: `Color.is_equal_approx` cannot survive a round trip
  through an RGBA8 texture (1/255 quantisation). Compared with a 0.01 tolerance now.
- The minimap is in the HUD, so it inherits the HUD's visibility with the file and the menus — no
  extra wiring was needed.
- Deferred: a map preview in the editor from the same bake (it has none today), fog of war,
  zoom levels, street names.

## Result summary
A minimap that costs one textured quad and a handful of circles per frame, because it is drawn from
`MapData.flags()` rather than from a second render of the city. Square, rotating with the car, a
radius around the player, flat. Blips for enemies and police, waiting fares, repair shops, gun shops
and the ride destination (clamped to the border when out of range), all from registries that already
existed.

18 autotests pass, the 18th being new. Not judged in motion yet — whether the rotating blocks read
or shimmer is the open question.
