class_name Player
extends CharacterBody2D

signal fireball_requested(origin: Vector2, direction: Vector2, damage: int)
signal health_changed(current_health: int, max_health: int)
signal experience_changed(current_experience: int, required_experience: int, level: int)
signal level_up_ready(level: int)
signal defense_status_changed(blink_remaining: float, blink_cooldown: float, blink_charges: int, blink_max_charges: int, barrier_remaining: float, barrier_cooldown: float, barrier_active: bool, barrier_shield_current: int, barrier_shield_max: int)
signal died

@export var move_speed := 260.0
@export var max_health := 100
@export var fireball_damage := 18
@export var attack_cooldown := 0.85
@export var level_required_base := 6
@export var level_required_growth := 4
@export var world_radius := 2600.0
@export var sprite_columns := 8
@export var sprite_rows := 8
@export var walk_animation_fps := 8.0
@export var walk_frame_distance := 14.0
@export var blink_distance := 260.0
@export var blink_cooldown := 2.5
@export var blink_invulnerable_duration := 0.18
@export var barrier_duration := 1.2
@export var barrier_cooldown := 6.0
@export var barrier_shield_max := 45
@export var blink_arrival_radius := 95.0
@export var barrier_explosion_radius := 145.0
@export var blink_vfx_texture: Texture2D
@export var barrier_vfx_texture: Texture2D
@export var blink_vfx_scale := 0.34
@export var barrier_vfx_scale := 0.44

var current_health := 100
var level := 1
var experience := 0
var required_experience := 6
var attack_timer := 0.0
var invulnerable_timer := 0.0
var blink_timer := 0.0
var blink_max_charges := 1
var blink_charges := 1
var barrier_timer := 0.0
var barrier_active_timer := 0.0
var barrier_shield_current := 0
var blink_arrival_damage := 0
var barrier_explosion_damage := 0
var walk_distance := 0.0
var last_direction := Vector2.DOWN
var is_dead := false

@onready var sprite: Sprite2D = $Sprite2D
var barrier_ring: Line2D
var barrier_sprite: Sprite2D
var defense_vfx_material: CanvasItemMaterial
const DEFENSE_VFX_COLUMNS := 4
const DEFENSE_VFX_ROWS := 4


func _ready() -> void:
	current_health = max_health
	required_experience = level_required_base
	add_to_group("player")
	_build_defense_vfx_material()
	_build_barrier_visual()
	health_changed.emit(current_health, max_health)
	experience_changed.emit(experience, required_experience, level)
	_emit_defense_status()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_defense_timers(delta)
	_handle_defense_skill_inputs(input_direction)

	var previous_position := global_position
	velocity = input_direction * move_speed
	move_and_slide()

	global_position.x = clampf(global_position.x, -world_radius, world_radius)
	global_position.y = clampf(global_position.y, -world_radius, world_radius)

	var moved_distance := previous_position.distance_to(global_position)
	_update_walk_animation(input_direction, moved_distance)

	attack_timer -= delta
	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	_update_player_modulate()
	_update_barrier_visual()
	_emit_defense_status()

	if attack_timer <= 0.0:
		_try_fireball()


func take_damage(amount: int) -> void:
	if is_dead or invulnerable_timer > 0.0:
		return
	if _is_barrier_active():
		var remaining_damage := _absorb_damage_with_barrier(amount)
		_pulse_barrier_block()
		if remaining_damage <= 0:
			return
		amount = remaining_damage

	current_health = maxi(0, current_health - amount)
	invulnerable_timer = 0.45
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		is_dead = true
		died.emit()


func add_experience(amount: int) -> void:
	if is_dead:
		return

	experience += amount
	if experience >= required_experience:
		experience -= required_experience
		level += 1
		required_experience = level_required_base + (level - 1) * level_required_growth
		level_up_ready.emit(level)

	experience_changed.emit(experience, required_experience, level)


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"damage":
			fireball_damage += 7
		"attack_speed":
			attack_cooldown = maxf(0.25, attack_cooldown * 0.82)
		"health":
			max_health += 25
			current_health = mini(max_health, current_health + 35)
		"mage_blink_distance":
			blink_distance += 70.0
		"mage_barrier_shield":
			barrier_shield_max += 30
			if _is_barrier_active():
				barrier_shield_current += 30
		"mage_barrier_duration":
			barrier_duration += 0.45
		"mage_blink_stack":
			blink_max_charges = mini(3, blink_max_charges + 1)
			blink_charges = mini(blink_max_charges, blink_charges + 1)
		"mage_blink_arrival_damage":
			blink_arrival_damage += 35
		"mage_barrier_explosion":
			barrier_explosion_damage += 50

	health_changed.emit(current_health, max_health)
	experience_changed.emit(experience, required_experience, level)
	_emit_defense_status()


func can_apply_upgrade(upgrade_id: String) -> bool:
	match upgrade_id:
		"mage_blink_stack":
			return blink_max_charges < 3
		_:
			return true


func _update_defense_timers(delta: float) -> void:
	if blink_charges < blink_max_charges:
		blink_timer = maxf(0.0, blink_timer - delta)
		if blink_timer <= 0.0:
			blink_charges += 1
			if blink_charges < blink_max_charges:
				blink_timer = blink_cooldown
	else:
		blink_timer = 0.0

	barrier_timer = maxf(0.0, barrier_timer - delta)
	barrier_active_timer = maxf(0.0, barrier_active_timer - delta)
	if barrier_active_timer <= 0.0 and barrier_shield_current > 0:
		barrier_shield_current = 0


func _handle_defense_skill_inputs(input_direction: Vector2) -> void:
	if Input.is_action_just_pressed("blink"):
		_try_defense_skill_1(input_direction)
	if Input.is_action_just_pressed("barrier"):
		_try_defense_skill_2()


func _try_defense_skill_1(input_direction: Vector2) -> void:
	_try_blink(input_direction)


func _try_defense_skill_2() -> void:
	_try_barrier()


func _try_blink(input_direction: Vector2) -> void:
	if blink_charges <= 0:
		return

	var blink_direction := input_direction.normalized()
	if blink_direction == Vector2.ZERO:
		blink_direction = last_direction.normalized()
	if blink_direction == Vector2.ZERO:
		blink_direction = Vector2.DOWN

	var start_position := global_position
	var target_position := global_position + blink_direction * blink_distance
	target_position.x = clampf(target_position.x, -world_radius, world_radius)
	target_position.y = clampf(target_position.y, -world_radius, world_radius)

	global_position = target_position
	velocity = Vector2.ZERO
	blink_charges -= 1
	if blink_charges < blink_max_charges and blink_timer <= 0.0:
		blink_timer = blink_cooldown
	invulnerable_timer = maxf(invulnerable_timer, blink_invulnerable_duration)
	last_direction = blink_direction
	_update_walk_animation(last_direction, blink_distance)
	_spawn_blink_vfx(start_position, target_position)
	_apply_blink_arrival_damage(target_position)
	_emit_defense_status()


func _try_barrier() -> void:
	if barrier_timer > 0.0:
		return

	barrier_timer = barrier_cooldown
	barrier_active_timer = barrier_duration
	barrier_shield_current = barrier_shield_max
	_update_barrier_visual()
	_emit_defense_status()


func _update_player_modulate() -> void:
	if _is_barrier_active():
		sprite.modulate = Color(0.72, 0.95, 1.35)
	elif invulnerable_timer > 0.0:
		sprite.modulate = Color(1.0, 0.55, 0.55)
	else:
		sprite.modulate = Color.WHITE


func _build_barrier_visual() -> void:
	barrier_ring = Line2D.new()
	barrier_ring.width = 4.0
	barrier_ring.closed = true
	barrier_ring.z_index = 20
	barrier_ring.default_color = Color(0.45, 0.78, 1.0, 0.0)
	barrier_ring.points = _make_circle_points(62.0, 56)
	barrier_ring.visible = false
	add_child(barrier_ring)

	if barrier_vfx_texture != null:
		barrier_sprite = Sprite2D.new()
		barrier_sprite.texture = barrier_vfx_texture
		barrier_sprite.region_enabled = true
		barrier_sprite.region_rect = _make_vfx_region(barrier_vfx_texture, 0, 0)
		barrier_sprite.material = defense_vfx_material
		barrier_sprite.position = Vector2(0, -10)
		barrier_sprite.scale = Vector2.ONE * barrier_vfx_scale
		barrier_sprite.z_index = 19
		barrier_sprite.visible = false
		add_child(barrier_sprite)


func _update_barrier_visual() -> void:
	if barrier_ring == null:
		return

	var active := _is_barrier_active()
	barrier_ring.visible = active
	if barrier_sprite != null:
		barrier_sprite.visible = active
	if not active:
		return

	var progress := barrier_active_timer / barrier_duration
	var shield_ratio := float(barrier_shield_current) / float(maxi(1, barrier_shield_max))
	var pulse := 0.08 + sin(Time.get_ticks_msec() / 70.0) * 0.04
	barrier_ring.scale = Vector2.ONE * (1.0 + pulse)
	barrier_ring.default_color = Color(0.45, 0.82, 1.0, clampf(0.18 + minf(progress, shield_ratio) * 0.65, 0.18, 0.85))
	if barrier_sprite != null:
		barrier_sprite.region_rect = _make_vfx_region(barrier_vfx_texture, 0, _barrier_state_column(shield_ratio))
		barrier_sprite.scale = Vector2.ONE * barrier_vfx_scale * (1.0 + pulse * 0.45)
		barrier_sprite.modulate = Color(1.0, 1.0, 1.0, clampf(0.48 + minf(progress, shield_ratio) * 0.52, 0.48, 1.0))


func _pulse_barrier_block() -> void:
	if barrier_sprite != null:
		_spawn_barrier_hit_vfx()
		var sprite_tween := create_tween()
		sprite_tween.tween_property(barrier_sprite, "scale", Vector2.ONE * barrier_vfx_scale * 1.22, 0.05)
		sprite_tween.tween_property(barrier_sprite, "scale", Vector2.ONE * barrier_vfx_scale, 0.12)

	if barrier_ring != null:
		var tween := create_tween()
		tween.tween_property(barrier_ring, "width", 8.0, 0.05)
		tween.tween_property(barrier_ring, "width", 4.0, 0.12)


func _is_barrier_active() -> bool:
	return barrier_active_timer > 0.0 and barrier_shield_current > 0


func _absorb_damage_with_barrier(amount: int) -> int:
	var remaining_damage := maxi(0, amount - barrier_shield_current)
	barrier_shield_current = maxi(0, barrier_shield_current - amount)
	_emit_defense_status()

	if barrier_shield_current <= 0:
		_break_barrier()

	return remaining_damage


func _break_barrier() -> void:
	barrier_active_timer = 0.0
	barrier_shield_current = 0
	_update_barrier_visual()
	if barrier_explosion_damage > 0:
		_apply_area_damage(global_position, barrier_explosion_radius, barrier_explosion_damage)
	_spawn_barrier_break_vfx()


func _spawn_barrier_break_vfx() -> void:
	var vfx_parent := get_parent()
	if vfx_parent == null:
		return
	if barrier_vfx_texture != null:
		_spawn_vfx_ring(vfx_parent, global_position, 58.0, 2.9, 0.42, Color(0.82, 0.96, 1.0, 0.9), 6.0, 27)
		_spawn_vfx_ring(vfx_parent, global_position, 38.0, 4.2, 0.5, Color(0.35, 0.78, 1.0, 0.58), 3.0, 24)
		_spawn_sheet_vfx(vfx_parent, barrier_vfx_texture, 2, 0, global_position, barrier_vfx_scale * 1.22, 0.34, 24)
		_spawn_sheet_vfx(vfx_parent, barrier_vfx_texture, 2, 1, global_position, barrier_vfx_scale * 1.42, 0.42, 25)
		_spawn_sheet_vfx(vfx_parent, barrier_vfx_texture, 2, 2, global_position, barrier_vfx_scale * 1.72, 0.5, 26)
		_spawn_sheet_vfx(vfx_parent, barrier_vfx_texture, 2, 3, global_position, barrier_vfx_scale * 1.32, 0.58, 24)
		return

	var ring := Line2D.new()
	ring.width = 5.0
	ring.closed = true
	ring.z_index = 14
	ring.default_color = Color(0.55, 0.86, 1.0, 0.8)
	ring.points = _make_circle_points(62.0, 56)
	ring.global_position = global_position
	vfx_parent.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 3.2, 0.26)
	tween.tween_property(ring, "modulate:a", 0.0, 0.26)
	tween.finished.connect(ring.queue_free)


func _spawn_blink_vfx(start_position: Vector2, end_position: Vector2) -> void:
	var vfx_parent := get_parent()
	if vfx_parent == null:
		return
	if blink_vfx_texture != null:
		_spawn_blink_sheet_vfx(vfx_parent, start_position, end_position)
		return

	var trail := Line2D.new()
	trail.width = 9.0
	trail.default_color = Color(0.45, 0.82, 1.0, 0.72)
	trail.z_index = 12
	trail.points = PackedVector2Array([start_position, end_position])
	vfx_parent.add_child(trail)

	var afterimage := Sprite2D.new()
	afterimage.texture = sprite.texture
	afterimage.hframes = sprite.hframes
	afterimage.vframes = sprite.vframes
	afterimage.frame = sprite.frame
	afterimage.scale = sprite.scale
	afterimage.position = start_position + sprite.position
	afterimage.modulate = Color(0.45, 0.85, 1.0, 0.52)
	afterimage.z_index = 11
	vfx_parent.add_child(afterimage)

	var arrival_ring := Line2D.new()
	arrival_ring.width = 3.0
	arrival_ring.closed = true
	arrival_ring.z_index = 13
	arrival_ring.default_color = Color(0.75, 0.95, 1.0, 0.72)
	arrival_ring.points = _make_circle_points(18.0, 32)
	arrival_ring.global_position = end_position
	vfx_parent.add_child(arrival_ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.22)
	tween.tween_property(trail, "width", 1.0, 0.22)
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.28)
	tween.tween_property(afterimage, "scale", afterimage.scale * 1.08, 0.28)
	tween.tween_property(arrival_ring, "scale", Vector2.ONE * 2.4, 0.24)
	tween.tween_property(arrival_ring, "modulate:a", 0.0, 0.24)
	tween.finished.connect(trail.queue_free)
	tween.finished.connect(afterimage.queue_free)
	tween.finished.connect(arrival_ring.queue_free)


func _apply_blink_arrival_damage(world_position: Vector2) -> void:
	if blink_arrival_damage <= 0:
		return

	_apply_area_damage(world_position, blink_arrival_radius, blink_arrival_damage)
	_spawn_blink_arrival_damage_vfx(world_position)


func _apply_area_damage(world_position: Vector2, radius: float, damage: int) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		if enemy_node.global_position.distance_to(world_position) > radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)


func _spawn_blink_arrival_damage_vfx(world_position: Vector2) -> void:
	var vfx_parent := get_parent()
	if vfx_parent == null:
		return
	if blink_vfx_texture != null:
		_spawn_vfx_ring(vfx_parent, world_position, blink_arrival_radius * 0.35, 2.8, 0.42, Color(0.78, 0.96, 1.0, 0.86), 5.0, 24)
		_spawn_vfx_ring(vfx_parent, world_position, blink_arrival_radius * 0.55, 2.0, 0.52, Color(0.32, 0.76, 1.0, 0.58), 3.0, 21)
		_spawn_sheet_vfx(vfx_parent, blink_vfx_texture, 2, 2, world_position, blink_vfx_scale * 1.72, 0.48, 23)
		_spawn_sheet_vfx(vfx_parent, blink_vfx_texture, 3, 1, world_position, blink_vfx_scale * 1.25, 0.9, 12)
		return

	var ring := Line2D.new()
	ring.width = 3.0
	ring.closed = true
	ring.z_index = 14
	ring.default_color = Color(0.42, 0.86, 1.0, 0.72)
	ring.points = _make_circle_points(blink_arrival_radius * 0.45, 40)
	ring.global_position = world_position
	vfx_parent.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.24)
	tween.tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.finished.connect(ring.queue_free)


func _emit_defense_status() -> void:
	var blink_remaining := 0.0 if blink_charges > 0 else blink_timer
	defense_status_changed.emit(
		blink_remaining,
		blink_cooldown,
		blink_charges,
		blink_max_charges,
		barrier_timer,
		barrier_cooldown,
		_is_barrier_active(),
		barrier_shield_current,
		barrier_shield_max
	)


func _make_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _build_defense_vfx_material() -> void:
	defense_vfx_material = CanvasItemMaterial.new()
	defense_vfx_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _barrier_state_column(shield_ratio: float) -> int:
	if shield_ratio > 0.75:
		return 0
	if shield_ratio > 0.5:
		return 1
	if shield_ratio > 0.25:
		return 2
	return 3


func _spawn_barrier_hit_vfx() -> void:
	var vfx_parent := get_parent()
	if vfx_parent == null or barrier_vfx_texture == null:
		return

	var hit_column := randi_range(0, 3)
	var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18.0, 44.0)
	var hit_position := global_position + Vector2(0, -10) + offset
	_spawn_sheet_vfx(vfx_parent, barrier_vfx_texture, 1, hit_column, hit_position, barrier_vfx_scale * 0.92, 0.28, 25)
	_spawn_vfx_ring(vfx_parent, global_position + Vector2(0, -10), 54.0, 1.45, 0.22, Color(0.85, 0.98, 1.0, 0.72), 3.5, 24)


func _spawn_blink_sheet_vfx(vfx_parent: Node, start_position: Vector2, end_position: Vector2) -> void:
	var direction := end_position - start_position
	var distance := direction.length()
	var angle := direction.angle() if distance > 0.01 else 0.0
	var midpoint := start_position + direction * 0.5

	_spawn_sheet_vfx(vfx_parent, blink_vfx_texture, 0, 1, start_position, blink_vfx_scale * 1.02, 0.3, 20)

	var trail := _make_sheet_sprite(blink_vfx_texture, 1, 0, midpoint, blink_vfx_scale, 18)
	trail.rotation = angle
	trail.scale = Vector2(blink_vfx_scale * clampf(distance / 220.0, 0.8, 1.85), blink_vfx_scale * 0.78)
	vfx_parent.add_child(trail)

	var afterimage := _make_sheet_sprite(blink_vfx_texture, 1, 3, start_position, blink_vfx_scale * 0.9, 17)
	afterimage.rotation = angle
	vfx_parent.add_child(afterimage)

	_spawn_vfx_ring(vfx_parent, end_position, 22.0, 2.6, 0.32, Color(0.75, 0.95, 1.0, 0.72), 4.0, 22)
	_spawn_sheet_vfx(vfx_parent, blink_vfx_texture, 2, 0, end_position, blink_vfx_scale * 1.08, 0.38, 21)
	_spawn_sheet_vfx(vfx_parent, blink_vfx_texture, 2, 1, end_position, blink_vfx_scale * 0.96, 0.42, 20)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.24)
	tween.tween_property(trail, "scale", trail.scale * Vector2(1.08, 0.45), 0.24)
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.3)
	tween.tween_property(afterimage, "scale", afterimage.scale * 1.08, 0.3)
	tween.finished.connect(trail.queue_free)
	tween.finished.connect(afterimage.queue_free)


func _spawn_vfx_ring(vfx_parent: Node, world_position: Vector2, radius: float, target_scale: float, duration: float, color: Color, width: float, z_index: int) -> Line2D:
	var ring := Line2D.new()
	ring.width = width
	ring.closed = true
	ring.z_index = z_index
	ring.default_color = color
	ring.points = _make_circle_points(radius, 56)
	ring.global_position = world_position
	vfx_parent.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * target_scale, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.finished.connect(ring.queue_free)
	return ring


func _spawn_sheet_vfx(vfx_parent: Node, texture: Texture2D, row: int, column: int, world_position: Vector2, scale_amount: float, duration: float, z_index: int) -> Sprite2D:
	var vfx := _make_sheet_sprite(texture, row, column, world_position, scale_amount, z_index)
	vfx_parent.add_child(vfx)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(vfx, "scale", vfx.scale * 1.18, duration)
	tween.tween_property(vfx, "modulate:a", 0.0, duration)
	tween.finished.connect(vfx.queue_free)
	return vfx


func _make_sheet_sprite(texture: Texture2D, row: int, column: int, world_position: Vector2, scale_amount: float, z_index: int) -> Sprite2D:
	var vfx := Sprite2D.new()
	vfx.texture = texture
	vfx.region_enabled = true
	vfx.region_rect = _make_vfx_region(texture, row, column)
	vfx.material = defense_vfx_material
	vfx.global_position = world_position
	vfx.scale = Vector2.ONE * scale_amount
	vfx.z_index = z_index
	return vfx


func _make_vfx_region(texture: Texture2D, row: int, column: int) -> Rect2:
	var cell_size := Vector2(
		float(texture.get_width()) / float(DEFENSE_VFX_COLUMNS),
		float(texture.get_height()) / float(DEFENSE_VFX_ROWS)
	)
	return Rect2(cell_size * Vector2(column, row), cell_size)


func _try_fireball() -> void:
	var nearest_enemy := _find_nearest_enemy()
	if nearest_enemy == null:
		attack_timer = 0.15
		return

	var direction := (nearest_enemy.global_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	fireball_requested.emit(global_position + direction * 40.0, direction, fireball_damage)
	attack_timer = attack_cooldown


func _find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance := INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue

		var distance := global_position.distance_squared_to(enemy_node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy_node

	return nearest_enemy


func _update_walk_animation(input_direction: Vector2, moved_distance: float) -> void:
	var is_moving := input_direction.length_squared() > 0.01
	if is_moving:
		last_direction = input_direction
		walk_distance += moved_distance
	else:
		walk_distance = 0.0

	var row := _direction_to_sprite_row(last_direction)
	var column := 0
	if is_moving:
		column = int(walk_distance / walk_frame_distance) % sprite_columns

	sprite.frame = row * sprite_columns + column


func _direction_to_sprite_row(direction: Vector2) -> int:
	var angle := fposmod(direction.angle() + PI / 8.0, TAU)
	var octant := int(angle / (PI / 4.0))

	match octant:
		0:
			return 2 # right
		1:
			return 1 # down_right
		2:
			return 0 # down
		3:
			return 7 # down_left
		4:
			return 6 # left
		5:
			return 5 # up_left
		6:
			return 4 # up
		_:
			return 3 # up_right
