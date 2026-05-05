class_name Fireball
extends Area2D

@export var speed := 540.0
@export var lifetime := 2.4

var direction := Vector2.RIGHT
var damage := 1
var has_hit := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(origin: Vector2, travel_direction: Vector2, attack_damage: int, _params := {}) -> void:
	global_position = origin
	direction = travel_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	damage = attack_damage
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if has_hit:
		return
	if not body.is_in_group("enemies"):
		return

	has_hit = true
	if body.has_method("take_damage"):
		body.take_damage(damage, "projectile")
	queue_free()
