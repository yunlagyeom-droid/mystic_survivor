extends Control

const Catalog := preload("res://scripts/character_catalog.gd")

const CARD_SIZE := Vector2(154.0, 700.0)
const CARD_GAP := 14
const LEFT_PANEL_WIDTH := 850.0
const DETAIL_PANEL_WIDTH := 920.0

var characters: Array = []
var selected_index := 0
var card_buttons: Array[Button] = []
var card_name_labels: Array[Label] = []
var card_symbol_labels: Array[Label] = []
var card_scroll: ScrollContainer
var detail_panel: PanelContainer
var detail_image
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_move_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_move_selection(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_start_selected_character()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_move_selection(-1)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_move_selection(1)
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

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
	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(DETAIL_PANEL_WIDTH, 0)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.clip_contents = true
	detail_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.045, 0.075, 0.82), Color(0.77, 0.58, 0.34, 0.52), 1, 2))
	parent.add_child(detail_panel)

	var detail_root := Control.new()
	detail_root.clip_contents = true
	detail_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_panel.add_child(detail_root)

	detail_image = FocusedTexture.new()
	detail_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_root.add_child(detail_image)

	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.0, 0.0, 0.0, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_root.add_child(shade)

	detail_info_panel = PanelContainer.new()
	detail_info_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.015, 0.022, 0.036, 0.88), Color(0.77, 0.58, 0.34, 0.26), 1, 2))
	detail_root.add_child(detail_info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 24)
	info_margin.add_theme_constant_override("margin_top", 22)
	info_margin.add_theme_constant_override("margin_right", 24)
	info_margin.add_theme_constant_override("margin_bottom", 20)
	detail_info_panel.add_child(info_margin)

	var info_column := VBoxContainer.new()
	info_column.add_theme_constant_override("separation", 11)
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
	select_button.custom_minimum_size = Vector2(300, 58)
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

		var symbol := Label.new()
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		symbol.text = character["skills"][0]["icon_label"]
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		symbol.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		symbol.offset_top = -112
		symbol.offset_bottom = -58
		symbol.add_theme_font_size_override("font_size", 42)
		button.add_child(symbol)
		card_symbol_labels.append(symbol)

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
	else:
		button.disabled = true
		button.add_theme_stylebox_override("disabled", _make_card_style(Color(0.015, 0.022, 0.035, 0.68), Color(0.35, 0.28, 0.2, 0.45), 1))

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
		if index == selected_index:
			button.add_theme_stylebox_override("normal", _make_card_style(Color(0.05, 0.045, 0.052, 0.95), accent_color, 3))
			button.add_theme_stylebox_override("hover", _make_card_style(Color(0.06, 0.05, 0.06, 0.98), accent_color.lightened(0.16), 3))
			card_name_labels[index].add_theme_color_override("font_color", Color(1.0, 0.92, 0.74))
			card_symbol_labels[index].add_theme_color_override("font_color", accent_color)
		else:
			button.add_theme_stylebox_override("normal", _make_card_style(Color(0.02, 0.03, 0.05, 0.86), Color(0.48, 0.36, 0.22, 0.72), 1))
			button.add_theme_stylebox_override("hover", _make_card_style(Color(0.04, 0.05, 0.08, 0.92), Color(0.72, 0.56, 0.34, 0.9), 2))
			card_name_labels[index].add_theme_color_override("font_color", Color(0.9, 0.82, 0.68))
			card_symbol_labels[index].add_theme_color_override("font_color", Color(0.72, 0.58, 0.42))

	detail_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.045, 0.075, 0.82), theme_color.darkened(0.12), 1, 2))
	detail_image.set_texture_data(
		_load_texture(character["detail_image"]),
		character.get("detail_mode", "contain"),
		character.get("detail_focus", Vector2(0.5, 0.5)),
		Color(1.0, 1.0, 1.0, 0.96),
		character.get("detail_overlay_color", Color(0.0, 0.0, 0.0, 0.05))
	)
	_position_detail_info_panel(character.get("detail_info_side", "left"))

	detail_name_label.text = character["name"]
	detail_name_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.68))
	detail_subtitle_label.text = character["subtitle"]
	detail_concept_label.text = character["concept"]

	_rebuild_skill_list(character["skills"])
	call_deferred("_scroll_selected_card_into_view_deferred")


func _position_detail_info_panel(side: String) -> void:
	var panel_width := 500.0
	detail_info_panel.anchor_top = 0.0
	detail_info_panel.anchor_bottom = 1.0
	detail_info_panel.offset_top = 28.0
	detail_info_panel.offset_bottom = -28.0

	if side == "right":
		detail_info_panel.anchor_left = 1.0
		detail_info_panel.anchor_right = 1.0
		detail_info_panel.offset_left = -panel_width - 28.0
		detail_info_panel.offset_right = -28.0
	else:
		detail_info_panel.anchor_left = 0.0
		detail_info_panel.anchor_right = 0.0
		detail_info_panel.offset_left = 28.0
		detail_info_panel.offset_right = panel_width + 28.0


func _rebuild_skill_list(skills: Array) -> void:
	for child in skill_list.get_children():
		child.queue_free()

	for skill in skills:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		skill_list.add_child(row)

		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(62, 62)
		icon_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.03, 0.05, 0.9), skill["color"], 2, 31))
		row.add_child(icon_panel)

		var icon_texture := _load_texture(skill.get("icon_path", ""))
		if icon_texture != null:
			var icon_image := FocusedTexture.new()
			icon_image.custom_minimum_size = Vector2(48, 48)
			icon_image.set_texture_data(icon_texture, "contain", Vector2(0.5, 0.5))
			icon_panel.add_child(icon_image)
		else:
			var icon_label := Label.new()
			icon_label.text = skill["icon_label"]
			icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_label.add_theme_font_size_override("font_size", 30)
			icon_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
			icon_panel.add_child(icon_label)

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
