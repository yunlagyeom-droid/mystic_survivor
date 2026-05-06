class_name DarkEnemy
extends CharacterBody2D

signal defeated(defeat_info: Dictionary)

enum Behavior {
	CHASER,
	BRUTE,
	CASTER,
}

@export var enemy_name := "Dark Enemy"
@export var behavior := Behavior.CHASER
@export var move_speed := 120.0
@export var max_health := 40
@export var touch_damage := 8
@export var contact_cooldown := 0.65
@export var experience_value := 3
@export var animation_frames := 6
@export var animation_fps := 10.0
@export var preferred_range := 360.0
@export var cast_cooldown := 2.4
@export var cast_windup := 0.72
@export var cast_radius := 86.0
@export var cast_damage := 12

var player: Node2D
var current_health := 1
var contact_timer := 0.0
var animation_time := 0.0
var cast_timer := 0.0
var cast_windup_timer := 0.0
var pending_cast_position := Vector2.ZERO
var is_dead := false
var telegraph: Line2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	cast_timer = randf_range(0.3, cast_cooldown)
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup_player(target: Node) -> void:
	player = target as Node2D


func _physics_process(delta: float) -> void:
	contact_timer = maxf(0.0, contact_timer - delta)
	cast_timer = maxf(0.0, cast_timer - delta)
	if sprite != null:
		sprite.modulate = sprite.modulate.lerp(Color.WHITE, minf(1.0, delta * 12.0))
		_update_animation(delta)

	if is_dead or not is_instance_valid(player):
		return

	if behavior == Behavior.CASTER:
		_process_caster(delta)
	else:
		_chase_player()
		_try_damage_player()


func take_damage(amount: int, source := "attack") -> void:
	if is_dead:
		return

	current_health -= amount
	if sprite != null:
		sprite.modulate = Color(1.55, 1.45, 1.45)

	if current_health <= 0:
		is_dead = true
		defeated.emit(_make_defeat_info(source))
		queue_free()


func _process_caster(delta: float) -> void:
	if cast_windup_timer > 0.0:
		cast_windup_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if cast_windup_timer <= 0.0:
			_finish_cast()
		return

	var offset := player.global_position - global_position
	var distance := offset.length()
	if distance > preferred_range + 70.0:
		velocity = offset.normalized() * move_speed
	elif distance < preferred_range - 90.0:
		velocity = -offset.normalized() * move_speed * 0.72
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if offset.x != 0.0 and sprite != null:
		sprite.flip_h = offset.x < 0.0

	if cast_timer <= 0.0:
		_begin_cast()


func _begin_cast() -> void:
	pending_cast_position = player.global_position
	cast_windup_timer = cast_windup
	cast_timer = cast_cooldown
	telegraph = _make_circle_telegraph(pending_cast_position, cast_radius, Color(0.75, 0.35, 1.0, 0.74), 3.0)
	get_tree().current_scene.add_child(telegraph)


func _finish_cast() -> void:
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	if is_instance_valid(player) and player.global_position.distance_to(pending_cast_position) <= cast_radius:
		if player.has_method("take_damage"):
			player.take_damage(cast_damage)


func _chase_player() -> void:
	var direction := (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

	if direction.x != 0.0 and sprite != null:
		sprite.flip_h = direction.x < 0.0


func _try_damage_player() -> void:
	if contact_timer > 0.0 or attack_area == null:
		return

	for body in attack_area.get_overlapping_bodies():
		if body == player and body.has_method("take_damage"):
			body.take_damage(touch_damage)
			contact_timer = contact_cooldown
			return


func _update_animation(delta: float) -> void:
	if animation_frames <= 1:
		return
	animation_time += delta
	sprite.frame = int(animation_time * animation_fps) % animation_frames


func _make_defeat_info(source: String) -> Dictionary:
	return {
		"position": global_position,
		"experience_value": experience_value,
		"counts_as_defeat": true,
		"charges_ultimate": source != "ultimate",
		"is_boss": false,
		"source": source,
	}


func _make_circle_telegraph(center: Vector2, radius: float, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.global_position = center
	line.closed = true
	line.width = width
	line.default_color = color
	line.z_index = 80
	for index in range(40):
		var angle := TAU * float(index) / 40.0
		line.add_point(Vector2.RIGHT.rotated(angle) * radius)
	return line
