extends Node
## Minimap (D-083). Headless:
##   <godot exe> --headless --path <project> --fixed-fps 60 res://tests/minimap_autotest.tscn
## Two things worth testing, both of which would be silent if wrong:
##   1. the bake matches the map's own cell flags, on a NON-SQUARE map so a swapped width/depth
##      cannot pass;
##   2. world -> minimap lands where it should, and keeps doing so once the taxi turns (the map
##      rotates, the arrow does not).

const TAXI := preload("res://src/vehicle/taxi.tscn")
const W := 40
const D := 24

var _errors: PackedStringArray = []


func _ready() -> void:
	MapData.use_builtin()
	_run()


func poll(input: VehicleInput) -> void:
	input.clear()


## RGBA8 quantises to bytes, so the colours come back about 1/255 off: `is_equal_approx` is far
## too strict for a round trip through a texture.
static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _check(ok: bool, what: String) -> void:
	print("[MinimapTest] %s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_errors.append(what)


func _run() -> void:
	# --- 1. the bake -------------------------------------------------------------------
	var map := MapData.make_empty("minimap", W, D)
	map.pieces.append(MapData.make_piece("spawn", 4, 4))
	map.pieces.append(MapData.make_piece("building", 10, 6, 3, 2))    # 6 solid cells
	map.pieces.append(MapData.make_piece("sidewalk", 20, 10, 4, 1))   # 4 covered, not solid
	var tex := Minimap.bake(map)
	_check(tex != null, "bake returns a texture")
	var img := tex.get_image()
	_check(img.get_width() == W and img.get_height() == D,
			"baked size is %d x %d (got %d x %d)" % [W, D, img.get_width(), img.get_height()])

	var flags := map.flags()
	var solid := 0
	var covered := 0
	var painted_solid := 0
	var painted_covered := 0
	for z in D:
		for x in W:
			var f := flags[z * W + x]
			if f & MapData.F_SOLID:
				solid += 1
			elif f & MapData.F_COVERED:
				covered += 1
			var col := img.get_pixel(x, z)
			if _same(col, Minimap.BUILDING):
				painted_solid += 1
			elif _same(col, Minimap.COVERED):
				painted_covered += 1
	_check(solid == painted_solid and solid == 6,
			"solid cells painted as buildings: %d flagged, %d painted (expected 6)" % [solid, painted_solid])
	_check(covered == painted_covered and covered == 4,
			"covered cells painted as covered: %d flagged, %d painted (expected 4)" % [covered, painted_covered])

	# --- 2. world -> minimap ----------------------------------------------------------
	var world := Node3D.new()
	add_child(world)
	var city := City.new()
	city.map = map
	world.add_child(city)
	var taxi := TAXI.instantiate() as Taxi
	taxi.input_provider = self
	world.add_child(taxi)
	var minimap := Minimap.new()
	minimap.size = Vector2(160, 160)
	add_child(minimap)
	await _wait(0.5)

	for yaw_deg: float in [0.0, 90.0, -135.0]:
		taxi.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), map.cell_center(20, 12) + Vector3(0, 0.9, 0)))
		await _wait(0.5)
		var centre := minimap.size * 0.5
		var here := taxi.global_position
		var forward := -taxi.global_basis.z
		var right := taxi.global_basis.x

		var at_self := minimap.world_to_minimap(here)
		_check(at_self.distance_to(centre) < 1.5, "yaw %.0f: the taxi sits at the centre" % yaw_deg)

		var ahead := minimap.world_to_minimap(here + forward * 40.0)
		_check(ahead.y < centre.y - 10.0 and absf(ahead.x - centre.x) < 6.0,
				"yaw %.0f: 40 m ahead draws above the centre (got %.0f, %.0f)" % [yaw_deg, ahead.x, ahead.y])

		var beside := minimap.world_to_minimap(here + right * 40.0)
		_check(beside.x > centre.x + 10.0 and absf(beside.y - centre.y) < 6.0,
				"yaw %.0f: 40 m to the right draws right of the centre (got %.0f, %.0f)" % [yaw_deg, beside.x, beside.y])

	if _errors.is_empty():
		print("[MinimapTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[MinimapTest] FAIL: ", e)
		get_tree().quit(1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
