class_name WeaponBar
extends Control
## Weapon hotbar (bottom-left of the HUD, full-screen Control that only draws there).
## One card per weapon that exists, in slot order = number key: gun silhouette, slot key,
## magazine bar + "mag | reserve". The equipped one is raised, yellow-framed and white; owned
## ones are grey; not-owned ones are dark with a lock and their gun-shop price. Above the bar
## the equipped weapon's name + ammo in big type; on a switch the name pops.

const CARD := Vector2(116.0, 84.0)
const GAP := 8.0
const MARGIN := Vector2(18.0, 16.0)
const RAISE := 10.0
const YELLOW := Color(1.0, 0.82, 0.1)
const RED := Color(1.0, 0.35, 0.3)
const BG := Color(0.04, 0.04, 0.06, 0.72)

## Gun silhouettes in a 100 x 40 box, muzzle to the right. Several polygons per gun.
const SHAPES := {
	&"revolver": [
		[Vector2(40, 8), Vector2(92, 8), Vector2(92, 15), Vector2(40, 15)],
		[Vector2(28, 6), Vector2(50, 6), Vector2(50, 22), Vector2(28, 22)],
		[Vector2(30, 18), Vector2(40, 18), Vector2(35, 37), Vector2(25, 37)],
		[Vector2(23, 3), Vector2(30, 3), Vector2(30, 10)],
		[Vector2(38, 22), Vector2(46, 22), Vector2(44, 28), Vector2(38, 28)],
	],
	&"smg": [
		[Vector2(20, 10), Vector2(78, 10), Vector2(78, 22), Vector2(20, 22)],
		[Vector2(78, 13), Vector2(97, 13), Vector2(97, 18), Vector2(78, 18)],
		[Vector2(32, 22), Vector2(43, 22), Vector2(41, 38), Vector2(30, 38)],
		[Vector2(50, 22), Vector2(58, 22), Vector2(60, 40), Vector2(52, 40)],
		[Vector2(2, 11), Vector2(20, 12), Vector2(20, 18), Vector2(2, 20)],
	],
	&"shotgun": [
		[Vector2(36, 8), Vector2(97, 8), Vector2(97, 13), Vector2(36, 13)],
		[Vector2(36, 14), Vector2(97, 14), Vector2(97, 19), Vector2(36, 19)],
		[Vector2(22, 7), Vector2(40, 7), Vector2(40, 23), Vector2(22, 23)],
		[Vector2(22, 14), Vector2(30, 16), Vector2(14, 36), Vector2(3, 33)],
	],
	&"rifle": [
		[Vector2(44, 12), Vector2(99, 12), Vector2(99, 16), Vector2(44, 16)],
		[Vector2(46, 17), Vector2(86, 17), Vector2(86, 21), Vector2(46, 21)],
		[Vector2(30, 9), Vector2(50, 9), Vector2(50, 21), Vector2(30, 21)],
		[Vector2(0, 15), Vector2(30, 11), Vector2(30, 22), Vector2(2, 30)],
		[Vector2(36, 21), Vector2(48, 21), Vector2(46, 30), Vector2(36, 29)],
	],
}

var _catalogue: Array[WeaponData] = []
var _last_id: StringName = &""
var _pop: float = 0.0
var _font: Font
var _bold: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catalogue = WeaponController.catalogue()
	_font = ThemeDB.fallback_font
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_embolden = 0.9


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 2.5, 0.0)
	var wc := _controller()
	var w := wc.current_weapon() if wc != null else null
	if w != null and w.id != _last_id:
		if _last_id != &"":
			_pop = 1.0
		_last_id = w.id
	queue_redraw()


func _draw() -> void:
	var wc := _controller()
	if wc == null or wc.current_weapon() == null:
		return
	var cur := wc.current_weapon()
	var base_y := size.y - MARGIN.y - CARD.y
	for i in _catalogue.size():
		var w := _catalogue[i]
		var owned := wc.owns(w.id)
		var selected := w.id == cur.id
		var pos := Vector2(MARGIN.x + i * (CARD.x + GAP), base_y - (RAISE if selected else 0.0))
		_draw_card(wc, w, Rect2(pos, CARD), owned, selected)
	# Equipped weapon: name + ammo in big type above the bar.
	var a := wc.get_ammo()
	var title_y := base_y - RAISE - 14.0
	var name_size := int(30 + 10 * _pop)
	var title := cur.display_name.to_upper()
	_text(_bold, Vector2(MARGIN.x, title_y), title, YELLOW.lerp(Color.WHITE, _pop), name_size, 7)
	var tw := _bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var ammo_text := "RELOADING" if wc.is_reloading else "%d | %d" % [a["mag"], a["reserve"]]
	var ammo_col := YELLOW if wc.is_reloading else (RED if int(a["mag"]) == 0 else Color.WHITE)
	_text(_bold, Vector2(MARGIN.x + tw + 16.0, title_y), ammo_text, ammo_col, 26, 6)


func _draw_card(wc: WeaponController, w: WeaponData, r: Rect2, owned: bool, selected: bool) -> void:
	draw_rect(r, BG if owned else Color(0.02, 0.02, 0.03, 0.55))
	if selected:
		draw_rect(r.grow(1.0), YELLOW, false, 3.0)
	# Slot key.
	var key := Rect2(r.position + Vector2(5, 5), Vector2(20, 20))
	draw_rect(key, YELLOW if selected else Color(1, 1, 1, 0.18 if owned else 0.08))
	_text(_font, key.position + Vector2(6, 15), str(w.slot), Color.BLACK if selected else Color(1, 1, 1, 0.8 if owned else 0.35), 15, 0)
	# Silhouette.
	var icon := Rect2(r.position + Vector2(10, 22), Vector2(r.size.x - 20, 34))
	var col := Color.WHITE if selected else (Color(0.72, 0.72, 0.75) if owned else Color(0.25, 0.25, 0.28))
	_draw_gun(w.id, icon, col)
	if not owned:
		_draw_lock(r.position + Vector2(r.size.x - 22, 6))
		_text(_font, r.position + Vector2(8, r.size.y - 9), "$%d · GUN SHOP" % w.price, Color(1, 1, 1, 0.45), 12, 0)
		return
	# Magazine bar + numbers.
	var a := wc.get_ammo(w)
	var bar := Rect2(r.position + Vector2(8, r.size.y - 22), Vector2(r.size.x - 16, 5))
	draw_rect(bar, Color(1, 1, 1, 0.15))
	var fill := clampf(float(a["mag"]) / maxf(w.mag_size, 1), 0.0, 1.0)
	if selected and wc.is_reloading:
		fill = wc.get_reload_progress()
	var fill_col := RED if int(a["mag"]) == 0 and not (selected and wc.is_reloading) else (YELLOW if selected else Color(0.8, 0.8, 0.8))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), fill_col)
	var low := int(a["mag"]) == 0 and int(a["reserve"]) == 0
	_text(_font, r.position + Vector2(8, r.size.y - 4), "EMPTY" if low else "%d | %d" % [a["mag"], a["reserve"]],
		RED if low else Color(1, 1, 1, 0.85 if selected else 0.6), 13, 0)


func _draw_gun(id: StringName, box: Rect2, col: Color) -> void:
	draw_gun(self, id, box, col)


## Draws a weapon's silhouette into `box` on any CanvasItem (also used by the gun shop).
static func draw_gun(ci: CanvasItem, id: StringName, box: Rect2, col: Color) -> void:
	var polys: Array = SHAPES.get(id, [[Vector2(10, 12), Vector2(90, 12), Vector2(90, 26), Vector2(10, 26)]])
	var s := minf(box.size.x / 100.0, box.size.y / 40.0)
	var off := box.position + (box.size - Vector2(100, 40) * s) * 0.5
	for poly: Array in polys:
		var pts := PackedVector2Array()
		for p: Vector2 in poly:
			pts.append(off + p * s)
		ci.draw_colored_polygon(pts, col)


func _draw_lock(p: Vector2) -> void:
	var c := Color(1, 1, 1, 0.45)
	draw_arc(p + Vector2(8, 7), 5.0, PI, TAU, 8, c, 2.0)
	draw_rect(Rect2(p + Vector2(2, 7), Vector2(12, 10)), c)


func _text(font: Font, pos: Vector2, text: String, color: Color, font_size: int, outline: int) -> void:
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _controller() -> WeaponController:
	return get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
