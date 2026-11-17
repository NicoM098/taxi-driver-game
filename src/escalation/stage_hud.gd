class_name StageHud
extends Control
## Escalation on screen (D-091), added by the HUD, drawn in code:
##   top right, under the cash: STAGE n/3 · TITLE and the three objectives (fares, kills, time)
##   with bars, ticked when done; "BOSS INCOMING" with its countdown; in the fight one health
##   bar per boss; then STAGE CLEARED / THE CITY IS YOURS.
##   centre: a big banner when a stage starts, a boss is coming, a stage is cleared.

const W := 330.0
const RIGHT := 18.0
const TOP := 58.0
const BANNER_TIME := 4.0
const GREEN := Color(0.45, 1, 0.5)
const RED := Color(1, 0.3, 0.25)

var _esc: Escalation
var _font: FontVariation
var _t: float = 0.0
var _banner_title: String = ""
var _banner_sub: String = ""
var _banner_col: Color = Color.WHITE
var _banner_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 0.9


func _process(delta: float) -> void:
	if _esc == null:
		_esc = get_tree().get_first_node_in_group(&"escalation") as Escalation
		if _esc != null:
			_esc.announced.connect(_on_announced)
	visible = _esc != null and Escalation.enabled and not _esc.stages.is_empty() and not GameState.tutorial_active
	if not visible:
		return
	_t += delta
	_banner_left = maxf(_banner_left - delta, 0.0)
	queue_redraw()


func _on_announced(title: String, subtitle: String, colour: Color) -> void:
	_banner_title = title
	_banner_sub = subtitle
	_banner_col = colour
	_banner_left = BANNER_TIME


func _draw() -> void:
	if _esc == null:
		return
	var s := _esc.stage()
	if s == null:
		return
	_draw_panel(s)
	if _banner_left > 0.0:
		_draw_banner()


func _draw_panel(s: StageData) -> void:
	var x := size.x - RIGHT - W
	var y := TOP
	var rows := 3
	match _esc.phase:
		Escalation.Phase.BOSS:
			rows = _esc.bosses.size()
		Escalation.Phase.BOSS_INCOMING, Escalation.Phase.CLEARED, Escalation.Phase.VICTORY:
			rows = 1
	var h := 34.0 + rows * 24.0 + 8.0
	_box(Rect2(x, y, W, h), Color(0.02, 0.02, 0.04, 0.6))
	draw_rect(Rect2(x, y, 4, h), s.color)
	_text("STAGE %d/%d" % [s.number, _esc.stages.size()], Vector2(x + 14, y + 22), 14, Color(1, 1, 1, 0.7))
	_text(s.title.to_upper(), Vector2(x + 104, y + 22), 18, s.color)
	y += 34.0
	match _esc.phase:
		Escalation.Phase.STAGE:
			_objective(x, y, "FARES", _esc.fares, s.fares, "%d / %d" % [mini(_esc.fares, s.fares), s.fares])
			_objective(x, y + 24, "KILLS", _esc.kills, s.kills, "%d / %d" % [mini(_esc.kills, s.kills), s.kills])
			_objective(x, y + 48, "SURVIVE", _esc.seconds, s.seconds, "%s / %s" % [_clock(minf(_esc.seconds, s.seconds)), _clock(s.seconds)])
		Escalation.Phase.BOSS_INCOMING:
			var blink := 0.55 + 0.45 * sin(_t * 10.0)
			_text("BOSS INCOMING  %d" % ceili(_esc.phase_left), Vector2(x + 14, y + 17), 17, Color(RED, blink))
		Escalation.Phase.BOSS:
			var i := 0
			for b in _esc.boss_health():
				var by := y + i * 24.0
				var frac := float(b["hp"]) / maxf(float(b["max_hp"]), 1.0)
				_text(String(b["name"]).to_upper(), Vector2(x + 14, by + 15), 12, Color(1, 1, 1, 0.85) if frac > 0.0 else Color(1, 1, 1, 0.35))
				var bar := Rect2(x + 184, by + 5, W - 198, 12)
				draw_rect(bar, Color(1, 1, 1, 0.1))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), RED)
				if frac <= 0.0:
					_text("DOWN", Vector2(bar.position.x + 4, by + 16), 12, GREEN)
				i += 1
		Escalation.Phase.CLEARED:
			_text("STAGE CLEARED  —  NEXT IN %d" % ceili(_esc.phase_left), Vector2(x + 14, y + 17), 15, GREEN)
		Escalation.Phase.VICTORY:
			_text("THE CITY IS YOURS", Vector2(x + 14, y + 17), 16, GREEN)


func _objective(x: float, y: float, label: String, value: float, goal: float, text: String) -> void:
	var done := value >= goal
	var col := GREEN if done else Color.WHITE
	_text(("+ " if done else "") + label, Vector2(x + 14, y + 15), 13, col)
	var bar := Rect2(x + 96, y + 6, 110, 9)
	draw_rect(bar, Color(1, 1, 1, 0.1))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value / maxf(goal, 0.001), 0.0, 1.0), bar.size.y)),
			GREEN if done else _esc.stage().color)
	_text(text, Vector2(x + 216, y + 15), 13, col)


func _draw_banner() -> void:
	var a := clampf(_banner_left / 0.6, 0.0, 1.0) * clampf((BANNER_TIME - _banner_left) / 0.25, 0.0, 1.0)
	var cy := size.y * 0.3
	draw_rect(Rect2(0, cy - 46, size.x, 86), Color(0, 0, 0, 0.55 * a))
	draw_rect(Rect2(0, cy - 46, size.x, 3), Color(_banner_col, a))
	draw_rect(Rect2(0, cy + 37, size.x, 3), Color(_banner_col, a))
	_text_centered(_banner_title, cy + 2, 44, Color(_banner_col, a))
	_text_centered(_banner_sub, cy + 28, 18, Color(1, 1, 1, 0.85 * a))


func _text(s: String, pos: Vector2, font_size: int, col: Color) -> void:
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.7 * col.a))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _text_centered(s: String, baseline: float, font_size: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(s, Vector2((size.x - w) * 0.5, baseline), font_size, col)


func _box(r: Rect2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	draw_style_box(sb, r)


static func _clock(t: float) -> String:
	var secs := int(t)
	@warning_ignore("integer_division")
	return "%d:%02d" % [secs / 60, secs % 60]
