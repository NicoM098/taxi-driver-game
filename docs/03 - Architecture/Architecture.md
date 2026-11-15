---
tags: [architecture]
---
# Architecture

> Target structure. Created in [[Phase 00 - Project Setup]]; grows phase by phase. Keep this note in sync with reality.

## 1. Godot project layout (repo root `taxi-driver-game/` = `res://`)
```
res://
├── assets/                 # imported art/audio (no scripts)
│   ├── models/  textures/  materials/  audio/sfx/  audio/music/  fonts/  ui/
├── data/                   # content as .tres resources (no code)
│   ├── passengers/  weapons/  upgrades/  perks/  items/  events/
├── src/                    # all scripts + scenes, grouped by feature
│   ├── autoload/           # singletons (see §2)
│   ├── core/               # shared components & base resource classes
│   │   ├── components/     # HealthComponent, HitboxComponent, ...
│   │   └── resources/      # PassengerProfile.gd, WeaponData.gd, ...
│   ├── vehicle/            # taxi controller, wheels, damage
│   ├── camera/             # first-person cab camera / head look
│   ├── world/              # city, districts, pickup & drop-off zones, traffic
│   ├── ride/               # RideManager, ShiftManager (run state, no clock), fare calc
│   ├── passengers/         # passenger spawn, passenger actor in cab
│   ├── dossier/            # dossier UI + decision logic
│   ├── events/             # RideEvent implementations
│   ├── combat/             # weapons, projectiles, aiming
│   ├── enemies/            # pursuer AI cars
│   ├── economy/            # shop/garage, upgrades, perks, PlayerStats
│   ├── items/              # inventory & item effects
│   ├── ui/                 # HUD, menus, garage screen
│   └── main/               # Main.tscn (boot), Game.tscn (gameplay root)
├── tests/                  # (optional) test scenes / GUT tests
└── project.godot
```
Rule: **scene + its script live together** in the feature folder (`src/vehicle/taxi.tscn` + `taxi.gd`).

## 2. Autoloads (singletons)
| Name | File | Responsibility |
|---|---|---|
| `EventBus` | `src/autoload/event_bus.gd` | Global signals only (no state). |
| `GameState` | `src/autoload/game_state.gd` | Current run: cash, shift number, heat, owned weapons, upgrade levels, inventory. |
| `PlayerStats` | `src/autoload/player_stats.gd` | Computes final stats = base + upgrades + perks + items. |
| `SaveManager` | `src/autoload/save_manager.gd` | Save/load `GameState` to `user://save.json`. |
| `SceneLoader` | `src/autoload/scene_loader.gd` | Requests world-scene swaps inside Main's viewport (`goto_world(path)`); fades later. |
| `InputDevice` | `src/autoload/input_device.gd` | Last-used device (KB+M/pad) + mouse-look accumulator (`consume_mouse_delta()`), see D-013. |
| `Audio` | `src/autoload/audio.gd` | Bus layout, pooled one-shot players (`play` / `play_at`), looping sources (`make_loop`), volume API. **Listens on the EventBus itself**, so no gameplay script knows about audio. Silent in headless runs. (D-066) |

Add autoloads only when a phase needs them.

## 3. Key signals (EventBus) — initial set
```gdscript
signal shift_started(shift_number: int)
signal shift_ended(summary: Dictionary)
signal shift_time_changed(seconds_left: float)
signal passenger_entered(profile: PassengerProfile)
signal dossier_opened(profile: PassengerProfile)
signal dossier_action_chosen(profile: PassengerProfile, action_id: StringName)
signal ride_started(ride: Ride)
signal ride_completed(ride: Ride, payout: int)
signal ride_failed(ride: Ride, reason: StringName)
signal cash_changed(new_amount: int, delta: int)
signal heat_changed(level: int)
signal taxi_damaged(amount: float, hp_left: float)
signal weapon_fired(weapon: WeaponData)
signal item_acquired(item: ItemData)
```

## 4. Core scene tree (Game.tscn, target)
```
Game (Node3D)
├── World (city instance: roads, buildings, zones, NavigationRegion3D)
├── Taxi (RigidBody3D, taxi.gd)
│   ├── Body mesh, CollisionShape3D
│   ├── Wheels (RayCast3D ×4 suspension) 
│   ├── Cabin
│   │   ├── HeadPivot (Node3D) → Camera3D   (first-person, cab_camera.gd)
│   │   ├── WeaponHolder (Node3D)            (combat)
│   │   └── PassengerSeat (Marker3D)
│   └── HealthComponent
├── RideManager (Node)        # ride state machine
├── ShiftManager (Node)       # run state + stats (no shift clock, D-051)
├── PassengerSpawner (Node)
├── EnemyDirector (Node)      # spawns pursuers on request
└── UI (CanvasLayer)
    ├── HUD (speed, timer, cash, destination arrow, ammo, crosshair)
    └── Dossier (Control)
```

## 5. Ride state machine (RideManager)
```
IDLE → PASSENGER_ENTERING → DOSSIER_OPEN → (DRIVE) RIDING → ARRIVED → PAYOUT → IDLE
                                         ↘ (KICK)  EJECTING → IDLE
                                         ↘ (KILL)  KILL_SEQUENCE → IDLE
                                         ↘ (SPECIAL) → custom → ...
RIDING → FAILED (timeout / passenger dead / taxi destroyed) → IDLE
```

## 6. Data resources (classes in `src/core/resources/`)
- `PassengerProfile`, `DossierPage`, `Examinable`, `PassengerAction`, `RideEvent` (base; subclasses in `src/events/`)
- `WeaponData`, `UpgradeData`, `UpgradeLevel`, `PerkData`, `ItemData`, `StatModifier`

All declared with `class_name` and `@export` fields so they are editable in the Inspector.

## 7. Physics layers (set in Phase 0)
| # | Name |
|---|---|
| 1 | world (static geometry) |
| 2 | player_taxi |
| 3 | enemy_vehicles |
| 4 | traffic |
| 5 | passengers / characters |
| 6 | hitboxes |
| 7 | projectiles |
| 8 | triggers (zones) |

## 8. Input map (set in Phase 0)
`accelerate, brake, steer_left, steer_right, handbrake, boost, aim, fire, reload, weapon_next, weapon_prev, weapon_1..4, interact, kick_out, pause` + controller look axes `look_left, look_right, look_up, look_down` — see [[Game Design Document]] §2.
- Every action gets **both** a KB+M and a gamepad binding (`InputEventJoypadButton` / `InputEventJoypadMotion`).
- Use `Input.get_axis()` / `get_action_strength()` so triggers and sticks are analog; mouse look via `InputEventMouseMotion`, stick look via axes × sensitivity × delta.
- An `InputDevice` helper tracks the last used device (for UI prompts & aim behaviour).

## 9. Render pipeline (PS1 look — see [[Art Direction]])
```
Main (Node)
├── SubViewportContainer (stretch, stretch_shrink 3–4, nearest filter, ps1_post material)
│   └── SubViewport (~320×240 / 480×270)
│       └── Game (3D world, taxi, cameras)
└── UI (CanvasLayer — native resolution: HUD, crosshair, dossier, menus)
```
Shaders live in `res://src/core/shaders/` (`ps1_world.gdshader`, `ps1_post.gdshader`); global shader uniforms `ps1_snap_strength`, `ps1_affine_strength`, `ps1_snap_resolution` (set by `main.gd`). Every world material is a `ShaderMaterial` preset in `res://assets/materials/` using `ps1_world.gdshader` (`snap_multiplier = 0` for taxi/interior).

## 10. As built (Iteration 01)
```
res://src/main/main.tscn        Main (Node, process ALWAYS) — main.gd
├── WorldContainer (SubViewportContainer, pausable, ps1_post material)
│   └── WorldViewport (SubViewport) → start_scene = src/vehicle/test_drive.tscn
└── UI (CanvasLayer) → DebugOverlay (Label, F2), PauseOverlay

res://src/vehicle/taxi.tscn     Taxi (RigidBody3D, taxi.gd, layer 2, mass 1000)
├── PlayerInput (player_vehicle_input.gd)   ← input_provider
├── CollisionBody, CollisionCabin
├── Wheels/FL,FR,RL,RR (RayCast3D, taxi_wheel.gd) → Visual → Tyre, Hub
├── Body/… (yellow blockout, pillars, roof, sign)
├── Interior/… (dash, SteeringPivot/SteeringWheel, seats, PassengerSeat marker)
└── HeadPivot (cab_camera.gd) → Camera3D
```
- Vehicle input: `VehicleInput` (RefCounted) filled each tick by `input_provider.poll(input)` (D-015).
- Tools: `res://tools/setup_project.gd` (project settings, D-012). Tests: `res://tests/vehicle_autotest.tscn` (D-017).
- `res://_backup/` holds manual backups from before git (ignored by Godot via `.gdignore`).

## 11. As built (Iteration 02)
```
res://src/main/game.tscn        Game (Node3D)          ← Main.start_scene
├── City (city.gd)               procedural blockout + 128 TaxiStops (group "city")
├── Taxi (taxi.tscn)             + DriftChain (Node) + HeadPivot/Camera3D/GuideArrow (overlay shader)
├── PassengerSpawner (Node3D)    group "passenger_spawner" → WaitingPassenger children
├── RideManager (Node)           group "ride_manager"   — ride state machine
└── ShiftManager (Node)          group "shift_manager"  — the run: starts once, ends on a wreck (no clock, D-051)
Main/UI/HUD (hud.gd)             polls groups + listens to EventBus (hud_message, shift_ended)
```
- Systems find each other via **groups** (`player_vehicle`, `city`, `passenger_spawner`, `ride_manager`, `shift_manager`) and talk via **EventBus**.
- Nodes inside the world SubViewport read input by **polling** `Input` (not `_unhandled_input`) — see D-013.
- New EventBus signal: `hud_message(text, kind)`.
- Data: `PassengerProfile` (`src/core/resources/passenger_profile.gd`), files in `res://data/passengers/` (auto-loaded via `ResourceLoader.list_directory`).

## 12. As built (Iteration 03 — shooting)
```
Taxi/HeadPivot/Camera3D
├── GuideArrow
└── WeaponHolder (weapon_controller.gd, group "weapon_controller") → Viewmodel (sleeve, hand, gun, muzzle flash + light)
src/core/components/  HealthComponent, Hitbox (Area3D layer 6, damage_multiplier)
src/core/resources/   WeaponData   → data/weapons/{revolver,smg,shotgun}.tres
src/combat/           weapon_controller, combat_fx (tracer/impact), shooting_target, target_car, shooting_range(.tscn)
src/ui/hud/crosshair.gd   spread-sized crosshair + hit marker
```
- EventBus: `hit_confirmed(killed)`, `weapon_fired(weapon)`.
- CabCamera additions: `add_recoil()`, `hold_look` (no recentre while the gun is up), `aim_zoom` (FOV offset).

## 13. As built (Iteration 04 — enemies & damage)
```
Taxi/TaxiDamage (taxi_damage.gd, group "taxi_damage") → TaxiHealth, DriverHealth, PassengerHealth, BodyHitbox, CabinHitbox, smoke/fire particles
Game/EnemyDirector (group "enemy_director") → EnemyCar (extends Taxi) → AI (EnemyDriverAI = input_provider), Gunner (EnemyGunner), HealthComponent, Hitboxes
City.road_graph (AStar3D) + get_route() + road_points()
src/core/resources/enemy_car_data.gd → data/enemies/{hitman_sedan,police_cruiser}.tres
src/ui/hud/{status_bars.gd, damage_indicator.gd}
```
- EventBus: `player_hit(amount, from)`, `taxi_wrecked(reason)`, `passenger_killed`, `enemy_destroyed(enemy, bounty)`; `taxi_damaged` now emitted.
- `Hitbox.take_hit(damage, source)` + `hit` signal.
- Tech debt: `Taxi` is now the generic vehicle class for player and enemies (rename to `Vehicle` someday — KI-014).
- Iteration 04 additions: `Taxi/Interior/RearMirror` (rear_mirror.gd, SubViewport camera), `src/ui/hud/threat_markers.gd`, `CombatFx.explosion()`, `EventBus.explosion(position, strength)` (CabCamera shakes).
- Iteration 05: `src/items/{energy_drink_pickup.gd, drink_viewmodel.gd}`; `HealthComponent.heal()` + `healed`; `TaxiDamage.drink()`; `EventBus.energy_drink_consumed`; `City.energy_drink_count`.

## 14. As built (Iteration 06 — passenger file)
```
Main/UI/Dossier (dossier.gd, group "dossier", process ALWAYS) + dossier_portrait.gd
src/core/resources/{examinable.gd, passenger_action.gd}; PassengerProfile file fields
src/passengers/passenger_instance.gd   (WaitingPassenger.instance; PassengerSpawner.spawn_at())
RideManager: IDLE → ENTERING → DOSSIER → RIDING → EXITING
```
- EventBus: `dossier_opened(passenger)`, `dossier_action_chosen(passenger, action)`, `dossier_closed`, `passenger_executed(passenger)`.
- `Ride.passenger`, `Ride.fare_mult`. Tool: `res://tools/check_profiles.gd` (prints each profile's examinables/actions and unlock results).

## Open-world map (Iteration 08, D-055 / D-056)
- `src/world/map_data.gd` — `MapData`: the map as data (8 m cells, pieces, zones), JSON in `res://data/maps/`, validation, the built-in starter city generator, which map is active.
- `src/world/map_builder.gd` — `MapBuilder`: piece → blockout geometry (used by the game and the editor).
- `src/world/city.gd` — `City`: builds the world from a `MapData` (ground, walls, pieces, stops, drinks, repair shops, lane dashes) and owns the cell road graph (`get_route`, `road_points`, `is_free`, `nearest_repair_shop`). Group `city`.
- `src/world/repair_shop.gd` — `RepairShop` (group `repair_shops`): pad where a wrecked / damaged taxi is repaired for a fee.
- `src/enemies/street_encounters.gd` (`StreetEncounters`, group `street_encounters`, node in `game.tscn`) + `src/core/resources/street_encounter.gd` — random hostile situations from `data/events/*.tres` (D-059). `City.region_at / can_reach / road_points_reachable` keep every spawn on streets with a way out (D-057).
- `src/editor/map_editor.tscn` + `map_editor.gd` — the in-game map editor (its own main scene; M from `Main`, PLAY goes back to `main.tscn`).
- New piece type = an entry in `MapData.TYPES` + a branch in `MapBuilder.build_piece` (+ `City._build_piece` if it needs a game node).

## Menu, tutorial, build (Iteration 09, D-061…D-063)
```
res://src/ui/menu/main_menu.tscn   MainMenu (Control, main_menu.gd)  ← application/run/main_scene
   PLAY / TUTORIAL → GameState.reset_run(), GameState.tutorial_active → change_scene main.tscn
   MAP EDITOR → src/editor/map_editor.tscn ("Main menu" button comes back)
Main/UI/Tutorial (tutorial.gd, class Tutorial, group "tutorial", process ALWAYS)
Main/UI/PauseOverlay  → pause menu built in main.gd (resume / skip tutorial / main menu / quit + run stats)
```
- `GameState.tutorial_active`: `PassengerSpawner` sends only `tutorial_profiles`, `StreetEncounters` stays off; cleared by the tutorial at DONE.
- `InputDevice` also owns F11 fullscreen.
- `MapData.save_dir()`: `res://data/maps/` in the Godot editor, `user://maps/` in an exported build; `find_path` / `list_maps` look in both.
- `export_presets.cfg` → `build/windows/TaxiDriver.exe` (+ `.console.exe`), embedded PCK, includes `data/maps/*.json`, excludes `tests/ tools/ _backup/ docs/`.

## Street life, gun shop, weapon bar (Iteration 10, D-064…D-067)
```
Game/StreetLife (street_life.gd, Node3D, group "street_life")
├── Pedestrian ×≤28   (pedestrian.gd: no physics; laps on building / sidewalk curbs)
└── TrafficCar ×≤8    (traffic_car.gd extends Taxi, layer 4) → AI (traffic_ai.gd = input_provider)
City: gun_shops[] ← GunShop (gun_shop.gd, group "gun_shops", map piece "gunshop")
Main/UI/GunShopUI (src/ui/shop/gun_shop_ui.gd, group "gun_shop_ui", pauses like the Dossier)
Main/UI/HUD → WeaponBar (src/ui/hud/weapon_bar.gd; static draw_gun() shared with the shop)
```
- `WeaponData.slot` = number key / hotbar position; `WeaponController.catalogue()` lists every weapon file; `add_weapon()`, `refill_ammo()`, `index_of_slot()`, `select()`.
- `EnemyCar.build_body()` / `build_wheels()` are static (shared with `TrafficCar`). `City.is_plain_street()`; `TrafficAI.lane_point()` = right-hand lane at a street point.
- EventBus: `pedestrian_hit(position)`.
