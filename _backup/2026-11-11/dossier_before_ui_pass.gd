class_name Dossier
extends Control
## The passenger file (Phase 04, Papers, Please layer). Opens on EventBus.dossier_opened:
## pauses the world (this node keeps running), shows identity / destination / fare estimate /
## notes with highlighted details. Examining a detail costs shift time, appends what you found
## and can unlock actions. Choosing an action closes the file and emits dossier_action_chosen.
## While open, the shift clock drains at `reading_drain` x real time.
## Mouse: click highlighted words or buttons. Gamepad: d-pad/stick focus + A.

@export var reading_drain: float = 0.5

var is_open: bool = false
var passenger: PassengerInstance

var _paper: ColorRect
var _title: Label
var _portrait: Control
var _fields: RichTextLabel
var _notes: RichTextLabel
var _found: RichTextLabel
var _examine_box: HBoxContainer
var _actions_box: VBoxContainer
var _clock: Label
var _file_no: int = 0

const INK := Color(0.12, 0.1, 0.08)
const PAPER := Color(0.92, 0.88, 0.78)
const RED := "#a3201a"


func _ready() -> void:
	add_to_group(&"dossier")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	EventBus.dossier_opened.connect(open)
	EventBus.shift_ended.connect(func(_s: Dictionary) -> void:
		if is_open:
			close())


func _process(delta: float) -> void:
	if not is_open:
		return
	var shift := _shift()
	if shift != null and shift.is_active:
		shift.time_left = maxf(shift.time_left - delta * reading_drain, 0.0)
		_clock.text = "SHIFT CLOCK %s  (reading costs time)" % _fmt(shift.time_left)
		if shift.time_left <= 0.0:
			close()   # out of time: the shift ends, the passenger gets out


# --- API (also used by tests) ---------------------------------------------------------

func open(p: RefCounted) -> void:
	passenger = p as PassengerInstance
	if passenger == null:
		return
	_file_no += 1
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.dossier_closed.emit()


func examine(id: StringName) -> void:
	if not is_open:
		return
	var e := passenger.examine(id)
	if e == null:
		return
	var shift := _shift()
	if shift != null:
		shift.time_left = maxf(shift.time_left - e.time_cost, 0.0)
	_refresh()


func choose(action_id: StringName) -> void:
	if not is_open:
		return
	for a in passenger.available_actions():
		if a.id == action_id:
			var p := passenger
			close()
			EventBus.dossier_action_chosen.emit(p, a)
			return


func available_action_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if passenger != null:
		for a in passenger.available_actions():
			ids.append(a.id)
	return ids


# --- Build / refresh --------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_fill(dim, 0, 0, 0, 0)

	_paper = ColorRect.new()
	_paper.color = PAPER
	add_child(_paper)
	_paper.anchor_left = 0.5
	_paper.anchor_top = 0.5
	_paper.anchor_right = 0.5
	_paper.anchor_bottom = 0.5
	_paper.offset_left = -400
	_paper.offset_top = -330
	_paper.offset_right = 400
	_paper.offset_bottom = 330

	_title = _label(26, INK)
	_paper.add_child(_title)
	_title.position = Vector2(24, 14)

	_portrait = Control.new()
	_portrait.set_script(preload("res://src/dossier/dossier_portrait.gd"))
	_paper.add_child(_portrait)
	_portrait.position = Vector2(24, 60)
	_portrait.size = Vector2(150, 190)

	_fields = _rich(18)
	_paper.add_child(_fields)
	_fields.position = Vector2(196, 60)
	_fields.size = Vector2(580, 150)

	_notes = _rich(18)
	_paper.add_child(_notes)
	_notes.position = Vector2(196, 205)
	_notes.size = Vector2(580, 80)
	_notes.meta_clicked.connect(func(meta: Variant) -> void: examine(StringName(str(meta))))

	_found = _rich(16)
	_paper.add_child(_found)
	_found.position = Vector2(24, 290)
	_found.size = Vector2(752, 110)

	_examine_box = HBoxContainer.new()
	_examine_box.add_theme_constant_override("separation", 10)
	_paper.add_child(_examine_box)
	_examine_box.position = Vector2(24, 404)
	_examine_box.size = Vector2(752, 34)

	_actions_box = VBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", 5)
	_paper.add_child(_actions_box)
	_actions_box.position = Vector2(24, 446)
	_actions_box.size = Vector2(752, 120)

	_clock = _label(15, Color(0.45, 0.15, 0.1))
	_paper.add_child(_clock)
	_clock.position = Vector2(470, 22)   # top right, next to the title: never covered by buttons


func _refresh() -> void:
	var p := passenger
	var prof := p.profile
	_title.text = "PASSENGER FILE  No. %04d" % (400 + _file_no)
	_portrait.set(&"passenger", p)
	_portrait.queue_redraw()

	var dest := p.destination
	var dist := 0.0
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	if dest != null and taxi != null:
		dist = Vector2(dest.global_position.x - taxi.global_position.x, dest.global_position.z - taxi.global_position.z).length()
	var fare := roundi(prof.fare_base + prof.fare_per_100m * dist / 100.0)
	_fields.text = "[b]NAME[/b]  %s\n[b]AGE[/b]  %d\n[b]OCCUPATION[/b]  %s\n[b]DESTINATION[/b]  %s  [i](%s, %d m)[/i]\n[b]FARE[/b]  ~$%d   [i](up to $%d if speedy)[/i]" % [
		p.display_name, p.age, prof.occupation,
		dest.stop_name if dest != null else "?", String(dest.district).capitalize() if dest != null else "?", roundi(dist),
		fare, roundi(fare * 1.5)]

	var notes := prof.notes
	for e in prof.examinables:
		var color := "#7a7166" if p.is_examined(e.id) else RED
		notes = notes.replace("[url=%s]" % e.id, "[color=%s][url=%s]" % [color, e.id])
	notes = notes.replace("[/url]", "[/url][/color]")
	_notes.text = "[b]NOTES[/b]  " + notes

	var found := ""
	for id in p.examined:
		var e := p.get_examinable(id)
		if e != null:
			found += "[color=%s]> %s:[/color] %s\n" % [RED, e.label.capitalize(), e.reveal_text]
	_found.text = found

	for c in _examine_box.get_children():
		c.queue_free()
	for e in prof.examinables:
		if p.is_examined(e.id):
			continue
		var b := _button("Examine %s  (-%ds)" % [e.label, roundi(e.time_cost)], 15)
		b.pressed.connect(examine.bind(e.id))
		_examine_box.add_child(b)

	for c in _actions_box.get_children():
		c.queue_free()
	var first: Button = null
	for a in p.available_actions():
		var b := _button(a.label, 18)
		if a.outcome == PassengerAction.Outcome.KILL:
			b.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		b.pressed.connect(choose.bind(a.id))
		_actions_box.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.call_deferred(&"grab_focus")


# --- Helpers ----------------------------------------------------------------------------

func _shift() -> ShiftManager:
	return get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _rich(font_size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_font_size_override("italics_font_size", font_size - 2)
	r.add_theme_color_override("default_color", INK)
	return r


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", font_size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


func _fill(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = 0
	c.anchor_top = 0
	c.anchor_right = 1
	c.anchor_bottom = 1
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


static func _fmt(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60]
