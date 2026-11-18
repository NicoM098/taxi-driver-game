extends Control
## Top-left status: health (one bar, or taxi body + driver with TaxiDamage.single_bar off),
## passenger HP (when aboard) and heat stars.

const BAR_W := 180.0
const BAR_H := 12.0
const ORIGIN := Vector2(18.0, 14.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var dmg := get_tree().get_first_node_in_group(&"taxi_damage") as TaxiDamage
	if dmg == null:
		return
	var font := get_theme_default_font()
	var y := ORIGIN.y
	if dmg.has_driver_bar():
		y = _bar(font, y, "TAXI", dmg.taxi_health, Color(1.0, 0.8, 0.1))
		y = _bar(font, y, "YOU", dmg.driver_health, Color(0.4, 1.0, 0.45))
	else:   # one bar (D-098)
		y = _bar(font, y, "HP", dmg.taxi_health, Color(0.4, 1.0, 0.45))
	if CarUpgrades.has_perk(&"guardian_angel"):   # D-107
		var ready := dmg.angel_cooldown <= 0.0
		var left := ceili(dmg.angel_cooldown)
		_text(font, Vector2(ORIGIN.x, y + 10.0), "ANGEL READY" if ready else "ANGEL  %d:%02d" % [left / 60, left % 60],
				Color(0.85, 0.95, 1.0) if ready else Color(1, 1, 1, 0.45), 14)
		y += 20.0
	if dmg.passenger_aboard:
		y = _bar(font, y, "FARE", dmg.passenger_health, Color(0.5, 0.75, 1.0))
	if GameState.heat > 0:
		var stars := ""
		for i in 5:
			stars += "*" if i < GameState.heat else "-"
		_text(font, Vector2(ORIGIN.x, y + 14.0), "HEAT  " + stars, Color(1.0, 0.35, 0.3), 16)


func _bar(font: Font, y: float, label: String, h: HealthComponent, color: Color) -> float:
	var ratio := clampf(h.hp / h.max_hp, 0.0, 1.0)
	_text(font, Vector2(ORIGIN.x, y + BAR_H), label, Color.WHITE, 14)
	var x := ORIGIN.x + 50.0
	draw_rect(Rect2(x - 2, y - 2, BAR_W + 4, BAR_H + 4), Color(0, 0, 0, 0.7))
	var c := color if ratio > 0.25 else Color(1.0, 0.25, 0.2)
	draw_rect(Rect2(x, y, BAR_W * ratio, BAR_H), c)
	return y + BAR_H + 8.0


func _text(font: Font, pos: Vector2, text: String, color: Color, size: int) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
