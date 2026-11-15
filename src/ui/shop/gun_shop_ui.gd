class_name GunShopUI
extends Control
## The gun shop screen (Main/UI, process ALWAYS). Opened by a GunShop pad; pauses the world
## like the passenger file. One card per weapon (slot order): silhouette, name, one-liner,
## stat bars, BUY / OWNED, REFILL AMMO. Mouse or pad (focus); Esc / B / LEAVE closes.

const YELLOW := Color(1.0, 0.82, 0.1)
const GREEN := Color(0.35, 0.85, 0.45)
const RED := Color(1.0, 0.35, 0.3)
const CARD_W := 238.0

var is_open: bool = false
var shop: GunShop

var _catalogue: Array[WeaponData] = []
var _cash: Label
var _note: Label
var _cards: HBoxContainer
var _leave: Button
var _buy_buttons: Dictionary = {}     # id -> Button
var _ammo_buttons: Dictionary = {}    # id -> Button
var _ammo_labels: Dictionary = {}     # id -> Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"gun_shop_ui")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_catalogue = WeaponController.catalogue()
	_build()


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
	_note.text = "Pick a gun. It is yours for the rest of the run."
	_refresh()
	_first_focus().grab_focus.call_deferred()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Buys a weapon (also used by tests). Returns true on success.
func buy(id: StringName) -> bool:
	var wc := _controller()
	var w := _weapon(id)
	if wc == null or w == null or wc.owns(id):
		return false
	if GameState.cash < w.price:
		_note.text = "Not enough cash for the %s — you need $%d more." % [w.display_name, w.price - GameState.cash]
		_note.modulate = RED
		return false
	GameState.add_cash(-w.price)
	wc.add_weapon(id)
	wc.select(wc.index_of_slot(w.slot))
	_note.text = "%s bought. Key %d / Y to switch to it." % [w.display_name, w.slot]
	_note.modulate = GREEN
	EventBus.hud_message.emit("BOUGHT: %s  -$%d" % [w.display_name.to_upper(), w.price], &"good")
	_refresh()
	return true


## Refills an owned weapon's ammo (also used by tests). Returns true on success.
func refill(id: StringName) -> bool:
	var wc := _controller()
	var w := _weapon(id)
	if wc == null or w == null or not wc.owns(id):
		return false
	if GameState.cash < w.ammo_price:
		_note.text = "Not enough cash for %s ammo ($%d)." % [w.display_name, w.ammo_price]
		_note.modulate = RED
		return false
	if not wc.refill_ammo(id):
		_note.text = "Your %s is already full." % w.display_name
		_note.modulate = Color.WHITE
		return false
	GameState.add_cash(-w.ammo_price)
	_note.text = "%s reloaded to the max." % w.display_name
	_note.modulate = GREEN
	_refresh()
	return true


func _refresh() -> void:
	var wc := _controller()
	_cash.text = "$%d" % GameState.cash
	for w in _catalogue:
		var owned := wc != null and wc.owns(w.id)
		var buy_b: Button = _buy_buttons[w.id]
		var ammo_b: Button = _ammo_buttons[w.id]
		buy_b.text = "OWNED" if owned else "BUY  $%d" % w.price
		buy_b.disabled = owned
		ammo_b.disabled = not owned
		ammo_b.text = "REFILL AMMO  $%d" % w.ammo_price
		var lbl: Label = _ammo_labels[w.id]
		if owned:
			var a := wc.get_ammo(w)
			lbl.text = "Ammo  %d | %d   (max %d | %d)" % [a["mag"], a["reserve"], w.mag_size, w.reserve_max]
		else:
			lbl.text = "Mag %d · carries %d" % [w.mag_size, w.reserve_max]
		buy_b.modulate = Color.WHITE if owned or GameState.cash >= w.price else Color(1, 1, 1, 0.55)
	for c in _cards.get_children():
		(c as Control).queue_redraw()


func _first_focus() -> Control:
	for w in _catalogue:
		var b: Button = _buy_buttons[w.id]
		if not b.disabled:
			return b
	return _leave


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
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "GUN SHOP"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", GREEN)
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_cash = Label.new()
	_cash.add_theme_font_size_override("font_size", 34)
	_cash.add_theme_color_override("font_color", YELLOW)
	head.add_child(_cash)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 12)
	col.add_child(_cards)
	for w in _catalogue:
		_cards.add_child(_card(w))

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	_note = Label.new()
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.add_theme_font_size_override("font_size", 17)
	foot.add_child(_note)
	_leave = _button("LEAVE  (Esc / B)", close)
	_leave.custom_minimum_size.x = 200
	foot.add_child(_leave)


func _card(w: WeaponData) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.12)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size.x = CARD_W
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(CARD_W - 24, 78)
	icon.draw.connect(func() -> void:
		var wc := _controller()
		var owned := wc != null and wc.owns(w.id)
		WeaponBar.draw_gun(icon, w.id, Rect2(Vector2(10, 6), icon.size - Vector2(20, 12)),
			Color.WHITE if owned else Color(0.75, 0.78, 0.75))
		icon.draw_string(ThemeDB.fallback_font, Vector2(0, 16), "KEY %d" % w.slot, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45)))
	col.add_child(icon)

	var name_l := Label.new()
	name_l.text = w.display_name.to_upper()
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", YELLOW)
	col.add_child(name_l)
	var blurb := Label.new()
	blurb.text = w.blurb
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(CARD_W - 24, 66)
	blurb.add_theme_font_size_override("font_size", 14)
	blurb.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	col.add_child(blurb)

	# Stat bars, normalised against the strongest weapon in each column.
	col.add_child(_stat("Damage", w.damage * w.pellets / 90.0))
	col.add_child(_stat("Fire rate", w.fire_rate / 11.0))
	col.add_child(_stat("Accuracy", 1.0 - clampf(w.spread_aimed / 4.5, 0.0, 0.95)))
	col.add_child(_stat("Range", w.weapon_range / 260.0))

	var ammo_l := Label.new()
	ammo_l.add_theme_font_size_override("font_size", 13)
	ammo_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	col.add_child(ammo_l)
	_ammo_labels[w.id] = ammo_l
	var buy_b := _button("BUY", func() -> void: buy(w.id))
	col.add_child(buy_b)
	_buy_buttons[w.id] = buy_b
	var ammo_b := _button("REFILL AMMO", func() -> void: refill(w.id))
	ammo_b.add_theme_font_size_override("font_size", 15)
	col.add_child(ammo_b)
	_ammo_buttons[w.id] = ammo_b
	return card


func _stat(label: String, value: float) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 82
	l.add_theme_font_size_override("font_size", 13)
	row.add_child(l)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(CARD_W - 24 - 90, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := clampf(value, 0.05, 1.0)
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
