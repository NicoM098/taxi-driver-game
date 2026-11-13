---
tags: [iteration]
iteration: 4
status: done
started: 2026-11-11
finished: 2026-11-11
---
# Iteration 04 — Enemies & Damage

## Scope (from user, verbatim)
> Okay shooting and arrow feels great lst move on the next logic iteration

Chosen by Claude (user delegated "next logical"): **[[Phase 06 - Damage & Enemy Pursuers]]** — the polished driving + shooting now get something that chases and shoots back. Completes the action core (milestone M4 "Guns out") and is a prerequisite for the passenger archetypes (Phase 07: businessman → hitmen).

## Interpretation
- **Player damage:** taxi body HP, driver HP, passenger HP. Crash damage (ignores jump landings), bullet damage via hitboxes, smoke/fire on the hood, wreck → shift over ("WRECKED"), repaired on the next shift.
- **Enemy cars:** reuse the taxi's raycast physics with an AI driver (chase via a road graph of the city's intersections, direct chase when close, flank alongside, ram, retreat when hurt, unstuck), a gunman shooting bursts with line of sight, health + driver hitbox, destruction (fire, explosion hop, despawn), bounty + heat.
- **EnemyDirector:** spawn pursuers behind the player, despawn far ones, heat decay, police placeholder at heat ≥ 3, debug key F7.
- **HUD:** taxi/driver HP bars, heat stars, damage-direction indicator, red hit flash, "WRECKED" summary.
**Out of scope:** navmesh (replaced by road graph — D-035), GPS line, traffic, ride events spawning hitmen (Phase 07), repairs shop (Phase 09).

## Checklist
- [x] Hitbox `hit` signal + source; player weapon ignores own hitboxes
- [x] `TaxiDamage` (taxi/driver/passenger HP, crash + bullet damage, smoke/fire, wreck, repair)
- [x] City road graph (AStar3D over 9×9 intersections) + route queries
- [x] `EnemyCarData` + hitman sedan / police cruiser
- [x] `EnemyCar` (extends Taxi physics), `EnemyDriverAI`, `EnemyGunner`
- [x] `EnemyDirector` (spawn/despawn, bounty, heat, police, F7)
- [x] HUD: HP bars, heat, damage direction, hit flash, wreck summary
- [x] Ride fails if the passenger is shot; shift ends on wreck
- [x] Enemy autotest; all previous tests still PASS

## Acceptance (how the user will judge it)
- [x] F7 spawns hitmen that chase, ram and shoot; you can kill them.
- [x] Getting shot is readable (where from, how hurt).
- [x] Difficulty: neither too dumb nor unfair.

## User test checklist
F5 → city (or F3 → shooting range). **F7 spawns two hitmen** (red cars) out of sight behind you.
1. [ ] They find you through the streets and chase; when you drive they pull alongside and shoot; sometimes they ram.
2. [ ] Stop the taxi: they hold ~9 m away and shoot instead of crowding you.
3. [ ] Getting shot: red wedges show the direction, red screen-edge flash, TAXI / YOU bars drop (top-left). Readable?
4. [ ] Shoot back: hit flash on the car, driver's window ×2.5, smoke when hurt, on kill it burns and hops, "+$40 HITMAN DOWN", HEAT star.
5. [ ] Ram them: crashes hurt both cars (hard crashes hurt you too — not jump landings).
6. [ ] Taxi < 50 % → smoke from the hood, < 20 % → fire.
7. [ ] Get wrecked / shot dead → shift ends with "WRECKED!" / "SHOT DEAD!", next shift repairs you. (Range: auto-repair after 4 s.)
8. [ ] With a passenger aboard: a FARE bar appears; if they get shot the ride fails.
9. [ ] Kill 3 → heat 3 → a police cruiser (blue, sirens) joins every 20 s. Heat drops by one every 45 s without kills.
10. [ ] Overall difficulty: too dumb / too deadly?

## Feedback from user
**2026-11-11 playtest (1):**
- Damage still too high → bullet damage −40 %, more spread, body/crash damage reduced (D-038). Measured survival next to two hitmen ~10 s → ~30 s. **recheck**
- Crashing into hitmen gets you stuck → killed cars explode and vanish instantly; enemies lighter than the taxi; no rams on a parked taxi (D-038, D-039). **recheck**
- Need to watch our backs → working rear-view mirror + edge threat markers with distance (D-040).

**2026-11-11 (2):** "it feels good enough for now, mirror is nice" → closed.

## Discovered / Deferred
- Navmesh replaced by a road graph (D-035); GPS line still deferred.
- City test found hitmen crowding a parked taxi (1.7 m, stuck loops, constant bumping) → standoff hold, early braking on approach, ram ends on contact (D-036). Also found a test bug that made the damage look 5× too high (observation window never ended).
- Enemy hit flash restored the wrong material (would turn white) — fixed before running.
- Screenshot runs must release the mouse: the real mouse moved the view (camera stared at the floor) — fixed in the test.
- Simulated F7 via `--hold` doesn't register as "just pressed" on physics ticks (test-input quirk, KI-013) — real key presses fine.

## Result summary (fill when done)
✅ **Closed 2026-11-11** — user: good enough for now, mirror is nice.
Built & auto-verified 2026-11-11: import clean; `enemy_autotest` (road graph, chase, shooting, bounty/heat, crash damage, wreck + repair) and `enemy_city_autotest` (2 hitmen through the city, standoff around a parked taxi, 5/5 runs) PASS; all earlier tests PASS; screenshot of two hitmen holding standoff and shooting checked. Pending user playtest.
