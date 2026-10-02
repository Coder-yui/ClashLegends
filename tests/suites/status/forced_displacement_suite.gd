extends "res://tests/suites/battle_suite.gd"
var units: Array[Unit] = []
func make(id: String, point: Vector2, team: int = 0) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team,id,point,{"deploy_time_override":0.0}))
	units.append(unit)
	return unit
func step(unit: Unit, count: int) -> void:
	for tick in count:
		unit.sim_tick(0.05)
		_main._movement.tick(0.05)
func clear() -> void:
	for unit in units:
		if is_instance_valid(unit): unit.free()
	units.clear()
func run(harness: Object, main: Node2D) -> void:
	_harness=harness
	_main=main
	_check_line_and_time()
	_check_dynamic_and_controls()
	_check_extra_boundaries()
	_check_batch_takeover()
	_check_failures()
	_check_real_spawns()
	_check_scattered_birth()
	clear()
func _check_line_and_time() -> void:
	var unit := make("voidmite",Vector2(360,720))
	_expect(unit.apply_forced_displacement(Vector2.UP,80,0.4),"强制位移允许跨河")
	_expect(is_equal_approx(unit.knockback.extension_limit,54) and unit.knockback.endpoint.y<589 and is_equal_approx(unit.knockback.speed,200),"中心线终点前延不超过默认54px，保持速度")
	_expect(unit.knockback.remaining>0.66 and unit.knockback.remaining<0.67,"延长距离增加控制时间")
	step(unit,4)
	_expect(unit.position.y>600 and unit.position.y<=680.001 and unit._knockback_timer>0,"途中穿过河流且仍受位移锁")
	step(unit,10)
	_expect(UnitLandingQuery.displacement_legal(unit,unit.position) and unit.position.y<589 and unit._knockback_timer==0,"延长抵达后恢复合法落点")
	clear()
	unit=make("voidmite",Vector2(360,720))
	unit.apply_forced_displacement(Vector2.UP,40,0.4)
	_expect(unit.knockback.endpoint.y>692 and unit.knockback.endpoint.y<693,"浅入河向前超上限后沿原线缩短")
	step(unit,6)
	var stop := unit.position
	_expect(not unit.knockback.in_transit and unit._knockback_timer>0 and (unit.action_permissions() & ControlState.MOVE)==0,"缩短提前到达但原控制锁未结束")
	step(unit,2)
	_expect(unit.position.is_equal_approx(stop) and unit._knockback_timer==0,"早停不继续走，按原时长解锁")
	clear()
	unit=make("voidmite",Vector2(330,720))
	unit.apply_forced_displacement(Vector2(1,-1),100,0.5)
	_expect(unit.knockback.endpoint.y>692 and unit.knockback.origin.distance_to(unit.knockback.endpoint)<100,"斜线不放宽世界距离上限")
	clear()
	unit=make("voidfish",Vector2(360,720))
	unit.apply_forced_displacement(Vector2.UP,80,0.4)
	_expect(unit.knockback.endpoint.is_equal_approx(Vector2(360,640)) and is_equal_approx(unit.knockback.remaining,0.4),"空军不套地面河流限制")
	step(unit,8)
	_expect(unit.position.distance_to(Vector2(360,640))<0.01,"空军保持原始距离")
	clear()
	unit=make("voidmite",Vector2(360,900))
	unit.body_radius=24
	unit.mass=100
	unit.move_speed=1
	unit.apply_forced_displacement(Vector2.RIGHT,100,0.5)
	_expect(is_equal_approx(unit.knockback.extension_limit,66) and is_equal_approx(unit.knockback.speed,200),"默认上限按起手实时半径，速度不受质量移速影响")
	clear()
func _check_dynamic_and_controls() -> void:
	for kind in ["stun","freeze","stasis","knockback","forced"]:
		var unit := make("voidmite",Vector2(360,720))
		unit.apply_forced_displacement(Vector2.UP,200,0.8)
		step(unit,4)
		var before := unit.position
		match kind:
			"stun": unit.stun(0.2)
			"freeze": unit.freeze(0.2)
			"stasis": unit.apply_stasis(0.2)
			"knockback": unit.apply_knockback(unit.position+Vector2(100,0),20,0.2,1.0)
			"forced": unit.apply_forced_displacement(Vector2.DOWN,80,0.4)
		if kind=="stasis":
			_expect(UnitLandingQuery.displacement_legal(unit,unit.position) and unit._knockback_timer==0,"河中凝滞同次先修正落点再固定")
			var frozen_point := unit.position
			step(unit,2)
			_expect(unit.position.is_equal_approx(frozen_point),"凝滞不补走旧路径")
		elif kind in ["stun","freeze"]:
			step(unit,2)
			_expect(unit.position.y<before.y and unit.knockback.collisionless,"眩晕/冰冻不取消外部强制位移")
		elif kind=="knockback":
			_expect(not unit.knockback.collisionless and unit.knockback.velocity.x<0 and is_equal_approx(unit._knockback_timer,0.2),"普通击退接管旧强制位移与锁，非法停点先修正")
		else:
			_expect(unit.knockback.origin.is_equal_approx(before) and unit.knockback.velocity.y>0 and unit.knockback.original_duration==0.4,"新强制位移从实际当前位置接管，不跳旧终点")
		clear()
	var unit := make("voidmite",Vector2(300,900))
	var friend := make("garen",Vector2(400,900))
	unit.apply_forced_displacement(Vector2.RIGHT,100,0.5)
	_expect(unit.knockback.endpoint.is_equal_approx(friend.position),"普通可推动单位不强制预排斥落点")
	step(unit,4)
	var blocker := make("tombstone",Vector2(400,900),1)
	var hp := blocker.hp
	step(unit,6)
	_expect(UnitLandingQuery.displacement_legal(unit,unit.position) and blocker.hp==hp,"到达时新增建筑使终点失效，近点修正无伤害")
	clear()
	unit=make("voidmite",Vector2(360,900))
	unit.apply_knockback(Vector2(260,900),30,0.3,1.0)
	unit.apply_forced_displacement(Vector2.UP,50,0.5)
	_expect(unit.knockback.collisionless and is_equal_approx(unit._knockback_timer,0.5),"强制位移接管普通击退不叠加锁")
	var end := unit.knockback.endpoint
	_expect(not unit.apply_forced_displacement(Vector2.ZERO,10,1) and unit.knockback.endpoint==end,"非法新请求不破坏旧位移")
	clear()
func _check_failures() -> void:
	var unit := make("voidmite",Vector2(360,900))
	var blocker := make("tombstone",Vector2(360,900),1)
	blocker.body_radius=150
	unit.apply_knockback(Vector2(260,900),10,0.3)
	var remaining := unit._knockback_timer
	_expect(not unit.apply_forced_displacement(Vector2.RIGHT,10,0.3,0) and unit._knockback_timer==remaining,"线段没有合法终点拒绝新请求并保留旧锁")
	blocker.body_radius=10000
	_expect(not unit.recover_displacement_position() and unit.knockback.recovery_pending and (unit.action_permissions() & ControlState.MOVE)==0,"全场无合法点时留在场内停止自主行动并待重试")
	blocker.free()
	step(unit,1)
	_expect(not unit.knockback.recovery_pending,"障碍消失后确定性重试恢复")
	clear()
func _check_real_spawns() -> void:
	var heard: Array = []
	var listener := func(card: String, cue: StringName, _position: Vector2):
		if card in ["voidmite", "voidfish"] and cue == &"spawn:start": heard.append(card)
	_main._audio_manager.cue_played.connect(listener)
	for team in [0,1]:
		heard.clear()
		var herald := make("rift_herald",Vector2(160,850) if team==0 else Vector2(560,430),team)
		var children: Array[Unit]=[]
		for tick in 700:
			_main._sim_step(0.05)
			for candidate in _main.get_tree().get_nodes_in_group("combatants"):
				if candidate is Unit and candidate.card_id=="voidmite" and not children.has(candidate): children.append(candidate)
			if not children.is_empty(): break
		_expect(children.size()==6,"双方先锋真实撞塔生成六只")
		_expect(heard.count("voidmite")==6,"六虫无部署锁仍每只播放一次出生声音")
		var starts: Array[Vector2]=[]
		for child in children:
			starts.append(child.position)
			units.append(child)
		for tick in 9: _main._sim_step(0.05)
		for index in children.size():
			_expect(children[index].position.distance_to(starts[index])>20 and children[index]._deploy_timer==0,"六虫整组实际外抛不互卡，无额外部署锁")
		clear()
		var queen := make("belveth",Vector2(360,850),team)
		var center := queen.position
		queen.take_damage(100000)
		children.clear()
		for candidate in _main.get_tree().get_nodes_in_group("combatants"):
			if candidate is Unit and candidate.card_id=="voidfish": children.append(candidate); units.append(candidate)
		_expect(children.size()==8,"女皇真实死亡生成八鱼")
		_expect(heard.count("voidfish")==8,"八鱼无部署锁仍每只播放一次出生声音")
		for child in children: _expect(child.position==center and child.knockback.origin==center,"八鱼强制散开起点恰是死亡点，不重复偏移")
		for tick in 9:
			for child in children: child.sim_tick(0.05)
			_main._movement.tick(0.05)
		for child in children: _expect(absf(child.position.distance_to(center)-100)<0.01,"八鱼实际散开100px不受质量和同点挤压改变")
		clear()

	_main._audio_manager.cue_played.disconnect(listener)

func _check_extra_boundaries() -> void:
	var unit := make("voidmite",Vector2(360,900))
	unit.apply_slow(2.0,0.1)
	var blocker := make("tombstone",Vector2(460,900),1)
	unit.apply_forced_displacement(Vector2.RIGHT,200,0.5)
	step(unit,5)
	_expect(unit.position.distance_to(Vector2(460,900))<0.01,"途中穿越建筑且不受减速改变速度")
	step(unit,5)
	_expect(unit.position.distance_to(Vector2(560,900))<0.01,"穿过建筑保持原终点")
	clear()
	unit=make("voidmite",Vector2(360,900))
	blocker=make("garen",Vector2(460,900),1)
	blocker.apply_stasis(2.0)
	unit.apply_forced_displacement(Vector2.RIGHT,200,0.5)
	step(unit,5)
	_expect(unit.position.distance_to(blocker.position)<0.01,"途中穿越凝滞占位，不推动凝滞目标")
	clear()
	unit=make("voidmite",Vector2(360,900))
	blocker=make("garen",Vector2(460,900),1)
	blocker.apply_stasis(2.0)
	unit.apply_forced_displacement(Vector2.RIGHT,100,0.5)
	_expect(unit.knockback.endpoint.x>490 and UnitLandingQuery.displacement_legal(unit,unit.knockback.endpoint),"凝滞占据终点时第一阶段沿线延长避让")
	clear()
	unit=make("voidmite",Vector2(690,900))
	unit.apply_forced_displacement(Vector2.RIGHT,100,0.5)
	step(unit,10)
	_expect(unit.position.x<=708.001 and unit.position.x>=690,"不能出界，沿线缩短且不反向越过起点")
	clear()
	unit=make("voidmite",Vector2(360,720))
	unit.apply_forced_displacement(Vector2.UP,80,0.4,0)
	_expect(unit.knockback.endpoint.y>692,"显式0延长上限不借用默认54")
	clear()
	unit=make("voidmite",Vector2(360,720))
	unit.apply_forced_displacement(Vector2.UP,80,0.4)
	unit.body_radius=30
	step(unit,14)
	_expect(UnitLandingQuery.displacement_legal(unit,unit.position) and unit.position.y<571,"结束按变化后的真实半径修正")
	clear()
	unit=make("voidfish",Vector2(360,720))
	unit.apply_forced_displacement(Vector2.UP,80,0.4)
	unit.is_air=false
	step(unit,8)
	_expect(UnitLandingQuery.displacement_legal(unit,unit.position),"空地类型变化后按实时类型结束落点")
	clear()
	unit=make("voidmite",Vector2(360,640))
	unit.position=Vector2(360,640) # 模拟自主位移已进入非法区域，绕过出生避让。
	unit.skill_dash_active=true
	unit.cancel_skill_cast()
	_expect(UnitLandingQuery.displacement_legal(unit,unit.position),"自主穿地形位移取消复用非法停点收尾")
	clear()
	unit=make("kayn",Vector2(360,640))
	unit.position=Vector2(360,640)
	unit.skill_dash_active=true
	unit.cancel_skill_cast()
	_expect(unit.position.is_equal_approx(Vector2(360,640)),"凯隐天然穿地形能力不被非法落点收尾改变")
	clear()
	unit=make("voidmite",Vector2(360,900))
	unit.apply_forced_displacement(Vector2.UP,80,0.4)
	step(unit,2)
	var snap: Array = _main._snapshot_system._unit_snapshot_payload(unit.net_id,unit)
	var decoded: Array = bytes_to_var(var_to_bytes(snap))
	_expect(decoded[NetworkSnapshotSystem.U_ACTION_PERMISSIONS]==unit.action_permissions() and (int(decoded[NetworkSnapshotSystem.U_ACTION_PERMISSIONS]) & ControlState.MOVE)==0,"快照沿用权威行动锁无需客户端重算轨迹")
	_expect(is_equal_approx(float(decoded[NetworkSnapshotSystem.U_X]),unit.position.x) and is_equal_approx(float(decoded[NetworkSnapshotSystem.U_Y]),unit.position.y),"快照包含实际强制位移位置")
	clear()

func _check_batch_takeover() -> void:
	var herald := make("rift_herald",Vector2(360,900))
	herald.structure_rush.phase=StructureRushState.Phase.PREPARING
	_expect(herald.apply_forced_displacement(Vector2.UP,50,0.5) and herald.structure_rush.phase==StructureRushState.Phase.READY,"强制位移与普通击退一致打断先锋准备")
	herald.structure_rush.phase=StructureRushState.Phase.DASHING
	var old_end := herald.knockback.endpoint
	_expect(not herald.apply_forced_displacement(Vector2.DOWN,50,0.5) and herald.knockback.endpoint==old_end,"先锋冲撞免控拒绝新强制位移，不破坏既有轨迹")
	clear()
	for forced_last in [false,true]:
		var unit := make("voidmite",Vector2(360,900))
		_main._combat.begin_batch(100,"mixed_displacements")
		var early: Array = _main._combat.next_displacement_order(unit)
		var late: Array = _main._combat.next_displacement_order(unit)
		unit.apply_forced_displacement(Vector2.UP,100,0.5,-1.0,{},late if forced_last else early)
		unit.apply_knockback(Vector2(260,900),20,0.2,1.0,early if forced_last else late)
		_main._combat.commit_batch()
		_expect(unit.knockback.collisionless==forced_last and is_equal_approx(unit._knockback_timer,0.5 if forced_last else 0.2),"同批普通/强制位移共用稳定顺序，最后有效请求接管")
		clear()

func _check_scattered_birth() -> void:
	for card in ["voidmite","voidfish"]:
		var unit := make(card,Vector2(360,900))
		unit.begin_scattered_birth(Vector2.RIGHT,50,0.45)
		var serial := unit.get_visual_action_serial()
		_expect(unit._deploy_timer==0 and unit.is_deployed() and CombatInteraction.allows_allied_target(unit,unit.team),"%s出生即实体可选，无部署锁" % card)
		var hp := unit.hp
		unit.take_damage(1)
		_expect(unit.hp<hp and unit.get_visual_action_duration()==0.45,"%s出生可受伤，动画基准0.45秒" % card)
		_expect((unit.action_permissions() & (ControlState.MOVE|ControlState.BASIC_ATTACK|ControlState.START_SKILL))==0,"%s仅外力限制散开自主行动" % card)
		step(unit,9)
		_expect(unit._knockback_timer==0 and unit._deploy_timer==0 and unit.get_visual_action_time_left()<0.000001 and (unit.action_permissions() & ControlState.BASIC_ATTACK)!=0,"%s正常散开与出生表现同期结束后立即可行动" % card)
		_expect(unit.get_visual_action_serial()==serial,"%s出生不重复播放" % card)
		clear()
		for kind in ["stun","freeze","stasis","knockback","forced"]:
			unit=make(card,Vector2(360,900))
			unit.begin_scattered_birth(Vector2.RIGHT,50,0.45)
			step(unit,2)
			serial=unit.get_visual_action_serial()
			match kind:
				"stun": unit.stun(0.6)
				"freeze": unit.freeze(0.6)
				"stasis": unit.apply_stasis(0.2)
				"knockback": unit.apply_knockback(unit.position+Vector2(50,0),20,0.2,1)
				"forced": unit.apply_forced_displacement(Vector2.UP,20,0.2)
			if kind=="stasis":
				_expect(unit._knockback_timer==0,"凝滞立即取消出生外抛")
			step(unit,5 if kind=="knockback" else 4)
			_expect(unit._deploy_timer==0 and unit.get_visual_action_serial()==serial,"%s/%s不遗留部署锁或重播出生" % [card,kind])
			if kind in ["stasis","knockback","forced"]:
				_expect(unit._knockback_timer==0 and (unit.action_permissions() & ControlState.BASIC_ATTACK)!=0,"%s/%s新控制结束即可行动，不等旧散开或部署" % [card,kind])
			else:
				step(unit,3)
				_expect(unit._knockback_timer==0 and (unit.action_permissions() & ControlState.BASIC_ATTACK)==0,"%s剩余硬控单独限制外抛后行动" % kind)
				step(unit,6)
				_expect((unit.action_permissions() & ControlState.BASIC_ATTACK)!=0,"%s剩余硬控结束后无额外等待" % kind)
			clear()
	var unit := make("voidmite",Vector2(360,720))
	unit.begin_scattered_birth(Vector2.UP,80,0.45)
	_expect(unit.knockback.remaining>0.7 and unit.get_visual_action_duration()==0.45,"落点延长只延长外力控制，出生动画仍0.45秒")
	step(unit,9)
	_expect(unit._knockback_timer>0 and unit.get_visual_action_time_left()<0.000001 and unit._deploy_timer==0,"延长时出生表现先结束，真实外力仍限制行动")
	step(unit,7)
	_expect(unit._knockback_timer==0 and (unit.action_permissions() & ControlState.MOVE)!=0,"延长控制结束并合法落位后立即可动")
	clear()
	unit=make("voidmite",Vector2(360,720))
	unit.begin_scattered_birth(Vector2.UP,40,0.45)
	step(unit,7)
	_expect(not unit.knockback.in_transit and unit._knockback_timer>0 and unit.get_visual_action_time_left()>0,"缩短早停仍等待原0.45秒且出生表现继续")
	step(unit,2)
	_expect(unit._knockback_timer==0 and unit.get_visual_action_time_left()<0.000001,"缩短等待与基准出生动画同期结束")
	clear()
	unit=_main._spawn_unit(UnitSpawnRequest.new(0,"garen",Vector2(360,900)))
	units.append(unit)
	_expect(unit._deploy_timer>0,"普通下牌部署锁不受召唤出生调整影响")
	clear()
