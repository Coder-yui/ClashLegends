extends "res://tests/suites/battle_suite.gd"

func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	_expect(CardDB.validate_all(false).is_empty(), "琴女及全卡定义有效：" + str(CardDB.validate_all(false)))
	for team in 2:
		_check_healing(team)
		_check_wave(team)
		_check_structure_stun(team)
	_check_real_hit()
	_check_periodic_cycle()
	_check_controls()
	_check_network()
	_check_contract()
	_check_paid_skill()
	_check_vfx_organization()
	_check_wave_range()
	_check_authored_trails()
	_check_model_blends()
	_main.free()

func _clear() -> void:
	_main._projectile_system.clear_all()
	for unit in _main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()

func _check_healing(team: int) -> void:
	var actor := _spawn_ready_unit("sona", team, Vector2(300, 900))
	var ally := _spawn_ready_unit("garen", team, Vector2(400, 900))
	var air := _spawn_ready_unit("sona", team, Vector2(300, 800))
	var enemy := _spawn_ready_unit("target_dummy", 1-team, Vector2(400, 850))
	var building := _spawn_ready_unit("tombstone", team, Vector2(200, 900))
	for unit in [actor, ally, air, enemy, building]: unit.hp -= 200
	for tick in 40: actor.heal_aura.tick(actor, 0.05)
	for tick in 9: actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-200, "治疗首次等待10Tick")
	actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-182 and air.hp == air.max_hp-182 and actor.hp == actor.max_hp-182, "双方光环治疗空地友军及自身18")
	_expect(enemy.hp == enemy.max_hp-200 and building.hp == building.max_hp-200, "不治疗敌军和建筑")
	for tick in 5: actor.heal_aura.tick(actor, 0.05)
	actor.on_attack_landed(0, 52)
	for tick in 5: actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-164 and is_equal_approx(actor.heal_aura.remaining, 2.0), "攻击命中不刷新光环、不重置周期或额外治疗")
	ally.position = Vector2(650, 900)
	for tick in 10: actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-164, "离开范围立即停止受益")
	actor.position = Vector2(600, 900)
	for tick in 10: actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-146, "光环跟随来源移动")
	ally.grievous_wounds = true
	for tick in 10: actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-146, "重伤遵循通用100%禁疗")
	_clear()

func _check_real_hit() -> void:
	var actor := _spawn_ready_unit("sona", 0, Vector2(300, 900))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(430, 900))
	actor.move_speed = 0.0
	for tick in 11: actor.sim_tick(0.05)
	_expect(_main._projectile_system.projectiles.size() == 1 and actor.heal_aura.remaining == 0.0, "第11Tick发射，未命中不治疗")
	for tick in 8: _main._tick_projectiles(0.05)
	_expect(target.hp == target.max_hp-52 and actor.heal_aura.remaining == 0.0, "真实普攻命中也不启动光环")
	actor.heal_aura.clear()
	actor._target = target
	actor._deal_attack_damage_to(target, 52.0)
	target.apply_stasis(1.0)
	for tick in 8: _main._tick_projectiles(0.05)
	_expect(actor.heal_aura.remaining == 0.0, "在途目标凝滞导致失效不触发治疗")
	_clear()

func _check_controls() -> void:
	var actor := _spawn_ready_unit("sona", 0, Vector2(300, 900))
	var ally := _spawn_ready_unit("garen", 0, Vector2(400, 900))
	ally.hp -= 500
	for tick in 40: actor.heal_aura.tick(actor, 0.05)
	actor.stun(1.0)
	actor.freeze(1.0)
	for tick in 10: actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-482, "眩晕/冰冻不取消既有光环")
	actor.apply_stasis(1.0)
	for tick in 10: actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-482 and is_equal_approx(actor.heal_aura.remaining, 2.0), "凝滞抑制光环且不延寿")
	actor.control.tick_hard_controls(1.0)
	ally.apply_stasis(1.0)
	for tick in 10: actor.heal_aura.tick(actor, 0.05)
	_expect(ally.hp == ally.max_hp-482, "凝滞友军不接受治疗")
	ally.control.tick_hard_controls(1.0)
	for tick in 30: actor.heal_aura.tick(actor, 0.05)
	_expect(actor.heal_aura.remaining == 0.0 and ally.hp == ally.max_hp-428, "3秒终点最后一次治疗且不补发凝滞期间次数")
	actor.take_damage(99999)
	_expect(actor.heal_aura.remaining == 0.0 and actor.heal_aura_state_visual() == Vector2.ZERO, "死亡立即清空光环")
	_clear()

func _check_wave(team: int) -> void:
	var actor := _spawn_ready_unit("sona", team, Vector2(250, 900))
	var near := _spawn_ready_unit("target_dummy", 1-team, Vector2(360, 900))
	var far := _spawn_ready_unit("sona", 1-team, Vector2(500, 950))
	var outside := _spawn_ready_unit("target_dummy", 1-team, Vector2(450, 1010))
	var ally := _spawn_ready_unit("garen", team, Vector2(400, 900))
	var skill: Dictionary = CardDB.active_skills_for("sona")[0].duplicate(true)
	_main._projectile_system.launch_skill_fan(actor, skill, Vector2.RIGHT)
	_expect(near.hp == near.max_hp, "R发射不提前伤害")
	var shot: Dictionary = _main._projectile_system.projectiles.values()[0]
	_expect(NetworkSnapshotSystem._valid_visual_path(shot.visual_path) and shot.pos == actor.position + Vector2.RIGHT * actor.body_radius, "R挂点元数据可同步且不改变权威出生点")
	for tick in 10: _main._tick_projectiles(0.05)
	_expect(near.hp == near.max_hp-140 and far.hp == far.max_hp-140, "R穿透命中空地多目标，每目标一次")
	_expect(is_equal_approx(near.control.stun_timer, 1.0) and is_equal_approx(far.control.stun_timer, 1.0), "R命中眩晕1秒")
	_expect(outside.hp == outside.max_hp and ally.hp == ally.max_hp, "R不伤范围外和友军")
	_expect(actor.heal_aura.remaining == 0.0, "R伤害不触发治疗")
	_expect(_main._projectile_system.projectiles.is_empty(), "R0.5秒结束并销毁")
	_clear()

func _check_network() -> void:
	var actor := _spawn_ready_unit("sona", 0, Vector2(300, 900))
	for tick in 40: actor.heal_aura.tick(actor, 0.05)
	actor.heal_aura.tick(actor, 0.5)
	var system: NetworkSnapshotSystem = _main._snapshot_system
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload := fixture.snapshot_payload(system, actor.net_id, actor)
	var packet := fixture.packet(system, [payload], [], fixture.tower_payloads(system), 5.0, 180.0, false)
	_expect(system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) != null, "治疗年龄/剩余时长快照可往返")
	_expect(payload[system.U_HEAL_AURA] == Vector2(0.5, 2.5), "快照使用权威光环时钟")
	for invalid in [Vector2(NAN, 1), Vector2(-1, 1), Vector2(1, -1), [], 1.0]:
		var bad := packet.duplicate(true)
		bad[system.S_UNITS][0][system.U_HEAL_AURA] = invalid
		_expect(system.decode_validated(var_to_bytes(bad).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "非法光环快照整包拒绝")
	_main.runtime.mode = "client"
	actor.net_heal_aura = Vector2(0.5, 2.5)
	actor.hp = 100
	actor.heal_aura.tick(actor, 10.0)
	_expect(actor.hp == 100 and actor.heal_aura_state_visual() == Vector2(0.5, 2.5), "客户端不推进权威治疗")
	_main.runtime.mode = "server"
	_clear()

func _check_contract() -> void:
	for field in ["heal_aura_initial_delay", "heal_aura_trigger_interval", "heal_aura_radius", "heal_aura_duration", "heal_aura_pulse_interval", "heal_aura_amount"]:
		for value in [0.0, -1.0, INF, "bad"]:
			var bad := CardDB.get_card("sona").duplicate(true)
			bad[field] = value
			_expect(not CardDB.VALIDATOR.validate_all({"sona": bad}, false).is_empty(), "拒绝非法光环参数")

	var overlap := CardDB.get_card("sona").duplicate(true)
	overlap.heal_aura_trigger_interval = 2.0
	_expect(not CardDB.VALIDATOR.validate_all({"sona": overlap}, false).is_empty(), "拒绝触发周期短于光环持续时间")

	for value in ["bad", 1.0]:
		var bad := CardDB.get_card("sona").duplicate(true)
		bad.active_skills[0].projectile_model_launch = value
		_expect(not CardDB.VALIDATOR.validate_all({"sona": bad}, false).is_empty(), "拒绝非法模型出弹开关")

func _check_paid_skill() -> void:
	var wallet := ElixirManager.new()
	_main.add_child(wallet)
	_main.runtime.bind_account(0, wallet)
	_main.runtime._deck = ["sona", "garen", "ashe", "teemo", "xin", "freeze", "heal", "pix"]
	var actor: Unit = _main.runtime._spawn_card_units(0, "sona", Vector2(300, 1000), 0.0, 0)[0]
	actor._deploy_timer = 0.0
	var id := actor.active_ability_id
	wallet.elixir = 10.0
	_expect(_main.use_active_skill(id, 0), "正式R请求接受")
	_expect(wallet.elixir == 8.0 and not _main.use_active_skill(id, 0), "扣2金币且不接受重复请求")
	_main.runtime._sim_tick_id += 10
	_main.runtime._tick_pending_active_skills(0.05)
	var entry: Dictionary = _main.runtime._active_skills.entry(id)
	_expect(entry.uses_remaining == 1 and entry.cooldown_left == 12.0, "起手消费1次并启动12秒冷却")
	_clear()

func _check_vfx_organization() -> void:
	var adapter = preload("res://scripts/presentation/sona_projectile_3d.gd")
	for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]:
		var basis: Basis = adapter.missile_basis(direction)
		_expect(basis.y.is_equal_approx(direction) and basis.z.is_equal_approx(Vector3.UP), "R原生导弹Y前进/Z向上，覆盖双方与横向")
	for direction in [Vector3(0, -0.625, -8), Vector3(8, -0.625, 0), Vector3(-8, -0.625, 8)]:
		var basis: Basis = adapter.missile_basis(direction)
		_expect(basis.z.is_equal_approx(Vector3.UP) and is_zero_approx(basis.x.y) and is_zero_approx(basis.y.y), "R导弹排除高度字段造成的额外俯仰/侧倾")
	var wave_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/sona/wave/sampled.json"))
	var note_layer := -1
	for index in wave_data.emitters.size():
		if wave_data.emitters[index].name == "notetrail": note_layer = index
	# 原生导弹模拟器seed79、t=0.3、serial1，世界加速度保持世界向下。
	var note: Array = wave_data.frames[36][note_layer][0]
	_expect(Vector3(note[1], note[2], note[3]).distance_to(Vector3(-33.78793716430664, 14.075974941253662, -107.42233276367188)) < 0.001, "R采样保留世界重力，不把音符下坠旋转为前后漂移")
	var model := Node3D.new()
	_harness.root.add_child(model)
	model.position = Vector3(3, 4, 5)
	var effect = preload("res://assets/effects/sona/heal_aura.gd").new()
	_harness.root.add_child(effect)
	effect.configure(21.0, 0)
	effect.bind_model(model)
	effect.status_state = Vector2(1.0, 2.0)
	effect.advance_status(true, true, 0.0)
	_expect(effect._player.global_position.is_equal_approx(model.global_position), "W使用模型根部高度，不落回权威地面")
	model.position += Vector3(2, 0, 1)
	effect.advance_status(true, true, 0.0)
	_expect(effect._player.global_position.is_equal_approx(model.global_position), "W跟随空军模型移动")
	effect.action_name = &"crescendo"
	effect.action_serial = 1
	effect.action_state = Vector2(0.1, 1.0)
	effect.advance_status(false, false, 0.0)
	_expect(effect.visible and effect._cast.visible and not effect._player.visible and is_equal_approx(effect._cast._age, 0.1), "R起手0.1秒已显示施法层，不依赖W或0.3秒后创建的导弹")
	_expect(effect._cast.global_position.is_equal_approx(model.global_position), "R_Cas原生高度只在模型根部叠加一次")
	effect.action_state = Vector2.ZERO
	effect.advance_status(false, false, 0.0)
	_expect(not effect.visible and not effect._cast.visible, "取消/结束施法关闭施法者层")
	var proxy := UnitModel3D.new()
	proxy._active_buff_visual = effect
	proxy._source = Unit.new()
	proxy._source.free()
	proxy._update_active_buff_visual(0.0)
	_expect(not effect.presentation_enabled and effect.action_state == Vector2.ZERO, "死亡源释放后清空动作状态，不读取失效单位")
	proxy._source = null
	proxy._update_active_buff_visual(0.0)
	_expect(not effect.visible, "模型回收时无源对象也安全关闭附属特效")
	proxy.free()
	effect.free()
	model.free()
	var missiles = adapter.new()
	_harness.root.add_child(missiles)
	var wave = missiles._create("wave")
	wave.seek_motion(0.2, Vector3.ZERO, adapter.missile_basis(Vector3.FORWARD))
	missiles._missiles[1] = {"player": wave, "wave": true, "age": 0.2, "origin": Vector3.ZERO, "basis": adapter.missile_basis(Vector3.FORWARD)}
	missiles.sync_effects()
	_expect(missiles._missiles.is_empty() and missiles._tails.size() == 1 and is_instance_valid(wave), "R权威弹体移除后进入尾迹，不立即删除全部粒子")
	missiles._tick_tails(0.1)
	var retained := 0
	var only_existing := true
	for emitter in wave._sample_values.size():
		for particle in wave._sample_values[emitter]:
			retained += 1
			only_existing = only_existing and float(wave._birth_times[Vector2i(emitter, int(particle[0]))]) <= 0.2
	_expect(retained > 0 and only_existing, "R收尾只保留已有粒子，不继续发射")
	missiles._tick_tails(1.5)
	_expect(missiles._tails.is_empty() and not is_instance_valid(wave), "R尾迹到期回收")
	missiles.free()

func _check_model_blends() -> void:
	var model := preload("res://assets/units/sona/sona_view.tscn").instantiate()
	var native := preload("res://assets/units/sona/source/sona.glb").instantiate()
	_harness.root.add_child(model)
	_harness.root.add_child(native)
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var original: AnimationPlayer = native.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var original_skeleton: Skeleton3D = native.find_children("*", "Skeleton3D", true, false)[0]
	var clips := ["Idle1", "Run", "Attack1", "Attack2", "Attack3", "Spell4"]
	for clip in clips + ["Death"]:
		var unchanged := true
		player.stop()
		original.stop()
		player.play(clip, 0.0)
		original.play(clip, 0.0)
		for phase in [0.0, 0.1, 0.3, 0.5, 0.7, 0.99]:
			var time := float(phase) * original.get_animation(clip).length
			player.seek(time, true)
			original.seek(time, true)
			for bone in skeleton.get_bone_count():
				unchanged = unchanged and skeleton.get_bone_global_pose(bone).is_equal_approx(original_skeleton.get_bone_global_pose(bone))
		_expect(unchanged, "混合参考修正保留源单片段全部骨骼姿势：" + clip)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var original_meshes := native.find_children("*", "MeshInstance3D", true, false)
	var binds_unchanged := true
	for mesh_index in meshes.size():
		var skin: Skin = meshes[mesh_index].skin
		if skin == null: continue
		for bind in skin.get_bind_count():
			binds_unchanged = binds_unchanged and skin.get_bind_pose(bind).is_equal_approx(original_meshes[mesh_index].skin.get_bind_pose(bind))
	_expect(binds_unchanged, "保留Skin逆绑定，旋转参考不改变蒙皮")
	var weapon := skeleton.find_bone("WEAPON")
	for source in clips:
		for target in clips:
			if source == target: continue
			var worst_step := 0.0
			for phase in [0.0, 0.1, 0.3, 0.5, 0.7, 0.99]:
				player.stop()
				player.play(source, 0.0)
				player.seek(phase, true)
				var previous := skeleton.get_bone_pose_rotation(weapon)
				player.play(target, 0.12)
				for frame in 10:
					player.advance(1.0 / 60.0)
					var rotation := skeleton.get_bone_pose_rotation(weapon)
					worst_step = maxf(worst_step, rad_to_deg(previous.angle_to(rotation)))
					previous = rotation
			_expect(worst_step < 15.0, "琴的混合沿短弧，无单帧大角度翻转：%s>%s（%.2f度）" % [source, target, worst_step])
	model.free()
	native.free()

func _check_periodic_cycle() -> void:
	var actor := _spawn_ready_unit("sona", 0, Vector2(300, 900))
	actor.can_attack = false
	actor.move_speed = 0.0
	actor.hp = 100.0
	actor._deploy_timer = 1.0
	for tick in 40: actor.heal_aura.tick(actor, 0.05)
	_expect(not actor.heal_aura.initialized and actor.heal_aura.state() == Vector2.ZERO, "部署时间不累计治疗周期")
	actor._deploy_timer = 0.0
	for tick in 39: actor.sim_tick(0.05)
	_expect(actor.hp == 100.0 and actor.heal_aura.state() == Vector2.ZERO, "没有攻击目标也独立计时，2秒前不启动")
	actor.sim_tick(0.05)
	_expect(actor.heal_aura.state() == Vector2(0.0, 3.0) and actor.hp == 100.0, "部署后第40Tick开启3秒光环，启动不提前治疗")
	for tick in 60: actor.sim_tick(0.05)
	_expect(actor.hp == 208.0 and actor.heal_aura.state() == Vector2.ZERO, "3秒内恰好治疗6次共108，含终点脉冲")
	for tick in 39: actor.sim_tick(0.05)
	_expect(actor.heal_aura.state() == Vector2.ZERO and actor.hp == 208.0, "光环结束后有2秒间隔")
	actor.sim_tick(0.05)
	_expect(actor.heal_aura.state() == Vector2(0.0, 3.0), "第140Tick独立启动第二轮，不依赖攻击")
	_clear()
	for control in ["stun", "freeze", "stasis"]:
		actor = _spawn_ready_unit("sona", 0, Vector2(300, 900))
		actor.can_attack = false
		actor.move_speed = 0.0
		actor.hp = 100.0
		if control == "stun": actor.stun(20.0)
		elif control == "freeze": actor.freeze(20.0)
		else: actor.apply_stasis(20.0)
		for tick in 220: actor.heal_aura.tick(actor, 0.05)
		_expect(actor.heal_aura.state() == Vector2.ZERO and actor.hp == 100.0, "到期受控只等待，不启动治疗：" + control)
		actor.control.tick_hard_controls(20.0)
		actor.heal_aura.tick(actor, 0.05)
		_expect(actor.heal_aura.state() == Vector2(0.0, 3.0) and is_equal_approx(actor.heal_aura.cycle.remaining, 5.0), "恢复只启动一轮并重计5秒：" + control)
		for tick in 60: actor.heal_aura.tick(actor, 0.05)
		_expect(actor.hp == 208.0, "不补发受控期间多轮治疗：" + control)
		_clear()

func _check_wave_range() -> void:
	var adapter = preload("res://scripts/presentation/sona_projectile_3d.gd")
	var player_script = preload("res://assets/effects/sona/player.gd")
	for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var player = player_script.new()
		_harness.root.add_child(player)
		player.load_kind("wave")
		player.setup_native(0.0125)
		var start := Vector3(2, 4, 3)
		player.use_battle_range()
		var orientation: Basis = adapter.missile_basis(direction)
		player.seek_motion(0.0, start, orientation)
		player.seek_motion(0.1, start + direction * 1.6, orientation)
		for age in [0.1, 0.3, 0.5]:
			player.seek_motion(age, start + direction * age * 16.0, orientation)
			var hidden := 0
			for i in player._data.emitters.size():
				var emitter: Dictionary = player._data.emitters[i]
				if not player_script._is_range_emitter(emitter): continue
				hidden += 1
				_expect(player._sample_values[i].is_empty(), "实战隐藏超出光波的原版范围层：" + emitter.name)
			_expect(hidden == 3, "仅隐藏三层源范围标识，不隐藏光波与拖尾")
		_expect(player._materials[7].shader.resource_path == "res://assets/effects/solar_flare/add.gdshader", "R音波主体保留原shader，不裁剪为范围层")
		player.free()
	var native = player_script.new()
	_harness.root.add_child(native)
	native.load_kind("wave")
	native.setup_native(0.0125)
	native.seek_motion(0.1, Vector3.ZERO, adapter.missile_basis(Vector3.FORWARD))
	_expect(native._sample_values[15].size() > 0 and native._sample_values[16].size() > 0 and native._sample_values[17].size() > 0, "独立原版预览保留范围标识，实战适配不污染源采样")
	var skill: Dictionary = CardDB.active_skills_for("sona")[0]
	var wave_mesh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(native._data.emitters[7].mesh_path))
	var xs: Array[float] = []
	for index in wave_mesh.vertices.size() / 3: xs.append(float(wave_mesh.vertices[index*3]))
	var authored_width: float = (xs.max() - xs.min()) * 9.0 * 0.0125 * 40.0
	_expect(absf(authored_width - 130.0) < 0.1 and absf(float(skill.near_width) - authored_width) <= 10.1 and skill.near_width == skill.far_width, "R原生主体约130像素，140宽权威范围每侧仅约5像素余量")
	_expect(is_equal_approx(float(skill.length), 320.0), "R项目统一范围长度320，原版范围标识不扩大伤害")
	native.free()
	var basic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/sona/basic/sampled.json"))
	_expect(basic.emitters.size() == 8 and basic.emitters.all(func(e): return not player_script._is_range_emitter(e)), "原版8层BA_Mis不进入R范围裁剪")

func _check_authored_trails() -> void:
	# 源BIN：5层全为VfxPrimitiveArbitraryTrail。R_Edge的局部+X在导弹姿态下竖直；
	# 三条ORA_TRAILYUS的局部+X横跨航线。宽度轴不能由相机叉积替代。
	var player_script = preload("res://assets/effects/sona/player.gd")
	var adapter = preload("res://scripts/presentation/sona_projectile_3d.gd")
	var camera := Camera3D.new()
	_harness.root.add_child(camera)
	camera.position = Vector3(4, 8, 12)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]:
		var player = player_script.new()
		_harness.root.add_child(player)
		player.load_kind("wave")
		player.setup_native(0.0125)
		var pose: Basis = adapter.missile_basis(direction)
		for step in 7:
			player.seek_motion(step * 0.05, direction * step * 0.8 + Vector3.UP * 3.0, pose)
		for index in player._trails:
			var emitter: Dictionary = player._data.emitters[index]
			var mesh: ImmediateMesh = player._trails[index].mesh
			_expect(mesh.get_surface_count() == 1, "原版方向带生成实际三角带：" + emitter.name)
			var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var expected := Vector3.DOWN if emitter.name in ["R_Edge", "R_Edge1"] else -pose.x
			for pair in vertices.size() / 2:
				var across: Vector3 = player.global_basis * (vertices[pair*2] - vertices[pair*2+1])
				if across.length_squared() > 0.000001:
					_expect(across.normalized().dot(expected) > 0.9999, "R带宽轴对齐源局部X：" + emitter.name)
			camera.position = Vector3(-9, 3, -4)
			camera.look_at(Vector3.ZERO)
			player.seek_motion(player._age, player.global_position, pose)
			var rotated: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			_expect(vertices == rotated, "旋转相机不扭转原版arbitraryTrail：" + emitter.name)
		player.free()
	camera.free()

func _check_structure_stun(team: int) -> void:
	for kind in ["tombstone", "tower", "crystal"]:
		for in_stasis in [false, true]:
			# 实际弹体命中，覆盖建筑卡、公主塔、水晶；只推进弹体以精确观察控制时长。
			var actor := _spawn_ready_unit("sona", team, Vector2(250, 900))
			var target: Node2D
			if kind == "tombstone":
				target = _spawn_ready_unit("tombstone", 1-team, Vector2(430, 900))
			else:
				target = Tower.new()
				target.setup(1-team, {"hp": 2000, "damage": 0, "range": 100.0, "interval": 1.0, "radius": 30.0}, kind == "crystal")
				target.position = Vector2(430, 900)
				target.battle_context = actor.battle_context
				_main.add_child(target)
			if in_stasis: target.apply_stasis(2.0)
			var immune: bool = kind == "crystal"
			var protected: bool = in_stasis and not immune
			var before: float = target.hp
			var skill: Dictionary = CardDB.active_skills_for("sona")[0].duplicate(true)
			_main._projectile_system.launch_skill_fan(actor, skill, Vector2.RIGHT)
			for tick in 10: _main._tick_projectiles(0.05)
			_expect(is_equal_approx(target.hp, before if protected else before - 140.0), "R建筑伤害每次一次，凝滞隔离：" + kind)
			_expect(is_equal_approx(target.control.stun_timer, 0.0 if immune or protected else 1.0), "R眩晕建筑卡和防御塔1秒，水晶免疫：" + kind)
			if target is Tower: target.free()
			_clear()
