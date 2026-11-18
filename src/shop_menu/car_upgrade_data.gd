class_name CarUpgradeData
extends Resource
## One upgrade sold in the shop menu (D-089): for the taxi or for the Monstrous Energy cans.
## Files in res://data/car_upgrades/<id>.tres. Levels belong to the run (GameState.car_levels).
## What a level does is `per_level` x level applied to `stat` (see CarUpgrades.apply).

@export var id: StringName = &""
@export var display_name: String = "Upgrade"
@export_multiline var blurb: String = ""
## Order in the shop list.
@export var slot: int = 0
## &"car", &"cans" or &"perks" (the PERKS tab, D-100): the section of the shop it is listed in.
@export var section: StringName = &"car"
## What it changes: &"armor", &"engine", &"glass", &"ram", &"nitro", &"can_size", &"can_holder";
## perks: &"double_tap" (fire rate), &"fast_reload" (reload time), &"rolling_pickup" (D-100).
@export var stat: StringName = &""
## Effect per level (a fraction, e.g. 0.25 = +25 %, or a count for can_holder).
@export var per_level: float = 0.25
## What `prices` are in (D-106): &"cash" (dollars) or &"parts" (spare parts from kills: the
## cab's upgrades). Perks are not bought at all: they come from the slot machine.
@export var currency: StringName = &"cash"
## Price of level 1, 2, 3... (its size is the number of levels).
@export var prices: PackedInt32Array = PackedInt32Array([300, 700, 1500])
## One line per level for the shop ("+25 % taxi health"); without a %d it is shown as is.
@export var level_text: String = "+%d %%"
