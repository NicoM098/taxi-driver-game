---
tags: [iteration]
iteration: 7
status: closed
started: 2026-11-12
finished: 2026-11-12
---
# Iteration 07 — Archetypes & Ride Events

## Scope (from user, verbatim)
> Okay looks good enough for now. Close it 06 and we can move to 07

"07" = what was proposed at the end of Iteration 06: **[[Phase 07 - Passenger Archetypes & Ride Events]]** — passengers with real twists and consequences, including the strategic hitman spawns (D-044). The user's playtest note "none of them spawn a hostile yet" is answered here.

## Interpretation
- A **ride-event framework**: passengers are built in data from reusable blocks that fire on triggers (time / distance / progress / arrival / kicked out).
- **Five new archetypes** (8 in total): Old Lady, Businessman, Burglar, Hijacker, Expectant Mother. The Rushed Executive gets a consequence for taking his hush money.
- **Strategic hitman spawns**: on the player's route to the destination (ambush ahead / pincer / tail), never in view.
- **New player verb: kick the passenger out mid-ride** (`kick_out`: Q / d-pad ↓ — the action was already bound in the input map since Phase 00 but unused). It is the counter to the burglar and a (costly) way out of a hijack.
- Shift summary records kicked / shot passengers, hitmen destroyed and cash stolen.
**Out of scope:** real items (the old lady's gift is heal / ammo / cash / time until Phase 08), screen effects (drunk passenger), mystery courier, portraits/animation, audio.

## Phase tasks covered
- [[Phase 07 - Passenger Archetypes & Ride Events]] → event framework, strategic spawns, 5 archetypes, weighted spawner with `min_shift`. Not done: `ScreenEffectEvent`, real `DropItemEvent` (Phase 08).

## Checklist
- [x] `RideEvent` base + `RideContext` + `RideEventRunner` (per-ride state outside the shared resources; flags; action conditions)
- [x] Blocks: `DialogueEvent`, `SpawnPursuersEvent`, `StealCashEvent` (counter window), `ForceDetourEvent`, `PassengerAttackEvent`, `TimerModifierEvent`, `HeatChangeEvent`, `RewardEvent` (stand-in for DropItem)
- [x] `RideManager`: runner integration, mid-ride kick, `change_destination`, `fail_ride`, completion text
- [x] `EnemyDirector.spawn_on_route` (ambush_ahead / pincer / tail) + line-of-sight check; `EnemyDriverAI` AMBUSH mode
- [x] HUD: passenger subtitles, flashing alert with countdown, kick hint, extended shift summary
- [x] 5 new profiles + executive "followed" event; `PassengerProfile.ride_events / min_shift / kick_damage`; `PassengerAction.shift_time_delta`
- [x] Spawner: `min_shift` filter; **F8** debug = put the next archetype at the nearest stop
- [x] `tests/events_autotest` (strategic spawns + every archetype) PASS; all older tests PASS
- [x] User playtest (2026-11-12)
- [x] Playtest fixes built & auto-verified (D-051…D-054)
- [ ] User re-test of the fixes — **not done**: the user closed the iteration without it (2026-11-12, "close it07"). The fixes get exercised during the Iteration 08 playtest; anything wrong is fixed there.

## Acceptance (how the user will judge it)
- [ ] Each passenger's twist is understandable from the file (fair but not obvious).
- [ ] Hitmen ahead on the route change how you drive (block / intercept), not just a tail.
- [ ] Kicking a passenger out mid-ride feels right as a verb.

## User test checklist
F5. **F8** puts the next archetype at the nearest stop (cycles through all 8, message says where). F7 still spawns two hitmen.
1. [ ] **Old Lady** — pays almost nothing; on arrival she hands you something (subtitle shows what: health / ammo / cash). Examine *the knitting bag* → **Carry her bags** (−6 s shift clock) → better gift. Kick her out → *WHACK*.
2. [ ] **Businessman** — huge fare. A little into the ride: "They've found me!" → hitmen **ahead and behind**. Is the one ahead where you'd expect to run into it (on your way, around a corner)? Sometimes a second ambush near the end. Examine *the letter* → **hazard pay (+60 %)** or **collect the contract (kill, +$150, +2 heat)**.
3. [ ] **Burglar** — around the middle of the ride: flashing **THIEF! Q: THROW THEM OUT** with a 3.5 s countdown. Press **Q** (d-pad ↓) in time → he's out and drops $25. Too late → he takes 30 % of your cash and jumps out. Examine *his pockets* → **shake him down** from the file (+$35).
4. [ ] **Hijacker** (random spawns from shift 2; F8 any time) — a few seconds in: "The docks." New destination, no fare. Drive slower than ~25 km/h for 3 s → he shoots (−10). At the docks he takes 20 % of your cash. Counters: examine *his coat pocket* → **shoot first**; or **Q** mid-ride (he shoots on the way out, −25).
5. [ ] **Expectant Mother** — very tight clock, big fare, barks, sometimes a contraction (−4 s). Examine *her breathing* → **promise** (double fare, even less time). Doable? Too tight?
6. [ ] **Rushed Executive** — take the hush money → a hitman tails you mid-ride.
7. [ ] **Q mid-ride on a normal passenger** — ends the ride without fare. Is a single key press too easy to hit by accident?
8. [ ] Subtitles readable (bottom, pale yellow)? Alert noticeable while driving?
9. [ ] Shift summary shows kicked / shot / hitmen down / stolen.
10. [ ] Mix: does a normal shift feel varied? Which archetype is most / least fun?

## Feedback from user
- 2026-11-12 (end of day): "document where we left off and I test tomorrow".
- **2026-11-12 playtest (verbatim):** "lady works. business man works but the hitmans are quite easy to avoid if you jut head straight to the point, lets make it so when we finish the drive the remaining hitman keep chasing us. Burglar options work fine, hijaker also. Rushed executive as well- ending the fare shouldnt be allowed.subtitles need a bolder font. The countdown for the passengers should be positioned below the arrow in bold red letters as soon as the timer starts. The timer for the game itself needs to be removed, was never part of the game, then we will build the bases for an open world map, then we will add different neighborhoods that will have different storylines and people inside.We will also have shops to upgrade stuff with our money, armory, bodyparts, items for the dashboard, perks, etc"
  - Old lady ✅, businessman ✅ (hitmen too easy → D-053), burglar ✅, hijacker ✅, executive ✅.
  - "Ending the fare shouldn't be allowed" → D-052 (Claude's reading: checklist item 7, Q on a normal passenger. Q still works against the burglar's theft and the hijacker).
  - Subtitles bolder, countdown under the arrow in bold red → D-054.
  - Game timer removed → D-051.
  - Not mentioned: expectant mother (item 5), shift summary (item 9), variety (item 10).
  - Roadmap (open world → neighbourhoods → shops) recorded in [[Development Plan]]; **not started** — needs scope.
- **2026-11-12 (later, verbatim):** "close it07 and give me the it 08hecklist" → closed. The re-test checklist below was not run by the user.

## Re-test checklist (after the fixes)
1. [ ] No clock at the top any more; nothing ends the run except a wreck. After a wreck: summary → E → repaired, back on the road.
2. [ ] On pickup the red bold countdown appears right under the arrow immediately; destination + distance in small text above the arrow. Readable? Right size?
3. [ ] Subtitles bold enough now?
4. [ ] **Businessman:** deliver him with hitmen alive → they keep coming after the drop-off; the one waiting ahead comes hunting if you take another street; outrun them → they show up behind you again (twice), then you can really lose them. Too much / too little?
5. [ ] **Q on a normal fare does nothing** (hint no longer shows it). Q still throws out the burglar during THIEF! and the hijacker after "The docks." — is that what you meant?
6. [ ] Passenger file: badge now says RIDE TIME; looking closer takes seconds off that passenger's clock (was the shift clock). Keep that cost, or should looking closer be free?
7. [ ] Expectant mother (not mentioned in the first playtest): doable? Her thank-you is now a $30 tip.

## Discovered / Deferred
- `ScreenEffectEvent` (drunk sway) and the mystery courier deferred — no archetype in this iteration needs them.
- `DropItemEvent` waits for Phase 08 items; `RewardEvent` covers heal / ammo / cash / shift time meanwhile.
- `tools/check_profiles` became a scene (`.tscn`): run with `--script` the event scripts fail to compile because autoloads don't exist in that mode.
- Bash heredocs with GDScript content broke twice in the tooling ("unexpected EOF") → files are written directly instead.
- The ride test now boards a commuter explicitly (random archetypes would make it flaky).
- Ambushers show up in the HUD threat markers when out of view — acceptable as a warning; revisit if it spoils the surprise.

## Result summary (fill when done)
Built & auto-verified 2026-11-12: `events_autotest` PASS ×4 (ambusher 0 m off the route, 92 m ahead, out of sight, parked until the taxi is 30 m away; pincer 1 ahead + 2 behind; businessman 2–3 hitmen; burglar robbed 30 % / caught +$25; kick input; hijack to the docks, shot when parked, robbed on arrival; old lady gifts; timer / heat blocks; `min_shift`). All 16 older test runs PASS, import clean, Main smoke clean, 3 HUD screenshots checked. User playtest 2026-11-12: all archetypes work; fixes D-051…D-054 built the same day (all 17 test runs + `check_profiles` PASS, import clean, HUD + file screenshots checked). **Closed by the user 2026-11-12** without a separate re-test of D-051…D-054 (auto-verified only; they are in play during the Iteration 08 playtest). Deferred: screen effects, mystery courier, real item drops.
