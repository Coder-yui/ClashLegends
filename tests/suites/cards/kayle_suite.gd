extends "res://tests/suites/battle_suite.gd"
## 支付边界、排程形态锁定、主动资格及真实在途光剑与焰浪。
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	main._deck = ["kayle", "garen", "ashe", "teemo", "xin", "freeze", "heal", "pix"]
	for tower in main._towers: tower.can_attack = false
	for money in [2.99, 3.0, 5.99, 6.0, 10.0]:
		_clear()
		preload("res://tests/suites/network_fixture.gd").fixed_cycle(main, 0, main._deck)
		main._elixir.elixir = money
		var expected_id := "kayle_ranged" if money >= 6 else "kayle"
		var cost := 6 if money >= 6 else 3
		_expect(main.card_cost_for_team(0, "kayle") == cost, "费用在6金币边界同步切换")
		_expect(main._hand._display_cost("kayle", CardDB.get_card("kayle")) == cost, "手牌费用与权威一致")
		var accepted: bool = main.play_card(0, "kayle", Vector2(300, 900), {"elixir": main._elixir})
		_expect(accepted == (money >= 3), "不足3拒绝，足够3接受")
		if not accepted:
			_expect(main._commands.inspect_cards().is_empty() and is_equal_approx(main._elixir.elixir, money), "拒绝不扣费不入队")
			continue
		_expect(is_equal_approx(main._elixir.elixir, money - cost), "只扣所选形态实际费用")
		var command: Dictionary = main._commands.inspect_cards()[0]
		main._elixir.elixir = 10 if money < 6 else 0
		main._sim_tick_id = int(command.execute_tick)
		main._tick_pending_card_deployments(0.05)
		var unit: Unit = main._latest_unit_for_card("kayle", 0)
		_expect(unit != null and unit.card_id == expected_id, "等待期间跨过6金币仍保持付款形态")
		_expect(unit.active_skill_card_id == "kayle" and unit.active_ability_id >= 0, "衍生形态保留下牌与主动槽资格")
		_expect(unit.is_air and unit.can_attack_air, "两种形态都为空军并可对空")
		unit._deploy_timer = 0
		unit.hp = 100
		var ability := unit.active_ability_id
		_expect(main.use_active_skill(ability, 0), "W正式排程接受")
		var before: float = main._elixir.elixir
		for _i in 11:
			main._sim_tick_id += 1
			main._tick_pending_active_skills(0.05)
			main._commands.tick_impacts(0.05)
		_expect(unit.hp == 260 and is_equal_approx(unit.active_speed_multiplier, 1.3), "W实际开始治疗160并加速30%")
		_expect(main._elixir.elixir == before, "W不消耗金币")
		_expect(not main.use_active_skill(ability, 0), "6秒冷却不能连续施放")
		unit._tick_active_statuses(0.95)
		_expect(is_equal_approx(unit.active_speed_multiplier, 1.3), "加速前19Tick仍生效")
		unit._tick_active_statuses(0.05)
		_expect(is_equal_approx(unit.active_speed_multiplier, 1.0), "20Tick后加速结束")
		unit.prepare_action_clocks(1.0)
		main._tick_active_skill_cooldowns(6.0)
		_expect(main.use_active_skill(ability, 0), "冷却结束可以第二次释放")
		main._sim_tick_id += 10
		main._tick_pending_active_skills(0.05)
		main._commands.tick_impacts(0.05)
		_expect(unit.hp == 420, "第二次再回复160生命")
		main._tick_active_skill_cooldowns(6.0)
		_expect(not main.use_active_skill(ability, 0), "两次耗尽后不能再用")
	_clear()
	var ranged: Unit = main._spawn_unit(0, "kayle_ranged", Vector2(300, 900), 0.0)
	var target: Unit = main._spawn_unit(1, "garen", Vector2(300, 780), 0.0)
	var air: Unit = main._spawn_unit(1, "anivia", Vector2(325, 780), 0.0)
	var ally: Unit = main._spawn_unit(0, "garen", Vector2(285, 780), 0.0)
	var far: Unit = main._spawn_unit(1, "garen", Vector2(450, 780), 0.0)
	var start := [target.hp, air.hp, ally.hp, far.hp]
	_expect(main.launch_attack(ranged, target, ranged.damage, ranged.projectile_speed, ranged.splash_radius, 0, Color.YELLOW), "远程真实发射弹体")
	_expect(target.hp == start[0] and air.hp == start[1], "出手不提前造成伤害")
	ranged.free()
	for _i in 12: main._tick_projectiles(0.05)
	_expect(target.hp == start[0] - 160 and air.hp == start[1], "来源死亡不取消弹体，对地焰浪不伤空中目标")
	_expect(ally.hp == start[2] and far.hp == start[3], "焰浪不伤友方或范围外目标")
	_clear()
	var invalid := CardDB.all().duplicate(true)
	invalid.kayle.deployment_upgrade_id = 6
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid, false).is_empty(), "升级引用拒绝错误类型")
	invalid = CardDB.all().duplicate(true)
	invalid.kayle.deployment_upgrade_id = "kayle"
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid, false).is_empty(), "拒绝自引用升级")
	invalid = CardDB.all().duplicate(true)
	invalid.kayle.active_skills[0].heal_amount = -1
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid, false).is_empty(), "治疗量拒绝负数")

	_test_hit_haste()
	_test_wave()
	_test_wave_category_and_scale()
	_test_wave_audio()
	_test_sword_facing()
	_test_enrage_visual()

func _test_hit_haste() -> void:
	for id in ["kayle", "kayle_ranged"]:
		_clear()
		var source: Unit = _main._spawn_unit(0, id, Vector2(300, 900), 0.0)
		var victim: Unit = _main._spawn_unit(1, "garen", Vector2(300, 820), 0.0)
		var nearby: Unit = _main._spawn_unit(1, "garen", Vector2(320, 820), 0.0)
		_expect(is_equal_approx(source.attack_interval, 1.5), "两形态基础间隔降至1.5秒")
		_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.0), "未命中无层数")
		_main._combat._resolve_immediate_attack_hit(0, source.position, victim, 1, source.splash_radius, 0, source)
		_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.1), "单击溅射多人也只叠一层")
		source._tick_active_statuses(2.0)
		source.attack_timeline.begin_windup(1.1, 1.1)
		var before := source.attack_timeline.windup
		source.on_attack_landed()
		_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.2), "第二次命中累加为20%")
		_expect(is_equal_approx(source.buffs.remaining(&"hit_haste"), 3.0), "第二秒命中后全部重新计时3秒")
		_expect(is_equal_approx(source.attack_timeline.windup, before * 1.1 / 1.2), "中途叠层按归一化进度缩短前摇")
		for i in 5: source.on_attack_landed()
		_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.4), "超过四次仍封顶40%")
		source._tick_active_statuses(2.95)
		_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.4), "满层最后一个Tick之前仍有效")
		source.on_attack_landed()
		_expect(is_equal_approx(source.buffs.remaining(&"hit_haste"), 3.0), "满层命中也刷新")
		source.freeze(4.0)
		source._tick_active_statuses(3.0)
		_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.0), "冻结期间照常到期并清空全部层数")
		source.on_attack_landed()
		_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.1), "到期后从第一层重新积累")
		source.hp = 0
		source.on_attack_landed()
		_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.1), "死亡来源不能从在途命中获取新层")
		_expect(nearby.hp > 0, "夹具目标存活")
	_clear()
	var archer: Unit = _main._spawn_unit(0, "kayle_ranged", Vector2(300, 900), 0.0)
	var target: Unit = _main._spawn_unit(1, "garen", Vector2(300, 780), 0.0)
	_main.launch_attack(archer, target, 1, archer.projectile_speed, archer.splash_radius, 0, Color.YELLOW)
	_expect(is_equal_approx(archer.active_attack_speed_multiplier, 1.0), "远程创建弹体不提前叠层")
	for i in 12: _main._tick_projectiles(0.05)
	_expect(is_equal_approx(archer.active_attack_speed_multiplier, 1.1), "远程实际抵达后叠层")
	var snapshot: Array = _main._snapshot_system._unit_snapshot_payload(123, archer)
	_expect(is_equal_approx(float(snapshot[preload("res://scripts/battle/network_snapshot_system.gd").U_ACTIVE_ATTACK_SPEED_MULTIPLIER]), 1.1), "快照携带被动的最终攻速倍率")
	var prior := archer.active_attack_speed_multiplier
	target.hp = 0
	_main._combat._resolve_immediate_attack_hit(0, archer.position, target, 1, 0, 0, archer)
	_expect(is_equal_approx(archer.active_attack_speed_multiplier, prior), "无效目标没有命中收益")
	_expect(is_equal_approx(CardDB.get_card("kayle").range, 56.0), "近战表面距离1.4格")
	var catalog := preload("res://scripts/ui/workbench/card_catalog.gd")
	_expect(catalog.deployment_id("kayle", 0) == "kayle" and catalog.deployment_id("kayle", 1) == "kayle_ranged", "工作台切换部署形态")
	_expect(catalog.stats_for_form(CardDB.get_card("kayle"), 1).damage == 105, "工作台远程信息读取正式定义")
	var bad := CardDB.all().duplicate(true)
	bad.kayle.hit_haste_max_stacks = 1.5
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(bad, false).is_empty(), "拒绝小数层数")
	bad.kayle.erase("hit_haste_duration")
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(bad, false).is_empty(), "拒绝缺少持续时间")

func _clear() -> void:
	_main._commands.clear()
	_main._projectile_system.clear_all()
	for c in _main.get_tree().get_nodes_in_group("combatants"):
		if c is Unit: c.free()

func _test_wave() -> void:
	_clear()
	var caster: Unit = _main._spawn_unit(0, "kayle_ranged", Vector2(300, 900), 0.0)
	var primary: Unit = _main._spawn_unit(1, "garen", Vector2(300, 800), 0.0)
	var back: Unit = _main._spawn_unit(1, "garen", Vector2(300, 770), 0.0)
	var side: Unit = _main._spawn_unit(1, "garen", Vector2(400, 740), 0.0)
	var outside: Unit = _main._spawn_unit(1, "garen", Vector2(300, 550), 0.0)
	var ally: Unit = _main._spawn_unit(0, "garen", Vector2(300, 720), 0.0)
	var before := [primary.hp, back.hp, side.hp, outside.hp, ally.hp]
	_expect(_main.launch_attack(caster, primary, caster.damage, caster.projectile_speed, 0, 0, Color.YELLOW), "一次普攻创建光剑和焰浪")
	_expect(_main._projectile_system.projectiles.size() == 1 and _main._projectile_system._pending_attack_waves.size() == 1, "光剑先创建，焰浪尚在延迟队列")
	_main._tick_projectiles(0.05)
	_expect(_main._projectile_system.projectiles.size() == 1, "首个Tick无焰浪碰撞或表现")
	_main._tick_projectiles(0.05)
	_expect(_main._projectile_system.projectiles.size() == 2, "0.1秒到期独立创建焰浪")
	var payloads: Array = []
	for id in _main._projectile_system.projectiles:
		payloads.append(_main._snapshot_system._projectile_snapshot_payload(id, _main._projectile_system.projectiles[id]))
	var old_mode: String = _main.mode
	_main.mode = "client"
	_main._snapshot_system._apply_projectiles(payloads)
	_main._projectile_system.tick_visuals(0.05)
	var views: Dictionary = _main._projectile_system._native_visuals._views
	_expect(views.size() == 2, "客户端快照重建独立光剑和焰浪表现")
	for shot in _main._projectile_system.client_snapshot().values():
		_expect(not shot.visual_path.is_empty() and shot.visual_path.end == primary.position, "客户端接收出手锁定的纯表现路径")
	_main._projectile_system.clear_client()
	_expect(_main._projectile_system._native_visuals._views.is_empty(), "客户端清场立即释放焰浪表现")
	_main.mode = old_mode
	for i in 20: _main._tick_projectiles(0.05)
	_expect(primary.hp == before[0] - 160, "主目标可叠加105+55")
	_expect(back.hp == before[1] - 55, "焰浪穿过主目标继续伤害地面后排")
	_expect(side.hp == before[2] and outside.hp == before[3] and ally.hp == before[4], "焰浪不伤路径外、射程外与友方")
	_expect(is_equal_approx(caster.active_attack_speed_multiplier, 1.1), "一剑多目标焰浪仅叠一层被动")
	_expect(_main._projectile_system.projectiles.is_empty(), "抵达出手锁定终点后销毁")
	# 光剑可追踪转向，焰浪在创建后方向固定。
	primary.position = Vector2(300, 800)
	_main.launch_attack(caster, primary, 1, caster.projectile_speed, 0, 0, Color.YELLOW)
	primary.position = Vector2(450, 800)
	_main._tick_projectiles(0.05)
	_main._tick_projectiles(0.05)
	for projectile in _main._projectile_system.projectiles.values():
		if projectile.get("skill_fan", false):
			_expect((projectile.direction as Vector2).is_equal_approx(Vector2.UP), "焰浪不随原目标转弯")
		else:
			_expect(projectile.direction.x > 0.0, "光剑仍追踪原目标")
	_clear()
	caster = _main._spawn_unit(0, "kayle_ranged", Vector2(300, 900), 0.0)
	var enemy_tower: Tower = _main._king_enemy
	var old_position := enemy_tower.position
	var old_hp := enemy_tower.hp
	enemy_tower.position = Vector2(300, 800)
	_main.launch_attack(caster, enemy_tower, 105, caster.projectile_speed, 0, 0, Color.YELLOW)
	for i in 20: _main._tick_projectiles(0.05)
	_expect(enemy_tower.hp == old_hp - 160, "水晶同样承受光剑与焰浪")
	enemy_tower.position = old_position
	enemy_tower.hp = old_hp
	var invalid := CardDB.all().duplicate(true)
	invalid.kayle_ranged.erase("attack_wave_near_width")
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid, false).is_empty(), "缺少焰浪宽度时拒绝定义")

	var near_end := _wave_lifecycle(100.0, false)
	var far_end := _wave_lifecycle(360.0, false)
	_expect(far_end > near_end + 200.0, "锁定远目标得到更长路径，但不改变索敌射程")
	_wave_lifecycle(360.0, true)
	_expect(CardDB.get_unit_stats("kayle_ranged").range == 190.0, "余波不增加190像素普攻范围")
	_expect(not ProjectileSystem._wave_sweep_overlaps(Vector2(5, 40), 2, 21, 24, 26.52), "近端窄波前不提前命中外侧")
	_expect(ProjectileSystem._wave_sweep_overlaps(Vector2(5, 40), 2, 21, 48, 50.52), "远端扩宽波前可命中相同侧向距离")
	_expect(not ProjectileSystem._wave_sweep_overlaps(Vector2(0, 45), 2, 100, 24, 60), "扩宽扫掠不用末端最大宽度误伤近端")

func _wave_lifecycle(distance: float, remove_target: bool) -> float:
	_clear()
	var caster: Unit = _main._spawn_unit(0, "kayle_ranged", Vector2(300, 1000), 0.0)
	var target: Unit = _main._spawn_unit(1, "garen", Vector2(300, 1000 - distance), 0.0)
	target.position = caster.position + Vector2.UP * distance
	var target_at_launch := target.position
	var system: ProjectileSystem = _main._projectile_system
	_main.launch_attack(caster, target, 105, caster.projectile_speed, 0, 0, Color.YELLOW)
	var pending: Dictionary = system._pending_attack_waves[0]
	var wave: Dictionary = pending.projectile
	var wave_id: int = pending.id
	var start: Vector2 = wave.pos
	var sword: Dictionary = system.projectiles.values()[0]
	_expect(start == sword.pos and wave.direction == (target_at_launch - start).normalized(), "焰浪起点与光剑相同，轴线在光剑创建时锁定")
	_expect(is_equal_approx(float(wave.remaining), start.distance_to(target_at_launch) + 40.0), "出手瞬间锁定目标位置后1格的全程")
	caster.position += Vector2(80, 0)
	if remove_target: target.free()
	else: target.position += Vector2(200, -80)
	_main._tick_projectiles(0.05)
	_expect(not system.projectiles.has(wave_id), "目标变动不提前触发延迟波")
	_main._tick_projectiles(0.05)
	_expect(system.projectiles.has(wave_id) and wave.pos == start, "延迟到期仍从出手原点创建")
	var initial_radius := float(wave.radius)
	for i in 40:
		if not system.projectiles.has(wave_id): break
		_main._tick_projectiles(0.05)
	_expect(not system.projectiles.has(wave_id), "目标移动或死亡均不改变焰浪终点")
	_expect((wave.pos as Vector2).is_equal_approx(target_at_launch + Vector2.UP * 40.0), "波前准确终止在旧目标位置后1格")
	_expect(float(wave.radius) > initial_radius, "锁定路线仍随飞行逐渐扩宽")
	var replacement: Unit = _main._spawn_unit(1, "garen", Vector2(300, 800), 0.0)
	_main.launch_attack(caster, replacement, 105, caster.projectile_speed, 0, 0, Color.YELLOW)
	_expect(system._pending_attack_waves.size() == 1, "新一次出手存在独立待创建波")
	system.clear_all()
	_expect(system._pending_attack_waves.is_empty(), "清场同时移除待创建焰浪")
	return start.distance_to(wave.pos)

func _test_wave_category_and_scale() -> void:
	for air_mode in [false, true]:
		_clear()
		var source: Unit = _main._spawn_unit(0, "kayle_ranged", Vector2(300, 1000), 0)
		var target: Unit = _main._spawn_unit(1, "anivia" if air_mode else "garen", Vector2(300, 800), 0)
		var max_center_distance := source.attack_range + source.body_radius + target.body_radius
		target.position = source.position + Vector2.UP * max_center_distance
		var air: Unit = _main._spawn_unit(1, "anivia", Vector2(325, target.position.y), 0)
		var ground: Unit = _main._spawn_unit(1, "garen", Vector2(325, target.position.y), 0)
		var air_hp := air.hp
		var ground_hp := ground.hp
		var system: ProjectileSystem = _main._projectile_system
		_main.launch_attack(source, target, 105, 420, 0, 0, Color.YELLOW)
		_expect(system.projectiles.size() == 1, "每次普攻仅一枚光剑权威弹体")
		var sword_id: int = system.projectiles.keys()[0]
		var wave: Dictionary = system._pending_attack_waves[0].projectile
		var initial_radius := float(wave.radius)
		var travel := float(wave.remaining)
		_expect(is_equal_approx(initial_radius, 24.0), "焰浪出现时倍率恰为1")
		_expect(is_equal_approx(initial_radius + travel * float(wave.width_growth) * 0.5, initial_radius * 2), "最大合法攻击距离加余波恰好达到2倍宽")
		_expect(is_equal_approx(initial_radius + travel * 0.5 * float(wave.width_growth) * 0.5, initial_radius * 1.5), "最大路径中点宽度线性为1.5倍")
		for i in 25: _main._tick_projectiles(0.05)
		_expect(not system.projectiles.has(sword_id), "光剑命中销毁，不能穿透或残留")
		_expect(air.hp == air_hp - (55 if air_mode else 0), "只有对空焰浪伤害空军")
		_expect(ground.hp == ground_hp - (0 if air_mode else 55), "只有对地焰浪伤害地面单位")
		_expect(is_equal_approx(float(wave.radius), initial_radius * 2), "最大路径末端为2倍宽")
		# 近目标终点更近，归一化标尺不随这次实际短路径缩小。
		system.clear_all()
		target.position = source.position + Vector2.UP * 100
		_main.launch_attack(source, target, 105, 420, 0, 0, Color.YELLOW)
		wave = system._pending_attack_waves[0].projectile
		var locked_mode: bool = wave.wave_air
		target.is_air = not target.is_air
		_expect(bool(wave.wave_air) == locked_mode, "目标后续改变飞行类别不改变已锁定焰浪")
		for i in 20: _main._tick_projectiles(0.05)
		_expect(float(wave.radius) < initial_radius * 2, "近距离提前结束时宽度不到2倍")

func _test_wave_audio() -> void:
	_expect(CardDB.validate_all(false).is_empty(), "焰浪事件具备完整配置及派发能力")
	_expect(not PresentationEvents.supports(CardDB.get_card("kayle"), "attack_wave:launch"), "近战不声明焰浪声音能力")
	var system: ProjectileSystem = _main._projectile_system
	var events: Array = []
	var listener := func(source: Dictionary, action: String, _pos: Vector2, phase: String): events.append([source.duplicate(true), action, phase])
	system.wave_audio.connect(listener)
	for miss in [false, true]:
		_clear()
		events.clear()
		var caster: Unit = _main._spawn_unit(0, "kayle_ranged", Vector2(300, 900), 0.0)
		var target: Unit = _main._spawn_unit(1, "garen", Vector2(300, 800), 0.0)
		var rear: Unit = _main._spawn_unit(1, "garen", Vector2(300, 770), 0.0)
		_main.launch_attack(caster, target, 105, caster.projectile_speed, 0, 0, Color.YELLOW)
		_expect(events.is_empty(), "光剑创建不提前播放焰浪发射声")
		caster.free()
		if miss:
			target.position.x += 300
			rear.position.x += 300
		system.tick(0.05)
		_expect(events.is_empty(), "焰浪延迟期不播放发射声")
		system.tick(0.05)
		_expect(events.size() == 1 and events[0][2] == "launch", "来源死亡后延迟焰浪仍发声且只播一次")
		_expect(events[0][0].card_id == "kayle_ranged" and events[0][1] == "attack_wave", "保留远程出手来源用于本机及RPC声音选择")
		for i in 15: system.tick(0.05)
		_expect(events.size() == (1 if miss else 2), "空波不播放命中声，穿过多个单位只播一次命中声")
		if not miss: _expect(events[1][2] == "hit", "真实焰浪伤害触发专属命中声")
	_clear()
	events.clear()
	var caster: Unit = _main._spawn_unit(0, "kayle_ranged", Vector2(300, 900), 0.0)
	var target: Unit = _main._spawn_unit(1, "garen", Vector2(300, 800), 0.0)
	_main.launch_attack(caster, target, 105, caster.projectile_speed, 0, 0, Color.YELLOW)
	system.clear_all()
	system.tick(0.2)
	_expect(events.is_empty(), "清场取消待创建焰浪声音")
	system.wave_audio.disconnect(listener)

func _test_sword_facing() -> void:
	for side in [-1.0, 1.0]:
		_clear()
		var caster: Unit = _main._spawn_unit(0, "kayle_ranged", Vector2(300, 900), 0.0)
		var target: Unit = _main._spawn_unit(1, "garen", Vector2(300 + side * 160, 900), 0.0)
		caster.set_meta("projectile_model_offset", Vector2(0, -80))
		target.set_meta("projectile_model_offset", Vector2(0, -30))
		var system: ProjectileSystem = _main._projectile_system
		system.launch(caster, target, 1, caster.projectile_speed, 0, 0, Color.YELLOW)
		system.tick_visuals(0.008)
		var view: Dictionary = system._native_visuals._views.values()[0]
		var expected := Vector2(side * 160, 50).angle() + PI * 0.5
		_expect(is_equal_approx(view.node.rotation, expected), "侧面地面目标首帧剑尖朝向包含模型高差")
		system.tick(0.05)
		system.tick_visuals(0.008)
		_expect(is_equal_approx(view.node.rotation, expected), "飞行位移不改变创建时朝向")
		target.position.y -= 40
		system.tick(0.05)
		system.tick_visuals(0.008)
		_expect(is_equal_approx(view.node.rotation, expected), "目标移动后光剑追踪但朝向保持出手方向")
		var angle: float = view.node.rotation
		for i in 6: system.tick_visuals(0.008)
		_expect(is_equal_approx(view.node.rotation, angle), "20Hz间静止渲染帧保持实际斜向轨迹，不退回水平")

func _test_enrage_visual() -> void:
	for id in ["kayle", "kayle_ranged"]:
		_clear()
		var unit: Unit = _main._spawn_unit(0, id, Vector2(300, 900), 0.0)
		var twin: Unit = _main._spawn_unit(0, id, Vector2(400, 900), 0.0)
		var view: UnitModel3D
		var other: UnitModel3D
		for candidate in _main._battle_presentation._world_root.get_children():
			if candidate is UnitModel3D and candidate._source == unit: view = candidate
			if candidate is UnitModel3D and candidate._source == twin: other = candidate
		_expect(view != null and other != null, "两形态均通过正式模型代理挂载被动材质")
		if view == null or other == null: continue
		for i in 3: unit.on_attack_landed()
		view._process(0.5)
		_expect(not unit.hit_haste_full_visual() and view._model_root._enrage_strength == 0.0, "三层不亮且W不影响被动特效")
		unit.apply_active_buff(5, 1.3, 1.0, 2.0)
		_expect(not unit.hit_haste_full_visual(), "其他攻速增益不能伪造满层")
		unit.on_attack_landed()
		unit.control.slow_timer = 2.0
		view._process(0.25)
		_expect(unit.hit_haste_full_visual() and is_equal_approx(view._model_root._enrage_strength, 0.5), "真实四层触发原版半秒淡入，不依赖最终攻速")
		view._process(0.25)
		_expect(view._model_root._enrage_strength == 1.0 and other._model_root._enrage_strength == 0.0, "两只天使材质独立，满层不串色")
		_expect(not view._model_root._enrage_materials.is_empty(), "满层特效附着可见翅膀表面")
		unit.buffs.advance(2.0)
		unit.on_attack_landed()
		view._process(0.1)
		_expect(view._model_root._enrage_strength == 1.0, "满层命中刷新寿命不重新闪烁")
		unit.buffs.advance(3.05)
		view._process(0.5)
		_expect(not unit.hit_haste_full_visual() and view._model_root._enrage_strength == 0.0, "三秒到期后按原版半秒淡出")
		for i in 4: unit.on_attack_landed()
		view._process(0.5)
		unit.hp = 0
		view._process(0.5)
		_expect(not unit.hit_haste_full_visual() and view._model_root._enrage_strength == 0.0, "死亡熄灭满层特效")
		view._model_root.advance_hit_haste_visual(true, 0.5)
		view._model_root.reset_pool_visual()
		_expect(view._model_root._enrage_strength == 0.0, "模型回池重置怒焰强度与动画时钟")
