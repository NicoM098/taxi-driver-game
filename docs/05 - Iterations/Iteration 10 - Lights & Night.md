---
tags: [iteration]
iteration: 10
status: closed
started: 2026-11-14
finished: 2026-11-14
---
# Iteration 10 — Lights & Night

## Scope (from user, verbatim)
> "Luces y noche" (chosen over re-testing Iteration 08, 2026-11-14).

## Interpretation
The city is lit like flat midday: one directional light at 1.1, ambient 0.7, a pale blue sky and
fog from 70 to 220 m — all of it in `Blockout.add_environment()`. Meanwhile the facade windows
built in Iteration 09 already drive `EMISSION` and nothing comes of it, because nothing around
them is dark.

[[Art Direction]] already decided the mood: *"dusky city (blue/purple shadows, sodium-orange street
lights); saturated taxi yellow as the hero colour; red for danger"*. This iteration builds that.

Four pieces:
1. **Time-of-day presets** (day / dusk / night) as data, with a debug key to switch in play, so the
   mood is chosen by looking at it rather than by argument. Dusk is the default per Art Direction.
2. **Street lamps** along the kerbs, sodium orange — the single biggest change to how a night city
   reads, and what gives the taxi something to drive between.
3. **Taxi headlights.** Non-negotiable once it is dark: driving a night city with no headlights is
   not a style choice, it is a bug.
4. **Per-pixel lighting in `ps1_world.gdshader`.** The shader is `vertex_lighting`; with the road
   tessellated at 6 m (D-063) a lamp's pool of light would be computed at four corners 6 m apart
   and look like a faceted blob. Everything else about the PS1 stack stays.

**OUT of scope:** shadows (the look has none and never will), a running day/night *cycle* tied to
gameplay, light shafts / volumetric fog, neon signs and shop fronts (that is neighbourhood
content), reworking the HUD or the dossier for darkness, enemy-car headlights unless they fall out
for free.

## Phase tasks covered
- [[Phase 11 - Audio, VFX & Juice]] → the lighting half of "juice"
- [[Art Direction]] → the palette / mood section, which was written and never built

## Checklist
- [x] `Lighting` presets: sky, ambient, sun, fog per mood (day / dusk / night)
- [x] `Blockout.add_environment()` takes a mood; dusk is the default
- [x] Debug key cycles the mood in play (not F9 / F10 — Godot's embedded game view uses those)
- [x] `ps1_world.gdshader` lit per pixel instead of per vertex
- [x] Street lamps generated along kerbs: post + emissive head + omni light, visual only
- [x] Lamp density and range tuned so the street has pools of light, not a flat orange wash
- [x] Taxi headlights: two spots + emissive lenses
- [x] Window emission re-checked at night (they were tuned against a bright sky)
- [x] Frame time checked with the lamps in — no shadows, so this should be cheap

## Acceptance (how the user will judge it)
- [x] The city at night looks like the third reference (*Shift at Midnight*), not like a dark day
- [x] Lit windows now read as the city being alive
- [x] You can see where you are going
- [x] The taxi's yellow still pops — it is the hero colour
- [x] The retro look survives: dither, wobble and warp all still read

## User test checklist
- [x] Drive at each mood (debug key) — which one is the game?
- [x] Can you drive at a normal speed without losing the road?
- [ ] Do the lamps look placed, or mechanical and repetitive?
- [x] Is anything now too dark to play: passengers, the beam at a stop, the arrow, enemies?
- [ ] Does the frame rate hold (F2 overlay)?

## Feedback from user
- **2026-11-14, playtest of all three moods: "Muy bueno! Y lo ideal sería tener variedad. Probe
  todas y se ven y sienten bien."** → all three stay; variety is wanted rather than one fixed mood.
- **Bug found by the user:** *"de día las luces del auto y de la calle se deberian apagar (de los
  edificios me imagino que tambien)"* — correct on all three counts. Fixed in D-065.
- **Request:** *"cuando tengamos un menú al iniciar una partida puedas elegir"* — the time of day
  should be a choice when starting a game; F6 is fine for now. Written into
  [[Phase 10 - Game Flow, UI & Save]], not built here.

## Discovered / Deferred
- **Three lights had to be switched, not one** (D-065): the lamp's omni light, the lamp glass's own
  emission, and the lit windows each needed turning off separately — and the headlights needed a
  way to hear about it at all, which is what `EventBus.mood_changed` is for.
- **Headlights are limited by physics, not by tuning** (D-064): a light 0.6 m above a flat road
  grazes it, so no sane energy makes a bright pool straight ahead. 45 is the compromise. If they
  ever need to read stronger, the PS1-era answer is a fake emissive "pool" quad on the ground
  rather than a brighter light.
- **Enemy cars have no headlights.** At night they are dark shapes until their sirens show. Cheap to
  add in `enemy_car.gd`, deliberately left out of this iteration's scope.
- The moon in `night` is a directional light at 0.2 doing the job of "you can still make out a
  silhouette". If night is chosen as the game's mood, that number is the first thing to argue about.
- Performance was measured on one high-end GPU (165 FPS, vsync-capped). The floor is unknown.

## Result summary
Three times of day as data (`src/world/lighting.gd`), dusk by default, F6 to cycle: sky, ambient,
sun, fog, lamp energy and glow, window emission and headlights all move together. 311 shadowless
street lamps along the kerbs, visual only. Taxi headlights, aimed and powered against the grazing
angle a headlight actually has on a flat road (D-064). The PS1 shader moved to per-pixel lighting
so lamp pools are not faceted at 6 m road quads. The user played all three and kept all three;
D-065 then made every light follow the time of day after daylight was found still burning.

Left for later, on purpose: picking the time of day from the main menu (→ [[Phase 10 - Game Flow, UI & Save]]),
enemy-car headlights, and the fact that performance is only known on one high-end GPU.
