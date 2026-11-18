class_name GunShopUI
extends Control
## The gun shop screen (Main/UI, process ALWAYS). Opened from a GunShop pad with interact;
## pauses the world like the passenger file. Mouse or pad (focus); Esc / B / LEAVE closes.
##
## List + detail (D-086, eight guns no longer fit as cards): on the left every gun in slot order
## with its state (OWNED · Mk, price, or LOCKED x / N fares); on the right the selected one —
## silhouette, blurb, stat bars, BUY / REFILL AMMO, EQUIP / UNEQUIP, its Mk level and the next
## upgrade tracks (D-085, D-093). Only four guns ride in the cab (D-087): the rest are stored here.

## Every feedback line (bought, not enough cash...): the shop menu shows them (D-090).
signal said(text: String, colour: Color)

const YELLOW := Color(1.0, 0.82, 0.1)
const GREEN := Color(0.35, 0.85, 0.45)
const RED := Color(1.0, 0.35, 0.3)
const GREY := Color(1, 1, 1, 0.45)
const LIST_W := 330.0
const DETAIL_W := 600.0

var is_open: bool = false
var shop: GunShop

var _catalogue: Array[WeaponData] = []
var _selected: StringName = &""
var _cash: Label
var _note: Label
var _leave: Button
var _list_buttons: Dictionary = {}    # id -> Button
var _maxima: Dictionary = {}          # stat -> highest value in the catalogue

# Detail panel.
var _icon: Control
var _name: Label
var _blurb: Label
var _stats: VBoxContainer
var _ammo_label: Label
var _buy: Button
var _equip_b: Button
var _level: Label
var _up_note: Label
var _track_buttons: Dictionary = {}   # position 0-3 -> Button (D-093); its track depends on the gun (D-099)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"gun_shop_ui")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_catalogue = WeaponController.catalogue()
	for w in _catalogue:
		_maxima["damage"] = maxf(_maxima.get("damage", 1.0), w.damage * w.pellets)
		_maxima["rate"] = maxf(_maxima.get("rate", 1.0), w.fire_rate)
		_maxima["range"] = maxf(_maxima.get("range", 1.0), w.weapon_range)
		_maxima["blast"] = maxf(_maxima.get("blast", 1.0), w.blast_radius)
	_build()
	if not _catalogue.is_empty():
		_selected = _catalogue[0].id


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(from: GunShop) -> void:
	if is_open:
		return
	shop = from
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_note.text = "Guns and upgrades are yours until the run ends."
	_note.modulate = Color.WHITE
	_refresh()
	(_list_buttons[_selected] as Button).grab_focus.call_deferred()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Shows `id` in the detail panel.
func select(id: StringName) -> void:
	if _weapon(id) == null:
		return
	_selected = id
	_refresh()


## Buys a weapon (also used by tests). Returns true on success.
func buy(id: StringName) -> bool:
	var wc := _controller()
	var w := _weapon(id)
	if wc == null or w == null or wc.owns(id):
		return false
	if not WeaponUpgrades.is_unlocked(w, get_tree()):
		_say("The %s is not for sale yet: deliver %d more fares." % [
				w.display_name, w.unlock_rides - WeaponUpgrades.rides_done(get_tree())], RED)
		return false
	if GameState.cash < w.price:
		_say("Not enough cash for the %s — you need $%d more." % [w.display_name, w.price - GameState.cash], RED)
		return false
	GameState.add_cash(-w.price)
	wc.add_weapon(id)
	if wc.is_equipped(id):
		wc.select(wc.index_of_weapon(id))
		_say("%s bought. Key %d to switch to it." % [w.display_name, wc.index_of_weapon(id) + 1], GREEN)
	else:
		_say("%s bought and stored: you already carry %d guns. Unequip one to take it." % [
				w.display_name, WeaponController.LOADOUT_SIZE], YELLOW)
	EventBus.hud_message.emit("BOUGHT: %s  -$%d" % [w.display_name.to_upper(), w.price], &"good")
	_refresh()
	return true


## Equips an owned gun, or unequips it if it is equipped (also used by tests). True if it changed.
func toggle_equip(id: StringName) -> bool:
	var wc := _controller()
	var w := _weapon(id)
	if wc == null or w == null or not wc.owns(id):
		return false
	if wc.is_equipped(id):
		if not wc.unequip(id):
			_say("You need at least one gun in the cab.", RED)
			return false
		_say("%s stored here. It keeps its ammo and upgrades." % w.display_name, Color.WHITE)
	else:
		if not wc.equip(id):
			_say("You already carry %d guns: unequip one first." % WeaponController.LOADOUT_SIZE, RED)
			return false
		_say("%s equipped: key %d." % [w.display_name, wc.index_of_weapon(id) + 1], GREEN)
	_refresh()
	return true


## Buys the next level of one upgrade track (WeaponUpgrades.TRACKS) of an owned weapon (also
## used by tests). Returns true on success.
func upgrade(id: StringName, track: StringName) -> bool:
	var wc := _controller()
	var w := _weapon(id)
	if wc == null or w == null or not wc.owns(id) or not track in WeaponUpgrades.tracks_for(w):
		return false
	var track_name := WeaponUpgrades.track_name(w, track)
	var price := WeaponUpgrades.next_price(w, track)
	if price < 0:
		_say("%s %s is maxed." % [w.display_name, track_name], Color.WHITE)
		return false
	if GameState.cash < price:
		_say("Not enough cash for %s %s — you need $%d more." % [
				w.display_name, track_name, price - GameState.cash], RED)
		return false
	var had_special := WeaponUpgrades.special_in(id) == 0
	var gives := WeaponUpgrades.describe_next(w, track)
	GameState.add_cash(-price)
	wc.upgrade(id, track)
	var label := "%s %s %d (%s)" % [w.display_name, track_name, WeaponUpgrades.level(id, track), gives]
	if not had_special and WeaponUpgrades.special_in(id) == 0 and w.special != &"":
		label += " — %s!" % w.special_name.to_upper()
	_say("%s." % label, GREEN)
	EventBus.hud_message.emit("UPGRADED: %s  -$%d" % [label.to_upper(), price], &"good")
	_refresh()
	return true


func _say(text: String, colour: Color) -> void:
	_note.text = text
	_note.modulate = colour
	said.emit(text, colour)


# --- Refresh ---------------------------------------------------------------------------

func _refresh() -> void:
	var wc := _controller()
	var rides := WeaponUpgrades.rides_done(get_tree())
	_cash.text = "$%d" % GameState.cash
	for w in _catalogue:
		var b: Button = _list_buttons[w.id]
		var owned := wc != null and wc.owns(w.id)
		var state := ""
		var colour := Color.WHITE
		if owned and wc.is_equipped(w.id):
			state = "EQUIPPED · key %d  %s" % [wc.index_of_weapon(w.id) + 1, WeaponUpgrades.level_name(w.id)]
			colour = GREEN
		elif owned:
			state = "STORED  %s" % WeaponUpgrades.level_name(w.id)
			colour = Color(0.6, 0.85, 1.0)
		elif rides >= w.unlock_rides:
			state = "$%d" % w.price
			colour = YELLOW if GameState.cash >= w.price else Color(1, 0.82, 0.1, 0.55)
		else:
			state = "LOCKED  %d / %d fares" % [rides, w.unlock_rides]
			colour = GREY
		b.text = "%s\n   %s" % [w.display_name.to_upper(), state]
		b.add_theme_color_override("font_color", colour)
		b.add_theme_color_override("font_focus_color", colour.lightened(0.3))
		b.add_theme_color_override("font_hover_color", colour.lightened(0.3))
		b.button_pressed = w.id == _selected
	_refresh_detail(wc, rides)


func _refresh_detail(wc: WeaponController, rides: int) -> void:
	var w := _weapon(_selected)
	if w == null:
		return
	var owned := wc != null and wc.owns(w.id)
	var unlocked := rides >= w.unlock_rides
	_name.text = w.display_name.to_upper()
	_blurb.text = w.blurb
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	_stats.add_child(_stat("Damage", w.damage * w.pellets / _maxima["damage"]))
	_stats.add_child(_stat("Fire rate", w.fire_rate / _maxima["rate"]))
	_stats.add_child(_stat("Accuracy", 1.0 - clampf(w.spread_aimed / 4.5, 0.0, 0.95)))
	if w.blast_radius > 0.0:
		_stats.add_child(_stat("Blast", w.blast_radius / _maxima["blast"]))
	if w.kind != &"mine":
		_stats.add_child(_stat("Range", w.weapon_range / _maxima["range"]))
	if owned:
		var carried := wc.get_weapon(w.id)
		var a := wc.get_ammo(carried)
		if carried.reloads():
			_ammo_label.text = "Ammo  %d | %d   (max %d | %d)" % [a["mag"], a["reserve"], carried.mag_size, carried.reserve_max]
		else:
			_ammo_label.text = "Carries  %d / %d" % [a["mag"], carried.mag_size]
	elif not w.reloads():
		_ammo_label.text = "Carries %d · never reloads" % w.mag_size
	else:
		_ammo_label.text = "Mag %d · carries %d" % [w.mag_size, w.reserve_max]

	if owned:
		_buy.text = "OWNED"
	elif unlocked:
		_buy.text = "BUY  $%d" % w.price
	else:
		_buy.text = "LOCKED — %d more fares" % (w.unlock_rides - rides)
	_buy.disabled = owned or not unlocked
	_buy.modulate = Color.WHITE if _buy.disabled or GameState.cash >= w.price else Color(1, 1, 1, 0.55)
	var equipped := owned and wc.is_equipped(w.id)
	if equipped:
		_equip_b.text = "UNEQUIP"
		_equip_b.disabled = GameState.loadout.size() <= 1
	else:
		var carrying := "CARRYING %d / %d" % [GameState.loadout.size(), WeaponController.LOADOUT_SIZE]
		_equip_b.text = carrying if owned and wc.loadout_full() else "EQUIP"
		_equip_b.disabled = not owned or wc.loadout_full()

	var left := WeaponUpgrades.special_in(w.id)
	_level.text = "UPGRADES  %s" % (WeaponUpgrades.level_name(w.id) if WeaponUpgrades.total(w.id) > 0 else "none")
	_level.modulate = Color.WHITE if owned else Color(1, 1, 1, 0.4)
	_up_note.text = ("%s: %s" % [w.special_name, w.special_text]) + (
			"  (active)" if left == 0 else "  — after %d more upgrades." % left)
	var tracks := WeaponUpgrades.tracks_for(w)
	for i in tracks.size():
		var t := tracks[i]
		var b: Button = _track_buttons[i]
		var price := WeaponUpgrades.next_price(w, t)
		b.text = "%s  %d
%s" % [WeaponUpgrades.track_name(w, t).to_upper(), WeaponUpgrades.level(w.id, t),
				"MAXED" if price < 0 else "%s  $%d" % [WeaponUpgrades.describe_next(w, t), price]]
		b.disabled = not owned or price < 0
		b.modulate = Color.WHITE if b.disabled or GameState.cash >= price else Color(1, 1, 1, 0.55)
	_icon.queue_redraw()


# --- Build -----------------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.06, 0.97)
	style.border_color = GREEN
	style.border_width_top = 6
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "GUN SHOP"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GREEN)
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_cash = Label.new()
	_cash.add_theme_font_size_override("font_size", 32)
	_cash.add_theme_color_override("font_color", YELLOW)
	head.add_child(_cash)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	list.custom_minimum_size.x = LIST_W
	body.add_child(list)
	var group := ButtonGroup.new()
	for w in _catalogue:
		var b := _button("", func() -> void: select(w.id))
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(LIST_W, 56)
		b.add_theme_font_size_override("font_size", 16)
		b.focus_entered.connect(func() -> void:
			if _selected != w.id:
				select(w.id))
		list.add_child(b)
		_list_buttons[w.id] = b
	body.add_child(_build_detail())

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	_note = Label.new()
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.add_theme_font_size_override("font_size", 16)
	foot.add_child(_note)
	_leave = _button("LEAVE  (Esc / B)", close)
	_leave.custom_minimum_size.x = 200
	foot.add_child(_leave)


func _build_detail() -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.12)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size.x = DETAIL_W
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(DETAIL_W - 28, 70)
	_icon.draw.connect(func() -> void:
		var wc := _controller()
		var owned := wc != null and wc.owns(_selected)
		WeaponBar.draw_gun(_icon, _selected, Rect2(Vector2(120, 4), Vector2(_icon.size.x - 240, _icon.size.y - 8)),
			Color.WHITE if owned else Color(0.7, 0.72, 0.7)))
	col.add_child(_icon)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", YELLOW)
	col.add_child(_name)
	_blurb = Label.new()
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(DETAIL_W - 28, 40)
	_blurb.add_theme_font_size_override("font_size", 15)
	_blurb.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	col.add_child(_blurb)
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 3)
	_stats.custom_minimum_size.y = 5 * 20
	col.add_child(_stats)
	_ammo_label = Label.new()
	_ammo_label.add_theme_font_size_override("font_size", 14)
	_ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	col.add_child(_ammo_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	_buy = _button("BUY", func() -> void: buy(_selected))
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_buy)
	_equip_b = _button("EQUIP", func() -> void: toggle_equip(_selected))
	_equip_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_equip_b)

	_level = Label.new()
	_level.add_theme_font_size_override("font_size", 20)
	_level.add_theme_color_override("font_color", YELLOW)
	col.add_child(_level)
	_up_note = Label.new()
	_up_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_up_note.custom_minimum_size = Vector2(DETAIL_W - 28, 40)
	_up_note.add_theme_font_size_override("font_size", 15)
	_up_note.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	col.add_child(_up_note)
	var tracks := HBoxContainer.new()
	tracks.add_theme_constant_override("separation", 6)
	col.add_child(tracks)
	for i in WeaponUpgrades.TRACKS.size():
		var b := _button("", func() -> void:
			upgrade(_selected, WeaponUpgrades.tracks_for(_weapon(_selected))[i]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 48
		b.add_theme_font_size_override("font_size", 13)
		tracks.add_child(b)
		_track_buttons[i] = b
	return card


func _stat(label: String, value: float) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 90
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(DETAIL_W - 28 - 100, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := clampf(value, 0.04, 1.0)
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(1, 1, 1, 0.12))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * v, bar.size.y)), GREEN))
	row.add_child(bar)
	return row


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.add_theme_font_size_override("font_size", 18)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(action)
	return b


func _weapon(id: StringName) -> WeaponData:
	for w in _catalogue:
		if w.id == id:
			return w
	return null


func _controller() -> WeaponController:
	return get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
