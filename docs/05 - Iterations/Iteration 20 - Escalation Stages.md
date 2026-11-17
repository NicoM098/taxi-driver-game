---
tags: [iteration]
iteration: 20
status: active
started: 2026-11-17
finished:
---
# Iteration 20 — Escalation Stages

Same branch as Iterations 17-19 (`feat/no-papers`).

## Scope (from user, verbatim)
> "okay lets make it so you cant buy energy drinks and neither can you repair the car. Also the
> game is quite easy when you have 5 stars, but instead of boosting the difficulty straight, i
> want to add 3 levels of it. First you fight against the cops and the gangs, then they could
> send the swat after you and a few gang bosses with bigger and better cars kinda like mini
> bossfights before passing to the next stage. And lastly they can send the military and the
> cartel for example, so you have 3 bosses. we will do a mix of fares, time and amounts of kills
> to go trough each"

## Interpretation (Claude's calls — the user can overrule)
- **No cans, no repair** → `ShopMenu.sells_cans` / `sells_repair` = false (switches, nothing
  deleted). The MONSTROUS ENERGY tab is gone; **Monstrous XL** moves to THE CAB (street cans
  still heal more with it); the Cup Holder Rack is not sold. Healing = street cans only.
- **3 levels** → the run is three **stages**; the heat stars still work inside each one. A stage
  ends with a **boss fight** once its fares, kills and survived time are all reached.

| Stage | Who answers the heat | Mini-bosses | To reach the boss | Boss | Reward |
|---|---|---|---|---|---|
| 1 Street War | police + gang coupes, 5 cars | — | 5 fares, 10 kills, 4:00 | Precinct Captain (+2 cruisers) | $1000 |
| 2 Crackdown | **SWAT** + gangs, 6 cars, heat ≥ 2 | a **gang boss** every 100 s at heat 3+ | 6 fares, 15 kills, 5:00 | the **three gang bosses** at once | $2500 |
| 3 All-Out War | **military** + **cartel**, 7 cars, heat ≥ 3 | a **cartel lieutenant** every 90 s at heat 3+ | 7 fares, 20 kills, 6:00 | the **Army APC** and **the Kingpin** | $5000 |

After the last boss: "THE CITY IS YOURS", the war goes on at stage 3. Bosses pay their own
bounty on top.

- Boss cars are bigger (body ×1.2-1.5, wheelbase too), heavier (1600-3000 kg: they shove you),
  with a steel nose plow and roof armour; 420-1800 HP. A boss is never given up on: outrun, it is
  put back on your tail; if it vanishes without being destroyed it comes back.
- HUD: a stage panel under the cash (objectives with bars, ticked when done → BOSS INCOMING
  countdown → one health bar per boss → STAGE CLEARED), and a big banner for each stage / boss.

## Design (D-091)
- Module `src/escalation/`: `Escalation` (switch `Escalation.enabled`, node in `game.tscn`),
  `StageData` (`data/stages/stage_1..3.tres`), `StageHud` (added by the HUD).
- New enemy data: `swat_van`, `military_jeep`, `cartel_truck`, `cartel_lieutenant`,
  `gang_boss_{red,purple,orange}`, `boss_captain`, `boss_apc`, `boss_kingpin`; materials
  `enemy_{swat_black,military_olive,cartel_white,boss_gold}`.
- `EnemyCarData`: `size`, `plow`, `is_boss`. `EnemyCar.build_body / build_wheels` take a size
  (traffic unchanged); heavy cars get a stiffer suspension.
- `EnemyDirector.set_roster(law, crime, cap)` and `spawn_boss(data)`.
- Debug **F11**: completes the current stage's objectives (straight to the boss).

## Checklist
- [x] Shop: no cans, no repair (switches); XL under THE CAB
- [x] Escalation module, stages as data, bosses and mini-bosses
- [x] Stage HUD + banners
- [x] `escalation_autotest` A-G PASS; screenshots of a boss and the boss bars
- [x] EnemyDirector cleanup fix: a car freed by someone else stayed in its list (typed-array erase error every frame)
- [ ] **User playtest:** objective numbers, boss toughness, whether stage 1 feels like the old game
