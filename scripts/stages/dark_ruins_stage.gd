class_name DarkRuinsStage
extends Node

const FLOOR_TEXTURE := preload("res://assets/_asset_store/Pixel Crawler - Free Pack/Environment/Tilesets/Floors_Tiles.png")
const DUNGEON_TEXTURE := preload("res://assets/_asset_store/Pixel Crawler - Free Pack/Environment/Tilesets/Dungeon_Tiles.png")
const PROP_TEXTURE := preload("res://assets/_asset_store/Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png")
const CYBER_PANEL_WEST_PATH := "res://assets/stages/dark_ruins/cyber_street_panel_west_v1.png"
const CYBER_PANEL_EAST_PATH := "res://assets/stages/dark_ruins/cyber_street_panel_east_v1.png"
const CYBER_RUINS_2X2_NW_PATH := "res://assets/stages/dark_ruins/cyber_ruins_2x2_nw_v1.png"
const CYBER_RUINS_2X2_NE_PATH := "res://assets/stages/dark_ruins/cyber_ruins_2x2_ne_v1.png"
const CYBER_RUINS_2X2_SW_PATH := "res://assets/stages/dark_ruins/cyber_ruins_2x2_sw_v1.png"
const CYBER_RUINS_2X2_SE_PATH := "res://assets/stages/dark_ruins/cyber_ruins_2x2_se_v1.png"
const MIN_CYBER_ARENA_SIZE := Vector2(3600.0, 1400.0)
const MIN_CYBER_2X2_ARENA_SIZE := Vector2(6000.0, 4000.0)

const TILE_SOURCE_SIZE := 16
const FLOOR_WORLD_SIZE := 96.0

var background_rect := Rect2()

var floor_regions := [
	Rect2(0, 0, 16, 16),
	Rect2(16, 0, 16, 16),
	Rect2(32, 0, 16, 16),
	Rect2(48, 0, 16, 16),
	Rect2(0, 16, 16, 16),
	Rect2(16, 16, 16, 16),
]

var crack_regions := [
	Rect2(64, 0, 16, 16),
	Rect2(80, 0, 16, 16),
	Rect2(96, 0, 16, 16),
	Rect2(112, 0, 16, 16),
]

var wall_regions := [
	Rect2(0, 0, 16, 16),
	Rect2(16, 0, 16, 16),
	Rect2(32, 0, 16, 16),
	Rect2(48, 0, 16, 16),
]

var prop_regions := [
	Rect2(0, 0, 16, 16),
	Rect2(16, 0, 16, 16),
	Rect2(32, 0, 16, 16),
	Rect2(48, 0, 16, 16),
	Rect2(64, 0, 16, 16),
	Rect2(80, 0, 16, 16),
	Rect2(96, 0, 16, 16),
	Rect2(112, 0, 16, 16),
]


func build(background_parent: Node2D, obstacle_parent: Node2D, world_bounds: Vector2) -> Rect2:
	background_rect = Rect2()
	if background_parent == null:
		return background_rect

	_clear_children(background_parent)
	if obstacle_parent != null:
		_clear_children(obstacle_parent)

	if _build_four_panel_cyber_arena(background_parent, world_bounds):
		return background_rect

	if _build_two_panel_cyber_arena(background_parent, world_bounds):
		return background_rect

	var fallback_radius := maxf(maxf(world_bounds.x, world_bounds.y), MIN_CYBER_ARENA_SIZE.x * 0.5)
	_build_floor(background_parent, fallback_radius)
	if obstacle_parent != null:
		_build_ruin_edges(obstacle_parent, fallback_radius)
		_build_debris(obstacle_parent)
	background_rect = Rect2(Vector2.ONE * -fallback_radius, Vector2.ONE * fallback_radius * 2.0)
	return background_rect


func get_background_rect() -> Rect2:
	return background_rect


func _build_four_panel_cyber_arena(parent: Node2D, world_bounds: Vector2) -> bool:
	var nw_texture := _load_stage_texture(CYBER_RUINS_2X2_NW_PATH)
	var ne_texture := _load_stage_texture(CYBER_RUINS_2X2_NE_PATH)
	var sw_texture := _load_stage_texture(CYBER_RUINS_2X2_SW_PATH)
	var se_texture := _load_stage_texture(CYBER_RUINS_2X2_SE_PATH)
	if nw_texture == null or ne_texture == null or sw_texture == null or se_texture == null:
		return false

	var panel_source_width := float(nw_texture.get_width())
	var panel_source_height := float(nw_texture.get_height())
	var total_source_size := Vector2(panel_source_width * 2.0, panel_source_height * 2.0)
	var target_size := Vector2(
		maxf(MIN_CYBER_2X2_ARENA_SIZE.x, world_bounds.x * 2.0),
		maxf(MIN_CYBER_2X2_ARENA_SIZE.y, world_bounds.y * 2.0)
	)
	var scale_amount := maxf(
		target_size.x / total_source_size.x,
		target_size.y / total_source_size.y
	)
	var panel_world_size := Vector2(panel_source_width, panel_source_height) * scale_amount
	var arena_world_size := total_source_size * scale_amount
	background_rect = Rect2(arena_world_size * -0.5, arena_world_size)

	_add_cyber_panel(parent, nw_texture, Vector2(-panel_world_size.x * 0.5, -panel_world_size.y * 0.5), scale_amount)
	_add_cyber_panel(parent, ne_texture, Vector2(panel_world_size.x * 0.5, -panel_world_size.y * 0.5), scale_amount)
	_add_cyber_panel(parent, sw_texture, Vector2(-panel_world_size.x * 0.5, panel_world_size.y * 0.5), scale_amount)
	_add_cyber_panel(parent, se_texture, Vector2(panel_world_size.x * 0.5, panel_world_size.y * 0.5), scale_amount)
	return true


func _add_cyber_panel(parent: Node2D, texture: Texture2D, position: Vector2, scale_amount: float) -> void:
	var panel := _make_full_background_sprite(texture, scale_amount)
	panel.position = position
	parent.add_child(panel)


func _build_two_panel_cyber_arena(parent: Node2D, world_bounds: Vector2) -> bool:
	var west_texture := _load_stage_texture(CYBER_PANEL_WEST_PATH)
	var east_texture := _load_stage_texture(CYBER_PANEL_EAST_PATH)
	if west_texture == null:
		return false
	if east_texture == null:
		return false

	var total_source_width := float(west_texture.get_width() + east_texture.get_width())
	var source_height := float(maxi(west_texture.get_height(), east_texture.get_height()))
	var target_size := Vector2(
		maxf(MIN_CYBER_ARENA_SIZE.x, world_bounds.x * 2.0),
		maxf(MIN_CYBER_ARENA_SIZE.y, world_bounds.y * 2.0)
	)
	var scale_by_width := target_size.x / total_source_width
	var scale_by_height := target_size.y / source_height
	var scale_amount := maxf(scale_by_width, scale_by_height)
	var panel_world_width := float(west_texture.get_width()) * scale_amount
	var arena_world_size := Vector2(total_source_width * scale_amount, source_height * scale_amount)
	background_rect = Rect2(arena_world_size * -0.5, arena_world_size)

	var west := _make_full_background_sprite(west_texture, scale_amount)
	west.position = Vector2(-panel_world_width * 0.5, 0.0)
	parent.add_child(west)

	var east := _make_full_background_sprite(east_texture, scale_amount)
	east.position = Vector2(panel_world_width * 0.5, 0.0)
	parent.add_child(east)
	return true


func _load_stage_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture

	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _make_full_background_sprite(texture: Texture2D, scale_amount: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * scale_amount
	sprite.z_index = -100
	return sprite


func _build_floor(parent: Node2D, world_radius: float) -> void:
	var columns_each_side := int(ceil(world_radius / FLOOR_WORLD_SIZE)) + 2
	var rows_each_side := int(ceil(world_radius / FLOOR_WORLD_SIZE)) + 2
	var scale_amount := FLOOR_WORLD_SIZE / float(TILE_SOURCE_SIZE)

	for y in range(-rows_each_side, rows_each_side + 1):
		for x in range(-columns_each_side, columns_each_side + 1):
			var position := Vector2(x * FLOOR_WORLD_SIZE, y * FLOOR_WORLD_SIZE)
			if position.length() > world_radius + FLOOR_WORLD_SIZE * 2.0:
				continue

			var tile := _make_region_sprite(FLOOR_TEXTURE, _pick_floor_region(x, y), scale_amount)
			tile.position = position
			tile.z_index = -100
			parent.add_child(tile)

			if _positive_mod(x * 17 + y * 31, 11) == 0:
				var crack := _make_region_sprite(DUNGEON_TEXTURE, crack_regions[_positive_mod(x + y, crack_regions.size())], scale_amount)
				crack.position = position
				crack.modulate = Color(0.7, 0.68, 0.72, 0.72)
				crack.z_index = -99
				parent.add_child(crack)


func _build_ruin_edges(parent: Node2D, world_radius: float) -> void:
	var scale_amount := FLOOR_WORLD_SIZE / float(TILE_SOURCE_SIZE)
	var ring_radius := world_radius * 0.72
	var placements := [
		Vector2(-ring_radius, -ring_radius * 0.38),
		Vector2(-ring_radius * 0.72, -ring_radius * 0.5),
		Vector2(-ring_radius * 0.38, -ring_radius * 0.58),
		Vector2(ring_radius * 0.38, -ring_radius * 0.58),
		Vector2(ring_radius * 0.72, -ring_radius * 0.5),
		Vector2(ring_radius, -ring_radius * 0.38),
		Vector2(-ring_radius, ring_radius * 0.38),
		Vector2(-ring_radius * 0.55, ring_radius * 0.52),
		Vector2(ring_radius * 0.55, ring_radius * 0.52),
		Vector2(ring_radius, ring_radius * 0.38),
	]

	for index in range(placements.size()):
		var wall := _make_region_sprite(DUNGEON_TEXTURE, wall_regions[index % wall_regions.size()], scale_amount * 1.45)
		wall.position = placements[index]
		wall.z_index = -8
		parent.add_child(wall)


func _build_debris(parent: Node2D) -> void:
	var scale_amount := 4.2
	var placements := [
		Vector2(-880, -360),
		Vector2(-520, 420),
		Vector2(-160, -620),
		Vector2(260, 520),
		Vector2(620, -420),
		Vector2(980, 220),
		Vector2(-1120, 180),
		Vector2(1160, -120),
	]

	for index in range(placements.size()):
		var prop := _make_region_sprite(PROP_TEXTURE, prop_regions[index % prop_regions.size()], scale_amount)
		prop.position = placements[index]
		prop.z_index = 2
		parent.add_child(prop)


func _make_region_sprite(texture: Texture2D, region: Rect2, scale_amount: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = true
	sprite.scale = Vector2.ONE * scale_amount
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _pick_floor_region(x: int, y: int) -> Rect2:
	var pattern := _positive_mod(x * 13 + y * 7, floor_regions.size())
	return floor_regions[pattern]


func _positive_mod(value: int, divisor: int) -> int:
	var result := value % divisor
	if result < 0:
		result += divisor
	return result


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
