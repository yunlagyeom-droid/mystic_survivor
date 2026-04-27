class_name ExperienceGem
extends Area2D

@export var value := 1
@export var attract_radius := 165.0
@export var collect_radius := 24.0
@export var min_speed := 90.0
@export var max_speed := 560.0

var player: Player
var bob_time := 0.0
var collected := false

@onready var gem_visual: Polygon2D = $Gem
@onready var glow_visual: Polygon2D = $Glow


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(spawn_position: Vector2, experience_value: int) -> void:
	global_position = spawn_position
	value = experience_value


func _physics_process(delta: float) -> void:
	bob_time += delta
	gem_visual.position.y = sin(bob_time * 7.0) * 2.0
	glow_visual.scale = Vector2.ONE * (1.0 + sin(bob_time * 5.0) * 0.08)

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return

	var distance := global_position.distance_to(player.global_position)
	if distance <= collect_radius:
		_collect()
		return

	if distance <= attract_radius:
		var pull := 1.0 - distance / attract_radius
		var speed := lerpf(min_speed, max_speed, pull)
		global_position = global_position.move_toward(player.global_position, speed * delta)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		player = body
		_collect()


func _collect() -> void:
	if collected:
		return

	collected = true
	if is_instance_valid(player):
		player.add_experience(value)
	queue_free()
