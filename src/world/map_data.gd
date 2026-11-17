class_name MapData
extends RefCounted
## A city map: a grid of CELL x CELL metre cells with a list of pieces on it (buildings,
## plazas, stairs, ramps, taxi stops, repair shops, neighbourhood zones...). Saved as JSON in
## res://data/maps/ (written by the in-game map editor, src/editor/). The City node builds
## the playable world from it; everything not covered by a solid piece is drivable asphalt and
## the road graph for the AI is derived from the free cells.
##
## A piece is a Dictionary:
##   type   String   key of TYPES
##   x, z   int      cell of the footprint's min corner (x grows east, z grows south)
##   w, d   int      footprint in cells (point pieces: 1 x 1)
##   h      float    height in metres (meaning depends on the type)
##   rot    int      0 = north (-Z), 1 = east (+X), 2 = south (+Z), 3 = west (-X)
##   shape  String   variant of the type (see TYPES[..]["shapes"])
##   mat    String   material name in res://assets/materials/ (buildings)
##   name   String   stop name / zone display name (optional)
##   id     String   zone id = district of the stops inside it (e.g. "docks")

const CELL := 8.0
const MAPS_DIR := "res://data/maps/"
## An exported build cannot write into res:// (it is packed): its editor saves here, and
## maps are looked up here first.
const USER_MAPS_DIR := "user://maps/"
const DEFAULT_NAME := "city"
## The map an exported build starts on (D-097): the last map PLAYed from the map editor while
## running in the Godot editor is written here and shipped with every export, so a fresh install
## plays the developer's map instead of the generated starter city.
const SHIPPED_ACTIVE := "res://data/default_map.txt"
const USER_ACTIVE := "user://active_map.txt"
const FORMAT := 2
const MIN_SIZE := 16
const MAX_SIZE := 160

const DIRS: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
const DIR_NAMES: Array[String] = ["north", "east", "south", "west"]

const BUILDING_MATS: Array[String] = ["building_a", "building_b", "building_c", "wall",
	"container_red", "container_blue", "container_green", "prop"]

## area: dragged as a rectangle (else one cell). solid: blocks the road graph.
const TYPES := {
	"building": {"label": "Building", "area": true, "solid": true, "h": 14.0, "min_h": 2.0, "max_h": 120.0,
		"shapes": ["box", "tower", "stepped", "l_shape", "round", "house"], "size": [2, 2]},
	"plaza": {"label": "Plaza / platform", "area": true, "solid": false, "h": 0.6, "min_h": 0.2, "max_h": 6.0,
		"shapes": ["steps", "flat"], "size": [4, 4]},
	"stairs": {"label": "Low stairs", "area": true, "solid": false, "h": 0.8, "min_h": 0.2, "max_h": 6.0,
		"shapes": ["steps"], "size": [1, 1]},
	# Kicker default 3.0 m: its lip is above one level of containers (2.8 m), so a ramp placed
	# right in front of them jumps the taxi over (tests/jump_autotest).
	"ramp": {"label": "Ramp", "area": true, "solid": false, "h": 3.0, "min_h": 0.3, "max_h": 8.0,
		"shapes": ["kicker", "wedge"], "size": [1, 1]},
	"sidewalk": {"label": "Sidewalk", "area": true, "solid": false, "h": 0.2, "min_h": 0.1, "max_h": 0.4,
		"shapes": ["slab"], "size": [2, 2]},
	"containers": {"label": "Containers", "area": true, "solid": true, "h": 1.0, "min_h": 1.0, "max_h": 3.0,
		"shapes": ["stacks"], "size": [2, 1]},
	"pillar": {"label": "Pillar", "area": false, "solid": false, "h": 3.0, "min_h": 1.0, "max_h": 12.0,
		"shapes": ["post"], "size": [1, 1]},
	"repair": {"label": "Repair shop", "area": true, "solid": true, "h": 6.0, "min_h": 4.0, "max_h": 12.0,
		"shapes": ["garage"], "size": [3, 3]},
	"gunshop": {"label": "Gun shop", "area": true, "solid": true, "h": 6.0, "min_h": 4.0, "max_h": 12.0,
		"shapes": ["store"], "size": [3, 3]},
	"stop": {"label": "Taxi stop", "area": false, "solid": false, "h": 0.0, "min_h": 0.0, "max_h": 0.0,
		"shapes": ["stop"], "size": [1, 1]},
	"drink": {"label": "Energy drink", "area": false, "solid": false, "h": 0.0, "min_h": 0.0, "max_h": 0.0,
		"shapes": ["can"], "size": [1, 1]},
	"zone": {"label": "Neighbourhood zone", "area": true, "solid": false, "h": 0.0, "min_h": 0.0, "max_h": 0.0,
		"shapes": ["zone"], "size": [8, 8]},
	"spawn": {"label": "Player start", "area": false, "solid": false, "h": 0.0, "min_h": 0.0, "max_h": 0.0,
		"shapes": ["spawn"], "size": [1, 1]},
}

## Grid flags (see flags()).
const F_SOLID := 1     # a wall: nothing drives through this cell
const F_COVERED := 2   # not plain street (any area piece): no lane dashes, sidewalk height

## Set by automated tests so they always run on the built-in city, whatever map the user
## made active in the editor.
static var override: MapData = null

var name: String = "untitled"
var width: int = 50    # cells along X
var depth: int = 50    # cells along Z
var pieces: Array[Dictionary] = []


# --- Pieces ---------------------------------------------------------------------------

static func make_piece(type: String, x: int, z: int, w: int = 0, d: int = 0) -> Dictionary:
	var info: Dictionary = TYPES[type]
	var size: Array = info["size"]
	var area: bool = info["area"]
	return {
		"type": type, "x": x, "z": z,
		"w": (w if w > 0 else int(size[0])) if area else 1,
		"d": (d if d > 0 else int(size[1])) if area else 1,
		"h": float(info["h"]), "rot": 0, "shape": String(info["shapes"][0]),
		"mat": "building_a", "name": "", "id": "",
	}


## Fills in missing keys and clamps values (files edited by hand / older versions).
static func sanitize(p: Dictionary) -> Dictionary:
	var type := String(p.get("type", ""))
	if not TYPES.has(type):
		return {}
	var out := make_piece(type, int(p.get("x", 0)), int(p.get("z", 0)), int(p.get("w", 0)), int(p.get("d", 0)))
	var info: Dictionary = TYPES[type]
	out["h"] = clampf(float(p.get("h", info["h"])), float(info["min_h"]), float(info["max_h"]))
	out["rot"] = posmod(int(p.get("rot", 0)), 4)
	var shape := String(p.get("shape", ""))
	if (info["shapes"] as Array).has(shape):
		out["shape"] = shape
	out["mat"] = String(p.get("mat", "building_a"))
	out["name"] = String(p.get("name", ""))
	out["id"] = String(p.get("id", ""))
	return out


static func rect_of(p: Dictionary) -> Rect2i:
	return Rect2i(int(p["x"]), int(p["z"]), int(p["w"]), int(p["d"]))


func bounds() -> Rect2i:
	return Rect2i(0, 0, width, depth)


func in_bounds(p: Dictionary) -> bool:
	return bounds().encloses(rect_of(p))


## Half extents of the map in metres.
func half() -> Vector2:
	return Vector2(width, depth) * CELL * 0.5


## World position (y = 0) of the min corner of a cell.
func cell_corner(x: int, z: int) -> Vector3:
	return Vector3(x * CELL - width * CELL * 0.5, 0.0, z * CELL - depth * CELL * 0.5)


func cell_center(x: int, z: int) -> Vector3:
	return cell_corner(x, z) + Vector3(CELL * 0.5, 0.0, CELL * 0.5)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori((pos.x + width * CELL * 0.5) / CELL), floori((pos.z + depth * CELL * 0.5) / CELL))


## World position of the centre of a piece's footprint.
func piece_center(p: Dictionary) -> Vector3:
	return cell_corner(int(p["x"]), int(p["z"])) + Vector3(int(p["w"]) * CELL * 0.5, 0.0, int(p["d"]) * CELL * 0.5)


## Index of the topmost piece at a cell (-1 = none). Zones only when `zones` is true and
## nothing else is there.
func piece_at(cell: Vector2i, zones: bool = true) -> int:
	var zone := -1
	for i in range(pieces.size() - 1, -1, -1):
		if rect_of(pieces[i]).has_point(cell):
			if String(pieces[i]["type"]) == "zone":
				if zone < 0:
					zone = i
			else:
				return i
	return zone if zones else -1


## Zone id (district) at a cell: the last zone drawn there wins. &"city" outside every zone.
func district_at(cell: Vector2i) -> StringName:
	for i in range(pieces.size() - 1, -1, -1):
		var p := pieces[i]
		if String(p["type"]) == "zone" and rect_of(p).has_point(cell):
			var id := String(p["id"]).strip_edges()
			return StringName(id) if id != "" else &"city"
	return &"city"


func zone_name_at(cell: Vector2i) -> String:
	for i in range(pieces.size() - 1, -1, -1):
		var p := pieces[i]
		if String(p["type"]) == "zone" and rect_of(p).has_point(cell):
			return String(p["name"]) if String(p["name"]) != "" else String(p["id"]).capitalize()
	return ""


static func is_solid(p: Dictionary) -> bool:
	var type := String(p["type"])
	if type == "plaza":
		# A sheer platform is a wall for the AI; a stepped plaza can be driven over.
		return String(p["shape"]) == "flat" and float(p["h"]) > 0.45
	return bool(TYPES[type]["solid"])


## One byte per cell (index = z * width + x): F_SOLID | F_COVERED.
func flags() -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(width * depth)
	for p in pieces:
		var type := String(p["type"])
		if not bool(TYPES[type]["area"]) or type == "zone":
			continue
		var bits := F_COVERED | (F_SOLID if is_solid(p) else 0)
		var r := rect_of(p).intersection(bounds())
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				grid[z * width + x] |= bits
	return grid


func count(type: String) -> int:
	var n := 0
	for p in pieces:
		if String(p["type"]) == type:
			n += 1
	return n


## The player start: {pos: Vector3, rot: int}. Without a spawn piece: the free cell nearest
## to the centre of the map.
func spawn_point() -> Dictionary:
	for p in pieces:
		if String(p["type"]) == "spawn":
			return {"pos": cell_center(int(p["x"]), int(p["z"])), "rot": int(p["rot"])}
	var grid := flags()
	var best := Vector2i(width / 2, depth / 2)
	var best_d := INF
	for z in depth:
		for x in width:
			if grid[z * width + x] == 0:
				var d := Vector2(x - width * 0.5, z - depth * 0.5).length_squared()
				if d < best_d:
					best_d = d
					best = Vector2i(x, z)
	return {"pos": cell_center(best.x, best.y), "rot": 0}


## Problems that make the map unplayable ("ERROR: ...") or poorer ("Warning: ...").
func validate() -> PackedStringArray:
	var out: PackedStringArray = []
	var stops := count("stop")
	if stops < 2:
		out.append("ERROR: the map needs at least 2 taxi stops (it has %d)" % stops)
	elif stops < 12:
		out.append("Warning: only %d taxi stops — passengers will be rare and rides repetitive" % stops)
	if count("spawn") == 0:
		out.append("Warning: no player start — the taxi starts at the free cell nearest to the centre")
	if count("spawn") > 1:
		out.append("Warning: more than one player start — the first one is used")
	if count("repair") == 0:
		out.append("Warning: no repair shop — a wrecked taxi repairs itself after a few seconds")
	if count("gunshop") == 0:
		out.append("Warning: no gun shop — you will only ever have the revolver")
	var grid := flags()
	for p in pieces:
		var type := String(p["type"])
		if not in_bounds(p):
			out.append("ERROR: a %s at %d,%d sticks out of the map" % [type, int(p["x"]), int(p["z"])])
		elif (type == "stop" or type == "spawn") and grid[int(p["z"]) * width + int(p["x"])] & F_SOLID:
			out.append("ERROR: a %s at %d,%d is inside a solid piece" % [type, int(p["x"]), int(p["z"])])
	return out


func has_errors() -> bool:
	for line in validate():
		if line.begins_with("ERROR"):
			return true
	return false


# --- Files ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"format": FORMAT, "name": name, "cell": CELL, "width": width, "depth": depth, "pieces": pieces}


## Format 1 -> 2 (2026-11-13): the old default kicker (2.0 m) could not clear the old default
## containers (stacked 1-2 high at random). Pieces still at those old defaults get the new
## ones (kicker 3.0 m, one level of containers); anything the mapper changed is left alone.
## The file itself only changes when the map is saved again from the editor.
static func _upgrade_v1(p: Dictionary) -> void:
	if String(p["type"]) == "ramp" and String(p["shape"]) == "kicker" and is_equal_approx(float(p["h"]), 2.0):
		p["h"] = float(TYPES["ramp"]["h"])
	elif String(p["type"]) == "containers" and is_equal_approx(float(p["h"]), 2.0):
		p["h"] = float(TYPES["containers"]["h"])


static func from_dict(data: Dictionary) -> MapData:
	var map := MapData.new()
	map.name = String(data.get("name", "untitled"))
	map.width = clampi(int(data.get("width", 50)), MIN_SIZE, MAX_SIZE)
	map.depth = clampi(int(data.get("depth", 50)), MIN_SIZE, MAX_SIZE)
	for raw: Variant in data.get("pieces", []):
		if raw is Dictionary:
			var p := sanitize(raw)
			if not p.is_empty():
				if int(data.get("format", 1)) < 2:
					_upgrade_v1(p)
				map.pieces.append(p)
	return map


func duplicate_map() -> MapData:
	return MapData.from_dict(to_dict().duplicate(true))


## Where maps are saved: res://data/maps/ when running from the Godot editor, user://maps/
## in an exported build.
static func save_dir() -> String:
	return MAPS_DIR if OS.has_feature("editor") else USER_MAPS_DIR


static func path_for(map_name: String) -> String:
	return save_dir() + _file_name(map_name)


static func _file_name(map_name: String) -> String:
	return map_name.validate_filename().to_lower().replace(" ", "_") + ".json"


## The saved file of a map: the writable folder first, then the maps shipped in res://.
static func find_path(map_name: String) -> String:
	for dir in [save_dir(), USER_MAPS_DIR, MAPS_DIR]:
		var path: String = dir + _file_name(map_name)
		if FileAccess.file_exists(path):
			return path
	return ""


func save() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir()))
	var file := FileAccess.open(path_for(name), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return OK


static func load_map(map_name: String) -> MapData:
	var path := find_path(map_name)
	if path == "":
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("[MapData] %s is not a map file" % path)
		return null
	return from_dict(parsed)


static func list_maps() -> PackedStringArray:
	var out: PackedStringArray = []
	for path in [MAPS_DIR, USER_MAPS_DIR]:
		var dir := DirAccess.open(path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.ends_with(".json") and not out.has(file.get_basename()):
				out.append(file.get_basename())
	out.sort()
	return out


## The map the game plays: `--map=<name>` (command line) > the one picked in the editor on this
## machine (user://active_map.txt) > the one shipped with the build (SHIPPED_ACTIVE) > "city" >
## the built-in generated city.
static func load_active() -> MapData:
	if override != null:
		return override
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			wanted = arg.get_slice("=", 1)
	if wanted == "":
		wanted = active_name()
	if wanted != "builtin":
		var map := load_map(wanted)
		if map != null and not map.has_errors():
			return map
	return make_default()


## Tests: play the built-in starter city.
static func use_builtin() -> void:
	override = make_default()


## The map picked last (this machine first, then the one the build shipped with), or DEFAULT_NAME.
static func active_name() -> String:
	for path in [USER_ACTIVE, SHIPPED_ACTIVE]:
		if FileAccess.file_exists(path):
			var n := FileAccess.get_file_as_string(path).strip_edges()
			if n != "":
				return n
	return DEFAULT_NAME


## Remembers the map to play. Run from the Godot editor it also becomes the map the next exported
## build starts on (SHIPPED_ACTIVE, D-097); an exported build only remembers it for this machine.
static func set_active(map_name: String) -> void:
	var paths: Array[String] = [USER_ACTIVE]
	if OS.has_feature("editor"):
		paths.append(SHIPPED_ACTIVE)
	for path in paths:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(map_name)
			file.close()


static func make_empty(map_name: String, w: int, d: int) -> MapData:
	var map := MapData.new()
	map.name = map_name
	map.width = clampi(w, MIN_SIZE, MAX_SIZE)
	map.depth = clampi(d, MIN_SIZE, MAX_SIZE)
	return map


# --- Built-in city --------------------------------------------------------------------

const GEN_BLOCKS := 8     # blocks per side
const GEN_BLOCK := 4      # cells per block (32 m)
const GEN_STREET := 2     # cells per street (16 m)
const GEN_PITCH := GEN_BLOCK + GEN_STREET


## Min cell of block (i, j) of the built-in city.
static func gen_block_cell(i: int, j: int) -> Vector2i:
	return Vector2i(GEN_STREET + i * GEN_PITCH, GEN_STREET + j * GEN_PITCH)


## The generated starter city (also what the game plays when there is no map file): 8 x 8
## blocks, suburbs / downtown / docks, a plaza, street ramps, three repair shops, two gun shops. A good
## starting point to edit: "Starter city" in the map editor.
static func make_default(rng_seed: int = 4242) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var size := GEN_BLOCKS * GEN_PITCH + GEN_STREET
	var map := make_empty(DEFAULT_NAME, size, size)
	var zones := [["suburbs", "Suburbs", 0, 19], ["downtown", "Downtown", 19, 18], ["docks", "The Docks", 37, size - 37]]
	for zdef: Array in zones:
		var zone := make_piece("zone", int(zdef[2]), 0, int(zdef[3]), size)
		zone["id"] = zdef[0]
		zone["name"] = zdef[1]
		map.pieces.append(zone)
	var plaza_block := Vector2i(4, 3)
	var repair_blocks := [Vector2i(1, 5), Vector2i(4, 6), Vector2i(7, 1)]
	var gun_blocks := [Vector2i(2, 1), Vector2i(6, 4)]
	for i in GEN_BLOCKS:
		for j in GEN_BLOCKS:
			var c := gen_block_cell(i, j)
			var block := Vector2i(i, j)
			if block == plaza_block:
				var plaza := make_piece("plaza", c.x, c.y, 4, 4)
				plaza["h"] = 0.6
				map.pieces.append(plaza)
				var kicker := make_piece("ramp", c.x + 1, c.y + 2, 1, 1)
				kicker["h"] = 1.8
				map.pieces.append(kicker)
				for corner: Vector2i in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]:
					map.pieces.append(make_piece("pillar", c.x + corner.x, c.y + corner.y))
			elif repair_blocks.has(block):
				var shop := make_piece("repair", c.x, c.y, 4, 4)
				shop["rot"] = 0
				map.pieces.append(shop)
			elif gun_blocks.has(block):
				var guns := make_piece("gunshop", c.x, c.y, 4, 4)
				guns["rot"] = 0
				map.pieces.append(guns)
			elif i <= 2:
				map.pieces.append(make_piece("sidewalk", c.x, c.y, 4, 4))
				for ox: int in [0, 2]:
					for oz: int in [0, 2]:
						var house := make_piece("building", c.x + ox, c.y + oz, 2, 2)
						house["h"] = snappedf(rng.randf_range(4.0, 8.0), 0.5)
						house["shape"] = "house" if rng.randf() < 0.6 else "box"
						house["mat"] = ["building_a", "building_c"][rng.randi() % 2]
						house["rot"] = rng.randi() % 2
						map.pieces.append(house)
			elif i <= 5:
				var tower := make_piece("building", c.x, c.y, 4, 4)
				tower["h"] = snappedf(rng.randf_range(20.0, 60.0), 1.0)
				tower["shape"] = ["box", "tower", "stepped", "round"][rng.randi() % 4]
				tower["mat"] = ["building_a", "building_b", "building_b"][rng.randi() % 3]
				map.pieces.append(tower)
			else:
				map.pieces.append(make_piece("sidewalk", c.x, c.y, 4, 4))
				var shed := make_piece("building", c.x, c.y, 4, 2)
				shed["h"] = snappedf(rng.randf_range(8.0, 12.0), 0.5)
				shed["mat"] = "building_c"
				map.pieces.append(shed)
				var cans := make_piece("containers", c.x, c.y + 3, 4, 1)
				cans["h"] = float(rng.randi_range(1, 2))
				map.pieces.append(cans)
			# Two stops per block: in the street north of it and in the street east of it.
			var north := make_piece("stop", c.x + 1, c.y - 1)
			north["rot"] = 2   # the passenger stands south of the stop (on the block)
			map.pieces.append(north)
			var east := make_piece("stop", c.x + GEN_BLOCK, c.y + 1)
			east["rot"] = 3
			map.pieces.append(east)
	# Jump ramps in the streets: [street index, block index] north-south, then east-west.
	for kj: Vector2i in [Vector2i(2, 5), Vector2i(6, 2), Vector2i(4, 6)]:
		var ramp := make_piece("ramp", kj.x * GEN_PITCH, gen_block_cell(0, kj.y).y + 1)
		ramp["h"] = 2.0
		map.pieces.append(ramp)
	for mi: Vector2i in [Vector2i(3, 1), Vector2i(5, 6), Vector2i(2, 4)]:
		var ramp := make_piece("ramp", gen_block_cell(mi.y, 0).x + 1, mi.x * GEN_PITCH)
		ramp["h"] = 2.0
		ramp["rot"] = 3
		map.pieces.append(ramp)
	# Energy drinks over random intersections (not the central one).
	var spots: Array[Vector2i] = []
	for k in GEN_BLOCKS + 1:
		for m in GEN_BLOCKS + 1:
			if absi(k - 4) + absi(m - 4) > 0:
				spots.append(Vector2i(k * GEN_PITCH, m * GEN_PITCH))
	for n in 12:
		var idx := rng.randi_range(0, spots.size() - 1)
		map.pieces.append(make_piece("drink", spots[idx].x, spots[idx].y))
		spots.remove_at(idx)
	var spawn := make_piece("spawn", 4 * GEN_PITCH, 4 * GEN_PITCH)
	map.pieces.append(spawn)
	return map
