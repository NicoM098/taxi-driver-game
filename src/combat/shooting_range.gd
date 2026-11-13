extends Node3D
## Shooting range world (Phase 05 test): the driving test course + target boards along the
## runway and red target cars circling on the +X/+Z side. Switch to it in-game with F3.

const COURSE := preload("res://src/vehicle/test_drive.tscn")


func _ready() -> void:
	add_child(COURSE.instantiate())
	# Boards on both sides of the runway (taxi spawns at origin facing -Z).
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		_add_board(Vector3(side * 11.0, 0.0, -20.0 - i * 25.0))
	# A close group to practise on while standing still.
	for x: float in [-6.0, 0.0, 6.0]:
		_add_board(Vector3(x, 0.0, -14.0))
	# Moving cars.
	_add_car(Vector3(85, 0, 75), 22.0, 10.0, 0.0)
	_add_car(Vector3(85, 0, 75), 22.0, 10.0, PI)
	_add_car(Vector3(85, 0, 75), 14.0, -13.0, PI * 0.5)
	for p: Vector3 in [Vector3(0, 0, -60), Vector3(-20, 0, -130), Vector3(25, 0, 40)]:
		var can := EnergyDrinkPickup.new()
		can.position = p
		add_child(can)
	var director := EnemyDirector.new()
	director.name = "EnemyDirector"
	add_child(director)  # F7 spawns hitmen here too (direct chase, no road graph)


func _add_board(pos: Vector3) -> void:
	var target := ShootingTarget.new()
	target.position = pos
	add_child(target)


func _add_car(center: Vector3, radius: float, speed: float, angle: float) -> void:
	var car := TargetCar.new()
	car.center = center
	car.radius = radius
	car.speed = speed
	car.start_angle = angle
	add_child(car)
