extends "res://tests/suites/battle_suite.gd"
func spawn(card: String, team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, card, point, {"position_resolved": true, "deploy_time_override": 0.0}))
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	for unit in main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()
	var turret := spawn("evolution_turret", 0, Vector2(360, 1100))
	turret._update_dormancy()
	_expect(turret.dormant and turret.untargetable_visual(), "射程无敌人时待机并显示不可选取")
	_expect(not CombatInteraction.can_acquire(turret, 1) and CombatInteraction.can_acquire(turret, 0), "待机仅阻挡敌方索敌")
	_expect(not turret.take_damage(100, null, 1, Vector2.ZERO), "敌方范围伤害不能击中待机炮台")
	_check_projectile_presentation(turret)
	var original_hp := turret.hp
	turret._tick_building_lifetime(1.0)
	_expect(turret.hp == original_hp - 30 and turret._lifespan_left == 23.0, "待机每秒仍衰减30生命及自然寿命")
	turret.hp = 300
	_main.preview_active_skill(turret, CardDB.active_skills_for("evolution_turret")[0])
	_expect(turret.hp == 540 and turret._lifespan_left == 23.0, "待机正式修复回复240且不修改衰减基准")
	turret.heal(999)
	_expect(turret.hp == turret.max_hp, "修复不超过最大生命")
	var enemy := spawn("target_dummy", 1, Vector2(360, 950))
	turret._update_dormancy()
	_expect(not turret.dormant and CombatInteraction.can_acquire(turret, 1), "敌军入射程当Tick展开并恢复可选取")
	enemy.is_air = true
	turret._update_dormancy()
	_expect(not turret.dormant and turret._target_is_attackable(enemy), "空军同样触发恢复")
	enemy.position.y = 600
	turret._update_dormancy()
	_expect(turret.dormant, "敌军离开射程立即收缩")
	enemy.position.y = 950
	enemy.apply_stasis(2)
	turret._update_dormancy()
	_expect(turret.dormant, "凝滞敌军不唤醒炮台")
	enemy.control.apply_replica_stasis(false)
	turret.control.refresh_stun(1.0)
	turret._update_dormancy()
	_expect(not turret.dormant, "自身眩晕不会延长待机保护")
	enemy.free()
	turret._update_dormancy()
	_expect(turret.dormant, "最后敌人死亡或释放后恢复待机")
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload: Array = fixture.snapshot_payload(_main._snapshot_system, 950, turret)
	_expect(payload[NetworkSnapshotSystem.U_DORMANT] and payload.size() == NetworkSnapshotSystem.UNIT_PAYLOAD_SIZE, "快照同步独立收缩位")
	var packet: Array = fixture.packet(_main._snapshot_system, [payload], [], fixture.tower_payloads(_main._snapshot_system), 0.0, 180.0, false)
	_expect(_main._snapshot_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) != null, "收缩快照可正式解码")
	packet[NetworkSnapshotSystem.S_UNITS][0][NetworkSnapshotSystem.U_DORMANT] = 1
	_expect(_main._snapshot_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "收缩字段拒绝整数冒充bool")

	turret._tick_building_lifetime(23.0)
	_expect(turret.hp == 30.0, "经过24秒后仍有生命，不强制死亡")
	turret._tick_building_lifetime(1.0)
	_expect(turret.hp == 0.0, "超过标称时间仍以每秒30生命衰减，归零才死亡")
	for unit in main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()

func _check_projectile_presentation(turret: Unit) -> void:
	var view = load("res://assets/units/evolution_turret/evolution_turret_view.tscn").instantiate()
	_main.add_child(view)
	view.configure_unit_visual(turret)
	var anchor: BoneAttachment3D = view.create_projectile_anchor()
	_expect(anchor.get_parent().get_bone_name(anchor.bone_idx) == "Rocket", "自制彗星从Rocket炮口发出")
	_expect(not view.has_method("_sync_cast"), "普攻不再生成原版炮口特效")
	view.free()
