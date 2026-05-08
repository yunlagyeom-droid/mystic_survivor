class_name MagnetPickup
extends Area2D

enum MagnetMode {
	RANGE,
	ALL,
}

@export var mode := MagnetMode.RANGE
@export var collect_range := 520.0

var bob_time := 0.0
var collected := false

@onready var glow: Polygon2D = $Glow
@onready var core: Polygon2D = $Core
@onready var range_ring: Line2D = $RangeRing


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_mode_visual()


func setup(spawn_position: Vector2, pickup_mode: int, radius: float) -> void:
	global_position = spawn_position
	mode = pickup_mode
	collect_range = radius
	if is_inside_tree():
		_apply_mode_visual()


func _process(delta: float) -> void:
	bob_time += delta
	if core != null:
		core.position.y = sin(bob_time * 6.5) * 2.5
	if glow != null:
		glow.scale = Vector2.ONE * (1.0 + sin(bob_time * 4.0) * 0.08)
	if range_ring != null:
		range_ring.rotation += delta * 1.6


func _on_body_entered(body: Node) -> void:
	if collected or not body.is_in_group("player"):
		return

	collected = true
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_activate_magnet_pickup"):
		scene.call("_activate_magnet_pickup", mode, global_position, collect_range)
	queue_free()


func _apply_mode_visual() -> void:
	var is_full := mode == MagnetMode.ALL
	if glow != null:
		glow.color = Color(1.0, 0.28, 0.18, 0.34) if is_full else Color(0.55, 0.95, 1.0, 0.32)
	if core != null:
		core.color = Color(1.0, 0.78, 0.62, 1.0) if is_full else Color(0.72, 1.0, 1.0, 1.0)
	if range_ring != null:
		range_ring.default_color = Color(1.0, 0.38, 0.25, 0.72) if is_full else Color(0.52, 0.92, 1.0, 0.62)
		range_ring.width = 4.0 if is_full else 2.6
