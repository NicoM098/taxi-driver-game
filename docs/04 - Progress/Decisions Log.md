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
