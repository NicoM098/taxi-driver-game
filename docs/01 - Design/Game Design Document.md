---
tags: [design, gdd]
status: living-document
---
# Game Design Document

> Living document. Change it when the design changes and note why in [[Decisions Log]].

## 1. Pillars
1. **Speed & chaos** — arcade driving, near misses, big jumps, time pressure.
2. **Judge your fare** — every passenger is a little puzzle: read the file, decide, live with it.
3. **Guns out the window** — first-person shooting while driving, simple to control, satisfying to land.
4. **Risk vs reward** — the best-paying passengers are the most dangerous ones.

## 2. Perspective & controls
- **Camera:** first-person, driver's seat. Visible dashboard, steering wheel, hands, mirrors. Free mouse-look (clamped) inside the cab.
- **Driving (arcade, simple):** accelerate / brake-reverse / steer / handbrake / boost (unlockable). No manual gears, no clutch, no per-hand steering.
- **Shooting (Half Grip-inspired, simplified):** aim with the mouse/right stick freely while driving; hold a button to raise the gun, click to fire, reload button. Steering stays on the keyboard/left stick, so you can drive and shoot at once.
- **Dossier:** when a passenger enters, the game slows (or the car is stopped) and the file opens. Read pages, tap highlighted details to **examine**, then pick an action.

Draft bindings — **KB+M and controller both supported from the start** (Xbox layout naming):
| Action | KB+M | Controller |
|---|---|---|
| Accelerate / Brake-Reverse | W / S | RT / LT |
| Steer | A / D | Left stick X |
| Handbrake | Space | B |
| Boost | Shift | A |
| Look / Aim | Mouse | Right stick (with aim assist/slowdown TBD) |
| Raise gun (hold) / Fire | RMB / LMB | LB (hold) / RB |
| Reload | R | X |
| Switch weapon | 1–4 / wheel | Y (cycle) / D-pad |
| Open dossier / interact | E / Tab | D-pad up / View |
| Kick passenger out | (contextual from dossier, or hold Q) | (contextual) |
| Pause | Esc | Menu/Start |

Note: on controller, triggers drive and bumpers shoot, so driving + shooting never conflict. Dossier must be fully navigable with the D-pad/stick (focus-based UI).

## 3. Core loop
**Moment-to-moment:** drive → dodge traffic → shoot threats → reach the drop-off zone.
**Ride loop:** passenger enters → dossier → decision → ride (+ events) → payout/consequence.
**Run structure (changed 2026-11-12, D-051): open world, NO shift clock.** The user: the game timer "was never part of the game". You cruise the city freely; the only countdown is each passenger's own ride clock. A run ends only when the taxi is wrecked or the driver is killed (summary → back on the road). Difficulty goes up with delivered passengers. **Direction:** an open-world map made of neighbourhoods, each with its own storylines and people, plus shops where money buys upgrades (armory, body parts, dashboard items, perks) — see the roadmap in [[Development Plan]].

*(Old design, superseded: a shift was a time budget, rides added bonus time, the shift ended when time ran out.)*
**Meta loop:** between shifts → shop (guns, ammo, perks, taxi upgrades, repairs) → next shift with harder passengers/heat.

## 3b. Drift Chain (requested by user 2026-11-11)
Reward flowing, stylish driving: **drifting from side to side builds a multiplier** that pays **bonus money** and **speed**, so a skilled player can chain drifts left→right→left **without losing momentum**.

**Rules (first pass, tune in playtest):**
- **Drift** = a slide **started with the handbrake** (normal cornering never counts), continuing while the rear wheels slide; flicking to the other side mid-drift counts as the next drift.
- **Chain link** = a drift in the *opposite direction* started within a short window (~1.0 s) after the previous drift ends. Same-direction drifts extend the current link but don't add one.
- **Multiplier** = `1 + 0.25 × links`, capped (e.g. ×3). Shown on the HUD as `DRIFT ×N` with a timer bar for the window.
- **Speed reward:** each new link raises top speed for ~2 s plus a small push (no lurch) → chaining keeps or gently builds momentum. Bigger multiplier = slightly bigger push.
- **Money reward:** drift style points (duration × angle × multiplier) are banked when the chain ends cleanly and added to the **current ride's tip** (or a shift style bonus when no passenger is aboard).
- **Chain ends cleanly (banks the points)** when no new drift starts within the window (straightening out, stopping). **Chain breaks (points lost)** on a hard crash (impact above threshold) or (later) taking damage. Landing a jump mid-chain keeps it (arcade).
- *Implemented 2026-11-11 (Iteration 02) — numbers in [[Phase 03 - Core Ride Loop]] notes.*
- **Passenger reaction (later):** some passengers love it (tip ×), some hate it (elderly / pregnant: tip penalty) — ties into [[Passengers & Encounters]].

**Tuning knobs:** chain window, multiplier step & cap, boost impulse per link, top-speed bonus + duration, points per drift-second, crash threshold for breaking.

## 4. Passengers
See [[Passengers & Encounters]]. Each passenger = data (`PassengerProfile` resource): identity, dossier pages, fare, destination type, available actions, hidden traits, and scripted **ride events**.

## 5. Ride outcomes
- **Delivered:** fare × speed bonus + tip (style: near misses, jumps, **drift chains** (§3b), no damage).
- **Kicked out:** no fare; may have consequences (angry passenger shoots at you, reputation change, or you dodged a disaster).
- **Killed:** no fare; may loot; may raise **heat** (police/gang attention); some passengers *deserve* it (bounty).
- **Failed:** time ran out / passenger died / taxi destroyed.

## 6. Threats
- Pursuer cars (hitmen, gangs, police at high heat) that ram and shoot.
- Passenger betrayal (burglar steals cash, hijacker pulls a gun).
- Environmental: traffic, roadblocks.

## 7. Progression
See [[Economy & Upgrades]] and [[Combat & Weapons]]. Money buys guns, ammo, perks, taxi upgrades. Items dropped by passengers give one-shot or passive effects.

## 8. Taxi health
The taxi has HP (body) and the driver has HP. Damage from crashes and bullets. Taxi at 0 → shift over. Repairs cost money between shifts.

## 9. World
One compact, dense city (graybox first). Districts with different passenger mixes (downtown = business, suburbs = old ladies, docks = criminals). Drop-off zones marked by a beacon + HUD arrow.

## 10. Tone & art
Dark comedy, pulpy, over the top. Visuals: primitive blockout + PS1-style render pipeline (proposed) — see [[Art Direction]].

## 11. Out of scope (for now)
Multiplayer, open-world story missions, on-foot gameplay, manual transmission/complex controls.
