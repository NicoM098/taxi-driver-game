extends Control
## Shows where shots come from: a red wedge around the screen centre pointing at the shooter
## (relative to where you are looking), plus a red screen-edge flash on every hit.

const LIFE := 1.2
const RADIUS := 230.0  # outside the top-centre guide arrow

var _marks: Array[Dictionary] = []   # {from: Vector3, t: float}
var _flash: float = 0.0
var _heal_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.energy_drink_consumed.connect(func() -> void: _heal_flash = 0.5)
	EventBus.passenger_executed.connect(func(_p: RefCounted) -> void: _flash = 0.6)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_heal_flash = maxf(_heal_flash - delta * 0.6, 0.0)
	for m in _marks:
		m["t"] -= delta
	_marks = _marks.filter(func(m: Dictionary) -> bool: return m["t"] > 0.0)
	queue_redraw()


func _on_player_hit(amount: float, from: Vector3) -> void:
	_flash = clampf(_flash + amount * 0.04, 0.0, 0.6)
	if from != Vector3.INF:
		_marks.append({"from": from, "t": LIFE})


func _draw() -> void:
	if _heal_flash > 0.0:
		var g := Color(0.3, 1.0, 0.5, _heal_flash * 0.6)
		draw_rect(Rect2(0, 0, size.x, 50), g)
		draw_rect(Rect2(0, size.y - 50, size.x, 50), g)
		draw_rect(Rect2(0, 0, 50, size.y), g)
		draw_rect(Rect2(size.x - 50, 0, 50, size.y), g)
	if _flash > 0.0:
		var edge := 70.0
		var col := Color(0.8, 0.0, 0.0, _flash)
		draw_rect(Rect2(0, 0, size.x, edge), col)
		draw_rect(Rect2(0, size.y - edge, size.x, edge), col)
		draw_rect(Rect2(0, 0, edge, size.y), col)
		draw_rect(Rect2(size.x - edge, 0, edge, size.y), col)
	var cam := _camera()
	if cam == null:
		return
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	var c := size * 0.5
	for m in _marks:
		var to: Vector3 = (m["from"] as Vector3) - cam.global_position
		to.y = 0.0
		if to.length() < 0.1:
			continue
		var rel := fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP)  # + = left
		var dir := Vector2(-sin(rel), -cos(rel))       # screen: up = ahead, left = left
		var side := Vector2(dir.y, -dir.x)
		var tip := c + dir * (RADIUS + 26.0)
		var base := c + dir * RADIUS
		var a := clampf(m["t"] / LIFE, 0.0, 1.0)
		var pts := PackedVector2Array([tip, base + side * 22.0, base - side * 22.0])
		draw_colored_polygon(pts, Color(1.0, 0.15, 0.1, 0.85 * a))


func _camera() -> Camera3D:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node
	return taxi.get_node_or_null("HeadPivot/Camera3D") as Camera3D if taxi != null else null
