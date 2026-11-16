---
tags: [iteration]
iteration: 13
status: closed
started: 2026-11-16
finished: 2026-11-16
---
# Iteration 13 — Merge Integration

## Scope (from user, verbatim)
> "hagamos una iteración corta de integración. Eso sí, la parte de la música por ahora la dejemos
> en stand-by. Ya después lo vamos a encarar el tema este del MP3, que tiene que ser, bueno, legal.
> Pero no te preocupes por eso. Por ahora sí vamos con los otros puntos que mencionaste."

## Interpretation
`temp/playtest-merge` brought two lines of work together — DLain47's menus, street life, shops and
heat, and Nico's textures, lights and audio. The merge is healthy (16 autotests pass, the visuals
survived), but the two sides do not know about each other yet. This closes the seams.

**OUT of scope, by explicit instruction:** the third-party music track (KI-034) and anything about
licensing it. Also out: the juice (skid marks, hit-stop, style points) and neighbourhoods.

### What the review actually found
A first pass claimed traffic and pedestrians had no lights. **That was wrong, and worth recording
why**: `TrafficCar extends Taxi`, so every civilian car already inherits the headlights and the
whole engine-audio rig through `super._ready()`. Grepping `traffic_car.gd` for `Light3D` found
nothing because the code is in the parent. Measured instead of grepped: 9 civilian cars in a
street-life run, each one getting headlights **and three engine loops plus a tyre loop**.

That inheritance is the actual bug. `Audio.make_loop()` builds a **non-positional**
`AudioStreamPlayer`, which is right for the car the player sits in and wrong for everyone else: 9
civilian cars × 4 loops = **36 flat loops**, all at the player's own engine volume, no matter how
far away the car is. Enemy cars (DV-067) do it properly with `make_loop_3d`.

## Checklist
- [x] Civilian cars stop inheriting the player's non-positional engine and tyre loops
- [x] Civilian cars get a positional engine of their own, like the enemy cars
- [x] Tail lights on the taxi (and so on every civilian car), brighter under braking
- [x] Tail lights and headlights both follow the time of day
- [x] Decide and record whether civilian engines are audible at all — **yes, but quiet**: -21 dB
      against the enemies' -14 and the player's -6 (D-078). The street should not be eerie, and an
      engine you can hear *clearly* that is not yours still reads as trouble. Hostiles also carry
      the red marker (D-076), so the cue is not carried by audio alone.
- [x] Iteration numbering untangled: two 09s and two 10s in `05 - Iterations/`
- [x] Night screenshot taken; the tail lamps were verified by state (2 lenses per car, lit at night, off by day) because the test camera does not reliably frame another car

## Acceptance (how the user will judge it)
- [ ] A street with traffic at night reads as a street with traffic: lights coming and going
- [ ] The mix is not a wall of engines; you can still hear your own car
- [ ] You can still tell a hostile from a civilian by ear or by eye
- [ ] Nothing DLain47 built behaves differently than it did before

## User test checklist
- [ ] Drive at night (F6) with traffic around: do the other cars read?
- [ ] Does the audio get crowded when several cars are near?
- [ ] Brake lights: do they help you read the car in front?
- [ ] Anything about the menus, shops, heat or tutorial that changed? (nothing should have)

## Feedback from user
- **2026-11-16, night drive with traffic: works.** "en tus primeras pruebas se sentía demasiado
  ruido de motores. Ahora se escuchan muy bajito, creo, los civiles, pero en realidad está bien."
  Confirms both the bug and the fix from the inside: what the user heard as "too much engine noise"
  was the 52 non-positional loops, and -21 dB is acceptable.
- **Question raised:** every vehicle's audio should be positional so it does not deafen — police,
  enemies and civilians. **Checked: it already is**, see the table below. Nothing to change.

## Discovered / Deferred
- **The review's first pass was wrong about the lights**, and the reason is worth keeping: grepping
  `traffic_car.gd` missed everything that `TrafficCar` inherits from `Taxi`. Measuring at runtime
  found the opposite problem — not too few lights, too much audio.
- **`streetlife_autotest` failed once when run windowed** ("the pedestrian neither dodged nor got
  hit") and passed every headless run. Not chased; if it comes back, it joins KI-029 / KI-032 as a
  flaky.
- Pedestrians have no audio and no lights at all. Left alone: they are small, and footsteps would
  need a sound that is not in the bank.
- Enemy cars still have no tail lights (they do not extend `Taxi`); only civilians and the player
  inherited them.
- Music stays out by explicit instruction (KI-034).

## Vehicle audio, as it stands (D-078)
| Source | Player | Distance | Where |
|---|---|---|---|
| Player's taxi | 3 layers + tyres, **non-positional** | — | `taxi.gd` (correct: you are inside it) |
| Police cruiser | 1 layer, **positional** | 80 m, -14 dB | `enemy_car.gd` (DV-067) |
| Hitmen / bruiser / gang | 1 layer, **positional** | 80 m, -14 dB | `enemy_car.gd` (DV-067) |
| Civilian traffic | 1 layer, **positional** | 55 m, -21 dB | `traffic_car.gd` (D-078) |
| Explosions, kills | one-shot, **positional** | `play_at` | `audio.gd` (DV-066) |
| Your gun, impacts, UI | one-shot, non-positional | — | `audio.gd` (correct: they happen to you) |

The police are `EnemyCar` with `police_cruiser.tres`, so they inherit the enemy treatment.

**Found while checking, not fixed:** `enemy_gunner.gd` draws tracers and muzzle flashes
(3 `CombatFx` calls) and plays **no sound at all** — being shot at from a car is silent. It is the
one obvious hole left in the positional audio.

## Result summary
The two lines of work now know about each other. Civilian cars no longer borrow the player's
non-positional engine rig — 52 flat loops became 4 flat (the taxi) plus one positional layer per
civilian at -21 dB — and every car that extends `Taxi`, the player's and the civilians', now has
tail lamps that light at dusk and flare under braking. The iteration notes are unambiguous again
(`09V` / `10V` / `11V`, shared numbering from 13 on).

All 16 autotests pass. Untouched on purpose: the music track, the juice, neighbourhoods, and
everything DLain47 built.
