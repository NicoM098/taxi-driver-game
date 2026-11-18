extends Control
## "Watch your back": a red chevron + distance on the screen edge for every live pursuer
## that is outside your current view (behind / beside you). Hidden when it is on screen.
## Bosses (D-102): a bigger gold chevron tagged "BOSS", at any distance.

const VIEW_HALF_ANGLE := deg_to_rad(42.0)   # roughly the visible horizontal half-FOV
const MAX_DISTANCE := 160.0
const BOSS_COLOR := Color(1.0, 0.78, 0.1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var director := get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node
	var cam := taxi.get_node_or_null("HeadPivot/Camera3D") as Camera3D if taxi != null else null
	if director == null or cam == null:
		return
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	var c := size * 0.5
	var radii := Vector2(size.x * 0.46, size.y * 0.44)
	var font := get_theme_default_font()
	var placed: Array[Vector2] = []
	for car in director.enemies:
		if not is_instance_valid(car) or car.is_destroyed:
			continue
		var to := car.global_position - cam.global_position
		to.y = 0.0
		var dist := to.length()
		var boss: bool = car.is_boss()
		if (dist > MAX_DISTANCE and not boss) or dist < 0.5:
			continue
		var rel := fwd.signed_angle_to(to / dist, Vector3.UP)   # + = left
		if absf(rel) < VIEW_HALF_ANGLE:
			continue   # visible on screen: no marker
		var dir := Vector2(-sin(rel), -cos(rel))      # up = ahead, down = behind
		var pos := c + dir * radii
		var side := Vector2(dir.y, -dir.x)
		var alpha := 1.0 if boss else clampf(1.2 - dist / MAX_DISTANCE, 0.35, 1.0)
		var col := Color(1.0, 0.2, 0.15, alpha) if not car.data.siren else Color(0.35, 0.55, 1.0, alpha)
		var k := 1.0
		if boss:
			col = BOSS_COLOR
			k = 1.7 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		var tip := pos + dir * 16.0 * k
		var pts := PackedVector2Array([tip, pos + side * 14.0 * k, pos - side * 14.0 * k])
		draw_colored_polygon(pts, Color(0, 0, 0, alpha * 0.8))
		draw_colored_polygon(PackedVector2Array([tip - dir * 3.0 * k, pos + side * 10.0 * k, pos - side * 10.0 * k]), col)
		var label := ("BOSS %dm" if boss else "%dm") % roundi(dist)
		var text_pos := pos - dir * 22.0 + Vector2(-14, 6)
		for p in placed:   # stack labels of markers that land on top of each other
			if p.distance_to(text_pos) < 18.0:
				text_pos -= dir * 16.0
		placed.append(text_pos)
		draw_string_outline(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
