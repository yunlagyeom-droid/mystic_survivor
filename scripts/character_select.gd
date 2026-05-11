extends Control

const Catalog := preload("res://scripts/character_catalog.gd")

const SELECT_MUSIC_PATH := "res://assets/audio/music/character_select_1.mp3"
const SELECTABLE_IDS := ["mage", "hunter"]
const LOCKED_SLOTS := [
	{"name": "???", "tag": "추가 예정", "shape": "star", "color": Color(0.72, 0.76, 0.86), "image": "res://assets/ui/character_select/roster/locked_roster_1.png"},
	{"name": "???", "tag": "추가 예정", "shape": "star", "color": Color(0.72, 0.76, 0.86), "image": "res://assets/ui/character_select/roster/locked_roster_2.png"},
	{"name": "???", "tag": "추가 예정", "shape": "star", "color": Color(0.72, 0.76, 0.86), "image": "res://assets/ui/character_select/roster/locked_roster_3.png"},
	{"name": "???", "tag": "추가 예정", "shape": "star", "color": Color(0.72, 0.76, 0.86), "image": "res://assets/ui/character_select/roster/locked_roster_4.png"},
	{"name": "???", "tag": "추가 예정", "shape": "star", "color": Color(0.72, 0.76, 0.86), "image": "res://assets/ui/character_select/roster/locked_roster_5.png"},
]

var characters: Array = []
var selected_index := 0
var active_background := 0

var background_layers: Array = []
var atmosphere_layer: AtmosphereLayer
var live_stage: Control
var live_animation_layers: Array = []
var active_live_animation := 0
var live_fallback: FocusedTexture
var live_caption: Label
var info_panel: PanelContainer
var title_label: Label
var tag_label: Label
var desc_label: Label
var skill_icons: Array = []
var stat_bars: Dictionary = {}
var stat_values: Dictionary = {}
var stat_display_values: Dictionary = {}
var stat_rows: Dictionary = {}
var roster_buttons: Array[Button] = []
var roster_frames: Array = []
var roster_badges: Array = []
var roster_portraits: Array = []
var roster_name_labels: Array[Label] = []
var roster_tag_labels: Array[Label] = []
var roster_hovered: Array = []
var select_button: Button
var music_player: AudioStreamPlayer
var music_button: Button
var music_enabled := true
var texture_cache: Dictionary = {}


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


class SheetAnimation:
	extends Control

	var texture: Texture2D
	var columns := 1
	var rows := 1
	var fps := 12.0
	var display_mode := "cover"
	var focus := Vector2(0.5, 0.5)
	var elapsed := 0.0
	var frame_index := 0

	func set_animation_data(new_texture: Texture2D, new_columns: int, new_rows: int, new_fps: float, new_display_mode: String, new_focus: Vector2) -> void:
		texture = new_texture
		columns = maxi(1, new_columns)
		rows = maxi(1, new_rows)
		fps = maxf(1.0, new_fps)
		display_mode = new_display_mode
		focus = new_focus
		elapsed = 0.0
		frame_index = 0
		visible = texture != null
		set_process(visible)
		queue_redraw()

	func clear_animation() -> void:
		texture = null
		visible = false
		set_process(false)
		queue_redraw()

	func _process(delta: float) -> void:
		if texture == null:
			return

		elapsed += delta
		frame_index = int(elapsed * fps) % maxi(1, columns * rows)
		queue_redraw()

	func _draw() -> void:
		if texture == null or size.x <= 0.0 or size.y <= 0.0:
			return

		var sheet_size := texture.get_size()
		var frame_size := Vector2(sheet_size.x / float(columns), sheet_size.y / float(rows))
		if frame_size.x <= 0.0 or frame_size.y <= 0.0:
			return

		var frame_column := frame_index % columns
		var frame_row := frame_index / columns
		var source_rect := Rect2(
			Vector2(frame_size.x * frame_column + 0.5, frame_size.y * frame_row + 0.5),
			frame_size - Vector2(1.0, 1.0)
		)
		var target_rect := _get_target_rect(frame_size)
		draw_texture_rect_region(texture, target_rect, source_rect)

	func _get_target_rect(frame_size: Vector2) -> Rect2:
		var scale := minf(size.x / frame_size.x, size.y / frame_size.y)
		if display_mode != "contain":
			scale = maxf(size.x / frame_size.x, size.y / frame_size.y)

		var draw_size := frame_size * scale
		var spare := size - draw_size
		return Rect2(
			Vector2(
				spare.x * clampf(focus.x, 0.0, 1.0),
				spare.y * clampf(focus.y, 0.0, 1.0)
			).round(),
			draw_size.round()
		)


class AtmosphereLayer:
	extends Control

	var theme_color := Color(0.48, 0.68, 1.0)
	var accent_color := Color(1.0, 0.78, 0.34)

	func set_colors(new_theme_color: Color, new_accent_color: Color) -> void:
		theme_color = new_theme_color
		accent_color = new_accent_color
		queue_redraw()

	func _draw() -> void:
		return

class OutlineFrame:
	extends Control

	var accent_color := Color(0.56, 0.46, 1.0)
	var selected := false
	var locked := false

	func set_state(new_accent_color: Color, new_selected: bool, new_locked := false) -> void:
		accent_color = new_accent_color
		selected = new_selected
		locked = new_locked
		queue_redraw()

	func _draw() -> void:
		return


class Emblem:
	extends Control

	var shape := "star"
	var icon_color := Color(0.48, 0.68, 1.0)
	var filled := false

	func set_icon_data(new_shape: String, new_color: Color, new_filled := false) -> void:
		shape = new_shape
		icon_color = new_color
		filled = new_filled
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return

		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		draw_circle(center, radius, Color(icon_color.r, icon_color.g, icon_color.b, 0.16 if filled else 0.09))
		draw_arc(center, radius, 0.0, TAU, 72, Color(icon_color.r, icon_color.g, icon_color.b, 0.9), 2.0)

	func _draw_symbol(center: Vector2, radius: float, color: Color, width: float) -> void:
		match shape:
			"slash", "guard":
				draw_line(center + Vector2(-radius, radius * 0.7), center + Vector2(radius, -radius * 0.7), color, width)
				draw_line(center + Vector2(-radius * 0.45, radius), center + Vector2(radius * 0.75, -radius * 0.15), color, width * 0.85)
			"step", "diamond":
				_draw_diamond(center, radius, color, width)
				draw_circle(center, radius * 0.26, color)
			"protocol", "shield":
				draw_rect(Rect2(center - Vector2(radius * 0.62, radius * 0.72), Vector2(radius * 1.24, radius * 1.44)), color, false, width)
				draw_line(center + Vector2(-radius * 0.62, -radius * 0.08), center + Vector2(0.0, radius * 0.72), color, width)
				draw_line(center + Vector2(radius * 0.62, -radius * 0.08), center + Vector2(0.0, radius * 0.72), color, width)
			"ray", "flame":
				for index in range(8):
					var angle := TAU * float(index) / 8.0
					draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.18, center + Vector2(cos(angle), sin(angle)) * radius, color, width)
			"bow":
				draw_arc(center + Vector2(-radius * 0.2, 0.0), radius, -PI * 0.5, PI * 0.5, 32, color, width)
				draw_line(center + Vector2(-radius * 0.2, -radius), center + Vector2(-radius * 0.2, radius), color, width)
				draw_line(center + Vector2(-radius * 0.2, 0.0), center + Vector2(radius, 0.0), color, width)
			_:
				draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), color, width)
				draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, width)
				draw_line(center + Vector2(-radius * 0.55, -radius * 0.55), center + Vector2(radius * 0.55, radius * 0.55), color, width * 0.65)
				draw_line(center + Vector2(radius * 0.55, -radius * 0.55), center + Vector2(-radius * 0.55, radius * 0.55), color, width * 0.65)

	func _draw_diamond(center: Vector2, radius: float, color: Color, width: float) -> void:
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
			center + Vector2(0.0, -radius),
		])
		draw_polyline(points, color, width)


func _ready() -> void:
	characters = _get_selectable_characters()
	selected_index = _find_visible_character_index(GameState.selected_character_id)
	_build_ui()
	_update_selection(false)
	call_deferred("_preload_select_assets")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not characters.is_empty():
		_update_live_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		_move_selection(-1)
		_mark_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		_move_selection(1)
		_mark_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_start_selected_character()
		_mark_input_as_handled()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	for index in range(2):
		var background := FocusedTexture.new()
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.modulate.a = 1.0 if index == 0 else 0.0
		add_child(background)
		background_layers.append(background)

	_build_live_stage()

	atmosphere_layer = AtmosphereLayer.new()
	atmosphere_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(atmosphere_layer)

	_build_title_layer()
	_build_music_control()
	_build_info_panel()
	_build_roster_panel()
	_build_bottom_bar()


func _build_title_layer() -> void:
	var title := Label.new()
	title.text = "캐릭터 선택"
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_left = 72
	title.offset_top = 34
	title.offset_right = 430
	title.offset_bottom = 96
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.48))
	add_child(title)

	var list_title := Label.new()
	list_title.text = "클래스 선택"
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_title.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	list_title.offset_left = -450
	list_title.offset_top = 54
	list_title.offset_right = -72
	list_title.offset_bottom = 94
	list_title.add_theme_font_size_override("font_size", 24)
	list_title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.65))
	add_child(list_title)


func _build_music_control() -> void:
	music_player = AudioStreamPlayer.new()
	var stream := load(SELECT_MUSIC_PATH) as AudioStreamMP3
	if stream != null:
		stream.loop = true
		music_player.stream = stream
		music_player.volume_db = -8.0
		add_child(music_player)
		music_player.play()

	music_button = Button.new()
	music_button.text = "♪"
	music_button.custom_minimum_size = Vector2(54, 54)
	music_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	music_button.offset_left = -82
	music_button.offset_top = 24
	music_button.offset_right = -28
	music_button.offset_bottom = 78
	music_button.focus_mode = Control.FOCUS_NONE
	music_button.add_theme_font_size_override("font_size", 28)
	music_button.pressed.connect(_toggle_music)
	add_child(music_button)
	_sync_music_button()


func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	info_panel.offset_left = 36
	info_panel.offset_top = 116
	info_panel.offset_right = 514
	info_panel.offset_bottom = -168
	add_child(info_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 34)
	info_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 17)
	margin.add_child(column)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	column.add_child(title_label)

	tag_label = Label.new()
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 20)
	column.add_child(tag_label)

	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 17)
	desc_label.add_theme_constant_override("line_spacing", 5)
	column.add_child(desc_label)

	column.add_child(_make_labeled_separator("스킬"))

	var skill_row := HBoxContainer.new()
	skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_row.add_theme_constant_override("separation", 20)
	column.add_child(skill_row)
	for index in range(4):
		var icon := Emblem.new()
		icon.custom_minimum_size = Vector2(68, 68)
		skill_row.add_child(icon)
		skill_icons.append(icon)

	column.add_child(_make_labeled_separator("주요 능력치"))

	_make_stat_row(column, "atk", "공격력")
	_make_stat_row(column, "mob", "기동력")
	_make_stat_row(column, "def", "방어력")


func _build_live_stage() -> void:
	live_stage = Control.new()
	live_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(live_stage)

	live_fallback = FocusedTexture.new()
	live_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	live_stage.add_child(live_fallback)

	for index in range(2):
		var animation := SheetAnimation.new()
		animation.mouse_filter = Control.MOUSE_FILTER_IGNORE
		animation.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		animation.set_anchors_preset(Control.PRESET_FULL_RECT)
		animation.modulate.a = 1.0 if index == 0 else 0.0
		live_stage.add_child(animation)
		live_animation_layers.append(animation)

	live_caption = Label.new()
	live_caption.text = "Live2D 미리보기"
	live_caption.visible = false
	live_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	live_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	live_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	live_caption.offset_left = 250
	live_caption.offset_top = -92
	live_caption.offset_right = -250
	live_caption.offset_bottom = -42
	live_caption.add_theme_font_size_override("font_size", 19)
	live_caption.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84))
	live_caption.add_theme_stylebox_override("normal", _make_panel_style(Color(0.18, 0.16, 0.24, 0.42), Color(1.0, 0.9, 0.66, 0.42), 1, 28))
	live_stage.add_child(live_caption)


func _build_roster_panel() -> void:
	var list := VBoxContainer.new()
	list.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	list.offset_left = -450
	list.offset_top = 112
	list.offset_right = -44
	list.offset_bottom = -146
	list.add_theme_constant_override("separation", 13)
	add_child(list)

	for index in range(characters.size()):
		list.add_child(_make_roster_card(index))

	for locked in LOCKED_SLOTS:
		list.add_child(_make_locked_card(locked))


func _build_bottom_bar() -> void:
	select_button = Button.new()
	select_button.text = "선택하기"
	select_button.custom_minimum_size = Vector2(360, 72)
	select_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	select_button.offset_left = 640
	select_button.offset_top = -108
	select_button.offset_right = -640
	select_button.offset_bottom = -36
	select_button.add_theme_font_size_override("font_size", 30)
	select_button.pressed.connect(_start_selected_character)
	select_button.mouse_entered.connect(_on_select_button_hovered.bind(true))
	select_button.mouse_exited.connect(_on_select_button_hovered.bind(false))
	add_child(select_button)

	var back := Button.new()
	back.text = "← 뒤로가기"
	back.disabled = true
	back.custom_minimum_size = Vector2(170, 54)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 48
	back.offset_top = -94
	back.offset_right = 218
	back.offset_bottom = -40
	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.18, 0.21, 0.30, 0.34), Color(1.0, 1.0, 1.0, 0.22), 1, 26))
	add_child(back)


func _make_roster_card(index: int) -> Button:
	var character: Dictionary = characters[index]
	var button := Button.new()
	button.custom_minimum_size = Vector2(406, 98)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.pressed.connect(_on_card_pressed.bind(index))
	button.mouse_entered.connect(_on_roster_card_hovered.bind(index, true))
	button.mouse_exited.connect(_on_roster_card_hovered.bind(index, false))
	roster_buttons.append(button)
	roster_hovered.append(false)

	var portrait := FocusedTexture.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	portrait.offset_left = -148
	portrait.offset_top = 8
	portrait.offset_right = -8
	portrait.offset_bottom = -8
	portrait.set_texture_data(
		_load_texture(character.get("select_roster_image", character["card_image"])),
		character.get("select_roster_mode", "contain"),
		character.get("select_roster_focus", Vector2(0.5, 0.5))
	)
	button.add_child(portrait)
	roster_portraits.append(portrait)

	var badge := FocusedTexture.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	badge.offset_left = 18
	badge.offset_top = 17
	badge.offset_right = 82
	badge.offset_bottom = -17
	badge.set_texture_data(
		_load_texture(character.get("select_roster_icon", "")),
		"contain",
		Vector2(0.5, 0.5)
	)
	button.add_child(badge)
	roster_badges.append(badge)

	var name := Label.new()
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.text = character["name"]
	name.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	name.offset_left = 96
	name.offset_top = 18
	name.offset_right = -142
	name.offset_bottom = -48
	name.add_theme_font_size_override("font_size", 25)
	button.add_child(name)
	roster_name_labels.append(name)

	var tag := Label.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.text = character.get("select_tag", character.get("subtitle", ""))
	tag.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	tag.offset_left = 98
	tag.offset_top = 52
	tag.offset_right = -142
	tag.offset_bottom = -16
	tag.add_theme_font_size_override("font_size", 16)
	button.add_child(tag)
	roster_tag_labels.append(tag)

	var frame := OutlineFrame.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.set_state(character["accent_color"], false)
	button.add_child(frame)
	roster_frames.append(frame)
	return button


func _make_locked_card(data: Dictionary) -> Button:
	var button := Button.new()
	button.disabled = true
	button.custom_minimum_size = Vector2(406, 98)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.add_theme_stylebox_override("disabled", _make_roster_card_style(Color(0.96, 0.97, 1.0, 0.42), Color(1.0, 1.0, 1.0, 0.3), 1, 36))

	var preview := FocusedTexture.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	preview.offset_left = -158
	preview.offset_top = 8
	preview.offset_right = -8
	preview.offset_bottom = -8
	preview.modulate.a = 0.8
	preview.set_texture_data(_load_texture(data.get("image", "")), "contain", Vector2(0.5, 0.5))
	button.add_child(preview)

	var badge := Emblem.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	badge.offset_left = 18
	badge.offset_top = 18
	badge.offset_right = 82
	badge.offset_bottom = -18
	badge.set_icon_data(data.get("shape", "star"), data.get("color", Color(0.72, 0.76, 0.86)), true)
	button.add_child(badge)

	var name := Label.new()
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.text = "???"
	name.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	name.offset_left = 98
	name.offset_top = 18
	name.offset_right = -42
	name.offset_bottom = -48
	name.add_theme_font_size_override("font_size", 24)
	name.add_theme_color_override("font_color", Color(0.25, 0.28, 0.42, 0.54))
	button.add_child(name)

	var tag := Label.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.text = "추가 예정"
	tag.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	tag.offset_left = 100
	tag.offset_top = 52
	tag.offset_right = -42
	tag.offset_bottom = -16
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color(0.35, 0.38, 0.5, 0.48))
	button.add_child(tag)

	var frame := OutlineFrame.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.set_state(data.get("color", Color(0.6, 0.6, 0.6)), false, true)
	button.add_child(frame)
	return button


func _make_labeled_separator(text: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	return row


func _make_stat_row(parent: VBoxContainer, id: String, label_text: String) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	parent.add_child(column)
	stat_rows[id] = column

	var label_row := HBoxContainer.new()
	column.add_child(label_row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 17)
	label_row.add_child(label)

	var value := Label.new()
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(44, 0)
	value.add_theme_font_size_override("font_size", 17)
	label_row.add_child(value)
	stat_values[id] = value

	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(0, 12)
	bg.clip_contents = true
	bg.add_theme_stylebox_override("panel", _make_bar_style(Color(0.88, 0.88, 0.94, 0.56), Color.TRANSPARENT, 0, 7))
	column.add_child(bg)

	var fill := ColorRect.new()
	fill.color = Color(0.48, 0.68, 1.0)
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = 0.0
	fill.offset_right = 0
	bg.add_child(fill)
	stat_bars[id] = fill


func _on_card_pressed(index: int) -> void:
	if index >= characters.size():
		return
	selected_index = index
	_update_selection()


func _on_roster_card_hovered(index: int, hovered: bool) -> void:
	if index < 0 or index >= roster_hovered.size():
		return
	roster_hovered[index] = hovered
	_update_roster(characters[selected_index])


func _on_select_button_hovered(hovered: bool) -> void:
	if select_button == null:
		return
	var target_scale := Vector2(1.045, 1.045) if hovered else Vector2.ONE
	select_button.pivot_offset = select_button.size * 0.5
	create_tween().tween_property(select_button, "scale", target_scale, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _toggle_music() -> void:
	music_enabled = not music_enabled
	if music_player != null:
		if music_enabled:
			if not music_player.playing:
				music_player.play()
		else:
			music_player.stop()
	_sync_music_button()


func _sync_music_button() -> void:
	if music_button == null:
		return
	music_button.text = "♪" if music_enabled else "♩"
	music_button.modulate.a = 1.0 if music_enabled else 0.52
	var fill := Color(1.0, 1.0, 1.0, 0.54 if music_enabled else 0.28)
	var border := Color(1.0, 0.9, 0.66, 0.5 if music_enabled else 0.22)
	music_button.add_theme_stylebox_override("normal", _make_glow_style(fill, border, Color(0.98, 0.82, 0.48), 0.18 if music_enabled else 0.0))
	music_button.add_theme_stylebox_override("hover", _make_glow_style(fill.lightened(0.08), Color(1.0, 0.95, 0.78, 0.72), Color(0.98, 0.82, 0.48), 0.32))
	music_button.add_theme_stylebox_override("pressed", _make_glow_style(fill.darkened(0.08), border, Color(0.98, 0.82, 0.48), 0.22))
	music_button.add_theme_color_override("font_color", Color(0.28, 0.22, 0.52) if music_enabled else Color(0.42, 0.44, 0.56))


func _move_selection(direction: int) -> void:
	if characters.is_empty():
		return
	selected_index = posmod(selected_index + direction, characters.size())
	_update_selection()


func _update_selection(animated := true) -> void:
	if characters.is_empty():
		return

	var character: Dictionary = characters[selected_index]
	var theme_color: Color = character["theme_color"]
	var accent_color: Color = character["accent_color"]
	atmosphere_layer.set_colors(theme_color, accent_color)
	_update_background(character, animated)
	_update_info_panel(character, animated)
	_update_live_preview(character, animated)
	_update_roster(character)


func _update_background(character: Dictionary, animated: bool) -> void:
	var next_index := 1 - active_background
	var next_layer: FocusedTexture = background_layers[next_index]
	var current_layer: FocusedTexture = background_layers[active_background]
	next_layer.set_texture_data(
		_load_texture(character.get("select_background_image", character.get("detail_image", ""))),
		character.get("select_background_mode", "cover"),
		character.get("select_background_focus", Vector2(0.5, 0.5)),
		Color.WHITE,
		Color(0.0, 0.0, 0.0, 0.0)
	)
	if animated:
		next_layer.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(next_layer, "modulate:a", 1.0, 0.86).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(current_layer, "modulate:a", 0.0, 0.86).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		next_layer.modulate.a = 1.0
		current_layer.modulate.a = 0.0
	active_background = next_index


func _update_info_panel(character: Dictionary, animated: bool) -> void:
	var theme_color: Color = character["theme_color"]
	var accent_color: Color = character["accent_color"]
	var light_theme: bool = character.get("select_light_theme", false)
	var panel_fill := Color(1.0, 1.0, 1.0, 0.66) if light_theme else Color(0.08, 0.035, 0.04, 0.78)
	var text_main := Color(0.12, 0.22, 0.54) if light_theme else accent_color.lightened(0.1)
	var text_body := Color(0.18, 0.22, 0.34) if light_theme else Color(0.86, 0.9, 0.96)

	if animated:
		info_panel.modulate.a = 0.88
		info_panel.position.y += 3.0
		var info_tween := create_tween().set_parallel(true)
		info_tween.tween_property(info_panel, "modulate:a", 1.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		info_tween.tween_property(info_panel, "position:y", info_panel.position.y - 3.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	info_panel.add_theme_stylebox_override("panel", _make_panel_style(panel_fill, Color(1.0, 1.0, 1.0, 0.72) if light_theme else Color(accent_color.r, accent_color.g, accent_color.b, 0.34), 1, 28))
	title_label.text = character.get("select_name", character["name"])
	title_label.add_theme_color_override("font_color", text_main)
	tag_label.text = character.get("select_tag", character.get("subtitle", ""))
	tag_label.add_theme_color_override("font_color", accent_color if light_theme else Color(1.0, 0.82, 0.62))
	desc_label.text = character.get("select_description", character.get("concept", ""))
	desc_label.add_theme_color_override("font_color", text_body)
	if animated:
		_pulse_info_text()

	var skills: Array = character.get("skills", [])
	for index in range(skill_icons.size()):
		var icon: Emblem = skill_icons[index]
		if index < skills.size():
			var skill: Dictionary = skills[index]
			icon.visible = true
			icon.set_icon_data(skill.get("icon_shape", "star"), skill.get("color", theme_color), true)
			if animated:
				_fade_control(icon, 0.08 + float(index) * 0.065, 0.0, 1.0, 0.56)
		else:
			icon.visible = false

	var stats: Dictionary = character.get("select_stats", {"atk": 70, "mob": 70, "def": 70})
	var stat_delay := 0.0
	for id in stat_bars.keys():
		var value := int(stats.get(id, 0))
		var fill: ColorRect = stat_bars[id]
		var label: Label = stat_values[id]
		label.add_theme_color_override("font_color", text_body)
		fill.color = theme_color
		var target_anchor := clampf(float(value) / 100.0, 0.0, 1.0)
		if animated:
			var bar_tween := create_tween()
			bar_tween.tween_interval(stat_delay)
			bar_tween.tween_property(fill, "anchor_right", target_anchor, 1.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			var current_value := float(stat_display_values.get(id, value))
			var value_tween := create_tween()
			value_tween.tween_interval(stat_delay)
			value_tween.tween_method(Callable(self, "_set_stat_display_value").bind(id), current_value, float(value), 1.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if stat_rows.has(id):
				_fade_control(stat_rows[id], stat_delay, 0.72, 1.0, 0.58)
			stat_delay += 0.11
		else:
			fill.anchor_right = target_anchor
			_set_stat_display_value(float(value), id)

	var normal_fill := Color(1.0, 1.0, 1.0, 0.76) if light_theme else Color(0.02, 0.02, 0.025, 0.78)
	var normal_text := accent_color.darkened(0.22) if light_theme else Color(0.96, 0.92, 0.9)
	select_button.add_theme_color_override("font_color", normal_text)
	select_button.add_theme_color_override("font_hover_color", Color.WHITE)
	select_button.add_theme_stylebox_override("normal", _make_glow_style(normal_fill, Color(1.0, 1.0, 1.0, 0.84), accent_color, 0.18))
	select_button.add_theme_stylebox_override("hover", _make_glow_style(accent_color, Color(1.0, 1.0, 1.0, 0.95), accent_color, 0.58))
	select_button.add_theme_stylebox_override("pressed", _make_glow_style(accent_color.darkened(0.18), Color(1.0, 0.92, 0.72, 0.9), accent_color, 0.42))


func _update_live_preview(character: Dictionary, animated: bool) -> void:
	live_fallback.set_texture_data(
		_load_texture(character.get("detail_image", character.get("card_image", ""))),
		character.get("detail_mode", "cover"),
		character.get("detail_focus", Vector2(0.5, 0.5)),
		Color.WHITE,
		character.get("detail_overlay_color", Color.TRANSPARENT)
	)

	var sheet_path: String = character.get("select_animation_sheet", "")
	var texture := _load_texture(sheet_path)
	if texture != null:
		live_fallback.modulate.a = 0.0
		var next_index := 1 - active_live_animation if animated else active_live_animation
		var current_layer: SheetAnimation = live_animation_layers[active_live_animation]
		var next_layer: SheetAnimation = live_animation_layers[next_index]
		next_layer.visible = true
		next_layer.modulate = Color(1.08, 1.08, 1.08, 0.0 if animated else 1.0)
		next_layer.set_animation_data(
			texture,
			int(character.get("select_animation_columns", 4)),
			int(character.get("select_animation_rows", 6)),
			float(character.get("select_animation_fps", 12.0)),
			character.get("select_animation_mode", "cover"),
			character.get("select_animation_focus", Vector2(0.5, 0.5))
		)
		if animated:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(next_layer, "modulate:a", 1.0, 0.86).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(current_layer, "modulate:a", 0.0, 0.86).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			current_layer.modulate.a = 1.0
		active_live_animation = next_index
	else:
		for layer in live_animation_layers:
			layer.clear_animation()
		live_fallback.modulate.a = 1.0

	live_caption.modulate = character["accent_color"].lightened(0.08)
	_update_live_layout()


func _update_live_layout() -> void:
	if live_stage == null:
		return
	live_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	live_stage.offset_left = 0
	live_stage.offset_top = 0
	live_stage.offset_right = 0
	live_stage.offset_bottom = 0


func _update_roster(character: Dictionary) -> void:
	for index in range(roster_buttons.size()):
		var button := roster_buttons[index]
		var frame: OutlineFrame = roster_frames[index]
		var badge: FocusedTexture = roster_badges[index]
		var name: Label = roster_name_labels[index]
		var tag: Label = roster_tag_labels[index]
		var card_character: Dictionary = characters[index]
		var selected := index == selected_index
		var hovered := bool(roster_hovered[index]) if index < roster_hovered.size() else false
		var accent: Color = card_character["accent_color"]
		var fill := Color(1.0, 1.0, 1.0, 0.9) if selected else Color(1.0, 1.0, 1.0, 0.58 if hovered else 0.42)
		if not card_character.get("select_light_theme", false):
			fill = Color(0.24, 0.07, 0.07, 0.86) if selected else Color(0.12, 0.07, 0.07, 0.7 if hovered else 0.52)

		button.add_theme_stylebox_override("normal", _make_roster_card_style(fill, Color(1.0, 1.0, 1.0, 0.28 if selected else 0.12), 1, 36))
		button.add_theme_stylebox_override("hover", _make_roster_hover_style(fill.lightened(0.06), Color(1.0, 1.0, 1.0, 0.24), accent, 0.18))
		frame.set_state(accent, selected)
		badge.set_texture_data(
			_load_texture(card_character.get("select_roster_icon", "")),
			"contain",
			Vector2(0.5, 0.5)
		)
		badge.modulate.a = 1.0 if selected or hovered else 0.86
		name.add_theme_color_override("font_color", accent.darkened(0.22) if card_character.get("select_light_theme", false) else Color(1.0, 0.86, 0.74))
		tag.add_theme_color_override("font_color", Color(0.2, 0.24, 0.38) if card_character.get("select_light_theme", false) else Color(0.86, 0.9, 0.96))
		button.pivot_offset = button.size * 0.5
		var target_scale := Vector2(1.018, 1.018) if hovered or selected else Vector2.ONE
		var target_x := -7.0 if selected else (-3.0 if hovered else 0.0)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(button, "scale", target_scale, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "position:x", target_x, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _start_selected_character() -> void:
	if selected_index < 0 or selected_index >= characters.size():
		return
	GameState.set_selected_character(characters[selected_index]["id"])
	get_tree().change_scene_to_file(Catalog.GAME_SCENE_PATH)


func _mark_input_as_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _get_selectable_characters() -> Array:
	var visible: Array = []
	for character in Catalog.get_characters():
		if SELECTABLE_IDS.has(character.get("id", "")):
			visible.append(_with_select_defaults(character))
	return visible


func _with_select_defaults(character: Dictionary) -> Dictionary:
	var copy := character.duplicate(true)
	match copy.get("id", ""):
		"mage":
			copy["select_name"] = "아크메이지"
			copy["select_tag"] = "불, 독"
			copy["select_description"] = "모든 것을 불태우는 불 마법과 적을 중독시키는 독 마법을 사용하는 마법사입니다. 강력한 광역 공격과 상태 이상으로 전장을 지배합니다."
			copy["select_stats"] = {"atk": 92, "mob": 40, "def": 60}
			copy["select_light_theme"] = true
			copy["theme_color"] = Color(0.36, 0.54, 0.9)
			copy["accent_color"] = Color(0.43, 0.34, 0.86)
			copy["select_animation_sheet"] = "res://assets/players/mage/select/mage_live_2d_sheet_hq.png"
			copy["select_animation_columns"] = 8
			copy["select_animation_rows"] = 12
			copy["select_animation_fps"] = 24.0
			copy["select_animation_mode"] = "cover"
			copy["select_animation_focus"] = Vector2(0.5, 0.5)
			copy["select_roster_image"] = "res://assets/ui/character_select/roster/mage_mini_select_roster.png"
			copy["select_roster_mode"] = "contain"
			copy["select_roster_icon"] = "res://assets/ui/character_select/roster/mage_icon_circle.png"
		"hunter":
			copy["select_name"] = "헌터"
			copy["select_tag"] = "암흑, 연계"
			copy["select_description"] = "빠른 검술로 적을 추적하는 근접형 헌터입니다. 적에게 표식을 남기고 연속 공격을 이어가며, 순식간에 치명적인 피해를 입힙니다."
			copy["select_stats"] = {"atk": 98, "mob": 82, "def": 40}
			copy["select_light_theme"] = false
			copy["theme_color"] = Color(0.94, 0.26, 0.24)
			copy["accent_color"] = Color(0.96, 0.38, 0.32)
			copy["select_animation_sheet"] = "res://assets/players/hunter/select/hunter_live_2d_sheet_hq.png"
			copy["select_animation_columns"] = 8
			copy["select_animation_rows"] = 12
			copy["select_animation_fps"] = 24.0
			copy["select_animation_mode"] = "cover"
			copy["select_animation_focus"] = Vector2(0.5, 0.5)
			copy["select_roster_image"] = "res://assets/ui/character_select/roster/hunter_mini_select_roster.png"
			copy["select_roster_mode"] = "contain"
			copy["select_roster_icon"] = "res://assets/ui/character_select/roster/hunter_icon_circle.png"
	return copy


func _find_visible_character_index(character_id: String) -> int:
	for index in range(characters.size()):
		if characters[index].get("id", "") == character_id:
			return index
	return 0


func _set_stat_display_value(value: float, id: String) -> void:
	stat_display_values[id] = value
	if stat_values.has(id):
		var label: Label = stat_values[id]
		label.text = str(roundi(value))


func _pulse_info_text() -> void:
	_fade_slide_control(title_label, 0.0, 0.0, 1.0, 2.0, 0.62)
	_fade_slide_control(tag_label, 0.08, 0.0, 1.0, 2.0, 0.62)
	desc_label.modulate.a = 0.0
	desc_label.position.y += 3.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(desc_label, "modulate:a", 1.0, 0.72).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(desc_label, "position:y", desc_label.position.y - 3.0, 0.72).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _fade_control(control: Control, delay: float, from_alpha: float, to_alpha: float, duration: float) -> void:
	control.modulate.a = from_alpha
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", to_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _fade_slide_control(control: Control, delay: float, from_alpha: float, to_alpha: float, y_offset: float, duration: float) -> void:
	control.modulate.a = from_alpha
	control.position.y += y_offset
	var tween := create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", to_alpha, duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position:y", control.position.y - y_offset, duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _preload_select_assets() -> void:
	for character in characters:
		_load_texture(character.get("select_animation_sheet", ""))
		_load_texture(character.get("select_background_image", character.get("detail_image", "")))
		_load_texture(character.get("detail_image", character.get("card_image", "")))
	_prewarm_inactive_live_layer()


func _prewarm_inactive_live_layer() -> void:
	if characters.size() < 2 or live_animation_layers.size() < 2:
		return
	var next_character: Dictionary = characters[posmod(selected_index + 1, characters.size())]
	var texture := _load_texture(next_character.get("select_animation_sheet", ""))
	if texture == null:
		return
	var layer_index := 1 - active_live_animation
	var layer: SheetAnimation = live_animation_layers[layer_index]
	layer.modulate = Color(1.08, 1.08, 1.08, 0.0)
	layer.set_animation_data(
		texture,
		int(next_character.get("select_animation_columns", 4)),
		int(next_character.get("select_animation_rows", 6)),
		float(next_character.get("select_animation_fps", 12.0)),
		next_character.get("select_animation_mode", "cover"),
		next_character.get("select_animation_focus", Vector2(0.5, 0.5))
	)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	if GameState.has_method("get_preloaded_texture"):
		var preloaded := GameState.get_preloaded_texture(path)
		if preloaded != null:
			texture_cache[path] = preloaded
			return preloaded
	if ResourceLoader.exists(path, "Texture2D"):
		var texture := load(path) as Texture2D
		if texture != null:
			texture_cache[path] = texture
			return texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture_cache[path] = texture
	return texture


func _make_panel_style(fill_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 14
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _make_bar_style(fill_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _make_glow_style(fill_color: Color, border_color: Color, glow_color: Color, glow_alpha: float) -> StyleBoxFlat:
	var style := _make_panel_style(fill_color, border_color, 1, 34)
	style.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
	style.shadow_size = 24
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	return style


func _make_roster_card_style(fill_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := _make_panel_style(fill_color, border_color, border_width, radius)
	style.shadow_color = Color.TRANSPARENT
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style


func _make_roster_hover_style(fill_color: Color, border_color: Color, glow_color: Color, glow_alpha: float) -> StyleBoxFlat:
	var style := _make_roster_card_style(fill_color, border_color, 1, 36)
	style.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
	style.shadow_size = 10
	style.shadow_offset = Vector2.ZERO
	return style
