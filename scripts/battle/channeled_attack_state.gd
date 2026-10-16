class_name ChanneledAttackState
extends RefCounted
## 下一击在命中节点消费；引导目标控制与独立区域分别持有生命周期。
var prepared: Dictionary = {}
var target_ref: WeakRef
var remaining := 0.0
var status_source: StringName

func active() -> bool:
	return remaining > 0.0

func begin(source: Unit, target: Node2D) -> void:
	if not is_instance_valid(target) or target.hp <= 0.0: return
	if not CombatInteraction.allows(target, source, source.team, source.global_position): return
	var skill := prepared
	prepared = {}
	source.cancel_basic_attack(ActionCancellation.EMPOWERED_RESET)
	remaining = float(skill.duration)
	target_ref = weakref(target)
	status_source = source.status_source("channel")
	source.begin_active_skill_cast(remaining, target.global_position - source.global_position)
	source.play_visual_action(&"channel", remaining)
	if target.has_method("stun"):
		var apply_control := func():
			if not is_instance_valid(source) or not active() or not is_instance_valid(target): return
			if target_ref == null or target_ref.get_ref() != target: return
			target.stun(remaining, status_source, CombatInteraction.effect_context(source, source.team, source.global_position))
		if source.battle_context.damage_batch().collecting:
			source.battle_context.damage_batch().defer_effect(apply_control)
		else: apply_control.call()
	source.battle_context.begin_channel_zone(source, target.global_position, skill)

func tick(source: Unit, dt: float) -> void:
	if not active(): return
	var target = target_ref.get_ref()
	if source.hp <= 0.0 or source.is_frozen() or source.is_stunned() or CombatInteraction.in_stasis(source) or source._knockback_timer > 0.0 or source.control.hard.remaining(&"silence") > 0.0 or source.control.hard.remaining(&"taunt") > 0.0:
		stop(source)
		return
	if not is_instance_valid(target) or target.hp <= 0.0 or not CombatInteraction.allows(target, source, source.team, source.global_position):
		stop(source)
		return
	remaining = maxf(remaining - dt, 0.0)
	if remaining <= 0.000001: stop(source)

func stop(source: Unit) -> void:
	if target_ref == null: return
	var target = target_ref.get_ref()
	if is_instance_valid(target) and target.get("control") is ControlState:
		target.control.hard.remove_source(&"stun", status_source)
	target_ref = null
	remaining = 0.0
	source.cancelled_visual_serial = maxi(source.cancelled_visual_serial, source.get_visual_action_serial())
	source.cancel_skill_cast()
