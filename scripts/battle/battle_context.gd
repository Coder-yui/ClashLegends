class_name BattleContext
extends RefCounted
## Unit / Tower 访问战场能力的轻量边界。
## 这里只转发稳定的战斗服务，不保存模拟状态，也不承担依赖注入框架职责。

var _controller: Node2D

func _init(controller: Node2D) -> void:
	_controller = controller

func is_net_client() -> bool:
	return _controller.is_net_client()

func simulation_interpolation_alpha() -> float:
	return _controller.get_sim_interpolation_alpha()

func navigation() -> NavGrid:
	return _controller.nav

func field_width() -> float:
	return float(ArenaRules.FIELD_W)

func ensure_unit_form_resize_safe(unit: Unit) -> void:
	_controller.ensure_unit_form_resize_safe(unit)

func spawn_summoned(team: int, card_id: String, position: Vector2, deploy_time_override: float = -1.0, visual_transition: String = "", death_replacement_charges_override: int = -1) -> Unit:
	return _controller.spawn_summoned(team, card_id, position, deploy_time_override, visual_transition, death_replacement_charges_override)

func is_ground_position_walkable(position: Vector2, mover_radius: float, excluded: Node = null) -> bool:
	return _controller.is_ground_position_walkable(position, mover_radius, excluded)

func is_ground_segment_walkable(from: Vector2, to: Vector2, mover_radius: float, excluded: Node = null) -> bool:
	return _controller.is_ground_segment_walkable(from, to, mover_radius, excluded)

func find_ground_path(from: Vector2, goal: Vector2, target: Node2D, mover_radius: float) -> PackedVector2Array:
	return _controller.find_ground_path(from, goal, target, mover_radius)

func launch_attack(attacker: Node2D, target: Node2D, amount: float, projectile_speed: float, splash_radius: float, knockback: float, projectile_color: Color, effects: Dictionary = {}) -> void:
	_controller.launch_attack(attacker, target, amount, projectile_speed, splash_radius, knockback, projectile_color, effects)

## 所有持续伤害共用的权威脉冲入口：目标筛选/计时由调用方负责，护盾、隐匿、死亡和命中回调由战场统一结算。
## counts_as_attack 仅供龙王吐息这类持续普攻使用；主动技能伤害传 false，避免给普攻资源或命中回血。
func apply_damage_pulse(source: Node2D, target: Node2D, amount: float, splash_radius: float = 0.0, origin: Vector2 = Vector2(INF, INF), counts_as_attack: bool = false, source_form_index: int = -1, effects: Dictionary = {}) -> bool:
	return _controller.apply_damage_pulse(source, target, amount, splash_radius, origin, counts_as_attack, source_form_index, effects)

func resolve_attack_hit(team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float, from: Node2D, source_position: Vector2, source_form_index: int, effects: Dictionary = {}, counts_as_attack: bool = true) -> bool:
	return _controller._combat.resolve_attack_hit(team, origin, primary, amount, radius, knockback, from, source_position, source_form_index, effects, counts_as_attack)

func show_projectile_impact(position: Vector2, radius: float, color: Color, visual: StringName) -> void:
	_controller.show_projectile_impact(position, radius, color, visual)

func unblock_nav_cells(cells: Array) -> void:
	_controller.unblock_nav_cells(cells)

func notify_unit_hit(net_id: int) -> void:
	_controller.on_unit_hit(net_id)

## 权威事件后的纯表现通知，不改变战斗状态。
func notify_unit_audio_event(unit: Unit, cue: StringName, position: Vector2) -> void:
	_controller._notify_unit_audio_event(unit, cue, position)

func notify_unit_died(net_id: int, play_death_visual: bool = true) -> void:
	_controller.on_unit_died(net_id, play_death_visual)

func notify_tower_hit(tower: Tower) -> void:
	_controller.on_tower_hit(tower)

func damage_batch() -> CombatResolver:
	return _controller._combat
