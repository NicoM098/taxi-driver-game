class_name ShopMenu
extends Control
## Shop menu (Iteration 18 D-089, redone in Iteration 19 D-090): every shop in one screen you
## open anywhere with `shop_menu` (Tab / Back), instead of driving to a gun shop or a garage.
## Three tabs of cards, and every card carries its own buttons: one click buys, upgrades
## or equips, nothing to "enter" first.
##   GUNS             one card per gun: BUY (then OWNED: ammo drops from enemies, D-094), EQUIP,
##                    and a row of four upgrade tracks (mag, ammo, damage, fire rate; the last
##                    two endless, D-093)
##   THE CAB          taxi upgrades (data/car_upgrades/, section &"car")
##   SLOTS            the slot machine (D-106): a slot ticket (won from bosses) = one spin =
##                    a random perk (Double Tap, Quick Hands, Rolling Pickup; no longer sold)
##                    or +5 Damage / Fire rate levels on your 1st or 2nd most upgraded gun
## THE CAB is paid in spare parts (from every enemy killed), guns in cash (D-106).
##   MONSTROUS ENERGY cans to carry (drink with F / Y, CanHolder) and the can upgrades
##   REPAIR           always in the header: fixes the cab and the driver for the quoted price
## Q / E or LB / RB switch tabs. Pauses the world. Main/UI node, process ALWAYS.
##
## `enabled` = false gives the old game back: shops in the city, no menu, no car upgrades
## (City asks it before building a gun shop / repair garage; TaxiDamage before self-repair).

static var enabled: bool = true
## Iteration 20 (D-091, user: "you cant buy energy drinks and neither can you repair the car"):
## both off. The cans are then only found on the street; Monstrous XL moves to THE CAB (it still
## makes street cans heal more) and the Cup Holder Rack is not sold. True brings them back.
static var sells_cans: bool = false
static var sells_repair: bool = false

const YELLOW := Color(1.0, 0.82, 0.1)
const GREEN := Color(0.35, 0.88, 0.45)
const RED := Color(1.0, 0.36, 0.3)
const CYAN := Color(0.35, 0.88, 1.0)
const BLUE := Color(0.55, 0.75, 1.0)
const GREY := Color(1, 1, 1, 0.42)
const INK := Color(0.05, 0.05, 0.07)
const CARD_BG := Color(0.1, 0.1, 0.125)
const CARD_BG_FOCUS := Color(0.15, 0.15, 0.19)
const CARD_H := 112.0
const ICON_W := 124.0
const BUTTONS_W := 160.0

const VIOLET := Color(0.78, 0.55, 1.0)
const TABS: Array[StringName] = [&"guns", &"cab", &"perks", &"energy"]
const TAB_TITLE := {&"guns": "GUNS", &"cab": "THE CAB", &"perks": "SLOTS", &"energy": "MONSTROUS ENERGY"}
const TAB_ACCENT := {&"guns": GREEN, &"cab": YELLOW, &"perks": VIOLET, &"energy": CYAN}
## Card ids that are not CarUpgradeData / WeaponData ids.
const REPAIR := &"_repair"
const CANS := &"_cans"
const SLOTS := &"_slots"
const ORANGE := Color(1.0, 0.6, 0.2)

var is_open: bool = false
var tab: StringName = &"guns"

var _bold: FontVariation
var _root: Control
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _panel_pos: Vector2
var _cash: Label
var _health: Label
var _repair: Button
var _note: Label
var _tab_buttons: Dictionary = {}    # tab -> Button
var _pages: Dictionary = {}          # tab -> ScrollContainer
var _cards: Dictionary = {}          # card id -> {card, style, icon, title, state, pips, level, note, main, alt, alt2, tab, tracks}
var _icon_state: Dictionary = {}     # card id -> {col, badge, locked}
var _guns_ui: GunShopUI
var _last_cash: int = -1
var _wallet: Label
var _slot_rng := RandomNumberGenerator.new()
var _machine: SlotMachineScreen
var _reels: Array[String] = ["7", "7", "7"]
var _prize: Dictionary = {}


func _ready() -> void:
	_slot_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"shop_menu")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not enabled:
		visible = false
		set_process_input(false)
		return
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.85
	_build()
	_root.visible = false
	add_child(CanHolder.new())
	_machine = SlotMachineScreen.new()   # the slot machine, over the shop (D-107)
	_machine.name = "SlotMachine"
	add_child(_machine)
	_machine.finished.connect(_on_slots_finished)


## _input, not _unhandled_input: Tab is also the GUI's "focus next", which would eat it.
func _input(event: InputEvent) -> void:
	if is_open:
		if event.is_action_pressed(&"shop_menu") or event.is_action_pressed(&"pause") \
				or event.is_action_pressed(&"ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
			return
		var step := 0
		var key := event as InputEventKey
		var pad := event as InputEventJoypadButton
		if key != null and key.pressed and not key.echo:
			step = -1 if key.physical_keycode == KEY_Q else (1 if key.physical_keycode == KEY_E else 0)
		elif pad != null and pad.pressed:
			step = -1 if pad.button_index == JOY_BUTTON_LEFT_SHOULDER else (
					1 if pad.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
		if step != 0:
			var tabs := active_tabs()
			show_tab(tabs[wrapi(tabs.find(tab) + step, 0, tabs.size())])
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"shop_menu") and can_open():
		open()
		get_viewport().set_input_as_handled()


## Not on top of another screen (pause menu, passenger file, gun shop), not once dead.
func can_open() -> bool:
	if get_tree().paused:
		return false
	var damage := _damage()
	return damage != null and not damage.is_dead


func open() -> void:
	if is_open or not enabled:
		return
	is_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_last_cash = GameState.cash
	_say("Everything here is yours until the run ends.", Color(1, 1, 1, 0.75))
	show_tab(tab)
	# Slide + fade in.
	_panel.position = _panel_pos + Vector2(0, 24)
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "position", _panel_pos, 0.22)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.16)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	_panel.position = _panel_pos
	_panel.modulate.a = 1.0
	get_viewport().gui_release_focus()   # or Tab would move focus instead of reopening the menu
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_tab(id: StringName) -> void:
	if not _pages.has(id):
		return
	tab = id
	for t: StringName in _pages:
		(_pages[t] as Control).visible = t == id
		(_tab_buttons[t] as Button).set_pressed_no_signal(t == id)
	_panel_style.border_color = TAB_ACCENT[id]
	_refresh()
	if is_open:
		_focus_first.call_deferred()


## The tabs this build of the menu shows (no MONSTROUS ENERGY tab while cans are not sold).
static func active_tabs() -> Array[StringName]:
	var out: Array[StringName] = [&"guns", &"cab", &"perks"]
	if sells_cans:
		out.append(&"energy")
	return out


## Which tab an upgrade is listed in (null = not sold).
static func tab_of(u: CarUpgradeData) -> StringName:
	if u.section == &"car":
		return &"cab"
	if u.section == &"perks":
		return &"perks"
	if sells_cans:
		return &"energy"
	return &"cab" if u.stat == &"can_size" else &""


## The main button of an upgrade / cans / repair card (also used by tests). True if bought.
func activate(id: StringName) -> bool:
	if (id == REPAIR and not sells_repair) or (id == CANS and not sells_cans):
		_say("Not sold here.", RED)
		return false
	var listed := CarUpgrades.get_upgrade(id)
	if listed != null and tab_of(listed) == &"":
		_say("Not sold here.", RED)
		return false
	match id:
		SLOTS:
			open_slots()
			return true
		REPAIR:
			return _result(id, CarUpgrades.repair(get_tree()), "Cab and driver patched up.")
		CANS:
			return _result(id, CarUpgrades.buy_cans(1), "One more can in the cup holder.")
	var u := CarUpgrades.get_upgrade(id)
	if u == null:
		return false
	var lv := CarUpgrades.level(id)
	return _result(id, CarUpgrades.buy_level(get_tree(), id), "%s level %d: %s." % [u.display_name, lv + 1,
			CarUpgrades.effect_text(u, lv + 1)])


## A gun card's buttons (also used by tests): &"main" buys (ammo is not sold: it drops from
## enemies, D-094), &"equip" equips / unequips, a track id (WeaponUpgrades.TRACKS) buys its next level.
## True if something changed.
func gun_action(id: StringName, what: StringName) -> bool:
	var ui := _gun_ui()
	var wc := _controller()
	if ui == null or wc == null:
		return false
	var ok := false
	match what:
		&"main":
			ok = false if wc.owns(id) else ui.buy(id)
		&"equip":
			ok = ui.toggle_equip(id)
		_:
			ok = ui.upgrade(id, what)
	_after(id, ok)
	return ok


func _result(id: StringName, error: String, success: String) -> bool:
	if error != "":
		_say(error, RED)
	else:
		_say(success, GREEN)
	_after(id, error == "")
	return error == ""


func _after(id: StringName, ok: bool) -> void:
	_refresh()
	if ok and _cards.has(id):
		var card: Control = _cards[id]["card"]
		card.modulate = Color(1.6, 1.6, 1.6)
		create_tween().tween_property(card, "modulate", Color.WHITE, 0.35)


func _say(text: String, colour: Color) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", colour)


# --- Refresh ---------------------------------------------------------------------------

func _refresh() -> void:
	_cash.text = "$%d" % GameState.cash
	_wallet.text = "%d PARTS  ·  %d TICKET%s" % [GameState.parts, GameState.tickets, "" if GameState.tickets == 1 else "S"]
	if _last_cash >= 0 and GameState.cash != _last_cash:
		_cash.modulate = Color(1.6, 0.6, 0.5) if GameState.cash < _last_cash else Color(0.6, 1.6, 0.7)
		create_tween().tween_property(_cash, "modulate", Color.WHITE, 0.4)
	_last_cash = GameState.cash
	_refresh_repair()
	match tab:
		&"guns":
			var wc := _controller()
			var rides := WeaponUpgrades.rides_done(get_tree())
			for w in WeaponController.catalogue():
				_refresh_gun(w, wc, rides)
		&"cab", &"perks", &"energy":
			for u in CarUpgrades.catalogue():
				if _cards.has(u.id):
					_refresh_upgrade(u)
			if _cards.has(CANS):
				_refresh_cans()
			if _cards.has(SLOTS):
				_refresh_slots()


func _refresh_repair() -> void:
	var damage := _damage()
	var fee := CarUpgrades.repair_quote(damage)
	if damage != null and not damage.has_driver_bar():   # one bar (D-098)
		_health.text = "HEALTH  %d / %d" % [roundi(damage.taxi_health.hp), roundi(damage.taxi_health.max_hp)]
	elif damage != null:
		_health.text = "CAB  %d / %d\nDRIVER  %d / %d" % [roundi(damage.taxi_health.hp), roundi(damage.taxi_health.max_hp),
				roundi(damage.driver_health.hp), roundi(damage.driver_health.max_hp)]
	_repair.visible = sells_repair
	_repair.text = "REPAIR  $%d" % fee if fee > 0 else "NO DAMAGE"
	_repair.disabled = fee <= 0
	_paint(_repair, RED if GameState.cash >= fee else RED.darkened(0.45), fee > 0)


func _refresh_gun(w: WeaponData, wc: WeaponController, rides: int) -> void:
	var c: Dictionary = _cards[w.id]
	var owned := wc != null and wc.owns(w.id)
	var equipped := owned and wc.is_equipped(w.id)
	var unlocked := rides >= w.unlock_rides
	var accent := GREY
	var state := ""
	if equipped:
		accent = GREEN
		state = "EQUIPPED  ·  KEY %d" % (wc.index_of_weapon(w.id) + 1)
	elif owned:
		accent = BLUE
		state = "STORED"
	elif unlocked:
		accent = YELLOW
		state = "FOR SALE"
	else:
		state = "LOCKED  ·  %d / %d FARES" % [rides, w.unlock_rides]
	if owned:
		var a := wc.get_ammo(wc.get_weapon(w.id))
		state += "  ·  AMMO %s" % WeaponData.ammo_text(w, a)
	_set_card(c, w.display_name.to_upper(), state, accent)
	# Pips: the way to the special (WeaponUpgrades.SPECIAL_AT upgrades, any tracks).
	var total := WeaponUpgrades.total(w.id)
	var left := WeaponUpgrades.special_in(w.id)
	_set_pips(c, mini(total, WeaponUpgrades.SPECIAL_AT), WeaponUpgrades.SPECIAL_AT, YELLOW if left == 0 else accent,
			(("%s  %s" % [WeaponUpgrades.level_name(w.id), w.special_name.to_upper()]) if left == 0
			else "%s  %d to %s" % [WeaponUpgrades.level_name(w.id), left, w.special_name]).strip_edges())
	(c["note"] as Label).text = w.special_text if owned else w.blurb
	if not w.upgradable:   # The Devastator (D-107)
		_set_pips(c, 0, 0, RED, "CANNOT BE UPGRADED")
		(c["note"] as Label).text = w.blurb

	var main: Button = c["main"]
	if not owned:
		main.text = "BUY  $%d" % w.price if unlocked else "LOCKED"
		main.disabled = not unlocked
		_paint(main, YELLOW if GameState.cash >= w.price else YELLOW.darkened(0.5), unlocked)
	else:
		main.text = "OWNED"
		main.disabled = true
		_paint(main, BLUE.darkened(0.5), false)
	var alt: Button = c["alt"]
	if equipped:
		alt.text = "UNEQUIP"
		alt.disabled = GameState.loadout.size() <= 1
	else:
		alt.text = "CAB FULL (%d)" % WeaponController.LOADOUT_SIZE if owned and wc.loadout_full() else "EQUIP"
		alt.disabled = not owned or wc.loadout_full()
	for t: StringName in WeaponUpgrades.tracks_for(w):
		var b: Button = c["tracks"][t]
		var price := WeaponUpgrades.next_price(w, t)
		var lv := WeaponUpgrades.level(w.id, t)
		var head := "%s  %d" % [WeaponUpgrades.track_name(w, t).to_upper(),  lv]
		if WeaponUpgrades.CAP.has(t):
			head += "/%d" % int(WeaponUpgrades.CAP[t])
		b.text = "%s\n%s" % [head, "MAXED" if price < 0 else "%s  $%d" % [WeaponUpgrades.describe_next(w, t), price]]
		b.disabled = not owned or price < 0
		_paint(b, GREEN if GameState.cash >= price else GREEN.darkened(0.55), owned and price >= 0)
	_icon_state[w.id] = {"col": Color.WHITE if owned else (Color(0.75, 0.76, 0.78) if unlocked else Color(0.4, 0.4, 0.43)),
			"badge": wc.index_of_weapon(w.id) + 1 if equipped else 0, "locked": not unlocked and not owned}
	(c["icon"] as Control).queue_redraw()


func _refresh_upgrade(u: CarUpgradeData) -> void:
	var c: Dictionary = _cards[u.id]
	var lv := CarUpgrades.level(u.id)
	var top := CarUpgrades.max_level(u)
	var price := CarUpgrades.next_price(u)
	var accent: Color = TAB_ACCENT[c["tab"]]
	var perk := CarUpgrades.is_perk(u)
	var now := CarUpgrades.effect_text(u, lv) if lv > 0 else ("not won yet" if perk else "not fitted")
	_set_card(c, u.display_name.to_upper(), "NOW: %s" % now.to_upper(), accent if lv > 0 else GREY)
	_set_pips(c, lv, top, accent, "LV %d / %d" % [lv, top])
	(c["note"] as Label).text = ("Next: %s.  " % CarUpgrades.effect_text(u, lv + 1) if price >= 0 else "") + u.blurb
	var main: Button = c["main"]
	if perk:   # won at the slot machine only (D-106)
		main.text = "MAXED" if price < 0 else "WIN AT SLOTS"
		main.disabled = true
		_paint(main, accent.darkened(0.5), false)
		return
	var accent_buy := ORANGE if u.currency == &"parts" else accent
	main.text = ("UPGRADE  %s" % CarUpgrades.price_text(u, price)) if price >= 0 else "MAXED"
	main.disabled = price < 0
	_paint(main, accent_buy if CarUpgrades.wallet(u) >= price else accent_buy.darkened(0.5), price >= 0)


## The slot machine card (D-106): opens the machine itself (SlotMachineScreen, D-107).
func _refresh_slots() -> void:
	var c: Dictionary = _cards[SLOTS]
	var t := GameState.tickets
	_set_card(c, "LUCKY CAB SLOT MACHINE", "TICKETS  %d  ·  ONE SPIN EACH  ·  BEAT A BOSS FOR MORE" % t, VIOLET if t > 0 else GREY)
	_set_pips(c, mini(t, 6), 6, VIOLET, "%d TICKET%s" % [t, "" if t == 1 else "S"])
	var note: Label = c["note"]
	if not _prize.is_empty():
		note.text = "LAST WIN: %s" % _prize["text"]
	else:
		note.text = "The only place to get perks. Every spin wins: a perk, or +5 Damage / Fire rate on your best two guns."
	var main: Button = c["main"]
	main.text = "PLAY THE SLOTS"
	main.disabled = false
	_paint(main, VIOLET if t > 0 else VIOLET.darkened(0.5), true)
	(c["icon"] as Control).queue_redraw()


## Opens the slot machine (the SLOTS card's button).
func open_slots() -> void:
	_machine.open()


## One spin without the machine on screen (tests). True if it paid out.
func spin() -> bool:
	var prize := SlotMachine.spin(get_tree(), _slot_rng)
	if prize.has("error"):
		_say(prize["error"], RED)
		return false
	_on_slots_finished(prize)
	return true


func _on_slots_finished(prize: Dictionary) -> void:
	if prize.is_empty() or prize.has("error"):
		return
	_prize = prize
	var s: String = prize.get("symbol", "7")
	_reels = [s, s, s]
	_say("WON: %s" % prize.get("text", ""), VIOLET)
	_refresh()


func _refresh_cans() -> void:
	var c: Dictionary = _cards[CANS]
	var cap := CarUpgrades.can_capacity()
	var room := cap - GameState.cans
	var m := CarUpgrades.can_mult()
	_set_card(c, "MONSTROUS ENERGY CAN", "CARRYING %d / %d  ·  DRINK WITH %s" % [GameState.cans, cap, CanHolder.key_name()], CYAN)
	_set_pips(c, GameState.cans, cap, CYAN, "%d / %d" % [GameState.cans, cap])
	(c["note"] as Label).text = "Each can heals %d driver and %d cab. The can that keeps cabbies alive." % [
			roundi(CarUpgrades.CAN_DRIVER_HEAL * m), roundi(CarUpgrades.CAN_BODY_HEAL * m)]
	var main: Button = c["main"]
	main.text = "BUY 1  $%d" % CarUpgrades.CAN_PRICE if room > 0 else "HOLDERS FULL"
	main.disabled = room <= 0
	_paint(main, CYAN if GameState.cash >= CarUpgrades.CAN_PRICE else CYAN.darkened(0.5), room > 0)
	var alt: Button = c["alt"]
	alt.visible = true
	alt.text = "FILL UP (%d)  $%d" % [room, room * CarUpgrades.CAN_PRICE] if room > 1 else "FILL UP"
	alt.disabled = room <= 1
	_icon_state[CANS] = {"count": GameState.cans}
	(c["icon"] as Control).queue_redraw()


func _set_card(c: Dictionary, title: String, state: String, accent: Color) -> void:
	(c["title"] as Label).text = title
	var s: Label = c["state"]
	s.text = state
	s.add_theme_color_override("font_color", accent)
	(c["style"] as StyleBoxFlat).border_color = accent


func _set_pips(c: Dictionary, value: int, top: int, col: Color, text: String) -> void:
	var p: Control = c["pips"]
	p.set_meta(&"value", value)
	p.set_meta(&"max", top)
	p.set_meta(&"col", col)
	p.custom_minimum_size.x = clampf(top * 22.0, 44.0, 130.0)
	p.queue_redraw()
	(c["level"] as Label).text = text


## Solid accent fill for the button that spends money; plain theme otherwise.
func _paint(b: Button, col: Color, solid: bool) -> void:
	for s in ["normal", "hover", "pressed", "focus"]:
		b.remove_theme_stylebox_override(s)
	for s in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.remove_theme_color_override(s)
	if not solid or b.disabled:
		return
	b.add_theme_stylebox_override("normal", _box(col.darkened(0.12), 7))
	b.add_theme_stylebox_override("hover", _box(col.lightened(0.12), 7, Color.WHITE, 2))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), 7, Color.WHITE, 2, false))
	b.add_theme_stylebox_override("pressed", _box(col.darkened(0.35), 7))
	for s in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(s, INK)


func _focus_first() -> void:
	var page: Control = _pages[tab]
	for b in page.find_children("*", "Button", true, false):
		if b is Button and not (b as Button).disabled and (b as Button).is_visible_in_tree():
			(b as Button).grab_focus()
			return
	(_tab_buttons[tab] as Button).grab_focus()


# --- Build -----------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 34
	_panel.offset_right = -34
	_panel.offset_top = 14
	_panel.offset_bottom = -14
	_panel_pos = Vector2(34, 14)
	_panel_style = _box(Color(0.05, 0.05, 0.07, 0.97), 14, YELLOW, 0)
	_panel_style.border_width_top = 5
	_panel_style.shadow_color = Color(0, 0, 0, 0.5)
	_panel_style.shadow_size = 18
	_panel_style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	col.add_child(_build_header())
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(pages)
	for t in active_tabs():
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 8)
		scroll.add_child(grid)
		pages.add_child(scroll)
		_pages[t] = scroll
		match t:
			&"guns":
				for w in WeaponController.catalogue():
					grid.add_child(_card(w.id, t, true))
			&"energy":
				grid.add_child(_card(CANS, t, true))
			&"perks":
				grid.add_child(_card(SLOTS, t, false))
		if t != &"guns":
			for u in CarUpgrades.catalogue():
				if tab_of(u) == t:
					grid.add_child(_card(u.id, t, false))

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	_note = Label.new()
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 16)
	_note.add_theme_font_override("font", _bold)
	foot.add_child(_note)
	var hint := Label.new()
	hint.text = "Q / E  or  LB / RB   switch tabs"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", GREY)
	foot.add_child(hint)
	var leave := _button("CLOSE   [Tab / Esc]", close)
	leave.custom_minimum_size = Vector2(210, 38)
	foot.add_child(leave)


func _build_header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	head.add_child(titles)
	var title := Label.new()
	title.text = "SHOP"
	title.add_theme_font_override("font", _bold)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", YELLOW)
	titles.add_child(title)
	var sub := Label.new()
	sub.text = "anywhere, any time"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", GREY)
	titles.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.x = 14
	head.add_child(gap)
	_build_tabs(head)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	# Health over the spare parts / slot tickets (D-106), one narrow column.
	var status := VBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 0)
	head.add_child(status)
	_health = Label.new()
	_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_health.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health.add_theme_font_size_override("font_size", 13)
	_health.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	status.add_child(_health)
	_wallet = Label.new()
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet.add_theme_font_override("font", _bold)
	_wallet.add_theme_font_size_override("font_size", 13)
	_wallet.add_theme_color_override("font_color", ORANGE)
	status.add_child(_wallet)
	_repair = _button("REPAIR", func() -> void: activate(REPAIR))
	_repair.custom_minimum_size = Vector2(170, 44)
	_repair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_repair)
	var cash_box := PanelContainer.new()
	var cs := _box(Color(1, 0.82, 0.1, 0.1), 10, Color(1, 0.82, 0.1, 0.5), 1)
	cs.content_margin_left = 16
	cs.content_margin_right = 16
	cash_box.add_theme_stylebox_override("panel", cs)
	cash_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cash_box)
	_cash = Label.new()
	_cash.add_theme_font_override("font", _bold)
	_cash.add_theme_font_size_override("font_size", 32)
	_cash.add_theme_color_override("font_color", YELLOW)
	cash_box.add_child(_cash)
	return head


func _build_tabs(row: HBoxContainer) -> void:
	var group := ButtonGroup.new()
	for t in active_tabs():
		var accent: Color = TAB_ACCENT[t]
		var b := Button.new()
		b.text = "  %s  " % TAB_TITLE[t]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_override("font", _bold)
		b.add_theme_font_size_override("font_size", 17)
		var idle := _box(Color(1, 1, 1, 0.04), 8)
		var on := _box(Color(accent, 0.16), 8, accent, 0)
		on.border_width_bottom = 3
		b.add_theme_stylebox_override("normal", idle)
		b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.1), 8))
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", accent)
		b.add_theme_color_override("font_hover_pressed_color", accent.lightened(0.2))
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		b.pressed.connect(func() -> void: show_tab(t))
		b.mouse_entered.connect(b.grab_focus)
		row.add_child(b)
		_tab_buttons[t] = b


## One card: icon on the left, name / state / level / note in the middle, its buttons on
## the right. `extra` adds the two small buttons (guns: AMMO + EQUIP, cans: FILL UP).
func _card(id: StringName, page: StringName, extra: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = CARD_H
	var style := _box(CARD_BG, 10, GREY, 0)
	style.border_width_left = 4
	style.set_content_margin_all(8)
	style.content_margin_left = 12
	panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(ICON_W, 0)
	icon.draw.connect(func() -> void: _draw_icon(icon, id, page))
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)
	var title := Label.new()
	title.add_theme_font_override("font", _bold)
	title.add_theme_font_size_override("font_size", 19)
	info.add_child(title)
	var state := Label.new()
	state.add_theme_font_size_override("font_size", 12)
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state.custom_minimum_size.x = 200
	info.add_child(state)
	var lvrow := HBoxContainer.new()
	lvrow.add_theme_constant_override("separation", 8)
	info.add_child(lvrow)
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(88, 12)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.draw.connect(func() -> void: _draw_pips(pips))
	lvrow.add_child(pips)
	var level := Label.new()
	level.add_theme_font_size_override("font_size", 12)
	level.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	lvrow.add_child(level)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.max_lines_visible = 2
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.custom_minimum_size.x = 220
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	info.add_child(note)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size.x = BUTTONS_W
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 4)
	row.add_child(buttons)
	var main := _button("", _main_action(id, page))
	main.custom_minimum_size.y = 36
	main.add_theme_font_override("font", _bold)
	buttons.add_child(main)
	var alt: Button = null
	var alt2: Button = null
	if extra:
		var small := HBoxContainer.new()
		small.add_theme_constant_override("separation", 4)
		buttons.add_child(small)
		if page == &"guns":
			alt = _button("EQUIP", func() -> void: gun_action(id, &"equip"))
			alt.custom_minimum_size.y = 30
			alt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			alt.add_theme_font_size_override("font_size", 12)
			small.add_child(alt)
		else:
			alt = _button("FILL UP", func() -> void:
				_result(CANS, CarUpgrades.buy_cans(99), "Cup holders full."))
			alt.custom_minimum_size.y = 30
			alt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			alt.add_theme_font_size_override("font_size", 13)
			small.add_child(alt)
	# Guns: the four upgrade tracks along the bottom of the card (D-093).
	var tracks := {}
	if page == &"guns":
		var track_row := HBoxContainer.new()
		track_row.add_theme_constant_override("separation", 5)
		stack.add_child(track_row)
		for t: StringName in WeaponUpgrades.tracks_for(WeaponController._base(id)):
			var b := _button("", func() -> void: gun_action(id, t))
			b.custom_minimum_size.y = 40
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 12)
			b.clip_text = true
			track_row.add_child(b)
			tracks[t] = b
	# The card lights up while one of its buttons has focus (mouse hover or pad).
	var focusable: Array = [main, alt, alt2]
	focusable.append_array(tracks.values())
	for b in focusable:
		if b != null:
			(b as Button).focus_entered.connect(func() -> void: style.bg_color = CARD_BG_FOCUS)
			(b as Button).focus_exited.connect(func() -> void: style.bg_color = CARD_BG)
	_cards[id] = {"card": panel, "style": style, "icon": icon, "title": title, "state": state, "pips": pips,
			"level": level, "note": note, "main": main, "alt": alt, "alt2": alt2, "tab": page, "tracks": tracks}
	return panel


func _main_action(id: StringName, page: StringName) -> Callable:
	if page == &"guns":
		return func() -> void: gun_action(id, &"main")
	return func() -> void: activate(id)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _box(Color(0.17, 0.17, 0.21), 7, Color(1, 1, 1, 0.08), 1))
	t.set_stylebox("hover", "Button", _box(Color(0.25, 0.25, 0.31), 7, Color(1, 1, 1, 0.3), 1))
	t.set_stylebox("pressed", "Button", _box(Color(0.32, 0.32, 0.38), 7))
	t.set_stylebox("disabled", "Button", _box(Color(0.11, 0.11, 0.13), 7, Color(1, 1, 1, 0.04), 1))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 7, YELLOW, 2, false))
	t.set_color("font_color", "Button", Color(0.92, 0.92, 0.96))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.28))
	t.set_font_size("font_size", "Button", 15)
	var grab := _box(Color(1, 1, 1, 0.25), 4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(Color(1, 1, 1, 0.45), 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(YELLOW, 4))
	var lane := _box(Color(1, 1, 1, 0.04), 4)
	lane.content_margin_left = 4
	lane.content_margin_right = 4
	t.set_stylebox("scroll", "VScrollBar", lane)
	return t


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 38
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(action)
	return b


static func _box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		center: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.draw_center = center
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.anti_aliasing = true
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


# --- Drawing ---------------------------------------------------------------------------

func _draw_pips(p: Control) -> void:
	var top := int(p.get_meta(&"max", 0))
	if top <= 0:
		return
	var value := int(p.get_meta(&"value", 0))
	var col: Color = p.get_meta(&"col", YELLOW)
	var gap := 3.0
	var w := (p.size.x - gap * (top - 1)) / top
	for i in top:
		var x := i * (w + gap)
		var poly := PackedVector2Array([Vector2(x, p.size.y), Vector2(x + w - 4, p.size.y), Vector2(x + w, 0), Vector2(x + 4, 0)])
		p.draw_colored_polygon(poly, col if i < value else Color(1, 1, 1, 0.1))


func _draw_icon(ci: Control, id: StringName, page: StringName) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	ci.draw_style_box(_box(Color(1, 1, 1, 0.035), 8), r)
	var inner := r.grow(-10)
	if page == &"guns":
		var st: Dictionary = _icon_state.get(id, {})
		WeaponBar.draw_gun(ci, id, inner, st.get("col", Color.WHITE))
		var badge := int(st.get("badge", 0))
		if badge > 0:
			ci.draw_circle(Vector2(16, 16), 11, GREEN)
			_draw_text(ci, str(badge), Vector2(16, 21), 14, INK)
		if st.get("locked", false):
			_draw_text(ci, "LOCKED", Vector2(r.size.x * 0.5, r.size.y - 8), 11, Color(1, 1, 1, 0.55))
		return
	if id == SLOTS:
		_draw_reels(ci, inner)
		return
	var accent: Color = TAB_ACCENT[page]
	var u := CarUpgrades.get_upgrade(id)
	var kind := &"can" if u == null else u.stat
	var lit := u == null or CarUpgrades.level(id) > 0
	_draw_symbol(ci, kind, inner.get_center(), minf(inner.size.x, inner.size.y) / 100.0,
			accent if lit else accent.lerp(Color(0.5, 0.5, 0.55), 0.6))
	if id == CANS:
		_draw_text(ci, "x%d" % int(_icon_state.get(CANS, {}).get("count", 0)), Vector2(r.size.x - 18, r.size.y - 8), 15, Color.WHITE)


## The slot machine's three reels (D-106).
func _draw_reels(ci: CanvasItem, r: Rect2) -> void:
	var w := (r.size.x - 8.0) / 3.0
	var h := minf(r.size.y, 54.0)
	var y := r.position.y + (r.size.y - h) * 0.5
	var won := not _prize.is_empty()
	for i in 3:
		var cell := Rect2(r.position.x + i * (w + 4.0), y, w, h)
		ci.draw_style_box(_box(Color(0.95, 0.93, 0.88), 5, VIOLET if won else Color(0, 0, 0, 0.5), 2), cell)
		var s: String = _reels[i]
		var size := 20 if s.length() <= 2 else (12 if s.length() == 3 else 10)
		_draw_text(ci, s, cell.get_center() + Vector2(0, size * 0.35), size, VIOLET.darkened(0.35) if s != "7" else RED)


## Simple vector symbols for the cab / energy cards, centred on `c`, ~100 units across x `s`.
func _draw_symbol(ci: CanvasItem, kind: StringName, c: Vector2, s: float, col: Color) -> void:
	var pts := func(arr: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for v: Vector2 in arr:
			out.append(c + v * s)
		return out
	var dark := col.darkened(0.55)
	match kind:
		&"armor":
			ci.draw_colored_polygon(pts.call([Vector2(-34, -38), Vector2(34, -38), Vector2(34, 2), Vector2(0, 42), Vector2(-34, 2)]), col)
			ci.draw_colored_polygon(pts.call([Vector2(-22, -27), Vector2(22, -27), Vector2(22, -1), Vector2(0, 26), Vector2(-22, -1)]), dark)
			for v: Vector2 in [Vector2(-27, -32), Vector2(27, -32), Vector2(-27, -2), Vector2(27, -2)]:
				ci.draw_circle(c + v * s, 3.0 * s, col.lightened(0.4))
		&"engine":
			ci.draw_colored_polygon(pts.call([Vector2(-4, -44), Vector2(24, -44), Vector2(6, -8), Vector2(26, -8),
					Vector2(-16, 44), Vector2(-4, 4), Vector2(-24, 4)]), col)
		&"glass":
			ci.draw_colored_polygon(pts.call([Vector2(-40, -26), Vector2(40, -26), Vector2(32, 26), Vector2(-32, 26)]), Color(col, 0.3))
			ci.draw_polyline(pts.call([Vector2(-40, -26), Vector2(40, -26), Vector2(32, 26), Vector2(-32, 26), Vector2(-40, -26)]), col, 3.0 * s, true)
			var hit := Vector2(10, -4)
			for v: Vector2 in [Vector2(-16, -14), Vector2(22, -18), Vector2(26, 10), Vector2(-6, 20)]:
				ci.draw_line(c + hit * s, c + (hit + v) * s, col.lightened(0.3), 2.0 * s, true)
			ci.draw_circle(c + hit * s, 4.0 * s, col.lightened(0.5))
		&"ram":
			ci.draw_rect(Rect2(c + Vector2(-44, -14) * s, Vector2(88, 16) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-30, 2) * s, Vector2(10, 26) * s), dark.lightened(0.2))
			ci.draw_rect(Rect2(c + Vector2(20, 2) * s, Vector2(10, 26) * s), dark.lightened(0.2))
			for x in [-34.0, -12.0, 12.0, 34.0]:
				ci.draw_circle(c + Vector2(x, -6) * s, 3.0 * s, col.lightened(0.5))
		&"nitro":
			ci.draw_rect(Rect2(c + Vector2(-8, -22) * s, Vector2(30, 60) * s), col)
			ci.draw_rect(Rect2(c + Vector2(1, -32) * s, Vector2(12, 10) * s), dark.lightened(0.3))
			ci.draw_rect(Rect2(c + Vector2(-6, -38) * s, Vector2(26, 6) * s), col.lightened(0.3))
			ci.draw_rect(Rect2(c + Vector2(-8, -2) * s, Vector2(30, 8) * s), dark)
			for i in 3:
				var y := -10.0 + i * 14.0
				ci.draw_line(c + Vector2(-44 + i * 4, y) * s, c + Vector2(-16, y) * s, Color(col, 0.7), 3.0 * s, true)
		&"can_holder":
			_draw_can(ci, c + Vector2(-17, 4) * s, s * 0.78, col)
			_draw_can(ci, c + Vector2(17, 4) * s, s * 0.78, col)
		&"can_size":
			_draw_can(ci, c, s * 1.1, col)
			_draw_text(ci, "XL", c + Vector2(30, 40) * s, 16, Color.WHITE)
		&"double_tap":   # two rounds side by side (D-100)
			for x in [-16.0, 16.0]:
				ci.draw_rect(Rect2(c + Vector2(x - 9, -14) * s, Vector2(18, 48) * s), col)
				ci.draw_colored_polygon(pts.call([Vector2(x - 9, -14), Vector2(x + 9, -14), Vector2(x, -40)]), col.lightened(0.35))
				ci.draw_rect(Rect2(c + Vector2(x - 11, 28) * s, Vector2(22, 8) * s), dark.lightened(0.2))
		&"fast_reload":  # a magazine and a circular arrow
			ci.draw_rect(Rect2(c + Vector2(-30, -30) * s, Vector2(24, 62) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-26, -26) * s, Vector2(16, 10) * s), dark)
			ci.draw_arc(c + Vector2(18, 0) * s, 22.0 * s, -PI * 0.9, PI * 0.6, 16, col.lightened(0.3), 6.0 * s, true)
			ci.draw_colored_polygon(pts.call([Vector2(4, 22), Vector2(22, 30), Vector2(6, 38)]), col.lightened(0.3))
		&"max_hp":  # Juggernaut: a big cross (D-107)
			ci.draw_rect(Rect2(c + Vector2(-12, -38) * s, Vector2(24, 76) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-38, -12) * s, Vector2(76, 24) * s), col)
		&"lifesteal":  # Road Vampire: two fangs and a drop
			ci.draw_colored_polygon(pts.call([Vector2(-30, -30), Vector2(-10, -30), Vector2(-20, 6)]), col.lightened(0.3))
			ci.draw_colored_polygon(pts.call([Vector2(10, -30), Vector2(30, -30), Vector2(20, 6)]), col.lightened(0.3))
			ci.draw_circle(c + Vector2(0, 26) * s, 12.0 * s, col)
			ci.draw_colored_polygon(pts.call([Vector2(-10, 20), Vector2(10, 20), Vector2(0, 2)]), col)
		&"ammo_cap":  # Deep Pockets: a crate of rounds
			ci.draw_rect(Rect2(c + Vector2(-38, -6) * s, Vector2(76, 40) * s), col.darkened(0.2))
			for i in 4:
				var x := -27.0 + i * 18.0
				ci.draw_rect(Rect2(c + Vector2(x - 5, -30) * s, Vector2(10, 26) * s), col.lightened(0.3))
				ci.draw_colored_polygon(pts.call([Vector2(x - 5, -30), Vector2(x + 5, -30), Vector2(x, -40)]), col.lightened(0.5))
		&"guardian_angel":  # a halo over wings
			ci.draw_arc(c + Vector2(0, -28) * s, 16.0 * s, 0.0, TAU, 20, col.lightened(0.4), 4.0 * s, true)
			for side in [-1.0, 1.0]:
				ci.draw_colored_polygon(pts.call([Vector2(4 * side, 0), Vector2(42 * side, -16), Vector2(36 * side, 8),
						Vector2(26 * side, 26), Vector2(4 * side, 18)]), col)
		&"rolling_pickup":  # a fare in a ring, with speed lines
			ci.draw_arc(c, 40.0 * s, 0.0, TAU, 28, col, 4.0 * s, true)
			ci.draw_circle(c + Vector2(0, -16) * s, 9.0 * s, col.lightened(0.3))
			ci.draw_rect(Rect2(c + Vector2(-9, -5) * s, Vector2(18, 30) * s), col.lightened(0.3))
			for i in 3:
				var y := -12.0 + i * 12.0
				ci.draw_line(c + Vector2(-34, y) * s, c + Vector2(-16, y) * s, Color(col, 0.8), 3.0 * s, true)
		_:
			_draw_can(ci, c, s, col)


## A Monstrous Energy can: body, rims, three claw marks.
func _draw_can(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-19, -36) * s, Vector2(38, 72) * s), Color(0.12, 0.13, 0.15))
	ci.draw_rect(Rect2(c + Vector2(-19, -36) * s, Vector2(38, 6) * s), Color(0.75, 0.77, 0.8))
	ci.draw_rect(Rect2(c + Vector2(-19, 30) * s, Vector2(38, 6) * s), Color(0.75, 0.77, 0.8))
	for i in 3:
		var x := -9.0 + i * 9.0
		ci.draw_line(c + Vector2(x + 3, -20) * s, c + Vector2(x - 3, 20) * s, col, 4.0 * s, true)


func _draw_text(ci: CanvasItem, s: String, centre_baseline: Vector2, font_size: int, col: Color) -> void:
	var tw := _bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string(_bold, centre_baseline - Vector2(tw * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


# --- Helpers ---------------------------------------------------------------------------

func _gun_ui() -> GunShopUI:
	if _guns_ui == null:
		_guns_ui = get_tree().get_first_node_in_group(&"gun_shop_ui") as GunShopUI
		if _guns_ui != null:
			_guns_ui.said.connect(_say)
	return _guns_ui


func _controller() -> WeaponController:
	return get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController


func _damage() -> TaxiDamage:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node
	return taxi.get_node_or_null("TaxiDamage") as TaxiDamage if taxi != null else null


## The lot a gun shop / repair garage stood on, with the shop gone (City, while `enabled`):
## the same building block on the back half so the map's solid cells still match, no sign,
## no pad, nothing to interact with.
static func build_closed_lot(map: MapData, p: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "closed_%s_%d_%d" % [p["type"], p["x"], p["z"]]
	root.position = map.piece_center(p)
	root.rotation.y = MapBuilder.yaw_of(int(p["rot"]))
	var size := MapBuilder.local_size(p)
	var h := float(p["h"])
	Blockout.add_box(root, Vector3(0, MapBuilder.CURB * 0.5, size.y * 0.25), Vector3(size.x, MapBuilder.CURB, size.y * 0.5),
			MapBuilder.mat("sidewalk"))
	Blockout.add_box(root, Vector3(0, MapBuilder.CURB + h * 0.5, size.y * 0.25), Vector3(size.x - 2.0, h, size.y * 0.5 - 2.0),
			MapBuilder.mat("building_c"))
	return root
