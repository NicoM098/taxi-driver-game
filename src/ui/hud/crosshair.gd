extends Control
## Centre crosshair: four ticks whose gap shows the current weapon spread (projected from the
## spread cone through the camera FOV), plus a hit marker (white = hit, red = kill).

var _hit_time: float = 0.0
var _hit_kill: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.hit_confirmed.connect(func(killed: bool) -> void:
		_hit_time = 0.25
		_hit_kill = killed)


func _process(delta: float) -> void:
	_hit_time -= delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var wc := get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	if wc != null and wc.raise_amount > 0.5:
		var cam := wc.get_parent() as Camera3D
		var gap := 4.0
		if cam != null:
			gap = maxf(tan(deg_to_rad(wc.current_spread_deg)) / tan(deg_to_rad(cam.fov * 0.5)) * size.y * 0.5, 4.0)
		var color := Color(1, 1, 1, 0.9) if wc.is_aiming else Color(1, 1, 1, 0.6)
		for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			_outlined_line(c + dir * gap, c + dir * (gap + 10.0), color)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), color)
	if _hit_time > 0.0:
		var hc := Color(1, 0.25, 0.2) if _hit_kill else Color(1, 1, 1)
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_outlined_line(c + d * 7.0, c + d * 15.0, hc)


func _outlined_line(a: Vector2, b: Vector2, color: Color) -> void:
	draw_line(a, b, Color(0, 0, 0, color.a), 4.0)
	draw_line(a, b, color, 2.0)
