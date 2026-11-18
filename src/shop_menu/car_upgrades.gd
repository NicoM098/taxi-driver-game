class_name CarUpgrades
extends RefCounted
## The shop menu's economy (D-089): taxi upgrades, Monstrous Energy cans, repair anywhere.
## Levels and cans belong to the run (GameState.car_levels / GameState.cans, reset with it).
## The taxi keeps its untouched values as metadata, so applying a level is always
## "base x multiplier" and can never stack twice.

const DIR := "res://data/car_upgrades/"
const CAN_PRICE := 60
const BASE_CANS := 2
## What one Monstrous Energy can heals before Monstrous XL (= the street pickup's values).
const CAN_DRIVER_HEAL := 50.0
const CAN_BODY_HEAL := 30.0
const CAN_HEAL_TIME := 1.2
## Repair anywhere costs what the old repair garage charged (RepairShop defaults).
const REPAIR_PER_TAXI_HP := 0.8
const REPAIR_PER_DRIVER_HP := 0.4

static var _catalogue: Array[CarUpgradeData] = []


static func catalogue() -> Array[CarUpgradeData]:
	if _catalogue.is_empty():
		for file in ResourceLoader.list_directory(DIR):
			var u := load(DIR + file) as CarUpgradeData
			if u != null:
				_catalogue.append(u)
		_catalogue.sort_custom(func(a: CarUpgradeData, b: CarUpgradeData) -> bool: return a.slot < b.slot)
	return _catalogue


static func get_upgrade(id: StringName) -> CarUpgradeData:
	for u in catalogue():
		if u.id == id:
			return u
	return null


static func level(id: StringName) -> int:
	return int(GameState.car_levels.get(id, 0))


static func max_level(u: CarUpgradeData) -> int:
	return u.prices.size()


## Price of the next level, -1 when maxed.
static func next_price(u: CarUpgradeData) -> int:
	var lv := level(u.id)
	return u.prices[lv] if lv < u.prices.size() else -1


## Sum of every bought level's effect on `stat` (0 when none).
static func value(stat: StringName) -> float:
	var total := 0.0
	for u in catalogue():
		if u.stat == stat:
			total += u.per_level * level(u.id)
	return total


## "+25 % taxi health" for `levels` levels of `u`.
static func effect_text(u: CarUpgradeData, levels: int) -> String:
	if not u.level_text.contains("%"):
		return u.level_text
	var amount := u.per_level * levels
	var shown := roundi(amount) if u.stat == &"can_holder" else roundi(amount * 100.0)
	return u.level_text % shown


## Whether a perk (D-100) with this stat has been bought.
static func has_perk(stat: StringName) -> bool:
	return value(stat) > 0.0


## Perks on the guns (D-100): fire rate x this (Double Tap)...
static func fire_rate_mult() -> float:
	return 1.0 + value(&"double_tap")


## ...and reload time x this (Quick Hands).
static func reload_mult() -> float:
	return maxf(1.0 - value(&"fast_reload"), 0.3)


static func can_capacity() -> int:
	return BASE_CANS + roundi(value(&"can_holder"))


static func can_mult() -> float:
	return 1.0 + value(&"can_size")


## What the player holds of an upgrade's currency (D-106): dollars or spare parts.
static func wallet(u: CarUpgradeData) -> int:
	return GameState.parts if u.currency == &"parts" else GameState.cash


## "$315" or "5 PARTS".
static func price_text(u: CarUpgradeData, price: int) -> String:
	if u.currency == &"parts":
		return "%d PART%s" % [price, "" if price == 1 else "S"]
	return "$%d" % price


## Perks (D-106) are won at the slot machine, never bought.
static func is_perk(u: CarUpgradeData) -> bool:
	return u != null and u.section == &"perks"


## Buys the next level of `id` and applies it to the taxi. Returns an error text ("" = done).
static func buy_level(tree: SceneTree, id: StringName) -> String:
	var u := get_upgrade(id)
	if u == null:
		return "Unknown upgrade."
	if is_perk(u):
		return "Perks are won at the slot machine: beat a boss for a ticket."
	var price := next_price(u)
	if price < 0:
		return "%s is maxed out." % u.display_name
	var have := wallet(u)
	if have < price:
		if u.currency == &"parts":
			return "Not enough spare parts: you need %d more. Wreck more enemies." % (price - have)
		return "Not enough cash: you need $%d more." % (price - have)
	if u.currency == &"parts":
		GameState.add_parts(-price)
	else:
		GameState.add_cash(-price)
	GameState.car_levels[id] = level(id) + 1
	apply(tree)
	return ""


## A level given for free (the slot machine's perks, D-106). False if maxed.
static func grant_level(tree: SceneTree, id: StringName) -> bool:
	var u := get_upgrade(id)
	if u == null or level(id) >= max_level(u):
		return false
	GameState.car_levels[id] = level(id) + 1
	apply(tree)
	return true


## Puts every bought level on the player's taxi (idempotent).
static func apply(tree: SceneTree) -> void:
	var wc := tree.get_first_node_in_group(&"weapon_controller") as WeaponController
	if wc != null:
		wc.refresh_arsenal()   # gun perks (D-100)
	var taxi := tree.get_first_node_in_group(&"player_vehicle") as Taxi
	if taxi == null:
		return
	_base(taxi, &"engine_force", taxi.engine_force)
	_base(taxi, &"max_speed", taxi.max_speed)
	_base(taxi, &"boost_max_speed", taxi.boost_max_speed)
	var engine := value(&"engine")
	taxi.engine_force = float(taxi.get_meta(&"base_engine_force")) * (1.0 + engine)
	# Top speed grows at half the rate of the pull, so the cab stays drivable.
	taxi.max_speed = float(taxi.get_meta(&"base_max_speed")) * (1.0 + engine * 0.5)
	taxi.boost_max_speed = float(taxi.get_meta(&"base_boost_max_speed")) * (1.0 + engine * 0.5)
	_base(taxi, &"nitro_max", taxi.nitro_max)
	_base(taxi, &"nitro_regen", taxi.nitro_regen)
	var tank := 1.0 + value(&"nitro")
	var old_max := taxi.nitro_max
	taxi.nitro_max = float(taxi.get_meta(&"base_nitro_max")) * tank
	taxi.nitro_regen = float(taxi.get_meta(&"base_nitro_regen")) * tank
	taxi.add_nitro(maxf(taxi.nitro_max - old_max, 0.0))   # the new bottle comes full
	var damage := taxi.get_node_or_null("TaxiDamage") as TaxiDamage
	if damage == null:
		return
	_base(damage, &"taxi_max_hp", damage.taxi_health.max_hp)
	_base(damage, &"driver_damage_mult", damage.driver_damage_mult)
	_base(damage, &"crash_damage_scale", damage.crash_damage_scale)
	# Armor (parts) and the Juggernaut perk (slots, D-107) add up.
	var new_max := float(damage.get_meta(&"base_taxi_max_hp")) * (1.0 + value(&"armor") + value(&"max_hp"))
	var gained := new_max - damage.taxi_health.max_hp
	damage.taxi_health.max_hp = new_max
	if gained > 0.0 and not damage.is_wrecked:
		damage.taxi_health.heal(gained)   # the new plates come undamaged
	damage.driver_damage_mult = float(damage.get_meta(&"base_driver_damage_mult")) * maxf(1.0 - value(&"glass"), 0.1)
	damage.crash_damage_scale = float(damage.get_meta(&"base_crash_damage_scale")) * maxf(1.0 - value(&"ram"), 0.1)


static func _base(node: Object, key: StringName, current: float) -> void:
	var meta := StringName("base_%s" % key)
	if not node.has_meta(meta):
		node.set_meta(meta, current)


# --- Monstrous Energy ------------------------------------------------------------------

## Buys `count` cans. Returns an error text ("" = done).
static func buy_cans(count: int = 1) -> String:
	var room := can_capacity() - GameState.cans
	if room <= 0:
		return "The cup holders are full (%d cans)." % can_capacity()
	count = mini(count, room)
	if GameState.cash < CAN_PRICE * count:
		return "Not enough cash: a can is $%d." % CAN_PRICE
	GameState.add_cash(-CAN_PRICE * count)
	GameState.cans += count
	return ""


## Drinks a carried can (F / Y). Returns an error text ("" = done).
static func drink_can(tree: SceneTree) -> String:
	if GameState.cans <= 0:
		return "No Monstrous Energy left: buy cans in the shop."
	var taxi := tree.get_first_node_in_group(&"player_vehicle") as Node
	var damage := taxi.get_node_or_null("TaxiDamage") as TaxiDamage if taxi != null else null
	if damage == null or damage.is_wrecked or damage.is_dead:
		return "Not now."
	if damage.driver_health.hp >= damage.driver_health.max_hp and damage.taxi_health.hp >= damage.taxi_health.max_hp:
		return "You feel fine. Save it."
	GameState.cans -= 1
	var m := can_mult()
	damage.drink(CAN_DRIVER_HEAL * m, CAN_BODY_HEAL * m, CAN_HEAL_TIME)
	EventBus.energy_drink_consumed.emit()
	EventBus.hud_message.emit("*CRACK*  MONSTROUS ENERGY!  (%d left)" % GameState.cans, &"good")
	return ""


# --- Repair ----------------------------------------------------------------------------

static func repair_quote(damage: TaxiDamage) -> int:
	if damage == null:
		return 0
	var driver := (damage.driver_health.max_hp - damage.driver_health.hp) if damage.has_driver_bar() else 0.0
	return ceili((damage.taxi_health.max_hp - damage.taxi_health.hp) * REPAIR_PER_TAXI_HP
			+ driver * REPAIR_PER_DRIVER_HP)


## Repairs the cab and the driver for money (anywhere, D-089). Returns an error text ("" = done).
static func repair(tree: SceneTree) -> String:
	var taxi := tree.get_first_node_in_group(&"player_vehicle") as Node
	var damage := taxi.get_node_or_null("TaxiDamage") as TaxiDamage if taxi != null else null
	if damage == null or damage.is_dead:
		return "Nothing left to repair."
	var fee := repair_quote(damage)
	if fee <= 0:
		return "The cab is in one piece."
	if GameState.cash < fee:
		return "Not enough cash: the repair is $%d." % fee
	GameState.add_cash(-fee)
	damage.repair()
	EventBus.hud_message.emit("REPAIRED  -$%d" % fee, &"good")
	return ""
