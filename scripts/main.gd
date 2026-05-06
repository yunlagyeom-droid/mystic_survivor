extends Node2D

const CITY_ROAD_TOP_ROW := -4
const CITY_ROAD_BOTTOM_ROW := 2
const CITY_TOP_CURB_ROW := -5
const CITY_BOTTOM_CURB_ROW := 3
const CITY_CENTERLINE_ROW := -1
const CITY_CROSSWALK_COLUMN := -1
const GothicWidgets := preload("res://scripts/ui/in_game_gothic_widgets.gd")
const HUNTER_HUD_PORTRAIT_PATH := "res://assets/ui/hud/hunter_hud_portrait_face_v1.png"
const DarkRuinsStageBuilder := preload("res://scripts/stages/dark_ruins_stage.gd")
const SETTINGS_PATH := "user://settings.cfg"
const SFX_BUS_NAME := "SFX"
const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

@export var bone_runner_scene: PackedScene
@export var grave_brute_scene: PackedScene
@export var hex_caster_scene: PackedScene
@export var ruin_warden_scene: PackedScene
@export var twin_wizard_primary_scene: PackedScene
@export var twin_wizard_support_scene: PackedScene
@export var experience_gem_scene: PackedScene
@export var obstacle_scenes: Array[PackedScene] = []
@export var use_dark_ruins_stage := true
@export var background_texture: Texture2D
@export var city_tile_set: TileSet
@export var use_city_tilemap := true
@export var city_master_texture: Texture2D
@export var road_background_textures: Array[Texture2D] = []
@export var sidewalk_background_texture: Texture2D
@export var curb_north_background_texture: Texture2D
@export var curb_south_background_texture: Texture2D
@export var ultimate_cutin_texture: Texture2D
@export var spawn_distance := 760.0
@export var spawn_interval := 0.3
@export var max_enemies := 400
@export var world_radius := 2600.0
@export var world_bounds := Vector2.ZERO
@export var world_edge_margin := 80.0
@export var pressure_phase_time := 70.0
@export var boss_phase_time := 150.0
@export var stage_duration := 60.0
@export var background_scale := 0.82
@export var ultimate_required_kills := 10
@export var debug_ultimate_always_ready := true
@export var ultimate_cutin_side := "right"
@export var ultimate_cutin_width_scale := 0.75
@export var ultimate_cutin_x_offset := 96.0
@export var ultimate_damage := 120
@export var ultimate_max_targets := 36
@export var ultimate_radius := 720.0
@export var show_experiment_mode_button := true
@export var show_dev_upgrade_tools := true

var elapsed_time := 0.0
var defeated_count := 0
var ultimate_kills := 0
var ultimate_charge_remainder := 0.0
var ultimate_ready := false
var ultimate_showing := false
var suppress_ultimate_charge := false
var ultimate_cooldown_visual_duration := 4.0
var ultimate_cooldown_visual_timer := 0.0
var experiment_mode := false
var game_over := false
var stage_cleared := false
var wave_time := 0.0
var stage_phase := 0
var stage_index := 1
var stage_time := 0.0
var stage_state := "wave"
var boss_spawned := false
var active_bosses := 0
var current_enemy_pool: Array[PackedScene] = []
var background_world_rect := Rect2()
var playable_world_rect := Rect2()

var canvas_layer: CanvasLayer
var health_bar
var exp_bar
var ultimate_bar: ProgressBar
var ultimate_portrait_ring
var level_label: Label
var time_label: Label
var defeated_label: Label
var ultimate_label: Label
var skill_1_label: Label
var skill_2_label: Label
var skill_3_label: Label
var hunter_skill_slots_panel: Control
var hunter_skill_slots: Array = []
var experiment_mode_button: Button
var dev_upgrade_panel: PanelContainer
var dev_upgrade_selector: OptionButton
var dev_upgrade_count_spinbox: SpinBox
var dev_upgrade_status_label: Label
var dev_upgrade_ids: Array[String] = []
var dev_upgrade_focus_release_token := 0
var boss_health_panel: PanelContainer
var boss_health_rows: Array[Dictionary] = []
var settings_panel: PanelContainer
var settings_resolution_option: OptionButton
var settings_fullscreen_check: CheckBox
var settings_master_slider: HSlider
var settings_sfx_slider: HSlider
var settings_master_value_label: Label
var settings_sfx_value_label: Label
var settings_was_paused := false
var settings_resolution_index := 2
var settings_fullscreen := false
var settings_master_volume := 1.0
var settings_sfx_volume := 1.0
var level_up_panel: Control
var level_up_title: Label
var level_up_option_buttons: Array[Button] = []
var current_level_up_options: Array[Dictionary] = []
var pending_level_up_levels: Array[int] = []
var game_over_panel: PanelContainer
var game_over_title_label: Label
var final_stats_label: Label
var ultimate_overlay: Control
var ultimate_texture_rect: TextureRect
var ultimate_flash_rect: ColorRect
var ultimate_prime_sfx: AudioStream
var ultimate_impact_sfx: AudioStream
var ultimate_prime_vfx_sheet: Texture2D
var ultimate_impact_vfx_sheet: Texture2D
var ultimate_activation_vfx_material: CanvasItemMaterial

@onready var background: Node2D = $Background
@onready var city_tile_map: TileMapLayer = $Background/CityTileMap
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var enemy_container: Node2D = $EnemyContainer
@onready var obstacle_container: Node2D = $ObstacleContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var gem_container: Node2D = $GemContainer
@onready var ultimate_vfx_container: Node2D = $UltimateVfxContainer
@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	randomize()
	_ensure_input_actions()
	_ensure_audio_buses()
	_load_settings()
	_apply_audio_settings()
	_apply_display_settings()
	_apply_selected_character_ultimate_cutin()
	_apply_selected_character_ultimate_assets()
	_build_background()
	_build_obstacles()
	_build_ui()
	_update_stage_phase()

	player.projectile_requested.connect(_spawn_projectile)
	player.health_changed.connect(_on_player_health_changed)
	player.experience_changed.connect(_on_player_experience_changed)
	player.combat_status_changed.connect(_on_player_combat_status_changed)
	player.level_up_ready.connect(_queue_level_up)
	player.world_vfx_requested.connect(_add_player_world_vfx)
	player.died.connect(_on_player_died)
	player.world_radius = world_radius
	player.world_bounds = _get_world_bounds()

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_enemy)

	_on_player_health_changed(player.current_health, player.max_health)
	_on_player_experience_changed(player.experience, player.required_experience, player.level)
	_update_ultimate_ui()
	_update_hunter_skill_slots()


func _process(delta: float) -> void:
	if game_over:
		return

	if not experiment_mode:
		elapsed_time += delta
		wave_time += delta
		stage_time += delta
		_update_stage_phase()
	if ultimate_cooldown_visual_timer > 0.0:
		ultimate_cooldown_visual_timer = maxf(0.0, ultimate_cooldown_visual_timer - delta)
		_update_ultimate_ui()
	time_label.text = _format_time(elapsed_time)
	defeated_label.text = "처치: %d" % defeated_count
	_update_hunter_skill_slots()
	_update_boss_health_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("settings"):
		_toggle_settings_panel()
	elif event.is_action_pressed("dev_experiment_mode"):
		_set_experiment_mode(not experiment_mode)
	elif event.is_action_pressed("ultimate"):
		_try_use_ultimate()
	elif game_over and event.is_action_pressed("ui_accept"):
		_restart_game()


func _spawn_enemy() -> void:
	if game_over or get_tree().paused or experiment_mode:
		return
	if stage_state != "wave" or boss_spawned:
		return
	if enemy_container.get_child_count() >= max_enemies:
		return

	var enemy_scene := _pick_enemy_scene()
	if enemy_scene == null:
		return

	var enemy := enemy_scene.instantiate()
	var angle := randf_range(0.0, TAU)
	var spawn_position := player.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
	spawn_position = _clamp_to_world_bounds(spawn_position)

	_add_enemy(enemy, spawn_position)


func _pick_enemy_scene() -> PackedScene:
	if current_enemy_pool.is_empty():
		_update_stage_phase()
	if current_enemy_pool.is_empty():
		return null

	var roll := randf()
	if stage_index <= 1:
		return bone_runner_scene
	if stage_index == 2:
		if roll < 0.72:
			return bone_runner_scene
		return grave_brute_scene
	if stage_index == 3:
		if roll < 0.55:
			return bone_runner_scene
		if roll < 0.78:
			return grave_brute_scene
		return hex_caster_scene

	if roll < 0.46:
		return bone_runner_scene
	if roll < 0.72:
		return grave_brute_scene
	return hex_caster_scene


func _add_enemy(enemy: Node, spawn_position: Vector2) -> void:
	if enemy == null:
		return

	enemy_container.add_child(enemy)
	var enemy_node := enemy as Node2D
	if enemy_node != null:
		enemy_node.global_position = spawn_position
	if enemy.has_method("setup_player"):
		enemy.setup_player(player)
	if enemy.has_signal("defeated"):
		enemy.connect("defeated", _on_enemy_defeated)


func _update_stage_phase() -> void:
	if not use_dark_ruins_stage:
		current_enemy_pool = []
		return

	if stage_state != "wave":
		return

	if stage_index <= 3 and stage_time >= stage_duration:
		_advance_stage()
		return

	match stage_index:
		1:
			stage_phase = 0
			current_enemy_pool = [bone_runner_scene]
			_set_spawn_interval(0.24)
		2:
			stage_phase = 1
			current_enemy_pool = [bone_runner_scene, grave_brute_scene]
			_set_spawn_interval(0.22)
		3:
			stage_phase = 2
			current_enemy_pool = [bone_runner_scene, grave_brute_scene, hex_caster_scene]
			_set_spawn_interval(0.2)
		_:
			stage_phase = 2
			current_enemy_pool = [bone_runner_scene, grave_brute_scene, hex_caster_scene]


func _advance_stage() -> void:
	stage_index += 1
	stage_time = 0.0
	wave_time = 0.0
	if stage_index <= 3:
		_update_stage_phase()
		return
	if stage_index == 4:
		_spawn_stage_4_miniboss()
		return
	if stage_index == 5:
		_spawn_twin_bosses()


func _spawn_boss() -> void:
	_spawn_stage_4_miniboss()


func _spawn_stage_4_miniboss() -> void:
	if ruin_warden_scene == null or player == null:
		return
	stage_state = "boss"
	boss_spawned = true
	active_bosses = 1
	if spawn_timer != null:
		spawn_timer.stop()
	_clear_current_enemies()

	var boss := ruin_warden_scene.instantiate()
	var spawn_position := player.global_position + Vector2(0.0, -520.0)
	spawn_position = _clamp_to_world_bounds(spawn_position)
	_add_enemy(boss, spawn_position)


func _spawn_twin_bosses() -> void:
	if twin_wizard_primary_scene == null or twin_wizard_support_scene == null or player == null:
		return
	stage_state = "boss"
	boss_spawned = true
	active_bosses = 2
	if spawn_timer != null:
		spawn_timer.stop()
	_clear_current_enemies()

	var left_position := _clamp_to_world_bounds(player.global_position + Vector2(-360.0, -360.0))
	var right_position := _clamp_to_world_bounds(player.global_position + Vector2(360.0, -360.0))
	_add_enemy(twin_wizard_primary_scene.instantiate(), left_position)
	_add_enemy(twin_wizard_support_scene.instantiate(), right_position)


func _clear_current_enemies() -> void:
	for child in enemy_container.get_children():
		child.queue_free()


func _set_spawn_interval(next_interval: float) -> void:
	if spawn_timer == null:
		return
	if absf(spawn_timer.wait_time - next_interval) < 0.001:
		return
	spawn_timer.wait_time = next_interval


func _get_world_bounds() -> Vector2:
	if playable_world_rect.size.x > 0.0 and playable_world_rect.size.y > 0.0:
		return playable_world_rect.size * 0.5
	if world_bounds.x > 0.0 and world_bounds.y > 0.0:
		return world_bounds
	return Vector2.ONE * world_radius


func _clamp_to_world_bounds(world_position: Vector2) -> Vector2:
	if playable_world_rect.size.x > 0.0 and playable_world_rect.size.y > 0.0:
		return Vector2(
			clampf(world_position.x, playable_world_rect.position.x, playable_world_rect.end.x),
			clampf(world_position.y, playable_world_rect.position.y, playable_world_rect.end.y)
		)

	var bounds := _get_world_bounds()
	return Vector2(
		clampf(world_position.x, -bounds.x, bounds.x),
		clampf(world_position.y, -bounds.y, bounds.y)
	)


func _spawn_projectile(projectile_scene: PackedScene, origin: Vector2, direction: Vector2, damage: int, params: Dictionary) -> void:
	if game_over or get_tree().paused or projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	projectile_container.add_child(projectile)
	if projectile.has_method("setup"):
		projectile.setup(origin, direction, damage, params)


func _on_enemy_defeated(defeat_info: Dictionary) -> void:
	var counts_as_defeat := bool(defeat_info.get("counts_as_defeat", true))
	var charges_ultimate := bool(defeat_info.get("charges_ultimate", true)) and not suppress_ultimate_charge
	var spawn_position: Vector2 = defeat_info.get("position", Vector2.ZERO)
	var experience_value := int(defeat_info.get("experience_value", 0))
	var is_boss := bool(defeat_info.get("is_boss", false))

	if counts_as_defeat:
		defeated_count += 1
	if charges_ultimate and not ultimate_showing and not ultimate_ready:
		var charge_gain := 1.0
		if player != null and player.has_method("get_ultimate_charge_multiplier"):
			charge_gain = player.get_ultimate_charge_multiplier()
		var total_charge_gain := charge_gain + ultimate_charge_remainder
		var whole_charge_gain := maxi(1, int(floor(total_charge_gain)))
		ultimate_charge_remainder = total_charge_gain - float(whole_charge_gain)
		ultimate_kills = mini(ultimate_required_kills, ultimate_kills + whole_charge_gain)
		if ultimate_kills >= ultimate_required_kills:
			ultimate_ready = true
		_update_ultimate_ui()

	if experience_value > 0:
		call_deferred("_spawn_experience_gem", spawn_position, experience_value)
	if is_boss:
		call_deferred("_on_boss_defeated", defeat_info)


func _on_boss_defeated(defeat_info: Dictionary) -> void:
	if game_over:
		return

	active_bosses = maxi(0, active_bosses - 1)
	if stage_index == 4:
		stage_index = 5
		stage_time = 0.0
		wave_time = 0.0
		boss_spawned = false
		active_bosses = 0
		call_deferred("_spawn_twin_bosses")
		return

	if stage_index == 5:
		if active_bosses > 0:
			_empower_remaining_twin_bosses()
			return
		call_deferred("_on_stage_cleared")
		return

	call_deferred("_on_stage_cleared")


func _empower_remaining_twin_bosses() -> void:
	for boss in get_tree().get_nodes_in_group("twin_bosses"):
		if is_instance_valid(boss) and boss.has_method("empower_from_twin_death"):
			boss.empower_from_twin_death()


func _spawn_experience_gem(spawn_position: Vector2, experience_value: int) -> void:
	if game_over:
		return

	var gem := experience_gem_scene.instantiate() as ExperienceGem
	gem_container.add_child(gem)
	gem.setup(spawn_position, experience_value)


func _build_obstacles() -> void:
	if use_dark_ruins_stage:
		return
	if obstacle_container == null or obstacle_scenes.is_empty():
		return

	var placements := [
		{"scene_index": 0, "position": Vector2(-720, -260), "rotation": -0.08},
		{"scene_index": 1, "position": Vector2(-340, 360), "rotation": 0.04},
		{"scene_index": 1, "position": Vector2(440, -420), "rotation": -0.03},
		{"scene_index": 0, "position": Vector2(760, 250), "rotation": 0.06},
	]

	for placement in placements:
		var scene_index := int(placement["scene_index"])
		if scene_index < 0 or scene_index >= obstacle_scenes.size():
			continue

		var obstacle_scene := obstacle_scenes[scene_index]
		if obstacle_scene == null:
			continue

		var obstacle := obstacle_scene.instantiate() as Node2D
		if obstacle == null:
			continue

		obstacle_container.add_child(obstacle)
		obstacle.global_position = placement["position"]
		obstacle.rotation = float(placement["rotation"])


func _try_use_ultimate() -> void:
	if game_over or ultimate_showing:
		return
	if player != null and player.has_method("try_ultimate_recast") and player.try_ultimate_recast():
		_play_ultimate_screen_flash()
		_shake_ultimate_camera()
		return
	if not debug_ultimate_always_ready and not ultimate_ready:
		return

	ultimate_ready = false
	ultimate_kills = 0
	ultimate_charge_remainder = 0.0
	ultimate_cooldown_visual_timer = ultimate_cooldown_visual_duration
	_update_ultimate_ui()
	_use_ultimate()


func _use_ultimate() -> void:
	ultimate_showing = true
	ultimate_overlay.visible = true
	_position_ultimate_cutin(true)
	_play_ultimate_sfx(ultimate_prime_sfx, -6.0, 0.98, 1.02)
	_play_ultimate_activation_vfx(ultimate_prime_vfx_sheet, 0.78, 0.62)
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
	_play_ultimate_sfx(ultimate_impact_sfx, -4.5, 0.98, 1.02)
	_play_ultimate_activation_vfx(ultimate_impact_vfx_sheet, 1.18, 0.68)
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
	level_up_title.text = "LEVEL UP"
	current_level_up_options = _roll_level_up_options(3)
	var character := GameState.get_selected_character()
	var theme_color: Color = character.get("theme_color", Color(0.48, 0.68, 1.0))
	var accent_color: Color = character.get("accent_color", Color(0.95, 0.72, 0.46))
	for index in range(level_up_option_buttons.size()):
		var button := level_up_option_buttons[index]
		if index >= current_level_up_options.size():
			button.visible = false
			continue

		var option := current_level_up_options[index]
		button.visible = true
		button.text = ""
		if button.has_method("set_option_data"):
			button.set_option_data(option, index, theme_color, accent_color)

	level_up_panel.visible = true
	level_up_panel.modulate.a = 0.0
	get_tree().paused = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(level_up_panel, "modulate:a", 1.0, 0.16)


func _choose_upgrade(upgrade_id: String) -> void:
	player.apply_upgrade(upgrade_id)
	if pending_level_up_levels.is_empty():
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(level_up_panel, "modulate:a", 0.0, 0.12)
		await tween.finished
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
	if roll < 0.05:
		return "Legendary"
	if roll < 0.60:
		return "Common"
	if roll < 0.90:
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
	var upgrades: Array[Dictionary] = player.get_common_upgrade_pool()
	upgrades.append_array(player.get_combat_upgrade_pool())
	return upgrades


func _upgrade_rarity_color(rarity: String) -> Color:
	match rarity:
		"Rare":
			return Color(0.58, 0.82, 1.0)
		"Epic":
			return Color(0.95, 0.65, 1.0)
		"Legendary":
			return Color(1.0, 0.78, 0.22)
		_:
			return Color.WHITE


func _get_rarity_display_name(rarity: String) -> String:
	match rarity:
		"Rare":
			return "레어"
		"Epic":
			return "에픽"
		"Legendary":
			return "레전더리"
		_:
			return "노말"


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	if health_bar == null:
		return
	if health_bar.has_method("set_values"):
		health_bar.set_values(current_health, max_health)


func _on_player_experience_changed(current_experience: int, required_experience: int, level: int) -> void:
	if exp_bar == null:
		return
	level_label.text = "레벨 %d" % level
	if exp_bar.has_method("set_values"):
		exp_bar.set_values(current_experience, required_experience)


func _on_player_combat_status_changed(skill_1_text: String, skill_2_text: String, skill_3_text: String) -> void:
	if skill_1_label == null or skill_2_label == null or skill_3_label == null:
		return

	skill_1_label.text = skill_1_text
	skill_2_label.text = skill_2_text
	skill_3_label.text = skill_3_text


func _update_hunter_skill_slots() -> void:
	if hunter_skill_slots_panel == null or not hunter_skill_slots_panel.visible:
		return
	if player == null or not player.has_method("get_hud_skill_slots"):
		return

	var slot_states: Array = player.get_hud_skill_slots()
	for index in range(hunter_skill_slots.size()):
		if index >= slot_states.size():
			continue
		var slot = hunter_skill_slots[index]
		if slot == null or not slot.has_method("set_slot_state"):
			continue
		var state: Dictionary = slot_states[index]
		slot.set_slot_state(
			float(state.get("cooldown_remaining", 0.0)),
			float(state.get("cooldown_total", 1.0)),
			bool(state.get("ready", true)),
			bool(state.get("active", false)),
			bool(state.get("locked", false)),
			int(state.get("charges", -1)),
			int(state.get("max_charges", -1))
		)


func _on_player_died() -> void:
	game_over = true
	stage_cleared = false
	spawn_timer.stop()
	if game_over_title_label != null:
		game_over_title_label.text = "게임 오버"
	final_stats_label.text = "시간 %s   처치 %d" % [_format_time(elapsed_time), defeated_count]
	game_over_panel.visible = true
	get_tree().paused = true


func _on_stage_cleared() -> void:
	if game_over:
		return
	game_over = true
	stage_cleared = true
	if spawn_timer != null:
		spawn_timer.stop()
	if game_over_title_label != null:
		game_over_title_label.text = "STAGE CLEAR"
	if final_stats_label != null:
		final_stats_label.text = "시간 %s   처치 %d" % [_format_time(elapsed_time), defeated_count]
	if game_over_panel != null:
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


func _apply_selected_character_ultimate_assets() -> void:
	var character := GameState.get_selected_character()
	if character.is_empty():
		return

	ultimate_prime_sfx = _load_optional_audio(str(character.get("ultimate_prime_sfx", "")))
	ultimate_impact_sfx = _load_optional_audio(str(character.get("ultimate_impact_sfx", "")))
	ultimate_prime_vfx_sheet = _load_optional_texture(str(character.get("ultimate_prime_vfx_sheet", "")))
	ultimate_impact_vfx_sheet = _load_optional_texture(str(character.get("ultimate_impact_vfx_sheet", "")))


func _load_optional_audio(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _load_optional_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(SFX_BUS_NAME) != -1:
		return

	AudioServer.add_bus()
	var sfx_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(sfx_index, SFX_BUS_NAME)
	AudioServer.set_bus_send(sfx_index, "Master")


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	settings_resolution_index = clampi(int(config.get_value("display", "resolution_index", settings_resolution_index)), 0, RESOLUTION_OPTIONS.size() - 1)
	settings_fullscreen = bool(config.get_value("display", "fullscreen", settings_fullscreen))
	settings_master_volume = clampf(float(config.get_value("audio", "master_volume", settings_master_volume)), 0.0, 1.0)
	settings_sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", settings_sfx_volume)), 0.0, 1.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "resolution_index", settings_resolution_index)
	config.set_value("display", "fullscreen", settings_fullscreen)
	config.set_value("audio", "master_volume", settings_master_volume)
	config.set_value("audio", "sfx_volume", settings_sfx_volume)
	config.save(SETTINGS_PATH)


func _apply_audio_settings() -> void:
	_ensure_audio_buses()
	_set_bus_volume("Master", settings_master_volume)
	_set_bus_volume(SFX_BUS_NAME, settings_sfx_volume)


func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, linear_value <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(linear_value, 0.001, 1.0)))


func _apply_display_settings() -> void:
	var resolution: Vector2i = RESOLUTION_OPTIONS[clampi(settings_resolution_index, 0, RESOLUTION_OPTIONS.size() - 1)]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not settings_fullscreen:
		DisplayServer.window_set_size(resolution)
		var screen_position := DisplayServer.screen_get_position()
		var screen_size := DisplayServer.screen_get_size()
		var centered_position := screen_position + Vector2i(
			int((screen_size.x - resolution.x) * 0.5),
			int((screen_size.y - resolution.y) * 0.5)
		)
		DisplayServer.window_set_position(centered_position)


func _toggle_settings_panel() -> void:
	if settings_panel != null and settings_panel.visible:
		_close_settings_panel()
	else:
		_open_settings_panel()


func _open_settings_panel() -> void:
	if settings_panel == null or game_over or ultimate_showing:
		return
	settings_was_paused = get_tree().paused
	get_tree().paused = true
	settings_panel.visible = true
	settings_panel.move_to_front()
	_sync_settings_controls()


func _close_settings_panel() -> void:
	if settings_panel == null:
		return
	settings_panel.visible = false
	if not settings_was_paused and not game_over:
		get_tree().paused = false


func _sync_settings_controls() -> void:
	if settings_resolution_option != null:
		settings_resolution_option.select(clampi(settings_resolution_index, 0, RESOLUTION_OPTIONS.size() - 1))
	if settings_fullscreen_check != null:
		settings_fullscreen_check.button_pressed = settings_fullscreen
	if settings_master_slider != null:
		settings_master_slider.set_value_no_signal(settings_master_volume)
	if settings_sfx_slider != null:
		settings_sfx_slider.set_value_no_signal(settings_sfx_volume)
	_update_settings_volume_labels()


func _apply_settings_from_panel() -> void:
	if settings_resolution_option != null:
		settings_resolution_index = clampi(settings_resolution_option.selected, 0, RESOLUTION_OPTIONS.size() - 1)
	if settings_fullscreen_check != null:
		settings_fullscreen = settings_fullscreen_check.button_pressed
	settings_master_volume = float(settings_master_slider.value) if settings_master_slider != null else settings_master_volume
	settings_sfx_volume = float(settings_sfx_slider.value) if settings_sfx_slider != null else settings_sfx_volume
	_apply_audio_settings()
	_apply_display_settings()
	_save_settings()


func _on_master_volume_changed(value: float) -> void:
	settings_master_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_update_settings_volume_labels()


func _on_sfx_volume_changed(value: float) -> void:
	settings_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_update_settings_volume_labels()


func _update_settings_volume_labels() -> void:
	if settings_master_value_label != null:
		settings_master_value_label.text = "%d%%" % int(round(settings_master_volume * 100.0))
	if settings_sfx_value_label != null:
		settings_sfx_value_label.text = "%d%%" % int(round(settings_sfx_volume * 100.0))


func _build_background() -> void:
	if use_dark_ruins_stage:
		var dark_stage := DarkRuinsStageBuilder.new()
		var stage_rect := dark_stage.build(background, obstacle_container, world_bounds)
		if stage_rect.size.x > 0.0 and stage_rect.size.y > 0.0:
			_set_world_rects_from_background(stage_rect)
		return

	if use_city_tilemap and city_tile_set != null and city_tile_map != null:
		_build_city_tilemap_background()
		return

	if city_master_texture != null:
		_build_city_master_background()
		return

	if not road_background_textures.is_empty() and sidewalk_background_texture != null:
		_build_quarter_view_city_background()
		return

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


func _set_world_rects_from_background(stage_rect: Rect2) -> void:
	background_world_rect = stage_rect
	var margin := maxf(0.0, world_edge_margin)
	var playable_size := background_world_rect.size - Vector2.ONE * margin * 2.0
	if playable_size.x <= 0.0 or playable_size.y <= 0.0:
		playable_world_rect = background_world_rect
	else:
		playable_world_rect = Rect2(background_world_rect.position + Vector2.ONE * margin, playable_size)

	world_bounds = playable_world_rect.size * 0.5
	world_radius = maxf(world_bounds.x, world_bounds.y)
	if player != null:
		player.world_bounds = world_bounds
		player.world_radius = world_radius
		player.global_position = _clamp_to_world_bounds(player.global_position)
	_apply_camera_limits(background_world_rect)


func _apply_camera_limits(stage_rect: Rect2) -> void:
	if camera == null:
		return

	camera.limit_left = int(floor(stage_rect.position.x))
	camera.limit_top = int(floor(stage_rect.position.y))
	camera.limit_right = int(ceil(stage_rect.end.x))
	camera.limit_bottom = int(ceil(stage_rect.end.y))


func _build_city_tilemap_background() -> void:
	city_tile_map.clear()
	city_tile_map.tile_set = city_tile_set
	city_tile_map.scale = Vector2.ONE * background_scale

	var tile_size := Vector2(city_tile_set.tile_size)
	var step_x := tile_size.x * 0.5 * background_scale
	var step_y := tile_size.y * 0.5 * background_scale
	var tile_extent := tile_size * background_scale
	var columns_each_side := int(ceil(world_radius / step_x)) + 6
	var rows_each_side := int(ceil(world_radius / step_y)) + 6

	for y in range(-rows_each_side, rows_each_side + 1):
		for x in range(-columns_each_side, columns_each_side + 1):
			var cell := Vector2i(x, y)
			var tile_center := city_tile_map.map_to_local(cell) * background_scale
			if absf(tile_center.x) > world_radius + tile_extent.x or absf(tile_center.y) > world_radius + tile_extent.y:
				continue

			var atlas_coords := _pick_city_tilemap_atlas_coords(cell)
			city_tile_map.set_cell(cell, 0, atlas_coords)


func _pick_city_tilemap_atlas_coords(cell: Vector2i) -> Vector2i:
	if cell.y == CITY_TOP_CURB_ROW:
		return Vector2i(0, 2)
	if cell.y == CITY_BOTTOM_CURB_ROW:
		return Vector2i(1, 2)

	if cell.y < CITY_TOP_CURB_ROW or cell.y > CITY_BOTTOM_CURB_ROW:
		return _pick_city_sidewalk_atlas_coords(cell)

	if _is_city_crosswalk_cell(cell):
		return Vector2i(cell.x - (CITY_CROSSWALK_COLUMN - 1), 1)

	if cell.y >= CITY_ROAD_TOP_ROW and cell.y <= CITY_ROAD_BOTTOM_ROW:
		if cell.y == CITY_CENTERLINE_ROW and not _is_city_centerline_break(cell):
			return Vector2i(3 + _positive_mod(cell.x, 2), 0)

		var detail_tile := _pick_city_authored_detail_atlas_coords(cell)
		if detail_tile != Vector2i(-1, -1):
			return detail_tile

		return _pick_city_road_base_atlas_coords(cell)

	return _pick_city_sidewalk_atlas_coords(cell)


func _is_city_crosswalk_cell(cell: Vector2i) -> bool:
	return (
		cell.y == CITY_CENTERLINE_ROW
		and cell.x >= CITY_CROSSWALK_COLUMN - 1
		and cell.x <= CITY_CROSSWALK_COLUMN + 1
	)


func _is_city_centerline_break(cell: Vector2i) -> bool:
	return cell.x >= CITY_CROSSWALK_COLUMN - 1 and cell.x <= CITY_CROSSWALK_COLUMN + 1


func _pick_city_authored_detail_atlas_coords(cell: Vector2i) -> Vector2i:
	if cell == Vector2i(-7, -2) or cell == Vector2i(8, 1):
		return Vector2i(2, 2)
	if cell == Vector2i(5, -3):
		return Vector2i(3, 2)
	if cell == Vector2i(-11, 1) or cell == Vector2i(12, -1):
		return Vector2i(4, 2)
	if cell == Vector2i(-9, 5) or cell == Vector2i(7, -7):
		return Vector2i(5, 2)
	return Vector2i(-1, -1)


func _pick_city_road_base_atlas_coords(cell: Vector2i) -> Vector2i:
	return Vector2i(_positive_mod(cell.x + cell.y, 3), 0)


func _pick_city_sidewalk_atlas_coords(cell: Vector2i) -> Vector2i:
	if cell == Vector2i(-9, -8) or cell == Vector2i(10, 7):
		return Vector2i(5, 2)
	return Vector2i(3 + _positive_mod(cell.x + cell.y, 3), 1)


func _positive_mod(value: int, divisor: int) -> int:
	var result := value % divisor
	if result < 0:
		result += divisor
	return result


func _build_city_master_background() -> void:
	var patch_size := Vector2(city_master_texture.get_width(), city_master_texture.get_height()) * background_scale
	var overlap := 2.0 * background_scale
	var step := patch_size - Vector2.ONE * overlap
	var columns_each_side := int(ceil(world_radius / step.x)) + 2
	var rows_each_side := int(ceil(world_radius / step.y)) + 2

	for y in range(-rows_each_side, rows_each_side + 1):
		for x in range(-columns_each_side, columns_each_side + 1):
			var patch := Sprite2D.new()
			patch.texture = city_master_texture
			patch.scale = Vector2.ONE * background_scale
			patch.position = Vector2(x * step.x, y * step.y)
			background.add_child(patch)


func _build_quarter_view_city_background() -> void:
	var base_texture := road_background_textures[0]
	if base_texture == null:
		return

	var tile_size := Vector2(base_texture.get_width(), base_texture.get_height()) * background_scale
	var tile_overlap := 2.0 * background_scale
	var step_x := tile_size.x - tile_overlap
	var step_y := tile_size.y * 0.5 - tile_overlap
	var columns_each_side := int(ceil(world_radius / step_x)) + 8
	var rows_each_side := int(ceil(world_radius / step_y)) + 8
	var road_half_height := world_radius * 0.34
	var curb_band_height := step_y * 1.5

	for row in range(-rows_each_side, rows_each_side + 1):
		for column in range(-columns_each_side, columns_each_side + 1):
			var tile_position := Vector2(
				column * step_x + (step_x * 0.5 if row % 2 != 0 else 0.0),
				row * step_y
			)
			var texture := _pick_city_background_texture(column, row, tile_position.y, road_half_height, curb_band_height)
			if texture == null:
				continue

			var tile := Sprite2D.new()
			tile.texture = texture
			tile.scale = Vector2.ONE * background_scale
			tile.position = tile_position
			background.add_child(tile)


func _pick_city_background_texture(
	column: int,
	row: int,
	y_position: float,
	road_half_height: float,
	curb_band_height: float
) -> Texture2D:
	if y_position < -road_half_height - curb_band_height:
		return sidewalk_background_texture
	if y_position < -road_half_height:
		return curb_north_background_texture if curb_north_background_texture != null else sidewalk_background_texture
	if y_position > road_half_height + curb_band_height:
		return sidewalk_background_texture
	if y_position > road_half_height:
		return curb_south_background_texture if curb_south_background_texture != null else sidewalk_background_texture

	var pattern := absi(column * 13 + row * 7)
	if road_background_textures.size() >= 3 and pattern % 23 == 0:
		return road_background_textures[2]
	if road_background_textures.size() >= 2 and pattern % 5 == 0:
		return road_background_textures[1]
	return road_background_textures[0]


func _build_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_layer)

	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(hud)

	var character := GameState.get_selected_character()
	var theme_color: Color = character.get("theme_color", Color(0.48, 0.68, 1.0))
	var accent_color: Color = character.get("accent_color", Color(0.95, 0.72, 0.46))

	var hud_frame := Control.new()
	hud_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_frame.offset_left = 18
	hud_frame.offset_top = 18
	hud_frame.offset_right = 690
	hud_frame.offset_bottom = 160
	hud.add_child(hud_frame)

	ultimate_portrait_ring = GothicWidgets.UltimatePortraitRing.new()
	ultimate_portrait_ring.custom_minimum_size = Vector2(138, 138)
	ultimate_portrait_ring.position = Vector2(0, 0)
	ultimate_portrait_ring.size = Vector2(138, 138)
	hud_frame.add_child(ultimate_portrait_ring)
	var portrait_texture := _load_hud_portrait_texture(character)
	ultimate_portrait_ring.configure(portrait_texture, _get_hud_portrait_region(character, portrait_texture), Color(0.18, 0.62, 1.0))

	var bars := VBoxContainer.new()
	bars.position = Vector2(140, 24)
	bars.size = Vector2(460, 90)
	bars.add_theme_constant_override("separation", 8)
	hud_frame.add_child(bars)

	health_bar = GothicWidgets.GothicProgressBar.new()
	health_bar.custom_minimum_size = Vector2(460, 30)
	health_bar.configure("HP", Color(0.82, 0.05, 0.08, 0.95), accent_color)
	bars.add_child(health_bar)

	exp_bar = GothicWidgets.GothicProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(460, 26)
	exp_bar.configure("EXP", Color(0.12, 0.58, 1.0, 0.95), Color(0.2, 0.72, 1.0))
	bars.add_child(exp_bar)

	level_label = Label.new()
	level_label.position = Vector2(140, 108)
	level_label.size = Vector2(110, 30)
	level_label.add_theme_font_size_override("font_size", 25)
	level_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.68))
	hud_frame.add_child(level_label)

	ultimate_label = Label.new()
	ultimate_label.position = Vector2(258, 111)
	ultimate_label.size = Vector2(250, 26)
	ultimate_label.add_theme_font_size_override("font_size", 18)
	ultimate_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	hud_frame.add_child(ultimate_label)

	time_label = Label.new()
	time_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	time_label.offset_top = 18
	time_label.offset_bottom = 64
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 34)
	time_label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.84))
	hud.add_child(time_label)

	_build_boss_health_panel(hud)

	var right_status := VBoxContainer.new()
	right_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_status.offset_left = -430
	right_status.offset_top = 24
	right_status.offset_right = -22
	right_status.offset_bottom = 146
	right_status.add_theme_constant_override("separation", 8)
	hud.add_child(right_status)

	defeated_label = _make_hud_status_label(accent_color)
	right_status.add_child(defeated_label)

	skill_1_label = _make_hud_status_label(theme_color)
	right_status.add_child(skill_1_label)

	skill_2_label = _make_hud_status_label(theme_color)
	right_status.add_child(skill_2_label)

	skill_3_label = _make_hud_status_label(theme_color)
	right_status.add_child(skill_3_label)
	_build_hunter_skill_slots(hud, character, theme_color, accent_color)

	if show_experiment_mode_button:
		experiment_mode_button = Button.new()
		experiment_mode_button.custom_minimum_size = Vector2(118, 28)
		experiment_mode_button.focus_mode = Control.FOCUS_NONE
		experiment_mode_button.toggle_mode = true
		experiment_mode_button.text = "DEV TEST: OFF"
		experiment_mode_button.toggled.connect(_set_experiment_mode)
		experiment_mode_button.position = Vector2(520, 110)
		hud_frame.add_child(experiment_mode_button)

	_build_dev_upgrade_panel(hud)
	_build_level_up_panel(hud)
	_build_game_over_panel(hud)
	_build_settings_panel(hud)
	_build_ultimate_overlay(hud)


func _build_boss_health_panel(parent: Control) -> void:
	boss_health_panel = PanelContainer.new()
	boss_health_panel.visible = false
	boss_health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_health_panel.offset_left = 560
	boss_health_panel.offset_top = 70
	boss_health_panel.offset_right = -560
	boss_health_panel.offset_bottom = 154
	boss_health_panel.add_theme_stylebox_override("panel", _make_gothic_panel_style(Color(0.025, 0.016, 0.022, 0.78), Color(0.65, 0.28, 0.36, 0.92), 1))
	parent.add_child(boss_health_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	boss_health_panel.add_child(content)

	for index in range(2):
		var row := HBoxContainer.new()
		row.visible = false
		row.add_theme_constant_override("separation", 10)
		content.add_child(row)

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(138, 28)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.74))
		row.add_child(name_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(420, 24)
		bar.max_value = 1.0
		bar.value = 1.0
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _make_gothic_panel_style(Color(0.02, 0.01, 0.012, 0.92), Color(0.32, 0.16, 0.2, 0.95), 1))
		bar.add_theme_stylebox_override("fill", _make_gothic_panel_style(Color(0.78, 0.06, 0.1, 0.96), Color(0.95, 0.42, 0.38, 0.0), 0))
		row.add_child(bar)

		boss_health_rows.append({
			"row": row,
			"name": name_label,
			"bar": bar,
		})


func _update_boss_health_ui() -> void:
	if boss_health_panel == null:
		return

	var bosses: Array[Node] = []
	for boss in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(boss) and not boss.is_queued_for_deletion():
			bosses.append(boss)

	boss_health_panel.visible = not bosses.is_empty()
	for index in range(boss_health_rows.size()):
		var row_data: Dictionary = boss_health_rows[index]
		var row := row_data.get("row") as Control
		var name_label := row_data.get("name") as Label
		var bar := row_data.get("bar") as ProgressBar
		var has_boss := index < bosses.size()
		if row != null:
			row.visible = has_boss
		if not has_boss:
			continue

		var boss := bosses[index]
		var ratio := 1.0
		if boss.has_method("get_health_ratio"):
			ratio = float(boss.call("get_health_ratio"))
		else:
			var current_health_value: Variant = boss.get("current_health")
			var max_health_value: Variant = boss.get("max_health")
			if current_health_value != null and max_health_value != null:
				ratio = clampf(float(current_health_value) / float(maxi(1, int(max_health_value))), 0.0, 1.0)

		if name_label != null:
			name_label.text = str(boss.call("get_boss_display_name")) if boss.has_method("get_boss_display_name") else "Boss"
		if bar != null:
			bar.value = ratio


func _build_settings_panel(parent: Control) -> void:
	settings_panel = PanelContainer.new()
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_panel.visible = false
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.custom_minimum_size = Vector2(460, 390)
	settings_panel.offset_left = -230
	settings_panel.offset_top = -195
	settings_panel.offset_right = 230
	settings_panel.offset_bottom = 195
	settings_panel.add_theme_stylebox_override("panel", _make_gothic_panel_style(Color(0.025, 0.018, 0.024, 0.94), Color(0.74, 0.38, 0.34, 0.95), 2))
	parent.add_child(settings_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	settings_panel.add_child(content)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.68))
	content.add_child(title)

	settings_resolution_option = OptionButton.new()
	settings_resolution_option.focus_mode = Control.FOCUS_NONE
	for resolution in RESOLUTION_OPTIONS:
		settings_resolution_option.add_item("%d x %d" % [resolution.x, resolution.y])
	settings_resolution_option.select(clampi(settings_resolution_index, 0, RESOLUTION_OPTIONS.size() - 1))
	content.add_child(_make_settings_row("Resolution", settings_resolution_option))

	settings_fullscreen_check = CheckBox.new()
	settings_fullscreen_check.text = "Fullscreen"
	settings_fullscreen_check.focus_mode = Control.FOCUS_NONE
	settings_fullscreen_check.button_pressed = settings_fullscreen
	content.add_child(_make_settings_row("Window", settings_fullscreen_check))

	var master_row := _make_volume_row("Master")
	settings_master_slider = master_row["slider"]
	settings_master_value_label = master_row["value_label"]
	settings_master_slider.value = settings_master_volume
	settings_master_slider.value_changed.connect(_on_master_volume_changed)
	content.add_child(master_row["row"])

	var sfx_row := _make_volume_row("SFX")
	settings_sfx_slider = sfx_row["slider"]
	settings_sfx_value_label = sfx_row["value_label"]
	settings_sfx_slider.value = settings_sfx_volume
	settings_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	content.add_child(sfx_row["row"])
	_update_settings_volume_labels()

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)

	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.custom_minimum_size = Vector2(130, 38)
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.pressed.connect(_apply_settings_from_panel)
	buttons.add_child(apply_button)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size = Vector2(130, 38)
	resume_button.focus_mode = Control.FOCUS_NONE
	resume_button.pressed.connect(_close_settings_panel)
	buttons.add_child(resume_button)


func _make_settings_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.64))
	row.add_child(label)

	control.custom_minimum_size = Vector2(260, 34)
	row.add_child(control)
	return row


func _make_volume_row(label_text: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.64))
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(200, 34)
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(50, 34)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	row.add_child(value_label)

	return {
		"row": row,
		"slider": slider,
		"value_label": value_label,
	}


func _build_hunter_skill_slots(parent: Control, character: Dictionary, theme_color: Color, accent_color: Color) -> void:
	hunter_skill_slots_panel = Control.new()
	hunter_skill_slots_panel.visible = str(character.get("id", "")) == "hunter"
	hunter_skill_slots_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hunter_skill_slots_panel.offset_left = 20
	hunter_skill_slots_panel.offset_top = -158
	hunter_skill_slots_panel.offset_right = 424
	hunter_skill_slots_panel.offset_bottom = -20
	parent.add_child(hunter_skill_slots_panel)

	var title := Label.new()
	title.text = "SKILLS"
	title.position = Vector2(4, 0)
	title.size = Vector2(390, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.88, 0.78, 0.62))
	hunter_skill_slots_panel.add_child(title)

	var row := HBoxContainer.new()
	row.position = Vector2(0, 30)
	row.size = Vector2(400, 108)
	row.add_theme_constant_override("separation", 22)
	hunter_skill_slots_panel.add_child(row)

	hunter_skill_slots.clear()
	if not hunter_skill_slots_panel.visible:
		return

	var slot_data := [
		{"label": "DASH", "path": "res://assets/ui/hud/hunter_skill_dash_casual_v2.png"},
		{"label": "PARRY", "path": "res://assets/ui/hud/hunter_skill_parry_casual_v2.png"},
		{"label": "WAVE", "path": "res://assets/ui/hud/hunter_skill_sword_wave_casual_v2.png"},
	]
	for data in slot_data:
		var slot := GothicWidgets.SkillCooldownSlot.new()
		slot.custom_minimum_size = Vector2(116, 108)
		hunter_skill_slots.append(slot)
		row.add_child(slot)
		slot.configure(str(data["label"]), _load_image_texture(str(data["path"])), accent_color)

	skill_1_label.visible = false
	skill_2_label.visible = false
	skill_3_label.visible = false


func _make_hud_status_label(accent_color: Color) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(390, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.8))
	label.add_theme_stylebox_override("normal", _make_gothic_panel_style(Color(0.0, 0.0, 0.0, 0.34), Color(accent_color.r, accent_color.g, accent_color.b, 0.24), 1))
	return label


func _load_hud_portrait_texture(character: Dictionary) -> Texture2D:
	if str(character.get("id", "")) == "hunter":
		var hunter_texture := _load_image_texture(HUNTER_HUD_PORTRAIT_PATH)
		if hunter_texture != null:
			return hunter_texture

	var portrait_paths := [
		str(character.get("ultimate_cutin_image", "")),
		str(character.get("detail_image", "")),
		str(character.get("card_image", "")),
	]
	for path in portrait_paths:
		if path.is_empty():
			continue
		var loaded := load(path) as Texture2D
		if loaded != null:
			return loaded
		loaded = _load_image_texture(path)
		if loaded != null:
			return loaded
	return ultimate_cutin_texture


func _load_image_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _get_hud_portrait_region(character: Dictionary, texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	return Rect2()


func _make_gothic_panel_style(fill_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


# DEV TEST UPGRADE TOOL START
func _build_dev_upgrade_panel(parent: Control) -> void:
	if not show_dev_upgrade_tools:
		return

	dev_upgrade_panel = PanelContainer.new()
	dev_upgrade_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	dev_upgrade_panel.visible = false
	dev_upgrade_panel.custom_minimum_size = Vector2(650, 124)
	dev_upgrade_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dev_upgrade_panel.offset_left = 16
	dev_upgrade_panel.offset_top = 170
	dev_upgrade_panel.offset_right = 666
	dev_upgrade_panel.offset_bottom = 294
	parent.add_child(dev_upgrade_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	dev_upgrade_panel.add_child(content)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	content.add_child(top)

	var title := Label.new()
	title.text = "DEV Upgrade"
	title.custom_minimum_size = Vector2(96, 28)
	top.add_child(title)

	dev_upgrade_selector = OptionButton.new()
	dev_upgrade_selector.custom_minimum_size = Vector2(250, 30)
	dev_upgrade_selector.focus_mode = Control.FOCUS_NONE
	top.add_child(dev_upgrade_selector)

	dev_upgrade_count_spinbox = SpinBox.new()
	dev_upgrade_count_spinbox.min_value = 1
	dev_upgrade_count_spinbox.max_value = 10
	dev_upgrade_count_spinbox.step = 1
	dev_upgrade_count_spinbox.value = 1
	dev_upgrade_count_spinbox.custom_minimum_size = Vector2(70, 30)
	dev_upgrade_count_spinbox.focus_mode = Control.FOCUS_NONE
	top.add_child(dev_upgrade_count_spinbox)
	var count_line_edit := dev_upgrade_count_spinbox.get_line_edit()
	if count_line_edit != null:
		count_line_edit.text_changed.connect(_on_dev_upgrade_count_text_changed)
		count_line_edit.text_submitted.connect(_on_dev_upgrade_count_submitted)
		count_line_edit.gui_input.connect(_on_dev_upgrade_count_gui_input)

	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.custom_minimum_size = Vector2(72, 30)
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.pressed.connect(_apply_dev_upgrade_selection)
	top.add_child(apply_button)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.custom_minimum_size = Vector2(78, 30)
	refresh_button.focus_mode = Control.FOCUS_NONE
	refresh_button.pressed.connect(_refresh_dev_upgrade_options_from_button)
	top.add_child(refresh_button)

	var reset_button := Button.new()
	reset_button.text = "Reset Upgrades"
	reset_button.custom_minimum_size = Vector2(120, 30)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_reset_dev_upgrades)
	top.add_child(reset_button)

	dev_upgrade_status_label = Label.new()
	dev_upgrade_status_label.text = "Apply upgrades instantly in DEV TEST."
	dev_upgrade_status_label.custom_minimum_size = Vector2(520, 24)
	content.add_child(dev_upgrade_status_label)
	_build_dev_stage_jump_row(content)


func _build_dev_stage_jump_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var title := Label.new()
	title.text = "Jump Stage"
	title.custom_minimum_size = Vector2(96, 28)
	row.add_child(title)

	for stage in range(1, 6):
		var button := Button.new()
		button.text = "S%d" % stage
		button.custom_minimum_size = Vector2(58, 28)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_jump_to_stage.bind(stage))
		row.add_child(button)


func _refresh_dev_upgrade_options_from_button() -> void:
	_release_dev_upgrade_focus()
	_refresh_dev_upgrade_options()


func _refresh_dev_upgrade_options() -> void:
	if dev_upgrade_selector == null:
		return

	var previous_id := ""
	if dev_upgrade_selector.selected >= 0 and dev_upgrade_selector.selected < dev_upgrade_ids.size():
		previous_id = dev_upgrade_ids[dev_upgrade_selector.selected]

	dev_upgrade_selector.clear()
	dev_upgrade_ids.clear()

	var selected_character_id := str(GameState.get_selected_character().get("id", GameState.selected_character_id))
	for option in _get_upgrade_pool():
		var option_id := str(option.get("id", ""))
		if option_id.is_empty():
			continue
		if str(option.get("category", "")) == "character" and str(option.get("character_id", "")) != selected_character_id:
			continue
		if player.has_method("can_apply_upgrade") and not player.can_apply_upgrade(option_id):
			continue

		var label := str(option.get("label", option_id))
		var rarity := str(option.get("rarity", "Common"))
		var skill_id := str(option.get("skill_id", ""))
		dev_upgrade_selector.add_item("[%s] %s (%s)" % [rarity, label, skill_id])
		dev_upgrade_ids.append(option_id)

	if dev_upgrade_ids.is_empty():
		dev_upgrade_selector.add_item("No available upgrades")
		dev_upgrade_selector.disabled = true
		if dev_upgrade_status_label != null:
			dev_upgrade_status_label.text = "No available upgrades."
		return

	dev_upgrade_selector.disabled = false
	var selected_index := dev_upgrade_ids.find(previous_id)
	dev_upgrade_selector.select(maxi(selected_index, 0))
	if dev_upgrade_status_label != null:
		dev_upgrade_status_label.text = "Choose an upgrade and count, then press Apply."


func _apply_dev_upgrade_selection() -> void:
	_release_dev_upgrade_focus()
	if player == null or dev_upgrade_selector == null or dev_upgrade_selector.disabled:
		return
	if dev_upgrade_selector.selected < 0 or dev_upgrade_selector.selected >= dev_upgrade_ids.size():
		return

	var upgrade_id := dev_upgrade_ids[dev_upgrade_selector.selected]
	var requested_count := int(dev_upgrade_count_spinbox.value) if dev_upgrade_count_spinbox != null else 1
	var applied_count := 0
	for index in range(requested_count):
		if player.has_method("can_apply_upgrade") and not player.can_apply_upgrade(upgrade_id):
			break
		player.apply_upgrade(upgrade_id)
		applied_count += 1

	_refresh_dev_upgrade_options()
	if dev_upgrade_status_label != null:
		dev_upgrade_status_label.text = "Applied %s x%d" % [upgrade_id, applied_count]


func _reset_dev_upgrades() -> void:
	_release_dev_upgrade_focus()
	if player == null or not player.has_method("reset_upgrades"):
		return
	player.reset_upgrades()
	_refresh_dev_upgrade_options()
	if dev_upgrade_status_label != null:
		dev_upgrade_status_label.text = "Reset upgrades."


func _jump_to_stage(target_stage: int) -> void:
	_release_dev_upgrade_focus()
	target_stage = clampi(target_stage, 1, 5)
	get_tree().paused = false
	game_over = false
	stage_cleared = false
	if game_over_panel != null:
		game_over_panel.visible = false
	if level_up_panel != null:
		level_up_panel.visible = false

	_clear_experiment_threats()
	for child in gem_container.get_children():
		child.queue_free()

	stage_index = target_stage
	stage_time = 0.0
	wave_time = 0.0
	boss_spawned = false
	active_bosses = 0
	stage_state = "wave"
	current_enemy_pool.clear()

	if player != null and player.has_method("set_experiment_mode"):
		player.set_experiment_mode(false)

	if target_stage <= 3 and experiment_mode:
		_set_experiment_mode(false)

	if target_stage <= 3:
		_update_stage_phase()
		if spawn_timer != null:
			spawn_timer.start()
	elif target_stage == 4:
		_spawn_stage_4_miniboss()
	else:
		_spawn_twin_bosses()

	if dev_upgrade_status_label != null:
		dev_upgrade_status_label.text = "Jumped to Stage %d. Combat cooldowns normal." % target_stage


func _on_dev_upgrade_count_text_changed(_new_text: String) -> void:
	dev_upgrade_focus_release_token += 1
	var token := dev_upgrade_focus_release_token
	await get_tree().create_timer(0.18).timeout
	if token == dev_upgrade_focus_release_token:
		_release_dev_upgrade_focus()


func _on_dev_upgrade_count_submitted(_new_text: String) -> void:
	_release_dev_upgrade_focus()


func _on_dev_upgrade_count_gui_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed:
		return
	if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		call_deferred("_release_dev_upgrade_focus")


func _release_dev_upgrade_focus() -> void:
	dev_upgrade_focus_release_token += 1
	if dev_upgrade_count_spinbox != null:
		var line_edit := dev_upgrade_count_spinbox.get_line_edit()
		if line_edit != null:
			line_edit.release_focus()
	if dev_upgrade_selector != null:
		dev_upgrade_selector.release_focus()
	get_viewport().gui_release_focus()
# DEV TEST UPGRADE TOOL END


func _build_level_up_panel(parent: Control) -> void:
	var character := GameState.get_selected_character()
	var theme_color: Color = character.get("theme_color", Color(0.48, 0.68, 1.0))
	var accent_color: Color = character.get("accent_color", Color(0.95, 0.72, 0.46))

	level_up_panel = Control.new()
	level_up_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_panel.visible = false
	level_up_panel.modulate.a = 0.0
	level_up_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(level_up_panel)

	var frame := GothicWidgets.GothicOverlayFrame.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.configure(theme_color, accent_color)
	level_up_panel.add_child(frame)

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -560
	content.offset_top = -330
	content.offset_right = 560
	content.offset_bottom = 330
	level_up_panel.add_child(content)

	level_up_title = Label.new()
	level_up_title.position = Vector2(0, 0)
	level_up_title.size = Vector2(1120, 76)
	level_up_title.text = "LEVEL UP"
	level_up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_up_title.add_theme_font_size_override("font_size", 52)
	level_up_title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	content.add_child(level_up_title)

	var subtitle := Label.new()
	subtitle.text = "증강 선택"
	subtitle.position = Vector2(0, 64)
	subtitle.size = Vector2(1120, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	content.add_child(subtitle)

	var cards := HBoxContainer.new()
	cards.position = Vector2(54, 124)
	cards.size = Vector2(1012, 500)
	cards.add_theme_constant_override("separation", 32)
	content.add_child(cards)

	level_up_option_buttons.clear()
	for index in range(3):
		var button := GothicWidgets.GothicUpgradeCard.new()
		button.custom_minimum_size = Vector2(316, 500)
		button.pressed.connect(_choose_level_up_option.bind(index))
		level_up_option_buttons.append(button)
		cards.add_child(button)


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

	game_over_title_label = Label.new()
	game_over_title_label.text = "게임 오버"
	game_over_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(game_over_title_label)

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


func _play_ultimate_sfx(stream: AudioStream, volume_db := -6.0, min_pitch := 1.0, max_pitch := 1.0) -> void:
	if stream == null:
		return

	var audio := AudioStreamPlayer.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	audio.stream = stream
	audio.bus = SFX_BUS_NAME
	audio.volume_db = volume_db
	audio.pitch_scale = randf_range(min_pitch, max_pitch)
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


func _play_ultimate_activation_vfx(texture: Texture2D, scale_amount: float, duration: float) -> void:
	if texture == null or player == null or ultimate_vfx_container == null:
		return

	if ultimate_activation_vfx_material == null:
		ultimate_activation_vfx_material = CanvasItemMaterial.new()
		ultimate_activation_vfx_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var sprite := Sprite2D.new()
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, Vector2(256.0, 256.0))
	sprite.centered = true
	sprite.global_position = player.global_position + Vector2(0.0, -18.0)
	sprite.scale = Vector2.ONE * scale_amount
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = ultimate_activation_vfx_material
	sprite.z_index = 96
	ultimate_vfx_container.add_child(sprite)
	_animate_ultimate_activation_vfx(sprite, texture, duration)


func _animate_ultimate_activation_vfx(sprite: Sprite2D, texture: Texture2D, duration: float) -> void:
	var frame_size := Vector2(256.0, 256.0)
	var columns := maxi(1, int(texture.get_width() / int(frame_size.x)))
	var rows := maxi(1, int(texture.get_height() / int(frame_size.y)))
	var frame_count := mini(16, columns * rows)
	var frame_time := maxf(0.02, duration / float(maxi(1, frame_count)))
	for frame in range(frame_count):
		if not is_instance_valid(sprite):
			return
		var column := frame % columns
		var row := int(frame / columns)
		sprite.region_rect = Rect2(Vector2(column, row) * frame_size, frame_size)
		await get_tree().create_timer(frame_time, true, false, true).timeout
	if is_instance_valid(sprite):
		sprite.queue_free()


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
	var progress := 1.0 if ultimate_ready else float(ultimate_kills) / maxf(1.0, float(ultimate_required_kills))
	var cooling_down := ultimate_cooldown_visual_timer > 0.0
	if cooling_down:
		progress = ultimate_cooldown_visual_timer / maxf(0.1, ultimate_cooldown_visual_duration)
	if ultimate_portrait_ring != null and ultimate_portrait_ring.has_method("set_charge"):
		ultimate_portrait_ring.set_charge(progress, ultimate_ready and not cooling_down)

	if ultimate_bar != null:
		if cooling_down:
			ultimate_bar.max_value = 1.0
			ultimate_bar.value = progress
		else:
			ultimate_bar.max_value = ultimate_required_kills
			ultimate_bar.value = ultimate_required_kills if ultimate_ready else ultimate_kills
	if ultimate_label != null:
		if cooling_down:
			ultimate_label.text = "ULT %.1fs" % ultimate_cooldown_visual_timer
		else:
			ultimate_label.text = "ULT READY  Q" if ultimate_ready else "ULT %d/%d" % [ultimate_kills, ultimate_required_kills]


func _set_experiment_mode(enabled: bool) -> void:
	experiment_mode = enabled
	if player != null and player.has_method("set_experiment_mode"):
		player.set_experiment_mode(false)

	if spawn_timer != null:
		if experiment_mode:
			spawn_timer.stop()
		elif not game_over and not boss_spawned:
			spawn_timer.start()

	if experiment_mode:
		_clear_experiment_threats()

	if experiment_mode_button != null:
		experiment_mode_button.set_pressed_no_signal(experiment_mode)
		experiment_mode_button.text = "DEV TEST: ON" if experiment_mode else "DEV TEST: OFF"
		experiment_mode_button.modulate = Color(0.55, 1.0, 0.72) if experiment_mode else Color.WHITE

	if dev_upgrade_panel != null:
		dev_upgrade_panel.visible = experiment_mode
		if experiment_mode:
			_refresh_dev_upgrade_options()


func _clear_experiment_threats() -> void:
	for child in enemy_container.get_children():
		child.queue_free()
	for child in projectile_container.get_children():
		child.queue_free()


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
	_set_key_action("sword_wave", [KEY_E])
	_set_key_action("dev_experiment_mode", [KEY_F10])
	_set_key_action("settings", [KEY_ESCAPE])


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
