extends Node

const Catalog := preload("res://scripts/character_catalog.gd")

var selected_character_id := "mage"
var selected_character: Dictionary = {}


func _ready() -> void:
	_sync_selected_character()


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


func _sync_selected_character() -> void:
	var character := Catalog.get_character(selected_character_id)
	if character.is_empty():
		selected_character_id = "mage"
		character = Catalog.get_character(selected_character_id)
	selected_character = character.duplicate(true)
