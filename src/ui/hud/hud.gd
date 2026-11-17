extends Control
## Gameplay HUD (native resolution, outside the PS1 viewport). Built in code.
## Polls the taxi / RideManager / ShiftManager / DriftChain each frame and listens to
## EventBus for popups and the wreck summary. No shift clock: the only countdown is the
## passenger's (bold red under the guide arrow while a ride is on).

const COLORS := {
	&"info": Color(1, 1, 1),
	&"good": Color(0.45, 1, 0.45),
	&"bad": Color(1, 0.4, 0.35),
	&"drift": Color(1, 0.75, 0.2),
	&"style": Color(1, 0.88, 0.3),
}

var _timer_label: Label
var _cash_label: Label
var _ride_label: Label
var _speed_label: Label
var _hint_label: Label
var _minimap: Minimap
var _style_label: Label
var _style_tween: Tween
var _drift_label: Label
var _drift_bar: ColorRect
var _message_label: Label
var _summary: ColorRect
var _summary_label: Label
var _message_tween: Tween
var _bark_label: Label
var _bark_tween: Tween
var _alert_label: Label
var _prompt_label: Label
var _prompt_source: Node = null
var _alert_text: String = ""
var _alert_left: float = 0.0
var _bold: FontVariation

## Vertical anchor (share of the screen height) of the passenger countdown: just below the
## guide arrow at the top centre.
const TIMER_ANCHOR_Y := 0.39
const TIMER_RED := Color(1.0, 0.16, 0.12)
## Square side in pixels (native resolution, outside the PS1 viewport).
const MINIMAP_SIZE := 164.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.9
	# Passenger countdown: bold red, right under the guide arrow, from the moment the ride
	# starts (there is no shift clock). Destination + distance in a small line above the arrow.
	# The arrow covers roughly 0.22-0.38 of the screen height, the crosshair sits at 0.5.
	_timer_label = _label(42, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_timer_label, 0, TIMER_ANCHOR_Y, 1, TIMER_ANCHOR_Y, 0, 0, 0, 52)
	_timer_label.add_theme_font_override("font", _bold)
	_timer_label.add_theme_color_override("font_color", TIMER_RED)
	_timer_label.add_theme_constant_override("outline_size", 10)
	_ride_label = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_ride_label, 0, 0.185, 1, 0.185, 0, 0, 0, 28)
	_cash_label = _label(32, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_cash_label, 1, 0, 1, 0, -320, 10, -18, 50)
	# Minimap above the speed, in the one corner the HUD was not already using (D-083).
	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	add_child(_minimap)
	_place(_minimap, 1, 1, 1, 1, -MINIMAP_SIZE - 18, -MINIMAP_SIZE - 76, -18, -76)
	_speed_label = _label(34, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_speed_label, 1, 1, 1, 1, -320, -62, -18, -14)
	_hint_label = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	# Between the weapon hotbar (left, ~510 px) and the speedometer (right).
	_place(_hint_label, 0, 1, 1, 1, 530, -70, -330, -12)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
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
	# Weapon hotbar (slot cards, silhouettes, ammo) bottom-left.
	var bar := WeaponBar.new()
	add_child(bar)
	_place(bar, 0, 0, 1, 1, 0, 0, 0, 0)
	_message_label = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	# Popups sit on the dark roof lining above the arrow (they used to cover the arrow).
	_place(_message_label, 0, 0.115, 1, 0.115, 0, 0, 0, 40)
	_message_label.modulate.a = 0.0
	# The style popup sits under the message line, bigger: it is a reward, not a notification.
	_style_label = _label(46, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_style_label, 0, 0.2, 1, 0.2, 0, 0, 0, 58)
	_style_label.modulate.a = 0.0
	# Passenger barks (subtitles) above the bottom hint; urgent ride alerts mid-screen.
	_bark_label = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_bark_label, 0.15, 1, 0.85, 1, 0, -170, 0, -96)
	_bark_label.add_theme_font_override("font", _bold)
	_bark_label.add_theme_constant_override("outline_size", 9)
	_bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bark_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_bark_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_bark_label.modulate.a = 0.0
	_alert_label = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_alert_label, 0, 0.53, 1, 0.53, 0, 0, 0, 46)
	_alert_label.add_theme_color_override("font_color", COLORS[&"bad"])
	_alert_label.visible = false
	# "[E]  REPAIR  -$34" while parked on a shop pad: below the crosshair, above the drift meter.
	_prompt_label = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_prompt_label, 0, 0.62, 1, 0.62, 0, 0, 0, 40)
	_prompt_label.add_theme_font_override("font", _bold)
	_prompt_label.add_theme_constant_override("outline_size", 9)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_prompt_label.visible = false

	_summary = ColorRect.new()
	_summary.color = Color(0, 0, 0, 0.7)
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary.visible = false
	add_child(_summary)
	_place(_summary, 0.5, 0.5, 0.5, 0.5, -300, -200, 300, 200)
	_summary_label = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_summary_label.reparent(_summary)
	_place(_summary_label, 0, 0, 1, 1, 10, 10, -10, -10)
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	add_child(RideCard.new())   # gang-rides mode: announces each fare (D-088)

	EventBus.hud_message.connect(show_message)
	EventBus.style_earned.connect(_on_style_earned)
	EventBus.passenger_bark.connect(show_bark)
	EventBus.ride_alert.connect(show_alert)
	EventBus.interact_prompt.connect(show_prompt)
	EventBus.shift_ended.connect(_on_shift_ended)
	EventBus.shift_started.connect(func(_n: int) -> void: _summary.visible = false)


func _process(delta: float) -> void:
	if _alert_left > 0.0:
		_alert_left -= delta
		_alert_label.visible = _alert_left > 0.0
		_alert_label.text = "%s   %.1f" % [_alert_text.replace("{kick}", _kick_key()), maxf(_alert_left, 0.0)]
		_alert_label.modulate.a = 1.0 if fmod(_alert_left, 0.3) < 0.2 else 0.45
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	var rides := get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager

	_cash_label.text = "$%d" % GameState.cash
	_speed_label.text = "%d km/h" % roundi(taxi.get_speed_kmh()) if taxi != null else ""

	_ride_label.text = ""
	_hint_label.text = ""
	_timer_label.text = ""
	if rides != null and shift != null and shift.is_active:
		match rides.state:
			RideManager.State.RIDING:
				var ride := rides.ride
				var dist := taxi.global_position.distance_to(ride.destination.global_position) if taxi != null else 0.0
				_timer_label.text = _format_time(ride.time_left)
				# Last quarter of the clock: the countdown blinks.
				var hurry := ride.time_ratio() < 0.25
				_timer_label.modulate.a = 0.45 if hurry and fmod(ride.time_left, 0.5) < 0.2 else 1.0
				_ride_label.text = "→ %s   %d m" % [ride.destination.stop_name, roundi(dist)]
				_hint_label.text = "Drive into the green ring" if GangRides.enabled else "Stop inside the green ring"
				if rides.can_kick_mid_ride():
					_hint_label.text += "   ·   %s: throw the passenger out" % _kick_key()
			RideManager.State.ENTERING:
				_hint_label.text = "Passenger boarding — hold still"
			RideManager.State.DOSSIER:
				_hint_label.text = "Read the passenger file"
			RideManager.State.IDLE:
				if rides.is_dead():
					_hint_label.text = ""
				elif rides.is_wrecked():
					_hint_label.text = "WRECKED — follow the arrow to a repair shop (red beacon) and stop on the yellow pad"
				else:
					_hint_label.text = "Find a passenger (yellow beam) and stop next to them"

	var chain := taxi.get_node_or_null("DriftChain") as DriftChain if taxi != null else null
	if chain != null and chain.is_active:
		_drift_label.text = "DRIFT  x%.2f   %d" % [chain.multiplier, roundi(chain.points)]
		_drift_label.modulate = COLORS[&"drift"]
		_drift_bar.visible = true
		_drift_bar.scale.x = clampf(chain.window_left / chain.chain_window, 0.0, 1.0)
	else:
		_drift_label.text = ""
		_drift_bar.visible = false


## The arcade popup: big, centre-right, punches in and fades. Style only - ordinary messages
## stay as the quiet line (D-081).
func show_style(text: String) -> void:
	_style_label.text = text
	_style_label.modulate = COLORS[&"style"]
	_style_label.modulate.a = 1.0
	_style_label.pivot_offset = _style_label.size * 0.5
	_style_label.scale = Vector2(1.45, 1.45)
	if _style_tween != null:
		_style_tween.kill()
	_style_tween = create_tween()
	var punch := _style_tween.tween_property(_style_label, "scale", Vector2.ONE, 0.18)
	punch.set_trans(Tween.TRANS_BACK)
	punch.set_ease(Tween.EASE_OUT)
	_style_tween.tween_interval(0.9)
	_style_tween.tween_property(_style_label, "modulate:a", 0.0, 0.5)


func _on_style_earned(_kind: StringName, label: String, _points: float) -> void:
	show_style(label)


func show_message(text: String, kind: StringName = &"info") -> void:
	_message_label.text = text
	_message_label.modulate = COLORS.get(kind, Color.WHITE)
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.6)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.6)


## Subtitle line from the passenger: `Name: "text"`.
func show_bark(speaker: String, text: String) -> void:
	_bark_label.text = "%s: %s" % [speaker, text]
	_bark_label.modulate.a = 1.0
	if _bark_tween != null:
		_bark_tween.kill()
	_bark_tween = create_tween()
	_bark_tween.tween_interval(3.2)
	_bark_tween.tween_property(_bark_label, "modulate:a", 0.0, 0.6)


## What pressing interact would do here; empty text clears it, but only if `source` owns it.
func show_prompt(source: Node, text: String) -> void:
	if text == "":
		if source == _prompt_source:
			_prompt_source = null
			_prompt_label.visible = false
		return
	_prompt_source = source
	_prompt_label.text = text
	_prompt_label.visible = true


## Flashing prompt with a countdown; empty text clears it.
func show_alert(text: String, seconds: float) -> void:
	_alert_text = text
	_alert_left = seconds if text != "" else 0.0
	_alert_label.visible = _alert_left > 0.0


func _kick_key() -> String:
	return "D-pad ↓" if InputDevice.using_gamepad else "Q"


func _on_shift_ended(summary: Dictionary) -> void:
	show_alert("", 0.0)
	_summary.visible = true
	var titles := {&"taxi_destroyed": "WRECKED!", &"driver_killed": "SHOT DEAD!"}
	var title: String = titles.get(summary.get("reason", &"taxi_destroyed"), "WRECKED!")
	var passengers := "Kicked out: %d   Shot: %d   Hitmen down: %d" % [
		summary.get("passengers_kicked", 0), summary.get("passengers_killed", 0), summary.get("enemies_destroyed", 0)]
	var stolen: int = summary.get("cash_stolen", 0)
	if stolen > 0:
		passengers += "\nStolen from you: $%d" % stolen
	_summary_label.text = title + "\n\nRides: %d   (failed %d)\n%s\nEarned: $%d\nBest drift chain: %d links\nTotal cash: $%d\n\nE / Enter / D-pad ↑  →  back on the road" % [
		summary["rides_completed"], summary["rides_failed"], passengers,
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
