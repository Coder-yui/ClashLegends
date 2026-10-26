extends RefCounted
var _harness
var _main: Node2D
func run(harness, main: Node2D) -> void:
	_harness = harness
	_main = main
	var spells: SpellSystem = main.get("_spell_system")
	var stats := CardDB.get_card("event_horizon")
	var center := Vector2(360, 800)
	_expect(stats.radius == 120.0 and stats.active_skills[0].radius == 65.0, "E120/W65整数像素范围")
	_expect(absf(120.0 / 390.0 / (65.0 / 225.0) - 1.0) < 0.07, "E/W源单位缩放差小于7%")
	var units: Array[Unit] = []
	for pair in [["garen",1,Vector2(120,0)], ["garen",1,Vector2.ZERO], ["garen",0,Vector2(-120,0)], ["anivia",1,Vector2(0,120)], ["tombstone",1,Vector2(0,-120)]]:
		units.append(main._spawn_unit(UnitSpawnRequest.new(pair[1], pair[0], center + pair[2], {"deploy_time_override":0.0})))
	spells.cast(0, stats, center, true)
	var start: int = spells.horizon_zones[0].start_tick
	_tick(start-1)
	_expect(units[0].control.stun_timer == 0, "成形前无眩晕")
	_tick(start)
	_expect(units[0].control.stun_timer == 1.5 and units[3].control.stun_timer == 1.5, "边界地面和空军眩晕1.5秒")
	_expect(units[1].control.stun_timer == 0 and units[2].control.stun_timer == 0 and units[4].control.stun_timer == 0, "圈内友军建筑不眩晕")
	_expect(spells.dark_matters.size() == 1 and spells.dark_matters[0].pos == units[0].position, "同Tick按出生顺序锁定首个成功位置")
	units[0].control.hard.clear_family(&"stun")
	units[0].position = center + Vector2(300,0)
	_tick(start+1)
	units[0].position = center
	units[1].position = center - Vector2(300,0)
	_tick(start+2)
	_expect(units[0].control.stun_timer == 0, "已命中目标不重复眩晕")
	_expect(units[1].control.stun_timer == 1.5, "跨边界扫掠不漏高速移动")
	var impact: int = spells.dark_matters[0].impact_tick
	units[0].position = center + Vector2(120,0)
	units[2].team = 1
	units[2].position = units[0].position + Vector2(64, 0)
	var expanded_hp := units[2].hp
	var hp := units[0].hp
	_tick(impact-1)
	_expect(units[0].hp == hp, "黑暗物质不提前伤害")
	_tick(impact)
	_expect(units[0].hp == hp-220 and spells.dark_matters.is_empty(), "固定落点24Tick后结算220伤害且清理")
	_expect(units[2].hp == expanded_hp-220, "W范围内64像素位置可命中")
	units[2].team = 0
	_tick(start+60)
	_expect(spells.horizon_zones.is_empty(), "60Tick到期清理空间")
	spells.clear()
	units[0].control.hard.clear_family(&"stun")
	units[3].position = center
	units[0].buffs.apply(&"effect_shield", &"test", 5.0, {})
	spells.cast(0,stats,center,true)
	start = spells.horizon_zones[0].start_tick
	_tick(start)
	_expect(units[0].control.stun_timer == 0 and spells.dark_matters.is_empty(), "法术盾抵挡眩晕且不触发黑暗物质")
	_tick(start+1)
	_expect(units[0].control.stun_timer == 0, "法术盾消费后同一空间不重复触发")
	spells.clear()
	spells.cast(0,stats,center,false)
	_tick(spells.horizon_zones[0].start_tick)
	_expect(units[0].control.stun_timer > 0 and spells.dark_matters.is_empty(), "新空间可重新眩晕且普通槽无黑暗物质")
	spells.clear()
	spells.show_flight(999,"event_horizon",center,center,100,0,75)
	_expect(spells.horizon_zones.is_empty() and spells.horizon_effects.size() == 1, "副本只创建表现")
	spells.clear()
	_expect(spells.horizon_effects.is_empty() and spells.dark_matters.is_empty(), "清场移除全部法术状态")
	_expect(not SpellSystem.touches_boundary(center,center,center,100,16), "纯圈内不接触")
	_expect(SpellSystem.touches_boundary(center-Vector2(200,0),center+Vector2(200,0),center,100,16), "穿越整个圆的扫掠")
	_expect(not SpellSystem.touches_boundary(center+Vector2(200,0),center+Vector2(200,200),center,100,16), "圈外线段不误判")
	for unit in units: unit.free()
func _tick(tick: int) -> void:
	_main.runtime.set("_sim_tick_id",tick)
	_main.combat_service().begin_batch(tick,"horizon_test")
	_main.get("_spell_system").tick(FixedStepClock.STEP)
	_main.combat_service().commit_batch()
func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, "扭曲空间：" + message)
