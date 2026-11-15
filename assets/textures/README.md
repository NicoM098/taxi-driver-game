# Textures

**In use since 2026-11-14:** `A_classic/` (90 PNGs, 64x64, 16 colours, ordered dither).
What each material uses is in [[Iteration 09 - Texture Pass]] and D-062.

## The pack (user's choice, Iteration 09)
**PSX Textures Vol. 1 — Francisco Cidade**, https://fcidade.itch.io/psx-textures-vol-1
CC0 1.0 (no credit required, commercial use fine). "Name your own price" — $0 is allowed.

The download has one folder per look: `A Classic` (64 px / 16 colours / dither), `B Flat`,
`C Soft` (128 px / 32 colours), `D Murky` (64 px / 24 colours, grimy), `E Chunky` (32 px).
**ONE look folder only** — mixing looks is what makes a free-asset game look stitched together.
`A_classic/` is the one in use.

Suggested look: **A Classic** for the default daytime read, **D Murky** if the city should feel
dirtier. Switching later = replace the files, nothing in the project changes.

## Wiring a texture to a material
Every material in `assets/materials/` is a `ShaderMaterial` on `ps1_world.gdshader`, which already
has the slot:

```
shader_parameter/albedo_texture = ExtResource("<the .png>")
```

The surface materials below are already on **world-space UVs** (`uv_mode = 1`), so a tiling texture
keeps the same real-world size on a generated box of any dimension — no per-piece setup, no
stretching. `world_uv_metres` is how many metres one tile covers.

| Material | `world_uv_metres` | Pack family to use |
|---|---|---|
| `road` | 8 | Ground and street |
| `lane_marking` | 4 | Ground and street |
| `sidewalk` | 2 | Concrete and stone |
| `ground` | 8 | Ground and street |
| `building_a` | 4 | Brick |
| `building_b` | 4 | Concrete and stone |
| `building_c` | 4 | Plaster and paper |
| `wall` | 4 | Concrete and stone |
| `container_blue/green/red` | 2 | Metal |
| `prop`, `ramp` | 2 | Metal / Wood |

**`albedo` must be rebalanced, not kept (D-062).** The shader does `albedo * texture`, and these
textures average 0.25-0.45, so reusing the blockout colour would darken the city to a fraction of
its designed brightness. The rule: `new_albedo = old_blockout_colour / texture_mean_rgb`, clamped
at 1.6. Redo it whenever a texture is swapped.

## Import settings (important — already applied to all 90)
PS1 textures must stay crunchy. Every `.png.import` here has:
- `compress/mode=0` (lossless) and `mipmaps/generate=false` — these are Godot's defaults
- **`detect_3d/compress_to=0`** — this one is **not** the default. Godot ships it as `1`, which
  silently re-imports a texture as VRAM-compressed **with mipmaps** the first time it is used in a
  3D material, and that smears the ordered dither into mush. **Any texture added later must get
  this too**, before it is first used.

The shader already samples with `filter_nearest`, so there is nothing to set per material.

## Not from this pack
Facade windows are **not** a texture. They are generated in `ps1_world.gdshader` (D-061) from world
coordinates, with random lit ones, so they fit buildings of any height without a UV layout. If a
window texture is ever added, set `windows_enabled = false` on that material.
