class_name Tower
extends Node2D

# 战场注册时分配的出生身份；不使用对象地址或场景树位置排序。
var combat_source_id := 0
## 防御塔：固定不动，自动攻击范围内的敌方单位。
## 参考皇室战争规则：国王塔初始休眠、不主动攻击；
## 受到伤害或己方任一公主塔被摧毁后激活。
## 战斗逻辑在固定 20Hz tick（sim_tick）中推进，与渲染帧率解耦，由 main 驱动。

signal destroyed
signal visual_hit

## 受击闪白事件限频：与单位一致，持续伤害（如龙息）每 0.18 秒最多触发一次表现。
const HIT_FLASH_EVENT_COOLDOWN := 0.18
const BLUE_PROJECTILE_COLOR := Color(0.18, 0.66, 1.0)
const RED_PROJECTILE_COLOR := Color(1.0, 0.18, 0.22)
const PRINCESS_HEALTH_BAR_WIDTH := 120.0
const KING_HEALTH_BAR_WIDTH := 160.0
const HEALTH_BAR_HEIGHT := 18.0
const HEALTH_TEXT_SIZE := 13

var team := 0  # 0 = 玩家（下方），1 = 敌方（上方）
var battle_context: BattleContext
var max_hp := 2000.0
var hp := 2000.0
var shields := ShieldState.new()
var _net_shield_hp := 0.0
var _net_shield_capacity := 0.0
var _shield_is_replica := false
var shield_hp: float:
	get: return _net_shield_hp if _shield_is_replica else shields.total_hp()
var shield_max_hp: float:
	get: return _net_shield_capacity if _shield_is_replica else shields.total_capacity()
var shield_timer: float:
	get: return (1.0 if _net_shield_hp > 0.0 else 0.0) if _shield_is_replica else shields.longest_remaining()
var damage := 50.0
var attack_range := 300.0
var attack_interval := 0.8
var body_radius := 34.0
## 只用于下牌占地；单位绕行始终使用 body_radius 的圆柱碰撞。
var footprint_tiles := Vector2i(3, 3)
## 物理圆、规则占地与绘制尺寸分离，美术不再反向改变手感。
var visual_radius := 34.0
var first_hit_time := 0.2
var projectile_speed := 400.0
# 权威弹体几何；与 projectile_visual_* 完全独立。
var projectile_spawn_at_edge := false
var projectile_spawn_offset := 0.0
var projectile_collision_radius := 7.0
## 仅用于弹体绘制的晶石起点偏移；权威发射位置仍是塔心。
var projectile_visual_offset := Vector2.ZERO
var splash_radius := 0.0
var attack_knockback := 0.0
var is_king := false
var activated := true
var can_attack := true
var has_model_art := false

var nav_cells: Array = []

var _cooldown := 0.0
var _lock_windup := 0.0
var _target: Node2D = null
var frozen_timer: float:
	get: return control.frozen_timer
var control := ControlState.new()
var _destroyed_visual_emitted := false
var _hit_flash_event_cooldown := 0.0

func set_battle_context(context: BattleContext) -> void:
	battle_context = context

func setup(p_team: int, stats: Dictionary, p_is_king: bool) -> void:
	team = p_team
	is_king = p_is_king
	max_hp = BattleNumbers.quantity(stats.hp)
	hp = max_hp
	shields.clear()
	_shield_is_replica = false
	_net_shield_hp = 0.0
	_net_shield_capacity = 0.0
	damage = BattleNumbers.quantity(stats.damage)
	attack_range = stats.range
	attack_interval = snappedf(stats.interval, 0.01)
	body_radius = stats.radius
	footprint_tiles = stats.get("footprint_tiles", Vector2i(4, 4) if is_king else Vector2i(3, 3))
	visual_radius = stats.get("visual_radius", body_radius)
	first_hit_time = stats.get("first_hit", 0.2)
	projectile_speed = stats.get("projectile_speed", 400.0)
	projectile_spawn_at_edge = bool(stats.get("projectile_spawn_at_edge", false))
	projectile_spawn_offset = float(stats.get("projectile_spawn_offset", 0.0))
	projectile_collision_radius = float(stats.get("projectile_collision_radius", 7.0))
	var configured_projectile_offset: Vector2 = stats.get("projectile_visual_offset", Vector2.ZERO)
	# 蓝/红塔素材在表现层相差 180°，权杖晶石的水平偏移随阵营镜像。
	projectile_visual_offset = Vector2(configured_projectile_offset.x if team == 0 else -configured_projectile_offset.x, configured_projectile_offset.y)
	splash_radius = stats.get("splash_radius", 0.0)
	attack_knockback = stats.get("knockback", 0.0)
	can_attack = stats.get("can_attack", true)
	# 国王塔初始休眠；公主塔默认激活
	activated = not is_king

func activate() -> void:
	# 国王塔被击中或己方公主塔被摧毁时唤醒
	if activated:
		return
	activated = true
	queue_redraw()

func freeze(duration: float, source: StringName = &"legacy") -> void:
	if hp <= 0.0 or not is_finite(duration) or duration <= 0.0: return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): freeze(duration, source))
		return
	if control.refresh_freeze(duration, source):
		_target = null
		_lock_windup = 0.0
		_cooldown = 0.0
	queue_redraw()

func stun(duration: float, source: StringName = &"legacy") -> void:
	if hp <= 0.0 or not is_finite(duration) or duration <= 0.0: return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): stun(duration, source))
		return
	if control.refresh_stun(duration, source):
		_target = null
		_lock_windup = 0.0
		_cooldown = 0.0
	queue_redraw()

func _ready() -> void:
	add_to_group("combatants")
	add_to_group("combat_structures")

func prepare_statuses(dt: float) -> void:
	_tick_shield(dt)
	control.tick_hard_controls(dt)

func sim_tick(dt: float, statuses_prepared: bool = false) -> void:
	# 已被摧毁：不再攻击
	if hp <= 0.0:
		return
	if not statuses_prepared:
		prepare_statuses(dt)
	# 冰冻计时不因国王塔休眠而暂停。
	_hit_flash_event_cooldown = maxf(0.0, _hit_flash_event_cooldown - dt)
	if frozen_timer > 0.0 or control.stun_timer > 0.0:
		queue_redraw()
		return
	if not can_attack:
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
		if battle_context != null:
			var projectile_color := BLUE_PROJECTILE_COLOR if team == 0 else RED_PROJECTILE_COLOR
			battle_context.launch_attack(self, _target, damage, projectile_speed, splash_radius, attack_knockback, projectile_color)
		else:
			_target.take_damage(damage)
		_cooldown = attack_interval

func _target_is_valid(target) -> bool:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return false
	if not target is Unit or target.team == team:
		return false
	var unit := target as Unit
	return _target_gap(unit) <= attack_range

func _target_gap(target: Node2D) -> float:
	return surface_gap_to_circle(target.global_position, target.body_radius)

## 塔使用圆形碰撞；单位从正后方推进时会自然贴着圆周绕到侧面。
func surface_gap_to_circle(center: Vector2, radius: float) -> float:
	return maxf(0.0, center.distance_to(global_position) - body_radius - radius)

func _find_enemy_in_range() -> Node2D:
	var best: Node2D = null
	var best_gap := INF
	for c in get_tree().get_nodes_in_group("combatants"):
		# 塔只打单位，不打塔
		if not c is Unit or c.team == team or c.hp <= 0.0:
			continue
		var unit := c as Unit
		var gap := _target_gap(unit)
		if gap <= attack_range and gap < best_gap:
			best_gap = gap
			best = c
	return best

func take_damage(amount: float, _from: Node2D = null, _source_team: int = -1, _source_position: Vector2 = Vector2(INF, INF)) -> bool:
	if battle_context != null and battle_context.damage_batch().collecting:
		return bool(battle_context.damage_batch().submit_damage(self, amount, _from, _source_team, _source_position).accepted)
	if hp <= 0.0:
		return false
	var was_alive := hp > 0.0
	var remaining_damage := BattleNumbers.quantity(maxf(amount, 0.0))
	remaining_damage = shields.absorb(remaining_damage)
	hp = maxf(hp - remaining_damage, 0.0)
	# CR 规则：国王塔受到伤害即激活
	if is_king and can_attack and not activated and hp > 0.0:
		activate()
	# 受击闪白只发限频表现事件；摧毁走 destroy 动画，不再闪白。
	if hp > 0.0 and _hit_flash_event_cooldown <= 0.0:
		_hit_flash_event_cooldown = HIT_FLASH_EVENT_COOLDOWN
		notify_visual_hit()
		if battle_context != null:
			battle_context.notify_tower_hit(self)
	if was_alive and hp <= 0.0:
		if battle_context != null and battle_context.damage_batch().committing:
			battle_context.damage_batch().defer_effect(notify_visual_destroyed)
		else:
			notify_visual_destroyed()
	queue_redraw()
	return true


func add_shield(amount: float, duration: float, decays: bool = false, source: StringName = &"legacy") -> void:
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): add_shield(amount, duration, decays, source))
		return
	if hp > 0.0:
		_shield_is_replica = false
		shields.add(amount, duration, decays, false, source)
		queue_redraw()

func clear_shields() -> void:
	_shield_is_replica = false
	_net_shield_hp = 0.0
	_net_shield_capacity = 0.0
	shields.clear()
	queue_redraw()

func _tick_shield(dt: float) -> void:
	shields.tick(dt)
	queue_redraw()

## 快照只写表现值，不创建或推进客户端权威护盾层。
func apply_shield_snapshot(ratio: float, capacity_ratio: float) -> void:
	shields.clear()
	_shield_is_replica = true
	_net_shield_capacity = BattleNumbers.quantity(maxf(capacity_ratio, 0.0) * max_hp)
	_net_shield_hp = BattleNumbers.quantity(clampf(ratio, 0.0, 1.0) * _net_shield_capacity)
	queue_redraw()


func get_shield_ratio() -> float:
	if shield_hp <= 0.0 or shield_max_hp <= 0.0 or shield_timer <= 0.0:
		return 0.0
	return clampf(shield_hp / shield_max_hp, 0.0, 1.0)


func get_shield_capacity_ratio() -> float:
	return maxf(shield_max_hp / maxf(max_hp, 0.001), 0.0) if shield_hp > 0.0 and shield_timer > 0.0 else 0.0


func get_shield_health_ratio() -> float:
	return get_shield_ratio() * get_shield_capacity_ratio()

## 网络只传递解码后的值；塔拥有副本更新、死亡表现与导航释放的完整转换。
func apply_network_state(health: float, active: bool, stunned: bool, shield_ratio: float, capacity_ratio: float, frozen: bool = false) -> void:
	var was_alive := hp > 0.0
	hp = BattleNumbers.quantity(health)
	activated = active
	control.apply_replica_flags(frozen, stunned)
	apply_shield_snapshot(shield_ratio, capacity_ratio)
	if was_alive and hp <= 0.0:
		notify_visual_destroyed()
	if hp <= 0.0 and not nav_cells.is_empty() and battle_context != null:
		battle_context.unblock_nav_cells(nav_cells)
		nav_cells = []
	queue_redraw()

## 塔不会像单位一样立即释放，因此血量快照本身可反复兜底这个一次性表现事件。
## 幂等标记确保本地伤害与客户端快照不会重复播放摧毁动画。
func notify_visual_destroyed() -> void:
	if _destroyed_visual_emitted:
		return
	_destroyed_visual_emitted = true
	destroyed.emit()

## 只触发表现闪白，不参与血量、激活或任何权威状态。
func notify_visual_hit() -> void:
	visual_hit.emit()

func _health_text() -> String:
	return "%d" % BattleNumbers.quantity(hp)

func _draw() -> void:
	# 已被摧毁：画废墟，不画描边和血条
	if hp <= 0.0:
		if not has_model_art:
			draw_circle(Vector2.ZERO, visual_radius, Color(0.22, 0.21, 0.20))
			draw_arc(Vector2.ZERO, visual_radius + 2.0, 0.0, TAU, 40, Color(0.15, 0.14, 0.13), 2.0)
		return
	# 队伍描边：玩家蓝、敌方红
	if not has_model_art:
		var outline := Color(0.30, 0.60, 1.00) if team == 0 else Color(1.00, 0.35, 0.30)
		draw_circle(Vector2.ZERO, visual_radius + 3.0, outline)
		draw_circle(Vector2.ZERO, visual_radius, Color(0.55, 0.50, 0.45))
	# 冰冻状态：蓝色覆盖
	if frozen_timer > 0.0:
		draw_circle(Vector2.ZERO, visual_radius + 4.0, Color(0.40, 0.70, 1.00, 0.35))
	if control.stun_timer > 0.0:
		draw_arc(Vector2.ZERO, visual_radius + 5.0, 0.0, TAU, 28, Color(1.0, 0.78, 0.18, 0.95), 3.0, true)
	# 国王塔顶部标记：激活金色，休眠灰色
	if is_king and not has_model_art:
		var crown_color := Color(0.95, 0.80, 0.25) if activated else Color(0.5, 0.5, 0.5)
		draw_circle(Vector2(0, -visual_radius * 0.4), visual_radius * 0.35, crown_color)
	# 血条：塔3格、水晶4格（每格40px）。敌方红条在建筑上方；
	# 己方塔绿条在塔身中央，己方水晶绿条贴着水晶底座下方。
	draw_set_transform(Vector2.ZERO, -get_global_transform_with_canvas().get_rotation(), Vector2.ONE)
	var local_team := 1 if battle_context != null and battle_context.is_net_client() else 0
	var bar_w := KING_HEALTH_BAR_WIDTH if is_king else PRINCESS_HEALTH_BAR_WIDTH
	var bar_h := HEALTH_BAR_HEIGHT
	var ratio := maxf(hp / max_hp, 0.0)
	var shield_health_ratio := get_shield_health_ratio()
	var shield_capacity_ratio := get_shield_capacity_ratio()
	var bar_center_y := -visual_radius - 16.0  # 敌方塔：塔上方；敌方水晶：水晶上方
	if is_king and team == local_team:
		bar_center_y = 84.0                    # 己方水晶：上移至血条顶边贴住最近的网格线(y=1240)
	elif is_king:
		bar_center_y = -visual_radius          # 敌方水晶：稍下移，贴在水晶顶部上方
	elif team == local_team:
		bar_center_y = -visual_radius * 2.0 + 80.0    # 己方塔：塔身中央再下放两格（每格40px）
	var bar_color := Color(0.95, 0.28, 0.26) if team == 1 else Color(0.28, 0.88, 0.28)
	var bar_rect := Rect2(Vector2(-bar_w / 2.0, bar_center_y - bar_h / 2.0), Vector2(bar_w, bar_h))
	draw_rect(bar_rect, Color(0.10, 0.10, 0.10))
	var combined_capacity := 1.0 + shield_capacity_ratio
	var hp_width := bar_w * ratio / combined_capacity
	var shield_width := bar_w * shield_health_ratio / combined_capacity
	draw_rect(Rect2(bar_rect.position, Vector2(hp_width, bar_h)), bar_color)
	if shield_width > 0.0:
		draw_rect(Rect2(Vector2(bar_rect.position.x + hp_width, bar_rect.position.y), Vector2(shield_width, bar_h)), Color.WHITE)
	# 血条内只显示权威当前生命；轻微黑色偏移保证在红绿填充上都清晰。
	var hp_text := _health_text()
	var text_pos := Vector2(bar_rect.position.x, bar_rect.position.y + 14.0)
	draw_string(ThemeDB.fallback_font, text_pos + Vector2.ONE, hp_text, HORIZONTAL_ALIGNMENT_CENTER, bar_w, HEALTH_TEXT_SIZE, Color(0.0, 0.0, 0.0, 0.85))
	draw_string(ThemeDB.fallback_font, text_pos, hp_text, HORIZONTAL_ALIGNMENT_CENTER, bar_w, HEALTH_TEXT_SIZE, Color.WHITE)
