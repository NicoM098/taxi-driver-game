---
tags: [iteration]
iteration: 17
status: active
started: 2026-11-16
finished:
---
# Iteration 17 — Gang Rides (the game without the passenger file)

## Scope (from user, verbatim)
> "when entering a green zone with a passenger it automaticall delivers him instead of you having
> to stop, then i want to test the game without the papers please feature, we will try the game
> without it, now the events of the passengers will be anounced in text. So now we will add
> different gangs lets say red, purple and orange. Each of these gangs will ahve its spawn zone, if
> you pickup a gang member, then the other gangs have a chance to come for you. Or if you pickup
> the granny she will still give you the perk drop, then the difficulty of the drive is random.
> Lets start with this and we will polish everything, lets not permanently delete the previous
> feature but lets just isolate it for the time being, implement the new feature as its own script
> so we have it locallized"

## Interpretation
- **A trial, not a removal.** The passenger file (Dossier) is switched off by one flag,
  `GangRides.enabled` (static, `src/gang_rides/gang_rides.gd`). `false` = the old game exactly.
  The Dossier code, its UI, the file actions and their tests are untouched.
- **Auto-delivery:** entering the destination ring delivers at any speed (gated by the same flag).
- **"Announced in text":** a ride card (top left) when the fare gets in: name, gang or job, the
  ride's difficulty, the destination, and in plain words what the passenger's ride events may do
  (what the file used to hide behind "examine"). The events themselves still bark / alert when
  they fire, as before.
- **Gangs:** Red Fangs, Purple Hounds, Orange Jackals (`data/gangs/*.tres`, original names). The
  "spawn zone" is where their members wait for a cab. Each gang owns one district of the map
  (gangs and districts each sorted by name, paired in order); a map with fewer districts than
  gangs is cut into pie slices around the centre of its stops instead.
- **Gang member picked up → each rival gang rolls** whether it comes for the taxi; their own cars
  (gang colour) arrive mid-ride, placed on the route like any ride-event pursuers.
- **The granny** is unchanged data: she still hands out her gift on arrival (the ride is always
  started as plain "drive", so it is her small gift; "carry her bags" was a file action).
- **Random difficulty** per ride: EASY / NORMAL / HARD / DEADLY changes the clock, the pay and how
  hard the gangs come.

## Design (D-088)
| Difficulty | Chance | Clock | Pay | Each rival gang comes (gang fare) | Cars per crew | A random crew hits an ordinary fare |
|---|---|---|---|---|---|---|
| EASY | 30 % | ×1.25 | ×0.8 | 25 % | 1 | never |
| NORMAL | 35 % | ×1.0 | ×1.0 | 45 % | 1 | 10 % |
| HARD | 23 % | ×0.85 | ×1.4 | 70 % | 2 (+1 at 40 %) | 35 % |
| DEADLY | 12 % | ×0.75 | ×2.0 | 95 % | 3 (+1 at 40 %) | 70 % |

| Gang | Zone (built-in city) | Car | Flavour |
|---|---|---|---|
| Red Fangs | downtown | 85 hp, heavier, rams more | brawlers |
| Purple Hounds | suburbs | 70 hp, long-range bursts, rarely rams | shooters |
| Orange Jackals | docks | 60 hp, fastest | chasers |

- Gang members: up to 3 waiting at once (any gangs), one attempt every 9 s, only at stops of their
  own zone inside the spawner's ring around the taxi. Wear the gang colour. Fare $55-70 + $14-18
  per 100 m (dangerous fares pay well), 220-520 m rides, a greeting line.
- A crew fires at a random point between 12 % and 60 % of the ride; pattern tail / ambush ahead /
  pincer at random. Alert "<GANG> ARE COMING FOR YOU" + the passenger's panic line.
- The tutorial fare is always EASY and never draws a crew.

## Checklist
- [x] `GangRides` (flag, zones, member spawning, difficulty, crews, ride card text) + `GangData`
- [x] `RideCard` (HUD, native resolution) on the new `EventBus.ride_announced`
- [x] `RideManager`: skip the file / deliver without stopping when the flag is on (2 gated lines)
- [x] Three gangs: `data/gangs/`, `data/enemies/gang_{red,purple,orange}.tres`, materials
- [x] Tutorial: no FILE step in this mode; texts
- [x] New `tests/gang_rides_autotest` (A-G); legacy tests (dossier, events, heat_passengers,
      hostiles) run with the flag off; tutorial test covers both modes

## User test checklist
- [ ] Does the game feel better without the file? What is missed?
- [ ] Auto-delivery: does it ever deliver by accident when just driving past?
- [ ] Is the ride card readable while driving? Too long, too short?
- [ ] Gang members: easy to tell apart (colour) at the stop? Do they show up often enough?
- [ ] Rival crews: too many / too few? Are DEADLY rides worth the pay?
- [ ] The granny's gift still arrives.

## Feedback from user
-

## Discovered / Deferred
- Gang members wait under the same yellow beam as everyone else; only their body has the colour.
  A coloured beam / minimap blip per gang is polish for later.
- Zones are not drawn anywhere (minimap, world). The player cannot see where a gang's turf is.
- Gangs do not fight each other, and a crew does not care which zone you are in.
- `change_destination` (detour events) recomputes the clock without the difficulty multiplier.
- The file-only actions are gone in this mode (overcharge, hazard pay, turn in, kill, the granny's
  bags...), so their consequences are too.
- Zones by district map docks → orange, downtown → red, suburbs → purple only because of sorting.

## Result summary (fill when done)
