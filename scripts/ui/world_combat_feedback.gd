class_name WorldCombatFeedback
extends RefCounted


static func make_health_bar(owner: Node2D, width: float, y_offset: float, fill_color: Color) -> Dictionary:
	var root := Node2D.new()
	root.position = Vector2(0.0, y_offset)
	root.z_index = 120
	owner.add_child(root)

	var background := Line2D.new()
	background.width = 6.0
	background.default_color = Color(0.02, 0.01, 0.012, 0.88)
	background.points = PackedVector2Array([Vector2(-width * 0.5, 0.0), Vector2(width * 0.5, 0.0)])
	root.add_child(background)

	var fill := Line2D.new()
	fill.width = 4.0
	fill.default_color = fill_color
	fill.points = PackedVector2Array([Vector2(-width * 0.5, 0.0), Vector2(width * 0.5, 0.0)])
	root.add_child(fill)

	return {
		"root": root,
		"fill": fill,
		"width": width,
	}


static func update_health_bar(health_bar: Dictionary, current_health: int, max_health: int, hide_when_full := true) -> void:
	var root := health_bar.get("root") as Node2D
	var fill := health_bar.get("fill") as Line2D
	if root == null or fill == null:
		return

	var ratio := clampf(float(current_health) / float(maxi(1, max_health)), 0.0, 1.0)
	var width := float(health_bar.get("width", 48.0))
	root.visible = current_health > 0 and (not hide_when_full or ratio < 0.999)
	fill.points = PackedVector2Array([
		Vector2(-width * 0.5, 0.0),
		Vector2(lerpf(-width * 0.5, width * 0.5, ratio), 0.0),
	])


static func spawn_damage_number(owner: Node2D, amount: int, y_offset: float, color := Color(1.0, 0.92, 0.68, 1.0)) -> void:
	if owner == null or owner.get_tree() == null or owner.get_tree().current_scene == null:
		return

	var root := Node2D.new()
	root.global_position = owner.global_position + Vector2(randf_range(-12.0, 12.0), y_offset)
	root.z_index = 210
	owner.get_tree().current_scene.add_child(root)

	var label := Label.new()
	label.text = str(maxi(0, amount))
	label.position = Vector2(-40.0, -14.0)
	label.size = Vector2(80.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label)

	var tween := owner.get_tree().current_scene.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "global_position", root.global_position + Vector2(randf_range(-8.0, 8.0), -48.0), 0.62)
	tween.tween_property(label, "modulate:a", 0.0, 0.62)
	tween.finished.connect(root.queue_free)
