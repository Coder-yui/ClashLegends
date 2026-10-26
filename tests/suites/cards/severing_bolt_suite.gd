extends RefCounted
var _harness
var _main: Node2D
var _spells: SpellSystem
func run(harness, main: Node2D) -> void:
	_harness = harness
	_main = main
	_spells = main.get("_spell_system")
	_check_vfx()
	var cues: Array[String] = []
	var on_cue := func(id, cue, _position):
		if id == "severing_bolt": cues.append(String(cue))
	main._audio_manager.cue_played.connect(on_cue)
	var stats := CardDB.get_card("severing_bolt")
	_expect(not stats.audio.events.has("spell:cast") and stats.audio.events.has("spell:launch"), "OnCast源音绑定施法完成而非前奏开始")
	var center := Vector2(360, 800)
	var a: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "garen", center, {"deploy_time_override": 0.0}))
	var b: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "anivia", center + Vector2(250, 0), {"deploy_time_override": 0.0}))
	var ally: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "garen", center, {"deploy_time_override": 0.0}))
	_expect(stats.cost == 3 and stats.active_cost_bonus == 0, "3费普通/强化同价")
	_spells.cast(0, stats, center)
	var impact: int = _spells.bolt_casts[0].impact_tick
	_expect(impact - main.get_authoritative_server_tick() == 30, "0.5秒前奏加1秒预警等于30Tick")
	_tick(impact - 21)
	_expect(cues.is_empty(), "前奏阶段不提前播放OnCast")
	_tick(impact - 20)
	_expect(cues == ["spell:launch", "spell:warning"], "施法完成与预警同Tick开始")
	var hp := a.hp
	_tick(impact - 1)
	_expect(a.hp == hp, "落雷前无伤害")
	_tick(impact)
	_expect(a.hp == hp - 300 and ally.hp == ally.max_hp, "单体2.5倍且友方不计数不受伤")
	_expect(cues == ["spell:launch", "spell:warning", "spell:impact"], "落雷音在预警一秒后且各播一次")
	main._audio_manager.cue_played.disconnect(on_cue)
	_tick(impact + 1)
	_expect(a.hp == hp - 300 and _spells.bolt_casts.is_empty(), "只结算一次并清理")
	for enhanced in [false, true]:
		for controlled in [false, true]:
			for isolated in [false, true]:
				a.hp = a.max_hp
				b.hp = b.max_hp
				a.control.clear_on_death()
				if controlled: a.control.refresh_stun(2.0)
				b.position = center + Vector2(250, 0) if isolated else center + Vector2(30, 0)
				_spells.cast(0, stats, center, enhanced)
				impact = _spells.bolt_casts[0].impact_tick
				_tick(impact)
				var expected := (420 if enhanced else 300) if isolated else ((300 if enhanced else 240) if controlled else 120)
				_expect(a.hp == a.max_hp - expected, "倍率增强=%s 控制=%s 单体=%s" % [enhanced, controlled, isolated])
				if not isolated: _expect(b.hp == b.max_hp - 120, "范围内空军受到基础伤害")
	a.control.clear_on_death()
	a.control.refresh_slow(3.0, 0.5)
	_expect(not SpellSystem.bolt_hard_controlled(a), "减速不算硬控")
	a.control.refresh_freeze(1.0)
	_expect(SpellSystem.bolt_hard_controlled(a), "冻结算硬控")
	a.control.clear_on_death()
	a.knockback.replace(Vector2.RIGHT, 30, 1.0)
	_expect(SpellSystem.bolt_hard_controlled(a), "击退/强制位移算硬控")
	a.knockback.cancel(&"test")
	a.control.hard.apply(&"root", &"test", 1.0, {})
	_expect(SpellSystem.bolt_hard_controlled(a), "禁锢算硬控")
	a.control.clear_on_death()
	a.hp = a.max_hp
	b.position = center + Vector2(250, 0)
	_spells.cast(0, stats, center)
	impact = _spells.bolt_casts[0].impact_tick
	b.position = center
	_tick(impact)
	_expect(a.hp == a.max_hp - 120, "按落雷时的入圈目标数判断")
	a.hp = a.max_hp
	b.apply_stasis(2.0)
	_spells.cast(0, stats, center)
	_tick(_spells.bolt_casts[0].impact_tick)
	_expect(a.hp == a.max_hp - 300, "凝滞对象不可命中且不占单体计数")
	a.hp = a.max_hp
	a.buffs.apply(&"effect_shield", &"test", 5.0, {})
	_spells.cast(0, stats, center, true)
	_tick(_spells.bolt_casts[0].impact_tick)
	_expect(a.hp == a.max_hp, "法术盾抵挡整次落雷")
	_spells.cast(0, stats, center)
	_spells.clear()
	_tick(main.get_authoritative_server_tick() + 40)
	_expect(a.hp == a.max_hp and _spells.bolt_casts.is_empty() and _spells.bolt_effects.is_empty(), "清场取消未落雷结果与表现")
	_spells.show_flight(999, "severing_bolt", center, center, 65, 0, 30)
	_expect(_spells.bolt_casts.is_empty() and _spells.bolt_effects.size() == 1, "客户端事件只建立表现")
	_spells.clear()
	for unit in [a, b, ally]: unit.free()
	for tower in main.world.towers_snapshot():
		if tower.team != 1: continue
		var tower_hp: float = tower.hp
		_spells.cast(0, stats, tower.global_position)
		_tick(_spells.bolt_casts[0].impact_tick)
		_expect(tower.hp == tower_hp - 90, "单塔及水晶：300乘30%")
		tower.hp = tower_hp
		_spells.cast(0, stats, tower.global_position, true)
		_tick(_spells.bolt_casts[0].impact_tick)
		_expect(tower.hp == tower_hp - 126, "强化单塔及水晶：420乘30%")
		tower.hp = tower_hp
	_spells.clear()
	_check_building_amplification(stats)
	for field in ["isolated_damage_multiplier", "controlled_damage_multiplier"]:
		var invalid := stats.duplicate(true)
		invalid[field] = -1.0
		_expect(not CardDB.VALIDATOR.validate_all({"severing_bolt": invalid}, false).is_empty(), "拒绝非法倍率" + field)
		invalid = stats.duplicate(true)
		invalid.active_skills[0][field] = 0.0
		_expect(not CardDB.VALIDATOR.validate_all({"severing_bolt": invalid}, false).is_empty(), "拒绝非法强化倍率" + field)
func _tick(tick: int) -> void:
	_main.runtime.set("_sim_tick_id", tick)
	_main.combat_service().begin_batch(tick, "bolt_test")
	_spells.tick(0.05)
	_main.combat_service().commit_batch()
func _expect(ok: bool, message: String) -> void:
	_harness._expect(ok, "攢聚雷：" + message)

func _check_vfx() -> void:
	var presentation = load("res://scripts/presentation/severing_bolt_3d.gd")
	for viewer in [0, 1]:
		_expect(presentation.variants_for("severing_bolt", viewer, viewer) == ["warning", "impact"], "己方保留共用预警主体")
		_expect(presentation.variants_for("severing_bolt", 1-viewer, viewer) == ["warning", "impact", "warning_red"], "双方视角均只向敌方添加原版红圈")
		_expect(presentation.variants_for("severing_bolt_hit", 1-viewer, viewer) == ["hit"], "受击使用共用原版颜色")
	var palette_layers := 0
	for kind in ["warning", "warning_red", "impact", "hit"]:
		var player = load("res://assets/effects/severing_bolt/player.gd").new()
		_main.add_child(player)
		player.load_kind(kind)
		player.setup_native(0.01)
		player.seek(0.25)
		var data: Dictionary = player._data
		_expect(data.palette_frames.size() == data.frames.size(), kind + "调色板时钟与粒子采样逐帧匹配")
		for i in data.emitters.size():
			var emitter: Dictionary = data.emitters[i]
			if emitter.palette == null: continue
			palette_layers += 1
			_expect(ResourceLoader.exists(emitter.palette_path) and player._materials[i].get_shader_parameter("has_palette") == true, kind + "/" + emitter.name + "原调色板已绑定")
			for item in player._pools[i]:
				if not item.visible: continue
				var lookup: Array = data.palette_frames[30][i]
				_expect(item.material_override.get_shader_parameter("palette_lookup") == Vector3(lookup[0],lookup[1],lookup[2]), kind + "/" + emitter.name + "使用发射器相位采样偏移")
				break
		player.free()
	_expect(palette_layers > 0, "调色板测试非空")

func _check_building_amplification(stats: Dictionary) -> void:
	var building: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(360,800), {"deploy_time_override":0.0}))
	var companion: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "garen", Vector2(650,800), {"deploy_time_override":0.0}))
	var structures: Array = [building]
	for tower in _main.world.towers_snapshot():
		if tower.team == 1: structures.append(tower)
	for target in structures:
		var original_hp: float = target.hp
		for enhanced in [false, true]:
			for isolated in [false, true]:
				for status in ["none", "stun", "freeze"]:
					target.hp = original_hp
					target.control.clear_on_death()
					companion.hp = companion.max_hp
					companion.position = Vector2(650,800) if isolated else target.global_position + Vector2(20,0)
					if status == "stun": target.stun(3.0)
					if status == "freeze": target.freeze(3.0)
					var controlled: bool = status != "none" and not (target is Tower and target.is_king)
					_expect(SpellSystem.bolt_hard_controlled(target) == controlled, "建筑控制识别及水晶免控：" + status)
					var damage := (420.0 if enhanced else 300.0) if isolated else ((300.0 if enhanced else 240.0) if controlled else 120.0)
					if target is Tower: damage *= 0.3
					_spells.cast(0, stats, target.global_position, enhanced)
					_tick(_spells.bolt_casts[0].impact_tick)
					_expect(is_equal_approx(target.hp, original_hp - damage), "建筑先取最高增幅再应用塔衰减：强化=%s 单体=%s 控制=%s" % [enhanced, isolated, status])
		target.hp = original_hp
		target.control.clear_on_death()
	building.free()
	companion.free()
	_spells.clear()
