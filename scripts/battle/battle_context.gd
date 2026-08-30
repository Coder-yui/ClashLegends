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
	return float(_controller.FIELD_W)

func ensure_unit_form_resize_safe(unit: Unit) -> void:
	_controller.ensure_unit_form_resize_safe(unit)

func spawn_summoned(team: int, card_id: String, position: Vector2) -> Unit:
	return _controller.spawn_summoned(team, card_id, position)

func is_ground_position_walkable(position: Vector2, mover_radius: float, excluded: Node = null) -> bool:
	return _controller.is_ground_position_walkable(position, mover_radius, excluded)

func is_ground_segment_walkable(from: Vector2, to: Vector2, mover_radius: float, excluded: Node = null) -> bool:
	return _controller.is_ground_segment_walkable(from, to, mover_radius, excluded)

func find_ground_path(from: Vector2, goal: Vector2, target: Node2D, mover_radius: float) -> PackedVector2Array:
	return _controller.find_ground_path(from, goal, target, mover_radius)

func launch_attack(attacker: Node2D, target: Node2D, amount: float, projectile_speed: float, splash_radius: float, knockback: float, projectile_color: Color) -> void:
	_controller.launch_attack(attacker, target, amount, projectile_speed, splash_radius, knockback, projectile_color)

func resolve_attack_hit(team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float, from: Node2D, source_position: Vector2, source_form_index: int) -> void:
	_controller.resolve_attack_hit(team, origin, primary, amount, radius, knockback, from, source_position, source_form_index)

func unblock_nav_cells(cells: Array) -> void:
	_controller.unblock_nav_cells(cells)

func notify_unit_hit(net_id: int) -> void:
	_controller.on_unit_hit(net_id)

func notify_unit_died(net_id: int) -> void:
	_controller.on_unit_died(net_id)

func notify_tower_hit(tower: Tower) -> void:
	_controller.on_tower_hit(tower)
