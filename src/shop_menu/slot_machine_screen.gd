class_name SlotMachineScreen
extends Control
## The slot machine you play (D-107, user: "a full animation slot machine where you insert the
## ticket and pull down the lever and have an animation come up with what you got").
## Opened from the shop's SLOTS tab, drawn in a 1280x720 design space scaled to the screen.
##   IDLE      a ticket waits in the tray (if you have one)     E / Space / A / click: insert it
##   INSERTING the ticket slides up into the slot                (0.8 s)
##   READY     "PULL THE LEVER"                                 E / Space / A / click the lever
##   PULLING   the lever goes down; at the bottom the spin is paid (SlotMachine.spin)
##   SPINNING  three reels roll and stop one after the other on the prize
##   REVEAL    the prize card pops up with rays and confetti     E / Space / A / click: collect
## Esc / B leaves (not mid-spin). The ticket is only spent when the lever is pulled.

signal finished(prize: Dictionary)

enum State { IDLE, INSERTING, READY, PULLING, SPINNING, REVEAL }

const DESIGN := Vector2(1280, 720)
const CAB := Rect2(410, 40, 460, 640)
const WINDOW := Rect2(440, 214, 400, 186)
const SYM_H := 92.0
const REEL_W := 122.0
const REEL_GAP := 17.0
const SLOT := Rect2(560, 446, 160, 14)
const TICKET_SIZE := Vector2(170, 70)
const TICKET_HOME := Vector2(640, 622)
const PIVOT := Vector2(898, 330)
const LEVER_LEN := 150.0
const LEVER_UP := -82.0
const LEVER_DOWN := 58.0
const SPIN_SPEED := 16.0          # symbols per second
const FIRST_STOP := 1.3
const STOP_GAP := 0.6
const STOP_TIME := 0.55

const RED := Color(0.62, 0.07, 0.12)
const RED_DARK := Color(0.36, 0.03, 0.08)
const GOLD := Color(1.0, 0.8, 0.2)
const CREAM := Color(0.97, 0.94, 0.86)
const INK := Color(0.06, 0.05, 0.08)

var state: State = State.IDLE
var prize: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _font: Font
var _bold: FontVariation
var _t: float = 0.0
var _state_t: float = 0.0
var _offsets: Array[float] = [0.0, 0.0, 0.0]
var _stop_from: Array[float] = [0.0, 0.0, 0.0]
var _stop_to: Array[float] = [0.0, 0.0, 0.0]
var _stopped: Array[bool] = [true, true, true]
var _lever: float = 0.0           # 0 up .. 1 pulled down
var _ticket_t: float = 0.0        # 0 in the tray .. 1 gone into the slot
var _pop: float = 0.0
var _confetti: Array[Dictionary] = []
var _tick_acc: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_font = ThemeDB.fallback_font
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_embolden = 0.9
	visible = false
	var seven := float(SlotMachine.REEL_SYMBOLS.find("7"))
	_offsets = [seven, seven, seven]


func open() -> void:
	visible = true
	prize = {}
	_set_state(State.IDLE)
	_ticket_t = 0.0
	_lever = 0.0
	_confetti.clear()
	get_viewport().gui_release_focus()
	Audio.play(&"ui_click")


func close() -> void:
	if state == State.PULLING or state == State.SPINNING:
		return
	if state == State.REVEAL:
		_collect()
	visible = false
	Audio.play(&"ui_close")


## E / Space / A / a click: the next step (insert, pull, collect). Also used by tests.
func advance() -> void:
	match state:
		State.IDLE:
			if GameState.tickets > 0:
				_set_state(State.INSERTING)
				Audio.play(&"reload", &"SFX", -4.0, 1.3)
		State.READY:
			_set_state(State.PULLING)
			Audio.play(&"impact_soft", &"SFX", -2.0, 0.7)
		State.REVEAL:
			if _state_t > 0.5:
				_collect()


func _collect() -> void:
	finished.emit(prize)
	_confetti.clear()
	_ticket_t = 0.0
	_set_state(State.IDLE)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Everything stops here while the machine is up: the shop behind must not react.
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"shop_menu"):
		close()
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	var mouse := event as InputEventMouseButton
	if key != null and key.pressed and not key.echo and key.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		advance()
	elif pad != null and pad.pressed and pad.button_index == JOY_BUTTON_A:
		advance()
	elif mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var p := _to_design(mouse.position)
		if state == State.READY and (p.distance_to(_knob()) < 60.0 or Rect2(870, 200, 120, 260).has_point(p)):
			advance()
		elif state != State.READY:
			advance()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_state_t += delta
	match state:
		State.INSERTING:
			_ticket_t = clampf(_state_t / 0.8, 0.0, 1.0)
			if _ticket_t >= 1.0:
				Audio.play(&"ui_click", &"SFX", 0.0, 0.8)
				_set_state(State.READY)
		State.PULLING:
			_lever = clampf(_state_t / 0.32, 0.0, 1.0)
			if _lever >= 1.0:
				_start_spin()
		State.SPINNING:
			_lever = maxf(_lever - delta * 2.2, 0.0)
			_update_reels(delta)
		State.REVEAL:
			_pop = minf(_pop + delta * 3.0, 1.0)
	_update_confetti(delta)
	queue_redraw()


# --- Reels -------------------------------------------------------------------------------

func _start_spin() -> void:
	prize = SlotMachine.spin(get_tree(), _rng)
	if prize.has("error"):
		_set_state(State.IDLE)
		return
	Audio.play(&"reload", &"SFX", 0.0, 0.8)
	_stopped = [false, false, false]
	_set_state(State.SPINNING)


func _update_reels(delta: float) -> void:
	var n := SlotMachine.REEL_SYMBOLS.size()
	var target := float(SlotMachine.REEL_SYMBOLS.find(String(prize.get("symbol", "7"))))
	var all_done := true
	for i in 3:
		var stop_at := FIRST_STOP + STOP_GAP * i
		if _state_t < stop_at:
			_offsets[i] += SPIN_SPEED * delta
			_tick(i, SPIN_SPEED * delta)
			all_done = false
			continue
		if _stopped[i]:
			continue
		if _stop_to[i] <= _stop_from[i]:   # first frame of the stop: pick where it lands
			_stop_from[i] = _offsets[i]
			var base := ceilf(_offsets[i])
			_stop_to[i] = base + n + fposmod(target - base, n)
		var k := clampf((_state_t - stop_at) / STOP_TIME, 0.0, 1.0)
		var before := _offsets[i]
		_offsets[i] = lerpf(_stop_from[i], _stop_to[i], _ease_out_back(k))
		_tick(i, absf(_offsets[i] - before))
		if k >= 1.0:
			_stopped[i] = true
			_offsets[i] = _stop_to[i]
			_stop_from[i] = 0.0
			_stop_to[i] = 0.0
			Audio.play(&"impact_soft", &"SFX", -1.0, 1.1 + i * 0.12)
		else:
			all_done = false
	if all_done and _state_t > FIRST_STOP + STOP_GAP * 2 + STOP_TIME + 0.25:
		_pop = 0.0
		_set_state(State.REVEAL)
		_burst()
		Audio.play(&"cash", &"SFX", 2.0)


## A soft click every symbol that passes the payline.
func _tick(i: int, moved: float) -> void:
	_tick_acc[i] += moved
	if _tick_acc[i] >= 1.0:
		_tick_acc[i] = fmod(_tick_acc[i], 1.0)
		if i == 0:
			Audio.play(&"ui_click", &"SFX", -14.0, 1.6)


static func _ease_out_back(x: float) -> float:
	var c1 := 1.4
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


# --- Confetti ----------------------------------------------------------------------------

func _burst() -> void:
	var col: Color = _symbol(String(prize.get("symbol", "7")))["color"]
	for i in 90:
		var a := _rng.randf_range(-PI, 0.0)
		var sp := _rng.randf_range(250.0, 650.0)
		_confetti.append({"p": Vector2(640, 330), "v": Vector2(cos(a), sin(a)) * sp,
				"c": [GOLD, col, Color.WHITE, Color(0.4, 0.9, 1.0)][i % 4],
				"r": _rng.randf() * TAU, "w": _rng.randf_range(-9.0, 9.0), "s": _rng.randf_range(5.0, 10.0)})


func _update_confetti(delta: float) -> void:
	for c in _confetti:
		c["v"] = (c["v"] as Vector2) * (1.0 - 0.8 * delta) + Vector2(0, 520.0 * delta)
		c["p"] = (c["p"] as Vector2) + (c["v"] as Vector2) * delta
		c["r"] = float(c["r"]) + float(c["w"]) * delta
	_confetti = _confetti.filter(func(c: Dictionary) -> bool: return (c["p"] as Vector2).y < DESIGN.y + 40.0)


# --- Drawing ----------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.78))
	var sc := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * sc) * 0.5, 0.0, Vector2(sc, sc))
	_draw_cabinet()
	_draw_reels()
	_draw_front()
	_draw_lever()
	_draw_ticket()
	if state == State.REVEAL:
		_draw_reveal()
	for c in _confetti:
		var p: Vector2 = c["p"]
		var s: float = c["s"]
		draw_set_transform((size - DESIGN * sc) * 0.5 + p * sc, float(c["r"]), Vector2(sc, sc))
		draw_rect(Rect2(-s * 0.5, -s * 0.25, s, s * 0.5), c["c"])
	draw_set_transform(Vector2.ZERO)


func _draw_cabinet() -> void:
	# Body, with a darker side band and a gold trim.
	draw_style_box(_box(RED, 26, GOLD, 4), CAB)
	draw_rect(Rect2(CAB.position + Vector2(10, 120), Vector2(28, CAB.size.y - 150)), RED_DARK)
	draw_rect(Rect2(CAB.end.x - 38, CAB.position.y + 120, 28, CAB.size.y - 150), RED_DARK)
	# Marquee.
	var marquee := Rect2(CAB.position + Vector2(24, 18), Vector2(CAB.size.x - 48, 96))
	draw_style_box(_box(INK, 14, GOLD, 3), marquee)
	var win := state == State.REVEAL
	var bulbs := 18
	for i in bulbs:
		var x := marquee.position.x + 14.0 + i * (marquee.size.x - 28.0) / (bulbs - 1)
		for y in [marquee.position.y - 1.0, marquee.end.y + 1.0]:
			var lit := (int(_t * (14.0 if win else 5.0)) + i) % 3 == 0 if not win else int(_t * 8.0) % 2 == 0
			draw_circle(Vector2(x, y), 5.5, GOLD if lit else Color(0.45, 0.32, 0.1))
	var glow := 0.75 + 0.25 * sin(_t * 3.0)
	_text("LUCKY  CAB", marquee.get_center() + Vector2(0, -6), 46, Color(GOLD, glow), 8, true)
	_text("ONE TICKET  ·  ONE SPIN  ·  ALWAYS A WINNER", marquee.get_center() + Vector2(0, 34), 13, Color(1, 1, 1, 0.75), 3, false)
	# Reel window frame.
	draw_style_box(_box(INK, 12, GOLD, 4), WINDOW.grow(14))


func _draw_reels() -> void:
	var n := SlotMachine.REEL_SYMBOLS.size()
	var mid := WINDOW.get_center().y
	for i in 3:
		var x := WINDOW.position.x + 6.0 + i * (REEL_W + REEL_GAP)
		var reel := Rect2(x, WINDOW.position.y, REEL_W, WINDOW.size.y)
		draw_rect(reel, CREAM)
		var o := _offsets[i]
		var spinning := state == State.SPINNING and not _stopped[i]
		var base := floori(o)
		for j in range(base - 2, base + 3):
			var y := mid + (o - float(j)) * SYM_H
			if y < reel.position.y - SYM_H * 0.5 or y > reel.end.y + SYM_H * 0.5:
				continue
			var sym: String = SlotMachine.REEL_SYMBOLS[posmod(j, n)]
			var fade := clampf(1.0 - absf(y - mid) / (WINDOW.size.y * 0.75), 0.25, 1.0)
			_draw_symbol(sym, Vector2(x + REEL_W * 0.5, y), fade * (0.55 if spinning else 1.0), spinning)
		# Shading top and bottom: a drum, not a flat strip.
		for k in 6:
			var a := 0.32 - k * 0.05
			draw_rect(Rect2(x, reel.position.y + k * 7.0, REEL_W, 7.0), Color(0, 0, 0, a))
			draw_rect(Rect2(x, reel.end.y - (k + 1) * 7.0, REEL_W, 7.0), Color(0, 0, 0, a))
	# Masks over anything drawn past the window, then the payline.
	draw_rect(Rect2(WINDOW.position.x - 10, WINDOW.position.y - 54, WINDOW.size.x + 20, 40), RED)
	draw_rect(Rect2(WINDOW.position.x - 10, WINDOW.end.y + 14, WINDOW.size.x + 20, 40), RED)
	draw_style_box(_box(Color(0, 0, 0, 0), 12, GOLD, 4), WINDOW.grow(14))
	var won := state == State.REVEAL and int(_t * 6.0) % 2 == 0
	draw_line(Vector2(WINDOW.position.x - 4, mid), Vector2(WINDOW.end.x + 4, mid), Color(1, 0.2, 0.2, 0.9 if won else 0.55), 3.0)
	for side in [-1.0, 1.0]:
		var tip := Vector2(WINDOW.position.x - 18 if side < 0 else WINDOW.end.x + 18, mid)
		var d := Vector2(side * -14.0, 0)
		draw_colored_polygon(PackedVector2Array([tip + d, tip - Vector2(0, 10), tip + Vector2(0, 10)]), GOLD)


func _draw_symbol(key: String, c: Vector2, alpha: float, blur: bool) -> void:
	var sym := _symbol(key)
	var col: Color = sym["color"]
	var label: String = sym["label"]
	if blur:   # motion streaks
		for k in 3:
			draw_rect(Rect2(c + Vector2(-34, -34 + k * 24), Vector2(68, 10)), Color(col, 0.12 * alpha))
	var tile := Rect2(c - Vector2(44, 36), Vector2(88, 72))
	draw_style_box(_box(Color(col, 0.18 * alpha), 10, Color(col, 0.9 * alpha), 3), tile)
	var fs := 46 if label.length() == 1 else (34 if label.length() == 2 else (26 if label.length() == 3 else 22))
	_text(label, c + Vector2(0, 2), fs, Color(col.darkened(0.25), alpha), 0, true)


func _draw_front() -> void:
	# Ticket slot and its label.
	draw_style_box(_box(Color(0.04, 0.03, 0.04), 4, GOLD, 2), SLOT.grow(5))
	draw_rect(SLOT, Color(0, 0, 0))
	var ready := state == State.IDLE and GameState.tickets > 0
	_text("INSERT TICKET", SLOT.get_center() + Vector2(0, 22), 14, Color(GOLD, 0.6 + 0.4 * sin(_t * 6.0)) if ready else Color(1, 1, 1, 0.45), 3, true)
	# LED message board.
	var board := Rect2(CAB.position.x + 50, 494, CAB.size.x - 100, 62)
	draw_style_box(_box(Color(0.02, 0.02, 0.03), 8, Color(1, 1, 1, 0.12), 2), board)
	var msg := ""
	var col := Color(1.0, 0.45, 0.2)
	match state:
		State.IDLE:
			msg = "INSERT A TICKET" if GameState.tickets > 0 else "NO TICKETS - BEAT A BOSS"
		State.INSERTING:
			msg = "TICKET ACCEPTED"
		State.READY:
			msg = "PULL THE LEVER!"
			col = Color(1.0, 0.85, 0.2, 0.6 + 0.4 * sin(_t * 8.0))
		State.PULLING, State.SPINNING:
			msg = "GOOD LUCK..." if int(_t * 3.0) % 2 == 0 else "ROLLING..."
		State.REVEAL:
			msg = "WINNER!"
			col = GOLD
	_text(msg, board.get_center() + Vector2(0, 2), 28, col, 0, true)
	# Tickets left, coin tray.
	_text("TICKETS  x%d" % GameState.tickets, Vector2(CAB.get_center().x, 578), 20, Color.WHITE, 4, true)
	var tray := Rect2(CAB.position.x + 60, 598, CAB.size.x - 120, 58)
	draw_style_box(_box(RED_DARK, 12, Color(GOLD, 0.6), 2), tray)
	draw_rect(Rect2(tray.position + Vector2(14, 32), Vector2(tray.size.x - 28, 16)), Color(0, 0, 0, 0.5))
	_text("[E / Space / A]  %s       [Esc]  leave" % _verb(), Vector2(640, 708), 15, Color(1, 1, 1, 0.7), 3, false)


func _verb() -> String:
	match state:
		State.IDLE:
			return "insert ticket" if GameState.tickets > 0 else "-"
		State.READY:
			return "pull the lever"
		State.REVEAL:
			return "collect"
	return "..."


func _draw_ticket() -> void:
	if GameState.tickets <= 0 and state == State.IDLE:
		return
	if state != State.IDLE and state != State.INSERTING:
		return
	# Tray -> under the slot (first 60 %), then into it (the rest: it gets shorter).
	var k := _ticket_t
	var up := clampf(k / 0.6, 0.0, 1.0)
	var into := clampf((k - 0.6) / 0.4, 0.0, 1.0)
	var pos := TICKET_HOME.lerp(SLOT.get_center() + Vector2(0, TICKET_SIZE.y * 0.5 + 6), _smooth(up))
	var h := TICKET_SIZE.y * (1.0 - into)
	pos.y -= TICKET_SIZE.y * 0.5 * into
	var bob := sin(_t * 4.0) * 3.0 if state == State.IDLE else 0.0
	var r := Rect2(pos - Vector2(TICKET_SIZE.x * 0.5, TICKET_SIZE.y * 0.5 - (TICKET_SIZE.y - h) + bob), Vector2(TICKET_SIZE.x, h))
	if h <= 1.0:
		return
	draw_style_box(_box(Color(1.0, 0.7, 0.15), 6, Color(0.55, 0.25, 0.0), 3), r)
	if h > 40.0:
		draw_rect(Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, r.size.y - 16)), Color(1, 1, 1, 0.0))
		_text("SLOT TICKET", r.get_center() + Vector2(0, -6), 18, Color(0.35, 0.12, 0.0), 0, true)
		_text("ADMIT ONE SPIN", r.get_center() + Vector2(0, 16), 11, Color(0.35, 0.12, 0.0, 0.8), 0, false)
		for side in [-1.0, 1.0]:   # punched notches
			draw_circle(Vector2(r.get_center().x + side * TICKET_SIZE.x * 0.5, r.get_center().y), 7.0, Color(0, 0, 0, 0.78))


func _knob() -> Vector2:
	var a := deg_to_rad(lerpf(LEVER_UP, LEVER_DOWN, _smooth(_lever)))
	return PIVOT + Vector2(cos(a), sin(a)) * LEVER_LEN


func _draw_lever() -> void:
	var housing := Rect2(CAB.end.x - 6, PIVOT.y - 40, 46, 80)
	draw_style_box(_box(Color(0.25, 0.25, 0.28), 10, Color(0.6, 0.6, 0.65), 2), housing)
	var knob := _knob()
	draw_line(PIVOT, knob, Color(0.15, 0.15, 0.17), 16.0, true)
	draw_line(PIVOT, knob, Color(0.78, 0.78, 0.82), 9.0, true)
	draw_circle(PIVOT, 14.0, Color(0.4, 0.4, 0.45))
	var pulse := state == State.READY
	if pulse:
		draw_circle(knob, 30.0 + 6.0 * sin(_t * 8.0), Color(1.0, 0.25, 0.2, 0.25))
	draw_circle(knob, 24.0, Color(0.85, 0.08, 0.1))
	draw_circle(knob + Vector2(-7, -8), 8.0, Color(1, 1, 1, 0.45))
	if pulse:
		_text("PULL!", knob + Vector2(0, -42), 18, Color(1, 0.9, 0.3), 4, true)


func _draw_reveal() -> void:
	var k := _ease_out_back(clampf(_pop, 0.0, 1.0))
	var c := Vector2(640, 345)
	var sym := _symbol(String(prize.get("symbol", "7")))
	var col: Color = sym["color"]
	# Rays.
	for i in 16:
		var a := _t * 0.6 + i * TAU / 16.0
		var d1 := Vector2(cos(a), sin(a))
		var d2 := Vector2(cos(a + 0.12), sin(a + 0.12))
		draw_colored_polygon(PackedVector2Array([c, c + d1 * 520.0 * k, c + d2 * 520.0 * k]), Color(col, 0.13))
	# Card.
	var card := Rect2(c - Vector2(300, 150) * k, Vector2(600, 300) * k)
	if k < 0.2:
		return
	draw_style_box(_box(Color(0.07, 0.06, 0.1, 0.97), 18, col, 5), card)
	var s := clampf(k, 0.0, 1.2)
	var tile := Rect2(c + Vector2(-60, -130) * s, Vector2(120, 96) * s)
	draw_style_box(_box(Color(col, 0.2), 14, col, 4), tile)
	_text(String(sym["label"]), tile.get_center() + Vector2(0, 2), roundi(40 * s), col, 0, true)
	var perk: bool = prize.get("kind", &"") == &"perk"
	_text("NEW PERK" if perk else "GUN UPGRADE", c + Vector2(0, -12) * s, roundi(16 * s), Color(1, 1, 1, 0.6), 0, true)
	_text(String(prize.get("title", "")), c + Vector2(0, 32) * s, roundi(42 * s), GOLD, 6, true)
	_text(String(prize.get("detail", "")), c + Vector2(0, 72) * s, roundi(19 * s), Color.WHITE, 3, false)
	if _state_t > 0.5:
		_text("COLLECT  [E]", c + Vector2(0, 122) * s, roundi(18 * s), Color(GOLD, 0.6 + 0.4 * sin(_t * 6.0)), 3, true)


# --- Helpers ----------------------------------------------------------------------------

func _design_xform() -> Transform2D:
	var sc := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	return Transform2D(0.0, Vector2(sc, sc), 0.0, (size - DESIGN * sc) * 0.5)


func _to_design(p: Vector2) -> Vector2:
	return _design_xform().affine_inverse() * p


static func _symbol(key: String) -> Dictionary:
	return SlotMachine.SYMBOLS.get(key, SlotMachine.SYMBOLS["7"])


static func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _text(s: String, centre: Vector2, font_size: int, col: Color, outline: int, bold: bool) -> void:
	if font_size <= 0 or s == "":
		return
	var f: Font = _bold if bold else _font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := centre + Vector2(-w * 0.5, font_size * 0.35)
	if outline > 0:
		draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(0, 0, 0, col.a))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


static func _box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), width: int = 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(radius)
	b.border_color = border
	b.set_border_width_all(width)
	b.anti_aliasing = true
	return b
