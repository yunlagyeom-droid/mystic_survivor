extends Node

signal projectile_requested(projectile_scene: PackedScene, origin: Vector2, direction: Vector2, damage: int)
signal world_vfx_requested(vfx: Node2D)
signal status_changed(skill_1_text: String, skill_2_text: String)

var slash_damage := 24
var slash_range := 120.0
var slash_cooldown := 0.62
var slash_timer := 0.0
var dash_distance := 210.0
var dash_cooldown := 2.2
var dash_timer := 0.0
var dash_invulnerable_duration := 0.16
var guard_duration := 1.15
var guard_cooldown := 5.5
var guard_timer := 0.0
var guard_active_timer := 0.0
var guard_damage_scale := 0.35
var ultimate_damage := 95
var ultimate_radius := 520.0
var experiment_mode := false
var player: Node


func setup(owner: Node) -> void:
	player = owner
	_emit_status()


func combat_process(delta: float, _input_direction: Vector2) -> void:
	if experiment_mode:
		_reset_experiment_cooldowns()

	slash_timer = maxf(0.0, slash_timer - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	guard_timer = maxf(0.0, guard_timer - delta)
	guard_active_timer = maxf(0.0, guard_active_timer - delta)

	if guard_active_timer > 0.0:
		player.set_combat_modulate(Color(1.25, 0.72, 0.72))
	else:
		player.clear_combat_modulate()

	if slash_timer <= 0.0:
		_try_slash()

	_emit_status()


func try_skill_1(input_direction: Vector2) -> void:
	if dash_timer > 0.0 and not experiment_mode:
		return

	var dash_direction := input_direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = player.last_direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.DOWN

	var start_position: Vector2 = player.global_position
	var target_position: Vector2 = player.global_position + dash_direction * dash_distance
	target_position.x = clampf(target_position.x, -player.world_radius, player.world_radius)
	target_position.y = clampf(target_position.y, -player.world_radius, player.world_radius)

	player.global_position = target_position
	player.velocity = Vector2.ZERO
	player.last_direction = dash_direction
	player.set_invulnerable(dash_invulnerable_duration)
	player.update_walk_animation(dash_direction, dash_distance)
	dash_timer = 0.0 if experiment_mode else dash_cooldown
	_spawn_dash_vfx(start_position, target_position)
	_emit_status()


func try_skill_2(_input_direction: Vector2) -> void:
	if guard_timer > 0.0 and not experiment_mode:
		return

	guard_timer = 0.0 if experiment_mode else guard_cooldown
	guard_active_timer = guard_duration
	_spawn_guard_vfx()
	_emit_status()


func set_experiment_mode(enabled: bool) -> void:
	experiment_mode = enabled
	if experiment_mode:
		_reset_experiment_cooldowns()
	_emit_status()


func _reset_experiment_cooldowns() -> void:
	slash_timer = 0.0
	dash_timer = 0.0
	guard_timer = 0.0


func use_ultimate(context: Dictionary) -> void:
	var center: Vector2 = context.get("origin", player.global_position)
	apply_area_damage(center, ultimate_radius, ultimate_damage, "ultimate")
	_spawn_ultimate_vfx(center)


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"hunter_slash_damage":
			slash_damage += 8
		"hunter_slash_speed":
			slash_cooldown = maxf(0.24, slash_cooldown * 0.84)
		"hunter_dash_distance":
			dash_distance += 55.0
		"hunter_guard_duration":
			guard_duration += 0.35
		"hunter_ultimate_damage":
			ultimate_damage += 35
	_emit_status()


func can_apply_upgrade(_upgrade_id: String) -> bool:
	return true


func get_upgrade_pool() -> Array[Dictionary]:
	return [
		{
			"id": "hunter_slash_damage",
			"label": "검격 강화",
			"description": "베기 피해 +8",
			"rarity": "Common",
			"category": "character",
			"character_id": "hunter",
			"skill_id": "slash",
		},
		{
			"id": "hunter_slash_speed",
			"label": "연속 베기",
			"description": "베기 재사용 대기시간 -16%",
			"rarity": "Common",
			"category": "character",
			"character_id": "hunter",
			"skill_id": "slash",
		},
		{
			"id": "hunter_dash_distance",
			"label": "그림자 보폭",
			"description": "대시 이동 거리 +55",
			"rarity": "Rare",
			"category": "character",
			"character_id": "hunter",
			"skill_id": "dash",
		},
		{
			"id": "hunter_guard_duration",
			"label": "집중 방어",
			"description": "방어 지속 시간 +0.35초",
			"rarity": "Rare",
			"category": "character",
			"character_id": "hunter",
			"skill_id": "guard",
		},
		{
			"id": "hunter_ultimate_damage",
			"label": "처형식 강화",
			"description": "궁극기 피해 +35",
			"rarity": "Epic",
			"category": "character",
			"character_id": "hunter",
			"skill_id": "ultimate",
		},
	]


func get_status_texts() -> Array[String]:
	var dash_text := "대시 준비" if dash_timer <= 0.0 else "대시 %.1f초" % dash_timer
	var guard_text := "방어 %.1f초" % guard_active_timer if guard_active_timer > 0.0 else "방어 준비"
	if guard_active_timer <= 0.0 and guard_timer > 0.0:
		guard_text = "방어 %.1f초" % guard_timer
	return [dash_text, guard_text]


func modify_incoming_damage(amount: int) -> int:
	if guard_active_timer <= 0.0:
		return amount

	_spawn_guard_block_vfx()
	return int(ceil(float(amount) * guard_damage_scale))


func _try_slash() -> void:
	var nearest_enemy := find_nearest_enemy()
	if nearest_enemy == null:
		slash_timer = 0.0 if experiment_mode else 0.15
		return
	if nearest_enemy.global_position.distance_to(player.global_position) > slash_range:
		slash_timer = 0.0 if experiment_mode else 0.18
		return

	var direction: Vector2 = (nearest_enemy.global_position - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = player.last_attack_direction

	if player.has_method("play_action_animation"):
		var animation_duration := 0.34
		if player.has_method("get_action_animation_duration"):
			animation_duration = player.get_action_animation_duration("attack", animation_duration)
		player.play_action_animation("attack", direction, animation_duration)
	nearest_enemy.take_damage(slash_damage, "attack")
	_spawn_slash_vfx(direction)
	slash_timer = 0.0 if experiment_mode else slash_cooldown


func _spawn_slash_vfx(direction: Vector2) -> void:
	var vfx_parent := make_world_vfx_group()
	var start_angle := direction.angle() - PI * 0.34
	var end_angle := direction.angle() + PI * 0.34
	var arc := Line2D.new()
	arc.width = 8.0
	arc.default_color = Color(1.0, 0.18, 0.14, 0.86)
	arc.z_index = 22
	for index in range(14):
		var t := float(index) / 13.0
		var angle := lerpf(start_angle, end_angle, t)
		arc.add_point(player.global_position + Vector2.RIGHT.rotated(angle) * (52.0 + t * 42.0))
	vfx_parent.add_child(arc)

	var tween := create_tween()
	tween.tween_property(arc, "modulate:a", 0.0, 0.22)
	tween.finished.connect(arc.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_dash_vfx(start_position: Vector2, end_position: Vector2) -> void:
	var vfx_parent := make_world_vfx_group()
	var trail := Line2D.new()
	trail.width = 7.0
	trail.default_color = Color(1.0, 0.22, 0.16, 0.72)
	trail.z_index = 20
	trail.points = PackedVector2Array([start_position, end_position])
	vfx_parent.add_child(trail)

	var ring := Line2D.new()
	ring.width = 3.0
	ring.closed = true
	ring.default_color = Color(1.0, 0.45, 0.35, 0.72)
	ring.points = make_circle_points(18.0, 32)
	ring.global_position = end_position
	ring.z_index = 21
	vfx_parent.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.22)
	tween.tween_property(trail, "width", 1.0, 0.22)
	tween.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.22)
	tween.tween_property(ring, "modulate:a", 0.0, 0.22)
	tween.finished.connect(trail.queue_free)
	tween.finished.connect(ring.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_guard_vfx() -> void:
	var vfx_parent := make_world_vfx_group()
	var ring := Line2D.new()
	ring.width = 5.0
	ring.closed = true
	ring.default_color = Color(1.0, 0.34, 0.25, 0.76)
	ring.points = make_circle_points(58.0, 48)
	ring.global_position = player.global_position
	ring.z_index = 20
	vfx_parent.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.35, 0.22)
	tween.tween_property(ring, "modulate:a", 0.0, 0.22)
	tween.finished.connect(ring.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_guard_block_vfx() -> void:
	var vfx_parent := make_world_vfx_group()
	var spark := Line2D.new()
	spark.width = 4.0
	spark.default_color = Color(1.0, 0.85, 0.55, 0.9)
	spark.z_index = 23
	var center: Vector2 = player.global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-34.0, 8.0))
	spark.points = PackedVector2Array([center + Vector2(-18, 0), center + Vector2(18, 0)])
	vfx_parent.add_child(spark)

	var tween := create_tween()
	tween.tween_property(spark, "modulate:a", 0.0, 0.14)
	tween.finished.connect(spark.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_ultimate_vfx(center: Vector2) -> void:
	var vfx_parent := make_world_vfx_group()
	for index in range(5):
		var slash := Line2D.new()
		slash.width = 10.0
		slash.default_color = Color(1.0, 0.08, 0.05, 0.82)
		slash.z_index = 30
		var angle := TAU * float(index) / 5.0 + randf_range(-0.18, 0.18)
		var side := Vector2.RIGHT.rotated(angle)
		var normal := side.rotated(PI * 0.5)
		slash.points = PackedVector2Array([
			center - side * ultimate_radius * 0.52 - normal * 42.0,
			center + side * ultimate_radius * 0.52 + normal * 42.0,
		])
		vfx_parent.add_child(slash)

		var tween := create_tween()
		tween.tween_property(slash, "modulate:a", 0.0, 0.42)
		tween.finished.connect(slash.queue_free)

	var ring := Line2D.new()
	ring.width = 4.0
	ring.closed = true
	ring.default_color = Color(1.0, 0.26, 0.18, 0.72)
	ring.points = make_circle_points(ultimate_radius * 0.28, 64)
	ring.global_position = center
	ring.z_index = 28
	vfx_parent.add_child(ring)

	var ring_tween := create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2.ONE * 2.0, 0.48)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.48)
	ring_tween.finished.connect(ring.queue_free)
	emit_world_vfx(vfx_parent)


func _emit_status() -> void:
	var texts := get_status_texts()
	status_changed.emit(texts[0], texts[1])


func find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance := INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue

		var distance: float = player.global_position.distance_squared_to(enemy_node.global_position)
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
