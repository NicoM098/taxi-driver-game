extends Node
## Headless gun-shop test through Main on the built-in city (it has two gun shops):
##  - a run starts with the revolver only; the hotbar knows all four weapons
##  - park on a shop pad -> nothing until interact (E) -> the shop opens and pauses the world
##  - the SMG is locked below its fares (D-085); then buy it -> owned, equipped, cash down;
##    the rifle stays locked whatever the cash
##  - upgrade the SMG: refused without cash or for a gun you do not own; Mk II for its price
##  - empty the SMG reserve -> refill ammo -> full, cash down; already full -> refused
##  - leave -> world unpaused; the shop does not reopen until the taxi left the pad
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/shop_autotest.tscn
## (-- --shot-dir=<dir> windowed: screenshot of the open shop and of the hotbar)

const MAIN := preload("res://src/main/main.tscn")

var _taxi: Taxi
var _city: City
var _ui: GunShopUI
var _wc: WeaponController
var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _errors: PackedStringArray = []
var _shot_dir: String = ""


func _ready() -> void:
	ShopMenu.enabled = false   # shops in the city (D-089 keeps them, switched off)
	MapData.use_builtin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset_run()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	add_child(MAIN.instantiate())


func _physics_process(delta: float) -> void:
	_release_tap()
	_t += delta
	_step_t += delta
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_city = get_tree().get_first_node_in_group(&"city") as City
		_ui = get_tree().get_first_node_in_group(&"gun_shop_ui") as GunShopUI
		_wc = get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
		return
	if _t > 40.0:
		_fail("timeout at step %d" % _step)
		return
	match _step:
		0:
			if _step_t > 1.5:
				var owned := _wc.weapons.map(func(w: WeaponData) -> StringName: return w.id)
				print("[ShopTest] start: owned %s, catalogue %d weapons, %d gun shops" % [owned, WeaponController.catalogue().size(), _city.gun_shops.size()])
				if owned != [&"revolver"]:
					_errors.append("a run should start with the revolver only")
				if WeaponController.catalogue().size() != 8:
					_errors.append("expected 8 weapons in data/weapons")
				if _city.gun_shops.is_empty():
					_fail("the built-in city has no gun shop")
					return
				GameState.cash = 520
				var shop := _city.gun_shops[0]
				_taxi.teleport(Transform3D(Basis.IDENTITY, shop.pad_position + Vector3(0, 1.0, 0)))
				_next()
		1:
			# Parking alone does nothing: the shop waits for interact (E).
			if _step_t > 1.5 and _step_t - delta <= 1.5:
				if _ui.is_open:
					_errors.append("the shop opened without pressing interact")
				_tap_interact()
			if _ui.is_open:
				print("[ShopTest] shop opened after %.1f s on the pad, paused=%s" % [_step_t, get_tree().paused])
				if not get_tree().paused:
					_errors.append("world not paused in the shop")
				if not _shot_dir.is_empty():
					_shot("shop.png")
				_next()
			elif _step_t > 5.0:
				_fail("pressing interact on the pad did not open the shop")
		2:
			# Locked until enough fares are delivered (D-085), whatever the cash.
			var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
			var smg_data := load("res://data/weapons/smg.tres") as WeaponData
			shift.rides_completed = smg_data.unlock_rides - 1
			if _ui.buy(&"smg"):
				_errors.append("bought the SMG with %d fares (needs %d)" % [shift.rides_completed, smg_data.unlock_rides])
			shift.rides_completed = smg_data.unlock_rides
			var cash0 := GameState.cash
			if not _ui.buy(&"smg"):
				_errors.append("could not buy the SMG with $%d and %d fares" % [cash0, shift.rides_completed])
			print("[ShopTest] bought SMG: cash %d -> %d, equipped %s" % [cash0, GameState.cash, _wc.current_weapon().id])
			if GameState.cash != cash0 - smg_data.price or not _wc.owns(&"smg") or _wc.current_weapon().id != &"smg":
				_errors.append("SMG purchase wrong")
			if not GameState.owned_weapons.has(&"smg"):
				_errors.append("GameState.owned_weapons not updated")
			GameState.cash = 5000
			if _ui.buy(&"rifle"):
				_errors.append("bought the rifle with %d fares (locked)" % shift.rides_completed)
			GameState.cash = 100
			if _ui.buy(&"smg"):
				_errors.append("bought the SMG twice")
			_wc.ammo[&"smg"]["reserve"] = 0
			_wc.ammo[&"smg"]["mag"] = 3
			GameState.cash = 100
			if not _ui.refill(&"smg"):
				_errors.append("refill refused")
			var a := _wc.get_ammo(_wc.weapons[_wc.index_of_slot(2)])
			print("[ShopTest] refill: ammo %d | %d, cash %d" % [a["mag"], a["reserve"], GameState.cash])
			if a["reserve"] != 120 or a["mag"] != 30 or GameState.cash != 65:
				_errors.append("refill wrong")
			if _ui.refill(&"smg"):
				_errors.append("refilled a full weapon")
			# Upgrades (D-085): refused without the cash, then Mk II for its price.
			if _ui.upgrade(&"smg"):
				_errors.append("upgraded the SMG with only $%d" % GameState.cash)
			if _ui.upgrade(&"rifle"):
				_errors.append("upgraded a weapon that is not owned")
			GameState.cash = 1000
			var up_price := WeaponUpgrades.next_price(load("res://data/weapons/smg.tres") as WeaponData, 1)
			if not _ui.upgrade(&"smg") or GameState.weapon_level(&"smg") != 2 or GameState.cash != 1000 - up_price:
				_errors.append("SMG Mk II purchase wrong (level %d, cash %d)" % [GameState.weapon_level(&"smg"), GameState.cash])
			# Loadout (D-087): store the SMG here and take it back.
			if not _ui.toggle_equip(&"smg") or _wc.is_equipped(&"smg") or not _wc.owns(&"smg"):
				_errors.append("could not store the SMG at the shop")
			if not _ui.toggle_equip(&"smg") or not _wc.is_equipped(&"smg"):
				_errors.append("could not equip the SMG again")
			if _ui.toggle_equip(&"revolver") and _ui.toggle_equip(&"smg"):
				_errors.append("unequipped the last gun in the cab")
			_ui.toggle_equip(&"revolver")
			print("[ShopTest] upgraded SMG to %s for $%d, damage %.1f" % [
					WeaponUpgrades.level_name(GameState.weapon_level(&"smg")), up_price, _wc.get_weapon(&"smg").damage])
			if not _shot_dir.is_empty():
				_ui.close()
				_next()
				return
			_ui.close()
			_next()
		3:
			if not _shot_dir.is_empty() and _step_t > 0.3 and _step_t < 0.35:
				_shot("hotbar.png")
			if _step_t > 1.5:
				print("[ShopTest] closed: paused=%s, reopened=%s" % [get_tree().paused, _ui.is_open])
				if get_tree().paused:
					_errors.append("world still paused after leaving")
				if _ui.is_open:
					_errors.append("the shop reopened without leaving the pad")
				_finish()


func _shot(file: String) -> void:
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file))
	print("[ShopTest] screenshot ", file)


func _next() -> void:
	_step += 1
	_step_t = 0.0


func _fail(msg: String) -> void:
	_errors.append(msg)
	_finish()


func _finish() -> void:
	set_physics_process(false)
	get_tree().paused = false
	if _errors.is_empty():
		print("[ShopTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[ShopTest] FAIL: ", e)
		get_tree().quit(1)


## Presses interact for one physics frame. This node is the parent of Main, so it runs before
## the shops in the same frame and they see `is_action_just_pressed`.
var _release_interact: bool = false


func _tap_interact() -> void:
	Input.action_press(&"interact")
	_release_interact = true


func _release_tap() -> void:
	if _release_interact and not Input.is_action_just_pressed(&"interact"):
		Input.action_release(&"interact")
		_release_interact = false
