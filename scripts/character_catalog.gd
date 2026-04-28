class_name CharacterCatalog
extends RefCounted

const MIN_SLOT_COUNT := 5
const GAME_SCENE_PATH := "res://scenes/Main.tscn"


static func get_characters() -> Array:
	return [
		{
			"id": "mage",
			"name": "마법사",
			"subtitle": "별빛을 다루는 강력한 마법사",
			"concept_title": "컨셉",
			"concept": "별의 힘을 빌려 전장을 지배하는 마법사.\n아름다운 별빛은 적에게는 재앙이 된다.",
			"card_image": "res://assets/players/mage/portraits/player_mage_ultimate_cutin_candidate.png",
			"card_mode": "cover",
			"card_focus": Vector2(0.48, 0.5),
			"sprite_sheet": "res://assets/players/mage/sprites/player_mage_sprite_sheet.png",
			"sprite_scale": Vector2(0.42, 0.42),
			"sprite_position": Vector2(0.0, -8.0),
			"sprite_columns": 8,
			"sprite_rows": 8,
			"ultimate_cutin_image": "res://assets/players/mage/portraits/player_mage_ultimate_character.png",
			"ultimate_cutin_side": "right",
			"ultimate_cutin_width_scale": 0.68,
			"ultimate_cutin_x_offset": 120.0,
			"select_background_image": "res://assets/ui/character_select/background_mage_v2.png",
			"select_background_mode": "cover",
			"select_background_focus": Vector2(0.5, 0.5),
			"info_side": "left",
			"info_width": 470.0,
			"detail_image": "res://assets/players/mage/portraits/player_mage_ultimate_cutin_candidate.png",
			"detail_mode": "contain",
			"detail_focus": Vector2(0.5, 0.5),
			"detail_info_side": "left",
			"detail_overlay_color": Color(0.0, 0.0, 0.0, 0.02),
			"theme_color": Color(0.48, 0.68, 1.0),
			"accent_color": Color(1.0, 0.78, 0.34),
			"skills": [
				{
					"name": "에너지 구체",
					"description": "마법 에너지를 구체로 발사하여 적에게 피해를 입힙니다.",
					"icon_label": "✦",
					"icon_shape": "star",
					"icon_path": "",
					"color": Color(0.22, 0.62, 1.0),
				},
				{
					"name": "별빛 광선",
					"description": "하늘에서 별빛 광선을 소환하여 적들을 심판합니다.",
					"icon_label": "✧",
					"icon_shape": "ray",
					"icon_path": "",
					"color": Color(0.65, 0.88, 1.0),
				},
				{
					"name": "마나 베리어",
					"description": "마나의 힘으로 보호막을 생성하여 피해를 흡수합니다.",
					"icon_label": "◌",
					"icon_shape": "barrier",
					"icon_path": "",
					"color": Color(0.35, 0.85, 1.0),
				},
			],
		},
		{
			"id": "hunter",
			"name": "헌터",
			"subtitle": "도심의 그림자를 가르는 집행자",
			"concept_title": "컨셉",
			"concept": "어반 판타지의 밤을 사냥터로 삼는 여자 헌터.\n검은 기계식 에너지소드로 표적을 조용히 집행한다.",
			"card_image": "res://assets/players/hunter/portraits/hunter_select_reference.png",
			"card_mode": "cover",
			"card_focus": Vector2(0.25, 0.48),
			"sprite_sheet": "res://assets/players/hunter/sprites/player_hunter_sprite_sheet_v3.png",
			"sprite_scale": Vector2(0.42, 0.42),
			"sprite_position": Vector2(0.0, -8.0),
			"sprite_columns": 8,
			"sprite_rows": 8,
			"ultimate_cutin_image": "res://assets/players/hunter/portraits/player_hunter_ultimate_character.png",
			"ultimate_cutin_side": "right",
			"ultimate_cutin_width_scale": 0.58,
			"ultimate_cutin_x_offset": 180.0,
			"select_background_image": "res://assets/ui/character_select/background_hunter_v2.png",
			"select_background_mode": "cover",
			"select_background_focus": Vector2(0.5, 0.5),
			"info_side": "left",
			"info_width": 470.0,
			"detail_image": "res://assets/players/hunter/portraits/hunter_select_reference.png",
			"detail_mode": "contain",
			"detail_focus": Vector2(0.5, 0.5),
			"detail_info_side": "right",
			"detail_overlay_color": Color(0.0, 0.0, 0.0, 0.04),
			"theme_color": Color(1.0, 0.18, 0.18),
			"accent_color": Color(0.98, 0.58, 0.48),
			"skills": [
				{
					"name": "에너지 슬래시",
					"description": "붉은 에너지 검격으로 전방의 적을 베어냅니다.",
					"icon_label": "◇",
					"icon_shape": "slash",
					"icon_path": "",
					"color": Color(1.0, 0.12, 0.12),
				},
				{
					"name": "섀도우 스텝",
					"description": "짧은 순간 그림자처럼 이동해 위험을 벗어납니다.",
					"icon_label": "◆",
					"icon_shape": "step",
					"icon_path": "",
					"color": Color(0.65, 0.08, 0.1),
				},
				{
					"name": "익스큐션 프로토콜",
					"description": "처형 명령을 내려 표적에게 강력한 일격을 가합니다.",
					"icon_label": "▣",
					"icon_shape": "protocol",
					"icon_path": "",
					"color": Color(1.0, 0.28, 0.18),
				},
			],
		},
	]


static func get_slot_count() -> int:
	return maxi(MIN_SLOT_COUNT, get_characters().size())


static func get_character(character_id: String) -> Dictionary:
	for character in get_characters():
		if character["id"] == character_id:
			return character
	return {}


static func find_character_index(character_id: String) -> int:
	var characters := get_characters()
	for index in range(characters.size()):
		if characters[index]["id"] == character_id:
			return index
	return 0
