class_name RideCard
extends PanelContainer
## The gang-rides mode's stand-in for the passenger file (D-088): a card at the top left that
## announces the fare in text when the ride starts (EventBus.ride_announced), then fades out.
## Native resolution: the HUD adds it to itself.

const SHOW_SECONDS := 6.5
const FADE_SECONDS := 0.8
const WIDTH := 470.0
## Under the health bars and clear of the centred HUD message line.
const TOP := 150.0

var _stripe: ColorRect
var _title: Label
var _body: RichTextLabel
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 18.0
	offset_top = TOP
	custom_minimum_size = Vector2(WIDTH, 0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.05, 0.78)
	bg.content_margin_left = 16
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 12
	add_theme_stylebox_override("panel", bg)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_stripe = ColorRect.new()
	_stripe.custom_minimum_size = Vector2(6, 0)
	_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_stripe)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 6)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(WIDTH - 50.0, 0)
	col.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	# A width up front: fit_content wraps at the current width, and 0 makes the card screen-tall.
	_body.custom_minimum_size = Vector2(WIDTH - 50.0, 0)
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_size_override("normal_font_size", 19)
	_body.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	col.add_child(_body)

	modulate.a = 0.0
	visible = false
	EventBus.ride_announced.connect(show_card)
	EventBus.ride_completed.connect(func(_r: RefCounted, _p: int) -> void: hide_card())
	EventBus.ride_failed.connect(func(_r: RefCounted, _reason: StringName) -> void: hide_card())


func show_card(title: String, lines: PackedStringArray, stripe: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", stripe.lightened(0.25))
	_stripe.color = stripe
	_body.text = "\n".join(lines)
	visible = true
	reset_size()
	size = Vector2(WIDTH, 0)
	if _tween != null:
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(func() -> void: visible = false)


func hide_card() -> void:
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	visible = false
