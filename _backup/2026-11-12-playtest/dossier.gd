class_name Dossier
extends Control
## The passenger file (Phase 04, Papers, Please layer). Opens on EventBus.dossier_opened:
## pauses the world (this node keeps running), shows identity / destination / fare estimate /
## notes with highlighted details. Examining a detail costs shift time, appends what you found
## and can unlock actions. Choosing an action closes the file and emits dossier_action_chosen.
## While open, the shift clock drains at `reading_drain` x real time.
## Mouse: click highlighted words or buttons. Gamepad: d-pad/stick focus + A.
##
## Layout (built in code, container-driven so the sheet is always as tall as its content):
## manila folder > paper sheet > header (title + shift clock) / photo + fields /
## observations (clues + "look closer" chips) / findings slip / "your call" action grid.

@export var reading_drain: float = 0.5
@export var low_time_warning: float = 20.0   # clock blinks below this many seconds

var is_open: bool = false
var passenger: PassengerInstance

var _sheet: Control
var _file_no_label: Label
var _portrait: Control
var _v_name: Label
var _v_age: Label
var _v_job: Label
var _v_dest: Label
var _v_dest_sub: Label
var _v_fare: Label
var _v_fare_sub: Label
var _notes: RichTextLabel
var _examine_box: HFlowContainer
var _found_panel: PanelContainer
var _found: RichTextLabel
var _actions_box: GridContainer
var _clock: Label
var _cost_pop: Label
var _file_no: int = 0
var _bold: FontVariation
var _pop_tween: Tween
var _open_tween: Tween
var _blink_t: float = 0.0

const INK := Color(0.12, 0.1, 0.08)
const INK_SOFT := Color(0.42, 0.36, 0.28)
const PAPER := Color(0.93, 0.89, 0.79)
const PAPER_DARK := Color(0.85, 0.8, 0.68)
const FOLDER := Color(0.72, 0.58, 0.34)
const FOLDER_EDGE := Color(0.45, 0.34, 0.18)
const SLIP := Color(0.98, 0.93, 0.62)
const TAXI_YELLOW := Color(0.98, 0.78, 0.15)
const FOCUS := Color(0.85, 0.4, 0.0)
const RED_C := Color(0.64, 0.13, 0.1)
const RED := "#a3201a"
const GREY := "#7a7166"
const SHEET_WIDTH := 840.0


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
		_clock.text = _fmt(shift.time_left)
		if shift.time_left <= low_time_warning:
			_blink_t += delta
			_clock.modulate.a = 1.0 if fmod(_blink_t, 0.5) < 0.3 else 0.35
		else:
			_clock.modulate.a = 1.0
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
	_cost_pop.modulate.a = 0.0
	_refresh(false)
	# Slide the folder up onto the screen.
	if _open_tween != null:
		_open_tween.kill()
	_sheet.modulate.a = 0.0
	_sheet.position.y = 26.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_sheet, "modulate:a", 1.0, 0.14)
	_open_tween.tween_property(_sheet, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	_pop_cost(e.time_cost)
	_refresh(true)


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


# --- Build ------------------------------------------------------------------------------

func _build() -> void:
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.7

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Manila folder with the paper sheet inside.
	var folder := PanelContainer.new()
	var folder_box := _box(FOLDER, FOLDER_EDGE, 2, 4, 9.0, 9.0)
	folder_box.shadow_color = Color(0, 0, 0, 0.5)
	folder_box.shadow_size = 14
	folder_box.shadow_offset = Vector2(0, 6)
	folder.add_theme_stylebox_override("panel", folder_box)
	center.add_child(folder)

	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _box(PAPER, Color(0.6, 0.54, 0.42), 1, 1, 22.0, 14.0))
	folder.add_child(paper)

	var col := VBoxContainer.new()
	col.custom_minimum_size.x = SHEET_WIDTH
	col.add_theme_constant_override("separation", 9)
	paper.add_child(col)

	col.add_child(_build_header())
	var rule := ColorRect.new()
	rule.color = INK
	rule.custom_minimum_size.y = 2.0
	col.add_child(rule)
	col.add_child(_build_identity())

	col.add_child(_section("OBSERVATIONS"))
	_notes = _rich(18)
	_notes.meta_clicked.connect(func(meta: Variant) -> void: examine(StringName(str(meta))))
	col.add_child(_notes)
	_examine_box = HFlowContainer.new()
	_examine_box.add_theme_constant_override("h_separation", 8)
	_examine_box.add_theme_constant_override("v_separation", 6)
	col.add_child(_examine_box)

	# Findings: a yellow slip clipped to the file, only visible once something was examined.
	_found_panel = PanelContainer.new()
	_found_panel.add_theme_stylebox_override("panel", _box(SLIP, Color(0.75, 0.66, 0.3), 1, 1, 12.0, 7.0))
	col.add_child(_found_panel)
	_found = _rich(16)
	_found_panel.add_child(_found)

	col.add_child(_section("YOUR CALL"))
	_actions_box = GridContainer.new()
	_actions_box.columns = 2
	_actions_box.add_theme_constant_override("h_separation", 8)
	_actions_box.add_theme_constant_override("v_separation", 6)
	col.add_child(_actions_box)

	var hint := _label(12, INK_SOFT)
	hint.text = "Click an underlined clue to look closer   ·   Gamepad: d-pad / stick + A"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	var title := _label(27, INK, true)
	title.text = "PASSENGER FILE"
	titles.add_child(title)
	_file_no_label = _label(12, INK_SOFT)
	titles.add_child(_file_no_label)

	_cost_pop = _label(20, RED_C, true)
	_cost_pop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cost_pop.modulate.a = 0.0
	row.add_child(_cost_pop)

	var clock_col := VBoxContainer.new()
	clock_col.add_theme_constant_override("separation", 0)
	row.add_child(clock_col)
	var clock_panel := PanelContainer.new()
	clock_panel.add_theme_stylebox_override("panel", _box(INK, INK, 0, 3, 12.0, 1.0))
	clock_col.add_child(clock_panel)
	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 10)
	clock_panel.add_child(clock_row)
	var clock_tag := _label(12, PAPER_DARK, true)
	clock_tag.text = "SHIFT"
	clock_row.add_child(clock_tag)
	_clock = _label(24, Color(1.0, 0.5, 0.32), true)
	_clock.text = "0:00"
	clock_row.add_child(_clock)
	var clock_note := _label(11, RED_C)
	clock_note.text = "runs while you read"
	clock_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_col.add_child(clock_note)
	return row


func _build_identity() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	_portrait = Control.new()
	_portrait.set_script(preload("res://src/dossier/dossier_portrait.gd"))
	_portrait.custom_minimum_size = Vector2(150, 190)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 7)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(grid)

	_v_name = _field(grid, "NAME", 23, true)[0]
	_v_age = _field(grid, "AGE", 18, false)[0]
	_v_job = _field(grid, "OCCUPATION", 18, false)[0]
	var dest := _field(grid, "DESTINATION", 18, true)
	_v_dest = dest[0]
	_v_dest_sub = dest[1]
	var fare := _field(grid, "FARE", 18, true)
	_v_fare = fare[0]
	_v_fare_sub = fare[1]
	return row


## Adds a "KEY  value  (detail)" row to the grid; returns [value label, detail label].
func _field(grid: GridContainer, key: String, value_size: int, bold: bool) -> Array[Label]:
	var k := _label(12, INK_SOFT, true)
	k.text = key
	k.custom_minimum_size.x = 104.0
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(k)
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 12)
	grid.add_child(cell)
	var value := _label(value_size, INK, bold)
	cell.add_child(value)
	var detail := _label(14, INK_SOFT)
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(detail)
	return [value, detail]


# --- Refresh ----------------------------------------------------------------------------

func _refresh(focus_examine: bool) -> void:
	var p := passenger
	var prof := p.profile
	_file_no_label.text = "No. %04d   ·   driver's copy" % (400 + _file_no)
	_portrait.set(&"passenger", p)
	_portrait.queue_redraw()

	var dest := p.destination
	var dist := 0.0
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	if dest != null and taxi != null:
		dist = Vector2(dest.global_position.x - taxi.global_position.x, dest.global_position.z - taxi.global_position.z).length()
	var fare := roundi(prof.fare_base + prof.fare_per_100m * dist / 100.0)
	_v_name.text = p.display_name
	_v_age.text = str(p.age)
	_v_job.text = prof.occupation
	_v_dest.text = dest.stop_name if dest != null else "?"
	_v_dest_sub.text = "%s  ·  %d m" % [String(dest.district).capitalize(), roundi(dist)] if dest != null else ""
	_v_fare.text = "~$%d" % fare
	_v_fare_sub.text = "up to $%d if you're quick" % roundi(fare * 1.5)

	var shift := _shift()
	if shift != null:
		_clock.text = _fmt(shift.time_left)

	var notes := prof.notes
	for e in prof.examinables:
		var color := GREY if p.is_examined(e.id) else RED
		notes = notes.replace("[url=%s]" % e.id, "[color=%s][url=%s]" % [color, e.id])
	notes = notes.replace("[/url]", "[/url][/color]")
	_notes.text = notes

	var found := ""
	for id in p.examined:
		var e := p.get_examinable(id)
		if e != null:
			if not found.is_empty():
				found += "\n"
			found += "[color=%s][b]%s[/b][/color]  %s" % [RED, e.label.capitalize(), e.reveal_text]
	_found.text = found
	_found_panel.visible = not found.is_empty()

	_clear(_examine_box)
	var first_examine: Button = null
	for e in prof.examinables:
		if p.is_examined(e.id):
			continue
		var b := _chip("Look closer: %s   -%ds" % [e.label, roundi(e.time_cost)])
		b.pressed.connect(examine.bind(e.id))
		_examine_box.add_child(b)
		if first_examine == null:
			first_examine = b
	_examine_box.visible = first_examine != null

	_clear(_actions_box)
	var first_action: Button = null
	var actions := p.available_actions()
	for a in actions:
		var b := _action_button(a, fare)
		b.pressed.connect(choose.bind(a.id))
		_actions_box.add_child(b)
		if first_action == null:
			first_action = b
	# An odd action count leaves a hole in the 2-column grid: pad it so the last row keeps its width.
	if actions.size() % 2 == 1:
		var pad := Control.new()
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_actions_box.add_child(pad)

	# Keep examining with the gamepad while clues remain, otherwise land on the first action.
	var target := first_examine if focus_examine and first_examine != null else first_action
	if target != null:
		target.call_deferred(&"grab_focus")


## What picking this action does, shown on the right of its button.
func _effects(a: PassengerAction, fare: int) -> String:
	var parts: PackedStringArray = []
	match a.outcome:
		PassengerAction.Outcome.DRIVE:
			parts.append("fare ~$%d" % roundi(fare * a.fare_mult))
			if not is_equal_approx(a.time_mult, 1.0):
				parts.append("%+d%% time" % roundi((a.time_mult - 1.0) * 100.0))
		PassengerAction.Outcome.KICK_OUT:
			parts.append("no fare")
	if a.cash_delta != 0:
		parts.append("%s$%d now" % ["+" if a.cash_delta > 0 else "-", absi(a.cash_delta)])
	if a.heat_delta != 0:
		parts.append("%+d heat" % a.heat_delta)
	if not is_zero_approx(a.shift_time_delta):
		parts.append("%+d s shift clock" % roundi(a.shift_time_delta))
	return "  ·  ".join(parts)


func _pop_cost(seconds: float) -> void:
	_cost_pop.text = "-%ds" % roundi(seconds)
	if _pop_tween != null:
		_pop_tween.kill()
	_cost_pop.modulate.a = 1.0
	_pop_tween = create_tween()
	_pop_tween.tween_interval(0.5)
	_pop_tween.tween_property(_cost_pop, "modulate:a", 0.0, 0.7)


# --- Helpers ----------------------------------------------------------------------------

func _shift() -> ShiftManager:
	return get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager


## Removes the children right away (queue_free alone leaves them in the layout and in the
## focus chain until the end of the frame).
func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _label(font_size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	return l


func _rich(font_size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_font_size_override("italics_font_size", font_size - 2)
	r.add_theme_color_override("default_color", INK)
	return r


## "TITLE ────────" divider.
func _section(title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(12, INK_SOFT, true)
	l.text = title
	row.add_child(l)
	var line := ColorRect.new()
	line.color = Color(INK_SOFT, 0.55)
	line.custom_minimum_size.y = 1.0
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


func _box(bg: Color, border: Color, border_width: int, radius: int, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


func _focus_box(radius: int) -> StyleBoxFlat:
	var s := _box(Color.TRANSPARENT, FOCUS, 3, radius, 0.0, 0.0)
	s.draw_center = false
	s.set_expand_margin_all(2.0)
	return s


func _style_button(b: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat, font: Color, font_hover: Color) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("focus", _focus_box(normal.corner_radius_top_left))
	for c: String in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(c, font)
	for c: String in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, font_hover)


## Small outlined "look closer" button (same effect as clicking the clue in the notes).
func _chip(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14)
	_style_button(b,
		_box(Color(RED_C, 0.06), RED_C, 1, 12, 12.0, 3.0),
		_box(Color(RED_C, 0.2), RED_C, 1, 12, 12.0, 3.0),
		_box(Color(RED_C, 0.35), RED_C, 1, 12, 12.0, 3.0),
		RED_C, RED_C.darkened(0.25))
	return b


func _action_button(a: PassengerAction, fare: int) -> Button:
	var kill := a.outcome == PassengerAction.Outcome.KILL
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size.y = 52.0
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if kill:
		_style_button(b,
			_box(Color(0.9, 0.7, 0.64), RED_C, 2, 3, 12.0, 4.0),
			_box(Color(0.93, 0.5, 0.43), RED_C, 2, 3, 12.0, 4.0),
			_box(Color(0.8, 0.33, 0.27), RED_C, 2, 3, 12.0, 4.0),
			RED_C, INK)
	else:
		_style_button(b,
			_box(PAPER_DARK, INK, 2, 3, 12.0, 4.0),
			_box(TAXI_YELLOW, INK, 2, 3, 12.0, 4.0),
			_box(TAXI_YELLOW.darkened(0.2), INK, 2, 3, 12.0, 4.0),
			INK, INK)
	# Two lines inside the button: what you do, and (smaller) what it gets you.
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", -3)
	b.add_child(lines)
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = 14.0
	lines.offset_right = -14.0
	var title := _label(17, RED_C if kill else INK, true)
	title.text = a.label
	title.clip_text = true
	lines.add_child(title)
	var fx := _label(13, RED_C if kill else INK_SOFT)
	fx.text = _effects(a, fare)
	fx.clip_text = true
	lines.add_child(fx)
	return b


static func _fmt(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60]
