---
tags: [design, passengers]
---
# Passengers & Encounters

## 1. Passenger flow
1. Taxi is in "available" state and slow/stopped in a pickup area (or a passenger flags you and you stop next to them).
2. Passenger **gets in** (door animation / sound).
3. **Dossier opens** — 1–3 pages: photo, name, age, occupation, destination, notes, red flags. Some details are **examinable** (highlighted).
4. Player picks an **action**. Available actions depend on the passenger + what has been examined + player perks/items.
5. Ride begins (or the passenger leaves / dies).
6. **Ride events** fire on triggers (time elapsed, distance, damage taken, arrival, etc.).
7. **Outcome** resolves: money, items, heat, time bonus.

## 2. Actions
| Action | Always available? | Notes |
|---|---|---|
| Drive | Yes | Accept the fare. |
| Kick out | Yes | No fare. Some passengers react (shoot, curse, thank you). |
| Examine X | Per passenger | Reveals hidden info, may unlock new actions. Costs a few seconds of that passenger's ride clock (D-051; there is no shift clock). |
| Kill | Only if prompted | Unlocked by examining / passenger traits (e.g. bounty, armed hijacker). |
| Special | Per passenger | Bizarre twists: "Drive to the river instead", "Call the number on the card", "Accept the bribe"… |

## 3. Data model (summary — see [[Architecture]])
`PassengerProfile` (Resource):
- `id`, `display_name`, `portrait`, `archetype`
- `dossier_pages: Array[DossierPage]` (text, image, `examinables: Array[Examinable]`)
- `fare_base`, `tip_multiplier`, `destination_tags` (e.g. "downtown", "docks")
- `actions: Array[PassengerAction]` (id, label, conditions, outcome)
- `hidden_traits: Array[StringName]` (e.g. `&"thief"`, `&"targeted"`, `&"armed"`)
- `ride_events: Array[RideEvent]` (trigger + effect)
- `spawn_weight`, `min_shift`, `districts`

## 4. Archetypes (initial list)
| Archetype | Pays | Twist | Examine reveals | Special actions |
|---|---|---|---|---|
| **Old lady** | ~Nothing | Drops a random item on arrival (health kit, ammo, lucky charm) | Knitting bag full of… grenades? | Help with bags (+time cost, better item) |
| **Businessman** | Very high | Hitmen spawn in 1–3 cars and chase you | Briefcase is handcuffed to wrist; "contract" letter | Kill him for the bounty; deliver him to the rival |
| **Burglar** | Medium (fake) | Steals % of your cash mid-ride unless caught | Bulging pockets, fake ID details mismatch | Kick out early; shoot him; lock doors (perk) |
| **Hijacker** | — | Pulls a gun, forces a detour | Gun outline under jacket | Kill on the spot if spotted |
| **Pregnant woman** | Medium | Very tight timer, huge tip | Contractions timer | — |
| **Drunk partier** | Low-med | Screen sway/vision blur; may puke (tip loss) | Bottle | — |
| **Cop (undercover)** | Medium | Lowers heat; may ask you to chase a car | Badge | Join the chase (bonus) |
| **Gang member** | High | Rival gang chases; friendly gang gives discounts later | Tattoos | Betray to rival gang |
| **Mystery package courier** | High | Package is ticking… | Ticking sound | Throw package out the window |
| **Tourist** | Medium | Wants scenic route (bonus for landmarks) | Camera, map | — |

Bizarre ideas backlog: a dog in a suit, a man who claims to be from the future, a ghost that vanishes mid-ride, a hitman who wants a ride *to* his target (you).

## 5. Ride events (reusable building blocks)
- `SpawnPursuers(count, archetype)` — enemy cars chase. **Spawn strategically (user request 2026-11-11):** in real gameplay hitmen must not only appear behind you — place some *ahead on your route to the destination* (on the road-graph path between taxi and drop-off) so they block / intercept / force a detour, e.g. a car parked across the next intersection, a pair converging from side streets, one tailing from behind. Variants per archetype: `ambush_ahead`, `pincer` (front + back), `tail`. Never spawn in the player's direct view (keep the out-of-sight rule).
- `StealCash(percent)` — burglar theft (counterable).
- `ForceDetour(destination)` — hijack.
- `ChangeDestination()` / `TimerModifier(x)`.
- `DropItem(item_table)` — on arrival or on death.
- `PassengerAttacks(damage)` — hostile passenger.
- `ScreenEffect(effect)` — drunk sway, smoke…
- `Dialogue(lines)` — passenger barks during the ride.
- `HeatChange(amount)`.

New passengers should be built from these blocks; a new *block* = new code.

## 5b. Hostile situations added 2026-11-13 (D-059)
**Passengers:** Bank Robber (police chase from the pickup; "half the bag" x2 fare, or hand him in for $60), Key Witness (bruisers parked across the route, hitmen behind; promise x1.6, or sell her out for $130), Gang Courier (rival gang cars within seconds; danger money x1.5, or keep the package for $90).

**Street encounters** (no passenger needed, `data/events/`): gang drive-by · cash robbery crew (carrying $250+) · roadblock (fare aboard) · payback (after 3 kills) · turf war (level 2+, no fare). One is rolled after a quiet stretch; each can be limited to districts, which is how neighbourhoods will get their own trouble.

**Enemy types:** Hitman (shoots, flanks), Police (heat), **Bruiser** (heavy, unarmed, rams), **Street Gang** coupe (fast, fragile, sprays bullets).

## 5c. Added 2026-11-15 (D-066, data only)
Dog in a Suit (lost: take him home for x2.5) · Night-Shift Nurse (heals you on arrival for half fare) · Man From the Future (level 2+, predicts the ambush ahead) · Street Musician (cash in the guitar case: gang tail, or keep it).

## 5d. Street life (D-065)
Pedestrians on the curbs (dodge, flee gunfire, can be run over — no consequence yet) and civilian traffic in the right-hand lane, spawned around the player.

## 6. Balancing knobs
Spawn weights per district & shift number, fare ranges, pursuer counts, theft %, examine time cost.
