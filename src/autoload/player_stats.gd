extends Node
## Final gameplay stats = base value + modifiers from upgrades/perks/items.
## Stub for now: modifiers arrive in Phases 08-09. Systems should already read values through get_stat().

signal stats_changed

const BASE_STATS: Dictionary = {
	&"reload_speed": 1.0,
	&"aim_spread_mult": 1.0,
	&"examine_time_mult": 1.0,
	&"fare_mult": 1.0,
	&"taxi_max_hp": 100.0,
}


func get_stat(id: StringName) -> float:
	return float(BASE_STATS.get(id, 0.0))


func notify_changed() -> void:
	stats_changed.emit()
