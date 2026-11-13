extends Control
## Blockout "photo" for the passenger file: shoulders in the profile colour, a head with
## features varied by the passenger's name (hair colour/style, glasses, moustache).

var passenger: PassengerInstance

const HAIR := [Color(0.1, 0.08, 0.06), Color(0.45, 0.3, 0.15), Color(0.8, 0.65, 0.3), Color(0.6, 0.6, 0.6), Color(0.55, 0.15, 0.1)]
const SKIN := [Color(0.95, 0.8, 0.65), Color(0.85, 0.65, 0.5), Color(0.6, 0.42, 0.3), Color(0.4, 0.28, 0.2)]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.8))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.2, 0.2), false, 3.0)
	if passenger == null:
		return
	var h := hash(passenger.display_name)
	var skin: Color = SKIN[absi(h) % SKIN.size()]
	var hair: Color = HAIR[absi(h >> 3) % HAIR.size()]
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	# Shoulders.
	draw_rect(Rect2(Vector2(size.x * 0.12, size.y * 0.72), Vector2(size.x * 0.76, size.y * 0.28)), passenger.profile.color)
	draw_rect(Rect2(Vector2(c.x - 10, size.y * 0.62), Vector2(20, size.y * 0.12)), skin)
	# Head + hair.
	if (h >> 5) % 3 != 0:
		draw_circle(c + Vector2(0, -12), 40.0, hair)
	draw_circle(c, 36.0, skin)
	# Eyes, glasses, mouth, moustache.
	for side: float in [-1.0, 1.0]:
		draw_circle(c + Vector2(side * 13, -6), 3.5, Color(0.1, 0.1, 0.1))
		if (h >> 7) % 4 == 0:
			draw_arc(c + Vector2(side * 13, -6), 9.0, 0.0, TAU, 12, Color(0.1, 0.1, 0.1), 2.0)
	draw_line(c + Vector2(-10, 16), c + Vector2(10, 16), Color(0.35, 0.12, 0.1), 3.0)
	if (h >> 9) % 3 == 0:
		draw_rect(Rect2(c + Vector2(-12, 7), Vector2(24, 5)), hair)
	# Mugshot height lines.
	for i in 4:
		var y := 12.0 + i * 14.0
		draw_line(Vector2(size.x - 18, y), Vector2(size.x - 6, y), Color(0.3, 0.3, 0.3), 1.0)
