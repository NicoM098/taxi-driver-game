---
tags: [iteration]
iteration: 6
status: done
started: 2026-11-11
finished: 2026-11-12
---
# Iteration 06 — Passenger File & Decisions

## Scope (from user, verbatim)
> close it 05. and start with the next one

Next one (as proposed at the end of Iterations 04 and 05): **[[Phase 04 - Dossier & Decisions]]** — the Papers, Please layer.

## Interpretation
When a passenger gets in, a file (dossier) opens: generated name + age, occupation, destination, estimated fare, notes with highlighted suspicious details. The player can **examine** details (costs shift time; reveals text, can reveal traits and unlock actions) and then pick an **action**: Drive, Kick out, Kill (only when unlocked), or data-driven special options (different fare/time/destination, cash, heat).
- World **paused** while reading; shift clock drains at half speed + a fixed cost per examination (time pressure).
- Fully playable with mouse and gamepad (examines also as buttons, focus navigation).
- Kick-out reactions (calm / angry parting shot); kill sequence (look back, bang, passenger gone, bounty/heat per action).
- 3 test passengers with different files; one hides a kill option behind an examination.
**Out of scope:** multi-page files and portraits from art (blockout portrait), ride events (Phase 07), new archetypes (Phase 07).

## Checklist
- [x] Resources: `Examinable`, `PassengerAction`; `PassengerProfile` dossier fields; `PassengerInstance` (name, age, examined, traits, destination)
- [x] RideManager: `DOSSIER` state between ENTERING and RIDING; outcomes DRIVE / KICK_OUT / KILL with modifiers
- [x] Dossier UI (paper file, blockout portrait, highlighted notes, examine + action buttons, focus nav, time drain)
- [x] Pause integration (Esc ignored while the file is open), mouse handling
- [x] Kill sequence + kick reactions
- [x] 3 profiles with files (commuter, tourist, rushed executive with hidden gun → kill)
- [x] Dossier autotest; ride test updated; all tests PASS

## Acceptance (how the user will judge it)
- [x] The file is readable at a glance and fun to inspect. *(after the D-046 UI pass: "looks good enough for now")*
- [x] Examining feels worthwhile (it reveals and unlocks things) and costs time. *(user 2026-11-12: all mechanics work as intended)*
- [x] Every action resolves cleanly back into the ride loop.

## User test checklist
F5 → pick up any passenger (stop next to a yellow beam). The **file** opens and the world freezes; the shift clock (top right of the file) keeps draining at half speed.
1. [ ] Readable at a glance? Name, age, job, destination (district + distance), fare estimate, notes, portrait.
2. [ ] Click a **red underlined clue** or an **Examine** button: the finding appears in red, the clue turns grey, the clock drops by its cost.
3. [ ] **Rushed Executive** ("Dentist"): examine *his jacket* → **Collect the bounty (kill him)** appears (red). Kill: the view snaps back, BANG, +$120, heat star. Examine *the phone call* → **hush money** (+$60, then drive).
4. [ ] **Tourist**: examine *the map* → **scenic route** (+50 % fare, more time).
5. [ ] **Kick them out**: Commuter grumbles; Tourist threatens a review; Executive fires a parting shot (YOU −8).
6. [ ] Gamepad: d-pad/stick moves between buttons, A selects.
7. [ ] Esc does nothing while the file is open (no accidental pause); mouse is free while reading and captured again after.
8. [ ] Full pause vs. slow-mo: does freezing the world while reading feel right?

## Feedback from user
- 2026-11-11 (end of day): "We will continue tomorrow, I haven't tested this" → **not tested yet**; start the next session with this checklist.

- 2026-11-11 (next session, after playtest): "I have tested all, UI could be improved. Everything else works as intended, tried all mechanics, none of them spawn a hostile yet." → mechanics approved; **dossier UI needs a polish pass**; no dossier outcome spawns a hostile yet (expected — hostile reactions / strategic spawns are Phase 07, D-044).

- 2026-11-12: UI pass done in response (D-046) — new layout, clock badge, "Look closer" chips, findings slip, action buttons that show their consequences. **Awaiting the user's look**: is this the kind of improvement meant, and did "UI" also mean the driving HUD?

- 2026-11-12: "Okay looks good enough for now. Close it 06 and we can move to 07" → **closed**. Further UI polish is welcome later but not blocking.

## Discovered / Deferred
- Multi-page files deferred (single page + findings section).
- First layout had the 4th action button covering the shift clock → paper taller, clock moved next to the title (found by screenshot).
- Tests that run while the file pauses the world need `process_mode = ALWAYS` on the test root.

## Result summary (fill when done)
Built & auto-verified 2026-11-11: `dossier_autotest` (pause, examine cost + unlock, kill bounty/heat, kick, scenic ×1.5, angry kick) and the updated `ride_autotest` PASS; all 15 test runs PASS; file screenshots (before/after examining) checked. User playtest 2026-11-12: all mechanics work as intended; UI improved in D-046 and accepted as good enough for now. **Closed 2026-11-12.**
