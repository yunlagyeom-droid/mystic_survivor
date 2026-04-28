class_name Slime
extends CharacterBody2D

signal died(position: Vector2, experience_value: int)

@export var move_speed := 105.0
@export var max_health := 36
@export var touch_damage := 8
@export var contact_cooldown := 0.65
@export var experience_value := 2

var player: Player
var current_health := 36
var contact_timer := 0.0
var is_dead := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	contact_timer = maxf(0.0, contact_timer - delta)
	sprite.modulate = sprite.modulate.lerp(Color.WHITE, minf(1.0, delta * 12.0))

	if is_dead:
		return

	if not is_instance_valid(player):
		return

	var direction := (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0

	_try_damage_player()


func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health -= amount
	sprite.modulate = Color(1.4, 1.4, 1.4)

	if current_health <= 0:
		is_dead = true
		died.emit(global_position, experience_value)
		queue_free()


func _try_damage_player() -> void:
	if contact_timer > 0.0:
		return

	for body in attack_area.get_overlapping_bodies():
		if body is Player:
			body.take_damage(touch_damage)
			contact_timer = contact_cooldown
			return
