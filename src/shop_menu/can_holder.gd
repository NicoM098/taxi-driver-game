class_name CanHolder
extends Label
## The Monstrous Energy cans carried in the cab (D-089): a small line above the weapon bar
## ("MONSTROUS x2  [F] drink   ·   [Tab] shop") and the `drink` key (F / Y) that cracks one open.
## Child of ShopMenu, outside its hidden screen, so it shows while driving.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 18.0
	offset_top = -182.0
	offset_right = 520.0
	offset_bottom = -152.0
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 6)


func _process(_delta: float) -> void:
	var shop := "%s shop" % ("[Back]" if InputDevice.using_gamepad else "[Tab]")
	if GameState.cans > 0:
		text = "MONSTROUS x%d  %s drink    ·    %s" % [GameState.cans, key_name(), shop]
		add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	else:
		text = shop
		add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	visible = not get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not event.is_action_pressed(&"drink"):
		return
	var error := CarUpgrades.drink_can(get_tree())
	if error != "":
		EventBus.hud_message.emit(error, &"info")
	get_viewport().set_input_as_handled()


static func key_name() -> String:
	return "[Y]" if InputDevice.using_gamepad else "[F]"
