---
tags: [iteration]
iteration: 09
status: closed
started: 2026-11-14
finished: 2026-11-14
---
# Iteration 09 — Texture Pass

## Scope (from user, verbatim)
> "me gustaría que el juego se mantenga con graficos y estetica como si fuera un juego viejo, estilo play 1 o low poly. Ejemplos como taxi driver, Driver, o ejemplos modernos como shift at midnight."
> "Vamos por texturas primero." · "Solo CC0" (on the base pack and on how to fill the window gap).

## Interpretation
The PS1 render pipeline already exists (D-010: snapping, affine, dither, fog, vertex lighting) and
`ps1_world.gdshader` already carries an `albedo_texture` uniform. What is missing is **surface
detail**: every building, road and sidewalk is a flat-colour primitive. This iteration makes the
world *read* as a city without modelling anything.

Two halves:
1. **Texture plumbing** so a CC0 pack drops onto the existing generated geometry without stretching.
2. **Procedural facade windows**, because the chosen CC0 pack has no window/facade textures and
   windows are what makes a block of boxes read as a city (see the Crazy Taxi / Driver references).

**Base pack (user's choice, CC0 only):** [PSX Textures Vol. 1 by Francisco Cidade](https://fcidade.itch.io/psx-textures-vol-1)
— CC0 1.0, 90 seamless textures × 5 looks (A Classic / B Flat / C Soft / D Murky / E Chunky),
already 32–128 px and 16–32 colours with ordered dither. One look folder is used for the whole game.

**OUT of scope:** 3D models of any kind (cars, props, people) — that is a later iteration. Lighting
and the night palette. Neighbourhood content. Changing the map editor or the piece kit. Any
non-CC0 asset. Re-testing Iteration 08 (still open, separate).

## Phase tasks covered
- [[Phase 00 - Project Setup]] → texture roadmap step 2 ("add textures where they help readability")
- [[Art Direction]] → texture roadmap steps 1→2

## Checklist
- [x] `ps1_world.gdshader`: single `base_uv` path so affine mapping works for every UV source
- [x] `ps1_world.gdshader`: `uv_mode` 1 = world-space planar UVs (scale-independent tiling)
- [x] `ps1_world.gdshader`: procedural window grid (cell size, glass fraction, ground-floor gap)
- [x] `ps1_world.gdshader`: random lit windows via hash + `EMISSION`
- [x] Building materials (`building_a/b/c`) switched to world UVs + windows
- [x] Road / sidewalk / container materials switched to world UVs, ready for textures
- [x] Texture slots documented so the user only has to drop the pack in `assets/textures/`
- [x] Screenshots before/after from `tests/view_shots.tscn`

## Textures wired (2026-11-14, DV-062)
Pack look in use: **A_classic** (64x64, 16 colours, ordered dither).

| Material | Texture | m / tile |
|---|---|---|
| `road` | `ground-street/Gravel023` | 3 |
| `ground` | `concrete-stone/Concrete031` | 8 |
| `sidewalk` | `concrete-stone/Concrete034` | 2 |
| `wall` | `concrete-stone/Concrete034` | 2.5 |
| `building_a` | `brick/Bricks074` | 2.5 |
| `building_b` | `plaster-paper/Plaster003` | 2.5 |
| `building_c` | `plaster-paper/Plaster001` | 2.5 |
| `container_blue/green/red` | `metal/Metal032` | 2 |
| `prop`, `ramp`, `lane_marking` | **none on purpose** (readability) | — |

Swap a texture = change the `ExtResource` path in the `.tres` **and** recompute `albedo`
(old blockout colour ÷ the new texture's mean RGB), or the surface changes brightness.

## Acceptance (how the user will judge it)
- [x] The city reads as a city from the driver's seat: facades have windows, not flat colour
- [x] Night-ish depth: some windows are lit, randomly, and it does not look uniform
- [x] The retro look is intact — no modern/clean surfaces, the dither and wobble still read
- [x] Nothing about driving, combat or the editor changed

## User test checklist
- [x] Drive around: do the buildings look like buildings now?
- [ ] Do the lit windows look random, or is the pattern obvious/repetitive?
- [x] **After DV-063: does the road still stretch / swim in motion?**
- [x] Textures while driving: does anything shimmer, moire or tile visibly?
- [x] Is the brick / concrete scale believable next to the car?
- [ ] Is the city too dark, too bright, or right?
- [ ] Are the windows the right size for the scale of the car?
- [ ] F1 (PS1 toggle) still switches the whole look off and on
- [ ] Does anything flicker or shimmer while driving past a facade?

## Feedback from user
- **2026-11-14, first playtest of the textures:** "Muy bueno pero hay como un efecto psicodelico con
  las texturas que no se que es. Se nota sobre todo con las calles, es como que se 'estiran' y se
  mueven." → affine mapping, finally visible now that there are textures. Fixed in DV-063 (road
  tessellated, affine dialled down on ground surfaces, isotropic road texture).
- **2026-11-14, re-test after DV-063: "me gusta!"** — approved. The user asked for the trade-off to be
  written down for later: [[Art Direction]] > "Tuning the PS1 look" now lists every dial
  (global affine / snap, per-material `affine_multiplier`, `snap_multiplier`, `world_uv_metres`,
  the window parameters) and what to reach for when a specific complaint comes up.

## Discovered / Deferred
- The pack has no window/facade textures at all — covered by generating them (DV-061) instead of buying
  the $1 urban pack, per the user's CC0-only call.
- Lighting and the night palette are the obvious next multiplier now that lit windows emit: the city
  is still lit as flat daytime. Deferred to its own iteration.
- `events_autotest` flakiness found while verifying — KI-026, unrelated to this work.
- The pack has no asphalt as such: `road` uses a dark concrete. If the road never reads right,
  that is the one texture worth sourcing separately (still CC0, e.g. ambientCG).
- 80 of the 90 textures are unused so far (wood, tiles, roofs, fabric, grass) — material for
  interiors, shop fronts and neighbourhood variety later.

## Result summary
The city reads as a city. Built: world-space UVs so a tiling texture keeps its real size on
generated boxes of any dimension (DV-061); procedural facade windows with randomly lit ones that
drive `EMISSION` (DV-061); the CC0 A_classic pack wired onto 10 materials with each flat colour
rebalanced against its texture's mean so the palette survived, and all 90 imports forced to
lossless / no mipmaps / no 3D auto-compression (DV-062); and the affine warping that this exposed
dialled down on ground surfaces (DV-063), which the user approved in play.

Still open, by choice: lighting and the night palette (the lit windows already emit, so the city is
still lit as flat daytime — the obvious next multiplier); 80 of the 90 textures unused; no
asphalt-proper in the pack, `road` uses gravel.
