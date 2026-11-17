class_name Blast
extends RefCounted
## An explosion from the player's rockets and mines (D-086). Hurts every HealthComponent with a
## hitbox inside the radius once (full damage at the centre, EDGE_FACTOR at the edge), shoves the
## cars around, and announces itself on EventBus.explosion (camera shake, sound, panicking
## pedestrians). **Never hurts the player's own taxi.**

const HITBOXES := 1 << 5
## enemy_vehicles | traffic | props
const BODIES := (1 << 2) | (1 << 3) | (1 << 8)
const EDGE_FACTOR := 0.35
const PUSH := 9.0          # impulse per kg of the car's mass, at the centre


## Returns how many things it killed.
static func detonate(world: Node3D, pos: Vector3, radius: float, damage: float) -> int:
	if world == null or not world.is_inside_tree() or radius <= 0.0:
		return 0
	var tree := world.get_tree()
	var taxi := tree.get_first_node_in_group(&"player_vehicle") as Node
	var space := world.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, pos)

	# One hit per HealthComponent: a car has several hitboxes, and the driver's x2.5 head
	# multiplier must not turn a blast into a one-shot through the roof.
	query.collision_mask = HITBOXES
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var closest: Dictionary = {}    # HealthComponent -> [Hitbox, distance]
	for r in space.intersect_shape(query, 64):
		var box := r["collider"] as Hitbox
		if box == null or box.health == null or box.health.is_dead:
			continue
		if taxi != null and taxi.is_ancestor_of(box):
			continue
		var d := box.global_position.distance_to(pos)
		if not closest.has(box.health) or d < closest[box.health][1]:
			closest[box.health] = [box, d]
	var kills := 0
	for health: HealthComponent in closest:
		var box: Hitbox = closest[health][0]
		var t := clampf(float(closest[health][1]) / radius, 0.0, 1.0)
		var dealt := damage * lerpf(1.0, EDGE_FACTOR, t)
		if box.take_hit(dealt / maxf(box.damage_multiplier, 0.01), pos):
			kills += 1
	if not closest.is_empty():
		EventBus.hit_confirmed.emit(kills > 0)

	query.collision_mask = BODIES
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for r in space.intersect_shape(query, 32):
		var body := r["collider"] as RigidBody3D
		if body == null or body == taxi:
			continue
		var away := body.global_position - pos
		var t := clampf(away.length() / radius, 0.0, 1.0)
		var dir := (away.normalized() + Vector3.UP * 0.6).normalized()
		body.apply_central_impulse(dir * PUSH * body.mass * (1.0 - t * 0.7))

	CombatFx.explosion(world, pos)
	EventBus.explosion.emit(pos, clampf(radius / 5.0, 0.8, 1.8))
	return kills
