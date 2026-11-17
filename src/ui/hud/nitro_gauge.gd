class_name NitroGauge
extends Control
## The nitro tank (Iteration 19): a tall segmented gauge beside the minimap and the speed, the
## corner your eyes already go to for "how fast". Drawn in code, polls the player's taxi.
##   filling / full  cyan→violet segments, a light sweep runs up a full tank
##   boosting        the bar glows and chevrons race up through it
##   empty           red, blinking, "EMPTY" until it can relight (Taxi.nitro_relight)

const SEGMENTS := 12
const LOW := Color(0.2, 0.95, 1.0)
const HIGH := Color(0.62, 0.38, 1.0)
const EMPTY_RED := Color(1.0, 0.22, 0.2)
const BG := Color(0.02, 0.03, 0.06, 0.62)
const PAD := 7.0
const TOP_TEXT := 20.0
const BOTTOM_TEXT := 22.0

var _taxi: Taxi
var _shown: float = 1.0      # eased fill 0..1
var _glow: float = 0.0       # 0..1 while boosting
var _t: float = 0.0
var _font: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 0.9


func _process(delta: float) -> void:
	if _taxi == null or not is_instance_valid(_taxi):
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	visible = _taxi != null and _taxi.nitro_tank and not get_tree().paused
	if not visible:
		return
	_t += delta
	var fill := _taxi.nitro / maxf(_taxi.nitro_max, 1.0)
	_shown = lerpf(_shown, fill, clampf(delta * 14.0, 0.0, 1.0))
	_glow = move_toward(_glow, 1.0 if _taxi.is_boosting else 0.0, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	if _taxi == null:
		return
	var w := size.x
	var h := size.y
	var empty := _taxi.nitro_empty
	var blink := 0.5 + 0.5 * sin(_t * 14.0)
	# Glow halo while boosting.
	if _glow > 0.01:
		var pulse := 0.75 + 0.25 * sin(_t * 30.0)
		for i in 3:
			var grow := 4.0 + i * 5.0
			_round_rect(Rect2(Vector2(-grow, -grow), size + Vector2(grow, grow) * 2.0),
					Color(LOW.r, LOW.g, LOW.b, 0.12 * _glow * pulse), 10.0 + grow)
	_round_rect(Rect2(Vector2.ZERO, size), BG, 9.0)
	var frame := EMPTY_RED if empty else LOW.lerp(HIGH, _shown)
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(frame, 0.35 + 0.4 * _glow), false, 1.5)

	# Title.
	var title := "EMPTY" if empty else "NITRO"
	var title_col := Color(EMPTY_RED, 0.5 + 0.5 * blink) if empty else Color(1, 1, 1, 0.85)
	_text(title, Vector2(0, 15), 12, title_col)

	# Segments, bottom-up, slanted like a rev light.
	var area := Rect2(Vector2(PAD, TOP_TEXT + 2.0), Vector2(w - PAD * 2.0, h - TOP_TEXT - BOTTOM_TEXT - 4.0))
	var gap := 3.0
	var seg_h := (area.size.y - gap * (SEGMENTS - 1)) / SEGMENTS
	var slant := 5.0
	var level := _shown * SEGMENTS
	var sweep := fmod(_t * 0.9, 1.6) * SEGMENTS   # light running up a full tank
	for i in SEGMENTS:
		var y1 := area.end.y - i * (seg_h + gap)
		var y0 := y1 - seg_h
		var x0 := area.position.x
		var x1 := area.end.x
		var poly := PackedVector2Array([Vector2(x0, y1), Vector2(x1 - slant, y1), Vector2(x1, y0), Vector2(x0 + slant, y0)])
		var base := LOW.lerp(HIGH, float(i) / (SEGMENTS - 1))
		var part := clampf(level - i, 0.0, 1.0)
		draw_colored_polygon(poly, Color(1, 1, 1, 0.07))
		if part <= 0.0:
			if empty and i < 2:
				draw_colored_polygon(poly, Color(EMPTY_RED, 0.25 + 0.5 * blink))
			continue
		var col := EMPTY_RED if empty else base
		col.a = 0.35 + 0.65 * part
		if _glow > 0.0:
			# Chevrons racing up the bar while the boost burns.
			var wave := 0.5 + 0.5 * sin(_t * 26.0 - i * 1.1)
			col = col.lightened(0.45 * _glow * wave)
		elif _shown >= 0.999 and absf(sweep - i) < 1.2:
			col = col.lightened(0.5 * (1.0 - absf(sweep - i) / 1.2))
		draw_colored_polygon(poly, col)
		# A bright top edge on each lit segment.
		draw_line(Vector2(x0 + slant, y0), Vector2(x1, y0), Color(1, 1, 1, 0.35 * part), 1.0)

	# Percentage underneath.
	var pct := roundi(_taxi.nitro / maxf(_taxi.nitro_max, 1.0) * 100.0)
	_text("%d%%" % pct, Vector2(0, h - 6.0), 14, Color(EMPTY_RED, 0.6 + 0.4 * blink) if empty else Color.WHITE)


func _text(s: String, baseline: Vector2, font_size: int, col: Color) -> void:
	var tw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2((size.x - tw) * 0.5, baseline.y)
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _round_rect(r: Rect2, col: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
