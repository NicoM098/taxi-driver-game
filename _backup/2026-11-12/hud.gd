extends Control
## Gameplay HUD (native resolution, outside the PS1 viewport). Built in code.
## Polls the taxi / RideManager / ShiftManager / DriftChain each frame and listens to
## EventBus for popups and the shift summary.

const COLORS := {
	&"info": Color(1, 1, 1),
	&"good": Color(0.45, 1, 0.45),
	&"bad": Color(1, 0.4, 0.35),
	&"drift": Color(1, 0.75, 0.2),
}

var _shift_label: Label
var _cash_label: Label
var _ride_label: Label
var _speed_label: Label
var _hint_label: Label
var _drift_label: Label
var _drift_bar: ColorRect
var _message_label: Label
var _summary: ColorRect
var _summary_label: Label
var _message_tween: Tween
var _ammo_label: Label
var _weapons_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shift_label = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_shift_label, 0, 0, 1, 0, 0, 6, 0, 60)
	_ride_label = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_ride_label, 0, 0, 1, 0, 0, 60, 0, 92)
	_cash_label = _label(32, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_cash_label, 1, 0, 1, 0, -320, 10, -18, 50)
	_speed_label = _label(34, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_speed_label, 1, 1, 1, 1, -320, -62, -18, -14)
	_hint_label = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_hint_label, 0, 1, 1, 1, 0, -40, 0, -12)
	_drift_label = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_drift_label, 0, 0.7, 1, 0.7, 0, 0, 0, 36)
	_drift_bar = ColorRect.new()
	_drift_bar.color = COLORS[&"drift"]
	_drift_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drift_bar)
	_place(_drift_bar, 0.5, 0.7, 0.5, 0.7, -100, 40, 100, 46)
	for script_path: String in ["res://src/ui/hud/damage_indicator.gd", "res://src/ui/hud/status_bars.gd",
			"res://src/ui/hud/threat_markers.gd"]:
		var c := Control.new()
		c.set_script(load(script_path))
		add_child(c)
		_place(c, 0, 0, 1, 1, 0, 0, 0, 0)
	var crosshair := Control.new()
	crosshair.set_script(preload("res://src/ui/hud/crosshair.gd"))
	add_child(crosshair)
	_place(crosshair, 0, 0, 1, 1, 0, 0, 0, 0)
	_ammo_label = _label(30, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_ammo_label, 0, 1, 0, 1, 18, -62, 520, -14)
	_weapons_label = _label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_weapons_label, 0, 1, 0, 1, 18, -88, 620, -62)
	_message_label = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_message_label, 0, 0.32, 1, 0.32, 0, 0, 0, 40)
	_message_label.modulate.a = 0.0

	_summary = ColorRect.new()
	_summary.color = Color(0, 0, 0, 0.7)
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary.visible = false
	add_child(_summary)
	_place(_summary, 0.5, 0.5, 0.5, 0.5, -280, -160, 280, 160)
	_summary_label = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_summary_label.reparent(_summary)
	_place(_summary_label, 0, 0, 1, 1, 10, 10, -10, -10)
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	EventBus.hud_message.connect(show_message)
	EventBus.shift_ended.connect(_on_shift_ended)
	EventBus.shift_started.connect(func(_n: int) -> void: _summary.visible = false)


func _process(_delta: float) -> void:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	var rides := get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager

	_cash_label.text = "$%d" % GameState.cash
	_speed_label.text = "%d km/h" % roundi(taxi.get_speed_kmh()) if taxi != null else ""

	if shift != null and shift.is_active:
		_shift_label.text = _format_time(shift.time_left)
		_shift_label.modulate = COLORS[&"bad"] if shift.time_left < 15.0 else Color.WHITE
	else:
		_shift_label.text = ""

	_ride_label.text = ""
	_hint_label.text = ""
	if rides != null and shift != null and shift.is_active:
		match rides.state:
			RideManager.State.RIDING:
				var ride := rides.ride
				var dist := taxi.global_position.distance_to(ride.destination.global_position) if taxi != null else 0.0
				_ride_label.text = "→ %s   %d m   %s" % [ride.destination.stop_name, roundi(dist), _format_time(ride.time_left)]
				_ride_label.modulate = COLORS[&"bad"] if ride.time_ratio() < 0.25 else Color.WHITE
				_hint_label.text = "Stop inside the green ring"
			RideManager.State.ENTERING:
				_hint_label.text = "Passenger boarding — hold still"
			RideManager.State.DOSSIER:
				_hint_label.text = "Read the passenger file"
			RideManager.State.IDLE:
				_hint_label.text = "Find a passenger (yellow beam) and stop next to them"

	_update_weapon_hud()

	var chain := taxi.get_node_or_null("DriftChain") as DriftChain if taxi != null else null
	if chain != null and chain.is_active:
		_drift_label.text = "DRIFT  x%.2f   %d" % [chain.multiplier, roundi(chain.points)]
		_drift_label.modulate = COLORS[&"drift"]
		_drift_bar.visible = true
		_drift_bar.scale.x = clampf(chain.window_left / chain.chain_window, 0.0, 1.0)
	else:
		_drift_label.text = ""
		_drift_bar.visible = false


func _update_weapon_hud() -> void:
	var wc := get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	var w := wc.current_weapon() if wc != null else null
	if w == null:
		_ammo_label.text = ""
		_weapons_label.text = ""
		return
	var a := wc.get_ammo()
	if wc.is_reloading:
		_ammo_label.text = "%s   RELOADING %d%%" % [w.display_name.to_upper(), roundi(wc.get_reload_progress() * 100.0)]
		_ammo_label.modulate = COLORS[&"drift"]
	else:
		_ammo_label.text = "%s   %d | %d" % [w.display_name.to_upper(), a["mag"], a["reserve"]]
		_ammo_label.modulate = COLORS[&"bad"] if a["mag"] == 0 else Color.WHITE
	var names := PackedStringArray()
	for i in wc.weapons.size():
		var n := "%d %s" % [i + 1, wc.weapons[i].display_name]
		names.append("[%s]" % n if i == wc.current_index else n)
	_weapons_label.text = "   ".join(names)


func show_message(text: String, kind: StringName = &"info") -> void:
	_message_label.text = text
	_message_label.modulate = COLORS.get(kind, Color.WHITE)
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.6)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.6)


func _on_shift_ended(summary: Dictionary) -> void:
	_summary.visible = true
	var titles := {&"taxi_destroyed": "WRECKED!", &"driver_killed": "SHOT DEAD!"}
	var title: String = titles.get(summary.get("reason", &"time_up"), "SHIFT %d OVER" % summary["shift_number"])
	_summary_label.text = title + "\n\nRides: %d   (failed %d)\nEarned: $%d\nBest drift chain: %d links\nTotal cash: $%d\n\nE / Enter / D-pad ↑  →  next shift" % [
		summary["rides_completed"], summary["rides_failed"],
		summary["cash_earned"], summary["best_drift_links"], summary["total_cash"]]


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _place(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


static func _format_time(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60]
