---
tags: [design, art]
status: accepted
---
# Art Direction

**Accepted (see [[Decisions Log]] D-010):** primitive **blockout geometry** + a **PS1-style render pipeline** from the start. **No textures from day 1** — the priority is fast blockout iteration.

## Texture roadmap
1. **Phase 00–01:** flat-colour `ShaderMaterial` presets (`road`, `sidewalk`, `building_a/b/c`, `taxi_yellow`, `enemy_red`, `glass`, `interior`, `prop`) in `res://assets/materials/`. Optional engine-generated `NoiseTexture2D` (64 px, nearest) for subtle grime — no asset files.
2. **Phase 02+:** add textures only where they help readability (lane lines, crosswalks, building windows, signs).
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
