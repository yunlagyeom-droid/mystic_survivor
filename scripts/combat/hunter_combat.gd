extends Node

signal projectile_requested(projectile_scene: PackedScene, origin: Vector2, direction: Vector2, damage: int, params: Dictionary)
signal world_vfx_requested(vfx: Node2D)
signal status_changed(skill_1_text: String, skill_2_text: String, skill_3_text: String)

const HUNTER_SWORD_WAVE_SCENE := preload("res://scenes/HunterSwordWave.tscn")
const DASH_BASIC_VFX_TEXTURE := preload("res://assets/players/hunter/skills/dash/hunter_dash_basic_vfx_sheet.png")
const DASH_PATH_DAMAGE_VFX_TEXTURE := preload("res://assets/players/hunter/skills/dash/hunter_dash_path_damage_vfx_sheet.png")
const DASH_SPINNING_ARRIVAL_VFX_TEXTURE := preload("res://assets/players/hunter/skills/dash/hunter_dash_spinning_arrival_vfx_sheet.png")
const EXECUTION_SLASH_VFX_TEXTURE := preload("res://assets/players/hunter/skills/ultimate/hunter_execution_slash_vfx_sheet.png")
const EXECUTION_DASH_VFX_TEXTURE := preload("res://assets/players/hunter/skills/ultimate/hunter_execution_dash_vfx_sheet.png")
const EXECUTION_SLASH_MAIN_TEXTURE := preload("res://assets/players/hunter/skills/variants/v12_sword_wave_enhanced_large.png")
const ULTIMATE_AURA_LOOP_TEXTURE := preload("res://assets/players/hunter/skills/ultimate/hunter_ultimate_aura_loop_sheet.png")
const ULTIMATE_BLAST_CHARGE_TEXTURE := preload("res://assets/players/hunter/skills/ultimate/hunter_ultimate_blast_charge_sheet.png")
const ULTIMATE_BLAST_IMPACT_TEXTURE := preload("res://assets/players/hunter/skills/ultimate/hunter_ultimate_blast_impact_sheet.png")
const DASH_SFX_PATH := "res://assets/audio/hunter/hunter_dash_clean_plasma_blade.mp3"
const BASIC_SLASH_SFX_PATH := "res://assets/audio/hunter/hunter_basic_fast_plasma_sword.mp3"
const BASIC_SLASH_LEVEL_2_SFX_PATH := "res://assets/audio/hunter/hunter_basic_slash_level2_rapid_bright.mp3"
const BASIC_SLASH_LEVEL_3_SFX_PATHS := [
	"res://assets/audio/hunter/hunter_basic_slash_level3_fast_plasma_alt.mp3",
	"res://assets/audio/hunter/hunter_basic_slash_level3_dark_fantasy.mp3",
	"res://assets/audio/hunter/hunter_basic_slash_level3_rapid_bright_a.mp3",
	"res://assets/audio/hunter/hunter_basic_slash_level3_rapid_bright_b.mp3",
]
const ULTIMATE_BASIC_SLASH_SFX_PATHS := [
	"res://assets/audio/hunter/hunter_basic_slash_level3_rapid_bright_a.mp3",
	"res://assets/audio/hunter/hunter_basic_slash_level3_rapid_bright_b.mp3",
	"res://assets/audio/hunter/hunter_basic_slash_level3_dark_fantasy.mp3",
]
const SWORD_WAVE_SFX_PATH := "res://assets/audio/hunter/hunter_sword_wave_energy_slash.mp3"
const SFX_BUS_NAME := "SFX"

const DASH_VFX_COLUMNS := 4
const DASH_VFX_ROWS := 4

const SLASH_VFX_STAGE_0 := [
	{"path": "res://assets/players/hunter/skills/variants/v09_short_safe_slash.png", "rotation_offset": 0.0, "scale": 0.92},
]
const SLASH_VFX_STAGE_1 := [
	{"path": "res://assets/players/hunter/skills/variants/v01_single_clean_arc.png", "rotation_offset": 0.0, "scale": 0.78},
]
const SLASH_VFX_STAGE_2 := [
	{"path": "res://assets/players/hunter/skills/variants/v01_single_clean_arc.png", "rotation_offset": 0.0, "scale": 0.9},
]
const SLASH_VFX_STAGE_3 := [
	{"path": "res://assets/players/hunter/skills/variants/v01_single_clean_arc.png", "rotation_offset": 0.0, "scale": 1.02},
]
const SLASH_VFX_STAGE_4 := [
	{"path": "res://assets/players/hunter/skills/variants/v01_single_clean_arc.png", "rotation_offset": -0.08, "scale": 1.0},
	{"path": "res://assets/players/hunter/skills/variants/v03_cone_edge_arc.png", "rotation_offset": 0.08, "scale": 1.04},
]
const SLASH_VFX_STAGE_5 := [
	{"path": "res://assets/players/hunter/skills/variants/v01_single_clean_arc.png", "rotation_offset": -0.1, "scale": 0.98},
	{"path": "res://assets/players/hunter/skills/variants/v03_cone_edge_arc.png", "rotation_offset": 0.04, "scale": 1.04},
	{"path": "res://assets/players/hunter/skills/variants/v02_single_heavy_arc.png", "rotation_offset": 0.12, "scale": 1.08},
]

var slash_damage := 24
var slash_range := 240.0
var slash_arc_degrees := 120.0
var slash_visual_radius := 240.0
var slash_vfx_texture_path := "res://assets/players/hunter/skills/hunter_wide_slash_v2.png"
var slash_growth_level := 0
var slash_form_level := 1
var slash_style_level := 0
var slash_sequence_step_delay := 0.07
var slash_sequence_lock_timer := 0.0
var slash_cooldown := 0.62
var slash_timer := 0.0
var dash_distance := 210.0
var dash_distance_level := 0
var dash_cooldown := 2.2
var dash_cooldown_level := 0
var dash_timer := 0.0
var dash_charges := 1
var dash_max_charges := 1
var dash_invulnerable_duration := 0.16
var dash_path_damage := 28
var dash_path_damage_width := 58.0
var dash_arrival_spin_damage := 42
var dash_arrival_spin_radius := 150.0
var dash_vfx_scale := 0.34
var dash_hit_vfx_scale := 0.28
var dash_path_damage_unlocked := false
var dash_spinning_arrival_unlocked := false
var dash_vfx_material: CanvasItemMaterial
var guard_duration := 0.24
var guard_growth_level := 0
var guard_cooldown := 5.5
var guard_timer := 0.0
var guard_active_timer := 0.0
var guard_damage_scale := 0.0
var parry_direction := Vector2.DOWN
var parry_counter_unlocked := false
var parry_counter_level := 0
var parry_spin_counter_unlocked := false
var parry_counter_damage := 38
var parry_counter_range := 260.0
var sword_wave_unlocked := true
var sword_wave_enhanced := false
var sword_wave_growth_level := 0
var sword_wave_stack_unlocked := false
var sword_wave_charges := 1
var sword_wave_max_charges := 1
var sword_wave_damage := 22
var sword_wave_enhanced_damage := 34
var sword_wave_cooldown := 2.4
var sword_wave_enhanced_cooldown := 2.8
var sword_wave_timer := 0.0
var ultimate_damage := 95
var ultimate_radius := 520.0
var execution_mode_base_duration := 6.0
var execution_mode_bonus_duration := 0.0
var ultimate_duration_level := 0
var ultimate_charge_level := 0
var ultimate_duration_epic_unlocked := false
var ultimate_charge_epic_unlocked := false
var execution_mode_timer := 0.0
var ultimate_finisher_unlocked := false
var ultimate_finisher_used := false
var ultimate_blast_unlocked := false
var execution_dash_cooldown_multiplier := 0.35
var execution_slash_step_delay := 0.045
var execution_slash_cooldown_multiplier := 0.55
var execution_slash_damage_multiplier := 0.72
var execution_slash_range := 520.0
var execution_slash_arc_degrees := 170.0
var execution_slash_cell_index := 0
var experiment_mode := false
var player: Node
var dash_sfx: AudioStream
var basic_slash_sfx: AudioStream
var basic_slash_level_2_sfx: AudioStream
var basic_slash_level_3_sfx_pool: Array[AudioStream] = []
var ultimate_basic_slash_sfx_pool: Array[AudioStream] = []
var sword_wave_sfx: AudioStream
var ultimate_aura_sprite: Sprite2D
var ultimate_vfx_material: CanvasItemMaterial
var ultimate_aura_animation_time := 0.0


func setup(owner: Node) -> void:
	player = owner
	_load_sfx()
	_build_dash_vfx_material()
	_emit_status()


func combat_process(delta: float, _input_direction: Vector2) -> void:
	if experiment_mode:
		_reset_experiment_cooldowns()

	slash_timer = maxf(0.0, slash_timer - delta)
	slash_sequence_lock_timer = maxf(0.0, slash_sequence_lock_timer - delta)
	_recharge_dash(delta)
	guard_timer = maxf(0.0, guard_timer - delta)
	guard_active_timer = maxf(0.0, guard_active_timer - delta)
	_recharge_sword_wave(delta)
	execution_mode_timer = maxf(0.0, execution_mode_timer - delta)
	_update_ultimate_aura(delta)

	if guard_active_timer > 0.0:
		player.set_combat_modulate(Color(1.25, 0.72, 0.72))
	elif _is_execution_mode_active():
		player.set_combat_modulate(Color(1.45, 0.62, 0.58))
	else:
		player.clear_combat_modulate()

	if slash_timer <= 0.0 and slash_sequence_lock_timer <= 0.0:
		_try_slash()

	_emit_status()


func try_skill_1(input_direction: Vector2) -> void:
	if dash_charges <= 0 and not experiment_mode:
		return

	var dash_direction := input_direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = player.last_direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.DOWN

	var start_position: Vector2 = player.global_position
	var target_position: Vector2 = player.global_position + dash_direction * dash_distance
	var bounds: Vector2 = player.get_world_bounds() if player.has_method("get_world_bounds") else Vector2.ONE * player.world_radius
	target_position.x = clampf(target_position.x, -bounds.x, bounds.x)
	target_position.y = clampf(target_position.y, -bounds.y, bounds.y)

	player.global_position = target_position
	player.velocity = Vector2.ZERO
	player.last_direction = dash_direction
	player.set_invulnerable(dash_invulnerable_duration)
	if player.has_method("play_mobility_voice"):
		player.play_mobility_voice(0.1, -5.8)
	player.update_walk_animation(dash_direction, dash_distance)
	if not experiment_mode:
		dash_charges = maxi(0, dash_charges - 1)
		if dash_charges < dash_max_charges and dash_timer <= 0.0:
			dash_timer = _get_dash_cooldown()
	var path_targets := _apply_dash_path_damage(start_position, target_position)
	if dash_spinning_arrival_unlocked:
		_apply_dash_arrival_spin_damage(target_position, path_targets)
	_spawn_dash_vfx(start_position, target_position)
	_play_sfx(dash_sfx, -11.5, 0.98, 1.04)
	_emit_status()


func try_skill_2(input_direction: Vector2) -> void:
	if guard_timer > 0.0 and not experiment_mode:
		return

	parry_direction = input_direction.normalized()
	if parry_direction == Vector2.ZERO:
		parry_direction = player.last_direction.normalized()
	if parry_direction == Vector2.ZERO:
		parry_direction = Vector2.DOWN
	guard_timer = 0.0 if experiment_mode else guard_cooldown
	guard_active_timer = guard_duration
	_spawn_guard_vfx()
	_emit_status()


func try_skill_3(input_direction: Vector2) -> void:
	if not sword_wave_unlocked:
		return
	if sword_wave_charges <= 0 and not experiment_mode:
		return

	var wave_direction := input_direction.normalized()
	if wave_direction == Vector2.ZERO:
		wave_direction = player.last_direction.normalized()
	if wave_direction == Vector2.ZERO:
		wave_direction = player.last_attack_direction.normalized()
	if wave_direction == Vector2.ZERO:
		wave_direction = Vector2.DOWN

	var damage := sword_wave_enhanced_damage if sword_wave_enhanced else sword_wave_damage
	var params := {
		"enhanced": sword_wave_enhanced,
		"speed_multiplier": _get_sword_wave_speed_multiplier(),
		"size_multiplier": 1.0 + 0.05 * float(sword_wave_growth_level),
	}
	if player.has_method("lock_movement"):
		player.lock_movement(0.1)
	if player.has_method("play_action_animation"):
		player.play_action_animation("attack", wave_direction, 0.12)
	if player.has_method("try_play_attack_voice"):
		player.try_play_attack_voice("sword_wave")
	projectile_requested.emit(HUNTER_SWORD_WAVE_SCENE, player.global_position + wave_direction * 48.0, wave_direction, _get_modified_attack_damage(damage), params)
	_play_sfx(sword_wave_sfx, -7.0, 0.96, 1.03)
	player.last_attack_direction = wave_direction
	if not experiment_mode:
		sword_wave_charges = maxi(0, sword_wave_charges - 1)
		if sword_wave_charges < sword_wave_max_charges and sword_wave_timer <= 0.0:
			sword_wave_timer = _get_sword_wave_cooldown()
	_emit_status()


func set_experiment_mode(enabled: bool) -> void:
	experiment_mode = enabled
	if experiment_mode:
		_reset_experiment_cooldowns()
	_emit_status()


func _reset_experiment_cooldowns() -> void:
	slash_timer = 0.0
	dash_timer = 0.0
	guard_timer = 0.0
	sword_wave_timer = 0.0


func reset_upgrades() -> void:
	slash_damage = 24
	slash_range = 240.0
	slash_visual_radius = 240.0
	slash_growth_level = 0
	slash_form_level = 1
	slash_cooldown = 0.62
	slash_style_level = 0
	dash_distance = 210.0
	dash_distance_level = 0
	dash_cooldown = 2.2
	dash_cooldown_level = 0
	dash_max_charges = 1
	dash_charges = 1
	dash_timer = 0.0
	dash_path_damage_unlocked = false
	dash_spinning_arrival_unlocked = false
	guard_duration = 0.24
	guard_growth_level = 0
	parry_counter_unlocked = false
	parry_counter_level = 0
	parry_spin_counter_unlocked = false
	sword_wave_unlocked = true
	sword_wave_enhanced = false
	sword_wave_growth_level = 0
	sword_wave_stack_unlocked = false
	sword_wave_max_charges = 1
	sword_wave_charges = 1
	sword_wave_timer = 0.0
	sword_wave_damage = 22
	sword_wave_enhanced_damage = 34
	ultimate_damage = 95
	execution_mode_bonus_duration = 0.0
	ultimate_duration_level = 0
	ultimate_charge_level = 0
	ultimate_duration_epic_unlocked = false
	ultimate_charge_epic_unlocked = false
	ultimate_finisher_unlocked = false
	ultimate_finisher_used = false
	ultimate_blast_unlocked = false
	execution_dash_cooldown_multiplier = 0.35
	execution_slash_cooldown_multiplier = 0.55
	execution_mode_timer = 0.0
	_stop_ultimate_aura()
	_emit_status()


func use_ultimate(context: Dictionary) -> void:
	var center: Vector2 = context.get("origin", player.global_position)
	execution_mode_timer = _get_execution_mode_duration()
	ultimate_finisher_used = false
	_start_ultimate_aura()
	if ultimate_blast_unlocked:
		_play_ultimate_blast_sequence(center)
	_emit_status()


func get_ultimate_charge_multiplier() -> float:
	return 1.0 + 0.08 * float(ultimate_charge_level)


func try_ultimate_recast() -> bool:
	if not ultimate_finisher_unlocked or ultimate_finisher_used or not _is_execution_mode_active():
		return false
	var direction: Vector2 = player.last_attack_direction.normalized()
	if direction == Vector2.ZERO:
		direction = player.last_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var params := {
		"enhanced": true,
		"speed_multiplier": 1.0,
		"size_multiplier": 1.35,
	}
	projectile_requested.emit(HUNTER_SWORD_WAVE_SCENE, player.global_position + direction * 54.0, direction, _get_modified_attack_damage(140), params)
	ultimate_finisher_used = true
	_emit_status()
	return true


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"hunter_slash_growth":
			slash_growth_level += 1
			slash_damage = maxi(1, int(round(float(slash_damage) * 1.06)))
			slash_range *= 1.04
			slash_visual_radius *= 1.04
		"hunter_slash_evolve":
			slash_form_level += 1
			slash_growth_level = 0
			slash_style_level = _get_slash_style_for_form()
		"hunter_dash_cooldown":
			dash_cooldown_level += 1
			dash_cooldown = maxf(0.75, dash_cooldown * 0.93)
			_update_dash_charge_capacity()
		"hunter_dash_distance":
			dash_distance_level += 1
			dash_distance += 35.0
		"hunter_dash_path_damage":
			dash_path_damage_unlocked = true
			dash_distance_level = 0
		"hunter_dash_spinning_arrival":
			dash_spinning_arrival_unlocked = true
			dash_distance_level = 0
		"hunter_parry_window":
			guard_growth_level += 1
			guard_duration = 0.24 + 0.04 * float(guard_growth_level)
		"hunter_parry_counter":
			parry_counter_unlocked = true
			guard_growth_level = 0
		"hunter_parry_counter_damage":
			parry_counter_level += 1
			parry_counter_damage = maxi(1, int(round(float(parry_counter_damage) * 1.1)))
		"hunter_parry_spin_counter":
			parry_spin_counter_unlocked = true
			parry_counter_level = 0
		"hunter_sword_wave_growth":
			sword_wave_growth_level += 1
			sword_wave_damage = maxi(1, int(round(float(sword_wave_damage) * 1.08)))
			sword_wave_enhanced_damage = maxi(1, int(round(float(sword_wave_enhanced_damage) * 1.08)))
		"hunter_sword_wave_enhance":
			sword_wave_enhanced = true
			sword_wave_growth_level = 0
		"hunter_sword_wave_stack":
			sword_wave_stack_unlocked = true
			sword_wave_max_charges = 2
			sword_wave_charges = maxi(sword_wave_charges, 2)
			sword_wave_growth_level = 0
		"hunter_ultimate_duration":
			ultimate_duration_level += 1
			execution_mode_bonus_duration += 0.7
		"hunter_ultimate_charge":
			ultimate_charge_level += 1
		"hunter_ultimate_duration_epic":
			ultimate_duration_epic_unlocked = true
			execution_slash_cooldown_multiplier = 0.48
		"hunter_ultimate_charge_epic":
			ultimate_charge_epic_unlocked = true
			execution_dash_cooldown_multiplier = 0.28
		"hunter_ultimate_finisher":
			ultimate_finisher_unlocked = true
		"hunter_ultimate_blast":
			ultimate_blast_unlocked = true
	_emit_status()


func can_apply_upgrade(upgrade_id: String) -> bool:
	match upgrade_id:
		"hunter_slash_growth":
			return slash_form_level < 4 and slash_growth_level < 5
		"hunter_slash_evolve":
			return slash_form_level < 4 and slash_growth_level >= 5
		"hunter_dash_cooldown":
			return dash_cooldown_level < 5
		"hunter_dash_distance":
			return dash_distance_level < 5
		"hunter_sword_wave_enhance":
			return sword_wave_growth_level >= 5 and not sword_wave_enhanced
		"hunter_sword_wave_growth":
			return sword_wave_growth_level < 5 and not sword_wave_stack_unlocked
		"hunter_sword_wave_stack":
			return sword_wave_enhanced and sword_wave_growth_level >= 5 and not sword_wave_stack_unlocked
		"hunter_dash_path_damage":
			return dash_distance_level >= 5 and not dash_path_damage_unlocked
		"hunter_dash_spinning_arrival":
			return dash_path_damage_unlocked and dash_distance_level >= 5 and not dash_spinning_arrival_unlocked
		"hunter_parry_window":
			return not parry_counter_unlocked and guard_growth_level < 5
		"hunter_parry_counter":
			return guard_growth_level >= 5 and not parry_counter_unlocked
		"hunter_parry_counter_damage":
			return parry_counter_unlocked and not parry_spin_counter_unlocked and parry_counter_level < 5
		"hunter_parry_spin_counter":
			return parry_counter_unlocked and parry_counter_level >= 5 and not parry_spin_counter_unlocked
		"hunter_ultimate_duration":
			return ultimate_duration_level < 5 and not ultimate_duration_epic_unlocked
		"hunter_ultimate_charge":
			return ultimate_charge_level < 5 and not ultimate_charge_epic_unlocked
		"hunter_ultimate_duration_epic":
			return ultimate_duration_level >= 5 and not ultimate_duration_epic_unlocked
		"hunter_ultimate_charge_epic":
			return ultimate_charge_level >= 5 and not ultimate_charge_epic_unlocked
		"hunter_ultimate_finisher":
			return ultimate_duration_epic_unlocked and not ultimate_finisher_unlocked
		"hunter_ultimate_blast":
			return ultimate_charge_epic_unlocked and not ultimate_blast_unlocked
		_:
			return true


func get_upgrade_pool() -> Array[Dictionary]:
	return [
		_make_upgrade("hunter_slash_growth", "에너지 슬래시 강화", "기본 공격의 피해량과 범위가 증가합니다.", "Rare", "slash", "res://assets/ui/hud/hunter_skill_sword_wave_casual_v2.png", "hunter_slash", slash_growth_level, 5),
		_make_upgrade("hunter_slash_evolve", "에너지 슬래시 Lv.%d" % [slash_form_level + 1], _get_slash_evolve_description(), "Epic", "slash", "res://assets/ui/hud/hunter_skill_sword_wave_casual_v2.png", "hunter_slash_evolve", slash_form_level - 1, 3),
		_make_upgrade("hunter_dash_cooldown", "재빠른 움직임", "섀도우 스탭의 재사용 대기 시간이 감소합니다.", "Rare", "dash", "res://assets/ui/hud/hunter_skill_dash_casual_v2.png", "hunter_dash_cooldown", dash_cooldown_level, 5),
		_make_upgrade("hunter_dash_distance", "도약", "새도우 스탭의 이동거리가 증가합니다", "Rare", "dash", "res://assets/ui/hud/hunter_skill_dash_casual_v2.png", "hunter_dash_distance", dash_distance_level, 5),
		_make_upgrade("hunter_dash_path_damage", "섀도우 스탭: 엑시스", "섀도우 스탭 사용 중 돌진 경로의 적에게 피해를 줍니다.", "Epic", "dash", "res://assets/ui/hud/hunter_skill_dash_casual_v2.png", "hunter_dash_path", 0, 1),
		_make_upgrade("hunter_dash_spinning_arrival", "섀도우 스탭: 블레이드 스톰", "도착 지점 주변을 회전 베기로 공격합니다.", "Epic", "dash", "res://assets/ui/hud/hunter_skill_dash_casual_v2.png", "hunter_dash_spin", 0, 1),
		_make_upgrade("hunter_parry_window", "카운터 엣지", "패링 판정시간이 소폭 증가합니다.", "Rare", "guard", "res://assets/ui/hud/hunter_skill_parry_casual_v2.png", "hunter_parry_window", guard_growth_level, 5),
		_make_upgrade("hunter_parry_counter", "카운터 엣지: 리포스트", "패링 성공 시 막은 방향으로 반격합니다.", "Epic", "guard", "res://assets/ui/hud/hunter_skill_parry_casual_v2.png", "hunter_parry_counter", 0, 1),
		_make_upgrade("hunter_parry_counter_damage", "리포스트 강화", "반격 피해가 소폭 증가합니다. ", "Rare", "guard", "res://assets/ui/hud/hunter_skill_parry_casual_v2.png", "hunter_parry_damage", parry_counter_level, 5),
		_make_upgrade("hunter_parry_spin_counter", "카운터 엣지: 스핀 리버설", "반격이 원형 회전 베기로 진화합니다.", "Epic", "guard", "res://assets/ui/hud/hunter_skill_parry_casual_v2.png", "hunter_parry_spin", 0, 1),
		_make_upgrade("hunter_sword_wave_growth", "에너지 소드: 방출", "검기의 크기와 피해량이 소폭 증가합니다.", "Rare", "sword_wave", "res://assets/ui/hud/hunter_skill_sword_wave_casual_v2.png", "hunter_red_arc", sword_wave_growth_level, 5),
		_make_upgrade("hunter_sword_wave_enhance", "에너지 소드: 오버차지", "에너지 소드의 출력이 상승하여 검기가 강화됩니다.", "Epic", "sword_wave", "res://assets/ui/hud/hunter_skill_sword_wave_casual_v2.png", "hunter_red_arc_enhance", 0, 1),
		_make_upgrade("hunter_sword_wave_stack", "에너지 소드: 더블 차지", "검기를 최대 2회 충전합니다.", "Epic", "sword_wave", "res://assets/ui/hud/hunter_skill_sword_wave_casual_v2.png", "hunter_red_arc_stack", 0, 1),
		_make_upgrade("hunter_ultimate_duration", "익스큐션 프로토콜: 오버로드", "처형 모드의 지속시간이 소폭 증가합니다.", "Rare", "ultimate", "res://assets/ui/hud/hunter_skill_ultimate_overload_casual_v1.png", "hunter_overload_duration", ultimate_duration_level, 5),
		_make_upgrade("hunter_ultimate_charge", "익스큐션 프로토콜: 오버차지", "궁극기 게이지의 획득량이 소폭 증가합니다. ", "Rare", "ultimate", "res://assets/ui/hud/hunter_skill_ultimate_overload_casual_v1.png", "hunter_overload_charge", ultimate_charge_level, 5),
		_make_upgrade("hunter_ultimate_duration_epic", "익스큐션 프로토콜: 레드 템포", "오버로드 중 기본공격 재사용 대기시간이 더 짧아집니다.", "Epic", "ultimate", "res://assets/ui/hud/hunter_skill_ultimate_overload_casual_v1.png", "hunter_overload_duration_epic", 0, 1),
		_make_upgrade("hunter_ultimate_charge_epic", "익스큐션 프로토콜: 제로 스텝", "오버로드 중 섀도우 스탭 재사용 대기시간이 더 짧아집니다.", "Epic", "ultimate", "res://assets/ui/hud/hunter_skill_ultimate_overload_casual_v1.png", "hunter_overload_charge_epic", 0, 1),
		_make_upgrade("hunter_ultimate_finisher", "익스큐션 프로토콜: 처형", "처형모드 중 Q를 다시 눌러 사용할 수 있습니다.", "Legendary", "ultimate", "res://assets/ui/hud/hunter_skill_ultimate_overload_casual_v1.png", "hunter_overload_legendary", 0, 1),
		_make_upgrade("hunter_ultimate_blast", "익스큐션 프로토콜: 크림슨 노바", "처형모드 발동 시 주변 적에게 큰 폭발 피해를 입힙니다.", "Legendary", "ultimate", "res://assets/ui/hud/hunter_skill_ultimate_overload_casual_v1.png", "hunter_overload_legendary", 0, 1),
	]


func _make_upgrade(id: String, label: String, description: String, rarity: String, skill_id: String, icon_path: String, family: String, level_current: int, level_max: int) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"description": description,
		"rarity": rarity,
		"category": "character",
		"character_id": "hunter",
		"skill_id": skill_id,
		"icon_path": icon_path,
		"upgrade_family": family,
		"level_current": level_current,
		"level_max": level_max,
	}


func _get_slash_evolve_description() -> String:
	match slash_form_level + 1:
		2:
			return "기본 공격이 조금 넓은 검격으로 바뀝니다."
		3:
			return "기본 공격이 2연속 검격으로 바뀝니다."
		_:
			return "기본 공격이 3연속 검격으로 바뀝니다."


func get_status_texts() -> Array[String]:
	var dash_text := "스탭 %d/%d" % [dash_charges, dash_max_charges]
	if dash_charges <= 0 and dash_timer > 0.0:
		dash_text = "스탭 %.1f초" % dash_timer
	var guard_text := "패링 %.1f초" % guard_active_timer if guard_active_timer > 0.0 else "패링 준비"
	if guard_active_timer <= 0.0 and guard_timer > 0.0:
		guard_text = "패링 %.1f초" % guard_timer

	var sword_wave_text := "익스큐션 %.1f초" % execution_mode_timer if _is_execution_mode_active() else "레드 아크 준비"
	if not _is_execution_mode_active() and sword_wave_unlocked:
		sword_wave_text = "레드 아크 %d/%d" % [sword_wave_charges, sword_wave_max_charges]
		if sword_wave_charges <= 0 and sword_wave_timer > 0.0:
			sword_wave_text = "검기 %.1f초" % sword_wave_timer
	return [dash_text, guard_text, sword_wave_text]


func get_hud_skill_slots() -> Array[Dictionary]:
	return [
		{
			"id": "dash",
			"label": "STEP",
			"icon_path": "res://assets/ui/hud/hunter_skill_dash_casual_v2.png",
			"cooldown_remaining": dash_timer,
			"cooldown_total": _get_dash_cooldown(),
			"ready": dash_charges > 0,
			"active": false,
			"locked": false,
			"charges": dash_charges,
			"max_charges": dash_max_charges,
		},
		{
			"id": "guard",
			"label": "PARRY",
			"icon_path": "res://assets/ui/hud/hunter_skill_parry_casual_v2.png",
			"cooldown_remaining": guard_timer,
			"cooldown_total": guard_cooldown,
			"ready": guard_timer <= 0.0,
			"active": guard_active_timer > 0.0,
			"locked": false,
		},
		{
			"id": "sword_wave",
			"label": "WAVE",
			"icon_path": "res://assets/ui/hud/hunter_skill_sword_wave_casual_v2.png",
			"cooldown_remaining": sword_wave_timer,
			"cooldown_total": _get_sword_wave_cooldown(),
			"ready": sword_wave_unlocked and sword_wave_charges > 0,
			"active": _is_execution_mode_active(),
			"locked": not sword_wave_unlocked,
			"charges": sword_wave_charges,
			"max_charges": sword_wave_max_charges,
		},
	]


func _is_execution_mode_active() -> bool:
	return execution_mode_timer > 0.0


func _get_execution_mode_duration() -> float:
	return execution_mode_base_duration + execution_mode_bonus_duration


func modify_incoming_damage(amount: int) -> int:
	if guard_active_timer <= 0.0:
		return amount

	_spawn_guard_block_vfx()
	guard_active_timer = 0.0
	if parry_counter_unlocked:
		_apply_parry_counter()
	return int(ceil(float(amount) * guard_damage_scale))


func _try_slash() -> void:
	var nearest_enemy := find_nearest_enemy()
	if nearest_enemy == null:
		slash_timer = 0.0 if experiment_mode else 0.15
		return
	var active_slash_range := execution_slash_range if _is_execution_mode_active() else slash_range
	if nearest_enemy.global_position.distance_to(player.global_position) > active_slash_range:
		slash_timer = 0.0 if experiment_mode else 0.18
		return

	var direction: Vector2 = (nearest_enemy.global_position - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = player.last_attack_direction

	var slash_targets := _find_execution_slash_targets(direction) if _is_execution_mode_active() else _find_slash_targets(direction)
	if slash_targets.is_empty():
		slash_timer = 0.0 if experiment_mode else 0.18
		return

	if player.has_method("play_action_animation"):
		var animation_duration := 0.34
		if player.has_method("get_action_animation_duration"):
			animation_duration = _get_basic_attack_cooldown(player.get_action_animation_duration("attack", animation_duration))
		player.play_action_animation("attack", direction, animation_duration)

	if player.has_method("try_play_attack_voice"):
		player.try_play_attack_voice("basic")
	_play_slash_sequence(direction)
	var active_slash_cooldown := slash_cooldown * (execution_slash_cooldown_multiplier if _is_execution_mode_active() else 1.0)
	slash_timer = 0.0 if experiment_mode else _get_basic_attack_cooldown(active_slash_cooldown)


func _play_slash_sequence(direction: Vector2) -> void:
	var execution_active := _is_execution_mode_active()
	var sequence := _get_execution_slash_sequence() if execution_active else _get_slash_sequence()
	var step_damage := _get_modified_attack_damage(_get_slash_step_damage(sequence.size()))
	var step_delay := execution_slash_step_delay if execution_active else slash_sequence_step_delay
	if execution_active:
		step_damage = maxi(1, int(round(float(slash_damage) * execution_slash_damage_multiplier)))
	slash_sequence_lock_timer = step_delay * float(sequence.size()) + 0.02

	for index in range(sequence.size()):
		var step: Dictionary = sequence[index]
		var delay := step_delay * float(index)
		if delay <= 0.0:
			_apply_slash_step(direction, step, step_damage, index, sequence.size())
		else:
			get_tree().create_timer(delay).timeout.connect(_apply_slash_step.bind(direction, step, step_damage, index, sequence.size()))


func _apply_slash_step(direction: Vector2, step: Dictionary, damage: int, step_index: int, step_count: int) -> void:
	if player == null or not is_instance_valid(player):
		return

	var targets := _find_execution_slash_targets(direction) if _is_execution_mode_active() else _find_slash_targets(direction)
	for enemy in targets:
		if is_instance_valid(enemy):
			enemy.call("take_damage", damage, "attack")

	_play_basic_slash_sfx(step_index, step_count)
	_spawn_slash_vfx(
		direction,
		str(step.get("path", slash_vfx_texture_path)),
		float(step.get("rotation_offset", 0.0)),
		float(step.get("scale", 1.0))
	)


func _get_slash_sequence() -> Array:
	var effective_style_level := maxi(slash_style_level, _get_slash_style_for_form())
	match effective_style_level:
		0:
			return SLASH_VFX_STAGE_0
		1:
			return SLASH_VFX_STAGE_1
		2:
			return SLASH_VFX_STAGE_2
		3:
			return SLASH_VFX_STAGE_3
		4:
			return SLASH_VFX_STAGE_4
		_:
			return SLASH_VFX_STAGE_5


func _get_slash_style_for_form() -> int:
	match slash_form_level:
		2:
			return 3
		3:
			return 4
		4:
			return 5
		_:
			return 0


func _get_execution_slash_sequence() -> Array:
	return [
		{"rotation_offset": -0.1, "scale": 1.0},
		{"rotation_offset": 0.08, "scale": 1.06},
		{"rotation_offset": -0.04, "scale": 1.12},
		{"rotation_offset": 0.12, "scale": 1.18},
	]


func _get_slash_step_damage(step_count: int) -> int:
	if step_count >= 3:
		return maxi(1, int(round(float(slash_damage) * 0.48)))
	if step_count == 2:
		return maxi(1, int(round(float(slash_damage) * 0.65)))
	return slash_damage


func _get_sword_wave_cooldown() -> float:
	return sword_wave_enhanced_cooldown if sword_wave_enhanced else sword_wave_cooldown


func _get_dash_cooldown() -> float:
	return dash_cooldown * (execution_dash_cooldown_multiplier if _is_execution_mode_active() else 1.0)


func _recharge_dash(delta: float) -> void:
	if dash_charges >= dash_max_charges:
		dash_timer = 0.0
		return
	dash_timer = maxf(0.0, dash_timer - delta)
	if dash_timer <= 0.0:
		dash_charges = mini(dash_max_charges, dash_charges + 1)
		if dash_charges < dash_max_charges:
			dash_timer = _get_dash_cooldown()


func _recharge_sword_wave(delta: float) -> void:
	if sword_wave_charges >= sword_wave_max_charges:
		sword_wave_timer = 0.0
		return
	sword_wave_timer = maxf(0.0, sword_wave_timer - delta)
	if sword_wave_timer <= 0.0:
		sword_wave_charges = mini(sword_wave_max_charges, sword_wave_charges + 1)
		if sword_wave_charges < sword_wave_max_charges:
			sword_wave_timer = _get_sword_wave_cooldown()


func _update_dash_charge_capacity() -> void:
	var next_max := 1
	if dash_cooldown_level >= 5:
		next_max = 3
	elif dash_cooldown_level >= 3:
		next_max = 2
	if next_max != dash_max_charges:
		dash_max_charges = next_max
		dash_charges = mini(dash_max_charges, dash_charges + 1)


func _get_sword_wave_speed_multiplier() -> float:
	return clampf(0.62 / slash_cooldown, 1.0, 1.8)


func _find_slash_targets(direction: Vector2) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var forward := direction.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.DOWN

	var half_arc := deg_to_rad(slash_arc_degrees) * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue

		var offset: Vector2 = enemy_node.global_position - player.global_position
		var distance := offset.length()
		if distance > slash_range:
			continue
		if distance > 0.0 and absf(forward.angle_to(offset.normalized())) > half_arc:
			continue
		if enemy.has_method("take_damage"):
			targets.append(enemy_node)

	return targets


func _find_execution_slash_targets(direction: Vector2) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var forward := direction.normalized()
	if forward == Vector2.ZERO:
		forward = player.last_attack_direction.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.DOWN

	var half_arc := deg_to_rad(execution_slash_arc_degrees) * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue

		var offset: Vector2 = enemy_node.global_position - player.global_position
		var distance := offset.length()
		if distance > execution_slash_range:
			continue
		if distance > 0.0 and absf(forward.angle_to(offset.normalized())) > half_arc:
			continue
		if enemy.has_method("take_damage"):
			targets.append(enemy_node)

	return targets


func _spawn_slash_vfx(direction: Vector2, texture_path := "", rotation_offset := 0.0, scale_multiplier := 1.0, alpha := 0.92) -> void:
	if _is_execution_mode_active():
		_spawn_execution_slash_vfx(direction, rotation_offset, scale_multiplier)
		return

	var vfx_parent := make_world_vfx_group()
	var active_texture_path := slash_vfx_texture_path if texture_path.is_empty() else texture_path
	var slash_texture := load(active_texture_path) as Texture2D
	if slash_texture != null:
		var slash_sprite := Sprite2D.new()
		slash_sprite.texture = slash_texture
		slash_sprite.centered = true
		slash_sprite.global_position = player.global_position
		slash_sprite.rotation = direction.angle() + rotation_offset
		slash_sprite.scale = Vector2.ONE * (slash_visual_radius / 240.0) * scale_multiplier
		slash_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
		slash_sprite.z_index = 22
		vfx_parent.add_child(slash_sprite)

		var sprite_tween := create_tween()
		sprite_tween.set_parallel(true)
		sprite_tween.tween_property(slash_sprite, "scale", slash_sprite.scale * 1.08, 0.18)
		sprite_tween.tween_property(slash_sprite, "modulate:a", 0.0, 0.22)
		sprite_tween.finished.connect(slash_sprite.queue_free)
		emit_world_vfx(vfx_parent)
		return

	var start_angle := direction.angle() - PI * 0.34
	var end_angle := direction.angle() + PI * 0.34
	var arc := Line2D.new()
	arc.width = 8.0
	arc.default_color = Color(1.0, 0.18, 0.14, 0.86)
	arc.z_index = 22
	for index in range(14):
		var t := float(index) / 13.0
		var angle := lerpf(start_angle, end_angle, t)
		arc.add_point(player.global_position + Vector2.RIGHT.rotated(angle) * (52.0 + t * 42.0))
	vfx_parent.add_child(arc)

	var tween := create_tween()
	tween.tween_property(arc, "modulate:a", 0.0, 0.22)
	tween.finished.connect(arc.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_dash_vfx(start_position: Vector2, end_position: Vector2) -> void:
	if dash_vfx_material == null:
		_spawn_dash_fallback_vfx(start_position, end_position)
		return

	var vfx_parent := make_world_vfx_group()
	var direction := end_position - start_position
	var distance := direction.length()
	var angle := direction.angle() if distance > 0.01 else 0.0
	var midpoint := start_position + direction * 0.5
	var normal := Vector2.UP.rotated(angle) if distance > 0.01 else Vector2.UP
	var path_scale_x := clampf((distance + 190.0) / 512.0, 0.78, 1.55)
	if _is_execution_mode_active():
		_spawn_execution_dash_vfx(start_position, end_position)
		return

	var path_scale_y := dash_vfx_scale * 0.96
	var dash_vfx_tier := 1
	if dash_path_damage_unlocked:
		dash_vfx_tier = 2
	if dash_spinning_arrival_unlocked:
		dash_vfx_tier = 3

	_spawn_dash_sheet_vfx(vfx_parent, DASH_BASIC_VFX_TEXTURE, 0, 2, start_position, dash_vfx_scale * (1.35 + 0.12 * float(dash_vfx_tier - 1)), 0.22, 22)

	var trail := _make_dash_sheet_sprite(DASH_BASIC_VFX_TEXTURE, 1, 2, midpoint, dash_vfx_scale, 20)
	trail.rotation = angle
	trail.scale = Vector2(path_scale_x, path_scale_y * (1.0 + 0.12 * float(dash_vfx_tier - 1)))
	trail.modulate = Color(1.35 + 0.08 * float(dash_vfx_tier - 1), 1.18, 1.18, 1.0)
	vfx_parent.add_child(trail)

	var cut_shadow := _spawn_dash_cut_line(vfx_parent, start_position, end_position, 10.0, Color(1.0, 0.05, 0.02, 0.55), 0.20, 18)
	var cut_core := _spawn_dash_cut_line(vfx_parent, start_position, end_position, 3.0, Color(1.0, 0.92, 0.86, 0.92), 0.14, 24)
	var extra_cuts: Array[Line2D] = []
	var extra_sprites: Array[Sprite2D] = []

	var residue := _make_dash_sheet_sprite(DASH_BASIC_VFX_TEXTURE, 3, 0, midpoint, dash_vfx_scale, 14)
	residue.rotation = angle
	residue.scale = Vector2(clampf((distance + 120.0) / 512.0, 0.65, 1.35), dash_vfx_scale * 0.62)
	residue.modulate = Color(1.2, 0.82, 0.82, 0.82)
	vfx_parent.add_child(residue)

	if dash_path_damage_unlocked:
		var sharp_accent := _make_dash_sheet_sprite(DASH_PATH_DAMAGE_VFX_TEXTURE, 3, 2, midpoint, dash_vfx_scale, 21)
		sharp_accent.rotation = angle
		sharp_accent.scale = Vector2(clampf((distance + 110.0) / 512.0, 0.72, 1.32), dash_vfx_scale * 0.62)
		sharp_accent.modulate = Color(1.35, 0.86, 0.78, 0.86)
		vfx_parent.add_child(sharp_accent)
		extra_sprites.append(sharp_accent)

		var thin_accent := _make_dash_sheet_sprite(DASH_PATH_DAMAGE_VFX_TEXTURE, 1, 1, midpoint + normal * 5.0, dash_vfx_scale, 22)
		thin_accent.rotation = angle
		thin_accent.scale = Vector2(clampf((distance + 70.0) / 512.0, 0.64, 1.18), dash_vfx_scale * 0.36)
		thin_accent.modulate = Color(1.18, 0.62, 0.56, 0.62)
		vfx_parent.add_child(thin_accent)
		extra_sprites.append(thin_accent)

		var offset := normal * 9.0
		extra_cuts.append(_spawn_dash_cut_line(vfx_parent, start_position + offset, end_position + offset, 2.6, Color(1.0, 0.26, 0.16, 0.78), 0.18, 23))
		extra_cuts.append(_spawn_dash_cut_line(vfx_parent, start_position - offset * 0.72, end_position - offset * 0.72, 1.8, Color(0.16, 0.0, 0.0, 0.78), 0.22, 17))
		extra_cuts.append(_spawn_dash_cut_line(vfx_parent, start_position + direction * 0.08 - normal * 3.0, end_position - direction * 0.06 - normal * 3.0, 1.2, Color(1.0, 0.95, 0.86, 0.72), 0.13, 25))
		_spawn_dash_sheet_vfx(vfx_parent, DASH_PATH_DAMAGE_VFX_TEXTURE, 2, 1, end_position, dash_vfx_scale * 1.12, 0.26, 23, Color(1.24, 0.86, 0.82, 0.82))

		if dash_vfx_tier >= 3:
			var upper_offset := normal * 18.0
			var lower_offset := -normal * 17.0
			extra_cuts.append(_spawn_dash_cut_line(vfx_parent, start_position + direction * 0.02 + upper_offset, end_position - direction * 0.08 + upper_offset, 2.0, Color(1.0, 0.16, 0.1, 0.74), 0.2, 24))
			extra_cuts.append(_spawn_dash_cut_line(vfx_parent, start_position + direction * 0.12 + lower_offset, end_position - direction * 0.02 + lower_offset, 1.6, Color(1.0, 0.86, 0.76, 0.58), 0.16, 26))
			extra_cuts.append(_spawn_dash_cut_line(vfx_parent, start_position + direction * 0.18, end_position - direction * 0.18, 5.2, Color(0.42, 0.0, 0.0, 0.46), 0.28, 16))

			var finisher_trail := _make_dash_sheet_sprite(DASH_SPINNING_ARRIVAL_VFX_TEXTURE, 1, 0, midpoint - normal * 8.0, dash_vfx_scale, 23)
			finisher_trail.rotation = angle
			finisher_trail.scale = Vector2(clampf((distance + 130.0) / 512.0, 0.78, 1.42), dash_vfx_scale * 0.58)
			finisher_trail.modulate = Color(1.18, 0.72, 0.68, 0.68)
			vfx_parent.add_child(finisher_trail)
			extra_sprites.append(finisher_trail)

			var first_cross_center := start_position + direction * 0.34
			var second_cross_center := start_position + direction * 0.68
			extra_cuts.append(_spawn_dash_cut_line(vfx_parent, first_cross_center - normal * 32.0 - direction.normalized() * 20.0, first_cross_center + normal * 32.0 + direction.normalized() * 20.0, 1.8, Color(1.0, 0.38, 0.24, 0.62), 0.18, 25))
			extra_cuts.append(_spawn_dash_cut_line(vfx_parent, second_cross_center + normal * 30.0 - direction.normalized() * 18.0, second_cross_center - normal * 30.0 + direction.normalized() * 18.0, 1.5, Color(1.0, 0.9, 0.82, 0.5), 0.16, 26))
	else:
		_spawn_dash_sheet_vfx(vfx_parent, DASH_BASIC_VFX_TEXTURE, 2, 1, end_position, dash_vfx_scale * 1.42, 0.28, 23)

	_spawn_dash_vfx_ring(vfx_parent, end_position, 24.0 + 4.0 * float(dash_vfx_tier - 1), 2.1 + 0.18 * float(dash_vfx_tier - 1), 0.22, Color(1.0, 0.62, 0.5, 0.58), 3.2, 25)

	_spawn_dash_arrival_spin_vfx(vfx_parent, end_position)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.24)
	tween.tween_property(trail, "scale", trail.scale * Vector2(1.08, 0.62), 0.24)
	tween.tween_property(residue, "modulate:a", 0.0, 0.32 if dash_path_damage_unlocked else 0.28)
	tween.tween_property(residue, "scale", residue.scale * Vector2(1.04, 0.72), 0.32 if dash_path_damage_unlocked else 0.28)
	tween.finished.connect(trail.queue_free)
	tween.finished.connect(residue.queue_free)
	tween.finished.connect(cut_shadow.queue_free)
	tween.finished.connect(cut_core.queue_free)
	for extra_sprite in extra_sprites:
		tween.tween_property(extra_sprite, "modulate:a", 0.0, 0.3 if dash_vfx_tier >= 3 else 0.26)
		tween.tween_property(extra_sprite, "scale", extra_sprite.scale * Vector2(1.06, 0.66), 0.3 if dash_vfx_tier >= 3 else 0.26)
		tween.finished.connect(extra_sprite.queue_free)
	for extra_cut in extra_cuts:
		tween.finished.connect(extra_cut.queue_free)
	emit_world_vfx(vfx_parent)




func _spawn_execution_slash_vfx(direction: Vector2, rotation_offset := 0.0, scale_multiplier := 1.0) -> void:
	var vfx_parent := make_world_vfx_group()
	var slash_direction := direction.normalized()
	if slash_direction == Vector2.ZERO:
		slash_direction = player.last_attack_direction.normalized()
	if slash_direction == Vector2.ZERO:
		slash_direction = Vector2.RIGHT

	var base_angle := slash_direction.angle() + rotation_offset
	var main_slash := Sprite2D.new()
	main_slash.texture = EXECUTION_SLASH_MAIN_TEXTURE
	main_slash.centered = true
	main_slash.global_position = player.global_position + slash_direction * 36.0
	main_slash.rotation = base_angle
	main_slash.scale = Vector2.ONE * (slash_visual_radius / 420.0) * scale_multiplier
	main_slash.modulate = Color(1.25, 0.95, 0.9, 0.92)
	main_slash.material = dash_vfx_material
	main_slash.z_index = 32
	vfx_parent.add_child(main_slash)

	var accent_columns := [0, 1, 2]
	for index in range(accent_columns.size()):
		var column := int(accent_columns[(execution_slash_cell_index + index) % accent_columns.size()])
		var accent := _make_dash_sheet_sprite(EXECUTION_SLASH_VFX_TEXTURE, 2, column, player.global_position + slash_direction * (24.0 + 10.0 * float(index)), dash_vfx_scale * (1.42 + 0.18 * float(index)) * scale_multiplier, 33 + index)
		accent.rotation = base_angle + randf_range(-0.1, 0.1)
		accent.modulate = Color(1.25, 0.74, 0.68, 0.72 - 0.1 * float(index))
		vfx_parent.add_child(accent)

		var accent_tween := create_tween()
		accent_tween.set_parallel(true)
		accent_tween.tween_property(accent, "scale", accent.scale * Vector2(1.1, 0.76), 0.18 + 0.03 * float(index))
		accent_tween.tween_property(accent, "modulate:a", 0.0, 0.18 + 0.03 * float(index))
		accent_tween.finished.connect(accent.queue_free)
	execution_slash_cell_index = (execution_slash_cell_index + 1) % 3

	var main_tween := create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(main_slash, "scale", main_slash.scale * Vector2(1.08, 0.82), 0.24)
	main_tween.tween_property(main_slash, "modulate:a", 0.0, 0.26)
	main_tween.finished.connect(main_slash.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_execution_dash_vfx(start_position: Vector2, end_position: Vector2) -> void:
	var vfx_parent := make_world_vfx_group()
	var direction := end_position - start_position
	var distance := direction.length()
	var angle := direction.angle() if distance > 0.01 else 0.0
	var midpoint := start_position + direction * 0.5
	var normal := Vector2.UP.rotated(angle) if distance > 0.01 else Vector2.UP
	var cell_width := float(EXECUTION_DASH_VFX_TEXTURE.get_width()) / float(DASH_VFX_COLUMNS)
	var path_scale_x := clampf((distance + 220.0) / cell_width, 0.95, 2.45)

	_spawn_dash_sheet_vfx(vfx_parent, EXECUTION_DASH_VFX_TEXTURE, 0, 0, start_position, dash_vfx_scale * 1.45, 0.22, 26, Color(1.28, 0.72, 0.68, 0.82))
	_spawn_dash_sheet_vfx(vfx_parent, EXECUTION_DASH_VFX_TEXTURE, 0, 2, end_position, dash_vfx_scale * 1.35, 0.22, 26, Color(1.12, 0.62, 0.58, 0.68))

	var trail_column := randi() % 4
	var trail := _make_dash_sheet_sprite(EXECUTION_DASH_VFX_TEXTURE, 2, trail_column, midpoint, dash_vfx_scale, 25)
	trail.rotation = angle
	trail.scale = Vector2(path_scale_x, dash_vfx_scale * 0.88)
	trail.modulate = Color(1.36, 0.82, 0.76, 0.9)
	vfx_parent.add_child(trail)

	var shadow_trail := _make_dash_sheet_sprite(EXECUTION_DASH_VFX_TEXTURE, 2, (trail_column + 1) % 4, midpoint - normal * 7.0, dash_vfx_scale, 24)
	shadow_trail.rotation = angle
	shadow_trail.scale = Vector2(path_scale_x * 0.92, dash_vfx_scale * 0.58)
	shadow_trail.modulate = Color(0.8, 0.18, 0.14, 0.5)
	vfx_parent.add_child(shadow_trail)

	var cut_core := _spawn_dash_cut_line(vfx_parent, start_position, end_position, 3.0, Color(1.0, 0.92, 0.86, 0.95), 0.13, 30)
	var cut_shadow := _spawn_dash_cut_line(vfx_parent, start_position + normal * 10.0, end_position + normal * 10.0, 2.0, Color(1.0, 0.12, 0.08, 0.78), 0.19, 28)
	var cut_black := _spawn_dash_cut_line(vfx_parent, start_position - normal * 12.0, end_position - normal * 12.0, 5.0, Color(0.22, 0.0, 0.0, 0.58), 0.24, 22)

	_spawn_dash_sheet_vfx(vfx_parent, EXECUTION_DASH_VFX_TEXTURE, 3, 1, end_position, dash_vfx_scale * 1.28, 0.28, 29, Color(1.18, 0.62, 0.58, 0.72))
	_spawn_dash_arrival_spin_vfx(vfx_parent, end_position)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.28)
	tween.tween_property(trail, "scale", trail.scale * Vector2(1.04, 0.64), 0.28)
	tween.tween_property(shadow_trail, "modulate:a", 0.0, 0.34)
	tween.tween_property(shadow_trail, "scale", shadow_trail.scale * Vector2(1.02, 0.58), 0.34)
	tween.finished.connect(trail.queue_free)
	tween.finished.connect(shadow_trail.queue_free)
	tween.finished.connect(cut_core.queue_free)
	tween.finished.connect(cut_shadow.queue_free)
	tween.finished.connect(cut_black.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_dash_arrival_spin_vfx(vfx_parent: Node, end_position: Vector2) -> void:
	if not dash_spinning_arrival_unlocked:
		return

	var spin_level := 3
	var spin_scale := dash_vfx_scale * (2.35 + 0.55 * float(spin_level - 1))
	var spin_duration := 0.38 + 0.08 * float(spin_level - 1)
	var spin_ring_radius := 58.0 + 18.0 * float(spin_level - 1)
	if spin_level >= 3:
		spin_scale = dash_vfx_scale * 4.85
		spin_duration = 0.62
		spin_ring_radius = 118.0
	_spawn_dash_sheet_vfx(vfx_parent, DASH_SPINNING_ARRIVAL_VFX_TEXTURE, 2, 2, end_position, spin_scale, spin_duration, 30, Color(1.18, 0.9, 0.86, 1.0))
	if spin_level >= 2:
		var secondary_spin_scale := dash_vfx_scale * (1.7 + 0.35 * float(spin_level - 2))
		var secondary_spin_alpha := 0.62
		if spin_level >= 3:
			secondary_spin_scale = dash_vfx_scale * 3.45
			secondary_spin_alpha = 0.78
		_spawn_dash_sheet_vfx(vfx_parent, DASH_SPINNING_ARRIVAL_VFX_TEXTURE, 1, 0, end_position, secondary_spin_scale, 0.34 + 0.08 * float(spin_level - 2), 28, Color(1.0, 0.72, 0.66, secondary_spin_alpha))
	if spin_level >= 3:
		_spawn_dash_sheet_vfx(vfx_parent, DASH_SPINNING_ARRIVAL_VFX_TEXTURE, 3, 2, end_position, dash_vfx_scale * 3.55, 0.56, 27, Color(1.0, 0.55, 0.48, 0.62))
		_spawn_dash_vfx_ring(vfx_parent, end_position, spin_ring_radius * 0.72, 2.35, 0.32, Color(1.0, 0.4, 0.32, 0.34), 2.6, 26)
		_spawn_dash_vfx_ring(vfx_parent, end_position, spin_ring_radius * 1.08, 2.55, 0.42, Color(1.0, 0.82, 0.72, 0.34), 3.2, 27)
	_spawn_dash_vfx_ring(vfx_parent, end_position, spin_ring_radius, 1.9 + 0.18 * float(spin_level - 1), 0.34 + 0.06 * float(spin_level - 1), Color(1.0, 0.72, 0.64, 0.42), 3.0, 26)


func _spawn_dash_cut_line(vfx_parent: Node, start_position: Vector2, end_position: Vector2, width: float, color: Color, duration: float, z_index: int) -> Line2D:
	var cut := Line2D.new()
	cut.width = width
	cut.default_color = color
	cut.z_index = z_index
	cut.points = PackedVector2Array([start_position, end_position])
	vfx_parent.add_child(cut)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(cut, "width", maxf(1.0, width * 0.25), duration)
	tween.tween_property(cut, "modulate:a", 0.0, duration)
	return cut


func _spawn_dash_fallback_vfx(start_position: Vector2, end_position: Vector2) -> void:
	var vfx_parent := make_world_vfx_group()
	var trail := Line2D.new()
	trail.width = 7.0
	trail.default_color = Color(1.0, 0.22, 0.16, 0.72)
	trail.z_index = 20
	trail.points = PackedVector2Array([start_position, end_position])
	vfx_parent.add_child(trail)

	var ring := Line2D.new()
	ring.width = 3.0
	ring.closed = true
	ring.default_color = Color(1.0, 0.45, 0.35, 0.72)
	ring.points = make_circle_points(18.0, 32)
	ring.global_position = end_position
	ring.z_index = 21
	vfx_parent.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.22)
	tween.tween_property(trail, "width", 1.0, 0.22)
	tween.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.22)
	tween.tween_property(ring, "modulate:a", 0.0, 0.22)
	tween.finished.connect(trail.queue_free)
	tween.finished.connect(ring.queue_free)
	emit_world_vfx(vfx_parent)


func _apply_dash_path_damage(start_position: Vector2, end_position: Vector2) -> Array[Node2D]:
	var hit_targets: Array[Node2D] = []
	if not dash_path_damage_unlocked:
		return hit_targets

	var final_damage := _get_modified_attack_damage(dash_path_damage)
	for enemy in _find_dash_path_targets(start_position, end_position):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, "skill")
			hit_targets.append(enemy)
			_spawn_dash_hit_vfx(enemy.global_position, true)
	return hit_targets


func _get_dash_arrival_spin_radius() -> float:
	return 280.0 if dash_spinning_arrival_unlocked else 0.0


func _apply_dash_arrival_spin_damage(world_position: Vector2, already_hit: Array[Node2D]) -> void:
	var final_damage := _get_modified_attack_damage(dash_arrival_spin_damage)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		if enemy_node.global_position.distance_to(world_position) > _get_dash_arrival_spin_radius():
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, "skill")
		if not already_hit.has(enemy_node):
			_spawn_dash_hit_vfx(enemy_node.global_position, false)


func _find_dash_path_targets(start_position: Vector2, end_position: Vector2) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var path := end_position - start_position
	var path_length_squared := path.length_squared()
	if path_length_squared <= 0.01:
		return targets

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue

		var to_enemy := enemy_node.global_position - start_position
		var t := clampf(to_enemy.dot(path) / path_length_squared, 0.0, 1.0)
		var closest_point := start_position + path * t
		if enemy_node.global_position.distance_to(closest_point) <= dash_path_damage_width:
			targets.append(enemy_node)
	return targets


func _spawn_dash_hit_vfx(world_position: Vector2, enhanced: bool) -> void:
	if dash_vfx_material == null:
		return

	var vfx_parent := make_world_vfx_group()
	var texture := DASH_PATH_DAMAGE_VFX_TEXTURE if enhanced else DASH_BASIC_VFX_TEXTURE
	var row := 2
	var column := 1 if enhanced else 2
	var hit := _make_dash_sheet_sprite(texture, row, column, world_position + Vector2(0, -12), dash_hit_vfx_scale * (1.15 if enhanced else 1.0), 28)
	hit.rotation = randf_range(-0.35, 0.35)
	vfx_parent.add_child(hit)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(hit, "scale", hit.scale * 1.22, 0.24 if enhanced else 0.18)
	tween.tween_property(hit, "modulate:a", 0.0, 0.24 if enhanced else 0.18)
	tween.finished.connect(hit.queue_free)
	emit_world_vfx(vfx_parent, 0.5)


func _apply_parry_counter() -> void:
	var direction: Vector2 = parry_direction.normalized()
	if direction == Vector2.ZERO:
		direction = player.last_attack_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	var final_damage := _get_modified_attack_damage(parry_counter_damage)
	if parry_spin_counter_unlocked:
		apply_area_damage(player.global_position, parry_counter_range * 0.82, final_damage, "skill")
		_spawn_parry_spin_vfx()
		return

	var half_arc := deg_to_rad(42.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var offset: Vector2 = enemy_node.global_position - player.global_position
		if offset.length() > parry_counter_range:
			continue
		if offset.length() > 0.0 and absf(direction.angle_to(offset.normalized())) > half_arc:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, "skill")
	_spawn_parry_thrust_vfx(direction)


func _spawn_parry_thrust_vfx(direction: Vector2) -> void:
	var vfx_parent := make_world_vfx_group()
	var start: Vector2 = player.global_position + direction * 16.0
	var end: Vector2 = player.global_position + direction * parry_counter_range
	var normal: Vector2 = direction.rotated(PI * 0.5)
	var cut := _spawn_dash_cut_line(vfx_parent, start, end, 7.0, Color(1.0, 0.92, 0.62, 0.92), 0.18, 31)
	var shadow := _spawn_dash_cut_line(vfx_parent, start - normal * 10.0, end - normal * 10.0, 4.0, Color(1.0, 0.22, 0.12, 0.7), 0.2, 30)
	var tween := create_tween()
	tween.finished.connect(cut.queue_free)
	tween.finished.connect(shadow.queue_free)
	emit_world_vfx(vfx_parent, 0.4)


func _spawn_parry_spin_vfx() -> void:
	var vfx_parent := make_world_vfx_group()
	_spawn_dash_vfx_ring(vfx_parent, player.global_position, parry_counter_range * 0.42, 2.2, 0.28, Color(1.0, 0.72, 0.36, 0.58), 5.0, 31)
	_spawn_dash_vfx_ring(vfx_parent, player.global_position, parry_counter_range * 0.28, 2.0, 0.22, Color(1.0, 0.18, 0.12, 0.5), 8.0, 30)
	emit_world_vfx(vfx_parent, 0.55)


func _spawn_guard_vfx() -> void:
	var vfx_parent := make_world_vfx_group()
	var ring := Line2D.new()
	ring.width = 5.0
	ring.closed = true
	ring.default_color = Color(1.0, 0.34, 0.25, 0.76)
	ring.points = make_circle_points(58.0, 48)
	ring.global_position = player.global_position
	ring.z_index = 20
	vfx_parent.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.35, 0.22)
	tween.tween_property(ring, "modulate:a", 0.0, 0.22)
	tween.finished.connect(ring.queue_free)
	emit_world_vfx(vfx_parent)


func _spawn_guard_block_vfx() -> void:
	var vfx_parent := make_world_vfx_group()
	var spark := Line2D.new()
	spark.width = 4.0
	spark.default_color = Color(1.0, 0.85, 0.55, 0.9)
	spark.z_index = 23
	var center: Vector2 = player.global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-34.0, 8.0))
	spark.points = PackedVector2Array([center + Vector2(-18, 0), center + Vector2(18, 0)])
	vfx_parent.add_child(spark)

	var tween := create_tween()
	tween.tween_property(spark, "modulate:a", 0.0, 0.14)
	tween.finished.connect(spark.queue_free)
	emit_world_vfx(vfx_parent)


func _start_ultimate_aura() -> void:
	if player == null:
		return
	_stop_ultimate_aura()
	_ensure_ultimate_vfx_material()
	ultimate_aura_sprite = Sprite2D.new()
	ultimate_aura_sprite.texture = ULTIMATE_AURA_LOOP_TEXTURE
	ultimate_aura_sprite.region_enabled = true
	ultimate_aura_sprite.region_rect = Rect2(Vector2.ZERO, Vector2(256.0, 256.0))
	ultimate_aura_sprite.centered = true
	ultimate_aura_sprite.position = Vector2(0.0, -34.0)
	ultimate_aura_sprite.scale = Vector2.ONE * 1.18
	ultimate_aura_sprite.modulate = Color(1.0, 0.88, 0.82, 0.62)
	ultimate_aura_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ultimate_aura_sprite.material = ultimate_vfx_material
	ultimate_aura_sprite.z_index = 31
	player.add_child(ultimate_aura_sprite)
	ultimate_aura_animation_time = 0.0


func _stop_ultimate_aura() -> void:
	if ultimate_aura_sprite != null and is_instance_valid(ultimate_aura_sprite):
		ultimate_aura_sprite.queue_free()
	ultimate_aura_sprite = null


func _update_ultimate_aura(delta: float) -> void:
	if not _is_execution_mode_active():
		_stop_ultimate_aura()
		return
	if ultimate_aura_sprite == null or not is_instance_valid(ultimate_aura_sprite):
		return
	ultimate_aura_animation_time += delta
	var frame := int(ultimate_aura_animation_time * 14.0) % 16
	ultimate_aura_sprite.region_rect = _make_ultimate_sheet_region(ULTIMATE_AURA_LOOP_TEXTURE, frame)
	var pulse := 0.96 + sin(ultimate_aura_animation_time * TAU * 1.45) * 0.035
	ultimate_aura_sprite.scale = Vector2.ONE * 1.18 * pulse


func _play_ultimate_blast_sequence(center: Vector2) -> void:
	_spawn_ultimate_sheet_vfx(ULTIMATE_BLAST_CHARGE_TEXTURE, center, 1.25, 0.18, 84)
	await get_tree().create_timer(0.14).timeout
	if player == null or not is_instance_valid(player):
		return
	apply_area_damage(center, 360.0, 90, "ultimate")
	_spawn_ultimate_sheet_vfx(ULTIMATE_BLAST_IMPACT_TEXTURE, center, 2.35, 0.34, 88)


func _spawn_ultimate_sheet_vfx(texture: Texture2D, world_position: Vector2, scale_amount: float, duration: float, z_index: int) -> void:
	if texture == null:
		return
	_ensure_ultimate_vfx_material()
	var vfx_parent := make_world_vfx_group()
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = _make_ultimate_sheet_region(texture, 0)
	sprite.centered = true
	sprite.global_position = world_position + Vector2(0.0, -18.0)
	sprite.scale = Vector2.ONE * scale_amount
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = ultimate_vfx_material
	sprite.z_index = z_index
	vfx_parent.add_child(sprite)
	emit_world_vfx(vfx_parent, duration + 0.25)
	_animate_ultimate_sheet_vfx(sprite, texture, duration)


func _animate_ultimate_sheet_vfx(sprite: Sprite2D, texture: Texture2D, duration: float) -> void:
	var frame_time := maxf(0.02, duration / 16.0)
	for frame in range(16):
		if not is_instance_valid(sprite):
			return
		sprite.region_rect = _make_ultimate_sheet_region(texture, frame)
		await get_tree().create_timer(frame_time).timeout
	if is_instance_valid(sprite):
		sprite.queue_free()


func _make_ultimate_sheet_region(texture: Texture2D, frame: int) -> Rect2:
	var columns := 4
	var frame_size := Vector2(float(texture.get_width()) / float(columns), float(texture.get_height()) / 4.0)
	var column := frame % columns
	var row := int(frame / columns)
	return Rect2(Vector2(column, row) * frame_size, frame_size)


func _ensure_ultimate_vfx_material() -> void:
	if ultimate_vfx_material != null:
		return
	ultimate_vfx_material = CanvasItemMaterial.new()
	ultimate_vfx_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _load_sfx() -> void:
	dash_sfx = load(DASH_SFX_PATH) as AudioStream
	basic_slash_sfx = load(BASIC_SLASH_SFX_PATH) as AudioStream
	basic_slash_level_2_sfx = load(BASIC_SLASH_LEVEL_2_SFX_PATH) as AudioStream
	basic_slash_level_3_sfx_pool = _load_sfx_pool(BASIC_SLASH_LEVEL_3_SFX_PATHS)
	ultimate_basic_slash_sfx_pool = _load_sfx_pool(ULTIMATE_BASIC_SLASH_SFX_PATHS)
	sword_wave_sfx = load(SWORD_WAVE_SFX_PATH) as AudioStream


func _load_sfx_pool(paths: Array) -> Array[AudioStream]:
	var pool: Array[AudioStream] = []
	for path in paths:
		var stream := load(str(path)) as AudioStream
		if stream != null:
			pool.append(stream)
	return pool


func _play_basic_slash_sfx(step_index := 0, step_count := 1) -> void:
	var multi_hit_volume_offset := -1.4 if step_count >= 3 else (-0.9 if step_count == 2 else 0.0)
	if _is_execution_mode_active():
		_play_sfx(_pick_sfx(ultimate_basic_slash_sfx_pool, basic_slash_sfx), -9.6 + multi_hit_volume_offset, 0.99 + 0.01 * float(step_index), 1.08 + 0.01 * float(step_index))
		return

	if slash_form_level <= 1:
		_play_sfx(basic_slash_sfx, -10.0 + multi_hit_volume_offset, 0.98, 1.06)
	elif slash_form_level == 2:
		_play_sfx(basic_slash_level_2_sfx, -10.0 + multi_hit_volume_offset, 0.98, 1.06)
	else:
		_play_sfx(_pick_sfx(basic_slash_level_3_sfx_pool, basic_slash_level_2_sfx), -9.8 + multi_hit_volume_offset, 0.98 + 0.01 * float(step_index), 1.07 + 0.01 * float(step_index))


func _pick_sfx(pool: Array[AudioStream], fallback: AudioStream) -> AudioStream:
	if pool.is_empty():
		return fallback
	return pool[randi() % pool.size()]


func _play_sfx(stream: AudioStream, volume_db := -8.0, min_pitch := 1.0, max_pitch := 1.0) -> void:
	if stream == null or player == null:
		return

	var audio := AudioStreamPlayer2D.new()
	audio.stream = stream
	if AudioServer.get_bus_index(SFX_BUS_NAME) != -1:
		audio.bus = SFX_BUS_NAME
	audio.volume_db = volume_db
	audio.pitch_scale = randf_range(min_pitch, max_pitch)
	audio.max_distance = 1200.0
	audio.attenuation = 0.2
	player.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


func _emit_status() -> void:
	var texts := get_status_texts()
	status_changed.emit(texts[0], texts[1], texts[2])


func find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance := INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue

		var distance: float = player.global_position.distance_squared_to(enemy_node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy_node

	return nearest_enemy


func apply_area_damage(world_position: Vector2, radius: float, damage: int, source := "skill") -> void:
	var final_damage := _get_modified_attack_damage(damage)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		if enemy_node.global_position.distance_to(world_position) > radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, source)


func _get_modified_attack_damage(base_damage: int) -> int:
	if player != null and player.has_method("get_modified_attack_damage"):
		return player.get_modified_attack_damage(base_damage)
	return base_damage


func _get_basic_attack_cooldown(base_cooldown: float) -> float:
	if player != null and player.has_method("get_basic_attack_cooldown"):
		return player.get_basic_attack_cooldown(base_cooldown)
	return base_cooldown



func _spawn_dash_vfx_ring(vfx_parent: Node, world_position: Vector2, radius: float, target_scale: float, duration: float, color: Color, width: float, z_index: int) -> Line2D:
	var ring := Line2D.new()
	ring.width = width
	ring.closed = true
	ring.z_index = z_index
	ring.default_color = color
	ring.points = make_circle_points(radius, 48)
	ring.global_position = world_position
	vfx_parent.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * target_scale, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.finished.connect(ring.queue_free)
	return ring


func _spawn_dash_sheet_vfx(vfx_parent: Node, texture: Texture2D, row: int, column: int, world_position: Vector2, scale_amount: float, duration: float, z_index: int, modulate_color := Color.WHITE) -> Sprite2D:
	var vfx := _make_dash_sheet_sprite(texture, row, column, world_position, scale_amount, z_index)
	vfx.modulate = modulate_color
	vfx_parent.add_child(vfx)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(vfx, "scale", vfx.scale * 1.18, duration)
	tween.tween_property(vfx, "modulate:a", 0.0, duration)
	tween.finished.connect(vfx.queue_free)
	return vfx


func _make_dash_sheet_sprite(texture: Texture2D, row: int, column: int, world_position: Vector2, scale_amount: float, z_index: int) -> Sprite2D:
	var vfx := Sprite2D.new()
	vfx.texture = texture
	vfx.region_enabled = true
	vfx.region_rect = _make_dash_vfx_region(texture, row, column)
	vfx.material = dash_vfx_material
	vfx.global_position = world_position
	vfx.scale = Vector2.ONE * scale_amount
	vfx.z_index = z_index
	return vfx


func _make_dash_vfx_region(texture: Texture2D, row: int, column: int) -> Rect2:
	var cell_size := Vector2(
		float(texture.get_width()) / float(DASH_VFX_COLUMNS),
		float(texture.get_height()) / float(DASH_VFX_ROWS)
	)
	return Rect2(cell_size * Vector2(column, row), cell_size)


func _build_dash_vfx_material() -> void:
	dash_vfx_material = CanvasItemMaterial.new()
	dash_vfx_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func make_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func make_world_vfx_group() -> Node2D:
	return Node2D.new()


func emit_world_vfx(vfx: Node2D, lifetime := 2.0) -> void:
	world_vfx_requested.emit(vfx)
	get_tree().create_timer(lifetime).timeout.connect(vfx.queue_free)
