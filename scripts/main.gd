extends Node2D

@export var slime_scene: PackedScene
@export var experience_gem_scene: PackedScene
@export var background_texture: Texture2D
@export var ultimate_cutin_texture: Texture2D
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
@export var ultimate_radius := 720.0

var elapsed_time := 0.0
var defeated_count := 0
var ultimate_kills := 0
var ultimate_ready := false
var ultimate_showing := false
var suppress_ultimate_charge := false
var game_over := false

var canvas_layer: CanvasLayer
var health_bar: ProgressBar
var exp_bar: ProgressBar
var ultimate_bar: ProgressBar
var level_label: Label
var time_label: Label
var defeated_label: Label
var ultimate_label: Label
var skill_1_label: Label
var skill_2_label: Label
var level_up_panel: PanelContainer
var level_up_title: Label
var level_up_option_buttons: Array[Button] = []
var current_level_up_options: Array[Dictionary] = []
var pending_level_up_levels: Array[int] = []
var game_over_panel: PanelContainer
var final_stats_label: Label
var ultimate_overlay: Control
var ultimate_texture_rect: TextureRect
var ultimate_flash_rect: ColorRect

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
	_apply_selected_character_ultimate_cutin()
	_build_background()
	_build_ui()

	player.projectile_requested.connect(_spawn_projectile)
	player.health_changed.connect(_on_player_health_changed)
	player.experience_changed.connect(_on_player_experience_changed)
	player.combat_status_changed.connect(_on_player_combat_status_changed)
	player.level_up_ready.connect(_queue_level_up)
	player.world_vfx_requested.connect(_add_player_world_vfx)
	player.died.connect(_on_player_died)

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_enemy)

	_on_player_health_changed(player.current_health, player.max_health)
	_on_player_experience_changed(player.experience, player.required_experience, player.level)
	_update_ultimate_ui()


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


func _spawn_enemy() -> void:
	if game_over or get_tree().paused:
		return
	if enemy_container.get_child_count() >= max_enemies:
		return

	var enemy := slime_scene.instantiate()
	var angle := randf_range(0.0, TAU)
	var spawn_position := player.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
	spawn_position.x = clampf(spawn_position.x, -world_radius, world_radius)
	spawn_position.y = clampf(spawn_position.y, -world_radius, world_radius)

	enemy_container.add_child(enemy)
	enemy.global_position = spawn_position
	if enemy.has_method("setup_player"):
		enemy.setup_player(player)
	elif enemy is Slime:
		(enemy as Slime).player = player
	if enemy.has_signal("defeated"):
		enemy.connect("defeated", _on_enemy_defeated)


func _spawn_projectile(projectile_scene: PackedScene, origin: Vector2, direction: Vector2, damage: int) -> void:
	if game_over or get_tree().paused or projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	projectile_container.add_child(projectile)
	if projectile.has_method("setup"):
		projectile.setup(origin, direction, damage)


func _on_enemy_defeated(defeat_info: Dictionary) -> void:
	var counts_as_defeat := bool(defeat_info.get("counts_as_defeat", true))
	var charges_ultimate := bool(defeat_info.get("charges_ultimate", true)) and not suppress_ultimate_charge
	var spawn_position: Vector2 = defeat_info.get("position", Vector2.ZERO)
	var experience_value := int(defeat_info.get("experience_value", 0))

	if counts_as_defeat:
		defeated_count += 1
	if charges_ultimate and not ultimate_showing and not ultimate_ready:
		ultimate_kills = mini(ultimate_required_kills, ultimate_kills + 1)
		if ultimate_kills >= ultimate_required_kills:
			ultimate_ready = true
		_update_ultimate_ui()

	if experience_value > 0:
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

	var enter_tween := create_tween()
	enter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	enter_tween.set_trans(Tween.TRANS_CUBIC)
	enter_tween.set_ease(Tween.EASE_OUT)
	enter_tween.set_parallel(true)
	enter_tween.tween_property(ultimate_texture_rect, "position", _ultimate_cutin_target_position(), 0.18)
	enter_tween.tween_property(ultimate_texture_rect, "modulate:a", 1.0, 0.18)
	await enter_tween.finished

	await get_tree().create_timer(1.25, true, false, true).timeout

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
	_play_ultimate_screen_flash()
	_shake_ultimate_camera()
	suppress_ultimate_charge = true
	player.use_ultimate(_make_ultimate_context())
	await get_tree().process_frame
	suppress_ultimate_charge = false


func _make_ultimate_context() -> Dictionary:
	return {
		"origin": player.global_position,
		"targets": _collect_ultimate_targets(),
		"damage": ultimate_damage,
		"radius": ultimate_radius,
	}


func _collect_ultimate_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		if enemy_node.global_position.distance_to(player.global_position) > ultimate_radius:
			continue

		targets.append(enemy_node)

	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)

	if targets.size() > ultimate_max_targets:
		targets.resize(ultimate_max_targets)

	return targets


func _queue_level_up(new_level: int) -> void:
	pending_level_up_levels.append(new_level)
	if level_up_panel == null or level_up_panel.visible:
		return

	_show_next_level_up()


func _show_next_level_up() -> void:
	if pending_level_up_levels.is_empty():
		return

	var new_level: int = pending_level_up_levels.pop_front()
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
	if pending_level_up_levels.is_empty():
		level_up_panel.visible = false
		get_tree().paused = false
	else:
		_show_next_level_up()


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
	var selected_character_id := str(GameState.get_selected_character().get("id", GameState.selected_character_id))
	for option in _get_upgrade_pool():
		var option_id := option["id"] as String
		if used_ids.has(option_id):
			continue
		if rarity != "" and option["rarity"] != rarity:
			continue
		if option["category"] == "character" and option["character_id"] != selected_character_id:
			continue
		if player.has_method("can_apply_upgrade") and not player.can_apply_upgrade(option_id):
			continue
		candidates.append(option)
	return candidates


func _get_upgrade_pool() -> Array[Dictionary]:
	var upgrades: Array[Dictionary] = [
		{
			"id": "health",
			"label": "체력 강화",
			"description": "최대 체력 +25, 체력 35 회복",
			"rarity": "Common",
			"category": "common",
			"character_id": "",
			"skill_id": "stat",
		},
	]
	upgrades.append_array(player.get_combat_upgrade_pool())
	return upgrades


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
			return "영웅"
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


func _on_player_combat_status_changed(skill_1_text: String, skill_2_text: String) -> void:
	if skill_1_label == null or skill_2_label == null:
		return

	skill_1_label.text = skill_1_text
	skill_2_label.text = skill_2_text


func _on_player_died() -> void:
	game_over = true
	spawn_timer.stop()
	final_stats_label.text = "시간 %s   처치 %d" % [_format_time(elapsed_time), defeated_count]
	game_over_panel.visible = true
	get_tree().paused = true


func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _add_player_world_vfx(vfx: Node2D) -> void:
	if vfx == null:
		return

	ultimate_vfx_container.add_child(vfx)


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

	skill_1_label = Label.new()
	skill_1_label.custom_minimum_size = Vector2(130, 24)
	top_row.add_child(skill_1_label)

	skill_2_label = Label.new()
	skill_2_label.custom_minimum_size = Vector2(130, 24)
	top_row.add_child(skill_2_label)

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


func _play_ultimate_screen_flash() -> void:
	if ultimate_flash_rect == null:
		return

	ultimate_flash_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(ultimate_flash_rect, "modulate:a", 0.22, 0.06)
	tween.tween_property(ultimate_flash_rect, "modulate:a", 0.0, 0.18)


func _shake_ultimate_camera() -> void:
	if camera == null:
		return

	var original_offset := camera.offset
	var tween := create_tween()
	tween.tween_property(camera, "offset", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 8.0, 0.04)
	tween.tween_property(camera, "offset", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 5.0, 0.05)
	tween.tween_property(camera, "offset", original_offset, 0.12)


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

	if not InputMap.action_get_events(action_name).is_empty():
		return

	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		InputMap.action_add_event(action_name, event)
