class_name Tutorial
extends Control
## The short first-time tutorial (main menu → TUTORIAL). Lives in Main's UI layer and only
## does something while GameState.tutorial_active is on. Six prompts, each one advances by
## doing it: drive → drift → shoot → pick up a fare → read the file → deliver. While it runs
## the spawner only sends calm fares and street encounters are off; at the end the flag is
## cleared and the city plays as normal.

enum Step { WAIT, DRIVE, DRIFT, SHOOT, PICKUP, FILE, DELIVER, DONE, OFF }

## km/h to hold for `drive_hold` seconds to pass the driving step.
@export var drive_speed_kmh: float = 35.0
@export var drive_hold: float = 1.5
## The drift step gives up after this long (it is the hardest one).
@export var drift_give_up: float = 30.0
@export var done_seconds: float = 9.0

const STEPS_SHOWN := 6
const YELLOW := Color(1.0, 0.82, 0.1)

var step: Step = Step.OFF

var _panel: PanelContainer
var _title: Label
var _body: Label
var _t: float = 0.0
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(&"tutorial")
	_build()
	EventBus.weapon_fired.connect(func(_w: Resource) -> void:
		if step == Step.SHOOT:
			_go(Step.PICKUP))
	EventBus.ride_completed.connect(func(_r: RefCounted, _pay: int) -> void:
		if step == Step.DELIVER:
			_go(Step.DONE))
	EventBus.ride_failed.connect(func(_r: RefCounted, _reason: StringName) -> void:
		if step == Step.DELIVER or step == Step.FILE:
			EventBus.hud_message.emit("No fare that time — find another one", &"bad")
			_go(Step.PICKUP))
	if GameState.tutorial_active:
		_go(Step.WAIT)
	else:
		visible = false


func _process(delta: float) -> void:
	if step == Step.OFF:
		return
	_t += delta
	var tree := get_tree()
	var taxi := tree.get_first_node_in_group(&"player_vehicle") as Taxi
	var rides := tree.get_first_node_in_group(&"ride_manager") as RideManager
	var shift := tree.get_first_node_in_group(&"shift_manager") as ShiftManager
	var dossier := tree.get_first_node_in_group(&"dossier") as Dossier
	var file_open := dossier != null and dossier.is_open
	match step:
		Step.WAIT:
			if shift != null and shift.is_active:
				_go(Step.DRIVE)
		Step.DRIVE:
			if taxi != null and not tree.paused:
				if taxi.get_speed_kmh() >= drive_speed_kmh:
					if _t >= drive_hold:
						_go(Step.DRIFT)
				else:
					_t = 0.0
		Step.DRIFT:
			var chain := taxi.get_node_or_null("DriftChain") as DriftChain if taxi != null else null
			if chain != null and chain.is_active:
				EventBus.hud_message.emit("NICE DRIFT!", &"drift")
				_go(Step.SHOOT)
			elif _t > drift_give_up:
				_go(Step.SHOOT)
		Step.PICKUP:
			if file_open or (rides != null and rides.state == RideManager.State.DOSSIER):
				_go(Step.FILE)
		Step.FILE:
			if not file_open and rides != null:
				if rides.state == RideManager.State.RIDING:
					_go(Step.DELIVER)
				elif rides.state == RideManager.State.IDLE:
					_go(Step.PICKUP)
		Step.DELIVER:
			if rides != null and rides.state == RideManager.State.IDLE and _t > 1.0:
				_go(Step.PICKUP)
		Step.DONE:
			if _t > done_seconds:
				_finish()
	_refresh_text()


## Ends the tutorial early (also used by tests).
func skip() -> void:
	_finish()


func _go(next: Step) -> void:
	step = next
	_t = 0.0
	visible = step != Step.OFF and step != Step.WAIT
	if step == Step.PICKUP:
		_place_fare()
	if step == Step.DONE:
		GameState.tutorial_active = false   # normal city from here on
	_refresh_text()
	if visible:
		if _tween != null:
			_tween.kill()
		_panel.modulate = Color(1.6, 1.6, 1.6, 0.0)
		_tween = create_tween()
		_tween.tween_property(_panel, "modulate", Color.WHITE, 0.35)


func _finish() -> void:
	GameState.tutorial_active = false
	step = Step.OFF
	visible = false


## Puts a calm fare at the nearest free taxi stop that is not right under the car.
func _place_fare() -> void:
	var spawner := get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
	var city := get_tree().get_first_node_in_group(&"city") as City
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	if spawner == null or city == null or taxi == null:
		return
	var profile := spawner.tutorial_profile()
	if profile == null:
		return
	var best: TaxiStop = null
	var best_d := INF
	for stop in city.stops:
		var d := stop.global_position.distance_to(taxi.global_position)
		if not stop.occupied and d > 25.0 and d < best_d:
			best_d = d
			best = stop
	if best != null:
		spawner.spawn_at(profile, best)


func _refresh_text() -> void:
	var pad := InputDevice.using_gamepad
	var n := clampi(int(step), 1, STEPS_SHOWN)
	_title.text = "TUTORIAL  %d / %d" % [n, STEPS_SHOWN] if step != Step.DONE else "TUTORIAL  DONE"
	match step:
		Step.DRIVE:
			_body.text = ("RT accelerate, LT brake / reverse, left stick steers." if pad
					else "W accelerate, S brake / reverse, A / D steer.") + "\nGet up to speed."
		Step.DRIFT:
			_body.text = ("Hold B" if pad else "Hold SPACE") + " (handbrake) while turning to drift.\nDrifting left-right-left chains a multiplier: money and speed."
		Step.SHOOT:
			_body.text = ("Hold LB to raise the gun, RB to fire. Right stick aims." if pad
					else "Hold RIGHT MOUSE to raise the gun, LEFT MOUSE to fire.") + "\nFire a shot."
		Step.PICKUP:
			_body.text = "A passenger is waiting under the yellow beam.\nDrive up, stop right next to them and wait."
		Step.FILE:
			_body.text = "Their file. Underlined details can be examined (costs ride time).\nChoose what to do — DRIVE accepts the fare."
		Step.DELIVER:
			_body.text = "Follow the arrow to the green ring and stop inside it before the red clock runs out."
		Step.DONE:
			_body.text = "Fare paid — you're a cabbie.\nRead every file: some fares bring hitmen, thieves or worse.\n%s pauses (main menu, run stats)." % ("Start" if pad else "Esc")
		_:
			_body.text = ""


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	style.border_color = YELLOW
	style.border_width_left = 6
	style.content_margin_left = 16
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -400.0
	_panel.offset_right = -18.0
	_panel.offset_top = 64.0
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", YELLOW)
	col.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 350.0
	_body.add_theme_font_size_override("font_size", 19)
	col.add_child(_body)
