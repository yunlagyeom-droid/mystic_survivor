extends RefCounted


class GothicProgressBar:
	extends Control

	var label: Label
	var title := ""
	var value := 0.0
	var max_value := 1.0
	var fill_color := Color(0.8, 0.1, 0.1)
	var accent_color := Color(0.95, 0.78, 0.48)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.84))
		add_child(label)
		_sync_label()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_sync_label()

	func configure(new_title: String, new_fill_color: Color, new_accent_color: Color) -> void:
		title = new_title
		fill_color = new_fill_color
		accent_color = new_accent_color
		_sync_label()
		queue_redraw()

	func set_values(new_value: float, new_max_value: float) -> void:
		value = maxf(0.0, new_value)
		max_value = maxf(1.0, new_max_value)
		_sync_label()
		queue_redraw()

	func _sync_label() -> void:
		if label == null:
			return
		label.position = Vector2.ZERO
		label.size = size
		label.text = "%s  %d / %d" % [title, int(round(value)), int(round(max_value))]

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size).grow(-1.0)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return

		var ratio := clampf(value / max_value, 0.0, 1.0)
		draw_rect(rect, Color(0.01, 0.012, 0.016, 0.78), true)
		draw_rect(rect, Color(accent_color.r, accent_color.g, accent_color.b, 0.45), false, 1.0)
		draw_rect(rect.grow(-4.0), Color(0.0, 0.0, 0.0, 0.42), true)

		var fill_rect := rect.grow(-5.0)
		fill_rect.size.x *= ratio
		if fill_rect.size.x > 0.0:
			draw_rect(fill_rect, fill_color, true)
			draw_rect(fill_rect, Color(1.0, 1.0, 1.0, 0.16), false, 1.0)

		var left_tip := Vector2(rect.position.x - 8.0, rect.get_center().y)
		var right_tip := Vector2(rect.end.x + 8.0, rect.get_center().y)
		draw_line(left_tip, rect.position + Vector2(0.0, rect.size.y * 0.5), accent_color, 1.0)
		draw_line(rect.end - Vector2(0.0, rect.size.y * 0.5), right_tip, accent_color, 1.0)


class GemStrip:
	extends Control

	var current := 0
	var total := 10
	var gem_color := Color(0.55, 0.82, 1.0)

	func set_gems(new_current: int, new_total: int, new_color: Color) -> void:
		current = maxi(0, new_current)
		total = maxi(1, new_total)
		gem_color = new_color
		queue_redraw()

	func _draw() -> void:
		var count := mini(total, 10)
		if count <= 0:
			return

		var gap := 8.0
		var gem_size := minf(12.0, (size.x - gap * float(count - 1)) / float(count))
		var total_width := gem_size * float(count) + gap * float(count - 1)
		var start_x := (size.x - total_width) * 0.5
		var center_y := size.y * 0.5
		for index in range(count):
			var center := Vector2(start_x + gem_size * 0.5 + float(index) * (gem_size + gap), center_y)
			var filled := index < current
			var color := gem_color if filled else Color(0.58, 0.58, 0.62, 0.32)
			var points := PackedVector2Array([
				center + Vector2(0.0, -gem_size * 0.55),
				center + Vector2(gem_size * 0.45, 0.0),
				center + Vector2(0.0, gem_size * 0.55),
				center + Vector2(-gem_size * 0.45, 0.0),
			])
			draw_colored_polygon(points, color)
			draw_polyline(points + PackedVector2Array([points[0]]), Color(1.0, 0.94, 0.82, 0.5 if filled else 0.22), 1.0)


class SkillSigil:
	extends Control

	var skill_id := ""
	var sigil_color := Color(0.9, 0.14, 0.14)

	func set_sigil_data(new_skill_id: String, new_color: Color) -> void:
		skill_id = new_skill_id
		sigil_color = new_color
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.68))
		draw_circle(center, radius * 0.84, Color(sigil_color.r, sigil_color.g, sigil_color.b, 0.09))
		draw_arc(center, radius, 0.0, TAU, 96, Color(sigil_color.r, sigil_color.g, sigil_color.b, 0.78), 2.0)
		draw_arc(center, radius * 0.72, PI * 0.12, PI * 1.88, 80, Color(1.0, 0.88, 0.72, 0.28), 1.0)

		match skill_id:
			"slash", "attack_damage", "attack_speed", "sword_wave":
				_draw_slash(center, radius * 0.58)
			"dash", "move_speed", "blink":
				_draw_arrows(center, radius * 0.52)
			"guard", "barrier", "max_health":
				_draw_shield(center, radius * 0.5)
			"ultimate":
				_draw_star(center, radius * 0.55)
			"experience_gain", "luck":
				_draw_diamond(center, radius * 0.5)
			_:
				_draw_star(center, radius * 0.46)

	func _draw_slash(center: Vector2, radius: float) -> void:
		var color := Color(1.0, 0.92, 0.84, 0.94)
		draw_line(center + Vector2(-radius, radius * 0.55), center + Vector2(radius, -radius * 0.55), color, 4.0)
		draw_line(center + Vector2(-radius * 0.56, radius * 0.9), center + Vector2(radius * 0.78, -radius * 0.08), sigil_color.lightened(0.28), 2.0)

	func _draw_arrows(center: Vector2, radius: float) -> void:
		var color := Color(0.9, 0.96, 1.0, 0.92)
		for side in [-1.0, 1.0]:
			var base := center + Vector2(side * radius * 0.18, 0.0)
			draw_line(base + Vector2(-side * radius * 0.58, -radius * 0.28), base + Vector2(side * radius * 0.52, 0.0), color, 2.4)
			draw_line(base + Vector2(side * radius * 0.52, 0.0), base + Vector2(-side * radius * 0.58, radius * 0.28), color, 2.4)

	func _draw_shield(center: Vector2, radius: float) -> void:
		var color := Color(0.94, 0.98, 1.0, 0.92)
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.72, -radius * 0.35),
			center + Vector2(radius * 0.45, radius * 0.74),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.45, radius * 0.74),
			center + Vector2(-radius * 0.72, -radius * 0.35),
			center + Vector2(0.0, -radius),
		])
		draw_polyline(points, color, 2.5)
		draw_line(center + Vector2(0.0, -radius * 0.64), center + Vector2(0.0, radius * 0.7), sigil_color.lightened(0.28), 1.8)

	func _draw_star(center: Vector2, radius: float) -> void:
		var color := Color(1.0, 0.92, 0.8, 0.94)
		draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), color, 2.4)
		draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), color, 2.4)
		draw_line(center + Vector2(-radius * 0.58, -radius * 0.58), center + Vector2(radius * 0.58, radius * 0.58), color, 1.5)
		draw_line(center + Vector2(radius * 0.58, -radius * 0.58), center + Vector2(-radius * 0.58, radius * 0.58), color, 1.5)

	func _draw_diamond(center: Vector2, radius: float) -> void:
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.74, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.74, 0.0),
			center + Vector2(0.0, -radius),
		])
		draw_polyline(points, Color(1.0, 0.94, 0.84, 0.94), 2.3)
		draw_circle(center, radius * 0.2, sigil_color.lightened(0.2))


class UltimatePortraitRing:
	extends Control

	var portrait_rect: TextureRect
	var portrait_texture: Texture2D
	var portrait_region := Rect2()
	var progress := 0.0
	var is_charged := false
	var accent_color := Color(0.28, 0.72, 1.0)
	var pulse_time := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_rect = TextureRect.new()
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
		portrait_rect.material = _make_circle_mask_material()
		add_child(portrait_rect)
		_sync_portrait()
		_sync_portrait_rect()
		set_process(true)

	func _process(delta: float) -> void:
		if is_charged:
			pulse_time += delta
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_sync_portrait_rect()

	func configure(new_texture: Texture2D, new_region: Rect2, new_accent_color: Color) -> void:
		portrait_texture = new_texture
		portrait_region = new_region
		accent_color = new_accent_color
		_sync_portrait()
		_sync_portrait_rect()
		queue_redraw()

	func set_charge(new_progress: float, is_ready: bool) -> void:
		progress = clampf(new_progress, 0.0, 1.0)
		is_charged = is_ready
		if not is_charged:
			pulse_time = 0.0
		queue_redraw()

	func _sync_portrait() -> void:
		if portrait_rect == null:
			return
		if portrait_texture == null:
			portrait_rect.texture = null
			return
		if portrait_region.size.x > 0.0 and portrait_region.size.y > 0.0:
			var atlas := AtlasTexture.new()
			atlas.atlas = portrait_texture
			atlas.region = portrait_region
			portrait_rect.texture = atlas
		else:
			portrait_rect.texture = portrait_texture

	func _sync_portrait_rect() -> void:
		if portrait_rect == null:
			return
		var inset := minf(size.x, size.y) * 0.09
		portrait_rect.position = Vector2(inset, inset)
		portrait_rect.size = size - Vector2.ONE * inset * 2.0

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		var pulse := 0.0
		if is_charged:
			pulse = (sin(pulse_time * TAU * 1.35) + 1.0) * 0.5

		draw_circle(center, radius + 10.0 + pulse * 5.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.08 + pulse * 0.12))
		draw_circle(center, radius * 0.83, Color(0.0, 0.0, 0.0, 0.46))
		draw_arc(center, radius, 0.0, TAU, 128, Color(0.1, 0.16, 0.22, 0.95), 8.0)
		draw_arc(center, radius - 8.0, 0.0, TAU, 128, Color(0.84, 0.64, 0.34, 0.34), 1.0)

		var end_angle := -PI * 0.5 + TAU * progress
		if progress > 0.0:
			draw_arc(center, radius, -PI * 0.5, end_angle, 128, accent_color.lightened(0.28), 8.0)
			draw_arc(center, radius + 7.0, -PI * 0.5, end_angle, 128, Color(accent_color.r, accent_color.g, accent_color.b, 0.28), 2.0)

		for index in range(8):
			var angle := TAU * float(index) / 8.0
			var inner := center + Vector2(cos(angle), sin(angle)) * (radius - 5.0)
			var outer := center + Vector2(cos(angle), sin(angle)) * (radius + 15.0)
			draw_line(inner, outer, Color(accent_color.r, accent_color.g, accent_color.b, 0.34), 1.0)

	func _make_circle_mask_material() -> ShaderMaterial:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float mask = 1.0 - smoothstep(0.47, 0.5, length(p));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= mask;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		return material


class CooldownPieOverlay:
	extends Control

	var cooldown_ratio := 0.0
	var is_locked := false

	func set_overlay_state(new_ratio: float, locked: bool) -> void:
		cooldown_ratio = clampf(new_ratio, 0.0, 1.0)
		is_locked = locked
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		if is_locked:
			draw_circle(center, radius * 1.08, Color(0.0, 0.0, 0.0, 0.62))
			draw_line(center + Vector2(-radius * 0.38, 0.0), center + Vector2(radius * 0.38, 0.0), Color(0.7, 0.7, 0.74, 0.72), 3.0)
			return
		if cooldown_ratio <= 0.0:
			return

		var points := PackedVector2Array([center])
		var segments := maxi(8, int(ceil(72.0 * cooldown_ratio)))
		var start_angle := -PI * 0.5
		var end_angle := start_angle + TAU * cooldown_ratio
		for index in range(segments + 1):
			var t := float(index) / float(segments)
			var angle := lerpf(start_angle, end_angle, t)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.52))


class SkillCooldownSlot:
	extends Control

	var icon_rect: TextureRect
	var overlay: CooldownPieOverlay
	var label: Label
	var count_label: Label
	var icon_texture: Texture2D
	var cooldown_ratio := 0.0
	var is_ready := true
	var is_active := false
	var is_locked := false
	var accent_color := Color(0.9, 0.12, 0.12)
	var slot_label := ""
	var pulse_time := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect = TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
		icon_rect.material = _make_circle_mask_material()
		add_child(icon_rect)

		overlay = CooldownPieOverlay.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)

		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.78))
		add_child(label)

		count_label = Label.new()
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.add_theme_font_size_override("font_size", 18)
		count_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
		add_child(count_label)
		_sync_content()
		_sync_layout()
		set_process(true)

	func _process(delta: float) -> void:
		if is_ready or is_active:
			pulse_time += delta
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_sync_layout()

	func configure(new_label: String, new_texture: Texture2D, new_accent_color: Color) -> void:
		slot_label = new_label
		icon_texture = new_texture
		accent_color = new_accent_color
		_sync_content()
		_sync_layout()
		queue_redraw()

	func _sync_content() -> void:
		if icon_rect != null:
			icon_rect.texture = icon_texture
		if label != null:
			label.text = slot_label

	func set_slot_state(remaining: float, total: float, ready: bool, active: bool, locked: bool, charges := -1, max_charges := -1) -> void:
		var safe_total := maxf(total, 0.01)
		cooldown_ratio = clampf(remaining / safe_total, 0.0, 1.0)
		is_ready = ready
		is_active = active
		is_locked = locked
		if count_label != null:
			if max_charges > 1:
				count_label.text = "%d" % maxi(0, charges)
			else:
				count_label.text = ""
		if overlay != null:
			overlay.set_overlay_state(cooldown_ratio, is_locked)
		if not is_ready and not is_active:
			pulse_time = 0.0
		queue_redraw()

	func _sync_layout() -> void:
		if icon_rect == null or label == null:
			return
		var icon_size := minf(size.x, size.y - 18.0)
		icon_rect.position = Vector2((size.x - icon_size) * 0.5, 0.0)
		icon_rect.size = Vector2(icon_size, icon_size)
		overlay.position = icon_rect.position
		overlay.size = icon_rect.size
		label.position = Vector2(0.0, icon_size - 4.0)
		label.size = Vector2(size.x, 24.0)
		if count_label != null:
			count_label.position = icon_rect.position + Vector2(icon_size * 0.52, icon_size * 0.52)
			count_label.size = Vector2(icon_size * 0.34, icon_size * 0.3)

	func _draw() -> void:
		var icon_size := minf(size.x, size.y - 18.0)
		var center := Vector2(size.x * 0.5, icon_size * 0.5)
		var radius := icon_size * 0.47
		var pulse := (sin(pulse_time * TAU * 1.6) + 1.0) * 0.5
		var alpha := 0.32 if is_ready else 0.14
		if is_active:
			alpha = 0.44
		if is_locked:
			alpha = 0.08

		draw_circle(center, radius + 8.0, Color(accent_color.r, accent_color.g, accent_color.b, alpha + pulse * 0.08))
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.22))
		draw_arc(center, radius, 0.0, TAU, 96, Color(0.08, 0.08, 0.09, 0.92), 5.0)
		draw_arc(center, radius - 6.0, 0.0, TAU, 96, Color(0.78, 0.62, 0.38, 0.32), 1.0)
		draw_arc(center, radius, 0.0, TAU, 96, Color(accent_color.r, accent_color.g, accent_color.b, 0.62 if is_ready or is_active else 0.34), 2.0)

	func _make_circle_mask_material() -> ShaderMaterial:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float mask = 1.0 - smoothstep(0.47, 0.5, length(p));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= mask;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		return material


class GothicUpgradeCard:
	extends Button

	var rarity_label: Label
	var name_label: Label
	var description_label: Label
	var icon_rect: TextureRect
	var sigil: SkillSigil
	var gems: GemStrip
	var rarity := "Common"
	var skill_id := ""
	var accent_color := Color(0.8, 0.8, 0.82)
	var icon_texture: Texture2D

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		_add_empty_button_styles()
		_build_children()
		_sync_layout()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_sync_layout()

	func set_option_data(option: Dictionary, index: int, theme_color: Color, character_accent: Color) -> void:
		rarity = str(option.get("rarity", "Common"))
		skill_id = str(option.get("skill_id", ""))
		accent_color = _rarity_color(rarity, theme_color, character_accent)
		var label_text := str(option.get("label", "Upgrade"))
		var description := str(option.get("description", ""))
		var pair := Vector2i(int(option.get("level_current", 0)), int(option.get("level_max", 10)))
		var icon_path := str(option.get("icon_path", ""))
		icon_texture = null
		if not icon_path.is_empty():
			icon_texture = load(icon_path) as Texture2D

		if rarity_label != null:
			rarity_label.text = _rarity_display_name(rarity)
			rarity_label.add_theme_color_override("font_color", accent_color.lightened(0.22))
		if name_label != null:
			name_label.text = label_text
		if description_label != null:
			description_label.text = description
		if icon_rect != null:
			icon_rect.texture = icon_texture
			icon_rect.visible = icon_texture != null
		if sigil != null:
			sigil.set_sigil_data(skill_id, accent_color)
			sigil.visible = icon_texture == null
		if gems != null:
			gems.set_gems(pair.x, pair.y, accent_color)
		queue_redraw()

	func _build_children() -> void:
		rarity_label = Label.new()
		rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_label.add_theme_font_size_override("font_size", 16)
		add_child(rarity_label)

		name_label = Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86))
		add_child(name_label)

		icon_rect = TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.material = _make_circle_mask_material()
		add_child(icon_rect)

		sigil = SkillSigil.new()
		sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sigil)

		gems = GemStrip.new()
		gems.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gems)

		description_label = Label.new()
		description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		description_label.add_theme_font_size_override("font_size", 18)
		description_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.78))
		add_child(description_label)

	func _sync_layout() -> void:
		if rarity_label == null:
			return
		rarity_label.position = Vector2(18.0, 24.0)
		rarity_label.size = Vector2(size.x - 36.0, 24.0)
		name_label.position = Vector2(18.0, 52.0)
		name_label.size = Vector2(size.x - 36.0, 58.0)
		icon_rect.position = Vector2(size.x * 0.5 - 76.0, 118.0)
		icon_rect.size = Vector2(152.0, 152.0)
		sigil.position = icon_rect.position
		sigil.size = icon_rect.size
		gems.position = Vector2(36.0, 258.0)
		gems.size = Vector2(size.x - 72.0, 30.0)
		description_label.position = Vector2(26.0, 316.0)
		description_label.size = Vector2(size.x - 52.0, maxf(72.0, size.y - 342.0))

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size).grow(-3.0)
		var hover_alpha := 0.12 if is_hovered() else 0.0
		var press_alpha := 0.12 if button_pressed else 0.0
		draw_rect(rect, Color(0.02, 0.024, 0.032, 0.94), true)
		draw_rect(rect.grow(-6.0), Color(accent_color.r, accent_color.g, accent_color.b, 0.1 + hover_alpha), true)
		draw_rect(rect, Color(accent_color.r, accent_color.g, accent_color.b, 0.82 + press_alpha), false, 2.0)
		draw_rect(rect.grow(-8.0), Color(1.0, 0.95, 0.82, 0.14), false, 1.0)
		var icon_center := Vector2(size.x * 0.5, 194.0)
		draw_circle(icon_center, 85.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.14 + hover_alpha))
		draw_circle(icon_center, 78.0, Color(0.0, 0.0, 0.0, 0.28))
		draw_arc(icon_center, 80.0, 0.0, TAU, 96, Color(accent_color.r, accent_color.g, accent_color.b, 0.72), 3.0)
		draw_line(Vector2(36.0, 296.0), Vector2(size.x - 36.0, 296.0), Color(accent_color.r, accent_color.g, accent_color.b, 0.26), 1.0)

	func _draw_corner_ornaments(rect: Rect2, color: Color) -> void:
		var length := 34.0
		var width := 2.0
		_draw_corner(rect.position, Vector2.RIGHT, Vector2.DOWN, length, color, width)
		_draw_corner(Vector2(rect.end.x, rect.position.y), Vector2.LEFT, Vector2.DOWN, length, color, width)
		_draw_corner(Vector2(rect.position.x, rect.end.y), Vector2.RIGHT, Vector2.UP, length, color, width)
		_draw_corner(rect.end, Vector2.LEFT, Vector2.UP, length, color, width)

	func _draw_corner(origin: Vector2, horizontal: Vector2, vertical: Vector2, length: float, color: Color, width: float) -> void:
		draw_line(origin, origin + horizontal * length, color, width)
		draw_line(origin, origin + vertical * length, color, width)

	func _draw_title_ornament(rect: Rect2) -> void:
		var y := rect.position.y + 108.0
		var center_x := rect.get_center().x
		draw_line(Vector2(rect.position.x + 26.0, y), Vector2(center_x - 82.0, y), Color(0.9, 0.72, 0.44, 0.22), 1.0)
		draw_line(Vector2(center_x + 82.0, y), Vector2(rect.end.x - 26.0, y), Color(0.9, 0.72, 0.44, 0.22), 1.0)

	func _extract_level_pair(label_text: String) -> Vector2i:
		for raw_part in label_text.split(" "):
			var part := raw_part.strip_edges()
			if part.find("/") == -1:
				continue
			var pieces := part.split("/")
			if pieces.size() != 2:
				continue
			if pieces[0].is_valid_int() and pieces[1].is_valid_int():
				return Vector2i(int(pieces[0]), int(pieces[1]))
		return Vector2i(0, 10)

	func _rarity_color(option_rarity: String, theme_color: Color, character_accent: Color) -> Color:
		match option_rarity:
			"Rare":
				return Color(0.22, 0.58, 1.0)
			"Epic":
				return Color(0.78, 0.26, 1.0).lerp(character_accent, 0.28)
			"Legendary":
				return Color(1.0, 0.72, 0.18)
			_:
				return Color(0.78, 0.78, 0.82).lerp(theme_color, 0.12)

	func _rarity_display_name(option_rarity: String) -> String:
		match option_rarity:
			"Rare":
				return "레어"
			"Epic":
				return "에픽"
			"Legendary":
				return "레전더리"
			_:
				return "노말"

	func _make_circle_mask_material() -> ShaderMaterial:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float mask = 1.0 - smoothstep(0.48, 0.5, length(p));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= mask;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		return material

	func _add_empty_button_styles() -> void:
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty)
		add_theme_stylebox_override("hover", empty)
		add_theme_stylebox_override("pressed", empty)
		add_theme_stylebox_override("focus", empty)


class GothicOverlayFrame:
	extends Control

	var theme_color := Color(0.8, 0.12, 0.12)
	var accent_color := Color(0.9, 0.72, 0.44)

	func configure(new_theme_color: Color, new_accent_color: Color) -> void:
		theme_color = new_theme_color
		accent_color = new_accent_color
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.58), true)
		draw_rect(rect, Color(theme_color.r, theme_color.g, theme_color.b, 0.08), true)

		var center_x := size.x * 0.5
		var title_y := size.y * 0.18
		var color := Color(accent_color.r, accent_color.g, accent_color.b, 0.42)
		draw_line(Vector2(center_x - 360.0, title_y), Vector2(center_x - 120.0, title_y), color, 1.0)
		draw_line(Vector2(center_x + 120.0, title_y), Vector2(center_x + 360.0, title_y), color, 1.0)
		draw_line(Vector2(center_x - 24.0, title_y + 24.0), Vector2(center_x, title_y + 42.0), color, 1.0)
		draw_line(Vector2(center_x, title_y + 42.0), Vector2(center_x + 24.0, title_y + 24.0), color, 1.0)

		var inset := 22.0
		var frame_rect := rect.grow(-inset)
		draw_rect(frame_rect, Color(accent_color.r, accent_color.g, accent_color.b, 0.18), false, 1.0)
		draw_rect(frame_rect.grow(-8.0), Color(accent_color.r, accent_color.g, accent_color.b, 0.08), false, 1.0)
