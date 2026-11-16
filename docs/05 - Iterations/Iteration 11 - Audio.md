---
tags: [iteration]
iteration: 11
status: closed
started: 2026-11-14
finished: 2026-11-15
---
# Iteration 11 — Audio

## Scope (from user, verbatim)
> "Audio" (chosen 2026-11-14, with Iteration 08 out being playtested by a friend of the user).

## Interpretation
The game is **completely silent**: no `AudioStreamPlayer` anywhere, no sound files, no audio
autoload, no bus layout. For an arcade driving game this is the largest missing dimension left —
engine note is most of what "driving feels good" even means, and the references (Crazy Taxi) are
loud games.

This is the other half of [[Phase 11 - Audio, VFX & Juice]], whose visual half closed yesterday as
Iteration 10.

**The engine problem, and the decision it forces.** There is no clean CC0 car-engine loop to be
had: Kenney has no vehicle audio pack at all, and the Freesound CC0 candidates are a truck idle, a
sci-fi hover vehicle and a 1:48 contact-mic recording of a Mini with no marked loop point. Rather
than block on asset hunting, the sounds are **generated offline** by `tools/gen_sfx.py` into
`assets/audio/`: seamless by construction (a whole number of cycles per loop), CC0 by construction
(nothing is downloaded), and reproducible — the script is the source, the WAVs are the build.
Synthesis also suits the PS1 blockout look better than a real car recording would.

**What I cannot do: hear any of it.** Everything here is verified by construction and by numbers
(loop continuity, peak and RMS levels, playback without errors). Whether it *sounds* good is the
user's call, exactly like the swimming road was.

**OUT of scope:** music and radio stations (own iteration, and a licensing question of its own),
interior-vs-exterior reverb, Doppler, passenger voice barks beyond a blip, a settings UI for
volume (the API exists, the menu is Phase 10), enemy-car engines, and anything touching what the
friend is testing (editor, piece kit, map data, wreck → repair).

## Phase tasks covered
- [[Phase 11 - Audio, VFX & Juice]] → the whole Audio section except music

## Checklist
- [x] Bus layout: Master, Music, SFX, Engine, UI, Voice (in `tools/setup_project.gd`)
- [x] `Audio` autoload: play one-shots, positional one-shots, volume per bus, pooling
- [x] `tools/gen_sfx.py` generates every sound into `assets/audio/`, documented and re-runnable
- [x] Engine: layered loop, pitch and volume by speed / throttle, different when boosting or limping
- [x] Tyre screech driven by the existing `rear_slip_signed` / `is_drifting`
- [x] Impacts by force; the wreck moment
- [x] Guns: per-weapon shot, reload, empty
- [x] Hit confirm, enemy destroyed, explosion
- [x] Cash register on payout, item pickup, energy drink
- [x] Dossier: open, close, choose an action
- [x] Nothing plays in headless autotests (they must stay silent and fast)

## Acceptance (how the user will judge it)
- [ ] The engine responds to the throttle and sounds like a car, not like a tone
- [ ] Drifting is audible and satisfying
- [ ] Shooting has weight; the three weapons sound different
- [ ] Getting paid feels good
- [ ] Nothing is painfully loud, harsh or clipping
- [ ] It fits the PS1 look rather than fighting it

## User test checklist
- [ ] Drive: accelerate, brake, drift, boost, crash. Is the engine convincing at every speed?
- [ ] Is anything too loud or too quiet relative to everything else?
- [ ] Fire all three weapons, reload, run dry
- [ ] Complete a ride and get paid
- [ ] Get wrecked and limp to a repair shop
- [ ] Anything that grates after five minutes?

## Feedback from user
- **2026-11-14, first listen:** everything worked **except the car itself** — no engine, no tyre
  screech — and the NPC cars had no engine either. Both fixed in D-067: the loops were playing once
  and stopping (the importer's loop flag never reached the resource), and enemy engines simply did
  not exist, having been scoped out.
- **2026-11-14, second listen:** the engine is "muy agudo" at high revs, a constant tone with no
  gear changes is "irrealista y molesto", and neither sliding nor braking sounds like rubber on
  tarmac. All three addressed in D-068: a five-speed gearbox, a narrower and lower pitch range with
  regenerated samples, a screech rebuilt from four rubber resonances instead of a band of hiss, and
  braking that makes a sound at all.
- **2026-11-15, third listen: accepted.** "el sonido quedo mejor pero seguramente lo cambiemos a
  futuro, por ahora está bien." Good enough to move on; the bank is expected to be revisited.

## Discovered / Deferred
- **The buses are created by the autoload, not by `setup_project.gd`** as the checklist assumed:
  idempotent code in one place beats a `.tres` that has to be kept in sync.
- ~~Loop flags live in the `.import` files~~ — **they did not take** (D-067): the flag was written
  after the first import and the cached `.sample` won. Looping is now forced on the resource in
  `Audio._force_loop()`, so regenerating the bank cannot break it.
- **Enemy-car engines, deferred here, were added in D-067** after the playtest: the user expected
  them and they cost one call to the new `make_loop_3d()`.
- Two EventBus signals were missing and were added: `weapon_reloading`, `weapon_empty`.
- **Deferred on purpose:** music and radio stations, interior-vs-exterior reverb, Doppler,
  passenger vocal blips, door sounds, and a volume slider UI (the API is there,
  the menu is Phase 10 — where the time-of-day choice is also waiting).
- `empty_click` and `reload` existed in the bank before anything emitted them; found by
  cross-checking every generated file against the names referenced in code. Worth repeating when
  the bank grows.

## Result summary
21 sounds, all generated by `tools/gen_sfx.py` (CC0 by construction, seamless by construction,
reproducible from a fixed seed). An `Audio` autoload owns the six buses, pooled one-shot players
flat and positional, looping sources, and the volume API — and wires fourteen sounds by listening
to the EventBus itself, so not one gameplay script mentions audio. The taxi drives three crossfaded
engine layers plus tyre screech from state it already tracked (`forward_speed`, `input.throttle`,
`is_boosting`, `limp`, `rear_slip_signed`). Silent in headless, so the suite stays green and fast.

**Unverified by Claude: how it sounds.** Every objective check passed; the aesthetic ones cannot be
made from here — they took three rounds of the user listening (D-067 the loops not looping, D-068
the gearbox and the tyres) and ended at "better, we will probably change it in future, fine for
now". The bank is explicitly expected to be revisited: `tools/gen_sfx.py` is the place, and
[[Art Direction]] has no audio section yet — worth writing one when it is.
