extends Control

const Catalog := preload("res://scripts/character_catalog.gd")

const CARD_SIZE := Vector2(162.0, 690.0)
const CARD_GAP := 15
const LEFT_PANEL_WIDTH := 870.0
const DETAIL_PANEL_WIDTH := 900.0
const DETAIL_INFO_TOP := 64.0
const DETAIL_INFO_BOTTOM := 112.0

var characters: Array = []
var selected_index := 0
var card_buttons: Array[Button] = []
var card_name_labels: Array[Label] = []
var card_symbol_controls: Array = []
var card_frame_overlays: Array = []
var background_image
var fade_layer
var card_scroll: ScrollContainer
var detail_panel: Control
var detail_frame
var detail_info_panel: PanelContainer
var detail_name_label: Label
var detail_subtitle_label: Label
var detail_concept_label: Label
var skill_list: VBoxContainer
var select_button: Button


class FocusedTexture:
	extends Control

	var texture: Texture2D
	var display_mode := "cover"
	var focus := Vector2(0.5, 0.5)
	var tint := Color.WHITE
	var overlay_color := Color.TRANSPARENT


	func set_texture_data(new_texture: Texture2D, new_display_mode: String, new_focus: Vector2, new_tint := Color.WHITE, new_overlay_color := Color.TRANSPARENT) -> void:
		texture = new_texture
		display_mode = new_display_mode
		focus = new_focus
		tint = new_tint
		overlay_color = new_overlay_color
		queue_redraw()


	func _draw() -> void:
		if texture == null or size.x <= 0.0 or size.y <= 0.0:
			return

		var texture_size := texture.get_size()
		if texture_size.x <= 0.0 or texture_size.y <= 0.0:
			return

		if display_mode == "contain":
			_draw_contained(texture_size)
		else:
			_draw_covered(texture_size)

		if overlay_color.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), overlay_color, true)


	func _draw_contained(texture_size: Vector2) -> void:
		var scale := minf(size.x / texture_size.x, size.y / texture_size.y)
		var draw_size := texture_size * scale
		var spare := size - draw_size
		var draw_position := Vector2(
			spare.x * clampf(focus.x, 0.0, 1.0),
			spare.y * clampf(focus.y, 0.0, 1.0)
		)
		draw_texture_rect(texture, Rect2(draw_position, draw_size), false, tint)


	func _draw_covered(texture_size: Vector2) -> void:
		var scale := maxf(size.x / texture_size.x, size.y / texture_size.y)
		var source_size := size / scale
		source_size.x = minf(source_size.x, texture_size.x)
		source_size.y = minf(source_size.y, texture_size.y)

		var source_position := Vector2(
			texture_size.x * clampf(focus.x, 0.0, 1.0) - source_size.x * 0.5,
			texture_size.y * clampf(focus.y, 0.0, 1.0) - source_size.y * 0.5
		)
		source_position.x = clampf(source_position.x, 0.0, maxf(0.0, texture_size.x - source_size.x))
		source_position.y = clampf(source_position.y, 0.0, maxf(0.0, texture_size.y - source_size.y))

		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), Rect2(source_position, source_size), tint)


class ShowcaseFade:
	extends Control

	var theme_color := Color(0.48, 0.68, 1.0)
	var accent_color := Color(1.0, 0.78, 0.34)
	var info_rect := Rect2()
	var info_side := "left"


	func set_fade_data(new_theme_color: Color, new_accent_color: Color, new_info_rect: Rect2, new_info_side: String) -> void:
		theme_color = new_theme_color
		accent_color = new_accent_color
		info_rect = new_info_rect
		info_side = new_info_side
		queue_redraw()


	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return

		var full_rect := Rect2(Vector2.ZERO, size)
		draw_rect(full_rect, Color(0.0, 0.0, 0.0, 0.12), true)
		_draw_horizontal_gradient(Rect2(0.0, 0.0, size.x * 0.56, size.y), Color.BLACK, 0.66, 0.18, 44)
		_draw_vertical_gradient(Rect2(0.0, 0.0, size.x, size.y * 0.22), Color.BLACK, 0.56, 0.0, 24)
		_draw_vertical_gradient(Rect2(0.0, size.y * 0.76, size.x, size.y * 0.24), Color.BLACK, 0.0, 0.58, 24)

		if info_rect.size.x > 0.0 and info_rect.size.y > 0.0:
			var safe_rect := info_rect.grow_individual(84.0, 52.0, 132.0, 58.0)
			if info_side == "right":
				_draw_horizontal_gradient(safe_rect, Color.BLACK, 0.08, 0.76, 44)
			else:
				_draw_horizontal_gradient(safe_rect, Color.BLACK, 0.76, 0.08, 44)
			draw_rect(info_rect.grow(18.0), Color(0.0, 0.0, 0.0, 0.16), true)
			_draw_info_frame(info_rect, accent_color)

		draw_rect(full_rect.grow(-6.0), Color(0.82, 0.62, 0.34, 0.5), false, 1.0)
		draw_rect(full_rect.grow(-14.0), Color(0.82, 0.62, 0.34, 0.2), false, 1.0)
		_draw_title_ornaments()
		_draw_hint_ornaments()
		_draw_corner_ornaments()


	func _draw_horizontal_gradient(rect: Rect2, color: Color, left_alpha: float, right_alpha: float, steps: int) -> void:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return

		var strip_width := rect.size.x / float(steps)
		for index in range(steps):
			var t := float(index) / float(maxi(steps - 1, 1))
			var alpha := lerpf(left_alpha, right_alpha, t)
			var strip_rect := Rect2(
				Vector2(rect.position.x + strip_width * float(index), rect.position.y),
				Vector2(ceilf(strip_width) + 1.0, rect.size.y)
			)
			draw_rect(strip_rect, Color(color.r, color.g, color.b, alpha), true)


	func _draw_vertical_gradient(rect: Rect2, color: Color, top_alpha: float, bottom_alpha: float, steps: int) -> void:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return

		var strip_height := rect.size.y / float(steps)
		for index in range(steps):
			var t := float(index) / float(maxi(steps - 1, 1))
			var alpha := lerpf(top_alpha, bottom_alpha, t)
			var strip_rect := Rect2(
				Vector2(rect.position.x, rect.position.y + strip_height * float(index)),
				Vector2(rect.size.x, ceilf(strip_height) + 1.0)
			)
			draw_rect(strip_rect, Color(color.r, color.g, color.b, alpha), true)


	func _draw_info_frame(rect: Rect2, color: Color) -> void:
		var frame_rect := rect.grow(4.0)
		draw_rect(frame_rect, Color(color.r, color.g, color.b, 0.36), false, 1.0)
		draw_rect(frame_rect.grow(-7.0), Color(0.84, 0.66, 0.38, 0.18), false, 1.0)

		var corner := 34.0
		var width := 2.0
		var corner_color := Color(color.r, color.g, color.b, 0.72)
		_draw_corner(frame_rect.position, Vector2.RIGHT, Vector2.DOWN, corner, corner_color, width)
		_draw_corner(Vector2(frame_rect.end.x, frame_rect.position.y), Vector2.LEFT, Vector2.DOWN, corner, corner_color, width)
		_draw_corner(Vector2(frame_rect.position.x, frame_rect.end.y), Vector2.RIGHT, Vector2.UP, corner, corner_color, width)
		_draw_corner(frame_rect.end, Vector2.LEFT, Vector2.UP, corner, corner_color, width)


	func _draw_title_ornaments() -> void:
		var y := 102.0
		var half_gap := 150.0
		var line_len := 210.0
		var center_x := size.x * 0.5
		var color := Color(0.84, 0.66, 0.38, 0.42)
		draw_line(Vector2(center_x - half_gap - line_len, y), Vector2(center_x - half_gap, y), color, 1.0)
		draw_line(Vector2(center_x + half_gap, y), Vector2(center_x + half_gap + line_len, y), color, 1.0)
		draw_circle(Vector2(center_x - half_gap - 18.0, y), 3.0, Color(0.84, 0.66, 0.38, 0.42))
		draw_circle(Vector2(center_x + half_gap + 18.0, y), 3.0, Color(0.84, 0.66, 0.38, 0.42))
		draw_line(Vector2(center_x - 26.0, y + 18.0), Vector2(center_x, y + 34.0), color, 1.0)
		draw_line(Vector2(center_x, y + 34.0), Vector2(center_x + 26.0, y + 18.0), color, 1.0)


	func _draw_hint_ornaments() -> void:
		var y := size.y - 56.0
		var center_x := size.x * 0.25
		var color := Color(0.84, 0.66, 0.38, 0.34)
		draw_line(Vector2(center_x - 250.0, y), Vector2(center_x - 118.0, y), color, 1.0)
		draw_line(Vector2(center_x + 118.0, y), Vector2(center_x + 250.0, y), color, 1.0)
		draw_circle(Vector2(center_x - 104.0, y), 3.0, color)
		draw_circle(Vector2(center_x + 104.0, y), 3.0, color)


	func _draw_corner_ornaments() -> void:
		var inset := 26.0
		var length := 58.0
		var color := Color(0.84, 0.66, 0.38, 0.38)
		_draw_corner(Vector2(inset, inset), Vector2.RIGHT, Vector2.DOWN, length, color, 1.0)
		_draw_corner(Vector2(size.x - inset, inset), Vector2.LEFT, Vector2.DOWN, length, color, 1.0)
		_draw_corner(Vector2(inset, size.y - inset), Vector2.RIGHT, Vector2.UP, length, color, 1.0)
		_draw_corner(Vector2(size.x - inset, size.y - inset), Vector2.LEFT, Vector2.UP, length, color, 1.0)


	func _draw_corner(origin: Vector2, horizontal: Vector2, vertical: Vector2, length: float, color: Color, width: float) -> void:
		draw_line(origin, origin + horizontal * length, color, width)
		draw_line(origin, origin + vertical * length, color, width)


class ShowcasePanelFrame:
	extends Control

	var theme_color := Color(0.48, 0.68, 1.0)
	var accent_color := Color(1.0, 0.78, 0.34)


	func set_colors(new_theme_color: Color, new_accent_color: Color) -> void:
		theme_color = new_theme_color
		accent_color = new_accent_color
		queue_redraw()


	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return

		var rect := Rect2(Vector2(8.0, 10.0), size - Vector2(16.0, 20.0))
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.08), true)
		draw_rect(rect, Color(theme_color.r, theme_color.g, theme_color.b, 0.34), false, 1.0)
		draw_rect(rect.grow(-8.0), Color(0.84, 0.66, 0.38, 0.16), false, 1.0)

		var corner := 44.0
		var corner_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.42)
		_draw_corner(rect.position, Vector2.RIGHT, Vector2.DOWN, corner, corner_color)
		_draw_corner(Vector2(rect.end.x, rect.position.y), Vector2.LEFT, Vector2.DOWN, corner, corner_color)
		_draw_corner(Vector2(rect.position.x, rect.end.y), Vector2.RIGHT, Vector2.UP, corner, corner_color)
		_draw_corner(rect.end, Vector2.LEFT, Vector2.UP, corner, corner_color)


	func _draw_corner(origin: Vector2, horizontal: Vector2, vertical: Vector2, length: float, color: Color) -> void:
		draw_line(origin, origin + horizontal * length, color, 1.0)
		draw_line(origin, origin + vertical * length, color, 1.0)


class CardFrameOverlay:
	extends Control

	var accent_color := Color(1.0, 0.78, 0.34)
	var selected := false
	var locked := false


	func set_state(new_accent_color: Color, new_selected: bool, new_locked := false) -> void:
		accent_color = new_accent_color
		selected = new_selected
		locked = new_locked
		queue_redraw()


	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return

		var rect := Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
		var border_alpha := 0.9 if selected else 0.36
		var border_width := 2.0 if selected else 1.0

		if selected:
			draw_rect(rect.grow(5.0), Color(accent_color.r, accent_color.g, accent_color.b, 0.16), false, 3.0)
			draw_rect(rect.grow(9.0), Color(accent_color.r, accent_color.g, accent_color.b, 0.08), false, 3.0)

		draw_rect(rect, Color(accent_color.r, accent_color.g, accent_color.b, border_alpha), false, border_width)
		draw_rect(rect.grow(-7.0), Color(0.94, 0.78, 0.48, 0.18 if selected else 0.08), false, 1.0)

		var corner := 22.0
		var corner_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.92 if selected else 0.42)
		_draw_corner(rect.position, Vector2.RIGHT, Vector2.DOWN, corner, corner_color, border_width)
		_draw_corner(Vector2(rect.end.x, rect.position.y), Vector2.LEFT, Vector2.DOWN, corner, corner_color, border_width)
		_draw_corner(Vector2(rect.position.x, rect.end.y), Vector2.RIGHT, Vector2.UP, corner, corner_color, border_width)
		_draw_corner(rect.end, Vector2.LEFT, Vector2.UP, corner, corner_color, border_width)

		if locked:
			_draw_locked_sigil(rect)


	func _draw_locked_sigil(rect: Rect2) -> void:
		var center := rect.get_center()
		var color := Color(0.84, 0.76, 0.62, 0.14)
		draw_arc(center, 64.0, 0.0, TAU, 80, color, 1.0)
		draw_arc(center, 42.0, 0.0, TAU, 80, color, 1.0)
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			var from := center + Vector2(cos(angle), sin(angle)) * 50.0
			var to := center + Vector2(cos(angle), sin(angle)) * 68.0
			draw_line(from, to, color, 1.0)


	func _draw_corner(origin: Vector2, horizontal: Vector2, vertical: Vector2, length: float, color: Color, width: float) -> void:
		draw_line(origin, origin + horizontal * length, color, width)
		draw_line(origin, origin + vertical * length, color, width)


class CardSymbol:
	extends Control

	var shape := "star"
	var accent_color := Color(1.0, 0.78, 0.34)
	var selected := false


	func set_symbol_data(new_shape: String, new_accent_color: Color, new_selected: bool) -> void:
		shape = new_shape
		accent_color = new_accent_color
		selected = new_selected
		queue_redraw()


	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return

		var center := size * 0.5
		var glow_alpha := 0.18 if selected else 0.06
		draw_circle(center, 30.0, Color(accent_color.r, accent_color.g, accent_color.b, glow_alpha))
		draw_arc(center, 22.0, 0.0, TAU, 72, Color(accent_color.r, accent_color.g, accent_color.b, 0.48 if selected else 0.18), 1.0)
		_draw_shape(center, 14.0, Color(1.0, 0.88, 0.62, 1.0) if selected else Color(accent_color.r, accent_color.g, accent_color.b, 0.72), 2.0)


	func _draw_shape(center: Vector2, radius: float, color: Color, width: float) -> void:
		match shape:
			"slash":
				draw_line(center + Vector2(-radius, radius * 0.7), center + Vector2(radius, -radius * 0.7), color, width)
				draw_line(center + Vector2(-radius * 0.45, radius), center + Vector2(radius * 0.75, -radius * 0.2), color, width)
			"step":
				_draw_diamond(center, radius, color, width)
				draw_circle(center, 5.0, color)
			"protocol":
				draw_rect(Rect2(center - Vector2(radius * 0.65, radius * 0.65), Vector2(radius * 1.3, radius * 1.3)), color, false, width)
				draw_rect(Rect2(center - Vector2(radius * 0.32, radius * 0.32), Vector2(radius * 0.64, radius * 0.64)), color, false, 1.0)
			"barrier":
				draw_arc(center, radius, 0.0, TAU, 48, color, width)
				draw_arc(center, radius * 0.58, PI * 0.12, PI * 1.85, 40, color, width)
			"ray":
				for index in range(6):
					var angle := TAU * float(index) / 6.0
					draw_line(center + Vector2(cos(angle), sin(angle)) * 4.0, center + Vector2(cos(angle), sin(angle)) * radius, color, width)
			_:
				_draw_star(center, radius, color, width)


	func _draw_star(center: Vector2, radius: float, color: Color, width: float) -> void:
		draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), color, width)
		draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, width)
		draw_line(center + Vector2(-radius * 0.55, -radius * 0.55), center + Vector2(radius * 0.55, radius * 0.55), color, width * 0.65)
		draw_line(center + Vector2(radius * 0.55, -radius * 0.55), center + Vector2(-radius * 0.55, radius * 0.55), color, width * 0.65)


	func _draw_diamond(center: Vector2, radius: float, color: Color, width: float) -> void:
		var top := center + Vector2(0.0, -radius)
		var right := center + Vector2(radius, 0.0)
		var bottom := center + Vector2(0.0, radius)
		var left := center + Vector2(-radius, 0.0)
		draw_line(top, right, color, width)
		draw_line(right, bottom, color, width)
		draw_line(bottom, left, color, width)
		draw_line(left, top, color, width)


class SkillIcon:
	extends Control

	var shape := "star"
	var icon_color := Color(0.22, 0.62, 1.0)


	func set_icon_data(new_shape: String, new_color: Color) -> void:
		shape = new_shape
		icon_color = new_color
		queue_redraw()


	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return

		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.62))
		draw_circle(center, radius * 0.86, Color(icon_color.r, icon_color.g, icon_color.b, 0.08))
		draw_arc(center, radius, 0.0, TAU, 80, Color(icon_color.r, icon_color.g, icon_color.b, 0.95), 2.0)
		draw_arc(center, radius * 0.72, PI * 0.12, PI * 1.82, 60, Color(1.0, 0.92, 0.78, 0.36), 1.0)
		_draw_symbol(center, radius * 0.43, Color(1.0, 0.95, 0.86, 1.0), 2.2)


	func _draw_symbol(center: Vector2, radius: float, color: Color, width: float) -> void:
		match shape:
			"slash":
				draw_line(center + Vector2(-radius, radius * 0.65), center + Vector2(radius, -radius * 0.65), color, width)
				draw_line(center + Vector2(-radius * 0.35, radius), center + Vector2(radius * 0.78, -radius * 0.05), color, width * 0.85)
			"step":
				_draw_diamond(center, radius, color, width)
				draw_circle(center, radius * 0.36, color)
			"protocol":
				draw_rect(Rect2(center - Vector2(radius * 0.72, radius * 0.72), Vector2(radius * 1.44, radius * 1.44)), color, false, width)
				draw_rect(Rect2(center - Vector2(radius * 0.36, radius * 0.36), Vector2(radius * 0.72, radius * 0.72)), color, false, width * 0.7)
			"barrier":
				draw_arc(center, radius, 0.0, TAU, 60, color, width)
				draw_arc(center, radius * 0.62, PI * 0.08, PI * 1.92, 50, color, width)
			"ray":
				for index in range(8):
					var angle := TAU * float(index) / 8.0
					var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.22
					var outer := center + Vector2(cos(angle), sin(angle)) * radius
					draw_line(inner, outer, color, width)
			_:
				draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), color, width)
				draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, width)
				draw_line(center + Vector2(-radius * 0.55, -radius * 0.55), center + Vector2(radius * 0.55, radius * 0.55), color, width * 0.65)
				draw_line(center + Vector2(radius * 0.55, -radius * 0.55), center + Vector2(-radius * 0.55, radius * 0.55), color, width * 0.65)


	func _draw_diamond(center: Vector2, radius: float, color: Color, width: float) -> void:
		var top := center + Vector2(0.0, -radius)
		var right := center + Vector2(radius, 0.0)
		var bottom := center + Vector2(0.0, radius)
		var left := center + Vector2(-radius, 0.0)
		draw_line(top, right, color, width)
		draw_line(right, bottom, color, width)
		draw_line(bottom, left, color, width)
		draw_line(left, top, color, width)


func _ready() -> void:
	characters = Catalog.get_characters()
	selected_index = Catalog.find_character_index(GameState.selected_character_id)
	_build_ui()
	_update_selection()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.012, 0.018, 0.032), true)
	draw_rect(rect.grow(-6.0), Color(0.82, 0.62, 0.34, 0.55), false, 1.0)
	draw_rect(rect.grow(-12.0), Color(0.82, 0.62, 0.34, 0.22), false, 1.0)

	for index in range(95):
		var x := fposmod(float(index * 97), maxf(size.x, 1.0))
		var y := fposmod(float(index * 53), maxf(size.y, 1.0))
		var alpha := 0.06 + fposmod(float(index * 17), 40.0) / 500.0
		draw_circle(Vector2(x, y), 1.0 + float(index % 3) * 0.3, Color(0.78, 0.85, 1.0, alpha))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		if not characters.is_empty():
			var character: Dictionary = characters[selected_index]
			call_deferred("_sync_fade_layer", character["theme_color"], character["accent_color"], character.get("info_side", "left"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_move_selection(-1)
				_mark_input_as_handled()
			KEY_RIGHT, KEY_D:
				_move_selection(1)
				_mark_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_mark_input_as_handled()
				_start_selected_character()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_move_selection(-1)
				_mark_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_move_selection(1)
				_mark_input_as_handled()


func _mark_input_as_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	background_image = FocusedTexture.new()
	background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background_image)

	fade_layer = ShowcaseFade.new()
	fade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_layer)

	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 48)
	frame.add_theme_constant_override("margin_top", 34)
	frame.add_theme_constant_override("margin_right", 48)
	frame.add_theme_constant_override("margin_bottom", 40)
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	frame.add_child(root)

	var title := Label.new()
	title.text = "캐릭터 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.56))
	root.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)

	_build_card_area(body)
	_build_detail_area(body)


func _build_card_area(parent: Control) -> void:
	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(LEFT_PANEL_WIDTH, 0)
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 18)
	parent.add_child(left_column)

	card_scroll = ScrollContainer.new()
	card_scroll.custom_minimum_size = Vector2(LEFT_PANEL_WIDTH, CARD_SIZE.y + 28.0)
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(card_scroll)

	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", CARD_GAP)
	card_scroll.add_child(rail)

	var slot_count := Catalog.get_slot_count()
	for slot_index in range(slot_count):
		rail.add_child(_make_card(slot_index))

	var hint := Label.new()
	hint.text = "마우스 휠 / ← → / A D 로 이동"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.78, 0.68, 0.5))
	left_column.add_child(hint)


func _build_detail_area(parent: Control) -> void:
	detail_panel = Control.new()
	detail_panel.custom_minimum_size = Vector2(DETAIL_PANEL_WIDTH, 0)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(detail_panel)

	detail_frame = ShowcasePanelFrame.new()
	detail_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_panel.add_child(detail_frame)

	detail_info_panel = PanelContainer.new()
	detail_info_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.015, 0.022, 0.036, 0.1), Color(0.77, 0.58, 0.34, 0.08), 1, 2))
	detail_panel.add_child(detail_info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 28)
	info_margin.add_theme_constant_override("margin_top", 24)
	info_margin.add_theme_constant_override("margin_right", 28)
	info_margin.add_theme_constant_override("margin_bottom", 22)
	detail_info_panel.add_child(info_margin)

	var info_column := VBoxContainer.new()
	info_column.add_theme_constant_override("separation", 12)
	info_margin.add_child(info_column)

	detail_name_label = Label.new()
	detail_name_label.add_theme_font_size_override("font_size", 42)
	detail_name_label.add_theme_color_override("font_color", Color(0.94, 0.84, 0.68))
	info_column.add_child(detail_name_label)

	detail_subtitle_label = Label.new()
	detail_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_subtitle_label.add_theme_font_size_override("font_size", 20)
	detail_subtitle_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.9))
	info_column.add_child(detail_subtitle_label)

	info_column.add_child(_make_separator())

	var concept_title := Label.new()
	concept_title.text = "컨셉"
	concept_title.add_theme_font_size_override("font_size", 25)
	concept_title.add_theme_color_override("font_color", Color(0.92, 0.72, 0.46))
	info_column.add_child(concept_title)

	detail_concept_label = Label.new()
	detail_concept_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_concept_label.add_theme_font_size_override("font_size", 18)
	detail_concept_label.add_theme_color_override("font_color", Color(0.83, 0.82, 0.86))
	info_column.add_child(detail_concept_label)

	info_column.add_child(_make_separator())

	var skill_title := Label.new()
	skill_title.text = "스킬"
	skill_title.add_theme_font_size_override("font_size", 25)
	skill_title.add_theme_color_override("font_color", Color(0.92, 0.72, 0.46))
	info_column.add_child(skill_title)

	skill_list = VBoxContainer.new()
	skill_list.add_theme_constant_override("separation", 9)
	info_column.add_child(skill_list)

	select_button = Button.new()
	select_button.text = "선택하기"
	select_button.custom_minimum_size = Vector2(300, 64)
	select_button.add_theme_font_size_override("font_size", 28)
	select_button.pressed.connect(_start_selected_character)
	info_column.add_child(select_button)


func _make_card(slot_index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _make_card_style(Color(0.02, 0.03, 0.05, 0.86), Color(0.48, 0.36, 0.22, 0.72), 1))
	button.add_theme_stylebox_override("hover", _make_card_style(Color(0.04, 0.05, 0.08, 0.92), Color(0.72, 0.56, 0.34, 0.9), 2))
	button.add_theme_stylebox_override("pressed", _make_card_style(Color(0.04, 0.04, 0.07, 0.96), Color(0.88, 0.68, 0.42, 1.0), 2))

	if slot_index < characters.size():
		var character: Dictionary = characters[slot_index]
		button.pressed.connect(_on_card_pressed.bind(slot_index))

		var image := FocusedTexture.new()
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.set_anchors_preset(Control.PRESET_FULL_RECT)
		image.offset_left = 8
		image.offset_top = 8
		image.offset_right = -8
		image.offset_bottom = -112
		image.set_texture_data(
			_load_texture(character["card_image"]),
			character.get("card_mode", "cover"),
			character.get("card_focus", Vector2(0.5, 0.5)),
			Color.WHITE,
			Color(0.0, 0.0, 0.0, 0.08)
		)
		button.add_child(image)

		var bottom_shade := ColorRect.new()
		bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom_shade.color = Color(0.0, 0.0, 0.0, 0.48)
		bottom_shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bottom_shade.offset_top = -120
		bottom_shade.offset_bottom = 0
		button.add_child(bottom_shade)

		var card_symbol := CardSymbol.new()
		card_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_symbol.set_symbol_data(character["skills"][0].get("icon_shape", "star"), character["accent_color"], false)
		card_symbol.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		card_symbol.offset_top = -112
		card_symbol.offset_bottom = -58
		button.add_child(card_symbol)
		card_symbol_controls.append(card_symbol)

		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = character["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.offset_top = -58
		name_label.offset_bottom = -8
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.7))
		button.add_child(name_label)
		card_name_labels.append(name_label)

		var frame_overlay := CardFrameOverlay.new()
		frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_overlay.set_state(character["accent_color"], false)
		button.add_child(frame_overlay)
		card_frame_overlays.append(frame_overlay)
	else:
		button.disabled = true
		button.add_theme_stylebox_override("disabled", _make_card_style(Color(0.015, 0.022, 0.035, 0.68), Color(0.35, 0.28, 0.2, 0.45), 1))

		var locked_frame := CardFrameOverlay.new()
		locked_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		locked_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		locked_frame.set_state(Color(0.58, 0.46, 0.32, 0.68), false, true)
		button.add_child(locked_frame)

		var lock_label := Label.new()
		lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_label.text = "?"
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_label.add_theme_font_size_override("font_size", 72)
		lock_label.add_theme_color_override("font_color", Color(0.76, 0.7, 0.62, 0.55))
		button.add_child(lock_label)

	card_buttons.append(button)
	return button


func _on_card_pressed(index: int) -> void:
	if index >= characters.size():
		return
	selected_index = index
	_update_selection()


func _move_selection(direction: int) -> void:
	if characters.is_empty():
		return

	selected_index = posmod(selected_index + direction, characters.size())
	_update_selection()


func _update_selection() -> void:
	if characters.is_empty():
		return

	var character: Dictionary = characters[selected_index]
	var theme_color: Color = character["theme_color"]
	var accent_color: Color = character["accent_color"]

	for index in range(card_buttons.size()):
		if index >= characters.size():
			continue

		var button := card_buttons[index]
		var character_for_card: Dictionary = characters[index]
		if index == selected_index:
			button.add_theme_stylebox_override("normal", _make_card_style(Color(0.05, 0.045, 0.052, 0.95), accent_color, 3))
			button.add_theme_stylebox_override("hover", _make_card_style(Color(0.06, 0.05, 0.06, 0.98), accent_color.lightened(0.16), 3))
			card_name_labels[index].add_theme_color_override("font_color", Color(1.0, 0.92, 0.74))
			card_symbol_controls[index].set_symbol_data(character_for_card["skills"][0].get("icon_shape", "star"), accent_color, true)
			card_frame_overlays[index].set_state(accent_color, true)
		else:
			button.add_theme_stylebox_override("normal", _make_card_style(Color(0.02, 0.03, 0.05, 0.86), Color(0.48, 0.36, 0.22, 0.72), 1))
			button.add_theme_stylebox_override("hover", _make_card_style(Color(0.04, 0.05, 0.08, 0.92), Color(0.72, 0.56, 0.34, 0.9), 2))
			card_name_labels[index].add_theme_color_override("font_color", Color(0.9, 0.82, 0.68))
			card_symbol_controls[index].set_symbol_data(character_for_card["skills"][0].get("icon_shape", "star"), Color(0.72, 0.58, 0.42), false)
			card_frame_overlays[index].set_state(Color(0.48, 0.36, 0.22, 0.72), false)

	background_image.set_texture_data(
		_load_texture(character.get("select_background_image", character["detail_image"])),
		character.get("select_background_mode", "cover"),
		character.get("select_background_focus", Vector2(0.5, 0.5)),
		Color.WHITE,
		Color(0.0, 0.0, 0.0, 0.0)
	)
	detail_info_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.015, 0.022, 0.036, 0.24), theme_color.lightened(0.08), 1, 2))
	detail_frame.set_colors(theme_color, accent_color)

	var info_side: String = character.get("info_side", "left")
	_position_detail_info_panel(info_side, character.get("info_width", 520.0))
	call_deferred("_sync_fade_layer", theme_color, accent_color, info_side)

	detail_name_label.text = character["name"]
	detail_name_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.68))
	detail_subtitle_label.text = character["subtitle"]
	detail_concept_label.text = character["concept"]
	select_button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.06, 0.06, 0.07, 0.68), accent_color.darkened(0.28), 1, 2))
	select_button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.11, 0.1, 0.12, 0.78), accent_color, 1, 2))
	select_button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.04, 0.04, 0.05, 0.88), accent_color.lightened(0.12), 1, 2))

	_rebuild_skill_list(character["skills"])
	call_deferred("_scroll_selected_card_into_view_deferred")


func _position_detail_info_panel(side: String, panel_width: float) -> void:
	detail_info_panel.anchor_top = 0.0
	detail_info_panel.anchor_bottom = 1.0
	detail_info_panel.offset_top = DETAIL_INFO_TOP
	detail_info_panel.offset_bottom = -DETAIL_INFO_BOTTOM

	if side == "right":
		detail_info_panel.anchor_left = 1.0
		detail_info_panel.anchor_right = 1.0
		detail_info_panel.offset_left = -panel_width - 28.0
		detail_info_panel.offset_right = -28.0
	else:
		detail_info_panel.anchor_left = 0.0
		detail_info_panel.anchor_right = 0.0
		detail_info_panel.offset_left = 22.0
		detail_info_panel.offset_right = panel_width + 22.0


func _sync_fade_layer(theme_color: Color, accent_color: Color, info_side: String) -> void:
	if fade_layer == null or detail_info_panel == null:
		return

	var global_rect := detail_info_panel.get_global_rect()
	if global_rect.size.x <= 0.0 or global_rect.size.y <= 0.0:
		return

	var local_position: Vector2 = fade_layer.get_global_transform().affine_inverse() * global_rect.position
	fade_layer.set_fade_data(theme_color, accent_color, Rect2(local_position, global_rect.size), info_side)


func _rebuild_skill_list(skills: Array) -> void:
	for child in skill_list.get_children():
		child.queue_free()

	for skill in skills:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		skill_list.add_child(row)

		var icon_texture := _load_texture(skill.get("icon_path", ""))
		if icon_texture != null:
			var icon_image := FocusedTexture.new()
			icon_image.custom_minimum_size = Vector2(62, 62)
			icon_image.set_texture_data(icon_texture, "contain", Vector2(0.5, 0.5))
			row.add_child(icon_image)
		else:
			var skill_icon := SkillIcon.new()
			skill_icon.custom_minimum_size = Vector2(62, 62)
			skill_icon.set_icon_data(skill.get("icon_shape", "star"), skill["color"])
			row.add_child(skill_icon)

		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_column)

		var name_label := Label.new()
		name_label.text = skill["name"]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.98))
		text_column.add_child(name_label)

		var description_label := Label.new()
		description_label.text = skill["description"]
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.add_theme_font_size_override("font_size", 16)
		description_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
		text_column.add_child(description_label)


func _scroll_selected_card_into_view_deferred() -> void:
	if card_scroll == null or selected_index >= card_buttons.size():
		return

	var card := card_buttons[selected_index]
	var visible_left := float(card_scroll.scroll_horizontal)
	var visible_right := visible_left + card_scroll.size.x
	var card_left := card.position.x
	var card_right := card_left + card.size.x

	if card_left < visible_left:
		card_scroll.scroll_horizontal = int(maxf(0.0, card_left - 10.0))
	elif card_right > visible_right:
		card_scroll.scroll_horizontal = int(card_right - card_scroll.size.x + 10.0)


func _start_selected_character() -> void:
	if selected_index < 0 or selected_index >= characters.size():
		return

	GameState.set_selected_character(characters[selected_index]["id"])
	get_tree().change_scene_to_file(Catalog.GAME_SCENE_PATH)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if ResourceLoader.exists(path, "Texture2D"):
		var texture := load(path) as Texture2D
		if texture != null:
			return texture

	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.modulate = Color(0.74, 0.56, 0.34, 0.45)
	return separator


func _make_card_style(fill_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	return _make_panel_style(fill_color, border_color, border_width, 4)


func _make_panel_style(fill_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 7
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	return style
