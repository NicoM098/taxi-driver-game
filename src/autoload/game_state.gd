extends Node
## State of the current run (cash, shift, heat...). Serialized by SaveManager.
## Grows in later phases (owned weapons, upgrade levels, inventory).

var cash: int = 0
## Difficulty level (the name is from the old timed shifts): starts at 1 and goes up every
## few delivered passengers (ShiftManager.rides_per_level).
var shift_number: int = 0
var heat: int = 0
## Weapon ids (res://data/weapons/<id>.tres). A run starts with the revolver; the rest are
## bought at gun shops (WeaponController.add_weapon).
const STARTING_WEAPONS: Array[StringName] = [&"revolver"]
var owned_weapons: Array[StringName] = STARTING_WEAPONS.duplicate()
## Set by the main menu: the next game runs the short tutorial (src/ui/tutorial/tutorial.gd),
## which clears it when it finishes. While it is on: only calm passengers, no street encounters.
var tutorial_active: bool = false


func reset_run() -> void:
	cash = 0
	shift_number = 0
	heat = 0
	owned_weapons = STARTING_WEAPONS.duplicate()


func add_cash(amount: int) -> void:
	cash = maxi(cash + amount, 0)
	EventBus.cash_changed.emit(cash, amount)


func set_heat(level: int) -> void:
	heat = clampi(level, 0, 5)
	EventBus.heat_changed.emit(heat)


func to_dict() -> Dictionary:
	return {"cash": cash, "shift_number": shift_number, "heat": heat, "owned_weapons": owned_weapons}


func from_dict(data: Dictionary) -> void:
	cash = int(data.get("cash", 0))
	shift_number = int(data.get("shift_number", 0))
	heat = int(data.get("heat", 0))
