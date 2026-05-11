extends Node

const Catalog := preload("res://scripts/character_catalog.gd")

const CHARACTER_SELECT_PRELOAD_PATHS := [
	"res://assets/players/mage/select/mage_live_2d_sheet_hq.png",
	"res://assets/players/hunter/select/hunter_live_2d_sheet_hq.png",
	"res://assets/ui/character_select/background_mage_v2.png",
	"res://assets/ui/character_select/background_hunter_v2.png",
	"res://assets/players/mage/portraits/mage_reference.png",
	"res://assets/players/hunter/portraits/hunter_select_reference.png",
]

var selected_character_id := "mage"
var selected_character: Dictionary = {}
var preloaded_textures: Dictionary = {}


func _ready() -> void:
	_sync_selected_character()
	preload_character_select_assets()


func _exit_tree() -> void:
	for path in CHARACTER_SELECT_PRELOAD_PATHS:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)


func set_selected_character(character_id: String) -> void:
	var character := Catalog.get_character(character_id)
	if character.is_empty():
		return

	selected_character_id = character_id
	selected_character = character.duplicate(true)


func get_selected_character() -> Dictionary:
	if selected_character.is_empty():
		_sync_selected_character()
	return selected_character


func preload_character_select_assets() -> void:
	for path in CHARACTER_SELECT_PRELOAD_PATHS:
		if ResourceLoader.exists(path, "Texture2D"):
			ResourceLoader.load_threaded_request(path, "Texture2D")


func get_preloaded_texture(path: String) -> Texture2D:
	if preloaded_textures.has(path):
		return preloaded_textures[path]
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	var texture := ResourceLoader.load_threaded_get(path) as Texture2D
	if texture != null:
		preloaded_textures[path] = texture
	return texture


func _sync_selected_character() -> void:
	var character := Catalog.get_character(selected_character_id)
	if character.is_empty():
		selected_character_id = "mage"
		character = Catalog.get_character(selected_character_id)
	selected_character = character.duplicate(true)
