class_name Player
extends CharacterBody2D

signal projectile_requested(projectile_scene: PackedScene, origin: Vector2, direction: Vector2, damage: int)
signal world_vfx_requested(vfx: Node2D)
signal health_changed(current_health: int, max_health: int)
signal experience_changed(current_experience: int, required_experience: int, level: int)
signal level_up_ready(level: int)
signal combat_status_changed(skill_1_text: String, skill_2_text: String)
signal died

@export var move_speed := 260.0
@export var max_health := 100
@export var level_required_base := 6
@export var level_required_growth := 4
@export var world_radius := 2600.0
@export var sprite_columns := 8
@export var sprite_rows := 8
@export var walk_animation_fps := 10.0
@export var walk_frame_distance := 14.0
@export var idle_breath_cycle_seconds := 2.0
@export var idle_breath_position_pixels := 1.5
@export var idle_breath_scale_amount := 0.012

var current_health := 100
var level := 1
var experience := 0
var required_experience := 6
var invulnerable_timer := 0.0
var walk_distance := 0.0
var walk_animation_time := 0.0
var idle_animation_time := 0.0
var base_sprite_position := Vector2.ZERO
var base_sprite_scale := Vector2.ONE
var default_texture: Texture2D
var idle_texture: Texture2D
var walk_texture: Texture2D
var idle_columns := 0
var idle_rows := 0
var idle_animation_fps := 4.0
var walk_columns := 0
var walk_rows := 0
var walk_sheet_fps := 10.0
var attack_texture: Texture2D
var attack_columns := 0
var attack_rows := 0
var attack_fps := 18.0
var attack_duration := 0.34
var action_name := ""
var action_elapsed := 0.0
var action_duration := 0.0
var action_direction := Vector2.DOWN
var current_motion_sheet := ""
var last_direction := Vector2.DOWN
var last_attack_direction := Vector2.DOWN
var is_moving_now := false
var is_dead := false
var experiment_mode := false
var combat: Node
var combat_modulate := Color.WHITE

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	current_health = max_health
	required_experience = level_required_base
	add_to_group("player")
	_apply_selected_character_sprite()
	_build_combat()
	health_changed.emit(current_health, max_health)
	experience_changed.emit(experience, required_experience, level)
	_emit_combat_status()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("blink") and combat != null:
		combat.try_skill_1(input_direction)
	if Input.is_action_just_pressed("barrier") and combat != null:
		combat.try_skill_2(input_direction)

	var previous_position := global_position
	velocity = input_direction * move_speed
	move_and_slide()

	global_position.x = clampf(global_position.x, -world_radius, world_radius)
	global_position.y = clampf(global_position.y, -world_radius, world_radius)

	var moved_distance := previous_position.distance_to(global_position)
	update_walk_animation(input_direction, moved_distance, delta)

	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	if combat != null:
		combat.combat_process(delta, input_direction)
	_update_player_modulate()


func set_experiment_mode(enabled: bool) -> void:
	experiment_mode = enabled
	if combat != null and combat.has_method("set_experiment_mode"):
		combat.set_experiment_mode(experiment_mode)


func take_damage(amount: int) -> void:
	if is_dead or invulnerable_timer > 0.0:
		return

	if combat != null:
		amount = combat.modify_incoming_damage(amount)
		if amount <= 0:
			return

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
	while experience >= required_experience:
		experience -= required_experience
		level += 1
		required_experience = level_required_base + (level - 1) * level_required_growth
		level_up_ready.emit(level)

	experience_changed.emit(experience, required_experience, level)


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"health":
			max_health += 25
			current_health = mini(max_health, current_health + 35)
		_:
			if combat != null:
				combat.apply_upgrade(upgrade_id)

	health_changed.emit(current_health, max_health)
	experience_changed.emit(experience, required_experience, level)
	_emit_combat_status()


func can_apply_upgrade(upgrade_id: String) -> bool:
	if combat != null and combat.has_method("can_apply_upgrade"):
		return combat.can_apply_upgrade(upgrade_id)
	return true


func get_combat_upgrade_pool() -> Array[Dictionary]:
	if combat == null or not combat.has_method("get_upgrade_pool"):
		return []
	return combat.get_upgrade_pool()


func use_ultimate(context: Dictionary) -> void:
	if combat != null and combat.has_method("use_ultimate"):
		combat.use_ultimate(context)


func set_invulnerable(duration: float) -> void:
	invulnerable_timer = maxf(invulnerable_timer, duration)


func set_combat_modulate(color: Color) -> void:
	combat_modulate = color


func clear_combat_modulate() -> void:
	combat_modulate = Color.WHITE


func play_action_animation(next_action_name: String, direction: Vector2, duration := -1.0) -> void:
	if next_action_name != "attack" or attack_texture == null:
		return

	var next_direction := direction.normalized()
	if next_direction == Vector2.ZERO:
		next_direction = last_direction.normalized()
	if next_direction == Vector2.ZERO:
		next_direction = Vector2.DOWN

	last_attack_direction = next_direction
	if is_moving_now:
		return

	last_direction = next_direction
	action_name = next_action_name
	action_direction = next_direction
	action_elapsed = 0.0
	action_duration = attack_duration if duration <= 0.0 else duration
	_apply_action_animation_frame()


func get_action_animation_duration(next_action_name: String, fallback_duration := 0.34) -> float:
	if next_action_name == "attack" and attack_texture != null:
		return attack_duration
	return fallback_duration


func update_walk_animation(input_direction: Vector2, moved_distance: float, delta := 0.0) -> void:
	var is_moving := input_direction.length_squared() > 0.01
	is_moving_now = is_moving
	if is_moving:
		_set_motion_sheet("walk")
		last_direction = input_direction.normalized()
		walk_distance += moved_distance
		walk_animation_time += delta
		idle_animation_time = 0.0
		_reset_idle_breath()
	else:
		_set_motion_sheet("idle")
		walk_distance = 0.0
		walk_animation_time = 0.0
		idle_animation_time += delta

	if _is_action_animation_active():
		action_elapsed += delta
		if action_elapsed >= action_duration:
			_finish_action_animation()
		else:
			_apply_action_animation_frame()
			return

	var row := _direction_to_sprite_row(last_direction)
	var column := 0
	var active_columns := sprite_columns
	var active_fps := walk_animation_fps
	if is_moving:
		if walk_texture != null:
			active_columns = walk_columns
			active_fps = walk_sheet_fps
		column = int(walk_animation_time * active_fps) % active_columns
	elif idle_texture != null:
		active_columns = idle_columns
		column = int(idle_animation_time * idle_animation_fps) % active_columns

	sprite.frame = row * active_columns + column
	if not is_moving:
		if idle_texture == null:
			_apply_idle_breath()
		else:
			_reset_idle_breath()


func _apply_selected_character_sprite() -> void:
	var character := GameState.get_selected_character()
	if character.is_empty():
		default_texture = sprite.texture
		base_sprite_position = sprite.position
		base_sprite_scale = sprite.scale
		return

	var sprite_sheet_path := str(character.get("sprite_sheet", ""))
	if not sprite_sheet_path.is_empty():
		var selected_texture := load(sprite_sheet_path) as Texture2D
		if selected_texture != null:
			sprite.texture = selected_texture
	default_texture = sprite.texture

	sprite_columns = int(character.get("sprite_columns", sprite_columns))
	sprite_rows = int(character.get("sprite_rows", sprite_rows))
	sprite.hframes = sprite_columns
	sprite.vframes = sprite_rows
	_load_optional_motion_sheets(character)

	var configured_scale: Variant = character.get("sprite_scale", null)
	if configured_scale is Vector2:
		sprite.scale = configured_scale

	var configured_position: Variant = character.get("sprite_position", null)
	if configured_position is Vector2:
		sprite.position = configured_position

	base_sprite_position = sprite.position
	base_sprite_scale = sprite.scale
	_set_motion_sheet("idle")


func _load_optional_motion_sheets(character: Dictionary) -> void:
	idle_texture = null
	walk_texture = null
	attack_texture = null
	current_motion_sheet = ""

	var idle_sheet_path := str(character.get("idle_sheet", ""))
	if not idle_sheet_path.is_empty():
		idle_texture = load(idle_sheet_path) as Texture2D
		idle_columns = int(character.get("idle_columns", 4))
		idle_rows = int(character.get("idle_rows", 8))
		idle_animation_fps = float(character.get("idle_fps", 4.0))

	var walk_sheet_path := str(character.get("walk_sheet", ""))
	if not walk_sheet_path.is_empty():
		walk_texture = load(walk_sheet_path) as Texture2D
		walk_columns = int(character.get("walk_columns", sprite_columns))
		walk_rows = int(character.get("walk_rows", sprite_rows))
		walk_sheet_fps = float(character.get("walk_fps", walk_animation_fps))

	var attack_sheet_path := str(character.get("attack_sheet", ""))
	if not attack_sheet_path.is_empty():
		attack_texture = load(attack_sheet_path) as Texture2D
		attack_columns = int(character.get("attack_columns", 6))
		attack_rows = int(character.get("attack_rows", 8))
		attack_fps = float(character.get("attack_fps", 18.0))
		attack_duration = float(character.get("attack_duration", 0.34))


func _set_motion_sheet(motion: String) -> void:
	var next_texture := default_texture
	var next_columns := sprite_columns
	var next_rows := sprite_rows

	if motion == "idle" and idle_texture != null:
		next_texture = idle_texture
		next_columns = idle_columns
		next_rows = idle_rows
	elif motion == "walk" and walk_texture != null:
		next_texture = walk_texture
		next_columns = walk_columns
		next_rows = walk_rows
	else:
		motion = "default"

	if current_motion_sheet == motion:
		return

	sprite.texture = next_texture
	sprite.hframes = next_columns
	sprite.vframes = next_rows
	current_motion_sheet = motion


func _apply_idle_breath() -> void:
	var cycle := maxf(0.1, idle_breath_cycle_seconds)
	var breath := (sin(idle_animation_time / cycle * TAU - PI * 0.5) + 1.0) * 0.5
	sprite.position = base_sprite_position + Vector2(0.0, -breath * idle_breath_position_pixels)
	sprite.scale = Vector2(
		base_sprite_scale.x * (1.0 - breath * idle_breath_scale_amount * 0.25),
		base_sprite_scale.y * (1.0 + breath * idle_breath_scale_amount)
	)


func _reset_idle_breath() -> void:
	sprite.position = base_sprite_position
	sprite.scale = base_sprite_scale


func _is_action_animation_active() -> bool:
	return not action_name.is_empty() and action_duration > 0.0


func _apply_action_animation_frame() -> void:
	if action_name != "attack" or attack_texture == null:
		return

	if current_motion_sheet != "action_attack":
		sprite.texture = attack_texture
		sprite.hframes = attack_columns
		sprite.vframes = attack_rows
		current_motion_sheet = "action_attack"

	var row := _direction_to_sprite_row(action_direction)
	var column := mini(int(action_elapsed * attack_fps), maxi(attack_columns - 1, 0))
	sprite.frame = row * attack_columns + column
	_reset_idle_breath()


func _finish_action_animation() -> void:
	action_name = ""
	action_elapsed = 0.0
	action_duration = 0.0
	current_motion_sheet = ""


func _build_combat() -> void:
	var character := GameState.get_selected_character()
	var combat_script_path := str(character.get("combat_script", "res://scripts/combat/mage_combat.gd"))
	var combat_script := load(combat_script_path) as Script
	if combat_script == null:
		push_warning("Combat script not found: %s" % combat_script_path)
		return

	combat = combat_script.new() as Node
	if combat == null:
		push_warning("Combat script did not create a node: %s" % combat_script_path)
		return
	if not combat.has_method("setup"):
		push_warning("Combat script has no setup method: %s" % combat_script_path)
		return

	add_child(combat)
	combat.projectile_requested.connect(_on_combat_projectile_requested)
	combat.world_vfx_requested.connect(_on_combat_world_vfx_requested)
	combat.status_changed.connect(_on_combat_status_changed)
	combat.setup(self)


func _on_combat_projectile_requested(projectile_scene: PackedScene, origin: Vector2, direction: Vector2, damage: int) -> void:
	projectile_requested.emit(projectile_scene, origin, direction, damage)


func _on_combat_world_vfx_requested(vfx: Node2D) -> void:
	world_vfx_requested.emit(vfx)


func _on_combat_status_changed(skill_1_text: String, skill_2_text: String) -> void:
	combat_status_changed.emit(skill_1_text, skill_2_text)


func _emit_combat_status() -> void:
	if combat == null:
		combat_status_changed.emit("", "")
		return

	var texts: Array = combat.get_status_texts()
	combat_status_changed.emit(texts[0], texts[1])


func _update_player_modulate() -> void:
	if invulnerable_timer > 0.0:
		sprite.modulate = Color(1.0, 0.55, 0.55)
	else:
		sprite.modulate = combat_modulate


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
