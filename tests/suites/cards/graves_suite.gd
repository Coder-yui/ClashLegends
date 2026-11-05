extends "res://tests/suites/battle_suite.gd"
func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	var errors := CardDB.validate_all(false)
	_expect(errors.is_empty(), "全卡定义合同：" + str(errors))
	_check_magazine()
	_check_pellets()
	_check_approach_spread()
	_check_dash()
	_check_paid_skill()
	_check_invalid()
	_main.free()

func _clear() -> void:
	_main._projectile_system.clear_all()
	for unit in _main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()

func _check_magazine() -> void:
	var actor := _spawn_ready_unit("graves", 0, Vector2(300, 950))
	var victim := _spawn_ready_unit("target_dummy", 1, Vector2(380, 950))
	victim.hp = 10000
	victim.max_hp = 10000
	actor.move_speed = 0.0
	_expect(actor.magazine.rounds == 2, "普通槽出生满两发")
	for i in 3: actor.sim_tick(0.05)
	_expect(actor.magazine.rounds == 1 and _main._projectile_system.projectiles.size() == 6, "第三Tick正式发射6发且只消费1颗弹药")
	for i in 18: actor.sim_tick(0.05)
	_expect(actor.magazine.rounds == 0 and actor.magazine.remaining > 1.9, "两枪间隔0.9秒后开始空弹匣换弹")
	var serial := actor.basic_attack_sequence
	for i in 39: actor.sim_tick(0.05)
	_expect(actor.magazine.rounds == 0 and actor.basic_attack_sequence == serial, "空弹匣未满40Tick禁止普攻")
	actor.sim_tick(0.05)
	_expect(actor.magazine.rounds == 2, "2秒到期补满弹匣")
	actor.magazine.rounds = 1
	actor.magazine.remaining = 0.0
	victim.position = Vector2(650, 1050)
	actor.cancel_basic_attack(ActionCancellation.STUN)
	actor.sim_tick(0.05)
	_expect(actor.magazine.remaining == 2.0, "离开攻击状态剩1发自动开始移动换弹")
	actor.magazine.remaining = 1.0
	victim.position = Vector2(380, 950)
	for i in 3: actor.sim_tick(0.05)
	_expect(actor.magazine.rounds == 0 and actor.magazine.remaining == 2.0, "有子弹时目标入射程立即取消旧换弹并完成普攻前摇")
	actor.freeze(0.3)
	var reload_left := actor.magazine.remaining
	actor.sim_tick(0.05)
	_expect(actor.magazine.remaining == reload_left, "冰冻暂停换弹")
	actor.magazine.restore(1)
	_expect(actor.magazine.rounds == 1 and actor.magazine.remaining == 0.0, "主动补弹取消空匣换弹")
	actor.magazine.restore(9)
	_expect(actor.magazine.rounds == 2, "补弹不超过容量")
	_clear()
	actor = _spawn_ready_unit("graves", 0, Vector2(300, 950))
	victim = _spawn_ready_unit("target_dummy", 1, Vector2(380, 950))
	actor.blind_attack_charges = 1
	for i in 3: actor.sim_tick(0.05)
	_expect(actor.magazine.rounds == 1 and actor.blind_attack_charges == 0 and _main._projectile_system.projectiles.is_empty(), "致盲按整枪消费1弹，不生成6颗伤害弹丸")
	actor.magazine.start(actor)
	actor.stun(0.5)
	actor.sim_tick(0.05)
	_expect(actor.magazine.remaining == 2.0, "眩晕暂停换弹进度")
	_clear()

func _check_approach_spread() -> void:
	for card in ["ashe", "teemo", "imp"]:
		var actor := _spawn_ready_unit("graves", 0, Vector2(240, 980))
		var target := _spawn_ready_unit(card, 1, Vector2(240, 750))
		target.max_hp = 10000
		target.hp = 10000
		target.can_attack = false
		target.move_speed = 0.0
		for i in 120:
			_main._sim_step(0.05)
			if actor.magazine.rounds == 1: break
		_expect(actor.position.y < 980 and actor.magazine.rounds == 1, card + " 正面走入射程开第一枪")
		for i in 6: _main._tick_projectiles(0.05)
		var hits := (10000.0 - target.hp) / 28.0
		print("[Graves approach] ", card, " pos=", actor.position, " target=", target.position, " hits=", hits)
		_expect(hits > 0 and hits < 6, card + " 射程边缘部分命中：" + str(hits))
		var before := target.hp
		actor.position = target.position + Vector2.DOWN * (actor.body_radius + target.body_radius)
		_shoot(actor, target)
		for i in 6: _main._tick_projectiles(0.05)
		_expect(before - target.hp == 168, card + " 贴身六颗全中")
		_clear()

func _shoot(actor: Unit, target: Unit) -> void:
	SuiteUtils.begin_attack_visual(actor, target)
	_main._projectile_system.launch(actor, target, 28.0, 900.0, 0.0, 12.0, actor.color)

func _check_pellets() -> void:
	var actor := _spawn_ready_unit("graves", 0, Vector2(200, 950))
	var victim := _spawn_ready_unit("garen", 1, Vector2(250, 950))
	victim.hp = 10000
	victim.max_hp = 10000
	var behind := _spawn_ready_unit("target_dummy", 1, Vector2(340, 950))
	var ally := _spawn_ready_unit("target_dummy", 0, Vector2(230, 950))
	var old_hp := victim.hp
	var behind_hp := behind.hp
	var ally_hp := ally.hp
	_shoot(actor, victim)
	_expect(_main._projectile_system.projectiles.size() == 6 and victim.hp == old_hp, "发射创建6枚独立在途弹丸且不提前伤害")
	for i in 6: _main._tick_projectiles(0.05)
	_expect(victim.hp == old_hp - 168.0, "贴身六发分别命中同一目标，共168伤害")
	_expect(behind.hp == behind_hp and ally.hp == ally_hp, "前排挡住后排且不伤友军")
	victim.position = Vector2(390, 950)
	behind.position = Vector2(600, 1150)
	old_hp = victim.hp
	_shoot(actor, victim)
	for i in 6: _main._tick_projectiles(0.05)
	_expect(victim.hp < old_hp and victim.hp > old_hp - 168.0, "远距离扇形分散，单体伤害下降")
	victim.position = Vector2(300, 950)
	_shoot(actor, victim)
	victim.position = Vector2(300, 1100)
	old_hp = victim.hp
	for i in 6: _main._tick_projectiles(0.05)
	_expect(victim.hp == old_hp and _main._projectile_system.projectiles.is_empty(), "发射后目标横移可躲开，弹丸不追踪并在固定距离消失")
	victim.position = Vector2(250, 950)
	victim.mass = 2.0
	_shoot(actor, victim)
	for i in 2: _main._tick_projectiles(0.05)
	_expect(victim._knockback_timer > 0.0, "轻单位真实命中获得击退")
	victim.knockback.cancel(&"test")
	victim.mass = 4.0
	_shoot(actor, victim)
	for i in 2: _main._tick_projectiles(0.05)
	_expect(victim._knockback_timer == 0.0, "质量4及以上不被击退")
	victim.is_air = true
	old_hp = victim.hp
	_shoot(actor, victim)
	actor.take_damage(99999.0)
	for i in 6: _main._tick_projectiles(0.05)
	_expect(victim.hp == old_hp - 168.0, "可对空且来源死亡不撤销独立弹丸")
	_clear()

func _dash(actor: Unit, direction: Vector2, length: float = -1.0) -> BoundedDashState:
	var skill: Dictionary = CardDB.active_skills_for("graves")[0].duplicate(true)
	if length > 0: skill.length = length
	actor.begin_active_skill_cast(0.4, -direction)
	return BoundedDashState.new(actor, skill)

func _check_dash() -> void:
	for team in [0, 1]:
		var actor := _spawn_ready_unit("graves", team, Vector2(300, 950))
		actor.magazine.rounds = 0
		actor.magazine.remaining = 1.0
		var dash := _dash(actor, Vector2.RIGHT)
		_expect(actor.magazine.rounds == 1 and actor.magazine.remaining == 0.0, "双方技能起手补1弹并取消换弹")
		for i in 8: dash.tick(0.05)
		_expect(actor.position.distance_to(Vector2(420, 950)) < 0.01 and not actor.skill_dash_active, "双方0.4秒后撤120px并释放行动锁")
		actor.position = Vector2(360, 565)
		dash = _dash(actor, Vector2.DOWN)
		for i in 8: dash.tick(0.05)
		_expect(actor.position.y > 685 and actor.position.y <= 748.001 and UnitLandingQuery.displacement_legal(actor, actor.position), "预算足够跨河且合法落地")
		actor.position = Vector2(360, 565)
		dash = _dash(actor, Vector2.DOWN, 60.0)
		for i in 8: dash.tick(0.05)
		_expect(actor.position.y < 600 and UnitLandingQuery.displacement_legal(actor, actor.position), "距离不足在河岸前停下，绝不延长距离")
		actor.position = Vector2(250, 950)
		var building := _spawn_ready_unit("tombstone", 1-team, Vector2(330, 950))
		dash = _dash(actor, Vector2.RIGHT)
		for i in 8: dash.tick(0.05)
		_expect(actor.position.x > 370 and actor.position.x <= 433.001 and UnitLandingQuery.displacement_legal(actor, actor.position), "足够距离跨建筑")
		actor.position = Vector2(250, 950)
		dash = _dash(actor, Vector2.RIGHT, 40.0)
		for i in 8: dash.tick(0.05)
		_expect(actor.position.x < 300 and UnitLandingQuery.displacement_legal(actor, actor.position), "不足距离在建筑前停下")
		building.free()
		actor.position = Vector2(300, 950)
		dash = _dash(actor, Vector2.RIGHT)
		dash.tick(0.05)
		actor.freeze(1.0)
		var stop := actor.position
		_expect(not dash.tick(0.05) and actor.position == stop and not actor.skill_dash_active, "冰冻取消自主位移，不恢复剩余路程")
		_clear()

func _check_invalid() -> void:
	for pair in [["magazine_size", 0], ["magazine_size", "two"], ["reload_duration", -1.0], ["attack_pellets", 1], ["attack_pellets", 2.5], ["attack_pellet_arc", 200.0], ["attack_pellet_distance", 0.0]]:
		var bad: Dictionary = CardDB.get_card("graves").duplicate(true)
		bad[pair[0]] = pair[1]
		_expect(not CardDB.VALIDATOR.validate_all({"graves": bad}, false).is_empty(), "拒绝非法参数：" + str(pair))
	var bad: Dictionary = CardDB.get_card("graves").duplicate(true)
	bad.active_skills[0].dash_backward = "yes"
	_expect(not CardDB.VALIDATOR.validate_all({"graves": bad}, false).is_empty(), "后撤必须为布尔")

func _check_paid_skill() -> void:
	for team in [0, 1]:
		var wallet := ElixirManager.new()
		_main.add_child(wallet)
		_main.runtime.bind_account(team, wallet)
	var old_deck: Array = _main.runtime._deck.duplicate()
	_main.runtime._deck = ["graves", "garen", "ashe", "teemo", "xin", "freeze", "heal", "pix"]
	var actor: Unit = _main.runtime._spawn_card_units(0, "graves", Vector2(300, 1000), 0.0, 0)[0]
	actor._deploy_timer = 0.0
	var id := actor.active_ability_id
	for use in 2:
		actor.magazine.rounds = 0
		actor.magazine.remaining = 1.5
		_main.runtime.account(0).elixir = 9.0
		_expect(_main.use_active_skill(id, 0), "正式技能请求接受")
		_expect(not _main.use_active_skill(id, 0), "排队请求去重")
		_expect(_main.runtime.account(0).elixir == 8.0, "请求仅扣1金币")
		_main.runtime._sim_tick_id += 10
		_main.runtime._tick_pending_active_skills(0.05)
		var entry: Dictionary = _main.runtime._active_skills.entry(id)
		_expect(entry.uses_remaining == 1-use and entry.cooldown_left == 8.0, "真正开始消费次数并启动8秒冷却")
		_expect(not _main.use_active_skill(id, 0), "冷却/耗尽拒绝释放")
		_run_main_ticks(1)
		_expect(actor.magazine.rounds == 1 and actor.magazine.remaining == 0.0, "正式效果节点补1弹取消换弹")
		_run_main_ticks(161)
	_expect(not _main.use_active_skill(id, 0), "两次耗尽后不能再次释放")
	_main.runtime._deck = old_deck
	_clear()
