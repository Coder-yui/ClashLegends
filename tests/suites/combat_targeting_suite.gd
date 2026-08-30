class_name CombatTargetingSuite
extends RefCounted
## 战斗索敌领域：目标锁定、攻击状态机、射程脱锁与塔目标规则。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_building_pulls_tower_target()
	_check_nearest_unit_or_building_target()
	_check_crystal_target_and_nearest_attack_target()
	_check_per_card_sight()
	_check_attack_target_lock()
	_check_attack_hit_recovery_commitment()
	_check_basic_attack_has_no_knockback()
	_check_freed_target_cleanup()
	_check_tower_loses_out_of_range_target()
	_check_landing_body_push_retargets_attacker()
	_check_destroyed_lane_targets_king()
	_check_unit_reaches_and_damages_tower()
	_check_sett_attack_rhythm()
	_check_king_activation()

func _check_building_pulls_tower_target() -> void:
	var attacker_stats: Dictionary = CardDB.get_card("garen").duplicate()
	attacker_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	attacker.position = Vector2(204.0, 760.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	_main.add_child(attacker)
	attacker._update_target()
	var started_for_tower: bool = attacker._target is Tower
	var building_stats: Dictionary = CardDB.get_card("tombstone").duplicate()
	building_stats["deploy_time"] = 0.0
	var building := Unit.new()
	building.position = Vector2(204.0, 610.0)
	building.setup(1, building_stats, building_stats.name)
	_main.add_child(building)
	attacker._update_target()
	_expect(started_for_tower and attacker._target == building, "视野内建筑可拉走正在向塔行军的攻城单位")
	attacker.free()
	building.free()

func _check_nearest_unit_or_building_target() -> void:
	var attacker_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var troop_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var building_stats: Dictionary = CardDB.get_card("tombstone").duplicate()
	attacker_stats["deploy_time"] = 0.0
	troop_stats["deploy_time"] = 0.0
	building_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var troop := Unit.new()
	var building := Unit.new()
	attacker.position = Vector2(300.0, 800.0)
	troop.position = Vector2(300.0, 650.0)
	building.position = Vector2(300.0, 720.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	troop.setup(1, troop_stats, troop_stats.name)
	building.setup(1, building_stats, building_stats.name)
	_main.add_child(attacker)
	_main.add_child(troop)
	_main.add_child(building)
	_expect(attacker._find_nearest_distraction() == building, "普通单位会选择视野内更近的敌方建筑，不固定优先兵种")
	troop.position = Vector2(300.0, 755.0)
	_expect(attacker._find_nearest_distraction() == troop, "敌方兵种更近时则改为追击兵种")
	attacker._target = building
	attacker._attacking = false
	attacker._update_target()
	_expect(attacker._target == troop, "追击期间出现更近的合法目标时会转移仇恨")
	attacker.free()
	troop.free()
	building.free()

func _check_crystal_target_and_nearest_attack_target() -> void:
	# 普通单位在攻击范围内应优先锁定最近的合法敌方单位；测试位置都在赵信的攻击距离内。
	var attacker_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var target_stats: Dictionary = CardDB.get_card("xin").duplicate()
	attacker_stats["deploy_time"] = 0.0
	target_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var nearer := Unit.new()
	var farther := Unit.new()
	attacker.position = Vector2(300.0, 800.0)
	nearer.position = Vector2(300.0, 755.0)
	farther.position = Vector2(300.0, 980.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	nearer.setup(1, target_stats, target_stats.name)
	farther.setup(1, target_stats, target_stats.name)
	_main.add_child(attacker)
	_main.add_child(nearer)
	_main.add_child(farther)
	attacker._update_target()
	var nearest_unit_ok: bool = (
		attacker._target == nearer
		and attacker._target_gap(nearer) <= attacker.attack_range
		and attacker._target_gap(farther) > attacker.attack_range
		and attacker._target_gap(farther) <= attacker.sight_range
	)
	_expect(nearest_unit_ok, "攻击范围内优先攻击最近单位，只有视野内的较远单位则继续追击最近目标")
	attacker.free()
	nearer.free()
	farther.free()

	# 两座敌方公主塔都还存活时，贴近水晶的单位也应能把水晶作为合法目标。
	var crystal_attacker := Unit.new()
	crystal_attacker.position = _main._king_enemy.position + Vector2.DOWN * 100.0
	crystal_attacker.setup(0, attacker_stats, attacker_stats.name)
	_main.add_child(crystal_attacker)
	crystal_attacker._target = _main._towers[3]
	crystal_attacker._update_target()
	var princesses_alive: bool = _main._towers[2].hp > 0.0 and _main._towers[3].hp > 0.0
	_expect(princesses_alive and crystal_attacker._target == _main._king_enemy, "公主塔未被摧毁时，进入攻击范围的单位也能选择敌方水晶")
	crystal_attacker.free()

func _check_per_card_sight() -> void:
	var melee_stats: Dictionary = CardDB.get_card("masteryi").duplicate()
	var ranged_stats: Dictionary = CardDB.get_card("ashe").duplicate()
	var enemy_stats: Dictionary = CardDB.get_card("xin").duplicate()
	for stats in [melee_stats, ranged_stats, enemy_stats]:
		stats["deploy_time"] = 0.0
	var melee := Unit.new()
	var ranged := Unit.new()
	var enemy := Unit.new()
	melee.position = Vector2(260.0, 800.0)
	ranged.position = Vector2(260.0, 840.0)
	enemy.position = Vector2(510.0, 800.0)
	melee.setup(0, melee_stats, melee_stats.name)
	ranged.setup(0, ranged_stats, ranged_stats.name)
	enemy.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(melee)
	_main.add_child(ranged)
	_main.add_child(enemy)
	_expect(melee.sight_range != ranged.sight_range, "视野已从全局常量下放到每张单位卡")
	_expect(melee._find_nearest_distraction() == null and ranged._find_nearest_distraction() == enemy, "不同单位会按自身视野范围产生仇恨")
	melee.free()
	ranged.free()
	enemy.free()

func _check_attack_target_lock() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var locked_target := Unit.new()
	var closer_target := Unit.new()
	attacker.position = Vector2(300.0, 760.0)
	locked_target.position = Vector2(300.0, 720.0)
	closer_target.position = Vector2(302.0, 750.0)
	attacker.setup(0, stats, stats.name)
	locked_target.setup(1, stats, stats.name)
	closer_target.setup(1, stats, stats.name)
	_main.add_child(attacker)
	_main.add_child(locked_target)
	_main.add_child(closer_target)
	attacker._target = locked_target
	attacker._attacking = true
	attacker._update_target()
	var kept_lock := attacker._target == locked_target
	locked_target.position = Vector2(300.0, 500.0)
	attacker._update_target()
	_expect(kept_lock, "攻击状态下不会因为出现更近目标而转火")
	_expect(attacker._target == closer_target, "原目标脱离攻击范围后才重新寻找目标")
	attacker.free()
	locked_target.free()
	closer_target.free()

func _check_attack_hit_recovery_commitment() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.setup(0, stats, stats.name)
	target.setup(1, stats, stats.name)
	attacker.position = Vector2(300.0, 760.0)
	target.position = Vector2(300.0, 760.0 - attacker.body_radius - target.body_radius - float(stats.range) - 8.0)
	_main.add_child(attacker)
	_main.add_child(target)
	# 目标在命中节点所在的固定 tick 刚越出射程：本次挥击依然成立。
	attacker._target = target
	attacker._attacking = true
	attacker._attack_windup = _main.SIM_DT
	attacker._attack_visual_pending = false
	var hp_before := target.hp
	attacker.sim_tick(_main.SIM_DT)
	var recovery_after_hit := attacker._attack_recovery_timer
	_expect(target.hp < hp_before, "目标在命中节点刚越出射程时，本次攻击仍然命中")
	_expect(attacker._attacking and recovery_after_hit > 0.0 and attacker._move_intent.is_zero_approx(), "攻击命中后进入后摇锁定，不会立刻追击")
	# 后摇中目标保持在射程外：不能补第二次伤害，也不能切到 Move。
	attacker.sim_tick(recovery_after_hit * 0.5)
	_expect(target.hp < hp_before and attacker._attacking and attacker._move_intent.is_zero_approx(), "后摇期间保持 Attack 状态且不重复结算伤害")
	# 收招完成后才解除锁定，重新追向仍然存活的移动目标。
	attacker.sim_tick(recovery_after_hit)
	_expect(not attacker._attacking and attacker._attack_recovery_timer <= 0.0 and not attacker._move_intent.is_zero_approx(), "完整播放后摇后才恢复追击")
	# 尚未到命中节点就提前脱离射程，仍可取消前摇，避免整段攻击无条件锁定。
	attacker._move_intent = Vector2.ZERO
	attacker._target = target
	attacker._attacking = true
	attacker._attack_windup = _main.SIM_DT * 2.0
	attacker._attack_recovery_timer = 0.0
	attacker._attack_visual_pending = false
	var hp_before_cancel := target.hp
	attacker.sim_tick(_main.SIM_DT)
	_expect(is_equal_approx(target.hp, hp_before_cancel) and not attacker._attacking and not attacker._move_intent.is_zero_approx(), "目标在命中节点前脱离射程时仍会取消前摇并追击")
	attacker.free()
	target.free()

func _check_basic_attack_has_no_knockback() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.position = Vector2(300.0, 760.0)
	target.position = Vector2(300.0, 720.0)
	attacker.setup(0, stats, stats.name)
	target.setup(1, stats, stats.name)
	_main.add_child(attacker)
	_main.add_child(target)
	attacker._target = target
	var before := target.position
	attacker.sim_tick(attacker.first_hit_time)
	_expect(attacker.attack_knockback == 0.0 and target.position.is_equal_approx(before) and target._knockback_timer == 0.0, "普通单位对打只造成伤害，不会把目标突然撞退")
	attacker.free()
	target.free()

func _check_freed_target_cleanup() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.position = Vector2(204.0, 800.0)
	target.position = Vector2(204.0, 700.0)
	attacker.setup(0, stats, stats.name)
	target.setup(1, stats, stats.name)
	_main.add_child(attacker)
	_main.add_child(target)
	attacker._target = target
	attacker._attacking = true
	target.free()
	attacker._update_target()
	_expect(attacker._target == null or is_instance_valid(attacker._target), "攻击中的目标释放后安全清理引用并重新索敌")
	attacker.free()

func _check_tower_loses_out_of_range_target() -> void:
	var tower: Tower = _main._towers[0]
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var enemy := Unit.new()
	enemy.position = tower.position + Vector2(0.0, -120.0)
	enemy.setup(1, stats, stats.name)
	_main.add_child(enemy)
	tower.sim_tick(0.2)
	tower.sim_tick(0.05)
	for _i in 20:
		_main._tick_projectiles(_main.SIM_DT)
	var hp_after_hit := enemy.hp
	enemy.position = Vector2(700.0, 40.0)
	for _i in 30:
		tower.sim_tick(0.05)
		_main._tick_projectiles(0.05)
	_expect(enemy.hp == hp_after_hit, "防御塔目标离开射程后停止攻击并脱锁")
	enemy.free()

func _check_landing_body_push_retargets_attacker() -> void:
	var tower: Tower = _main._towers[0]
	var enemy_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var defender_stats: Dictionary = CardDB.get_card("garen").duplicate()
	enemy_stats["deploy_time"] = 0.0
	defender_stats["deploy_time"] = _main.SIM_DT
	var enemy := Unit.new()
	var defender := Unit.new()
	# 放在攻塔射程的外沿内侧，确保落地体积推挤后会真正越出扩大后的塔碰撞圈。
	var initial_tower_distance := tower.body_radius + float(enemy_stats.radius) + float(enemy_stats.range) - 2.0
	var landing_pos := tower.position + Vector2(0.0, -initial_tower_distance)
	enemy.position = landing_pos
	defender.position = landing_pos
	enemy.setup(1, enemy_stats, enemy_stats.name)
	defender.setup(0, defender_stats, defender_stats.name)
	_main.add_child(enemy)
	_main.add_child(defender)
	enemy._target = tower
	enemy._attacking = true
	# 仍处于命中节点之前；若已经命中则新规则要求先完整播放后摇，不能立即转火。
	enemy._attack_windup = _main.SIM_DT * 3.0
	enemy._attack_visual_pending = true
	var before_distance := enemy.position.distance_to(tower.position)
	var overlap_deploy_allowed: bool = _main.is_card_deploy_position_valid(0, "garen", landing_pos)
	_main._sim_step(_main.SIM_DT)
	var pushed_from_tower := enemy.position.distance_to(tower.position) > before_distance + 1.0
	var no_fake_knockback := enemy._knockback_timer == 0.0 and defender._knockback_timer == 0.0
	_main._sim_step(_main.SIM_DT)
	_expect(overlap_deploy_allowed, "部署校验允许在塔前已有可移动单位下方落兵")
	_expect(pushed_from_tower and no_fake_knockback, "大体积单位落地会通过体积/质量把塔前小单位挤开，不伪造击退状态")
	_expect(enemy._target == defender, "攻塔单位被挤出射程后会解锁塔并改为攻击新落地单位")
	enemy.free()
	defender.free()

func _check_destroyed_lane_targets_king() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var blue_left := Unit.new()
	blue_left.position = Vector2(204.0, 520.0)
	blue_left.setup(0, stats, stats.name)
	_main.add_child(blue_left)
	var red_left_hp: float = _main._towers[2].hp
	_main._towers[2].hp = 0.0
	blue_left._update_target()
	_expect(blue_left._target == _main._king_enemy, "左路敌方公主塔摧毁后，同路单位转推敌方水晶而不是跨向右塔")
	_main._towers[2].hp = red_left_hp
	blue_left.free()

	var red_right := Unit.new()
	red_right.position = Vector2(516.0, 760.0)
	red_right.setup(1, stats, stats.name)
	_main.add_child(red_right)
	var blue_right_hp: float = _main._towers[1].hp
	_main._towers[1].hp = 0.0
	red_right._update_target()
	_expect(red_right._target == _main._king_player, "右路我方公主塔摧毁后，敌方单位镜像转推我方水晶而不是跨向左塔")
	_main._towers[1].hp = blue_right_hp
	red_right.free()

func _check_unit_reaches_and_damages_tower() -> void:
	var stats: Dictionary = CardDB.get_card("garen").duplicate(true)
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var tower: Tower = _main._towers[3]
	var unit := Unit.new()
	var stop_distance: float = tower.body_radius + stats.radius + stats.range
	unit.position = tower.position + Vector2.DOWN * (stop_distance + 12.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	unit._target = tower
	var hp_before := tower.hp
	tower.frozen_timer = 5.0
	for _tick in 60:
		_main._sim_step(_main.SIM_DT)
	_expect(tower.hp < hp_before, "攻城单位会补齐 A* 末端距离并对塔造成伤害")
	var hit_ratio := unit.first_hit_time / unit.attack_interval
	_expect(hit_ratio > 0.3 and hit_ratio < 0.4, "盖伦权威命中点提前到完整攻击周期约 35%")
	_expect(unit.get_attack_visual_serial() >= 2, "连续真实攻击会产生递增的独立表现序号")
	var attack_animations: Array = stats.visual_animations.attack
	_expect(attack_animations == ["Attack1", "Attack2"], "盖伦两套攻击动作按表现序号交替选择")
	tower.hp = hp_before
	tower.frozen_timer = 0.0
	if is_instance_valid(unit):
		unit.free()

## 腕豪连招节奏：快速两拳(0.28)→停顿(1.05)→快速两拳(0.28)→停顿(1.05) 循环。
func _check_sett_attack_rhythm() -> void:
	var stats: Dictionary = CardDB.get_card("sett").duplicate(true)
	stats["deploy_time"] = 0.0
	_expect(stats.attack_pattern == [0.28, 1.05, 0.28, 1.05], "腕豪配置了 两拳→停顿→两拳→停顿 的连招节奏")
	var unit := Unit.new()
	unit.setup(0, stats, stats.name)
	# 逐个取出连招间距，验证节奏确实按数组循环
	var expected: Array = [0.28, 1.05, 0.28, 1.05]
	var rhythm_ok := true
	for i in range(8):
		var gap: float = unit._next_attack_gap()
		rhythm_ok = rhythm_ok and is_equal_approx(gap, float(expected[i % expected.size()]))
	_expect(rhythm_ok, "腕豪连招间距按 两拳→停顿→两拳→停顿 依次循环")
	var damage_multipliers: Array = stats.get("attack_damage_multipliers", [])
	var damage_ok := damage_multipliers == [1.0, 1.5, 1.0, 1.5]
	for i in range(4):
		damage_ok = damage_ok and is_equal_approx(unit._attack_damage_multiplier(i), float(damage_multipliers[i]))
	_expect(damage_ok, "腕豪右拳伤害为左拳的1.5倍，并按左右拳循环")
	unit.free()

func _check_king_activation() -> void:
	var king: Tower = _main._king_player
	var princess: Tower = _main._towers[0]
	var saved_hp: float = princess.hp
	var saved_nav_cells: Array = princess.nav_cells.duplicate()
	princess.hp = 0.0
	_main._sim_step(_main.SIM_DT)
	_expect(not king.activated and not king.can_attack, "任一公主塔被摧毁后水晶仍不具备攻击能力")
	# 还原现场：本用例只验证激活规则，恢复血量与导航占用，不向其他领域 suite 泄露“公主塔已摧毁”。
	princess.hp = saved_hp
	if princess.nav_cells.is_empty() and not saved_nav_cells.is_empty():
		princess.nav_cells = saved_nav_cells.duplicate()
		_main.nav.set_cells_blocked(princess.nav_cells, true)
