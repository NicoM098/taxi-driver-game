---
tags: [iteration]
iteration: 5
status: done
started: 2026-11-11
finished: 2026-11-11
---
# Iteration 05 — Energy Drink & Fixes

## Scope (from user, verbatim)
> it feels good enough for now, mirror is nice. i forgot to ask but i have been noticing that with a certain combination of keys i do an instante turn, is that something you added? Also we need to add a healing item that we could drive trough "mountrous energy" and we crack a white monster energy drink to replenish health

## Interpretation
1. **Instant turn** — not intended. Investigate, reproduce with a test, fix.
2. **"Monstrous Energy" healing pickup** — drive through a floating can; first-person "crack and drink" animation; replenishes health. Fictional brand (white can, light-blue band) — no real Monster Energy name/logo/claw (original content rule).
**Out of scope:** carried/inventory items (Phase 08), shop (Phase 09).

## Checklist
- [x] Reproduce + fix the instant turn (autotest)
- [x] `HealthComponent.heal`, `TaxiDamage.drink()` (heal over time)
- [x] `EnergyDrinkPickup` (Area3D, spinning can, respawn) placed in the city (12 intersections) and the range (3)
- [x] First-person drink animation + green heal flash + HUD message
- [x] Pickup autotest; all previous tests PASS

## Acceptance
- [x] No more instant turns.
- [x] Driving through a can heals you and feels good.

## User test checklist
1. [ ] Reverse (S), then press W while still rolling back → the car slows and drives forward, **no instant turn**.
2. [ ] City: white cans with a light-blue band float and spin over 12 intersections (range: 3 on the course). Drive through one: "*CRACK* MONSTROUS ENERGY!", green screen flash, first-person chug, YOU bar +50 and TAXI bar +30 over ~1 s.
3. [ ] The can disappears and comes back after 30 s.
4. [ ] Drink animation: readable / funny / too much in the way while driving?

## Feedback from user
- (mid-build) "the instant turn is awful, should be removed" → already removed (D-041).
- 2026-11-11 (2): "still z-fighting on the asphalt sometimes" → flat surfaces no wobble, no ground under the road, wider/raised dashes (D-043). **recheck**
- "when we spawn hitmen in actual gameplay the spawn should be strategic to block the player from getting to the objective" → design note (D-044), planned in Phase 07.
- "can looks fine, no bug found, will keep testing".
- 2026-11-11 (3): "close it 05 and start with the next one" → closed.

## Discovered / Deferred
- Instant turn = drift angle limiter (D-027) yanking the car 180° when rolling backwards with throttle (S then W): 177° in < 0.5 s, 532°/s. Fixed: limiter only for forward travel (D-041). New autotest `--reverse-throttle`.
- Original-content rule: "Monster Energy" is a real brand → fictional "Monstrous Energy", own colours (white + light-blue band), no logo/claw.

## Result summary (fill when done)
✅ **Closed 2026-11-11.** Carry-over: confirm the asphalt z-fighting fix while playing (KI-017).
Built & auto-verified 2026-11-11: instant turn fixed (177° → 0°); energy drink pickup (heal +50 driver / +30 taxi over 1.2 s, respawn 30 s, 12 in the city, 3 in the range), first-person drink animation, green flash. 14 test runs PASS (9 vehicle scenarios, ride, weapon, enemy, enemy-city, pickup). Screenshots of the can + drink animation checked.
