---
tags: [progress, decisions]
---
# Decisions Log

Record every non-obvious design or technical decision so it isn't re-debated later.

Format:
```
## D-NNN — <title> (YYYY-MM-DD)
**Context:** why a decision was needed
**Decision:** what we chose
**Alternatives:** what we didn't choose and why
**Status:** proposed / accepted / superseded by D-XXX
```

---

## D-001 — Engine & core tech (2026-11-10)
**Context:** project start.
**Decision:** Godot 4.6.1, GDScript with static typing, Forward+, Jolt Physics (as configured in the existing project).
**Alternatives:** C# — not needed; GDScript iterates faster.
**Status:** accepted

## D-002 — Borrow only perspective + shooting from Half Grip (2026-11-10)
**Context:** user wants Half Grip's first-person in-car shooting but not its complex controls.
**Decision:** first-person cab camera + free mouse-aim shooting; driving controls remain arcade-simple (WASD + handbrake + boost).
**Status:** accepted

## D-003 — Passengers enter the cab; no street pickups (2026-11-10)
**Context:** core difference from Crazy Taxi.
**Decision:** passengers come to/enter the taxi, triggering a dossier with actions (drive, kick out, examine, kill/special when prompted).
**Status:** accepted

## D-004 — Data-driven content via Resources (2026-11-10)
**Context:** many passengers, weapons, upgrades planned.
**Decision:** custom `Resource` classes + `.tres` files in `res://data/`; ride twists composed from reusable `RideEvent` blocks.
**Status:** accepted

## D-005 — Vehicle physics approach (2026-11-10)
**Context:** arcade driving feel is the #1 priority.
**Decision (proposed):** custom raycast-suspension `RigidBody3D` rather than `VehicleBody3D`.
**Alternatives:** `VehicleBody3D` — faster to start, harder to tune for arcade drift/air control.
**Status:** ✅ accepted (2026-11-10, implemented in `src/vehicle/taxi.gd`)

## D-006 — Final title: TaxiDriver (2026-11-10)
**Decision:** the game is called **TaxiDriver**. Godot `config/name` renamed in Phase 00.
**Status:** accepted

## D-007 — No version control (2026-11-10)
**Context:** quick iteration / proof of concept.
**Decision:** no git. Mitigation: careful edits + manual backups to `new-game-project/_backup/<date>/` (with `.gdignore`) before risky restructures (see [[CLAUDE]] §6).
**Alternatives:** git — rejected by user for this project.
**Status:** accepted

## D-008 — Controller supported from the start (2026-11-10)
**Decision:** every input action has KB+M and gamepad bindings from Phase 00; UI must be focus-navigable. Triggers drive, bumpers aim/fire.
**Status:** accepted

## D-009 — Endless shifts for the demo (2026-11-10)
**Decision:** no campaign; shifts repeat endlessly with difficulty scaling by shift number.
**Status:** accepted

## D-010 — Art direction: blockout + PS1 render pipeline (2026-11-10)
**Context:** user asked for the easiest option between a pure blockout and PS1-style textures.
**Decision (proposed):** primitive blockout geometry with a PS1 pipeline from the start (low-res SubViewport, vertex snapping, affine mapping, dither + colour quantise, fog); flat colours first, 64–128 px nearest-filtered textures added incrementally. UI rendered at native resolution; reduced snapping on the cab interior. Details: [[Art Direction]].
**Alternatives:** pure grey blockout (cheapest but looks unfinished); modelled PS1 assets (too costly for a PoC).
**Status:** ✅ accepted by user (2026-11-10). **No textures from day 1** — blockouts use flat-colour material presets (+ optional engine-generated `NoiseTexture2D` grime); real textures introduced from Phase 02 onward only where they aid readability. The world shader must accept an optional albedo texture so adding textures later needs no rework.

## D-011 — Claude decides tech choices without asking (2026-11-10)
**Context:** user instruction: "when facing design decisions on the technology to choose, just go with your recommended input without asking from now on".
**Decision:** Claude picks the recommended technical option and logs it here. Scope and creative/game-design calls are still asked.
**Status:** accepted

## D-012 — Project settings written by a tool script (2026-11-10)
**Decision:** `res://tools/setup_project.gd` (run headless with `--script`) writes name, main scene, display, autoloads, layer names, shader globals and the full input map via `ProjectSettings.save()`. Guarantees valid `project.godot` syntax; re-runnable. Settings changed later in the editor are fine — but re-running the tool overwrites those keys.
**Status:** accepted

## D-013 — Mouse look read via the InputDevice autoload (2026-11-10)
**Context:** the 3D world is inside a SubViewport (PS1 low-res); captured mouse motion is not reliably forwarded into SubViewports.
**Decision:** `InputDevice` (autoload, root level) accumulates `screen_relative` mouse motion; `CabCamera` calls `consume_mouse_delta()`. Actions (keys/pad) are polled via the global `Input` singleton.
**Status:** accepted

## D-014 — Physics interpolation ON, head camera excluded (2026-11-10)
**Decision:** `physics/common/physics_interpolation = true` (60 Hz physics, smooth on high-refresh monitors). `HeadPivot` has interpolation OFF because mouse look updates it every rendered frame. F4 toggles interpolation at runtime for A/B testing.
**Status:** accepted — verify smoothness in playtest

## D-015 — Vehicle input provider pattern (2026-11-10)
**Decision:** `Taxi` reads a `VehicleInput` each tick from `input_provider` (any node with `poll(input)`). Player = `PlayerVehicleInput`; AI pursuers (Phase 06) and the autotest plug in the same way.
**Status:** accepted

## D-016 — Arcade driving assists (2026-11-10)
**Context:** headless autotest showed full-lock turns at 80 km/h scrubbed speed to 19 km/h, then (after fixing that) spun the car out.
**Decision:** `turn_speed_retention` 0.7 (gives back 70% of tyre-scrub drag), rear grip 1.9 > front 1.6 (stable understeer), `yaw_stability` torque limiting yaw rate to the steering's kinematic rate (25% strength while handbrake held). Result: full-lock turn keeps ~85 km/h, no spin; handbrake held at speed = 180° turn.
**Status:** accepted — tune by feel in playtest

## D-017 — Automated verification (2026-11-10)
**Decision:** headless vehicle autotest (`res://tests/vehicle_autotest.tscn`, with `-- --jump` variant) + windowed screenshot capture (`main.gd` user args `--screenshot=<png> --screenshot-frame=N [--no-ps1]`) so Claude can verify physics and visuals without the user. Feel still requires a human playtest.
**Status:** accepted


## D-018 — Air self-levelling + delayed landing bounce (2026-11-11)
**Context:** playtest: on ramp jumps the nose dropped a lot; user wants a quicker, small bounce on landing where the nose doesn't dive. Cause: throttle was mapped to nose-down air pitch (holding W dove the nose to -22°/-37°).
**Decision:** throttle/brake no longer pitch the car in the air (steer = yaw only); PD self-levelling torque on pitch & roll while airborne (`air_level_strength/damping`); on touchdown after ≥0.25 s air: damp pitch rotation 60% and queue an upward kick = 40% of fall speed (max 3.5 m/s) fired when the suspension bottoms out (firing at first contact got absorbed). Result: touchdown pitch ≈ 0°, hop 9–11 cm.
**Status:** accepted — confirm feel in playtest

## D-019 — Speed-scaled handbrake (2026-11-11)
**Context:** playtest: handbrake too aggressive at low speed, fine at high speed.
**Decision:** handbrake grip loss and yaw-stability reduction scale from 0 at 3 m/s (~11 km/h) to full at 12 m/s (~43 km/h). High-speed behaviour essentially unchanged.
**Status:** accepted — confirm feel in playtest


## D-020 — Stronger, deterministic arcade landing bounce + camera landing kick (2026-11-11)
**Context:** user wants landing bumps much more noticeable ("really arcade"). Raising the impulse barely helped (suspension dampers soaked it); disabling rebound damping made it erratic (0.46 m vs 1.67 m hops for nearly identical settings).
**Decision:** at suspension bottom-out set vertical velocity to `fall_speed × landing_bounce` (0.7, max 5.5 m/s) and zero the suspension force while rising for ≤0.25 s → clean, predictable ballistic hop. Camera gets a `landed(fall_speed)` signal → shake + springy head dip. Result: small ramp hop 0.46 m, medium 0.69 m, nose within 2° of level, one hop then settles (no pogo).
**Status:** accepted — confirm feel in playtest (supersedes the bounce part of D-018)

## D-021 — Drift chain multiplier (design) (2026-11-11)
**Decision:** add a side-to-side drift chain that pays bonus money (into the ride tip) and speed (boost per link) — design in [[Game Design Document]] §3b, implementation tasks in [[Phase 03 - Core Ride Loop]].
**Status:** accepted (design); not implemented


## D-022 — Defer navmesh, GPS line and traffic (2026-11-11)
**Context:** Phase 02 listed a baked navmesh, GPS line and simple traffic. Nothing in Iterations 01-02 needs them; the guide arrow points straight at the target.
**Decision:** navmesh + GPS moved to Phase 06 (enemy AI needs them; bake at runtime from the procedural city). Traffic deferred to a later iteration.
**Status:** accepted

## D-023 — Procedural city with TaxiStops (2026-11-11)
**Decision:** city built in code (`City`, `Blockout`), deterministic seed. Pickup/drop-off = `TaxiStop` nodes on the N and E side of every block (128), each with a street arrival point, a sidewalk point and a hidden beacon. Districts by block column. Names: landmark lists per district, then street addresses.
**Status:** accepted

## D-024 — Ride loop rules (2026-11-11)
**Decision:** stop-to-pickup (7 m, <9 km/h), stop-in-ring to deliver (8 m, <11 km/h), ride clock from straight-line distance, SPEEDY/GOOD/OK rating multipliers, shift time bonus per delivery, 150 s endless shifts with summary. Passengers are data (`PassengerProfile`), loaded from `data/passengers/` automatically. Phase 04 will insert the dossier state between ENTERING and RIDING.
**Status:** accepted — balance in playtest

## D-025 — Drift chain implementation + speed-gated drift assist (2026-11-11)
**Context:** autotest showed a left/right chain lost momentum (76→28 km/h) because the handbrake braked hard and drifting scrubbed speed; fixing that globally made the low-speed handbrake aggressive again (98°→159°).
**Decision:** `DriftChain` node (uses travel speed, not forward speed); taxi gets `drift_speed_retention` 0.95 and handbrake braking 1500 N that blend in between 10 and 16 m/s only. Result: chain of 5 links 76→125 km/h; low-speed handbrake unchanged (98°). The handbrake-low autotest now fails above 130° to protect the user's fix.
**Status:** superseded in part by D-030 (assist values reverted)

## D-026 — Ride integration test through Main (2026-11-11)
**Decision:** `tests/ride_autotest.tscn` instantiates `main.tscn` and teleports the taxi (`Taxi.teleport()`) through pickup → delivery → timeout fail → shift end → next shift. With `-- --shot-dir=<dir>` (windowed) it saves mid-ride screenshots including the HUD.
**Status:** accepted


## D-027 — Drift angle limiter (2026-11-11)
**Context:** playtest of Iteration 02: "as soon as you hit the space bar the car does a 180". Reproduced with new `--handbrake-high` autotest: steer + hold handbrake at ~75 km/h → drift angle 180°, heading 160° in 1 s. Cause: D-025's at-speed drift assist keeps momentum while the rear is loose, so nothing stopped the rotation.
**Decision:** `Taxi._apply_drift_angle_limit()`: max 40° between nose and travel direction; beyond it a corrective yaw torque (60000 N·m/rad) + damping of yaw that pushes further out (20000). Skipped when slow (<5 m/s) or deliberately reversing.
**Result:** peak drift angle 50°, controlled ~90° handbrake turn at speed; straight handbrake unchanged; low-speed handbrake unchanged (98°); drift chain unchanged (5 links, 76→125 km/h). `--handbrake-high` fails if the angle exceeds 60°.
**Status:** accepted — confirm feel in playtest


## D-028 — Classic top-centre compass arrow (2026-11-11)
**Context:** playtest: arrow felt mispositioned ("like it's clipping into the car"); user wants it top-centre like the classic games.
**Decision:** `GuideArrow` moved under `HeadPivot/Camera3D` (fixed at the top centre of the view, 1.3 m ahead). Drawn with a new `ps1_overlay.gdshader` (unshaded, transparent pass, no depth test, render_priority 10) so the cabin never hides it. Orientation = flat plate tilted 55° towards the viewer, rotated in-plane by the target's angle relative to the view (ahead = up, right = right, behind = down) — the first world-yaw version was unreadable edge-on when the target was to the side.
**Status:** accepted — confirm in playtest

## D-029 — Longer rides + destination fallback (2026-11-11)
**Context:** playtest: rides too short ("2 seconds away"). Min distances were 80–180 m.
**Decision:** commuter 160–380 m, rushed executive 180–380 m, tourist 260–520 m. Destination picking: in range + preferred district → in range any district → farthest free stop (the old fallback could pick any stop ≥60 m, giving a 122 m tourist ride). Ride autotest now fails if a ride is shorter than the profile minimum.
**Status:** accepted — tune in playtest


## D-030 — Revert at-speed drift assist; handbrake-initiated drift chain with smooth reward (2026-11-11)
**Context:** playtest: "car is undriveable with the current drift chain settings". New `--weave` autotest showed normal (no-handbrake) driving was unaffected, so the culprit was the handbrake/drift behaviour added for the chain: D-025's at-speed drift assist (0.95 speed retention, weak handbrake braking) + the strong forward kicks per link (up to ~4 m/s, top speed +5) — the car kept its speed while sliding and lurched forward on each link.
**Decision:**
- **Supersedes D-025's assist values:** `drift_speed_retention` = 0.7 (same as normal turns) and `handbrake_force_drift` = 4000 N (same as low speed) → handling back to the Iteration 01 tune the user approved. The D-027 drift angle limiter stays as a spin-out safety net (peak ~47°).
- **DriftChain:** a drift must be **started with the handbrake** (normal cornering never counts); continues while rear slip > 1.5 m/s; own thresholds (start 2.0 m/s); flicking sides mid-drift = link.
- **Smooth reward:** push 0.8 m/s per link (was 2.5) + top speed +4 m/s for 2 s (was +5 for 1.5 s).
- Result: 5-link chain 76→96 km/h (was 76→125), weave: 0 links. Backups of the previous versions: `_backup/2026-11-10/taxi_before_drift_revert.gd`, `drift_chain_before_revert.gd`.
**Status:** accepted — confirm in playtest


## D-031 — Shooting before passenger mechanics (2026-11-11)
**Context:** user: "lets start with the shooting before adding the mechanics so we can polish the basics of driving".
**Decision:** Iteration 03 = Phase 05 (shooting). Phase 04 (dossier) comes after the core feels (drive + shoot) are polished. Iteration 02 closed.
**Status:** accepted

## D-032 — Weapon model (2026-11-11)
**Decision:** hitscan from the screen centre (camera), not from the gun muzzle — the crosshair is always truthful; tracers start at the muzzle for looks. Raise on AIM or FIRE (hip fire with extra spread, gun lingers 0.8 s). Spread = aimed base + hip + speed·k + yaw-rate·k + bloom. Recoil: 75% springs back, 25% permanent climb. Auto-reload when the mag runs dry. Shots ignore the taxi's own body. Targets use `Hitbox` Area3Ds (layer 6) slightly larger than their bodies, forwarding damage × multiplier to a `HealthComponent`.
**Status:** accepted — tune in playtest

## D-033 — Debug worlds + held actions (2026-11-11)
**Decision:** F3 cycles Main's world between the city and `shooting_range.tscn`. Main also accepts `-- --world=<scene>` and `-- --hold=action1,action2` so Claude can screenshot gameplay states (e.g. gun raised / firing).
**Status:** accepted


## D-034 — Arrow depth cues (2026-11-11)
**Context:** playtest: hard to tell if the arrow points forward or backward; user wants it at a slight angle.
**Decision:** arrow plate tilted 40° (was 55°) so it reads as a 3D arrow lying on a plane (forward tip recedes, backward tip comes towards you, bigger); two-tone overlay materials (bright head, dark shaft); slightly bigger (scale 1.35) and lower (0.4 m above eye line). 30° was tried and read as a blob at 240p. Visual check tool: `tests/arrow_shots.tscn -- --shot-dir=<dir>` (screenshots at 0/45/90/180/-135°).
**Status:** accepted — confirm in playtest


## D-035 — Road graph instead of navmesh for AI cars (2026-11-11)
**Context:** D-022 moved the navmesh to Phase 06. The city is a regular street grid and cars must stay on streets.
**Decision:** `City.road_graph` = AStar3D with one point per intersection (9×9 = 81) linked to its neighbours; `City.get_route(from, to)` returns intersection waypoints + the goal. AI uses it beyond 50 m and drives directly when closer. No navmesh baking. Worlds without a city (shooting range) use direct chase only.
**Status:** accepted (supersedes the navmesh part of D-022)

## D-036 — Enemy AI behaviour & damage tuning (2026-11-11)
**Context:** `enemy_city_autotest` showed hitmen driving into a parked taxi and getting stuck on it.
**Decision:** parked target (< 4 m/s) → approach a standoff point 9 m away with early braking, then hold position (brake, never reverse); flank offset 6 m; RAM ends 0.4 s after contact. Gunner: 4-shot bursts (6/s) + 1.3 s pause, damage 5. Cabin hits → driver ×0.45. Measured: two hitmen around a parked taxi ≈ 1.5–4 hits/s → driver lasts ~13–15 s.
**Status:** accepted — tune in playtest

## D-037 — Player damage model (2026-11-11)
**Decision:** separate taxi body / driver / passenger health (`TaxiDamage`); body hitbox and cabin hitbox (Hitbox now emits `hit(damage, source)` so the owner can route damage and show where it came from). Crash damage above dv 7 m/s per tick, ignored right after jump landings. Wreck or driver death ends the shift; repair on the next shift. Player shots ignore all of the taxi's own colliders/hitboxes.
**Status:** accepted


## D-038 — Lower enemy lethality; instant explosion on kill; lighter enemy cars (2026-11-11)
**Context:** playtest: "damage is still too high"; "when you inevitably crash into a hitman they get you stuck, so their car should explode and disappear instantly on kill".
**Decision:** hitman bullet damage 5 → 3, spread 3° → 4.5° (police 3 / 5°); taxi body hitbox ×0.6, cabin → body ×0.15 (was 0.3); crash damage threshold 8 m/s (was 7), scale ×2 (was 3). Killed enemies explode (fireball, light, flying visual-only debris, camera shake via `EventBus.explosion`) and are removed instantly. Enemy mass 800 kg (taxi 1000) so you can shove them. Measured: two hitmen around a parked taxi ≈ 25 body + 25 driver damage per 8 s → ~30 s to die (was ~10 s).
**Status:** accepted — confirm in playtest

## D-039 — No rams on a parked taxi; locked standoff side; stopping-distance braking (2026-11-11)
**Context:** while tuning, the city test showed hitmen still sliding past / ramming a parked taxi (up to 3.3 s within 4 m).
**Decision:** RAM only against a moving taxi (> 4 m/s); standoff direction chosen once per hold (no side flipping); approach speed follows a stopping-distance curve (comfort decel 5 m/s²); braking engages 1.5 m/s over target. Result: 8/8 runs, 0 s within 4 m, 0 bumps.
**Status:** accepted

## D-040 — Watching your back: rear-view mirror + threat markers (2026-11-11)
**Context:** user: "we need to be able to watch our backs somehow".
**Decision:** (1) working rear-view mirror (`RearMirror`: 192×64 SubViewport camera behind the rear bench, mirrored texture on a quad above the dashboard — resolves KI-005); (2) HUD threat markers: red chevron + distance on the screen edge for each pursuer outside the view (blue for police), labels stack when overlapping. Existing look-behind (C / R3) stays.
**Status:** accepted — confirm in playtest


## D-041 — Drift limiter only for forward travel (fixes "instant turn") (2026-11-11)
**Context:** user noticed an "instant turn" with some key combination (and wants it removed). Reproduced: reverse, then throttle while still rolling back → the D-027 drift angle limiter saw a 180° "drift" and spun the car 177° in < 0.5 s.
**Decision:** `_apply_drift_angle_limit` returns when the car travels backwards relative to its nose (vel · forward < 0). Guarded by autotest `--reverse-throttle` (fails above 20°).
**Status:** accepted

## D-042 — "Monstrous Energy" healing pickup (2026-11-11)
**Context:** user: drive-through healing item, "crack a white monster energy drink".
**Decision:** fictional brand "Monstrous Energy" (original look: white can + light-blue band). `EnergyDrinkPickup` (Area3D on layer 8, detects the player taxi): giant floating spinning can; on drive-through `TaxiDamage.drink(50 driver, 30 taxi, 1.2 s)` (heal over time via `HealthComponent.heal`), `EventBus.energy_drink_consumed` → first-person chug (`DrinkViewmodel` under the camera) + green flash + HUD message; respawns after 30 s. Placed at 12 random intersections (seeded, not the spawn one) and 3 spots in the range. World pickup only — carried items come with Phase 08.
**Status:** accepted — tune in playtest


## D-043 — Flat surfaces don't wobble; no overlapping ground planes (2026-11-11)
**Context:** playtest: "we still have that z-fighting on the asphalt sometimes". PS1 vertex snapping moves each triangle's screen position → depth becomes inaccurate on grazing flat surfaces; the city had a ground plane 30 cm under the whole road and lane dashes 2 cm above it. View screenshots also showed most lane dashes missing.
**Decision:** `snap_multiplier = 0` for road, ground, lane markings and beacon rings (flat ground wobble is invisible anyway); the outer ground is now 4 strips around the city (nothing under the road); dashes raised to 6 cm and widened to 0.5 m (thinner ones vanish/shimmer at 240p). New visual tool `tests/view_shots.tscn` (screenshots down long streets).
**Status:** accepted — confirm in playtest (it was intermittent)

## D-044 — Strategic enemy spawns in gameplay (design, 2026-11-11)
**Decision:** for Phase 07 ride events, hitmen spawn on the player's route to the destination (ambush ahead / pincer / tail), not only behind. Documented in [[Passengers & Encounters]] §5, [[Combat & Weapons]] §5, Phase 07 tasks; TODO in `enemy_director.gd`. Not implemented yet.
**Status:** accepted (design)


## D-045 — Passenger file design (2026-11-11)
**Decision:**
- **Full world pause while the file is open, shift clock drains ×0.5 + per-examine time cost** — read calmly, but dawdling costs (Papers, Please pressure). Esc/pause disabled while open.
- **Data-driven choices:** `PassengerAction` = outcome (DRIVE / KICK_OUT / KILL) + effects (fare/time multipliers, destination district, cash, heat, message); requirements = examined ids and/or revealed traits. "Special" options need no code. Drive + Kick out are defaults.
- **Examinables** are BBCode `[url=id]` clues in the notes (clickable) **and** buttons (gamepad).
- **Identity per passenger** (`PassengerInstance`: name from pool, age range, blockout portrait varied by name hash).
- Destination is chosen and reserved when the file opens (shown in the file, used by the ride).
- Single page for now (multi-page deferred).
**Status:** accepted — confirm in playtest (pause vs slow-mo)


## D-046 — Passenger file UI pass (2026-11-12)
**Context:** user playtest of Iteration 06: mechanics fine, "UI could be improved" (no specifics given — the points below are Claude's reading of the old screenshots: flat beige slab, big empty gap, default grey buttons, tiny clock, no idea what an action gives you).
**Decision:**
- Layout is **container-driven** (folder > paper > VBox), so the sheet is exactly as tall as its content — no fixed offsets, no gaps, nothing can overlap.
- Manila folder frame + drop shadow, darker dim (0.62) so the HUD behind doesn't compete; short slide-in on open.
- Fields as a key/value grid (small caps keys, bold name/destination/fare, muted details).
- **Shift clock is a dark badge** top right with big digits; a red "-4s" pops next to it on every examine; blinks under 20 s.
- Examine buttons became small red outlined **"Look closer" chips** under the notes; findings sit on a yellow slip that only appears once something was examined.
- Actions in a **2-column grid of two-line buttons**: what you do + what it gets you (`fare ~$74`, `no fare`, `+$120 now · +1 heat`, `+50% time`), generated from `PassengerAction` effects — no new data fields. Kill stays red. Hover = taxi yellow, focus = orange ring (gamepad).
- After examining, focus stays on the next remaining chip (gamepad flow), else the first action.
**Status:** built, auto-verified, awaiting user's look


## D-047 — Ride-event framework (2026-11-12)
**Decision:**
- `RideEvent` (Resource) = trigger (ON_START / AFTER_SECONDS / AFTER_DISTANCE / AFTER_PROGRESS / ON_ARRIVAL / ON_KICKED_OUT) + chance + conditions (`requires_action`, `unless_action`, `requires_flag`, `sets_flag`) + `start / tick / on_kick`. Listed in `PassengerProfile.ride_events`.
- **Per-ride state never lives in the resource** (it is shared by every passenger of that type): the `RideEventRunner` (owned by `RideManager` while RIDING) hands each event a `state` Dictionary; shared ride state (flags, seconds, metres driven) is in `RideContext`.
- AFTER_PROGRESS = metres driven / straight-line ride distance (an odometer, so it survives detours and wrong turns).
- Flags chain blocks without code: hijacker = `ForceDetourEvent` sets `hijacked` -> `PassengerAttackEvent` and the arrival `StealCashEvent` require it.
- Blocks: Dialogue, SpawnPursuers, StealCash, ForceDetour, PassengerAttack, TimerModifier, HeatChange, Reward. `RewardEvent` stands in for DropItem until Phase 08. ScreenEffect deferred.
**Status:** accepted (built, auto-verified)

## D-048 — Strategic hitman spawns (2026-11-12)
**Context:** D-044 / user request: hitmen must not only appear behind you.
**Decision:** `EnemyDirector.spawn_on_route(destination, pattern, count, data)`:
- `ambush_ahead`: walk the road-graph route taxi -> destination, take intersections 70-240 m of driving distance ahead (never within 30 m of the destination). Prefer ones the player **cannot see** (ray from the driver's seat against the world layer): the car parks **across the road** there. If a route point is in view (long straight) the car waits in a **side street** next to it, nose towards the route. Last resort: the farthest visible point.
- `pincer`: half ahead (at least one), the rest behind. `tail`: old behaviour.
- Tail spawns now also avoid visible road points (score penalty).
- `EnemyDriverAI.Mode.AMBUSH`: handbrake on until the taxi is within 45 m, the car is shot, or 40 s pass; then normal CHASE.
**Status:** accepted (built, auto-verified; feel needs playtest)

## D-049 — Kick the passenger out mid-ride (2026-11-12)
**Context:** the burglar needs a counter; the `kick_out` action (Q / d-pad down) was in the input map since Phase 00 but unused.
**Decision:** during a ride `kick_out` throws the passenger out: no fare, the profile's kick reaction applies (ANGRY = parting shot, `kick_damage` per profile), counted as "kicked out" (not as a failed ride). Active events can take over via `on_kick` (thief caught -> drops loot, no reaction). Single press, any speed (arcade). Claude's call as the minimal mechanic the design needed - flagged for the playtest (accidental presses?).
**Status:** changed by D-052 (playtest 2026-11-12: a normal fare must not be endable)

## D-050 — Archetype set and numbers (2026-11-12)
**Decision:** 8 profiles. New: Old Lady (fare ~$6; gift on arrival; help with bags = -6 s shift, better gift), Businessman (fare 90 + 22/100 m; pincer of 2 at 20-35 % progress, +1 hitman every two shifts; 50 % second ambush at 75 %; hazard pay x1.6 or kill +$150 / +2 heat), Burglar (30 % of cash, $20-300, 3.5 s window, drops $25 when caught; shakedown +$35), Hijacker (min_shift 2; detour to the farthest docks stop after 4-8 s, no fare, shoots 10 dmg below 7 m/s for 3 s, takes 20 % on arrival; kill from the file +$45; kick mid-ride costs 25 HP), Expectant Mother (time x0.7, fare 55 + 16/100 m, 60 % chance of a -4 s contraction; promise = fare x2, time x0.85). Executive: hush money -> one tailing hitman. All numbers are first guesses for the playtest.
**Status:** accepted - tune after playtest

## D-051 — No shift clock; open-world run (2026-11-12)
**Context:** user after the Iteration 07 playtest: "The timer for the game itself needs to be removed, was never part of the game", followed by the open-world direction (map base → neighbourhoods with storylines and people → shops).
**Decision:**
- `ShiftManager` has no countdown any more. The run starts once and ends only on a wreck (taxi destroyed / driver killed) → summary → interact → repaired and back on the road (cash kept). No time bonus per delivery; `EventBus.shift_time_changed` removed.
- **Difficulty level** = `GameState.shift_number` (old name kept, KI-021): starts at 1, +1 every `ShiftManager.rides_per_level` (4) delivered passengers. `min_shift` of profiles and `extra_per_shift` of `SpawnPursuersEvent` read it. (Claude's call so the hijacker and the extra hitmen still show up without timed shifts.)
- **Examining the file costs time on that passenger's ride clock** instead of the shift clock (Claude's call, to keep "looking closer has a price"): `PassengerInstance.time_spent`, applied by `RideManager.planned_time()` with a floor of 50 % of the untouched limit. The file's badge shows the resulting "RIDE TIME". No drain while the file is open. To make examining free: set `time_cost = 0` in the data.
- `PassengerAction.shift_time_delta` → `ride_time_delta` (old lady's bags: −6 s on her ride). `RewardEvent` kind `time` removed (expectant mother now tips $30; old lady's big gift = heal / cash).
**Status:** accepted (built, auto-verified) — the two "Claude's call" points need the user's OK

## D-052 — A fare can only be thrown out when an event allows it (2026-11-12)
**Context:** playtest: "ending the fare shouldn't be allowed" (D-049 let Q end any ride).
**Decision:** `kick_out` works only while `RideContext.can_kick()`: `kick_window` (the burglar's counter window, set by `StealCashEvent`) or `kick_unlocked` (set by `ForceDetourEvent` — once hijacked you may throw him out at the profile's price, −25 HP). `RideManager.can_kick_mid_ride()`; the HUD hint shows the key only then. Kicking from the passenger file (before the ride) is unchanged.
**Status:** accepted (built, auto-verified) — Claude's reading of the feedback: confirm that the hijacker kick should stay

## D-053 — Pursuers do not give up when the fare is delivered (2026-11-12)
**Context:** playtest: businessman works, "but the hitmen are quite easy to avoid if you just head straight to the point — when we finish the drive the remaining hitmen keep chasing us".
**Decision:**
- On `ride_completed / ride_failed` the director calls `release_ambushes()`: everybody still parked in ambush starts hunting.
- An ambusher also springs when the taxi **drives past on another street** (distance grows 25 m over the closest it has been) — not only inside 45 m.
- **Relocation:** a hunting car more than `lose_distance` (210 m) away is put back on the player's tail, out of sight (same placement as a tail spawn), up to `pursuit_relocations` (2) times; only then can it be lost (despawn at 330 m). Applies to every enemy car (police too). Cars in AMBUSH or RETREAT are not relocated.
**Status:** accepted (built, auto-verified; feel needs playtest)

## D-054 — HUD: passenger countdown under the arrow, bold subtitles (2026-11-12)
**Context:** playtest: "subtitles need a bolder font", "the countdown for the passengers should be positioned below the arrow in bold red letters as soon as the timer starts".
**Decision:** the ride countdown is its own label: bold (embolden 0.9), red, 42 px, at 0.39 of the screen height (just under the guide arrow, above the crosshair), visible from the first frame of the ride; it blinks in the last quarter. Destination + distance moved to a small line above the arrow. Subtitles: bold, 26 px, thicker outline. The shift clock label is gone. Popups (`hud_message`) moved up onto the roof lining (0.115) and the thief alert down to 0.53 so nothing overlaps the arrow / countdown.
**Status:** accepted (built, screenshots checked) — confirm in playtest

## D-055 — The world is a data map made in an in-game map editor (2026-11-12)
**Context:** user: "i want a map editor, different building sizes and shapes, plazas, low stairs, ramps and such" (base of the open world; neighbourhoods and shops come after).
**Decision:**
- **Editor inside the game** (`src/editor/map_editor.tscn`, F9 from the game, full resolution, no PS1 filter), not Godot scenes: the user builds without touching the engine, and the map stays plain data that the game, the AI and the tests can read. (Claude's reading of "map editor".)
- **`MapData`** = grid of **8 m cells** + a list of pieces `{type, x, z, w, d, h, rot, shape, mat, name, id}`, saved as JSON in `res://data/maps/<name>.json`. Max 160 x 160 cells (1280 m). Active map: `--map=<name>` > `user://active_map.txt` (set by PLAY in the editor) > `city.json` > the built-in generated starter city (`MapData.make_default()`, the old 8 x 8 block city rebuilt from pieces: 32 m blocks, 16 m streets, 400 m square, 128 stops, 3 repair shops).
- **Streets are the gaps:** every cell not covered by a solid piece is asphalt. No road pieces. Lane dashes appear automatically where a street is exactly 2 cells wide.
- **`MapBuilder`** builds each piece in local space under one node (shared by game and editor). Stairs and stepped plazas are step *visuals* over one smooth convex collider, so wheels roll instead of hitting 0.2 m steps.
- **Road graph** = `AStarGrid2D` over the cells (solid pieces blocked, covered cells cost x3, 8-way without corner cutting). `City.get_route()` returns the corners of the cell path (or every cell with `dense`); `road_points()` = plain street cells. Replaces the hand-made 9 x 9 intersection graph; `EnemyDirector` side-street ambush now probes left / right of the route instead of graph neighbours.
- **Zones** (piece type) = neighbourhoods: the zone id is the `district` of the stops inside. Passenger profiles restricted to districts a map does not have may spawn anywhere.
- Tests always run on the built-in city (`MapData.use_builtin()` in every test `_ready`), never on the user's map.
**Status:** accepted (built, auto-verified) — awaiting the user's hands on the editor

## D-056 — Wreck = limp mode until a repair shop (2026-11-12)
**Context:** user: "Wreck makes the car work like shit until you go to the repair shop" (answers KI-022; replaces the wreck summary of D-051).
**Decision:**
- Taxi or driver at 0 HP → `TaxiDamage.is_wrecked`, `Taxi.limp = true`: top speed 8.5 m/s (~30 km/h), engine x0.45 with a 0.45 s cut-out every 1.9 s, wandering steering (±0.22), no boost. No further damage while wrecked.
- The fare bails out (ride fails as `wrecked`), nobody boards a wreck, the pursuers drive off and heat resets (Claude's calls: shooting an invulnerable limping car would only be noise).
- **`RepairShop`** (map piece `repair`): stop on the yellow pad for 1.2 s → repaired. Wreck fee **$60**; plain damage $0.8 / taxi HP + $0.4 / driver HP. Not enough cash → they take what you have and repair anyway (never stuck for good). The guide arrow and a red beacon point to the nearest shop while wrecked.
- Worlds / maps without a repair shop keep the old behaviour: control off, auto-repair after 4 s.
- `ShiftManager` no longer ends the run on a wreck (it only counts `wrecks`); the summary screen is unused for now.
**Status:** accepted (built, auto-verified; feel and prices need playtest)

## D-057 — Enemies only spawn on streets they can drive out of (2026-11-13)
**Context:** user after playing their own map: "the enemies can appear inside the buildings with no way out". Their map has courtyards fully walled in by building pieces; those cells are free street for the spawner and, being out of sight, were even preferred.
**Decision:** `City` flood-fills the free cells into connected regions at build time (`region_at`, `can_reach`, `road_points_reachable`, `count_cut_off_cells`). `EnemyDirector` picks tail spawns, relocations and side-street ambush spots only in the taxi's region; on a small map the fallback is the nearest reachable street beyond the spawn ring, and as a last resort right behind the taxi, never a clamped point that may be inside a building.
**Status:** accepted (auto-verified: `tests/hostiles_autotest` A, 64 spawns on a map with 144 walled-in cells, 0 trapped)

## D-058 — Kicker ramps clear one level of containers (2026-11-13)
**Context:** user: "i want the ramps to be able to get me to jump above the containers". Measured (`tests/jump_autotest -- --explore`): the default 2.0 m kicker ends below a container (2.8 m) placed in the next cell, so the taxi hits it at any speed, boost included; from 2.6 m up it clears.
**Decision:**
- New defaults: **kicker 3.0 m**, **containers 1 level** (height 1 = one level everywhere; 2-3 = mixed stacks up to that many, as before).
- Map format 2. A format 1 map is upgraded **when loaded**: kickers still at 2.0 m and containers still at 2 levels (the old defaults) get the new ones; pieces the mapper changed are left alone. The file is only rewritten when the user saves it from the editor (Claude's call: the user's map has 8 ramps facing containers, all at the old defaults).
- The built-in starter city keeps its explicit 2.0 m street kickers and 1-2 level containers.
**Status:** accepted (auto-verified: default ramp clears default containers from 8 / 12 / 20 cells of run-up, with boost, and over two rows; feel needs playtest)

## D-059 — More hostile situations: street encounters, two enemy types, three passengers (2026-11-13)
**Context:** user: "we need more hostile situations". No detail given; Claude's reading: more ways to end up chased, with and without a fare, using the systems that exist.
**Decision:**
- **Street encounters** (`StreetEncounter` resources in `data/events/`, run by `StreetEncounters` in `game.tscn`): after a quiet stretch with no enemy around (70-100 s for the first, then 80-140 s, 7 % shorter per level, never under 40 s) one that fits the moment is rolled. Conditions: fare aboard / free roam, level, cash carried, kills, **district** (hook for neighbourhood-specific trouble). Five to start: gang drive-by, cash robbery crew ($250+), roadblock (fare aboard), payback (3+ kills), turf war (level 2+, free roam). Without a fare, ambushes use a street point ~240 m ahead of the taxi as the destination. Debug key **H** fires the next one. Off in automated tests unless `run_in_tests`.
- **Enemy types:** `bruiser` (260 HP, 1500 kg, no gun, always rams, $70) and `gang_coupe` (70 HP, 35 m/s, long bursts of weak shots, $25, no heat). `EnemyCarData.mass` is new.
- **Passengers:** Bank Robber (heat +2 on pickup, police ahead and behind; take half the bag or hand him in), Key Witness (bruisers block the route, hitmen behind; promise a safe arrival or sell her out), Gang Courier (rival gang cars from the first seconds; danger money or keep the package).
- All numbers are first guesses.
**Status:** accepted (auto-verified: `tests/hostiles_autotest` B / C); frequency, difficulty and whether this is what the user meant need playtest

## D-060 — The chassis collider clears curbs at full suspension compression (2026-11-13)
**Context:** user: "i think the sidewalks are damaging the car". Measured with the new `tests/curb_autotest`: on flat ground a 0.2 m sidewalk never produces a crash at any speed / angle, but the chassis box reached 0.3 m below the wheel mounts, so with the suspension compressed (landing a jump, a hard bump) its underside dropped under curb height and hit the slab's side like a wall: 89 km/h → dead stop, velocity change 24 m/s (= ~32 HP outside the 0.3 s landing grace). Building bases and repair shops have the same 0.2 m slab.
**Decision:** the lower collision box of the taxi (`taxi.tscn`) and of the enemy cars (`enemy_car.gd`) is 0.6 m tall centred at +0.2 (was 0.8 at +0.1): its underside is 0.1 m below the mounts, i.e. 0.25 m above the ground with the suspension fully compressed. Sidewalk geometry, the crash threshold and the damage numbers are unchanged. Side effect: 0.4 m sidewalks (the editor's maximum), which were a wall for the body, can now be driven onto.
**Status:** accepted (auto-verified: `curb_autotest` 82 cases, no HP lost, no hit after a landing; 9 vehicle scenarios, jump, map, ride, enemy, enemy-city, hostiles, events PASS) — needs the user's confirmation in play

## D-061 — World-space UVs for generated surfaces, and procedural facade windows (2026-11-14)
**Context:** Iteration 09. The city is built from primitives of wildly different sizes
(`map_builder.gd`: `tower`, `stepped`, `l_shape`, `round`, plus roads, sidewalks and containers).
Two problems blocked the texture pass: (1) a tiling texture on `BoxMesh` UVs is stretched by the
box's dimensions, so the same brick would be a different size on every building; (2) the chosen CC0
pack ([PSX Textures Vol. 1](https://fcidade.itch.io/psx-textures-vol-1), user's pick, CC0 only) has
no window or facade textures, and windows are what makes a block of boxes read as a city.
**Decision:**
- `ps1_world.gdshader` gets `uv_mode` (0 = mesh UVs as before, 1 = **world-space planar UVs**,
  projection axis chosen from the dominant normal) and `world_uv_metres` (metres per tile). The
  city surface materials are on mode 1: `road` 8 m, `ground` 8 m, `lane_marking` 4 m, `sidewalk` 2 m,
  `wall` 4 m, `building_a/b/c` 4 m, containers / `prop` / `ramp` 2 m. Everything else (taxi,
  interior, viewmodel, FX, markers) stays on mode 0 — those are hand-sized meshes with real UVs.
- UV selection moved into the vertex stage as a single `base_uv`, so **affine mapping works for both
  modes** (the affine trick needs the UV multiplied by `clip.w` before interpolation).
- **Facade windows are generated, not textured:** on vertical faces only, a world-space grid
  (`window_cell` metres between centres, `window_fill` fraction of glass, `window_ground_floor`
  metres of blank wall at street level). A hash of the cell id decides lit vs unlit
  (`window_lit_chance`), lit ones drive `EMISSION` (`window_lit_emission`), and the two parallel
  faces of one building are decorrelated by the depth coordinate. Unlit glass only replaces
  `window_dark_mix` (0.72) of the wall colour so facades keep their hue instead of reading as black
  holes. Windows fade back into the wall between 45 m and 85 m, because a ~1 m grid at 320x240 turns
  into moire long before it is readable; the fog finishes the job.
- Per-material variety so three materials do not read as one repeated facade: `building_a`
  2.6 x 2.8 m cells / 30 % lit, `building_b` 2.2 x 2.6 m / 22 %, `building_c` 3.0 x 3.2 m / 38 %.
**Alternative rejected:** buying [PSX Urban City Textures](https://russelldoss.itch.io/psx-urban-city-textures)
($1) for its window tiles — the user asked for CC0 only, and a fixed window texture would have to be
UV-scaled per building anyway, which is the problem D-061 exists to avoid.
**Status:** accepted (auto-verified: map, ride, hostiles, events, enemy, enemy-city, weapon, dossier,
pickup, curb, jump and the 9 vehicle scenarios PASS; `check_profiles` OK; before/after screenshots
from `tests/view_shots.tscn`) — needs the user's eye on window size, density and lit frequency.

## D-062 — Textures multiply a rebalanced flat colour, and import must not auto-compress (2026-11-14)
**Context:** Iteration 09, with the CC0 pack (A_classic, 90 x 64x64) in `assets/textures/`.
`ps1_world.gdshader` computes `ALBEDO = albedo * texture(...)`, and the pack's textures average
around 0.25-0.45 luminance, so assigning one to a material would have multiplied the whole city
down to a fraction of its designed brightness and thrown away the palette.
**Decision:**
- **Rebalance, don't replace:** a textured material's `albedo` is its old blockout colour divided
  by the texture's mean RGB (clamped at 1.6). The surface keeps the average brightness the palette
  called for, and the texture contributes grain and pattern only. Recomputed whenever a texture is
  swapped. (`road` 0.17,0.17,0.19 -> 0.65,0.70,0.84 over Concrete042A, etc.)
- **Tile sizes** (`world_uv_metres`): buildings and `wall` 2.5 m, `sidewalk` and containers 2 m,
  `road` 6 m, `ground` 8 m. Buildings started at 4 m, which made each brick ~50 cm wide.
- **Import:** every PNG gets `detect_3d/compress_to=0` plus `mipmaps/generate=false` and
  `compress/mode=0`. Godot's default `detect_3d/compress_to=1` silently re-imports a texture as
  VRAM-compressed with mipmaps the first time it is used in 3D, which destroys the ordered dither
  the whole look depends on. This must be redone for any texture added later.
- **Not everything gets a texture:** `prop`, `ramp` and `lane_marking` stay flat colour. They are
  gameplay-readable elements (a ramp has to read as a ramp at speed) and a metal texture turned the
  repair shop into speckled noise. [[Art Direction]]: texture only where it helps readability.
- **Texture choices are reviewed on screen, not by name:** PaintedPlaster010 read as camouflage on
  facades and Concrete030 as marble streaks on walls; both were swapped after looking at the
  view-shot screenshots.
**Status:** accepted (auto-verified: import clean; map, ride, hostiles, enemy, enemy-city, weapon,
dossier, pickup, curb, jump PASS; `events_autotest` see KI-026) — needs the user's eye in motion.

## D-063 — Affine warping is dialled down on ground surfaces (2026-11-14)
**Context:** user, after the first playtest of the textured city: *"hay como un efecto psicodelico con
las texturas... se nota sobre todo con las calles, es como que se estiran y se mueven"*. This is
**affine texture mapping** (D-010, `ps1_affine_strength` = 1.0) finally becoming visible: it was in
the pipeline from the start but a flat colour has no detail to warp, so nothing showed until
Iteration 09 put textures on. The error it produces grows with the on-screen size of a polygon and
with how obliquely it is seen — and the road is both the biggest quad in the game and the one
always seen edge-on from the driver's seat. The ground strips around the city were worse still:
single quads hundreds of metres across, with no subdivision at all.
**Decision:**
- **Tessellation:** the road plane goes from ~12 m to ~6 m quads, and the four ground strips get
  ~12 m subdivision (they had none). Affine error per quad falls with quad size. Cost: the road
  goes from ~2.2k to ~8.7k triangles on a 400 x 400 m map — nothing.
- **Per-material affine:** `affine_multiplier` 0.25 on `road` and `ground`, 0.5 on `sidewalk`.
  Walls, buildings and props keep the full 1.0: vertical faces are seen closer to head-on, and
  that is where the warp reads as charm instead of nausea. The global `ps1_affine_strength` stays
  at 1.0 so F1 still toggles the whole look.
- **Road texture swapped** `Concrete042A` -> `ground-street/Gravel023` at 3 m per tile (was 6 m).
  The concrete's own vertical streaks were being stretched into metre-long smears and were making
  the swimming far more visible than the warp alone; gravel is isotropic fine grain, so there is no
  direction for the eye to track. Albedo rebalanced per D-062 (0.31, 0.32, 0.38).
**Not done:** dropping road affine to 0. Some warp is the look; 0.25 keeps a trace of it. If it
still swims in motion, `road`/`ground` to 0.0 is the next step and costs nothing.
**Status:** **accepted and confirmed in play by the user (2026-11-14: "me gusta")**. Auto-verified:
import clean; map, ride, curb, jump, hostiles, enemy-city, events, enemy, weapon, dossier, pickup
PASS. The dials are written up in [[Art Direction]] > "Tuning the PS1 look" so the balance between
authentic artefact and comfort can be moved again later without re-deriving any of this.

## D-064 — Time-of-day moods, street lamps, headlights, per-pixel lighting (2026-11-14)
**Context:** Iteration 10. The city was lit as flat midday (one directional light at 1.1, ambient
0.7, pale sky, fog 70-220) while [[Art Direction]] had specified a *"dusky city, blue/purple
shadows, sodium-orange street lights"* since Phase 00, and the lit facade windows from D-061 were
driving `EMISSION` into a scene too bright for it to mean anything.
**Decision:**
- **`Lighting` (`src/world/lighting.gd`)** holds three moods — **day / dusk / night** — each a sky
  colour, ambient colour + energy, sun colour / energy / angle, fog colour + range, lamp energy and
  a window-emission multiplier. **Dusk is the default**, as the design asked. `Blockout.add_environment()`
  takes a mood and returns `{env, sun}`; `City.set_mood()` re-applies it live, and **F6** cycles in
  play (F5 is "run project", F9 / F10 are the embedded game view's suspend / next frame).
- **Street lamps** generated in `City._build_street_lamps()`: on any drivable cell that touches
  something built, every 4 cells along that kerb (8 m cells → one lamp per 32 m), capped at 420.
  311 on the starter city. Posts and heads are one MultiMesh each; only the omni lights are nodes,
  all shadowless. **Visual only, no collision**, like the lane dashes, so routing, driving and the
  autotests are untouched. Sodium orange `Color(1.0, 0.72, 0.36)`, 17 m range.
- **Headlights** on the taxi, built in code in `taxi.gd` so `taxi.tscn` stays hand-editable. Always
  on — arcade taxi, night-ish city, and in daylight they are lost in the sun anyway.
- **`ps1_world.gdshader` is lit per pixel** (`vertex_lighting` dropped from `render_mode`). With the
  road tessellated at 6 m (D-063) a vertex-lit lamp pool would be computed at four corners 6 m apart
  and read as a faceted blob. Nothing else in the PS1 stack changed, and with only a directional
  light the two modes were indistinguishable anyway, so this costs nothing visually.
**Measured, not guessed — why the headlights are at energy 45:** at 3.2 they produced *nothing*
visible on the road, which looked like a bug and is not one. A headlight sits ~0.6 m above a flat
road, so the beam hits it at a grazing angle: aimed 4° down, lambert gives `N·L ≈ sin(4°) ≈ 0.07`,
and against a road whose albedo is ~0.17 the result is invisible. Aiming it steeply down instead
(-11°) puts the pool within ~4 m of the bumper, where the car's own bodywork hides it from the cab
camera. Isolated with a temporary omni probe on the taxi, which lit the road fine and proved the
surface receives light and the problem was the geometry of the beam. Settled at y +0.35, -6° and
energy 45: the pool lands 5-25 m ahead where the driver can see it, and the kerbs and wall bases
catch it, which is what actually sells headlights.
- Dusk and night were lifted after the first screenshots (dusk ambient 0.42 → 0.62, sun 0.6 → 0.9;
  night ambient 0.26 → 0.34): the first pass was atmospheric and unplayable.
**Performance:** 165 FPS (6.06 ms) on the starter city with 311 lamps, i.e. pinned to this machine's
vsync cap on an RTX 4070 Ti SUPER. No shadows anywhere, so the lamps are nearly free — but that is
one high-end GPU, not a measurement of the floor.
**Status:** accepted (auto-verified: import clean; the 9 vehicle scenarios, map, ride, events,
hostiles, enemy, enemy-city, weapon, dossier, pickup, curb, jump PASS; `check_profiles` OK) —
**needs the user to pick the mood in play (F6) and to say whether it is drivable.**

## D-065 — Everything that emits light follows the time of day (2026-11-14)
**Context:** user, after playing all three moods: *"de día las luces del auto y de la calle se
deberian apagar (de los edificios me imagino que tambien)"*. Right on all three. D-064 only killed
the street lamps' **omni lights** in daylight; three other things kept glowing at midday — the
lamp glass's own `emission_strength`, the lit facade windows from D-061, and the taxi's headlights,
which had no way of hearing about the mood at all.
**Decision:**
- **`EventBus.mood_changed(mood: int)`**, emitted by `City.set_mood()`. Anything that owns lights
  listens there instead of polling the city — the architecture rule for this project. The taxi
  connects to it and also asks the city once on `_ready()`, because a taxi can be built before or
  after the city (and the test worlds have no city at all, where the headlights stay on).
- **Three new per-mood values in `Lighting`:** `lamp_glow` (the lamp glass's emission, separate
  from the light it casts — a switched-off lamp that still glows looks broken), `window_lit`
  (0 = nobody has a light on) and `headlights_on()`.
- **New shader uniform `window_lit_amount`**: at 0 a "lit" window falls back to exactly the unlit
  look, colour and wall-blend included, so daylight facades have no bright squares. The random
  pattern is untouched, so the same windows light up again at dusk.
- **Headlight lenses get a second material** (`headlight_off.tres`, no emission): the spot going
  invisible is not enough, the glass has to stop glowing too.
**Verified:** headless, `ride_autotest` with the default forced to each mood — `headlights OFF` at
day, `ON` at dusk. Screenshots of all three moods: day has dark windows and dark lamp heads, dusk
and night are unchanged.
**Status:** accepted (auto-verified: import clean; map, ride, events, hostiles, enemy, enemy-city,
weapon, dossier, pickup, curb, jump, vehicle PASS) — the user approved the three moods themselves
in play the same day.

## D-066 — The whole sound bank is generated, and Audio listens on the EventBus (2026-11-14)
**Context:** Iteration 11. The game was completely silent — no `AudioStreamPlayer` anywhere, no
sound files, no bus layout.
**Decision 1 — generated, not sampled.** There is no clean CC0 car-engine loop to be had: Kenney
publishes no vehicle audio at all, and the Freesound CC0 candidates are a truck idle, a sci-fi
hover vehicle and a 1:48 contact-mic recording of a Mini with no marked loop point. So
`tools/gen_sfx.py` (Python + numpy, fixed seed) synthesises all 21 sounds into `assets/audio/`:
- **Seamless by construction.** Loops hold a whole number of cycles, and their noise is built by
  giving a shaped spectrum random phases and inverse-FFT-ing it, which is periodic by definition.
  Measured discontinuity at the wrap: 0.003-0.006 on the engine layers.
- **CC0 by construction** — nothing is downloaded, so there is no licence to track.
- **Reproducible**: the script is the source, the WAVs are the build. Same seed, same bank.
- It also suits the PS1 blockout better than a real car recording would. 22050 Hz mono 16-bit.
**Decision 2 — the engine is three loops, crossfaded and pitched.** `engine_idle` / `engine_mid` /
`engine_high`, blended by a `_revs` value that follows speed, can be lifted by the throttle alone
at a standstill, and lags so the note never snaps. Pitch 0.72-1.65, with boost pushing it up and
`limp` holding it down and flat. The classic arcade approach, and the reason the samples are
generated at exact frequencies.
**Decision 3 — `Audio` listens on the EventBus itself.** Fourteen sounds (guns, reload, dry click,
impacts, the wreck, explosions, kills, hit confirm, cash, pickups, the drink, dossier open / close /
choose, taking a hit) are wired by `Audio` connecting to signals that already existed. No gameplay
script gained a line about audio — the Architecture rule. Two signals were added where none
existed: `weapon_reloading` and `weapon_empty`.
**Decision 4 — silent in headless.** `Audio.enabled` is false when `DisplayServer` is headless, so
the autotests stay quiet and fast and the taxi skips building its engine players entirely.
**Buses** (Master, Music, SFX, Engine, UI, Voice) are created idempotently by the autoload rather
than shipped as a `.tres`, so there is one source of truth and nothing to keep in sync. Loop flags
are **not** in the WAVs — they live in `edit/loop_mode=1` in the four `.import` files, which must be
re-checked if the bank is regenerated.
**What is NOT verified: how any of it sounds.** Checked by construction and by numbers — loop
continuity, peak and RMS per file, every name resolving to a file, all four loops reporting
`playing = true` in a windowed run, no warnings, the suite green. Whether it is pleasant, too loud
or grating is the user's call.
**Status:** accepted (auto-verified: import clean; map, ride, events, hostiles, enemy, enemy-city,
weapon, dossier, pickup, curb, jump, vehicle PASS; `check_profiles` OK) — **needs the user's ears.**

## D-067 — Looping is forced on the resource, and enemy cars have engines (2026-11-14)
**Context:** user, after the first listen: *"creo que todos funcionan salvo el del vehiculo en si
mismo. Como que no escucho nada, ni el motor ni el rechinado de las gomas... Al igual que el de los
vehiculos de los NPCs"*. Two separate things, one a bug and one a gap.
**The bug.** The engine and tyre loops played **once** and stopped. Found by printing the players'
state once a second in a windowed run: `playing=false`, `loop=0`, volume and bus both correct
(-18.1 dB on bus Engine). Godot's WAV importer flag `edit/loop_mode=1` had been written into the
four `.import` files **after** the bank had already been imported, and `--import` reused the cached
`.sample` instead of rebuilding it, so the flag never reached the resource. My earlier check was
worthless: it printed `playing = true` immediately after `play()`, which is true for a one-shot too.
**Decision:** `Audio` forces looping **on the resource** in `_force_loop()`, called from
`make_loop()` / `make_loop_3d()` — `loop_mode = LOOP_FORWARD`, `loop_end` computed from the data
size and format. It is idempotent (streams are cached) and cannot be lost by regenerating the bank,
which removes the footgun D-066 had to warn about. The `.import` flags stay as belt and braces.
**The gap: enemy cars had no engine.** Out of scope in Iteration 11, but trivial once the system
existed, and the user expected it. One positional layer (`engine_mid`) per car via the new
`Audio.make_loop_3d()`, pitched 0.78-1.45 by speed, 80 m range, -14 dB (there can be several at
once), silenced when the car is destroyed. You can now hear them coming and roughly from where.
**Also:** the taxi's idle was lifted (`ENGINE_DB` -9 → -6, idle floor 0.35 → 0.45) — at -18 dB a
stationary engine was technically audible and practically not.
**Lesson recorded:** "the player reports `playing = true`" is not evidence that a loop loops. Check
it a second later, not in the same frame.
**Status:** accepted (auto-verified: import clean; the 12 autotests PASS; windowed runs show the
taxi's four loops still playing after several seconds with `loop=1`, and enemy cars starting their
own) — **needs the user's ears again.**

## D-068 — The engine has a gearbox, and the tyres sound like rubber (2026-11-14)
**Context:** user, second listen: *"El sonido del motor, sobre todo a maximas revoluciones, suena
muy agudo"*, *"al no tener el efecto de 'cambios' y ser un ruido constante, es un poco irrealista y
molesto"*, and the slide *"no suena como un rechinado de las gomas para con la calle. Al igual que
cuando frena"*. Three separate faults, all fair.
**Decision 1 — a gearbox.** The revs no longer map straight from standstill to top speed. Five
gears topping out at 15 / 31 / 49 / 71 / 101 % of top speed — **18, 37, 58, 84 and 119 km/h** — and
the revs run up inside the current gear and drop back when it changes, with a 0.16 s throttle-cut
dip (-7 dB) on each shift and hysteresis so a boundary cannot flutter. Verified by driving the
vehicle autotest windowed: upshifts logged at 18 / 37 / 58 / 84 km/h with revs at 0.82-0.98, and
downshifts on the way back down at 81 / 55 / 33 / 14 km/h with revs falling to 0.04-0.13.
**Decision 2 — pitch and timbre are separated.** Pitch follows the revs, so it cycles per gear;
which of the three layers you hear follows road **speed**, so the engine keeps getting fuller as
the car gets faster instead of dropping back to an idle note after every shift.
**Decision 3 — it is no longer shrill.** The pitch range is 0.80-1.24 (was 0.72-**1.65**), and the
samples themselves were regenerated an octave-ish down with fewer screaming partials: fundamentals
42 / 78 / 132 Hz → **38 / 64 / 96 Hz**, harmonics 14 / 18 / 22 → **12 / 14 / 15**.
**Decision 4 — a tyre squeal is not hiss.** The old screech was one band of noise (900-4200 Hz)
with a 6 Hz warble, which is wind. The new one is **four sharp resonances** at 690 / 1180 / 1760 /
2550 Hz, each wobbling at its own rate (7 / 11 / 17 / 23 Hz — the chaotic stick-slip of rubber on
tarmac), over a quieter band of broadband scrub and a little contact-patch rumble. One second long,
every modulation completing a whole number of cycles, so it still loops dead.
**Decision 5 — braking makes a noise at all.** It never did: the screech was driven only by lateral
slip, so a straight-line stop was silent. Braking hard above 6 m/s now scrubs, and because locked
wheels sit lower than a drift squeal, the same sample is pitched **0.76** for braking against
0.84-1.16 for a drift. The handbrake counts as a full brake.
**Status:** accepted (auto-verified: import clean; the 9 vehicle scenarios and 11 other autotests
PASS; gear changes and both tyre modes observed in a windowed run) — **needs the user's ears.**
