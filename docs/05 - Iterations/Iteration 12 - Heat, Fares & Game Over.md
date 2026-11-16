---
tags: [iteration]
iteration: 12
status: active
started: 2026-11-15
finished:
---
# Iteration 12 — Heat, Fares & Game Over

> Built on the temporary branch `temp/playtest-merge` = this repo's Iterations 09-10 **+** Nico's branch
> `feat/visuals-and-audio` (his Iterations 09 Texture Pass, 10 Lights & Night, 11 Audio). See D-069.
> Numbered 12 because both branches already used 09-11.

## Scope (from user, verbatim)
> "i need the heat to be a little more aggresive and the street gangs to appear as well when heat is high, lets say that somebody put a reward on our head. also lets make it so the guns have a little bit less bullets so we need to go to the armory a bit more frequently. i also addded a song file to loop while on the game, and i would need an options menu for the volume. Then i would like he passengers to be procedarully generated, they become way too repetitive with fixed spawns, and lets add more variety to the drop off zones, they are always the same as well"

Follow-ups the same day:
> "lets add that you can kill pedestrian cars but it gives you heat witht he police, as well asrunning over pedestrians."
> "add an indicator over hostile vehicles, they can be confused with the civil ones"
> "when your lige runs out you explode and have to start again from the main menu, also the difficulty is now really hard so make it in between"
> "im still getting the wrecked message and still able to drive" → the TAXI bar also kills.

## Interpretation
- "Reward on our head" = a heat threshold above which street-gang cars hunt the player in waves, on top of the police.
- "Less bullets" = smaller *reserve* (spare rounds); magazine sizes unchanged.
- "Procedurally generated" passengers = generated alongside the hand-made archetypes (which keep the special mechanics), not replacing them.
- "More variety to the drop off zones" = more stops (generated along the kerbs) + no repeats.
- "Life runs out" = either bar (YOU or TAXI) at 0 ends the run. Repair shops still fix damage for cash before that.
- OUT of scope: shooting pedestrians, traffic rules, a save/continue, the docs clash with Nico (handled as bookkeeping, D-069).

## Checklist
- [x] Heat: police from 2★, price on your head from 4★ (gang waves) — D-070
- [x] Ammo reserves cut — D-072
- [x] Music loop in game + OPTIONS menu (main + pause) with saved volume sliders — D-071
- [x] Procedural passengers (60 % of spawns) — D-073
- [x] Curbside drop-offs + no repeat of the last 8 — D-074
- [x] Destructible civilian traffic; crimes against civilians give heat — D-075
- [x] Red marker over hostile cars — D-076
- [x] Death: explosion → GAME OVER → main menu (both bars) — D-077
- [x] Difficulty re-tuned "in between" — D-070 / D-072 / D-073 numbers are the final ones
- [x] New test `tests/heat_passengers_autotest` (A-H); ride / weapon / shop / map tests updated
- [x] Build 0.10.5 exported (`build/TaxiDriver-0.10.5-windows.7z`, 28.7 MB, sent to the user)
- [x] Push `temp/playtest-merge` — pushed 2026-11-16 after DLain47 accepted the collaborator invite

## User test checklist
- [ ] Get 2★: police show up; 4★: "THERE'S A PRICE ON YOUR HEAD!" and gang cars come in waves. Too much / too little?
- [ ] Run out of spare ammo and refill at a gun shop: is the armory trip frequency right?
- [ ] Music plays in a run, keeps going in the pause menu, stops in the menu / editor. OPTIONS sliders change Master / Music / Effects / Engine and are remembered after a restart.
- [ ] Generated passengers: do they feel varied? Do their file details (envelope, badge, "followed"...) and the extra choices make sense?
- [ ] Drop-offs on `TEST1`: different places every ride (13 map stops + ~25-28 curbside ones)?
- [ ] Shoot / ram a civilian car until it explodes → +1★ and police soon after. Run a pedestrian over → +1★.
- [ ] Red marker: hostile cars obvious at a distance, at night, never on civilians?
- [ ] Empty either bar: cab explodes, GAME OVER with stats, MAIN MENU starts a fresh run.

## Feedback from user
- (playtest of 0.10.4) "im still getting the wrecked message and still able to drive" → the TAXI bar still meant limp mode; fixed in 0.10.5 (D-077).
- "the difficulty is now really hard" → numbers moved half-way back (D-070).

## Discovered / Deferred
- Pedestrians cannot be shot (only run over). KI-030.
- The song is a third-party track in a **public** repo (user chose to include it). KI-034.
- `hostiles_autotest` "gang_courier: 1 cars walled in" ~1 in 5, pre-existing. KI-032.
- Nico's code comments still say D-061…D-068 for what this log calls DV-061…DV-068.

## Result summary (fill when done)
