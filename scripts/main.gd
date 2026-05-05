extends Node2D

const CITY_ROAD_TOP_ROW := -4
const CITY_ROAD_BOTTOM_ROW := 2
const CITY_TOP_CURB_ROW := -5
const CITY_BOTTOM_CURB_ROW := 3
const CITY_CENTERLINE_ROW := -1
const CITY_CROSSWALK_COLUMN := -1
const GothicWidgets := preload("res://scripts/ui/in_game_gothic_widgets.gd")
const HUNTER_HUD_PORTRAIT_PATH := "res://assets/ui/hud/hunter_hud_portrait_face_v1.png"

@export var slime_scene: PackedScene
@export var experience_gem_scene: PackedScene
@export var obstacle_scenes: Array[PackedScene] = []
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
var experiment_mode := false
var game_over := false

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
var level_up_panel: Control
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
	_apply_selected_character_ultimate_cutin()
	_build_background()
	_build_obstacles()
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
	_update_hunter_skill_slots()


func _process(delta: float) -> void:
	if game_over:
		return

	if not experiment_mode:
		elapsed_time += delta
	time_label.text = _format_time(elapsed_time)
	defeated_label.text = "처치: %d" % defeated_count
	_update_hunter_skill_slots()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_experiment_mode"):
		_set_experiment_mode(not experiment_mode)
	elif event.is_action_pressed("ultimate"):
		_try_use_ultimate()
	elif game_over and event.is_action_pressed("ui_accept"):
		_restart_game()


func _spawn_enemy() -> void:
	if game_over or get_tree().paused or experiment_mode:
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


func _spawn_experience_gem(spawn_position: Vector2, experience_value: int) -> void:
	if game_over:
		return

	var gem := experience_gem_scene.instantiate() as ExperienceGem
	gem_container.add_child(gem)
	gem.setup(spawn_position, experience_value)


func _build_obstacles() -> void:
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
	_build_ultimate_overlay(hud)


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
	dev_upgrade_panel.custom_minimum_size = Vector2(650, 86)
	dev_upgrade_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dev_upgrade_panel.offset_left = 16
	dev_upgrade_panel.offset_top = 170
	dev_upgrade_panel.offset_right = 666
	dev_upgrade_panel.offset_bottom = 256
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
	content.offset_left = -500
	content.offset_top = -286
	content.offset_right = 500
	content.offset_bottom = 286
	level_up_panel.add_child(content)

	level_up_title = Label.new()
	level_up_title.position = Vector2(0, 0)
	level_up_title.size = Vector2(1000, 72)
	level_up_title.text = "LEVEL UP"
	level_up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_up_title.add_theme_font_size_override("font_size", 52)
	level_up_title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	content.add_child(level_up_title)

	var subtitle := Label.new()
	subtitle.text = "증강 선택"
	subtitle.position = Vector2(0, 64)
	subtitle.size = Vector2(1000, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	content.add_child(subtitle)

	var cards := HBoxContainer.new()
	cards.position = Vector2(26, 108)
	cards.size = Vector2(948, 438)
	cards.add_theme_constant_override("separation", 28)
	content.add_child(cards)

	level_up_option_buttons.clear()
	for index in range(3):
		var button := GothicWidgets.GothicUpgradeCard.new()
		button.custom_minimum_size = Vector2(296, 438)
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
	var progress := 1.0 if ultimate_ready else float(ultimate_kills) / maxf(1.0, float(ultimate_required_kills))
	if ultimate_portrait_ring != null and ultimate_portrait_ring.has_method("set_charge"):
		ultimate_portrait_ring.set_charge(progress, ultimate_ready)

	if ultimate_bar != null:
		ultimate_bar.max_value = ultimate_required_kills
		ultimate_bar.value = ultimate_required_kills if ultimate_ready else ultimate_kills
	if ultimate_label != null:
		ultimate_label.text = "ULT READY  Q" if ultimate_ready else "ULT %d/%d" % [ultimate_kills, ultimate_required_kills]


func _set_experiment_mode(enabled: bool) -> void:
	experiment_mode = enabled
	if player != null and player.has_method("set_experiment_mode"):
		player.set_experiment_mode(experiment_mode)

	if spawn_timer != null:
		if experiment_mode:
			spawn_timer.stop()
		elif not game_over:
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
