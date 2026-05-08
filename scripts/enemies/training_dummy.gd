extends StaticBody2D

signal defeated(defeat_info: Dictionary)

const CombatFeedback := preload("res://scripts/ui/world_combat_feedback.gd")

@export var max_health := 2000
@export var animation_frames := 6
@export var animation_fps := 7.0

var current_health := 1
var animation_time := 0.0
var hit_motion_timer := 0.0
var base_sprite_scale := Vector2.ONE
var health_bar := {}

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		base_sprite_scale = sprite.scale
	health_bar = CombatFeedback.make_health_bar(self, 92.0, -86.0, Color(0.9, 0.16, 0.12, 0.95))
	CombatFeedback.update_health_bar(health_bar, current_health, max_health, false)


func setup_player(_target: Node) -> void:
	pass


func _process(delta: float) -> void:
	animation_time += delta
	hit_motion_timer = maxf(0.0, hit_motion_timer - delta)
	if sprite == null:
		return

	if animation_frames > 1:
		sprite.frame = int(animation_time * animation_fps) % animation_frames
	sprite.modulate = sprite.modulate.lerp(Color.WHITE, minf(1.0, delta * 12.0))
	if hit_motion_timer > 0.0:
		sprite.scale = base_sprite_scale * Vector2(1.08, 0.92)
	else:
		sprite.scale = sprite.scale.lerp(base_sprite_scale, minf(1.0, delta * 18.0))


func take_damage(amount: int, _source := "attack") -> void:
	current_health = maxi(1, current_health - amount)
	if current_health <= 1:
		current_health = max_health
	if sprite != null:
		sprite.modulate = Color(1.55, 1.45, 1.45)
		hit_motion_timer = 0.1
	CombatFeedback.update_health_bar(health_bar, current_health, max_health, false)
	CombatFeedback.spawn_damage_number(self, amount, -104.0)
