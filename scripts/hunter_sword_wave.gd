class_name HunterSwordWave
extends Area2D

const BASIC_TEXTURE := preload("res://assets/players/hunter/skills/variants/v11_sword_wave_basic_bold.png")
const ENHANCED_TEXTURE := preload("res://assets/players/hunter/skills/variants/v12_sword_wave_enhanced_large.png")
const BASIC_REF_SHEET_PATH := "res://assets/players/hunter/skills/variants/hunter_sword_wave_basic_crescent_v1.png"
const ENHANCED_REF_SHEET_PATH := "res://assets/players/hunter/skills/variants/hunter_sword_wave_enhanced_crescent_v1.png"

@export var basic_speed := 2100.0
@export var basic_travel_distance := 1350.0
@export var basic_scale := 0.2
@export var basic_collision_size := Vector2(360.0, 160.0)
@export var enhanced_speed := 1950.0
@export var enhanced_travel_distance := 1450.0
@export var enhanced_scale := 0.26
@export var enhanced_collision_size := Vector2(480.0, 220.0)
@export var basic_frame_count := 1
@export var enhanced_frame_count := 1
@export var leading_cut_duration := 0.09
@export var leading_cut_enabled := false

var direction := Vector2.RIGHT
var damage := 1
var speed := 620.0
var lifetime := 0.9
var max_lifetime := 0.9
var hit_bodies: Array[Node] = []
var active_collision_size := Vector2(360.0, 160.0)
var active_enhanced := false
var additive_material: CanvasItemMaterial

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_ensure_nodes()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func setup(origin: Vector2, travel_direction: Vector2, attack_damage: int, params := {}) -> void:
	_ensure_nodes()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	global_position = origin
	direction = travel_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	damage = attack_damage
	rotation = direction.angle()

	active_enhanced = bool(params.get("enhanced", false))
	var speed_multiplier := clampf(float(params.get("speed_multiplier", 1.0)), 1.0, 1.8)
	var size_multiplier := clampf(float(params.get("size_multiplier", 1.0)), 0.75, 1.65)
	var basic_ref_texture := _load_texture(BASIC_REF_SHEET_PATH)
	var enhanced_ref_texture := _load_enhanced_ref_texture()
	var active_texture := enhanced_ref_texture if active_enhanced and enhanced_ref_texture != null else (ENHANCED_TEXTURE if active_enhanced else (basic_ref_texture if basic_ref_texture != null else BASIC_TEXTURE))

	_build_additive_material()
	sprite.texture = active_texture
	sprite.material = additive_material
	sprite.scale = Vector2.ONE * (enhanced_scale if active_enhanced else basic_scale) * size_multiplier
	sprite.hframes = enhanced_frame_count if active_enhanced and enhanced_ref_texture != null else (basic_frame_count if not active_enhanced and basic_ref_texture != null else 1)
	sprite.vframes = 1
	sprite.frame = 0
	sprite.modulate = Color(1.18, 0.84, 0.78, 0.92) if active_enhanced else Color(1.08, 0.82, 0.78, 0.88)

	active_collision_size = (enhanced_collision_size if active_enhanced else basic_collision_size) * size_multiplier
	if active_enhanced:
		speed = enhanced_speed * speed_multiplier
		lifetime = _get_screen_edge_distance(origin, direction, enhanced_travel_distance) / speed
	else:
		speed = basic_speed * speed_multiplier
		lifetime = _get_screen_edge_distance(origin, direction, basic_travel_distance) / speed
	max_lifetime = lifetime

	collision_shape.shape = collision_shape.shape.duplicate()
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = active_collision_size

	if leading_cut_enabled:
		_spawn_leading_cut_line(origin, speed * lifetime)


func _physics_process(delta: float) -> void:
	var previous_position := global_position
	global_position += direction * speed * delta
	lifetime -= delta
	_update_animation_frame()
	_hit_enemies_along_segment(previous_position, global_position)

	if lifetime <= 0.0:
		queue_free()


func _update_animation_frame() -> void:
	if sprite.hframes <= 1 or max_lifetime <= 0.0:
		return

	var progress := clampf(1.0 - lifetime / max_lifetime, 0.0, 0.999)
	sprite.frame = mini(int(progress * float(sprite.hframes)), sprite.hframes - 1)


func _hit_enemies_along_segment(from_position: Vector2, to_position: Vector2) -> void:
	var segment_start := from_position - direction * active_collision_size.x * 0.45
	var segment_end := to_position + direction * active_collision_size.x * 0.45
	var hit_radius := active_collision_size.y * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		if _distance_to_segment(enemy_node.global_position, segment_start, segment_end) <= hit_radius:
			_try_hit_body(enemy)


func _try_hit_body(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	if hit_bodies.has(body):
		return

	hit_bodies.append(body)
	if body.has_method("take_damage"):
		body.call("take_damage", damage, "projectile")
	var enemy_node := body as Node2D
	if enemy_node != null:
		_spawn_hit_cut(enemy_node.global_position)


func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(segment_start)
	var t := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * t)


func _get_screen_edge_distance(origin: Vector2, travel_direction: Vector2, fallback_distance: float) -> float:
	var viewport := get_viewport()
	if viewport == null:
		return fallback_distance
	var camera := viewport.get_camera_2d()
	if camera == null:
		return fallback_distance
	var viewport_size := viewport.get_visible_rect().size * camera.zoom
	var min_corner := camera.global_position - viewport_size * 0.5
	var max_corner := camera.global_position + viewport_size * 0.5
	var candidates: Array[float] = []
	if absf(travel_direction.x) > 0.001:
		var x_bound := max_corner.x if travel_direction.x > 0.0 else min_corner.x
		var x_distance := (x_bound - origin.x) / travel_direction.x
		if x_distance > 0.0:
			candidates.append(x_distance)
	if absf(travel_direction.y) > 0.001:
		var y_bound := max_corner.y if travel_direction.y > 0.0 else min_corner.y
		var y_distance := (y_bound - origin.y) / travel_direction.y
		if y_distance > 0.0:
			candidates.append(y_distance)
	if candidates.is_empty():
		return fallback_distance
	var edge_distance := candidates[0]
	for candidate in candidates:
		edge_distance = minf(edge_distance, candidate)
	return clampf(edge_distance + 180.0, 420.0, 1800.0)


func _spawn_leading_cut_line(origin: Vector2, travel_distance: float) -> void:
	var parent_node := get_parent() as Node2D
	if parent_node == null:
		return
	var cut_line := Line2D.new()
	cut_line.width = 4.0 if active_enhanced else 3.0
	cut_line.default_color = Color(1.0, 0.88, 0.78, 0.88)
	cut_line.z_index = 38
	cut_line.points = PackedVector2Array([origin + direction * 12.0, origin + direction * travel_distance])
	parent_node.add_child(cut_line)

	var red_line := Line2D.new()
	red_line.width = 2.0
	red_line.default_color = Color(1.0, 0.04, 0.02, 0.58)
	red_line.z_index = 37
	var normal := direction.orthogonal() * (9.0 if active_enhanced else 6.0)
	red_line.points = PackedVector2Array([origin + normal, origin + direction * travel_distance + normal * 0.35])
	parent_node.add_child(red_line)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(cut_line, "modulate:a", 0.0, leading_cut_duration)
	tween.tween_property(red_line, "modulate:a", 0.0, leading_cut_duration + 0.04)
	tween.finished.connect(cut_line.queue_free)
	tween.finished.connect(red_line.queue_free)


func _spawn_hit_cut(world_position: Vector2) -> void:
	var parent_node := get_parent() as Node2D
	if parent_node == null:
		return
	var hit_line := Line2D.new()
	hit_line.width = 3.4 if active_enhanced else 2.6
	hit_line.default_color = Color(1.0, 0.9, 0.82, 0.88)
	hit_line.z_index = 42
	var normal := direction.orthogonal()
	var half_width := 42.0 if active_enhanced else 32.0
	hit_line.points = PackedVector2Array([world_position - normal * half_width, world_position + normal * half_width])
	parent_node.add_child(hit_line)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(hit_line, "modulate:a", 0.0, 0.16)
	tween.tween_property(hit_line, "width", 0.4, 0.16)
	tween.finished.connect(hit_line.queue_free)


func _ensure_nodes() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _load_enhanced_ref_texture() -> Texture2D:
	return _load_texture(ENHANCED_REF_SHEET_PATH)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _build_additive_material() -> void:
	if additive_material != null:
		return
	additive_material = CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _on_body_entered(body: Node) -> void:
	_try_hit_body(body)
