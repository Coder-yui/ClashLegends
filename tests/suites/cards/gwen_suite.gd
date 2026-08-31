class_name GwenSuite
extends RefCounted
## 格温卡牌领域：丝缕缠流机制、推塔回归与美术接入。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_gwen_mechanic()
	_check_gwen_tower_combat()
	_check_gwen_snip_snip_skill()
	_check_gwen_art_integration()

func _check_gwen_snip_snip_skill() -> void:
	var stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	stats["deploy_time"] = 0.0
	var skill: Dictionary = stats.active_skill
	var gwen := Unit.new()
	gwen.position = Vector2(360.0, 900.0)
	gwen.setup(0, stats, stats.name)
	_main.add_child(gwen)
	gwen.on_attack_landed()
	var disabled_without_loadout := not gwen.is_skill_resource_visible() and is_zero_approx(gwen.skill_resource_value)
	gwen.configure_carried_active_skill(skill)
	for _hit in range(3):
		gwen.on_attack_landed()
	var charged_full := is_equal_approx(gwen.skill_resource_value, 3.0)
	var prepared_full: Dictionary = _main._active_skill_effect_system.prepare_cast(gwen, skill)
	var full_tier := (
		charged_full and is_zero_approx(gwen.skill_resource_value)
		and is_equal_approx(float(prepared_full.damage), 160.0)
		and String(prepared_full.visual_action) == "active_strong"
		and is_equal_approx(float(prepared_full.cast_duration), 2.8000002)
	)
	var partial := Unit.new()
	partial.position = Vector2(560.0, 900.0)
	partial.setup(0, stats, stats.name)
	partial.configure_carried_active_skill(skill)
	partial.add_skill_resource(2.0)
	_main.add_child(partial)
	var prepared_partial: Dictionary = _main._active_skill_effect_system.prepare_cast(partial, skill)
	_expect(
		disabled_without_loadout and full_tier
		and is_equal_approx(float(prepared_partial.damage), 120.0)
		and String(prepared_partial.visual_action) == "active",
		"格温只有携带快刀乱剪时普攻命中才充能；0~3 层读取对应伤害，满层选择 Spell1 0→B→C 并消耗全部层数",
	)
	var dummy_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	var center := Unit.new()
	var edge := Unit.new()
	var behind := Unit.new()
	center.position = Vector2(360.0, 790.0)
	edge.position = Vector2(414.0, 790.0)
	behind.position = Vector2(360.0, 990.0)
	for target in [center, edge, behind]:
		target.setup(1, dummy_stats, "剪切木桩")
		_main.add_child(target)
	gwen.begin_active_skill_cast(float(prepared_full.cast_duration), Vector2.UP, prepared_full.cast_locks)
	var center_before := center.hp
	var edge_before := edge.hp
	var behind_before := behind.hp
	_main._active_skill_effect_system.apply(gwen, prepared_full)
	_expect(
		is_equal_approx(center_before - center.hp, 160.0 * 1.2)
		and is_equal_approx(edge_before - edge.hp, 160.0)
		and is_equal_approx(behind.hp, behind_before)
		and gwen.is_active_skill_movement_locked() and gwen.is_active_skill_attack_locked() and gwen.is_active_skill_facing_locked(),
		"格温快刀乱剪锁定行动并命中前方扇形，中央区域造成 1.2 倍伤害且不命中身后",
	)
	_main._battle_presentation.attach_unit(gwen, stats)
	var view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == gwen:
			view = child as UnitModel3D
			break
	var animation_chain := false
	if view != null:
		gwen.play_visual_action(&"active_strong", float(prepared_full.cast_duration))
		view._sync_visual(false, 0.05)
		var clip_0 := view._animation_player.current_animation == "Spell1_0"
		view._on_animation_finished(&"Spell1_0")
		var clip_b := view._animation_player.current_animation == "Spell1_B"
		view._on_animation_finished(&"Spell1_B")
		var clip_c := view._animation_player.current_animation == "Spell1_C_anm"
		gwen.active_skill_cast_timer = 0.0
		gwen.active_skill_cast_locks.clear()
		gwen._move_intent = Vector2.UP * gwen.move_speed
		view._on_animation_finished(&"Spell1_C_anm")
		var transition_entry_short := (
			view._animation_player.current_animation == "Spell1_C_to_Run_anm"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"sequence"))
		)
		view._on_animation_finished(&"Spell1_C_to_Run_anm")
		var transition_to_run_short := (
			view._animation_player.current_animation == "Run_anm"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"sequence"))
		)
		animation_chain = clip_0 and clip_b and clip_c and transition_entry_short and transition_to_run_short
	_expect(animation_chain, "格温满层技能播放 Spell1 0→B→C，技能后移动直接衔接 Spell1 C ToRun；普通移动入口配置 Into Run")
	for unit in [gwen, partial, center, edge, behind]:
		if is_instance_valid(unit):
			unit.free()

func _check_gwen_mechanic() -> void:
	var gwen_stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	var enemy_stats: Dictionary = CardDB.get_card("xin").duplicate(true)
	gwen_stats["deploy_time"] = 0.0
	gwen_stats["hp"] = 1000.0
	enemy_stats["deploy_time"] = 0.0
	var gwen := Unit.new()
	var foe := Unit.new()
	gwen.position = Vector2(300.0, 800.0)
	foe.position = Vector2(300.0, 760.0)
	gwen.setup(0, gwen_stats, gwen_stats.name)
	foe.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(gwen)
	_main.add_child(foe)
	_expect(is_equal_approx(gwen.shroud_radius, 120.0), "格温缠流半径读取为 3 格（120px）")
	# 未开启时：圈外敌方能看到她，攻击造成完整伤害
	var far := Unit.new()
	far.position = Vector2(300.0, 660.0)   # 距 gwen 140px > 120，属圈外
	far.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(far)
	_expect(not gwen.is_hidden_from(far), "未开启时，圈外敌方能看到格温")
	_expect(far._target_is_attackable(gwen), "未开启时，圈外敌方能把格温锁定为目标")
	far.free()
	# 首次普攻命中 → 开启丝缕缠流
	var activated := false
	for _i in 60:
		_main._sim_step(_main.SIM_DT)
		if gwen._shroud_active:
			activated = true
			break
	_expect(activated, "格温首次普攻命中后开启丝缕缠流")
	_expect(gwen._shroud_active, "锁定在攻中时，缠流处于开启状态")
	# 开启后：圈外敌方/塔看不到她，无法锁定、不会攻击
	far = Unit.new()
	far.position = Vector2(300.0, 660.0)
	far.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(far)
	_expect(gwen.is_hidden_from(far), "开启后，圈外敌方看不到格温")
	_expect(not far._target_is_attackable(gwen), "开启后，圈外敌方不会把格温锁定为目标")
	far._target = gwen
	far._attacking = false
	far._update_target()
	_expect(far._target != gwen, "正在圈外追击的敌方会立即丢失格温并重新行动")
	var tower := Tower.new()
	tower.team = 1
	tower.position = Vector2(300.0, 620.0)
	_main.add_child(tower)
	_expect(gwen.is_hidden_from(tower), "开启后，圈外塔也看不到格温")
	tower.free()
	# 圈内的敌方仍能看到并攻击
	var near := Unit.new()
	near.position = Vector2(300.0, 760.0)   # 距 40px < 100，属圈内
	near.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(near)
	_expect(not gwen.is_hidden_from(near), "圈内敌方能看到格温")
	var in_hp := gwen.hp
	_main.launch_attack(near, gwen, 30.0, 0.0, 0.0, 0.0, near.color)
	_expect(gwen.hp == in_hp - 30.0, "圈内敌方的攻击仍然生效")
	# 弹体已在空中、格温随后开启缠流 → 圈外弹体立即失去目标并消散。
	# 隔离：清掉圈内目标保证飞行期间 hp 只受这支弹体影响；foe 保留存活以维持格温攻击态。
	near.free()
	foe.damage = 0.0   # foe 只在圈内站桩，确保攻击态持续但不产生正常伤害
	gwen._shroud_active = false
	var inb_hp := gwen.hp
	var shooter := Unit.new()
	shooter.position = Vector2(300.0, 600.0)   # 距 200px，圈外射手
	shooter.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(shooter)
	_main.launch_attack(shooter, gwen, 50.0, 600.0, 0.0, 0.0, shooter.color)
	var launched_before_shroud: bool = not _main._projectiles.is_empty()
	gwen.on_attack_landed()
	_main._tick_projectiles(_main.SIM_DT)
	_expect(launched_before_shroud and _main._projectiles.is_empty() and gwen.hp == inb_hp, "弹体飞行中开启缠流时，圈外弹体立即消散且不造成伤害")
	# 攻击者在弹体飞行途中死亡，仍使用其最后位置判断，不能因来源节点释放而穿透缠流。
	gwen._shroud_active = false
	_main.launch_attack(shooter, gwen, 50.0, 600.0, 0.0, 0.0, shooter.color)
	var launched_before_source_freed: bool = not _main._projectiles.is_empty()
	shooter.free()
	gwen.on_attack_landed()
	_main._tick_projectiles(_main.SIM_DT)
	_expect(launched_before_source_freed and _main._projectiles.is_empty() and gwen.hp == inb_hp, "攻击者死亡后，弹体仍按最后来源位置被缠流拦截")
	# 缠流已经开启时，圈外来源不能创建新的弹体。
	var blocked_shooter := Unit.new()
	blocked_shooter.position = Vector2(300.0, 600.0)
	blocked_shooter.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(blocked_shooter)
	_main.launch_attack(blocked_shooter, gwen, 50.0, 600.0, 0.0, 0.0, blocked_shooter.color)
	_expect(_main._projectiles.is_empty(), "缠流开启后，圈外攻击者无法继续向格温发射弹体")
	blocked_shooter.free()
	# 目标死亡 → 退出攻击状态 → 关闭缠流，敌方又能看到并攻击
	far.free()
	foe.hp = 0.0
	foe.queue_free()
	for _i in 20:
		_main._sim_step(_main.SIM_DT)
	_expect(not gwen._shroud_active, "目标死亡、格温退出攻击状态后缠流关闭")
	var observer := Unit.new()
	observer.position = Vector2(300.0, 660.0)
	observer.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(observer)
	_expect(not gwen.is_hidden_from(observer), "缠流关闭后，圈外敌方又能看到格温")
	observer.free()
	gwen.free()

## 缠流扩大到 3 格后的推塔回归：格温贴身攻击时，公主塔心距她 ≤ 54+18+30=102px、
## 水晶心距她 ≤ 72+18+30=120px，都落在 120px 缠流圈内 → 塔和水晶能看见她并反击，
## 修复旧版 100px 半径下"圈外塔心看不到格温"导致的无伤推塔。
func _check_gwen_tower_combat() -> void:
	var gwen_stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	gwen_stats["deploy_time"] = 0.0
	gwen_stats["hp"] = 100000.0
	# —— 场景一：攻击敌方公主塔 ——
	var tower: Tower = _main._towers[3]
	var stop_distance: float = tower.body_radius + gwen_stats.radius + gwen_stats.range
	var gwen := Unit.new()
	gwen.position = tower.position + Vector2.DOWN * (stop_distance + 12.0)
	gwen.setup(0, gwen_stats, gwen_stats.name)
	_main.add_child(gwen)
	gwen._target = tower
	var tower_hp := tower.hp
	var gwen_hp := gwen.hp
	for _tick in 100:
		_main._sim_step(_main.SIM_DT)
	_expect(gwen._shroud_active, "格温攻击公主塔首次命中后开启丝缕缠流")
	_expect(tower.hp < tower_hp, "格温对公主塔持续输出")
	_expect(gwen.hp < gwen_hp, "缠流开启后，贴身的公主塔仍在圈内，能看见并反击格温")
	# 塔也接入受击闪白：3D 代理收到限频表现事件，且闪白强度已减淡。
	var tower_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == tower:
			tower_view = child as TowerModel3D
			break
	_expect(tower_view != null and tower_view._hit_flash_timer > 0.0 and tower_view._hit_flash_timer <= TowerModel3D.HIT_FLASH_DURATION, "公主塔受击后 3D 模型同步轻微闪白")
	gwen.free()
	tower.hp = tower_hp
	# —— 场景二：攻击敌方水晶（国王塔）——
	# 冻结两座敌方公主塔做隔离，保证水晶战斗期间对格温的伤害只可能来自水晶。
	var left_princess: Tower = _main._towers[2]
	left_princess.freeze(999.0)
	tower.freeze(999.0)
	var king: Tower = _main._king_enemy
	var king_was_active := king.activated
	var king_hp := king.hp
	var king_stop: float = king.body_radius + gwen_stats.radius + gwen_stats.range
	var attacker := Unit.new()
	attacker.position = king.position + Vector2.DOWN * (king_stop + 12.0)
	attacker.setup(0, gwen_stats, gwen_stats.name)
	_main.add_child(attacker)
	attacker._target = king
	var attacker_hp := attacker.hp
	for _tick in 100:
		_main._sim_step(_main.SIM_DT)
	_expect(attacker._shroud_active, "格温攻击水晶首次命中后开启丝缕缠流")
	_expect(king.hp < king_hp, "格温对水晶持续输出")
	_expect(not king.activated, "水晶受到攻击后仍不激活攻击能力")
	_expect(is_equal_approx(attacker.hp, attacker_hp), "水晶不索敌、不发射弹体也不造成伤害")
	# 水晶同样接入受击闪白表现。
	var king_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == king:
			king_view = child as TowerModel3D
			break
	_expect(king_view != null and king_view._hit_flash_timer > 0.0, "水晶受击后 3D 模型同步轻微闪白")
	attacker.free()
	# 还原现场：公主塔解冻、水晶回到初始血量与休眠状态，不影响后续测试。
	left_princess.frozen_timer = 0.0
	tower.frozen_timer = 0.0
	king.hp = king_hp
	king.activated = king_was_active

func _check_gwen_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var model_node := sample.get_node_or_null("Model") as Node3D
	_expect(model_node != null and is_equal_approx(model_node.position.y, -0.045), "格温放大后脚底校正同步缩放，模型仍落在地面")
	var attacks: Array = anim_names.attack
	_expect(attacks == ["Attack1", "Attack2", "Attack3"], "格温三套攻击动作按表现序号交替选择")
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			death_view_found = view._dying and view._animation_player.current_animation == "Death"
			view.free()
			break
	_expect(attached and death_view_found, "格温死亡时由独立 3D 代理播放 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()
