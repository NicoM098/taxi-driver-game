---
tags: [design, art]
status: accepted
---
# Art Direction

**Accepted (see [[Decisions Log]] D-010):** primitive **blockout geometry** + a **PS1-style render pipeline** from the start. **No textures from day 1** — the priority is fast blockout iteration.

## Texture roadmap
1. **Phase 00–01:** flat-colour `ShaderMaterial` presets (`road`, `sidewalk`, `building_a/b/c`, `taxi_yellow`, `enemy_red`, `glass`, `interior`, `prop`) in `res://assets/materials/`. Optional engine-generated `NoiseTexture2D` (64 px, nearest) for subtle grime — no asset files.
2. **Phase 02+ / Iteration 09:** add textures only where they help readability (lane lines, crosswalks, signs).
   **Building windows are generated, not textured** (D-061): a world-space grid in `ps1_world.gdshader`
   with randomly lit ones, so it fits buildings of any height with no UV layout.
   Chosen pack (CC0 only): [PSX Textures Vol. 1](https://fcidade.itch.io/psx-textures-vol-1) — see
   `assets/textures/README.md`. Surfaces are on world-space UVs so one material tiles correctly on
   generated boxes of any size.
3. **Phase 12:** full texture pass — one cohesive CC0/itch.io pack + shrunken CC0 photos (64–128 px, palette-reduced); custom signs and taxi livery for identity. Check licenses (prefer CC0).

Rule: `ps1_world.gdshader` always has an optional `albedo_texture` uniform (white default), so textures drop in without changing materials' structure.

## Why
- The PS1 look is ~90% shaders/render settings, not assets → near-zero art cost.
- Low resolution + jitter hides blockout crudeness and makes primitives look intentional.
- Fits the pulpy dark-comedy tone and keeps performance high.

## Options compared
| Option | Effort | Result |
|---|---|---|
| Pure blockout (grey primitives) | Lowest | Readable, looks unfinished |
| **Blockout + PS1 pipeline, flat colours** ← start here | Low (≈1 session one-time) | Stylised, demo-ready |
| Blockout + PS1 pipeline + low-res textures | Low–medium | Full retro look; incremental, no rework |
| Modelled & textured PS1 assets | High | Polished; post-PoC |

## PS1 techniques in Godot 4.6
1. **Low internal resolution** — render the 3D world in a `SubViewport` at ~320×240 (or 480×270 for 16:9) inside a `SubViewportContainer` (`stretch = true`, `stretch_shrink` 3–4, `texture_filter = nearest`). Biggest single contributor.
2. **Vertex snapping (wobble)** — spatial shader: compute clip position, snap `xy / w` to a coarse grid (e.g. the low-res pixel grid), write to `POSITION`. Strength as a uniform.
3. **Affine texture mapping** — in `vertex()` pass `UV * clip.w` and `clip.w` as varyings; in `fragment()` divide → textures warp like PS1. Strength uniform (blend with perspective-correct UV).
4. **Colour depth + dithering** — full-screen shader on the viewport output: 4×4 Bayer dither, then quantise each channel to 5 bits (32 levels).
5. **Fog + short draw distance** — `WorldEnvironment` depth fog + camera `far` ~150–250 m; hides city edges, helps performance.
6. **Textures** — 64–128 px, `texture_filter = nearest`, no mipmaps (or nearest mipmaps); vertex colours for cheap shading variation.
7. **Lighting** — mostly unshaded/vertex-lit look: `shading_mode = per_vertex` or simple lambert, no shadows (or blob shadows), no SSAO/SSR/glow.

## Implementation plan
- One shared `ps1_world.gdshader` (snapping + affine + albedo/texture + vertex colour + fog-compatible), used via a few `ShaderMaterial` presets (road, building, car body, glass, interior).
- `ps1_post.gdshader` for dither/quantise on the low-res viewport.
- Global toggles/uniforms (`global shader uniforms` in Project Settings): `ps1_snap_strength`, `ps1_affine_strength`, so the effect can be tuned or turned off for debugging.

## Special care
- **Cab interior** (dashboard, wheel, hands, gun) is very close to the camera → snapping is exaggerated and nauseating. Use reduced/zero snap strength on interior materials.
- **UI** (dossier, HUD, menus) lives *outside* the low-res SubViewport, rendered at native resolution for readability. Optionally a pixel font for style.
- Controller & mouse aim precision at low res: crosshair rendered in the full-res UI layer.

## Palette / mood (draft)
Saturated taxi yellow as the hero colour; dusky city (blue/purple shadows, sodium-orange street lights); red for danger/enemies; dossier in off-white paper + typewriter font.


## Tuning the PS1 look (the knobs)
Everything below is data, not code: a value in Project Settings or a `shader_parameter` line in an
`assets/materials/*.tres`. Nothing here needs a rebuild, and `F1` in game still toggles the whole
look off and on. Added 2026-11-14 at the user's request, so the dials are findable later.

### Global — Project Settings > Shader Globals (defaults set in `tools/setup_project.gd`)
| Setting | Now | What it does | Push it up / down |
|---|---|---|---|
| `ps1_affine_strength` | 1.0 | How much textures warp (no perspective correction) | 0 = modern, perspective-correct |
| `ps1_snap_strength` | 1.0 | How much vertices jitter to the pixel grid | 0 = rock-steady geometry |
| `ps1_snap_resolution` | 426 x 240 | The grid vertices snap to | Lower = coarser wobble |

### Per material — in the `.tres`
| Parameter | Typical | Notes |
|---|---|---|
| `affine_multiplier` | 1.0 | **0.25 on `road` / `ground`, 0.5 on `sidewalk` (D-063).** Big surfaces seen edge-on warp hardest; this is the dial for "the road is swimming". `0.0` kills it on that surface alone. |
| `snap_multiplier` | 1.0 | **0.0 on the cab interior** — it sits centimetres from the camera, where wobble is nauseating. |
| `world_uv_metres` | 2.5-8 | Metres covered by one texture tile (`uv_mode = 1`). Smaller = finer detail, more repetition. |
| `albedo` | — | **Must be rebalanced when a texture changes** (D-062): old flat colour ÷ the texture's mean RGB. |

### Facade windows (D-061, on `building_a/b/c`)
`window_cell` metres between centres · `window_fill` how much of the cell is glass ·
`window_ground_floor` blank wall at street level · `window_lit_chance` how many are lit ·
`window_lit_emission` how brightly · `window_dark_mix` how much of the wall an unlit window
replaces (1.0 = black holes) · `window_fade_near/far` the distance where they dissolve back into
the wall, which is what stops the grid turning into moire.

### Time of day (D-064) — `src/world/lighting.gd`
Three moods, **dusk is the default**; **F6** cycles them in play. Each one is a dictionary: sky,
ambient colour + energy, sun colour / energy / angle, fog colour + range, `lamp_energy` (0 switches
the street lamps off) and `window_emission` (how hard a lit window burns, since D-061's windows were
tuned against a bright sky). Changing a mood is editing numbers in one file — no scene, no code.

| | day | dusk | night |
|---|---|---|---|
| ambient energy | 0.70 | 0.62 | 0.34 |
| sun energy | 1.10 | 0.90 | 0.20 (moon) |
| fog | 70-220 m | 55-190 m | 40-150 m |
| lamps (light / glow) | off / off | 1.6 / 1.2 | 2.4 / 1.6 |
| lit windows | off | 1.2 | 1.8 |
| headlights | off | on | on |

Everything that emits light follows the mood (D-065): the lamp's omni light **and** its glass, the
lit windows (`window_lit_amount` = 0 makes them identical to unlit ones) and the taxi's headlights,
which hear about it through `EventBus.mood_changed`. Add a new light to the game and it has to
listen there too, or it will be burning at midday.

**Street lamps:** `City.LAMP_SPACING` (cells between lamps on a kerb), `LAMP_RANGE`, `LAMP_MAX`,
and `Lighting.LAMP_COLOR`. They have no collision — purely visual, like the lane dashes.
**Headlights:** `taxi.gd > _add_headlights()`. Energy is high (45) on purpose: see D-064, a light
0.6 m above a flat road hits it at a grazing angle and lambert gives it almost nothing.

### If someone complains about...
- **"The road stretches / swims"** → `affine_multiplier` on `road` and `ground`; then tessellation
  in `city.gd` (`_build_ground_and_walls`, ~6 m quads); then whether that texture has a direction
  to it (a streaky one smears, an isotropic grain does not) — all three, in that order (D-063).
- **"It's too wobbly / I feel sick"** → `ps1_snap_strength`, or `snap_multiplier` on whatever is
  closest to the camera.
- **"It's too dark / washed out"** → `albedo` per material, never the texture.
- **"The windows look fake / repetitive"** → `window_cell` and `window_lit_chance` per building
  material; the three building materials are deliberately different so facades do not rhyme.
- **"I can't see where I'm going"** → the mood's `ambient_energy` first, then `lamp_energy`, then
  `LAMP_SPACING`; the headlights are the last thing to touch, because their angle against the road
  limits what they can ever do (D-064).
- **"It doesn't feel like night / like evening"** → the whole mood lives in one dictionary in
  `lighting.gd`; change the sky, fog and sun together or it reads as "a dark day" instead.
