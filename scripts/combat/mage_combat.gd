extends Node

signal projectile_requested(projectile_scene: PackedScene, origin: Vector2, direction: Vector2, damage: int)
signal world_vfx_requested(vfx: Node2D)
signal status_changed(skill_1_text: String, skill_2_text: String)

const FIREBALL_SCENE := preload("res://scenes/Fireball.tscn")
const BLINK_VFX_TEXTURE := preload("res://assets/players/mage/skills/blink/mage_blink_vfx_sheet.png")
const BARRIER_VFX_TEXTURE := preload("res://assets/players/mage/skills/barrier/mage_barrier_vfx_sheet.png")
const ULTIMATE_VFX_TEXTURE := preload("res://assets/players/mage/skills/ultimate/ultimate_starfall_vfx_sheet.png")

const DEFENSE_VFX_COLUMNS := 4
const DEFENSE_VFX_ROWS := 4

var fireball_damage := 18
var attack_cooldown := 0.85
var attack_timer := 0.0
var blink_distance := 260.0
var blink_cooldown := 2.5
var blink_invulnerable_duration := 0.18
var blink_timer := 0.0
var blink_max_charges := 1
var blink_charges := 1
var blink_arrival_radius := 95.0
var blink_arrival_damage := 0
var blink_vfx_scale := 0.34
var barrier_duration := 1.2
var barrier_cooldown := 6.0
var barrier_timer := 0.0
var barrier_active_timer := 0.0
var barrier_shield_max := 45
var barrier_shield_current := 0
var barrier_explosion_radius := 145.0
var barrier_explosion_damage := 0
var barrier_vfx_scale := 0.44
var barrier_ring: Line2D
var barrier_sprite: Sprite2D
var defense_vfx_material: CanvasItemMaterial
var ultimate_vfx_material: CanvasItemMaterial
var experiment_mode := false
var player: Node


func setup(owner: Node) -> void:
	player = owner
	_build_defense_vfx_material()
	_build_ultimate_vfx_material()
	_build_barrier_visual()
	_emit_status()


func combat_process(delta: float, _input_direction: Vector2) -> void:
	if experiment_mode:
		_reset_experiment_cooldowns()

	_update_timers(delta)
	attack_timer -= delta
	_update_player_modulate()
	_update_barrier_visual()

	if attack_timer <= 0.0:
		_try_fireball()

	_emit_status()


func try_skill_1(input_direction: Vector2) -> void:
	_try_blink(input_direction)


func try_skill_2(_input_direction: Vector2) -> void:
	_try_barrier()


func set_experiment_mode(enabled: bool) -> void:
	experiment_mode = enabled
	if experiment_mode:
		_reset_experiment_cooldowns()
	_emit_status()


func _reset_experiment_cooldowns() -> void:
	attack_timer = 0.0
	blink_timer = 0.0
	blink_charges = blink_max_charges
	barrier_timer = 0.0


func use_ultimate(context: Dictionary) -> void:
	var targets: Array[Node2D] = context.get("targets", [])
	var damage := int(context.get("damage", 120))
	_spawn_ultimate_vfx(context.get("origin", player.global_position), targets)
	for target in targets:
		if not is_instance_valid(target):
			continue
		if target.has_method("take_damage"):
			target.take_damage(damage, "ultimate")


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"mage_fireball_damage":
			fireball_damage += 7
		"mage_fireball_speed":
			attack_cooldown = maxf(0.25, attack_cooldown * 0.82)
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
	_emit_status()


func can_apply_upgrade(upgrade_id: String) -> bool:
	match upgrade_id:
		"mage_blink_stack":
			return blink_max_charges < 3
		_:
			return true


func get_upgrade_pool() -> Array[Dictionary]:
	return [
		{
			"id": "mage_fireball_damage",
			"label": "파이어볼 강화",
			"description": "파이어볼 피해 +7",
			"rarity": "Common",
			"category": "character",
			"character_id": "mage",
			"skill_id": "fireball",
		},
		{
			"id": "mage_fireball_speed",
			"label": "파이어볼 속도 증가",
			"description": "파이어볼 재사용 대기시간 -18%",
			"rarity": "Common",
			"category": "character",
			"character_id": "mage",
			"skill_id": "fireball",
		},
		{
			"id": "mage_blink_distance",
			"label": "아스트랄 블링크",
			"description": "블링크 이동 거리 +70",
			"rarity": "Rare",
			"category": "character",
			"character_id": "mage",
			"skill_id": "blink",
		},
		{
			"id": "mage_barrier_shield",
			"label": "마나 장벽",
			"description": "배리어 보호막 +30",
			"rarity": "Rare",
			"category": "character",
			"character_id": "mage",
			"skill_id": "barrier",
		},
		{
			"id": "mage_barrier_duration",
			"label": "장벽 유지",
			"description": "배리어 지속 시간 +0.45초",
			"rarity": "Rare",
			"category": "character",
			"character_id": "mage",
			"skill_id": "barrier",
		},
		{
			"id": "mage_blink_stack",
			"label": "블링크 충전",
			"description": "블링크 최대 충전 +1",
			"rarity": "Epic",
			"category": "character",
			"character_id": "mage",
			"skill_id": "blink",
		},
		{
			"id": "mage_blink_arrival_damage",
			"label": "도착 충격",
			"description": "블링크 도착 지점에 피해 35",
			"rarity": "Epic",
			"category": "character",
			"character_id": "mage",
			"skill_id": "blink",
		},
		{
			"id": "mage_barrier_explosion",
			"label": "장벽 폭발",
			"description": "배리어 파괴 시 주변 피해 50",
			"rarity": "Epic",
			"category": "character",
			"character_id": "mage",
			"skill_id": "barrier",
		},
	]


func get_status_texts() -> Array[String]:
	var blink_text := "블링크 %d/%d" % [blink_charges, blink_max_charges]
	if blink_charges <= 0:
		blink_text = "블링크 %.1f초" % blink_timer

	var barrier_text := "배리어 준비"
	if _is_barrier_active():
		barrier_text = "배리어 %d/%d" % [barrier_shield_current, barrier_shield_max]
	elif barrier_timer > 0.0:
		barrier_text = "배리어 %.1f초" % barrier_timer

	return [blink_text, barrier_text]


func modify_incoming_damage(amount: int) -> int:
	if not _is_barrier_active():
		return amount

	var remaining_damage := maxi(0, amount - barrier_shield_current)
	barrier_shield_current = maxi(0, barrier_shield_current - amount)
	_pulse_barrier_block()
	_emit_status()

	if barrier_shield_current <= 0:
		_break_barrier()

	return remaining_damage


func _update_timers(delta: float) -> void:
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


func _try_fireball() -> void:
	var nearest_enemy := find_nearest_enemy()
	if nearest_enemy == null:
		attack_timer = 0.0 if experiment_mode else 0.15
		return

	var direction: Vector2 = (nearest_enemy.global_position - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	projectile_requested.emit(FIREBALL_SCENE, player.global_position + direction * 40.0, direction, fireball_damage)
	attack_timer = 0.0 if experiment_mode else attack_cooldown


func _try_blink(input_direction: Vector2) -> void:
	if blink_charges <= 0 and not experiment_mode:
		return

	var blink_direction := input_direction.normalized()
	if blink_direction == Vector2.ZERO:
		blink_direction = player.last_direction.normalized()
	if blink_direction == Vector2.ZERO:
		blink_direction = Vector2.DOWN

	var start_position: Vector2 = player.global_position
	var target_position: Vector2 = player.global_position + blink_direction * blink_distance
	target_position.x = clampf(target_position.x, -player.world_radius, player.world_radius)
	target_position.y = clampf(target_position.y, -player.world_radius, player.world_radius)

	player.global_position = target_position
	player.velocity = Vector2.ZERO
	if not experiment_mode:
		blink_charges -= 1
	if blink_charges < blink_max_charges and blink_timer <= 0.0 and not experiment_mode:
		blink_timer = blink_cooldown
	player.set_invulnerable(blink_invulnerable_duration)
	player.last_direction = blink_direction
	player.update_walk_animation(blink_direction, blink_distance)
	_spawn_blink_vfx(start_position, target_position)
	_apply_blink_arrival_damage(target_position)
	_emit_status()


func _try_barrier() -> void:
	if barrier_timer > 0.0 and not experiment_mode:
		return

	barrier_timer = 0.0 if experiment_mode else barrier_cooldown
	barrier_active_timer = barrier_duration
	barrier_shield_current = barrier_shield_max
	_update_barrier_visual()
	_emit_status()


func _is_barrier_active() -> bool:
	return barrier_active_timer > 0.0 and barrier_shield_current > 0


func _break_barrier() -> void:
	barrier_active_timer = 0.0
	barrier_shield_current = 0
	_update_barrier_visual()
	if barrier_explosion_damage > 0:
		apply_area_damage(player.global_position, barrier_explosion_radius, barrier_explosion_damage, "skill")
	_spawn_barrier_break_vfx()


func _update_player_modulate() -> void:
	if _is_barrier_active():
		player.set_combat_modulate(Color(0.72, 0.95, 1.35))
	else:
		player.clear_combat_modulate()


func _build_barrier_visual() -> void:
	barrier_ring = Line2D.new()
	barrier_ring.width = 4.0
	barrier_ring.closed = true
	barrier_ring.z_index = 20
	barrier_ring.default_color = Color(0.45, 0.78, 1.0, 0.0)
	barrier_ring.points = make_circle_points(62.0, 56)
	barrier_ring.visible = false
	player.add_child(barrier_ring)

	barrier_sprite = Sprite2D.new()
	barrier_sprite.texture = BARRIER_VFX_TEXTURE
	barrier_sprite.region_enabled = true
	barrier_sprite.region_rect = _make_vfx_region(BARRIER_VFX_TEXTURE, 0, 0)
	barrier_sprite.material = defense_vfx_material
	barrier_sprite.position = Vector2(0, -10)
	barrier_sprite.scale = Vector2.ONE * barrier_vfx_scale
	barrier_sprite.z_index = 19
	barrier_sprite.visible = false
	player.add_child(barrier_sprite)


func _update_barrier_visual() -> void:
	if barrier_ring == null:
		return

	var active := _is_barrier_active()
	barrier_ring.visible = active
	barrier_sprite.visible = active
	if not active:
		return

	var progress := barrier_active_timer / barrier_duration
	var shield_ratio := float(barrier_shield_current) / float(maxi(1, barrier_shield_max))
	var pulse := 0.08 + sin(Time.get_ticks_msec() / 70.0) * 0.04
	barrier_ring.scale = Vector2.ONE * (1.0 + pulse)
	barrier_ring.default_color = Color(0.45, 0.82, 1.0, clampf(0.18 + minf(progress, shield_ratio) * 0.65, 0.18, 0.85))
	barrier_sprite.region_rect = _make_vfx_region(BARRIER_VFX_TEXTURE, 0, _barrier_state_column(shield_ratio))
	barrier_sprite.scale = Vector2.ONE * barrier_vfx_scale * (1.0 + pulse * 0.45)
	barrier_sprite.modulate = Color(1.0, 1.0, 1.0, clampf(0.48 + minf(progress, shield_ratio) * 0.52, 0.48, 1.0))


func _pulse_barrier_block() -> void:
	_spawn_barrier_hit_vfx()
	var sprite_tween := create_tween()
	sprite_tween.tween_property(barrier_sprite, "scale", Vector2.ONE * barrier_vfx_scale * 1.22, 0.05)
	sprite_tween.tween_property(barrier_sprite, "scale", Vector2.ONE * barrier_vfx_scale, 0.12)

	var ring_tween := create_tween()
	ring_tween.tween_property(barrier_ring, "width", 8.0, 0.05)
	ring_tween.tween_property(barrier_ring, "width", 4.0, 0.12)


func _apply_blink_arrival_damage(world_position: Vector2) -> void:
	if blink_arrival_damage <= 0:
		return

	apply_area_damage(world_position, blink_arrival_radius, blink_arrival_damage, "skill")
	_spawn_blink_arrival_damage_vfx(world_position)


func _spawn_barrier_break_vfx() -> void:
	var vfx_parent := make_world_vfx_group()
	_spawn_vfx_ring(vfx_parent, player.global_position, 58.0, 2.9, 0.42, Color(0.82, 0.96, 1.0, 0.9), 6.0, 27)
	_spawn_vfx_ring(vfx_parent, player.global_position, 38.0, 4.2, 0.5, Color(0.35, 0.78, 1.0, 0.58), 3.0, 24)
	_spawn_sheet_vfx(vfx_parent, BARRIER_VFX_TEXTURE, 2, 0, player.global_position, barrier_vfx_scale * 1.22, 0.34, 24)
	_spawn_sheet_vfx(vfx_parent, BARRIER_VFX_TEXTURE, 2, 1, player.global_position, barrier_vfx_scale * 1.42, 0.42, 25)
	_spawn_sheet_vfx(vfx_parent, BARRIER_VFX_TEXTURE, 2, 2, player.global_position, barrier_vfx_scale * 1.72, 0.5, 26)
	_spawn_sheet_vfx(vfx_parent, BARRIER_VFX_TEXTURE, 2, 3, player.global_position, barrier_vfx_scale * 1.32, 0.58, 24)
	emit_world_vfx(vfx_parent)


func _spawn_blink_vfx(start_position: Vector2, end_position: Vector2) -> void:
	var vfx_parent := make_world_vfx_group()
	var direction := end_position - start_position
	var distance := direction.length()
	var angle := direction.angle() if distance > 0.01 else 0.0
	var midpoint := start_position + direction * 0.5

	_spawn_sheet_vfx(vfx_parent, BLINK_VFX_TEXTURE, 0, 1, start_position, blink_vfx_scale * 1.02, 0.3, 20)

	var trail := _make_sheet_sprite(BLINK_VFX_TEXTURE, 1, 0, midpoint, blink_vfx_scale, 18)
	trail.rotation = angle
	trail.scale = Vector2(blink_vfx_scale * clampf(distance / 220.0, 0.8, 1.85), blink_vfx_scale * 0.78)
	vfx_parent.add_child(trail)

	var afterimage := _make_sheet_sprite(BLINK_VFX_TEXTURE, 1, 3, start_position, blink_vfx_scale * 0.9, 17)
	afterimage.rotation = angle
	vfx_parent.add_child(afterimage)

	_spawn_vfx_ring(vfx_parent, end_position, 22.0, 2.6, 0.32, Color(0.75, 0.95, 1.0, 0.72), 4.0, 22)
	_spawn_sheet_vfx(vfx_parent, BLINK_VFX_TEXTURE, 2, 0, end_position, blink_vfx_scale * 1.08, 0.38, 21)
	_spawn_sheet_vfx(vfx_parent, BLINK_VFX_TEXTURE, 2, 1, end_position, blink_vfx_scale * 0.96, 0.42, 20)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.24)
	tween.tween_property(trail, "scale", trail.scale * Vector2(1.08, 0.45), 0.24)
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.3)
	tween.tween_property(afterimage, "scale", afterimage.scale * 1.08, 0.3)
	tween.finished.connect(trail.queue_free)
	tween.finished.connect(afterimage.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_blink_arrival_damage_vfx(world_position: Vector2) -> void:
	var vfx_parent := make_world_vfx_group()
	_spawn_vfx_ring(vfx_parent, world_position, blink_arrival_radius * 0.35, 2.8, 0.42, Color(0.78, 0.96, 1.0, 0.86), 5.0, 24)
	_spawn_vfx_ring(vfx_parent, world_position, blink_arrival_radius * 0.55, 2.0, 0.52, Color(0.32, 0.76, 1.0, 0.58), 3.0, 21)
	_spawn_sheet_vfx(vfx_parent, BLINK_VFX_TEXTURE, 2, 2, world_position, blink_vfx_scale * 1.72, 0.48, 23)
	_spawn_sheet_vfx(vfx_parent, BLINK_VFX_TEXTURE, 3, 1, world_position, blink_vfx_scale * 1.25, 0.9, 12)
	emit_world_vfx(vfx_parent)


func _spawn_barrier_hit_vfx() -> void:
	var vfx_parent := make_world_vfx_group()
	var hit_column := randi_range(0, 3)
	var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18.0, 44.0)
	var hit_position: Vector2 = player.global_position + Vector2(0, -10) + offset
	_spawn_sheet_vfx(vfx_parent, BARRIER_VFX_TEXTURE, 1, hit_column, hit_position, barrier_vfx_scale * 0.92, 0.28, 25)
	_spawn_vfx_ring(vfx_parent, player.global_position + Vector2(0, -10), 54.0, 1.45, 0.22, Color(0.85, 0.98, 1.0, 0.72), 3.5, 24)
	emit_world_vfx(vfx_parent)


func _spawn_ultimate_vfx(center: Vector2, targets: Array[Node2D]) -> void:
	var vfx_parent := make_world_vfx_group()
	var center_circle := _make_ultimate_vfx_sprite(
		center,
		Rect2(35, 35, 370, 255),
		24,
		Vector2.ONE * 1.25,
		Color(0.7, 0.86, 1.0, 0.75)
	)
	vfx_parent.add_child(center_circle)

	var center_tween := create_tween()
	center_tween.set_parallel(true)
	center_tween.tween_property(center_circle, "scale", center_circle.scale * 1.18, 0.58)
	center_tween.tween_property(center_circle, "modulate:a", 0.0, 0.58)
	center_tween.finished.connect(center_circle.queue_free)

	var impact_regions: Array[Rect2] = [
		Rect2(815, 330, 315, 230),
		Rect2(1125, 330, 330, 245),
		Rect2(820, 610, 360, 360),
		Rect2(1160, 610, 365, 365),
	]
	var beam_regions: Array[Rect2] = [
		Rect2(935, 35, 70, 300),
		Rect2(1010, 28, 82, 310),
		Rect2(1100, 18, 88, 320),
		Rect2(1198, 12, 105, 330),
	]

	for target in targets:
		if not is_instance_valid(target):
			continue

		var impact_position := target.global_position
		var beam := _make_ultimate_vfx_sprite(
			impact_position + Vector2(0.0, -220.0),
			beam_regions.pick_random(),
			28,
			Vector2(randf_range(0.78, 1.0), randf_range(0.95, 1.2)),
			Color(0.85, 0.95, 1.0, 0.9),
			Vector2(0.5, 0.9)
		)
		vfx_parent.add_child(beam)

		var impact := _make_ultimate_vfx_sprite(
			impact_position,
			impact_regions.pick_random(),
			29,
			Vector2.ONE * randf_range(0.72, 0.96),
			Color(0.9, 0.96, 1.0, 1.0),
			Vector2(0.5, 0.72)
		)
		vfx_parent.add_child(impact)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(beam, "modulate:a", 0.0, 0.45)
		tween.tween_property(beam, "global_position", impact_position + Vector2(0.0, -8.0), 0.45)
		tween.tween_property(impact, "scale", impact.scale * 1.22, 0.45)
		tween.tween_property(impact, "modulate:a", 0.0, 0.45)
		tween.finished.connect(beam.queue_free)
		tween.finished.connect(impact.queue_free)

	emit_world_vfx(vfx_parent)


func _make_ultimate_vfx_sprite(
	world_position: Vector2,
	region: Rect2,
	z_layer: int,
	sprite_scale: Vector2,
	color: Color,
	anchor := Vector2(0.5, 0.5)
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ULTIMATE_VFX_TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = true
	sprite.offset = (Vector2(0.5, 0.5) - anchor) * region.size
	sprite.material = ultimate_vfx_material
	sprite.z_index = z_layer
	sprite.scale = sprite_scale
	sprite.modulate = color
	sprite.global_position = world_position
	return sprite


func _spawn_vfx_ring(vfx_parent: Node, world_position: Vector2, radius: float, target_scale: float, duration: float, color: Color, width: float, z_index: int) -> Line2D:
	var ring := Line2D.new()
	ring.width = width
	ring.closed = true
	ring.z_index = z_index
	ring.default_color = color
	ring.points = make_circle_points(radius, 56)
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


func _build_defense_vfx_material() -> void:
	defense_vfx_material = CanvasItemMaterial.new()
	defense_vfx_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _build_ultimate_vfx_material() -> void:
	ultimate_vfx_material = CanvasItemMaterial.new()
	ultimate_vfx_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _barrier_state_column(shield_ratio: float) -> int:
	if shield_ratio > 0.75:
		return 0
	if shield_ratio > 0.5:
		return 1
	if shield_ratio > 0.25:
		return 2
	return 3


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
