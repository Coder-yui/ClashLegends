extends RefCounted
var _harness
var _main: Node2D
var _spells: SpellSystem
var _audio: Array[Dictionary] = []

func run(harness, main: Node2D) -> void:
	_harness = harness
	_main = main
	_spells = main._spell_system
	_audio.clear()
	main.runtime.event.connect(_capture_audio)
	var stats := CardDB.get_card("stellar_convergence")
	var center := Vector2(360, 850)
	var ground := _unit("garen", center + Vector2(80, 0))
	var air := _unit("anivia", center + Vector2(-80, 0))
	var ally := _unit("garen", center, 0)
	var building := _unit("target_dummy", center)
	_spells.cast(0, stats, center)
	var start: int = main.get_authoritative_server_tick()
	_tick(start + 4)
	_expect(ground.hp == ground.max_hp, "首个0.25秒前不伤害")
	_tick(start + 5)
	_expect(ground.hp == ground.max_hp - 6 and air.hp == air.max_hp - 6, "空地每次6伤害")
	_expect(ally.hp == ally.max_hp and building.hp == building.max_hp - 6, "友军免伤、建筑受伤")
	_expect(_count_audio("spell:hit") == 3, "真实伤害结算后每敌方目标首次命中发声，友军不发声")
	var pull := _spells.area_pull_velocity(ground, 0.05)
	_expect(pull == Vector2(-40, 0) and _spells.area_pull_velocity(air, 0.05) == Vector2(40, 0), "两侧空地向中心持续牵引")
	_expect(_spells.area_pull_velocity(building, 0.05) == Vector2.ZERO, "建筑不受牵引")
	_expect(ground.knockback.remaining == 0 and ground.control.stun_timer == 0, "牵引不建立击退或眩晕")
	_tick(start + 5)
	_expect(ground.hp == ground.max_hp - 6, "相同Tick不重复伤害")
	for t in range(start + 6, start + 101): _tick(t)
	_expect(ground.hp == ground.max_hp - 120, "5秒20次总120伤害")
	_expect(_spells.stellar_zones.is_empty() and _spells.area_pull_velocity(ground, 0.05) == Vector2.ZERO, "到期释放区域与外力")
	_expect(_count_audio("spell:hit") == 3, "持续20跳不重复叠加首次命中声")
	ground.position = center
	ground.hp = ground.max_hp * 0.15
	ground.add_shield(10000, 10)
	_spells.cast(0, stats, center, true)
	_tick(main.get_authoritative_server_tick())
	_expect(ground.hp > 0, "恰好15%不斩杀")
	ground.hp -= 1
	_tick(main.get_authoritative_server_tick() + 1)
	_expect(ground.hp == 0, "低于15%时绕过普通护盾斩杀")
	_expect(_count_audio("spell:execute") == 1, "成功斩杀独立发声一次")
	_spells.clear()
	var protected := _unit("garen", center)
	protected.hp = 1
	protected.buffs.apply(&"undying", &"test", 5, {})
	_spells.cast(0, stats, center, true)
	_tick(main.get_authoritative_server_tick() + 1)
	_expect(protected.hp == 1, "拒绝死亡阻止斩杀")
	protected.buffs.clear_family(&"undying")
	protected.apply_stasis(2)
	_tick(main.get_authoritative_server_tick() + 1)
	_expect(protected.hp == 1 and _spells.area_pull_velocity(protected, 0.05) == Vector2.ZERO, "凝滞拒绝斩杀与牵引")
	_expect(_count_audio("spell:execute") == 1, "阈值未达、拒绝死亡、凝滞不伪造斩杀声")
	building.hp = 1
	_expect(not CombatExecution.try_execute(building, 0.15), "共享斩杀默认禁止建筑")
	_expect(CombatExecution.try_execute(building, 0.15, {}, true) and building.hp == 0, "显式配置允许建筑斩杀")
	var shielded := _unit("garen", center + Vector2(70, 0))
	shielded.buffs.apply(&"effect_shield", &"test", 5, {})
	_tick(main.get_authoritative_server_tick() + 1)
	_expect(_spells.area_pull_velocity(shielded, 0.05) == Vector2.ZERO, "法术盾拒绝同次持续牵引")
	_spells.clear()
	_spells.cast(0, stats, center)
	_spells.cast(0, stats, center + Vector2(140, 0))
	_expect(_spells.area_pull_velocity(shielded, 0.05).is_zero_approx(), "相反区域外力抵消")
	_spells.clear()
	shielded.position = center + Vector2(70, 0)
	shielded.can_attack = false
	shielded.root(10)
	_spells.cast(0, stats, center)
	var before := shielded.position.x
	shielded.sim_tick(0.05)
	_main._movement.tick(0.05)
	_expect(shielded.position.x < before, "实际移动系统应用持续外力")
	_spells.clear()
	for tower in main.world.towers_snapshot():
		var hp: float = tower.hp
		_spells.cast(1 - tower.team, stats, tower.position)
		var tower_start: int = main.get_authoritative_server_tick()
		for t in range(tower_start + 1, tower_start + 101): _tick(t)
		_expect(is_equal_approx(tower.hp, hp - 36), "塔与水晶连续小数余量累计36伤害")
	_spells.clear()
	_spells.show_flight(999, "stellar_convergence", center, center, 160, 0, 100, 1)
	_expect(_spells.stellar_zones.is_empty() and _spells.stellar_effects.size() == 1, "客户端只建立表现区域")
	_spells.clear()
	for unit in [ground, air, ally, building, protected, shielded]:
		if is_instance_valid(unit): unit.free()
	# 新范围按身体接触边界判定；中心为金色圆内部60像素。
	var edge := _unit("garen", center)
	edge.hp = 10
	edge.position = center + Vector2(60.0 + edge.body_radius + 0.1, 0)
	_spells.cast(0, stats, center, true)
	_tick(main.get_authoritative_server_tick() + 1)
	_expect(edge.hp == 10, "中心60半径外不斩杀")
	edge.position.x -= 0.2
	_tick(main.get_authoritative_server_tick() + 1)
	_expect(edge.hp == 0, "触碰中心60半径即斩杀")
	edge.free()
	_spells.clear()
	var outer := _unit("garen", center)
	outer.position = center + Vector2(160.0 + outer.body_radius - 0.1, 0)
	_spells.cast(0, stats, center)
	var boundary_start: int = main.get_authoritative_server_tick()
	_tick(boundary_start + 5)
	_expect(outer.hp == outer.max_hp - 6, "外圈160半径身体接触受伤")
	outer.position.x += 0.2
	_tick(boundary_start + 10)
	_expect(outer.hp == outer.max_hp - 6, "160半径外不受伤")
	outer.free()
	_spells.clear()
	var blocked := _unit("garen", center)
	blocked.apply_stasis(2)
	var absorbed := _unit("garen", center)
	absorbed.add_shield(1000, 10)
	_audio.clear()
	_spells.cast(1, stats, center) # 所有这些目标同队，空场不发命中声。
	_tick(main.get_authoritative_server_tick() + 5)
	_expect(_count_audio("spell:hit") == 0, "空场和友军不发命中声")
	_spells.clear()
	_spells.cast(0, stats, center)
	_tick(main.get_authoritative_server_tick() + 5)
	_expect(_count_audio("spell:hit") == 1 and absorbed.hp == absorbed.max_hp, "免疫不发声；普通护盾吸收仍算真实命中")
	blocked.free()
	absorbed.free()
	_spells.clear()
	main.runtime.event.disconnect(_capture_audio)
	for field in ["radius", "inner_radius", "duration", "damage", "damage_interval", "pull_speed"]:
		var bad := stats.duplicate(true)
		bad[field] = NAN
		_expect(not CardDB.VALIDATOR.validate_all({"stellar_convergence": bad}, false).is_empty(), "拒绝非法" + field)

func _unit(card: String, pos: Vector2, team: int = 1) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))
func _tick(tick: int) -> void:
	_main.runtime.set("_sim_tick_id", tick)
	_main.combat_service().begin_batch(tick, "stellar_test")
	_spells.tick(0.05)
	_main.combat_service().commit_batch()
func _expect(ok: bool, message: String) -> void:
	_harness._expect(ok, "星芒凝汇：" + message)

func _capture_audio(kind: String, payload: Dictionary) -> void:
	if kind == "card_event" and payload.get("card_id") == "stellar_convergence": _audio.append(payload)
func _count_audio(cue: String) -> int:
	return _audio.filter(func(item): return item.cue == cue).size()
