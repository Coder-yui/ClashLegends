extends "res://tests/suites/battle_suite.gd"

func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	for team in 2:
		_check_box(team)
	_check_native_visuals()
	var wallet := ElixirManager.new()
	_main.add_child(wallet)
	_main.runtime.bind_account(0, wallet)
	_main.runtime._deck = ["jack_in_the_box", "garen", "xin", "ashe", "teemo", "gnar", "heal", "freeze"]
	wallet.elixir = 10
	var box: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "jack_in_the_box", Vector2(360, 800), {"active_slot": 0, "deploy_time_override": 0.0}))
	var ability: int = box.active_ability_id
	_expect(_main.use_active_skill(ability, 0), "惊吓正式入口接受第一次请求")
	_expect(wallet.elixir == 9, "惊吓请求扣1金币")
	_main.runtime._sim_tick_id += _main.COMMAND_DELAY_TICKS
	_main.runtime._tick_pending_active_skills(0.05)
	_expect(not _main.use_active_skill(ability, 0), "冷却期间拒绝再次请求")
	_main.runtime._tick_active_skill_cooldowns(10.0)
	_expect(_main.use_active_skill(ability, 0), "10秒冷却结束可使用第二次")
	_main.runtime._sim_tick_id += _main.COMMAND_DELAY_TICKS
	_main.runtime._tick_pending_active_skills(0.05)
	_main.runtime._tick_active_skill_cooldowns(10.0)
	_expect(not _main.use_active_skill(ability, 0) and wallet.elixir == 8, "两次用尽后拒绝请求且不再扣费")
	_main.free()

func _check_box(team: int) -> void:
	var box: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "jack_in_the_box", Vector2(360, 800)))
	var enemy := _spawn_ready_unit("target_dummy", 1 - team, Vector2(460, 800))
	var air := _spawn_ready_unit("pix", 1 - team, Vector2(360, 700))
	var ally := _spawn_ready_unit("target_dummy", team, Vector2(260, 800))
	var outside := _spawn_ready_unit("target_dummy", 1 - team, Vector2(650, 800))
	for unit in [enemy, air, ally, outside]: unit.move_speed = 0.0
	_expect(box.stealth_hidden() and not enemy._target_is_attackable(box), "出生即隐身且敌人无法新锁定")
	box.take_damage(10, enemy)
	_expect(box.stealth_hidden(), "范围伤害不破隐")
	for i in 19: box.sim_tick(0.05)
	_expect(box.stealth_hidden() and enemy.control.stun_timer == 0, "部署未完成不激活")
	box.sim_tick(0.05)
	_expect(not box.stealth_hidden() and enemy._target_is_attackable(box), "完成部署时发现敌人立即破隐")
	_expect(enemy.control.stun_timer == 1.0 and air.control.stun_timer == 1.0, "首次激活同时眩晕地面与空军1秒")
	_expect(ally.control.stun_timer == 0 and outside.control.stun_timer == 0, "激活不影响友军与范围外敌人")
	enemy.control.hard.clear_family(&"stun")
	box._try_proximity_reveal()
	box.stealth.sync_idle(100.0)
	_expect(not box.stealth_hidden() and enemy.control.stun_timer == 0, "破隐永久且激活不重复")
	var system: ProjectileSystem = _main._projectile_system
	system.clear_all()
	box._perform_attack_strike(enemy, 50.0)
	_expect(system.projectiles.size() == 2, "全目标齐射对每个范围内敌人生成独立弹体")
	for shot in system.projectiles.values(): _expect(shot.damage == 50.0, "多目标每发50伤害")
	system.clear_all()
	air.position = Vector2(650, 500)
	box._perform_attack_strike(enemy, 50.0)
	_expect(system.projectiles.size() == 1 and system.projectiles.values()[0].damage == 100.0, "单目标伤害100")
	air.position = Vector2(360, 700)
	_expect(system.projectiles.values()[0].damage == 100.0, "出手后进入第二目标不改变在途伤害")
	system.clear_all()
	box.blind_attack_charges = 1
	box._perform_attack_strike(enemy, 50.0)
	_expect(box.blind_attack_charges == 0 and system.projectiles.is_empty(), "一次致盲取消整次齐射且只消耗一层")
	air.control.hard.clear_family(&"stun")
	air.apply_stasis(2.0)
	box._perform_attack_strike(enemy, 50.0)
	_expect(system.projectiles.size() == 1 and system.projectiles.values()[0].damage == 100.0, "凝滞敌人不计入目标数")
	system.clear_all()
	enemy.control.hard.clear_family(&"stun")
	_main._active_skill_effect_system.apply(box, CardDB.active_skills_for("jack_in_the_box")[0])
	_expect(enemy.control.stun_timer == 1.0 and air.control.stun_timer == 0, "主动群晕生效且凝滞拒绝")
	for i in 19: enemy._tick_active_statuses(0.05)
	_expect(enemy.control.stun_timer > 0, "1秒眩晕第19Tick尚未结束")
	enemy._tick_active_statuses(0.05)
	_expect(enemy.control.stun_timer <= 0.000001, "1秒眩晕第20Tick结束")
	box.body_radius = 40.0
	enemy.position = box.position + Vector2(210, 0)
	_main._active_skill_effect_system.apply(box, CardDB.active_skills_for("jack_in_the_box")[0])
	_expect(enemy.control.stun_timer == 1.0, "体型增益后主动按当前攻击边缘计算范围")
	for unit in [box, enemy, air, ally, outside]: unit.free()
	box = _spawn_ready_unit("jack_in_the_box", team, Vector2(360, 800))
	enemy = _spawn_ready_unit("target_dummy", 1 - team, Vector2(460, 800))
	box.freeze(1.0)
	box.sim_tick(0.05)
	_expect(box.stealth_hidden(), "冰冻时不提前触发埋伏")
	box.control.hard.clear_family(&"freeze")
	box.sim_tick(0.05)
	_expect(not box.stealth_hidden(), "控制解除后仍可触发埋伏")
	box.free()
	enemy.free()

func _check_native_visuals() -> void:
	var box := _spawn_ready_unit("jack_in_the_box", 0, Vector2(360, 800))
	var view = load("res://assets/units/jack_in_the_box/box_view.tscn").instantiate()
	_main.add_child(view)
	view.configure_unit_visual(box)
	box.presentation_cue.emit(&"stealth:exit")
	_expect(view._effects.size() == 1, "破隐只创建原皮W的四层范围爆发")
	_expect(is_equal_approx(view._effects[0].player.scale.x * 373.0 * 40.0, 160.0), "主可见波纹标定为160像素4格半径")
	var kinds: Array = []
	for effect in view._effects: kinds.append(effect.player._data.emitters.size())
	view.sync_combat_visual(box.presentation_state(), 2.1, false)
	_expect(view._effects.is_empty(), "破隐完整寿命后释放全部原版表现")
	box.presentation_cue.emit(&"active:impact")
	var active_kinds: Array = []
	for effect in view._effects: active_kinds.append(effect.player._data.emitters.size())
	_expect(active_kinds == kinds and kinds == [4], "主动技能复用同一原皮W完整四层特效")
	view.sync_combat_visual(box.presentation_state(), 0.05, true)
	_expect(view._effects.is_empty(), "死亡立即清理范围爆发粒子")
	view.configure_unit_visual(box)
	view.configure_unit_visual(box)
	box.presentation_cue.emit(&"active:impact")
	_expect(view._effects.size() == 1, "重复配置不重复订阅事件")
	view.free()
	box.free()
	_check_missile_births()

func _check_missile_births() -> void:
	var missile = load("res://assets/effects/jack_in_the_box/player.gd").new()
	_main.add_child(missile)
	missile.load_kind("missile")
	missile.setup_native(0.007)
	missile.seek_motion(0.0, Vector3.ZERO, Basis.IDENTITY)
	missile.seek_motion(0.05, Vector3(1,0,0), Basis.IDENTITY)
	var positions: Array = []
	for key in missile._birth_positions:
		if key.x == 0: positions.append(missile._birth_positions[key].origin.x)
	positions.sort()
	_expect(positions.size() >= 3 and positions[0] < positions[-1], "同一权威Tick新生拖尾按出生时刻分布，不堆叠成一个点")
	var retained: Dictionary = missile._birth_positions.duplicate()
	missile.seek_motion(0.10, Vector3(2,0,0), Basis.IDENTITY)
	var preserved := true
	for key in retained:
		if missile._birth_positions.has(key): preserved = preserved and retained[key] == missile._birth_positions[key]
	_expect(preserved, "后续移动保留旧拖尾世界位置")
	missile.seek_motion(0.0, Vector3(10,0,0), Basis.IDENTITY)
	_expect(missile._motion_previous.origin == Vector3(10,0,0), "回放重置出生历史")
	missile.free()
