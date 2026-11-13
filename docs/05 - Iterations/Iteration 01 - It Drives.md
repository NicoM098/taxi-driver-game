---
tags: [iteration]
iteration: 1
status: done
started: 2026-11-10
finished: 2026-11-11
---
# Iteration 01 — It Drives

## Scope (from user, verbatim)
> okay lets start, the scope for it 01 will be your recommended

Recommended scope = [[Phase 00 - Project Setup]] + [[Phase 01 - Taxi Driving & Cab Camera]].

## Interpretation
A Godot project that boots into a PS1-styled test course where you drive an arcade taxi in first person, with KB+M and gamepad.
**Out of scope:** city layout (Phase 02), passengers, shooting, HUD beyond a debug overlay, audio, rear-view mirror render.

## Phase tasks covered
- Phase 00 — all tasks.
- Phase 01 — all tasks except the rear-view mirror render (placeholder only).

## Checklist
- [x] Project renamed, folders, autoloads, input map (KB+M + pad), physics layers, physics interpolation
- [x] Main scene with low-res SubViewport + PS1 post shader + UI layer, pause, debug toggles
- [x] PS1 world shader + flat-colour material presets
- [x] Raycast taxi: suspension, engine, brakes/reverse, grip & drift, steering, air control, flip recovery, boost
- [x] Cab camera: free look (mouse + stick), recenter, look-behind, g-force lean, FOV kick, crash shake
- [x] Blockout taxi with interior (dashboard, steering wheel, pillars, seats, headliner)
- [x] Test course: ramps, tabletop, hill, speed bumps, slalom, cones, mini city blocks
- [x] Debug overlay
- [x] Headless vehicle autotest passes (drive + jump scenarios)
- [x] **User playtest** (see below)

## Acceptance (how the user will judge it)
- [ ] F5 → drive the taxi in first person; driving feels arcade-fun; drift, jumps and recovery work.
- [ ] PS1 look is visible and can be toggled (F1).
- [ ] Gamepad works for driving and looking.

## User test checklist
Open `new-game-project` in Godot 4.6.1 → F5.
1. [ ] Drive straight (W / RT): acceleration and top speed (~120 km/h, ~150 with boost Shift / A) feel right?
2. [ ] Turn at low and high speed (A/D / left stick): responsive? too grippy / too slidey?
3. [ ] Handbrake (Space / B): tap while turning → drift. Controllable?
4. [ ] Ramps (orange, to the right of spawn at x=40): jump and landing OK? Tabletop and hill further right.
5. [ ] Speed bumps & city blocks (to the left): suspension and driving between buildings.
6. [ ] Knock over the cone rows (behind-right of spawn).
7. [ ] Flip the car → it auto-recovers after ~2.5 s, or press T / L3.
8. [ ] Mouse look and right-stick look; C / R3 look behind. Comfortable? Any motion sickness from lean/shake?
9. [ ] F1 toggles the PS1 look; F2 overlay; F4 physics interpolation — does the camera look smoother with F4 on or off?
10. [ ] Esc / Start pauses and frees the mouse; click to recapture.
11. [ ] Does the steering wheel turn the right way?

## Feedback from user
**2026-11-11 playtest:**
- Driving feel itself: good ✅. Turn dynamics approved ✅. City & bumps approved ✅. Steering wheel direction fine ✅.
- Jumps: nose drops too much; wants a quicker little bounce where the nose doesn't dive and the car hops up a bit → fixed (D-018), **recheck**.
- Handbrake too aggressive at low speed, fine at high speed → fixed (D-019), **recheck**.
- Camera smooth with interpolation on and off; can't tell the difference → keep F4 toggle until textures (KI-001).
- Couldn't flip the car → verified by new `--flip` autotest (recovers in ~2.9 s).
- "The cones fall over" — read as: knocking them over works (intended).

**2026-11-11 (2):**
- Wants landing bumps much more noticeable, really arcade → D-020: deterministic hop (0.46 m small ramp / 0.69 m medium) + camera landing shake & head dip. **recheck**
- Asked to note a side-to-side **drift chain multiplier** (money + speed) in the design docs → GDD §3b, Phase 03 tasks (D-021). Not implemented in this iteration.

## Discovered / Deferred
- Rear-view mirror render → polish later (KI-005).
- Vehicle tunables → `VehicleStats` resource before Phase 09 upgrades (KI-006).

## Result summary (fill when done)
✅ **Closed 2026-11-11 by the user** ("close it 01 and move on").
Delivered: project setup, PS1 pipeline, arcade raycast taxi (assists, air levelling, arcade landing hop, speed-scaled handbrake), first-person cab camera, test course, debug tools, 4 autotest scenarios. Playtest approved driving, turning, city/bumps, steering wheel; landing/handbrake changes accepted when closing.
Carried over: gamepad not explicitly confirmed (KI-002), mirror render (KI-005), VehicleStats resource (KI-006), interpolation decision at textures (KI-001).
