class_name Tower
extends Node2D
## 防御塔：固定不动，自动攻击范围内的敌方单位。
## 参考皇室战争规则：国王塔初始休眠、不主动攻击；
## 受到伤害或己方任一公主塔被摧毁后激活。
## 战斗逻辑在固定 20Hz tick（sim_tick）中推进，与渲染帧率解耦，由 main 驱动。

var team := 0  # 0 = 玩家（下方），1 = 敌方（上方）
var max_hp := 2000.0
var hp := 2000.0
var damage := 50.0
var attack_range := 300.0
var attack_interval := 0.8
var body_radius := 34.0
## 物理圆、绘制尺寸、部署禁区分离，美术不再反向改变手感。
var visual_radius := 34.0
var deployment_radius := 34.0
var first_hit_time := 0.2
var projectile_speed := 400.0
var splash_radius := 0.0
var attack_knockback := 0.0
var is_king := false
var activated := true

var nav_cells: Array = []

var _cooldown := 0.0
var _lock_windup := 0.0
var _target: Node2D = null
var frozen_timer := 0.0

func setup(p_team: int, stats: Dictionary, p_is_king: bool) -> void:
	team = p_team
	is_king = p_is_king
	max_hp = stats.hp
	hp = max_hp
	damage = stats.damage
	attack_range = stats.range
	attack_interval = stats.interval
	body_radius = stats.radius
	visual_radius = stats.get("visual_radius", body_radius)
	deployment_radius = stats.get("deployment_radius", visual_radius)
	first_hit_time = stats.get("first_hit", 0.2)
	projectile_speed = stats.get("projectile_speed", 400.0)
	splash_radius = stats.get("splash_radius", 0.0)
	attack_knockback = stats.get("knockback", 0.0)
	# 国王塔初始休眠；公主塔默认激活
	activated = not is_king

func activate() -> void:
	# 国王塔被击中或己方公主塔被摧毁时唤醒
	if activated:
		return
	activated = true
	queue_redraw()

func freeze(duration: float) -> void:
	frozen_timer = maxf(frozen_timer, duration)
	queue_redraw()

func _ready() -> void:
	add_to_group("combatants")

func sim_tick(dt: float) -> void:
	# 已被摧毁：不再攻击
	if hp <= 0.0:
		return
	# 冰冻计时不因国王塔休眠而暂停。
	if frozen_timer > 0.0:
		frozen_timer = maxf(0.0, frozen_timer - dt)
		queue_redraw()
		return
	# 国王塔休眠中：不索敌不攻击
	if is_king and not activated:
		return
	_cooldown = maxf(0.0, _cooldown - dt)
	if not _target_is_valid(_target):
		_target = null
		_lock_windup = 0.0
	if _target == null:
		_target = _find_enemy_in_range()
		if _target != null:
			_lock_windup = first_hit_time
	if _target == null:
		return
	if _lock_windup > 0.0:
		_lock_windup = maxf(0.0, _lock_windup - dt)
		if _lock_windup > 0.0:
			return
	if _cooldown <= 0.0:
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("launch_attack"):
			var projectile_color := Color(1.0, 0.82, 0.30) if is_king else Color(0.95, 0.95, 0.82)
			scene.launch_attack(self, _target, damage, projectile_speed, splash_radius, attack_knockback, projectile_color)
		else:
			_target.take_damage(damage)
		_cooldown = attack_interval

func _target_is_valid(target) -> bool:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return false
	if not target is Unit or target.team == team:
		return false
	var unit := target as Unit
	if not unit.is_deployed():
		return false
	return _target_gap(unit) <= attack_range

func _target_gap(target: Node2D) -> float:
	return surface_gap_to_circle(target.global_position, target.body_radius)

## 塔使用圆形碰撞；单位从正后方推进时会自然贴着圆周绕到侧面。
func surface_gap_to_circle(center: Vector2, radius: float) -> float:
	return maxf(0.0, center.distance_to(global_position) - body_radius - radius)

func deployment_gap_to_circle(center: Vector2, radius: float) -> float:
	return maxf(0.0, center.distance_to(global_position) - deployment_radius - radius)

func _find_enemy_in_range() -> Node2D:
	var best: Node2D = null
	var best_gap := INF
	for c in get_tree().get_nodes_in_group("combatants"):
		# 塔只打单位，不打塔
		if not c is Unit or c.team == team or c.hp <= 0.0:
			continue
		var unit := c as Unit
		if not unit.is_deployed():
			continue
		var gap := _target_gap(unit)
		if gap <= attack_range and gap < best_gap:
			best_gap = gap
			best = c
	return best

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	# CR 规则：国王塔受到伤害即激活
	if is_king and not activated and hp > 0.0:
		activate()
	queue_redraw()

func _draw() -> void:
	# 已被摧毁：画废墟，不画描边和血条
	if hp <= 0.0:
		draw_circle(Vector2.ZERO, visual_radius, Color(0.22, 0.21, 0.20))
		draw_arc(Vector2.ZERO, visual_radius + 2.0, 0.0, TAU, 40, Color(0.15, 0.14, 0.13), 2.0)
		return
	# 队伍描边：玩家蓝、敌方红
	var outline := Color(0.30, 0.60, 1.00) if team == 0 else Color(1.00, 0.35, 0.30)
	draw_circle(Vector2.ZERO, visual_radius + 3.0, outline)
	draw_circle(Vector2.ZERO, visual_radius, Color(0.55, 0.50, 0.45))
	# 冰冻状态：蓝色覆盖
	if frozen_timer > 0.0:
		draw_circle(Vector2.ZERO, visual_radius + 4.0, Color(0.40, 0.70, 1.00, 0.35))
	# 国王塔顶部标记：激活金色，休眠灰色
	if is_king:
		var crown_color := Color(0.95, 0.80, 0.25) if activated else Color(0.5, 0.5, 0.5)
		draw_circle(Vector2(0, -visual_radius * 0.4), visual_radius * 0.35, crown_color)
	# 血条
	var ratio := maxf(hp / max_hp, 0.0)
	var bar_pos := Vector2(-visual_radius, -visual_radius - 16)
	draw_rect(Rect2(bar_pos, Vector2(visual_radius * 2, 7)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(bar_pos, Vector2(visual_radius * 2 * ratio, 7)), Color(0.30, 0.90, 0.30))
