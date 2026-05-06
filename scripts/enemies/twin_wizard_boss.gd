class_name TwinWizardBoss
extends CharacterBody2D

signal defeated(defeat_info: Dictionary)

const EFFECT_FRAME_SIZE := 100
const MAGIC_SPELL_TEXTURE := preload("res://assets/_asset_store/Free Pixel Effects Pack/1_magicspell_spritesheet.png")
const CASTING_TEXTURE := preload("res://assets/_asset_store/Free Pixel Effects Pack/4_casting_spritesheet.png")
const MAGIC_HIT_TEXTURE := preload("res://assets/_asset_store/Free Pixel Effects Pack/5_magickahit_spritesheet.png")
const PROTECTION_TEXTURE := preload("res://assets/_asset_store/Free Pixel Effects Pack/8_protectioncircle_spritesheet.png")
const VORTEX_TEXTURE := preload("res://assets/_asset_store/Free Pixel Effects Pack/13_vortex_spritesheet.png")
const FEL_SPELL_TEXTURE := preload("res://assets/_asset_store/Free Pixel Effects Pack/17_felspell_spritesheet.png")
const MIDNIGHT_TEXTURE := preload("res://assets/_asset_store/Free Pixel Effects Pack/18_midnight_spritesheet.png")

@export var boss_id := "twin_wizard"
@export var is_primary := true
@export var move_speed := 92.0
@export var max_health := 1200
@export var touch_damage := 10
@export var contact_cooldown := 0.75
@export var experience_value := 80
@export var preferred_range := 420.0
@export var pattern_cooldown := 1.55
@export var empowered_cooldown_multiplier := 0.68
@export var arena_radius := 1500.0
@export var arena_bounds := Vector2.ZERO
@export var idle_texture: Texture2D
@export var move_texture: Texture2D
@export var attack_1_texture: Texture2D
@export var attack_2_texture: Texture2D
@export var take_hit_texture: Texture2D
@export var death_texture: Texture2D
@export var animation_fps := 8.0

var player: Node2D
var current_health := 1
var contact_timer := 0.0
var pattern_timer := 1.0
var pattern_state := ""
var pattern_windup := 0.0
var pending_target := Vector2.ZERO
var pending_direction := Vector2.DOWN
var animation_time := 0.0
var current_animation := ""
var current_frame_count := 1
var is_dead := false
var enraged := false
var empowered_by_twin_death := false
var telegraph_nodes: Array[Node] = []
var add_material: CanvasItemMaterial

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("twin_bosses")
	add_material = CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_play_animation("idle")


func setup_player(target: Node) -> void:
	player = target as Node2D
	if target != null and target.has_method("get_world_bounds"):
		arena_bounds = target.get_world_bounds()
	elif target != null and "world_radius" in target:
		arena_radius = float(target.world_radius)
		arena_bounds = Vector2.ONE * arena_radius


func empower_from_twin_death() -> void:
	if empowered_by_twin_death or is_dead:
		return
	empowered_by_twin_death = true
	move_speed *= 1.18
	pattern_timer = minf(pattern_timer, 0.35)
	_spawn_sheet_vfx(PROTECTION_TEXTURE, global_position + Vector2(0, -42), 2.4, 0.55, 91)


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
		move_speed *= 1.12
		pattern_timer = minf(pattern_timer, 0.45)

	if pattern_state != "":
		_process_pattern(delta)
	else:
		_process_movement(delta)
		_try_start_pattern(delta)

	_try_touch_damage()


func take_damage(amount: int, source := "attack") -> void:
	if is_dead:
		return

	current_health -= amount
	if sprite != null:
		sprite.modulate = Color(1.65, 1.35, 1.35)
		_play_animation("hit")

	if current_health <= 0:
		is_dead = true
		_clear_telegraphs()
		_spawn_sheet_vfx(MAGIC_HIT_TEXTURE, global_position + Vector2(0, -44), 2.2, 0.5, 94)
		defeated.emit(_make_defeat_info(source))
		queue_free()


func _process_movement(_delta: float) -> void:
	var offset := player.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	if distance > preferred_range + 80.0:
		velocity = direction * move_speed
		_play_animation("move")
	elif distance < preferred_range - 120.0:
		velocity = -direction * move_speed * 0.78
		_play_animation("move")
	else:
		velocity = Vector2.ZERO
		_play_animation("idle")
	move_and_slide()
	_clamp_self_to_arena()

	if direction.x != 0.0 and sprite != null:
		sprite.flip_h = direction.x < 0.0


func _try_start_pattern(delta: float) -> void:
	pattern_timer -= delta
	if pattern_timer > 0.0:
		return

	var roll := randf()
	if is_primary:
		if _has_living_twin() and roll < 0.26:
			_begin_ritual_cross()
		elif roll < 0.58:
			_begin_vortex_burst()
		elif roll < 0.82:
			_begin_fel_zone()
		else:
			_begin_midnight_ring()
	else:
		if _has_living_twin() and roll < 0.18:
			_begin_ritual_cross()
		elif roll < 0.58:
			_begin_magic_lance()
		else:
			_begin_curse_step()


func _begin_vortex_burst() -> void:
	pattern_state = "vortex"
	pattern_windup = _scaled_windup(0.86)
	pending_target = player.global_position
	velocity = Vector2.ZERO
	_play_animation("attack1")
	telegraph_nodes.append(_make_circle_telegraph(pending_target, 150.0, Color(1.0, 0.18, 0.22, 0.76), 5.0))
	_spawn_sheet_vfx(CASTING_TEXTURE, global_position + Vector2(0, -48), 1.25, pattern_windup, 88)


func _begin_fel_zone() -> void:
	pattern_state = "fel_zone"
	pattern_windup = _scaled_windup(1.0)
	pending_target = player.global_position
	velocity = Vector2.ZERO
	_play_animation("attack2")
	telegraph_nodes.append(_make_circle_telegraph(pending_target, 215.0, Color(0.4, 1.0, 0.2, 0.76), 5.0))
	_spawn_sheet_vfx(FEL_SPELL_TEXTURE, pending_target, 2.8, pattern_windup, 82)


func _begin_midnight_ring() -> void:
	pattern_state = "midnight"
	pattern_windup = _scaled_windup(1.05)
	pending_target = global_position
	velocity = Vector2.ZERO
	_play_animation("attack2")
	telegraph_nodes.append(_make_circle_telegraph(pending_target, 300.0, Color(0.65, 0.34, 1.0, 0.78), 5.0))
	_spawn_sheet_vfx(MIDNIGHT_TEXTURE, pending_target, 3.5, pattern_windup, 82)


func _begin_magic_lance() -> void:
	pattern_state = "lance"
	pattern_windup = _scaled_windup(0.58)
	pending_target = player.global_position
	pending_direction = (pending_target - global_position).normalized()
	if pending_direction == Vector2.ZERO:
		pending_direction = Vector2.DOWN
	velocity = Vector2.ZERO
	_play_animation("attack1")
	telegraph_nodes.append(_make_line_telegraph(global_position, global_position + pending_direction * 760.0, Color(0.95, 0.25, 1.0, 0.72), 14.0))
	_spawn_sheet_vfx(CASTING_TEXTURE, global_position + Vector2(0, -34), 1.0, pattern_windup, 88)


func _begin_curse_step() -> void:
	pattern_state = "curse_step"
	pattern_windup = _scaled_windup(0.72)
	pending_target = player.global_position
	velocity = Vector2.ZERO
	_play_animation("attack1")
	telegraph_nodes.append(_make_circle_telegraph(pending_target, 115.0, Color(0.8, 0.15, 1.0, 0.74), 4.0))
	_spawn_sheet_vfx(MAGIC_SPELL_TEXTURE, pending_target, 1.55, pattern_windup, 82)


func _begin_ritual_cross() -> void:
	pattern_state = "ritual"
	pattern_windup = _scaled_windup(1.16)
	pending_target = player.global_position
	velocity = Vector2.ZERO
	_play_animation("attack2" if is_primary else "attack1")
	var length := 620.0
	telegraph_nodes.append(_make_line_telegraph(pending_target + Vector2.LEFT * length, pending_target + Vector2.RIGHT * length, Color(1.0, 0.15, 0.58, 0.72), 22.0))
	telegraph_nodes.append(_make_line_telegraph(pending_target + Vector2.UP * length, pending_target + Vector2.DOWN * length, Color(0.38, 1.0, 0.42, 0.72), 22.0))
	telegraph_nodes.append(_make_circle_telegraph(pending_target, 120.0, Color(1.0, 1.0, 1.0, 0.72), 5.0))
	_spawn_sheet_vfx(PROTECTION_TEXTURE, pending_target, 2.4, pattern_windup, 83)


func _process_pattern(delta: float) -> void:
	pattern_windup -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	_clamp_self_to_arena()
	if pattern_windup > 0.0:
		return

	match pattern_state:
		"vortex":
			_finish_vortex_burst()
		"fel_zone":
			_finish_area_pattern(215.0, 32, FEL_SPELL_TEXTURE, 3.1)
		"midnight":
			_finish_area_pattern(300.0, 34, MIDNIGHT_TEXTURE, 3.8)
		"lance":
			_finish_magic_lance()
		"curse_step":
			_finish_area_pattern(115.0, 20, MAGIC_HIT_TEXTURE, 1.6)
		"ritual":
			_finish_ritual_cross()

	pattern_state = ""
	pattern_timer = _next_pattern_cooldown()
	_clear_telegraphs()


func _finish_vortex_burst() -> void:
	_spawn_sheet_vfx(VORTEX_TEXTURE, pending_target, 2.1, 0.5, 90)
	if _player_in_radius(pending_target, 150.0):
		player.take_damage(28)


func _finish_area_pattern(radius: float, damage: int, texture: Texture2D, scale_amount: float) -> void:
	_spawn_sheet_vfx(texture, pending_target, scale_amount, 0.55, 90)
	if _player_in_radius(pending_target, radius):
		player.take_damage(damage)


func _finish_magic_lance() -> void:
	var start := global_position
	var end := global_position + pending_direction * 760.0
	var closest := _closest_point_on_segment(player.global_position, start, end)
	_spawn_sheet_vfx(MAGIC_SPELL_TEXTURE, closest, 1.35, 0.35, 90)
	if player.global_position.distance_to(closest) <= 62.0:
		player.take_damage(18)


func _finish_ritual_cross() -> void:
	_spawn_sheet_vfx(PROTECTION_TEXTURE, pending_target, 3.0, 0.6, 90)
	var delta := player.global_position - pending_target
	if absf(delta.x) <= 70.0 and absf(delta.y) <= 640.0:
		player.take_damage(30)
	elif absf(delta.y) <= 70.0 and absf(delta.x) <= 640.0:
		player.take_damage(30)
	elif _player_in_radius(pending_target, 130.0):
		player.take_damage(30)


func _try_touch_damage() -> void:
	if contact_timer > 0.0 or attack_area == null:
		return

	for body in attack_area.get_overlapping_bodies():
		if body == player and body.has_method("take_damage"):
			body.take_damage(touch_damage)
			contact_timer = contact_cooldown
			return


func _player_in_radius(center: Vector2, radius: float) -> bool:
	return is_instance_valid(player) and player.has_method("take_damage") and player.global_position.distance_to(center) <= radius


func _clamp_self_to_arena() -> void:
	var bounds := arena_bounds if arena_bounds.x > 0.0 and arena_bounds.y > 0.0 else Vector2.ONE * arena_radius
	global_position.x = clampf(global_position.x, -bounds.x, bounds.x)
	global_position.y = clampf(global_position.y, -bounds.y, bounds.y)


func _closest_point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var path := end - start
	var length_squared := path.length_squared()
	if length_squared <= 0.0:
		return start
	var t := clampf((point - start).dot(path) / length_squared, 0.0, 1.0)
	return start + path * t


func _scaled_windup(base_windup: float) -> float:
	var multiplier := 1.0
	if enraged:
		multiplier *= 0.82
	if empowered_by_twin_death:
		multiplier *= 0.78
	return base_windup * multiplier


func _next_pattern_cooldown() -> float:
	var cooldown := pattern_cooldown
	if enraged:
		cooldown *= 0.82
	if empowered_by_twin_death:
		cooldown *= empowered_cooldown_multiplier
	return cooldown


func _has_living_twin() -> bool:
	for boss in get_tree().get_nodes_in_group("twin_bosses"):
		if boss != self and is_instance_valid(boss):
			return true
	return false


func _make_circle_telegraph(center: Vector2, radius: float, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.global_position = center
	line.closed = true
	line.width = width
	line.default_color = color
	line.z_index = 84
	for index in range(64):
		var angle := TAU * float(index) / 64.0
		line.add_point(Vector2.RIGHT.rotated(angle) * radius)
	get_tree().current_scene.add_child(line)
	return line


func _make_line_telegraph(start: Vector2, end: Vector2, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.global_position = Vector2.ZERO
	line.width = width
	line.default_color = color
	line.z_index = 84
	line.add_point(start)
	line.add_point(end)
	get_tree().current_scene.add_child(line)
	return line


func _clear_telegraphs() -> void:
	for node in telegraph_nodes:
		if is_instance_valid(node):
			node.queue_free()
	telegraph_nodes.clear()


func _spawn_sheet_vfx(texture: Texture2D, world_position: Vector2, scale_amount: float, duration: float, z_index: int) -> Sprite2D:
	var vfx := Sprite2D.new()
	vfx.texture = texture
	vfx.region_enabled = true
	vfx.region_rect = Rect2(Vector2.ZERO, Vector2.ONE * EFFECT_FRAME_SIZE)
	vfx.centered = true
	vfx.global_position = world_position
	vfx.scale = Vector2.ONE * scale_amount
	vfx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vfx.material = add_material
	vfx.z_index = z_index
	get_tree().current_scene.add_child(vfx)
	_animate_vfx(vfx, texture, maxf(0.12, duration))
	return vfx


func _animate_vfx(vfx: Sprite2D, texture: Texture2D, duration: float) -> void:
	var columns := maxi(1, int(texture.get_width() / EFFECT_FRAME_SIZE))
	var rows := maxi(1, int(texture.get_height() / EFFECT_FRAME_SIZE))
	var frame_count := columns * rows
	var frame_time := duration / float(maxi(1, frame_count))
	for frame in range(frame_count):
		if not is_instance_valid(vfx):
			return
		var column := frame % columns
		var row := int(frame / columns)
		vfx.region_rect = Rect2(Vector2(column, row) * EFFECT_FRAME_SIZE, Vector2.ONE * EFFECT_FRAME_SIZE)
		await get_tree().create_timer(frame_time).timeout
	if is_instance_valid(vfx):
		vfx.queue_free()


func _play_animation(name: String) -> void:
	if current_animation == name or sprite == null:
		return

	var texture := _get_animation_texture(name)
	if texture == null:
		return

	current_animation = name
	animation_time = 0.0
	current_frame_count = maxi(1, int(texture.get_width() / texture.get_height()))
	sprite.texture = texture
	sprite.hframes = current_frame_count
	sprite.vframes = 1
	sprite.frame = 0


func _update_animation(delta: float) -> void:
	if current_frame_count <= 1 or sprite == null:
		return
	animation_time += delta
	sprite.frame = int(animation_time * animation_fps) % current_frame_count


func _get_animation_texture(name: String) -> Texture2D:
	match name:
		"move":
			return move_texture if move_texture != null else idle_texture
		"attack1":
			return attack_1_texture if attack_1_texture != null else idle_texture
		"attack2":
			return attack_2_texture if attack_2_texture != null else attack_1_texture
		"hit":
			return take_hit_texture if take_hit_texture != null else idle_texture
		"death":
			return death_texture if death_texture != null else idle_texture
		_:
			return idle_texture


func _make_defeat_info(source: String) -> Dictionary:
	return {
		"position": global_position,
		"experience_value": experience_value,
		"counts_as_defeat": true,
		"charges_ultimate": source != "ultimate",
		"is_boss": true,
		"source": source,
		"boss_id": boss_id,
		"boss_group": "twin_wizards",
	}
