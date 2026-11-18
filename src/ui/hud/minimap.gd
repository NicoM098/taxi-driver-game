class_name Minimap
extends Control
## Square minimap that rotates with the taxi and shows a radius around it (D-083).
##
## **It is drawn from the map's own data, not from a second camera.** `MapData.flags()` already
## gives one byte per cell with `F_SOLID` / `F_COVERED`, which is a bitmap of the map: baked once
## into an `ImageTexture` (one pixel per cell, nearest filtering) when a city is built, and from
## then on this just draws a rotated slice of it plus a handful of blips. That is why it works on
## any map, including one made in the editor — there is nothing to keep in sync.
##
## Flat by design: a raised plaza is just another covered cell.

## Colours. Streets are the darkest thing on it so the blips read.
const STREET := Color(0.10, 0.11, 0.14, 0.85)
const COVERED := Color(0.24, 0.24, 0.28, 0.85)   # sidewalk, plaza, ramp, stairs
const BUILDING := Color(0.44, 0.44, 0.49, 0.85)
const EDGE := Color(0.0, 0.0, 0.0, 0.55)         # off the map
const BORDER := Color(0.0, 0.0, 0.0, 0.8)

const C_PLAYER := Color(1.0, 0.85, 0.2)
const C_ENEMY := Color(1.0, 0.3, 0.25)
const C_POLICE := Color(0.4, 0.65, 1.0)
const C_BOSS := Color(1.0, 0.7, 0.05)
const C_FARE := Color(0.5, 1.0, 0.5)
## Green like the dashboard arrow and the beacon in the world, never the player's yellow.
const C_DESTINATION := Color(0.3, 1.0, 0.45)
const C_REPAIR := Color(0.6, 0.8, 1.0)
const C_GUNSHOP := Color(1.0, 0.6, 0.2)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.9)
## Marker sizes in pixels, on a 164 px square: big on purpose, they must read at a glance.
const SHOP_HALF := 9.0
const DESTINATION_RADIUS := 11.0

## How many cells fit across the square. One cell is 8 m, so 26 is a bit over 200 m.
@export var cells_across: float = 26.0
@export var blip_radius: float = 5.0          # cars and fares; shops and the destination are bigger

var _tex: ImageTexture
var _map: MapData
var _city: City
var _taxi: Node3D
var _director: EnemyDirector
var _rides: RideManager


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true                      # the square is the window; nothing spills out
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	_refresh_sources()
	queue_redraw()


## Rebuilds the baked texture whenever the city (and so the map) changes.
func _refresh_sources() -> void:
	var city := get_tree().get_first_node_in_group(&"city") as City
	if city != _city:
		_city = city
		_map = city.map if city != null else null
		_tex = bake(_map) if _map != null else null
	if _taxi == null or not is_instance_valid(_taxi):
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	if _director == null or not is_instance_valid(_director):
		_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	if _rides == null or not is_instance_valid(_rides):
		_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager


## One pixel per cell. 2,500 of them for the starter city, 25,600 for the biggest map the editor
## allows, so this is cheap enough to do on every map load.
static func bake(map: MapData) -> ImageTexture:
	if map == null or map.width <= 0 or map.depth <= 0:
		return null
	var flags := map.flags()
	var img := Image.create(map.width, map.depth, false, Image.FORMAT_RGBA8)
	for z in map.depth:
		for x in map.width:
			var f := flags[z * map.width + x]
			var col := STREET
			if f & MapData.F_SOLID:
				col = BUILDING
			elif f & MapData.F_COVERED:
				col = COVERED
			img.set_pixel(x, z, col)
	return ImageTexture.create_from_image(img)


## Where a world position lands on the minimap, in pixels. Public so the test can check it.
func world_to_minimap(pos: Vector3) -> Vector2:
	var centre := size * 0.5
	if _map == null or _taxi == null:
		return centre
	var per_cell := size.x / maxf(cells_across, 1.0)
	var cells := Vector2(pos.x - _taxi.global_position.x, pos.z - _taxi.global_position.z) / MapData.CELL
	# The taxi's forward is -Z, which is already "up" on the texture at yaw 0, so rotating the
	# world offset by the yaw puts the heading at the top of the square.
	return centre + cells.rotated(_taxi.global_rotation.y) * per_cell


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), EDGE)
	if _tex != null and _map != null and _taxi != null:
		_draw_map()
		_draw_blips()
	_draw_player()
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 2.0)


func _draw_map() -> void:
	var per_cell := size.x / maxf(cells_across, 1.0)
	var origin := _map.cell_corner(0, 0)
	var taxi_cell := Vector2(_taxi.global_position.x - origin.x, _taxi.global_position.z - origin.z) \
			/ MapData.CELL
	# Draw in cell space, rotated about the taxi: the map turns, the arrow does not.
	draw_set_transform(size * 0.5, _taxi.global_rotation.y, Vector2(per_cell, per_cell))
	draw_texture_rect(_tex, Rect2(-taxi_cell, Vector2(_map.width, _map.depth)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_blips() -> void:
	# A square that rotates shows its corners at 45 degrees, so the cull radius is the
	# half-diagonal, not the half-side.
	var reach := cells_across * 0.75 * MapData.CELL
	var here := _taxi.global_position

	for p in shop_points(_city.repair_shops):
		_shop_blip(p, here, reach, C_REPAIR, "R")
	for p in shop_points(_city.gun_shops):
		_shop_blip(p, here, reach, C_GUNSHOP, "G")
	for stop in _city.stops:
		if stop.occupied:
			_blip(stop.global_position, here, reach, C_FARE)
	if _director != null:
		for enemy in _director.enemies:
			if enemy == null or not is_instance_valid(enemy) or enemy.is_destroyed:
				continue
			if enemy.is_boss():
				continue   # drawn last, on top (D-102)
			var police := enemy.data != null and String(enemy.data.resource_path).contains("police")
			_blip(enemy.global_position, here, reach, C_POLICE if police else C_ENEMY, 1.2)
	_draw_destination(here)
	if _director != null:
		for enemy in _director.enemies:
			if is_instance_valid(enemy) and not enemy.is_destroyed and enemy.is_boss():
				_draw_boss(enemy.global_position)


## A boss (D-102): a big gold blip with a B, kept on the map's border when out of range.
func _draw_boss(pos: Vector3) -> void:
	var at := world_to_minimap(pos)
	var r := 9.0 * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.008))
	var margin := r + 3.0
	at.x = clampf(at.x, margin, size.x - margin)
	at.y = clampf(at.y, margin, size.y - margin)
	draw_circle(at, r + 2.5, OUTLINE)
	draw_circle(at, r, C_BOSS)
	var font := get_theme_default_font()
	var tw := font.get_string_size("B", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, at + Vector2(-tw * 0.5, 5), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)


## The one blip worth keeping on screen when it is out of range: clamped to the border.
func _draw_destination(here: Vector3) -> void:
	if _rides == null or _rides.ride == null:
		return
	var destination := _rides.ride.destination
	if destination == null or not is_instance_valid(destination):
		return
	var at := world_to_minimap(destination.global_position)
	# A big pulsing diamond, so it cannot be read as a car or a fare.
	var r := DESTINATION_RADIUS * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.008))
	var margin := r + 3.0
	at.x = clampf(at.x, margin, size.x - margin)
	at.y = clampf(at.y, margin, size.y - margin)
	var diamond := PackedVector2Array([
			at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	draw_colored_polygon(diamond, C_DESTINATION)
	diamond.append(diamond[0])
	draw_polyline(diamond, OUTLINE, 4.0)
	draw_polyline(diamond, Color(1, 1, 1, 0.95), 2.0)


## Where shops go on the map. Shops are built in world coordinates under a node left at the
## origin, so `global_position` is (0, 0, 0) for every one of them: the pad is where the shop
## really is. Public so the test can check it.
static func shop_points(shops: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for shop in shops:
		if shop != null and is_instance_valid(shop):
			out.append(shop.pad_position)
	return out


## Shops are big squares with a letter and a dark outline: a fixed place, not something moving.
func _shop_blip(pos: Vector3, here: Vector3, reach: float, colour: Color, letter: String) -> void:
	if Vector2(pos.x - here.x, pos.z - here.z).length() > reach:
		return
	var r := SHOP_HALF
	var at := world_to_minimap(pos)
	var rect := Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)
	draw_rect(rect, colour)
	draw_rect(rect, OUTLINE, false, 2.0)
	var font := ThemeDB.fallback_font
	var fs := int(r * 1.5)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, OUTLINE)


func _blip(pos: Vector3, here: Vector3, reach: float, colour: Color, scale: float = 1.0) -> void:
	if Vector2(pos.x - here.x, pos.z - here.z).length() > reach:
		return
	var at := world_to_minimap(pos)
	draw_circle(at, blip_radius * scale + 1.5, OUTLINE)
	draw_circle(at, blip_radius * scale, colour)


## Fixed arrow at the centre: the map rotates around it.
func _draw_player() -> void:
	var c := size * 0.5
	var r := 9.0
	draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r * 0.7, r * 0.8), c, c + Vector2(-r * 0.7, r * 0.8)]),
			C_PLAYER)
