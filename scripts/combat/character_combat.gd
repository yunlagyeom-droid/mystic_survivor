extends Node

signal projectile_requested(projectile_scene: PackedScene, origin: Vector2, direction: Vector2, damage: int, params: Dictionary)
signal world_vfx_requested(vfx: Node2D)
signal status_changed(skill_1_text: String, skill_2_text: String, skill_3_text: String)

var player: Node


func setup(owner: Node) -> void:
	player = owner


func combat_process(_delta: float, _input_direction: Vector2) -> void:
	pass


func try_skill_1(_input_direction: Vector2) -> void:
	pass


func try_skill_2(_input_direction: Vector2) -> void:
	pass


func try_skill_3(_input_direction: Vector2) -> void:
	pass


func use_ultimate(_context: Dictionary) -> void:
	pass


func apply_upgrade(_upgrade_id: String) -> void:
	pass


func can_apply_upgrade(_upgrade_id: String) -> bool:
	return true


func get_upgrade_pool() -> Array[Dictionary]:
	return []


func get_status_texts() -> Array[String]:
	return ["", "", ""]


func modify_incoming_damage(amount: int) -> int:
	return amount


func find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance := INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue

		var distance := player.global_position.distance_squared_to(enemy_node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy_node

	return nearest_enemy


func apply_area_damage(world_position: Vector2, radius: float, damage: int, source := "skill") -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		if enemy_node.global_position.distance_to(world_position) > radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, source)


func make_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func make_world_vfx_group() -> Node2D:
	return Node2D.new()


func emit_world_vfx(vfx: Node2D, lifetime := 2.0) -> void:
	world_vfx_requested.emit(vfx)
	get_tree().create_timer(lifetime).timeout.connect(vfx.queue_free)
