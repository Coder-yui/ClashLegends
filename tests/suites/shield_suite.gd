extends RefCounted

func run(harness: Object) -> void:
	for decaying_first in [true, false]:
		for recipient in [Unit.new(), Tower.new()]:
			recipient.hp = 1000.0
			recipient.max_hp = 1000.0
			if decaying_first:
				recipient.add_shield(300, 2, true)
				recipient.add_shield(100, 4, false)
			else:
				recipient.add_shield(100, 4, false)
				recipient.add_shield(300, 2, true)
			for tick in 20:
				if recipient is Unit:
					recipient._tick_active_statuses(0.05)
				else:
					recipient._tick_shield(0.05)
			harness._expect(recipient.shield_hp == 250.0, "独立护盾：先后施加不影响瑟提式衰减，1秒后150+100")
			recipient.take_damage(120)
			harness._expect(recipient.hp == 1000.0 and recipient.shield_hp == 130.0, "伤害优先消耗最早到期的衰减盾")
			if recipient is Unit:
				recipient._tick_active_statuses(1.0)
			else:
				recipient._tick_shield(1.0)
			harness._expect(recipient.shield_hp == 100.0 and recipient.shield_max_hp == 100.0, "旧盾耗尽/到期只移除自身，不衰减新盾或保留失效容量")
			recipient.shields.tick(2.0)
			harness._expect(recipient.shield_hp == 0.0 and recipient.get_shield_ratio() == 0.0, "友方盾到自己的四秒期限才消失")
			recipient.free()
	var shield := ShieldState.new()
	shield.add(100, 5)
	shield.tick(1)
	shield.add(60, 1)
	shield.absorb(50)
	harness._expect(shield.inspect_layers()[0].hp == 10 and shield.inspect_layers()[1].hp == 100, "新盾先到期时优先承伤，与新旧顺序无关")
	shield.tick(1)
	harness._expect(shield.total_hp() == 100, "新盾过期不延长或清除旧盾")
	shield.clear()
	var first := shield.add(100, 3, true)
	shield.tick(1)
	var second := shield.add(80, 2)
	shield.absorb(40)
	var layers := shield.inspect_layers()
	harness._expect(layers[0].id == first and layers[0].hp == 27 and layers[1].id == second and layers[1].hp == 80, "同刻到期时按获得顺序承伤")
	layers[0].hp = 9999
	harness._expect(shield.total_hp() == 107, "诊断副本无法反向修改护盾层")
	shield.clear()
	shield.add(101, 2, true)
	shield.add(51, 2, true)
	for tick in 20:
		shield.tick(0.05)
	harness._expect(shield.total_hp() == 75, "两层独立累积整数衰减余量，1秒分别剩50和25")
	harness._expect(shield.absorb(100) == 25 and shield.total_hp() == 0 and shield.total_capacity() == 0, "一次伤害可穿透多层，只有余量扣生命")
	shield.add(100, 1)
	shield.tick(0.999999999)
	harness._expect(shield.total_hp() == 0, "到期边界不因浮点余量多留一Tick")
	harness._expect(shield.add(NAN, 1) == -1 and shield.add(1, INF) == -1 and shield.inspect_layers().is_empty(), "非有限护盾参数不污染状态")
	var tower := Tower.new()
	tower.apply_shield_snapshot(0.5, 0.1)
	var visible_hp: float = tower.shield_hp
	tower.shields.tick(100)
	harness._expect(visible_hp > 0 and tower.shield_hp == visible_hp and tower.shields.inspect_layers().is_empty(), "客户端塔快照是只读表现值，不创建或衰减权威层")
	tower.clear_shields()
	harness._expect(tower.shield_hp == 0 and tower.shield_max_hp == 0, "清场同步清空塔的表现护盾")
	tower.free()
