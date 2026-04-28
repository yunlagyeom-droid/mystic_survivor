extends Node2D

@export var slime_scene: PackedScene
@export var fireball_scene: PackedScene
@export var experience_gem_scene: PackedScene
@export var background_texture: Texture2D
@export var ultimate_cutin_texture: Texture2D
@export var ultimate_vfx_texture: Texture2D
@export var spawn_distance := 760.0
@export var spawn_interval := 0.3
@export var max_enemies := 400
@export var world_radius := 2600.0
@export var background_scale := 0.82
@export var ultimate_required_kills := 10
@export var debug_ultimate_always_ready := true
@export var ultimate_cutin_side := "right"
@export var ultimate_cutin_width_scale := 0.75
@export var ultimate_cutin_x_offset := 96.0
@export var ultimate_damage := 120
@export var ultimate_max_targets := 36
@export var ultimate_warning_duration := 1.0
@export var ultimate_impact_duration := 0.65
@export var ultimate_radius := 720.0
@export var ultimate_camera_shake_strength := 8.0
@export var ultimate_screen_flash_alpha := 0.22
@export var ultimate_center_circle_scale := 1.25
@export var ultimate_target_padding := 24.0
@export var ultimate_beam_start_offset := Vector2(0.0, -220.0)
@export var ultimate_beam_end_offset := Vector2(0.0, -8.0)
@export var ultimate_beam_anchor := Vector2(0.5, 0.9)
@export var ultimate_impact_anchor := Vector2(0.5, 0.72)
@export var ultimate_particle_spread := 8.0

var elapsed_time := 0.0
var defeated_count := 0
var ultimate_kills := 0
var ultimate_ready := false
var ultimate_showing := false
var game_over := false

var canvas_layer: CanvasLayer
var health_bar: ProgressBar
var exp_bar: ProgressBar
var ultimate_bar: ProgressBar
var level_label: Label
var time_label: Label
var defeated_label: Label
var ultimate_label: Label
var blink_label: Label
var barrier_label: Label
var level_up_panel: PanelContainer
var level_up_title: Label
var level_up_option_buttons: Array[Button] = []
var current_level_up_options: Array[Dictionary] = []
var game_over_panel: PanelContainer
var final_stats_label: Label
var ultimate_overlay: Control
var ultimate_texture_rect: TextureRect
var ultimate_flash_rect: ColorRect
var ultimate_vfx_material: CanvasItemMaterial

@onready var background: Node2D = $Background
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var gem_container: Node2D = $GemContainer
@onready var ultimate_vfx_container: Node2D = $UltimateVfxContainer
@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	randomize()
	_ensure_input_actions()
	_build_ultimate_vfx_material()
	_apply_selected_character_ultimate_cutin()
	_build_background()
	_build_ui()

	player.fireball_requested.connect(_spawn_fireball)
	player.health_changed.connect(_on_player_health_changed)
	player.experience_changed.connect(_on_player_experience_changed)
	player.defense_status_changed.connect(_on_player_defense_status_changed)
	player.level_up_ready.connect(_show_level_up)
	player.died.connect(_on_player_died)

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_slime)

	_on_player_health_changed(player.current_health, player.max_health)
	_on_player_experience_changed(player.experience, player.required_experience, player.level)
	_on_player_defense_status_changed(
		0.0 if player.blink_charges > 0 else player.blink_timer,
		player.blink_cooldown,
		player.blink_charges,
		player.blink_max_charges,
		player.barrier_timer,
		player.barrier_cooldown,
		player.barrier_active_timer > 0.0 and player.barrier_shield_current > 0,
		player.barrier_shield_current,
		player.barrier_shield_max
	)
	_update_ultimate_ui()


func _apply_selected_character_ultimate_cutin() -> void:
	var character := GameState.get_selected_character()
	if character.is_empty():
		return

	var cutin_path := str(character.get("ultimate_cutin_image", ""))
	if not cutin_path.is_empty():
		var selected_cutin := load(cutin_path) as Texture2D
		if selected_cutin != null:
			ultimate_cutin_texture = selected_cutin
			if ultimate_texture_rect != null:
				ultimate_texture_rect.texture = selected_cutin

	ultimate_cutin_side = str(character.get("ultimate_cutin_side", ultimate_cutin_side))
	ultimate_cutin_width_scale = float(character.get("ultimate_cutin_width_scale", ultimate_cutin_width_scale))
	ultimate_cutin_x_offset = float(character.get("ultimate_cutin_x_offset", ultimate_cutin_x_offset))


func _process(delta: float) -> void:
	if game_over:
		return

	elapsed_time += delta
	time_label.text = _format_time(elapsed_time)
	defeated_label.text = "처치: %d" % defeated_count


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ultimate"):
		_try_use_ultimate()
	elif game_over and event.is_action_pressed("ui_accept"):
		_restart_game()


func _spawn_slime() -> void:
	if game_over or get_tree().paused:
		return
	if enemy_container.get_child_count() >= max_enemies:
		return

	var slime := slime_scene.instantiate() as Slime
	var angle := randf_range(0.0, TAU)
	var spawn_position := player.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
	spawn_position.x = clampf(spawn_position.x, -world_radius, world_radius)
	spawn_position.y = clampf(spawn_position.y, -world_radius, world_radius)

	enemy_container.add_child(slime)
	slime.global_position = spawn_position
	slime.player = player
	slime.died.connect(_on_slime_died)


func _spawn_fireball(origin: Vector2, direction: Vector2, damage: int) -> void:
	if game_over or get_tree().paused:
		return

	var fireball := fireball_scene.instantiate() as Fireball
	projectile_container.add_child(fireball)
	fireball.setup(origin, direction, damage)


func _on_slime_died(spawn_position: Vector2, experience_value: int) -> void:
	defeated_count += 1
	if not ultimate_showing and not ultimate_ready:
		ultimate_kills = mini(ultimate_required_kills, ultimate_kills + 1)
		if ultimate_kills >= ultimate_required_kills:
			ultimate_ready = true
		_update_ultimate_ui()

	call_deferred("_spawn_experience_gem", spawn_position, experience_value)


func _spawn_experience_gem(spawn_position: Vector2, experience_value: int) -> void:
	if game_over:
		return

	var gem := experience_gem_scene.instantiate() as ExperienceGem
	gem_container.add_child(gem)
	gem.setup(spawn_position, experience_value)


func _try_use_ultimate() -> void:
	if game_over or ultimate_showing:
		return
	if not debug_ultimate_always_ready and not ultimate_ready:
		return

	ultimate_ready = false
	ultimate_kills = 0
	_update_ultimate_ui()
	_use_ultimate()


func _use_ultimate() -> void:
	ultimate_showing = true
	ultimate_overlay.visible = true
	_position_ultimate_cutin(true)
	get_tree().paused = true
	_play_starfall_ultimate()

	var enter_tween := create_tween()
	enter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	enter_tween.set_trans(Tween.TRANS_CUBIC)
	enter_tween.set_ease(Tween.EASE_OUT)
	enter_tween.set_parallel(true)
	enter_tween.tween_property(ultimate_texture_rect, "position", _ultimate_cutin_target_position(), 0.18)
	enter_tween.tween_property(ultimate_texture_rect, "modulate:a", 1.0, 0.18)
	await enter_tween.finished

	var hold_duration := maxf(0.0, _get_ultimate_cast_duration() - 0.18 - 0.2)
	await get_tree().create_timer(hold_duration, true, false, true).timeout

	var exit_tween := create_tween()
	exit_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	exit_tween.set_trans(Tween.TRANS_CUBIC)
	exit_tween.set_ease(Tween.EASE_IN)
	exit_tween.set_parallel(true)
	exit_tween.tween_property(ultimate_texture_rect, "position", _ultimate_cutin_hidden_position(), 0.2)
	exit_tween.tween_property(ultimate_texture_rect, "modulate:a", 0.0, 0.2)
	await exit_tween.finished

	ultimate_overlay.visible = false
	ultimate_showing = false
	get_tree().paused = false


func _get_ultimate_cast_duration() -> float:
	return ultimate_warning_duration + ultimate_impact_duration


func _play_starfall_ultimate() -> void:
	var targets := _collect_ultimate_targets()
	var impact_positions := _make_ultimate_impact_positions(targets)
	_spawn_ultimate_center_circle(player.global_position)

	for impact_position in impact_positions:
		_spawn_ultimate_warning(impact_position)

	await get_tree().create_timer(ultimate_warning_duration, true, false, true).timeout

	if impact_positions.is_empty():
		await get_tree().create_timer(ultimate_impact_duration, true, false, true).timeout
		_clear_ultimate_vfx()
		return

	_damage_ultimate_targets(targets)
	_play_ultimate_screen_flash()
	_shake_ultimate_camera()
	for impact_position in impact_positions:
		_spawn_ultimate_impact(impact_position)

	await get_tree().create_timer(ultimate_impact_duration, true, false, true).timeout
	_clear_ultimate_vfx()


func _collect_ultimate_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		if enemy_node.global_position.distance_to(player.global_position) > ultimate_radius + ultimate_target_padding:
			continue

		targets.append(enemy_node)

	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)

	if targets.size() > ultimate_max_targets:
		targets.resize(ultimate_max_targets)

	return targets


func _make_ultimate_impact_positions(targets: Array[Node2D]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for target in targets:
		if is_instance_valid(target):
			positions.append(target.global_position)
	return positions


func _spawn_ultimate_warning(world_position: Vector2) -> void:
	if ultimate_vfx_texture != null:
		_spawn_ultimate_warning_sprite(world_position)
		return

	var circle := Line2D.new()
	circle.width = 3.0
	circle.default_color = Color(0.45, 0.8, 1.0, 0.75)
	circle.closed = true
	circle.z_index = 1
	circle.points = _make_circle_points(32.0, 36)
	circle.global_position = world_position
	ultimate_vfx_container.add_child(circle)

	var fall_line := Line2D.new()
	fall_line.width = 5.0
	fall_line.default_color = Color(0.8, 0.92, 1.0, 0.72)
	fall_line.z_index = 2
	fall_line.points = PackedVector2Array([Vector2(-70, -270), Vector2(0, -35)])
	fall_line.global_position = world_position
	ultimate_vfx_container.add_child(fall_line)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", Vector2.ONE * 1.55, ultimate_warning_duration)
	tween.tween_property(circle, "modulate:a", 0.15, ultimate_warning_duration)
	tween.tween_property(fall_line, "position", Vector2(70, 235), ultimate_warning_duration)
	tween.tween_property(fall_line, "modulate:a", 0.25, ultimate_warning_duration)


func _spawn_ultimate_impact(world_position: Vector2) -> void:
	if ultimate_vfx_texture != null:
		_spawn_ultimate_impact_sprite(world_position)
		return

	var star := Polygon2D.new()
	star.color = Color(0.9, 0.96, 1.0, 0.92)
	star.polygon = _make_star_polygon(52.0, 22.0, 8)
	star.z_index = 4
	star.global_position = world_position
	ultimate_vfx_container.add_child(star)

	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(0.55, 0.78, 1.0, 0.85)
	ring.closed = true
	ring.z_index = 3
	ring.points = _make_circle_points(18.0, 36)
	ring.global_position = world_position
	ultimate_vfx_container.add_child(ring)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(star, "scale", Vector2.ONE * 1.7, ultimate_impact_duration)
	tween.tween_property(star, "modulate:a", 0.0, ultimate_impact_duration)
	tween.tween_property(ring, "scale", Vector2.ONE * 4.0, ultimate_impact_duration)
	tween.tween_property(ring, "modulate:a", 0.0, ultimate_impact_duration)


func _damage_ultimate_targets(targets: Array[Node2D]) -> void:
	for target in targets:
		if not is_instance_valid(target):
			continue
		if target.has_method("take_damage"):
			target.take_damage(ultimate_damage)


func _clear_ultimate_vfx() -> void:
	for child in ultimate_vfx_container.get_children():
		child.queue_free()


func _build_ultimate_vfx_material() -> void:
	ultimate_vfx_material = CanvasItemMaterial.new()
	ultimate_vfx_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _spawn_ultimate_center_circle(world_position: Vector2) -> void:
	if ultimate_vfx_texture != null:
		var circle := _make_ultimate_vfx_sprite(
			world_position,
			Rect2(35, 35, 370, 255),
			0,
			Vector2.ONE * ultimate_center_circle_scale,
			Color(0.7, 0.86, 1.0, 0.0)
		)
		ultimate_vfx_container.add_child(circle)

		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_parallel(true)
		tween.tween_property(circle, "modulate:a", 0.75, ultimate_warning_duration * 0.45)
		tween.tween_property(circle, "scale", circle.scale * 1.18, ultimate_warning_duration + ultimate_impact_duration)
		tween.tween_property(circle, "modulate:a", 0.0, ultimate_impact_duration).set_delay(ultimate_warning_duration)
		return

	var circle := Line2D.new()
	circle.width = 5.0
	circle.default_color = Color(0.45, 0.8, 1.0, 0.45)
	circle.closed = true
	circle.z_index = 0
	circle.points = _make_circle_points(ultimate_radius * 0.42, 64)
	circle.global_position = world_position
	ultimate_vfx_container.add_child(circle)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", Vector2.ONE * 1.2, ultimate_warning_duration + ultimate_impact_duration)
	tween.tween_property(circle, "modulate:a", 0.0, ultimate_warning_duration + ultimate_impact_duration)


func _spawn_ultimate_warning_sprite(world_position: Vector2) -> void:
	var circle_regions: Array[Rect2] = [
		Rect2(435, 48, 145, 145),
		Rect2(590, 48, 145, 145),
		Rect2(745, 58, 135, 125),
		Rect2(450, 210, 145, 115),
		Rect2(605, 210, 145, 115),
		Rect2(760, 210, 145, 115),
	]
	var beam_regions: Array[Rect2] = [
		Rect2(935, 35, 70, 300),
		Rect2(1010, 28, 82, 310),
		Rect2(1100, 18, 88, 320),
		Rect2(1198, 12, 105, 330),
	]

	var circle := _make_ultimate_vfx_sprite(
		world_position,
		circle_regions.pick_random(),
		1,
		Vector2.ONE * randf_range(0.62, 0.82),
		Color(0.75, 0.9, 1.0, 0.0)
	)
	ultimate_vfx_container.add_child(circle)

	var beam := _make_ultimate_vfx_sprite(
		world_position + ultimate_beam_start_offset,
		beam_regions.pick_random(),
		2,
		Vector2(randf_range(0.78, 1.0), randf_range(0.95, 1.2)),
		Color(0.85, 0.95, 1.0, 0.0),
		ultimate_beam_anchor
	)
	ultimate_vfx_container.add_child(beam)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", circle.scale * 1.35, ultimate_warning_duration)
	tween.tween_property(circle, "modulate:a", 0.85, ultimate_warning_duration * 0.35)
	tween.tween_property(beam, "global_position", world_position + ultimate_beam_end_offset, ultimate_warning_duration)
	tween.tween_property(beam, "modulate:a", 0.95, ultimate_warning_duration * 0.5)
	tween.tween_property(beam, "scale", beam.scale * Vector2(1.08, 1.16), ultimate_warning_duration)


func _spawn_ultimate_impact_sprite(world_position: Vector2) -> void:
	var impact_regions: Array[Rect2] = [
		Rect2(815, 330, 315, 230),
		Rect2(1125, 330, 330, 245),
		Rect2(820, 610, 360, 360),
		Rect2(1160, 610, 365, 365),
	]
	var dust_regions: Array[Rect2] = [
		Rect2(70, 600, 235, 150),
		Rect2(330, 600, 210, 150),
		Rect2(560, 600, 210, 150),
	]
	var shard_regions: Array[Rect2] = [
		Rect2(520, 340, 160, 190),
		Rect2(600, 600, 210, 150),
		Rect2(65, 790, 210, 180),
	]

	var impact := _make_ultimate_vfx_sprite(
		world_position,
		impact_regions.pick_random(),
		4,
		Vector2.ONE * randf_range(0.72, 0.96),
		Color(0.9, 0.96, 1.0, 1.0),
		ultimate_impact_anchor
	)
	ultimate_vfx_container.add_child(impact)

	var dust := _make_ultimate_vfx_sprite(
		world_position + _make_ultimate_particle_offset(),
		dust_regions.pick_random(),
		3,
		Vector2.ONE * randf_range(0.95, 1.22),
		Color(0.75, 0.9, 1.0, 0.78)
	)
	ultimate_vfx_container.add_child(dust)

	var shards := _make_ultimate_vfx_sprite(
		world_position + _make_ultimate_particle_offset(),
		shard_regions.pick_random(),
		5,
		Vector2.ONE * randf_range(0.82, 1.08),
		Color(0.72, 0.9, 1.0, 0.82)
	)
	ultimate_vfx_container.add_child(shards)

	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(0.62, 0.84, 1.0, 0.88)
	ring.closed = true
	ring.z_index = 2
	ring.points = _make_circle_points(24.0, 48)
	ring.global_position = world_position
	ultimate_vfx_container.add_child(ring)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(impact, "scale", impact.scale * 1.22, ultimate_impact_duration)
	tween.tween_property(impact, "modulate:a", 0.0, ultimate_impact_duration)
	tween.tween_property(dust, "scale", dust.scale * 1.35, ultimate_impact_duration)
	tween.tween_property(dust, "modulate:a", 0.0, ultimate_impact_duration)
	tween.tween_property(shards, "scale", shards.scale * 1.3, ultimate_impact_duration)
	tween.tween_property(shards, "modulate:a", 0.0, ultimate_impact_duration)
	tween.tween_property(ring, "scale", Vector2.ONE * 4.4, ultimate_impact_duration)
	tween.tween_property(ring, "modulate:a", 0.0, ultimate_impact_duration)


func _make_ultimate_vfx_sprite(
	world_position: Vector2,
	region: Rect2,
	z_layer: int,
	sprite_scale: Vector2,
	color: Color,
	anchor := Vector2(0.5, 0.5),
	visual_offset := Vector2.ZERO
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ultimate_vfx_texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = true
	sprite.offset = (Vector2(0.5, 0.5) - anchor) * region.size + visual_offset
	sprite.material = ultimate_vfx_material
	sprite.z_index = z_layer
	sprite.scale = sprite_scale
	sprite.modulate = color
	sprite.global_position = world_position
	return sprite


func _make_ultimate_particle_offset() -> Vector2:
	return Vector2(
		randf_range(-ultimate_particle_spread, ultimate_particle_spread),
		randf_range(-ultimate_particle_spread, ultimate_particle_spread)
	)


func _play_ultimate_screen_flash() -> void:
	if ultimate_flash_rect == null:
		return

	ultimate_flash_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(ultimate_flash_rect, "modulate:a", ultimate_screen_flash_alpha, 0.06)
	tween.tween_property(ultimate_flash_rect, "modulate:a", 0.0, 0.18)


func _shake_ultimate_camera() -> void:
	if camera == null:
		return

	var original_offset := camera.offset
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(camera, "offset", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * ultimate_camera_shake_strength, 0.04)
	tween.tween_property(camera, "offset", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * ultimate_camera_shake_strength * 0.65, 0.05)
	tween.tween_property(camera, "offset", original_offset, 0.12)


func _make_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _make_star_polygon(outer_radius: float, inner_radius: float, points_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(points_count * 2):
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := -PI / 2.0 + PI * float(index) / float(points_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _show_level_up(new_level: int) -> void:
	level_up_title.text = "레벨 %d" % new_level
	current_level_up_options = _roll_level_up_options(3)
	for index in range(level_up_option_buttons.size()):
		var button := level_up_option_buttons[index]
		if index >= current_level_up_options.size():
			button.visible = false
			continue

		var option := current_level_up_options[index]
		button.visible = true
		button.text = "[%s] %s\n%s" % [_get_rarity_display_name(option["rarity"]), option["label"], option["description"]]
		button.modulate = _upgrade_rarity_color(option["rarity"])

	level_up_panel.visible = true
	get_tree().paused = true


func _choose_upgrade(upgrade_id: String) -> void:
	player.apply_upgrade(upgrade_id)
	level_up_panel.visible = false
	get_tree().paused = false


func _choose_level_up_option(option_index: int) -> void:
	if option_index < 0 or option_index >= current_level_up_options.size():
		return

	_choose_upgrade(current_level_up_options[option_index]["id"])


func _roll_level_up_options(count: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var used_ids: Array[String] = []

	for index in range(count):
		var rarity := _pick_upgrade_rarity()
		var candidates := _get_upgrade_candidates(rarity, used_ids)
		if candidates.is_empty():
			candidates = _get_upgrade_candidates("", used_ids)
		if candidates.is_empty():
			break

		var option: Dictionary = candidates.pick_random()
		options.append(option)
		used_ids.append(option["id"])

	return options


func _pick_upgrade_rarity() -> String:
	var roll := randf()
	if roll < 0.55:
		return "Common"
	if roll < 0.87:
		return "Rare"
	return "Epic"


func _get_upgrade_candidates(rarity: String, used_ids: Array[String]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for option in _get_upgrade_pool():
		var option_id := option["id"] as String
		if used_ids.has(option_id):
			continue
		if rarity != "" and option["rarity"] != rarity:
			continue
		if option["category"] == "character" and option["character_id"] != "mage":
			continue
		if player.has_method("can_apply_upgrade") and not player.can_apply_upgrade(option_id):
			continue
		candidates.append(option)
	return candidates


func _get_upgrade_pool() -> Array[Dictionary]:
	return [
		{
			"id": "damage",
			"label": "공격력 강화",
			"description": "파이어볼 피해 +7",
			"rarity": "Common",
			"category": "common",
			"character_id": "",
			"skill_id": "stat",
		},
		{
			"id": "attack_speed",
			"label": "공격속도 증가",
			"description": "파이어볼 재사용 대기시간 -18%",
			"rarity": "Common",
			"category": "common",
			"character_id": "",
			"skill_id": "fireball",
		},
		{
			"id": "health",
			"label": "체력 강화",
			"description": "최대 체력 +25, 체력 35 회복",
			"rarity": "Common",
			"category": "common",
			"character_id": "",
			"skill_id": "stat",
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
			"label": "스타 배리어",
			"description": "배리어 보호막 +30",
			"rarity": "Rare",
			"category": "character",
			"character_id": "mage",
			"skill_id": "barrier",
		},
		{
			"id": "mage_barrier_duration",
			"label": "배리어 지속 시간 증가",
			"description": "배리어 지속 시간 +0.45초",
			"rarity": "Rare",
			"category": "character",
			"character_id": "mage",
			"skill_id": "barrier",
		},
		{
			"id": "mage_blink_stack",
			"label": "블링크 차지",
			"description": "블링크 최대 충전 +1",
			"rarity": "Epic",
			"category": "character",
			"character_id": "mage",
			"skill_id": "blink",
		},
		{
			"id": "mage_blink_arrival_damage",
			"label": "코멧 어라이벌",
			"description": "블링크 도착 지점에 피해 35",
			"rarity": "Epic",
			"category": "character",
			"character_id": "mage",
			"skill_id": "blink",
		},
		{
			"id": "mage_barrier_explosion",
			"label": "스타 배리어 버스트",
			"description": "배리어 파괴 시 주변에 피해 50",
			"rarity": "Epic",
			"category": "character",
			"character_id": "mage",
			"skill_id": "barrier",
		},
	]


func _upgrade_rarity_color(rarity: String) -> Color:
	match rarity:
		"Rare":
			return Color(0.58, 0.82, 1.0)
		"Epic":
			return Color(0.95, 0.65, 1.0)
		_:
			return Color.WHITE


func _get_rarity_display_name(rarity: String) -> String:
	match rarity:
		"Rare":
			return "희귀"
		"Epic":
			return "에픽"
		_:
			return "일반"


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	if health_bar == null:
		return
	health_bar.max_value = max_health
	health_bar.value = current_health


func _on_player_experience_changed(current_experience: int, required_experience: int, level: int) -> void:
	if exp_bar == null:
		return
	level_label.text = "레벨 %d" % level
	exp_bar.max_value = required_experience
	exp_bar.value = current_experience


func _on_player_defense_status_changed(
	blink_remaining: float,
	blink_cooldown: float,
	blink_charges: int,
	blink_max_charges: int,
	barrier_remaining: float,
	barrier_cooldown: float,
	barrier_active: bool,
	barrier_shield_current: int,
	barrier_shield_max: int
) -> void:
	if blink_label == null or barrier_label == null:
		return

	if blink_charges > 0:
		blink_label.text = "블링크 %d/%d" % [blink_charges, blink_max_charges]
	else:
		blink_label.text = "블링크 %.1f초" % blink_remaining

	if barrier_active:
		barrier_label.text = "배리어 %d/%d" % [barrier_shield_current, barrier_shield_max]
	else:
		barrier_label.text = "배리어 준비" if barrier_remaining <= 0.0 else "배리어 %.1f초" % barrier_remaining


func _on_player_died() -> void:
	game_over = true
	spawn_timer.stop()
	final_stats_label.text = "시간 %s   처치 %d" % [_format_time(elapsed_time), defeated_count]
	game_over_panel.visible = true
	get_tree().paused = true


func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _build_background() -> void:
	if background_texture == null:
		return

	var tile_size := Vector2(background_texture.get_width(), background_texture.get_height()) * background_scale
	var tiles_each_side := int(ceil((world_radius * 2.0) / tile_size.x / 2.0)) + 1

	for y in range(-tiles_each_side, tiles_each_side + 1):
		for x in range(-tiles_each_side, tiles_each_side + 1):
			var tile := Sprite2D.new()
			tile.texture = background_texture
			tile.scale = Vector2.ONE * background_scale
			tile.position = Vector2(x * tile_size.x, y * tile_size.y)
			background.add_child(tile)


func _build_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_layer)

	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(hud)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.offset_left = 18
	top_margin.offset_top = 14
	top_margin.offset_right = -18
	top_margin.offset_bottom = 118
	hud.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top_margin.add_child(top_row)

	var bars := VBoxContainer.new()
	bars.custom_minimum_size = Vector2(360, 92)
	top_row.add_child(bars)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(360, 24)
	health_bar.show_percentage = false
	health_bar.modulate = Color(1.0, 0.35, 0.35)
	bars.add_child(health_bar)

	exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(360, 18)
	exp_bar.show_percentage = false
	exp_bar.modulate = Color(0.4, 0.85, 1.0)
	bars.add_child(exp_bar)

	ultimate_bar = ProgressBar.new()
	ultimate_bar.custom_minimum_size = Vector2(360, 18)
	ultimate_bar.show_percentage = false
	ultimate_bar.modulate = Color(0.95, 0.75, 1.0)
	bars.add_child(ultimate_bar)

	level_label = Label.new()
	level_label.custom_minimum_size = Vector2(110, 24)
	top_row.add_child(level_label)

	time_label = Label.new()
	time_label.custom_minimum_size = Vector2(90, 24)
	top_row.add_child(time_label)

	defeated_label = Label.new()
	defeated_label.custom_minimum_size = Vector2(150, 24)
	top_row.add_child(defeated_label)

	ultimate_label = Label.new()
	ultimate_label.custom_minimum_size = Vector2(180, 24)
	top_row.add_child(ultimate_label)

	blink_label = Label.new()
	blink_label.custom_minimum_size = Vector2(120, 24)
	top_row.add_child(blink_label)

	barrier_label = Label.new()
	barrier_label.custom_minimum_size = Vector2(130, 24)
	top_row.add_child(barrier_label)

	_build_level_up_panel(hud)
	_build_game_over_panel(hud)
	_build_ultimate_overlay(hud)


func _build_level_up_panel(parent: Control) -> void:
	level_up_panel = PanelContainer.new()
	level_up_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_panel.visible = false
	level_up_panel.custom_minimum_size = Vector2(520, 340)
	level_up_panel.set_anchors_preset(Control.PRESET_CENTER)
	level_up_panel.offset_left = -260
	level_up_panel.offset_top = -170
	level_up_panel.offset_right = 260
	level_up_panel.offset_bottom = 170
	parent.add_child(level_up_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	level_up_panel.add_child(content)

	level_up_title = Label.new()
	level_up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(level_up_title)

	level_up_option_buttons.clear()
	for index in range(3):
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(470, 66)
		button.pressed.connect(_choose_level_up_option.bind(index))
		level_up_option_buttons.append(button)
		content.add_child(button)


func _build_game_over_panel(parent: Control) -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_panel.visible = false
	game_over_panel.custom_minimum_size = Vector2(360, 190)
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.offset_left = -180
	game_over_panel.offset_top = -95
	game_over_panel.offset_right = 180
	game_over_panel.offset_bottom = 95
	parent.add_child(game_over_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	game_over_panel.add_child(content)

	var title := Label.new()
	title.text = "게임 오버"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	final_stats_label = Label.new()
	final_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(final_stats_label)

	var restart_button := Button.new()
	restart_button.text = "다시 시작"
	restart_button.custom_minimum_size = Vector2(240, 44)
	restart_button.pressed.connect(_restart_game)
	content.add_child(restart_button)


func _build_ultimate_overlay(parent: Control) -> void:
	ultimate_overlay = Control.new()
	ultimate_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ultimate_overlay.visible = false
	ultimate_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(ultimate_overlay)

	ultimate_flash_rect = ColorRect.new()
	ultimate_flash_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	ultimate_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_flash_rect.color = Color(0.45, 0.7, 1.0, 1.0)
	ultimate_flash_rect.modulate.a = 0.0
	ultimate_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ultimate_overlay.add_child(ultimate_flash_rect)

	ultimate_texture_rect = TextureRect.new()
	ultimate_texture_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	ultimate_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_texture_rect.texture = ultimate_cutin_texture
	ultimate_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	ultimate_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ultimate_texture_rect.modulate.a = 0.0
	ultimate_overlay.add_child(ultimate_texture_rect)


func _position_ultimate_cutin(hidden: bool) -> void:
	var viewport_size := get_viewport_rect().size
	var cutin_width := minf(700.0, viewport_size.x * 0.52) * ultimate_cutin_width_scale
	ultimate_texture_rect.size = Vector2(cutin_width, viewport_size.y)
	ultimate_texture_rect.position = _ultimate_cutin_hidden_position() if hidden else _ultimate_cutin_target_position()
	ultimate_texture_rect.modulate.a = 0.0 if hidden else 1.0


func _ultimate_cutin_hidden_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var x := viewport_size.x
	if ultimate_cutin_side == "left":
		x = -ultimate_texture_rect.size.x
	return Vector2(x, 0.0)


func _ultimate_cutin_target_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var x := viewport_size.x - ultimate_texture_rect.size.x + ultimate_cutin_x_offset
	if ultimate_cutin_side == "left":
		x = -ultimate_cutin_x_offset
	return Vector2(x, 0.0)


func _update_ultimate_ui() -> void:
	if ultimate_bar == null:
		return

	ultimate_bar.max_value = ultimate_required_kills
	ultimate_bar.value = ultimate_required_kills if ultimate_ready else ultimate_kills
	ultimate_label.text = "궁극기 준비: Q" if ultimate_ready else "궁극기: %d/%d" % [ultimate_kills, ultimate_required_kills]


func _format_time(seconds: float) -> String:
	var total_seconds := int(seconds)
	var minutes := int(total_seconds / 60)
	var remaining_seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]


func _ensure_input_actions() -> void:
	_set_key_action("move_left", [KEY_A, KEY_LEFT])
	_set_key_action("move_right", [KEY_D, KEY_RIGHT])
	_set_key_action("move_up", [KEY_W, KEY_UP])
	_set_key_action("move_down", [KEY_S, KEY_DOWN])
	_set_key_action("ultimate", [KEY_Q])
	_set_key_action("blink", [KEY_SPACE])
	_set_key_action("barrier", [KEY_F])


func _set_key_action(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, existing_event)

	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		InputMap.action_add_event(action_name, event)
