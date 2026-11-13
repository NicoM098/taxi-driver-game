---
tags: [architecture, conventions]
---
# Conventions

Based on the official Godot GDScript style guide.

## Naming
| Thing | Style | Example |
|---|---|---|
| Files & folders | snake_case | `cab_camera.gd`, `taxi.tscn` |
| Classes (`class_name`) | PascalCase | `PassengerProfile` |
| Nodes in scenes | PascalCase | `HeadPivot` |
| Functions / variables | snake_case | `apply_damage()`, `max_speed` |
| Private members | leading `_` | `_current_state` |
| Constants & enum values | CONSTANT_CASE | `MAX_PASSENGERS`, `State.RIDING` |
| Signals | past tense snake_case | `ride_completed` |
| StringName IDs | `&"snake_case"` | `&"businessman"` |
| Resource files | snake_case `.tres` | `data/passengers/old_lady.tres` |

## Script layout order
1. `class_name` / `extends`
2. doc comment `##`
3. signals
4. enums, constants
5. `@export` vars, then public vars, then `_private` vars, then `@onready` vars
6. `_ready`, `_process`, `_physics_process`, other virtuals
7. public methods, then private methods

## Rules
- **Static typing always.** `func get_fare(distance: float) -> int:`
- Use `@export` for tunables; never hard-code magic numbers in logic.
- Physics/vehicle code in `_physics_process`; UI in `_process` or signals.
- Use `@onready var x: Node = $Path` (or `%UniqueName`) — avoid long `get_node` chains across scenes.
- Communicate **down** by calling methods, **up/sideways** via signals (`EventBus` for cross-system).
- Components (`HealthComponent`, etc.) over deep inheritance.
- No logic in resources beyond small helpers; resources are data.
- Keep functions short; comment the *why*, not the *what*.
- Print debugging: prefix with system tag, e.g. `print("[Ride] state -> ", state)`; remove noisy prints before closing an iteration.

## Commits (if git is adopted)
`<area>: <short imperative>` — e.g. `vehicle: add drift handbrake`.
