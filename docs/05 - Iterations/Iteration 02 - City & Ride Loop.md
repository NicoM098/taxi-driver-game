---
tags: [iteration]
iteration: 2
status: done
started: 2026-11-11
finished: 2026-11-11
---
# Iteration 02 — City & Ride Loop

## Scope (from user, verbatim)
> close it 01 and move on to the next one

Next one = the scope proposed at the end of Iteration 01 and accepted: **[[Phase 02 - City Graybox & Navigation]] + [[Phase 03 - Core Ride Loop]] + the drift chain** ([[Game Design Document]] §3b).

## Interpretation
A playable "Crazy Taxi skeleton": endless shifts in a blockout city — find a waiting passenger, stop next to them, they get in, drive them to their destination before their timer runs out, get paid (fare × speed bonus + drift tips), shift time bonus, shift summary, next shift.
**Out of scope (deferred):** dossier/decisions (Phase 04), navmesh + GPS line (moved to Phase 06 where AI needs it — D-022), traffic cars (later), textures.

## Checklist
### Phase 02 — City
- [x] Procedural blockout city 8×8 blocks, 3 districts (suburbs W / downtown centre / docks E), plaza, street ramps, lane dashes
- [x] TaxiStops on block sides (named places per district) — pickup & drop-off points, destination beacon + ring
- [x] Guide arrow on the dashboard (yellow → nearest passenger, green → destination) + distance
### Phase 03 — Ride loop
- [x] `PassengerProfile` resource + 3 profiles in `data/passengers/`
- [x] PassengerSpawner (waiting passengers with marker beams)
- [x] RideManager state machine (IDLE → ENTERING → RIDING → EXITING), fares, speed rating, time bonus
- [x] ShiftManager (endless shifts, timer, summary, next shift)
- [x] HUD (shift timer, cash, ride panel, speed, drift, messages, hints, summary)
### Drift chain
- [x] DriftChain node: links, multiplier, banked points, speed boost per link, break on crash
- [x] Drift money → ride tip / style cash
### Verification
- [x] Ride autotest (pickup → deliver → pay, fail, shift end/restart)
- [x] Drift-chain autotest scenario
- [x] Vehicle regression autotests still PASS; screenshot check

## Acceptance (how the user will judge it)
- [ ] Shift loop is playable and fun for a few shifts.
- [ ] Finding passengers & destinations is clear (beams, arrow, ring).
- [ ] Drift chains feel rewarding (speed + money).

## User test checklist
F5 → the first shift starts after 1 s (2:30 on the clock).
1. [ ] Follow the **yellow dashboard arrow** / **yellow beams** to a waiting passenger; stop next to them (<9 km/h). They board.
2. [ ] The arrow turns **green**; the HUD shows destination, distance and ride timer. Find the **green beacon & ring**, stop inside. Paid + time bonus?
3. [ ] Are ride timers fair (too tight / too loose)? Does the shift length (150 s + bonuses) feel right?
4. [ ] **Drift chain:** at speed, flick left/right with handbrake taps → `DRIFT xN` + bar, speed boost per link. Fun? Money ("DRIFT TIP" with a passenger, "STYLE" without)?
5. [ ] Crash hard mid-chain → "DRIFT CHAIN LOST!".
6. [ ] Let the shift run out → summary → E / Enter / D-pad ↑ starts the next shift.
7. [ ] City: districts readable (suburbs W, downtown centre, docks E)? Street ramps & plaza kicker fun? Big enough / too big?
8. [ ] Is the guide arrow readable? Are the passengers/beams easy to spot?
9. [ ] Low-speed handbrake still gentle? (should be unchanged)

## Feedback from user
**2026-11-11 playtest (1):**
- "Game feels like as soon as you hit the space bar the car does a 180" → reproduced (`--handbrake-high`: 180° drift angle), fixed with drift angle limiter (D-027): max ~50°, controlled handbrake turn. **recheck**

**2026-11-11 playtest (2):**
- Arrow mispositioned (looks like clipping into the car); wants it top-centre like the classic games → camera-attached compass arrow drawn on top (D-028). **recheck**
- Rides too short ("2 seconds away") → distances roughly doubled + robust destination fallback (D-029). **recheck**

**2026-11-11 playtest (3):**
- "Car is undriveable with the current drift chain settings" → handling reverted to the approved Iteration 01 tune (drift assist off), drift chain now handbrake-initiated with a smooth speed reward (D-030).

**2026-11-11 (4):** "driving is manageable now, lets start with the shooting before adding the mechanics so we can polish the basics of driving" → Iteration 02 closed; next = Phase 05 shooting.

## Discovered / Deferred
- Navmesh, GPS line, traffic → deferred (D-022).
- Drift chain needed speed-gated drift assist (D-025) — found by the new `--drift-chain` autotest.
- Road plane z-fought with the ground plane 2 cm below (fixed, moved to -0.3 m) — found by screenshot.

## Result summary (fill when done)
✅ **Closed 2026-11-11** — user: driving manageable, move on to shooting.
Delivered: procedural city (3 districts, 128 named stops, ramps), passengers (3 data profiles), ride loop (pickup/deliver/rating/time bonus), endless shifts + summary, HUD, top-centre compass arrow, handbrake-initiated drift chain (money + smooth speed reward), drift angle limiter. Tests: 8 vehicle scenarios + ride integration test.
Not explicitly confirmed by the user (carry over, revisit when polishing): ride timer & money balance (KI-007), shift length, city size, drift chain fun, gamepad (KI-002).
