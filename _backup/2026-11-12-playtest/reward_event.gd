class_name RewardEvent
extends RideEvent
## The passenger gives the driver something (stand-in for DropItemEvent until Phase 08 items
## exist). One of `kinds` is picked at random: &"heal", &"cash", &"ammo", &"time".
## A heal is skipped when the driver and taxi are already at full health.

@export var kinds: Array[StringName] = [&"cash"]
@export var heal_amount: float = 35.0
@export var cash_amount: int = 40
## Magazines added to the reserve of every weapon.
@export var ammo_mags: int = 1
## Shift seconds.
@export var time_amount: float = 10.0
@export var line: String = "Here, take this."


func start(ctx: RideContext, _state: Dictionary) -> bool:
	var options: Array[StringName] = []
	for k in kinds:
		if k == &"heal" and ctx.damage != null and _full_health(ctx.damage):
			continue
		options.append(k)
	if options.is_empty():
		options = [&"cash"]
	var kind: StringName = options[ctx.rng.randi() % options.size()]
	var what := ""
	var amount := 0.0
	match kind:
		&"heal":
			amount = heal_amount
			if ctx.damage != null:
				ctx.damage.drink(heal_amount, heal_amount * 0.6, 1.5)
			what = "+%d HEALTH" % roundi(heal_amount)
		&"ammo":
			amount = ammo_mags
			var wc := ctx.taxi.get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
			if wc != null:
				for w in wc.weapons:
					var a: Dictionary = wc.ammo[w.id]
					a["reserve"] = mini(int(a["reserve"]) + w.mag_size * ammo_mags, w.reserve_max)
			what = "AMMO"
		&"time":
			amount = time_amount
			if ctx.shift != null:
				ctx.shift.add_time(time_amount)
			what = "+%d s SHIFT TIME" % roundi(time_amount)
		_:
			kind = &"cash"
			amount = cash_amount
			GameState.add_cash(cash_amount)
			if ctx.shift != null:
				ctx.shift.register_bonus_cash(cash_amount)
			what = "+$%d" % cash_amount
	EventBus.passenger_bark.emit(ctx.speaker(), "%s   [%s]" % [line, what])
	EventBus.ride_reward.emit(kind, amount)
	return false


func _full_health(d: TaxiDamage) -> bool:
	return d.driver_health.hp >= d.driver_health.max_hp and d.taxi_health.hp >= d.taxi_health.max_hp
