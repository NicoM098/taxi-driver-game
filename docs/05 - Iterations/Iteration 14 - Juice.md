---
tags: [iteration]
iteration: 14
status: awaiting playtest
started: 2026-11-16
finished:
---
# Iteration 14 — Juice

## Scope (from user, verbatim)
> "ahora si podemos seguir con el juice. Lo planifiquemos primero antes de implementar" →
> plan presented → **"Core + near miss"**.

## Interpretation
The last of [[Phase 11 - Audio, VFX & Juice]]. Camera shake (with a trauma system), speed FOV
kick, muzzle flash, tracers, impacts, explosions and damage smoke all already exist, and so does
a **full drift-chain system** (`drift_chain.gd`: side-to-side links, ×3 multiplier, speed reward,
cash payout, HUD bar). **Checking that first changed the plan** — "style points" is not missing,
it is missing everywhere except drifting.

Four pieces, in this order (payoff over risk):
1. **Air time** — "CRAZY JUMP". The headline gap, and literally what the user's own Crazy Taxi
   reference screenshot shows.
2. **Hit-stop** on kills — what gives a shot weight.
3. **Skid marks** — leaves a trace of the drifting the game already rewards.
4. **Near miss** — only meaningful now that there is traffic to miss.

**Design rule: one economy.** Air time and near misses pay through the same path drifting uses
(points → `dollars_per_drift_point` → tip while riding, cash otherwise), so the game has one style
currency instead of three.

**OUT of scope:** speed lines on boost (cosmetic, and it would fight the PS1 dither), glass
shatter, windshield cracks, rain, slow-mo, the music track, neighbourhoods, and anything DLain47
is still playtesting.

## Known risks (named before starting)
- **Hit-stop touches `Engine.time_scale`**, which is global and affects physics — and 16 autotests
  run at `--fixed-fps 60`. It is disabled in headless, like the audio; if the suite still moves,
  it comes out.
- **Skid marks z-fight with the asphalt** (KI-017 exists for exactly that).
- **Near miss can spam** in traffic. Gated by relative speed and a per-car cooldown; the number
  most likely to need the user's hands on it.
- Everything here must be **player-only**: `TrafficCar extends Taxi`, so anything put on `Taxi`
  itself would fire for civilians too. The juice lives in a child node of `taxi.tscn`, the way
  `DriftChain` already does.

## Checklist
- [x] `EventBus.style_earned(kind, label, points)` + big transient popup in the HUD
- [x] `RideManager` pays style the same way it pays drifts
- [x] Air time measured and paid on landing; `best_air_time` in the run stats
- [x] Hit-stop + camera trauma on a kill, off in headless
- [x] Skid marks under the rear wheels while sliding
- [x] Near miss: close + fast + no contact, with a cooldown per car
- [x] All 16 autotests still pass

## Acceptance (how the user will judge it)
- [ ] A jump off a ramp feels rewarded, not just survived
- [ ] Killing an enemy has weight
- [ ] Drifting leaves a mark on the road
- [ ] Near misses fire when you earn them, not constantly
- [ ] Nothing feels spammy; the HUD does not become noise

## User test checklist
- [ ] Jump a kicker ramp: does "CRAZY JUMP" land at the right moment and feel earned?
- [ ] Shoot an enemy car dead: is the hit-stop noticeable but not annoying?
- [ ] Handbrake into a corner: are the marks in the right place?
- [ ] Drive fast through traffic: do near misses fire too often, too rarely, or about right?
- [ ] Does the frame rate hold with marks on the road?

## Feedback from user
-

## Discovered / Deferred
- **A real bug the tests could not catch:** `SkidMarks` added its MultiMesh to the world directly,
  which Godot refuses while that parent is still setting up its children. It only showed when
  driving the actual game — every test builds its world by hand. Fixed with `call_deferred`.
- **The near-miss rule had no possible coverage**: the closest another car gets to the player in
  any existing test is 58 m. Hence `tests/style_autotest`, which is now the 17th.
- **`weapon_autotest` is flaky (~1 in 5) and the cause is identified**: `weapon_controller` calls
  `_rng.randomize()`, so the shotgun's 8 pellets scatter differently every run. Logged as KI-036,
  **not fixed** — it is not this iteration's code. One-line fix available (seed when headless).
- `hostiles_autotest` failed once, which is its known KI-032 rate.
- Air time paid nearly double at first — a 1.5 s jump beat a good drift chain. Halved.
- Deferred as planned: speed lines on boost, glass shatter, slow-mo.

## Result summary
The game now rewards more than drifting. Air time pays on landing ("CRAZY JUMP" / "HUGE AIR"),
kills freeze the world for 70 ms with a camera kick, the rear wheels leave rubber on the road, and
passing close and fast scores a near miss — all paying through the drift chain's own economy, so
there is one style currency, and all living on child nodes of `taxi.tscn` so no civilian car
scores anything.

17 autotests pass, including a new `style_autotest` written because the near-miss rule could not
otherwise be covered. Not in a human's hands yet: how often near misses fire is the number most
likely to need moving.
