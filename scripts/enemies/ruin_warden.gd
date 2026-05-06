class_name RuinWarden
extends CharacterBody2D

signal defeated(defeat_info: Dictionary)

@export var move_speed := 90.0
@export var max_health := 1450
@export var touch_damage := 14
@export var contact_cooldown := 0.8
@export var experience_value := 60
@export var animation_frames := 6
@export var animation_fps := 7.0
@export var slam_damage := 28
@export var dash_damage := 24
@export var shockwave_damage := 26
@export var arena_radius := 1500.0
@export var arena_bounds := Vector2.ZERO

var player: Node2D
var current_health := 1
var contact_timer := 0.0
var pattern_timer := 1.2
var pattern_state := ""
var pattern_windup := 0.0
var pattern_direction := Vector2.DOWN
var pattern_target := Vector2.ZERO
var animation_time := 0.0
var is_dead := false
var enraged := false
var telegraph_node: Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	add_to_group("bosses")
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup_player(target: Node) -> void:
	player = target as Node2D
	if target != null and target.has_method("get_world_bounds"):
		arena_bounds = target.get_world_bounds()
	elif target != null and "world_radius" in target:
		arena_radius = float(target.world_radius)
		arena_bounds = Vector2.ONE * arena_radius


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	contact_timer = maxf(0.0, contact_timer - delta)
	if sprite != null:
		sprite.modulate = sprite.modulate.lerp(Color.WHITE, minf(1.0, delta * 10.0))
		_update_animation(delta)

	if not is_instance_valid(player):
		return

	if not enraged and current_health <= int(float(max_health) * 0.5):
		enraged = true
		move_speed *= 1.16
		pattern_timer = minf(pattern_timer, 0.45)

	if pattern_state != "":
		_process_pattern(delta)
	else:
		_process_chase(delta)

	_try_touch_damage()


func take_damage(amount: int, source := "attack") -> void:
	if is_dead:
		return

	current_health -= amount
	if sprite != null:
		sprite.modulate = Color(1.65, 1.42, 1.28)

	if current_health <= 0:
		is_dead = true
		_clear_telegraph()
		defeated.emit(_make_defeat_info(source))
		queue_free()


func _process_chase(delta: float) -> void:
	pattern_timer -= delta
	var offset := player.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized()

	if distance > 220.0:
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if direction.x != 0.0 and sprite != null:
		sprite.flip_h = direction.x < 0.0

	if pattern_timer <= 0.0:
		_start_next_pattern(distance)


func _start_next_pattern(distance: float) -> void:
	pattern_direction = (player.global_position - global_position).normalized()
	if pattern_direction == Vector2.ZERO:
		pattern_direction = Vector2.DOWN

	var roll := randi() % 3
	if distance > 420.0:
		roll = 1

	match roll:
		0:
			_start_slam()
		1:
			_start_dash()
		_:
			_start_shockwave()


func _start_slam() -> void:
	pattern_state = "slam"
	pattern_windup = 0.72 if not enraged else 0.56
	velocity = Vector2.ZERO
	telegraph_node = _make_wedge_telegraph(300.0, deg_to_rad(76.0), Color(1.0, 0.42, 0.24, 0.42))
	add_child(telegraph_node)


func _start_dash() -> void:
	pattern_state = "dash"
	pattern_windup = 0.64 if not enraged else 0.48
	pattern_target = global_position + pattern_direction * 620.0
	var bounds := arena_bounds if arena_bounds.x > 0.0 and arena_bounds.y > 0.0 else Vector2.ONE * arena_radius
	pattern_target.x = clampf(pattern_target.x, -bounds.x, bounds.x)
	pattern_target.y = clampf(pattern_target.y, -bounds.y, bounds.y)
	velocity = Vector2.ZERO
	telegraph_node = _make_dash_telegraph(pattern_target, Color(1.0, 0.26, 0.18, 0.78))
	get_tree().current_scene.add_child(telegraph_node)


func _start_shockwave() -> void:
	pattern_state = "shockwave"
	pattern_windup = 0.9 if not enraged else 0.68
	velocity = Vector2.ZERO
	telegraph_node = _make_circle_telegraph(global_position, 290.0, Color(0.78, 0.54, 1.0, 0.76), 5.0)
	get_tree().current_scene.add_child(telegraph_node)


func _process_pattern(delta: float) -> void:
	pattern_windup -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if pattern_windup > 0.0:
		return

	match pattern_state:
		"slam":
			_finish_slam()
		"dash":
			_finish_dash()
		"shockwave":
			_finish_shockwave()

	pattern_state = ""
	pattern_timer = 1.45 if not enraged else 1.05
	_clear_telegraph()


func _finish_slam() -> void:
	if not is_instance_valid(player):
		return
	var offset := player.global_position - global_position
	if offset.length() > 300.0:
		return
	var angle := absf(pattern_direction.angle_to(offset.normalized()))
	if angle <= deg_to_rad(38.0) and player.has_method("take_damage"):
		player.take_damage(slam_damage)


func _finish_dash() -> void:
	var start := global_position
	global_position = pattern_target
	velocity = Vector2.ZERO
	if is_instance_valid(player):
		var path := pattern_target - start
		var length_squared := path.length_squared()
		if length_squared > 0.0:
			var to_player := player.global_position - start
			var t := clampf(to_player.dot(path) / length_squared, 0.0, 1.0)
			var closest := start + path * t
			if player.global_position.distance_to(closest) <= 70.0 and player.has_method("take_damage"):
				player.take_damage(dash_damage)


func _finish_shockwave() -> void:
	if is_instance_valid(player) and player.global_position.distance_to(global_position) <= 290.0:
		if player.has_method("take_damage"):
			player.take_damage(shockwave_damage)


func _try_touch_damage() -> void:
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


func _make_wedge_telegraph(radius: float, arc: float, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	var points: PackedVector2Array = [Vector2.ZERO]
	for index in range(18):
		var t := float(index) / 17.0
		var angle := lerpf(-arc * 0.5, arc * 0.5, t)
		points.append(pattern_direction.rotated(angle) * radius)
	polygon.polygon = points
	polygon.color = color
	polygon.z_index = 78
	return polygon


func _make_dash_telegraph(target: Vector2, color: Color) -> Line2D:
	var line := Line2D.new()
	line.global_position = Vector2.ZERO
	line.width = 18.0
	line.default_color = color
	line.z_index = 79
	line.add_point(global_position)
	line.add_point(target)
	return line


func _make_circle_telegraph(center: Vector2, radius: float, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.global_position = center
	line.closed = true
	line.width = width
	line.default_color = color
	line.z_index = 79
	for index in range(56):
		var angle := TAU * float(index) / 56.0
		line.add_point(Vector2.RIGHT.rotated(angle) * radius)
	return line


func _clear_telegraph() -> void:
	if is_instance_valid(telegraph_node):
		telegraph_node.queue_free()
	telegraph_node = null


func _make_defeat_info(source: String) -> Dictionary:
	return {
		"position": global_position,
		"experience_value": experience_value,
		"counts_as_defeat": true,
		"charges_ultimate": source != "ultimate",
		"is_boss": true,
		"source": source,
	}
