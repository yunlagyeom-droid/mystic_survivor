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
@export var walk_animation_fps := 8.0
@export var walk_frame_distance := 14.0

var current_health := 100
var level := 1
var experience := 0
var required_experience := 6
var invulnerable_timer := 0.0
var walk_distance := 0.0
var last_direction := Vector2.DOWN
var is_dead := false
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
	update_walk_animation(input_direction, moved_distance)

	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	if combat != null:
		combat.combat_process(delta, input_direction)
	_update_player_modulate()


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


func update_walk_animation(input_direction: Vector2, moved_distance: float) -> void:
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


func _apply_selected_character_sprite() -> void:
	var character := GameState.get_selected_character()
	if character.is_empty():
		return

	var sprite_sheet_path := str(character.get("sprite_sheet", ""))
	if not sprite_sheet_path.is_empty():
		var selected_texture := load(sprite_sheet_path) as Texture2D
		if selected_texture != null:
			sprite.texture = selected_texture

	sprite_columns = int(character.get("sprite_columns", sprite_columns))
	sprite_rows = int(character.get("sprite_rows", sprite_rows))
	sprite.hframes = sprite_columns
	sprite.vframes = sprite_rows

	var configured_scale: Variant = character.get("sprite_scale", null)
	if configured_scale is Vector2:
		sprite.scale = configured_scale

	var configured_position: Variant = character.get("sprite_position", null)
	if configured_position is Vector2:
		sprite.position = configured_position


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
