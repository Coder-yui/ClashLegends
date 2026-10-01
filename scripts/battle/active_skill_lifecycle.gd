class_name ActiveSkillLifecycle
extends RefCounted
## 协调 Cast Start、动作锁、独立结果和后段排程。资格与付款由请求入口管理。
## CommandSchedule 按身份推进结束/取消；Unit 汇合动作权限，不由视觉计时决定完成。
var _effects: ActiveSkillEffectSystem
var _presentation: SkillEffectPresentation
var _commands: CommandSchedule
var _combat: CombatResolver

func _init(effects: ActiveSkillEffectSystem, presentation: SkillEffectPresentation, commands: CommandSchedule, combat: CombatResolver) -> void:
	_effects = effects
	_presentation = presentation
	_commands = commands
	_combat = combat

func start(unit: Unit, skill: Dictionary) -> bool:
	if unit != null and (unit.is_active_skill_rush_locked() or unit.death_form.used): return false
	var prepared_skill: Dictionary = _effects.prepare_cast(unit, skill)
	if StringName(prepared_skill.get("kind", "")) == &"dual_form":
		prepared_skill = _effects.prepare_dual_form_cast(unit, prepared_skill)
	if prepared_skill.is_empty():
		return false
	# 先发布 Cast Start，再按 impact_delay 进入固定 Tick 队列；动画回调不参与结算。
	if is_offensive(prepared_skill): unit.record_combat_activity()
	_effects.apply_cast_start(unit, prepared_skill)
	_begin_cast(unit, prepared_skill)
	# 瞬时主动技能可能没有 visual_action，不能依赖表现动作序号触发起手声。
	var audio_card_id := unit.active_skill_card_id if not unit.active_skill_card_id.is_empty() else unit.card_id
	var configured_audio := PresentationConfig.audio_for(CardDB.get_card(audio_card_id), unit.team, unit.form_index)
	var configured_events: Variant = configured_audio.get("events", {})
	if configured_events is Dictionary and configured_events.has("active:cast"):
		unit.battle_context.notify_unit_audio_event(unit, &"active:cast", unit.get_visual_screen_position())
	_commands.schedule_cast(unit, prepared_skill, maxf(float(prepared_skill.get("impact_delay", 0.0)), 0.0), _combat.next_displacement_order(unit))
	return true

func _begin_cast(unit: Unit, skill: Dictionary) -> void:
	var cast_duration := maxf(float(skill.get("cast_duration", 0.0)), 0.0)
	var action_name := StringName(skill.get("visual_action", ""))
	if cast_duration <= 0.0 and action_name == &"":
		return
	var cast_locks: Array = skill.get("cast_locks", Unit.DEFAULT_CAST_LOCKS)
	var cast_facing: Vector2 = skill.get("cast_forward", unit.get_visual_facing_direction())
	if cast_duration > 0.0:
		unit.begin_active_skill_cast(cast_duration, cast_facing, cast_locks, is_offensive(skill))
	if action_name != &"":
		unit.play_visual_action(action_name, cast_duration)
	if StringName(skill.get("kind", "")) in [&"frontal", &"dual_form"]:
		var cast_forward := unit.active_skill_cast_facing
		if cast_forward.length_squared() < 0.001:
			cast_forward = unit.get_visual_facing_direction()
		_presentation.begin_frontal_visual(unit, skill, cast_forward)
	elif StringName(skill.get("kind", "")) == &"forward_area":
		var cast_forward := unit.active_skill_cast_facing
		if cast_forward.length_squared() < 0.001:
			cast_forward = unit.get_visual_facing_direction()
		_effects.prepare_forward_area_result(unit, skill, cast_forward)
	elif StringName(skill.get("kind", "")) == &"continuous_area":
		_presentation.begin_continuous_area_visual(unit, skill)

## 依据实际效果分类，不按动画长短、卡牌名字或普通友方收益判战斗。
static func is_offensive(skill: Dictionary) -> bool:
	var kind := StringName(skill.get("kind", ""))
	if kind == &"buff":
		return float(skill.get("damage_multiplier", 1.0)) > 1.0 or float(skill.get("attack_speed_multiplier", 1.0)) > 1.0 or bool(skill.get("piercing_attacks", false))
	return kind in [&"frontal", &"forward_area", &"continuous_area", &"nova", &"dash_strike", &"terrain_charge", &"bleeding_execute", &"empowered_attack", &"explosive_shield", &"attack_lifesteal", &"timed_form"]
