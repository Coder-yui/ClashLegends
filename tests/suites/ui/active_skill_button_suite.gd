extends "res://tests/suites/battle_suite.gd"
const ButtonView := preload("res://scripts/ui/active_skill_button.gd")
const NetworkFixture := preload("res://tests/fixtures/network_fixture.gd")
var bar: ActiveSkillBar

func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	_main.runtime.mode = "local"
	_main.runtime.local_team = 0
	_main.runtime._deck = ["garen", "xin", "ashe", "teemo", "freeze", "heal", "tombstone", "gnar"]
	for team in 2:
		var wallet := ElixirManager.new()
		_main.add_child(wallet)
		_main.runtime.bind_account(team, wallet)
	_main.runtime._match_started = true
	_main.runtime.session.phase = MatchSession.Phase.RUNNING
	bar = ActiveSkillBar.new()
	bar.can_submit = _main._can_submit_active_skill
	_main._active_skill_bar = bar
	_main.add_child(bar)
	_main.runtime.account(0).changed.connect(bar.set_elixir)
	_check_states_and_lifecycle()
	_check_groups_icons_and_pause()
	_check_resources()
	_check_replica_and_corrections()
	_check_layout()
	_main.free()
	_main = null

func _spawn(card: String, slot: int = 0) -> Unit:
	_main.runtime._deck[slot] = card
	return _main._spawn_unit(UnitSpawnRequest.new(0, card, Vector2(200 + slot * 200, 900), {"position_resolved": true, "deploy_time_override": 0.0, "active_slot": slot}))

func _sync() -> void:
	bar.set_elixir(_main.runtime.account(0).elixir)
	_main._sync_active_skill_deployment_readiness()

func _check_states_and_lifecycle() -> void:
	_main.runtime.account(0).elixir = 10
	var unit := _spawn("kassadin")
	var other := _spawn("garen", 1)
	var id := unit.active_ability_id
	var right: Vector2 = bar._buttons[1].position
	_sync()
	_expect(not bar._buttons[0].disabled and bar._buttons[0].cost_label.text == "0", "卡萨丁真实首发0费正常可用")
	var entry: Dictionary = _main.runtime._active_skills.entry(id)
	var before := int(entry.uses_remaining)
	_expect(_main.use_active_skill(id, 0), "真实提交0费技能")
	_sync()
	_expect(bar.is_pending(id) and not _main.use_active_skill(id, 0) and bar._buttons[0].disabled and not bar._buttons[0].cooldown_label.visible and int(_main.runtime._active_skills.entry(id).uses_remaining) == before, "待执行防重复、无假CD、不私扣次数")
	_run_main_ticks(10)
	_sync()
	_expect(not bar.is_pending(id) and bar._buttons[0].cost_label.text == "1" and int(_main.runtime._active_skills.entry(id).uses_remaining) == before - 1, "实际执行后动态费用与剩余次数更新")
	for remaining in [6.0, 3.7, 0.1, 0.05, 0.0011, 0.0]:
		_main.runtime._active_skills.replace_replica(id, 1, remaining)
		_main.runtime.account(0).elixir = 0
		_sync()
		var button = bar._buttons[0]
		var cooling: bool = remaining > 0.001
		_expect(button.cooldown_label.visible == cooling and (button.cooldown_label.text != "0.0" if cooling else button.cooldown_label.text.is_empty()), "CD边界%f：正数不显示0.0，到期清除" % remaining)
		_expect(button.skill_icon.material.get_shader_parameter("cooldown_active") == cooling and button.cost_label.get_theme_color("font_color").r > button.cost_label.get_theme_color("font_color").g, "CD与缺钱可组合，0CD不伪造遮罩")
	var finite := _spawn("garen")
	id = finite.active_ability_id
	_main.runtime._active_skills.replace_replica(id, 0, 4)
	_sync()
	_expect(not bar.is_slot_visible(0) and bar.is_slot_visible(1) and bar._buttons[1].position == right, "有限最后一次耗尽隐藏且其他槽位不移动")
	var fresh := _spawn("garen")
	var fresh_id := fresh.active_ability_id
	bar.set_pending(id, true)
	bar.update_skill_state(id, 0, 99, false, 99, 1)
	_sync()
	_expect(bar.current_ability_id(0) == fresh_id and bar.is_slot_visible(0) and not bar.is_pending(fresh_id) and bar._states[0].cooldown_left == 0, "重部署恢复，新槽位拒绝旧资格状态")
	_main.runtime.account(0).elixir = 10
	_main.runtime._active_skills.replace_replica(fresh_id, 2, 0)
	fresh.control.refresh_stun(1.0)
	_sync()
	_expect(bar._buttons[0].lock_mark.visible and not bar._buttons[0].disabled and bar._buttons[0].tooltip_text.contains("执行时复核"), "受控锁提示仍沿用真实提交权限")
	var balance: float = _main.runtime.account(0).elixir
	_expect(_main.use_active_skill(fresh_id, 0), "受控时接受技能指令")
	_sync()
	_expect(_main.runtime.account(0).elixir == balance - 1 and bar._states[0].uses == 2 and not bar._buttons[0].cooldown_label.visible, "接受时只扣费，未执行不消费次数CD")
	_run_main_ticks(10)
	_sync()
	_expect(_main.runtime.account(0).elixir == balance and not bar.is_pending(fresh_id) and bar._states[0].uses == 2 and bar._states[0].cooldown_left == 0, "执行仍受控取消、退款、恢复真实按钮")
	fresh.control.stun_timer = 0
	# 免费重施与无限次数不会被付费计数0隐藏。
	_main.runtime._active_skills.replace_replica(fresh_id, 0, 4, true)
	_sync()
	_expect(bar.is_slot_visible(0) and bar._buttons[0].uses_label.text == "1" and bar._buttons[0].cost_label.text == "0" and not bar._buttons[0].cooldown_label.visible, "真实免费资格独立于付费次数和CD")
	var replacement_id := fresh.active_ability_id
	fresh.take_damage(fresh.hp * 2)
	_expect(bar.current_ability_id(0) == -1 and not bar.is_slot_visible(0), "死亡移除按钮")
	bar.set_pending(replacement_id, true)
	unit.free()
	finite.free()
	other.free()
	if is_instance_valid(fresh): fresh.free()

func _check_groups_icons_and_pause() -> void:
	_main.runtime.account(0).elixir = 10
	_main.runtime._deck[0] = "minion_squad"
	var members: Array[Unit] = _main.runtime._spawn_card_units(0, "minion_squad", Vector2(360, 1000), 0.0, 0)
	var id := members[0].active_ability_id
	_sync()
	_expect(_main.use_active_skill(id, 0), "编队技能真实提交")
	members[0].take_damage(100000)
	_sync()
	_expect(bar.current_ability_id(0) == id and bar.is_pending(id) and _main.runtime._active_skills.entry(id).unit != members[0], "编队队长死亡转交保留同一按钮和在途指令")
	_main.runtime._sim_tick_id += 10
	_main.runtime._tick_pending_active_skills(0.05)
	_sync()
	_expect(not bar.is_pending(id) and bar._states[0].uses == 0 and not bar.is_slot_visible(0), "编队继任者只执行一次并刷新真实次数")
	for member in members: member.free()
	_main.runtime._deck[0] = "mirror"
	var copied: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(300, 900), {"position_resolved": true, "deploy_time_override": 0.0, "active_slot": 0}))
	_sync()
	_expect(bar._icons[0].texture == CardArt.skill_icon(_main.runtime._active_skills.entry(copied.active_ability_id).skill) and not bar._buttons[0].disabled, "镜像主动槽沿复制来源技能图标与原资格查询")
	_main.runtime._active_skills.replace_replica(copied.active_ability_id, 1, 3.7)
	_sync()
	_main._workbench.enabled = true
	_main._workbench.battle_active = false
	_main._process(1.0)
	_expect(bar._states[0].cooldown_left == 3.7, "工作台暂停时不另跑UI冷却时钟")
	_main._workbench.enabled = false
	_main._sim_step(0.05)
	_sync()
	_expect(bar._states[0].cooldown_left < 3.7, "恢复权威Tick后UI冷却跟随推进")
	copied.free()
	for card in ["jayce", "gnar", "kayn"]:
		var unit := _spawn(card)
		var skill: Dictionary = _main.runtime._active_skills.entry(unit.active_ability_id).skill
		_expect(bar._icons[0].texture == CardArt.skill_icon(skill), card + "沿用当前形态图标配置合同")
		unit.free()
	bar.show_skill(0, 999999, "缺省图标", Color.WHITE)
	_expect(bar._icons[0].texture == null and bar._buttons[0].get_node("Fallback").text == "缺", "明确缺省图标沿项目文字合同，不借用其他图片")
	bar.remove_skill(999999)
	var old_id := bar.current_ability_id(0)
	_main.runtime._deck[0] = "freeze"
	_main.runtime._cast_spell(0, "freeze", Vector2(360, 900), true)
	_expect(bar.current_ability_id(0) == old_id, "纯法术强化不新增独立点击按钮")

func _check_resources() -> void:
	_main.runtime.account(0).elixir = 10
	for card in ["sett", "pantheon", "gwen", "samira", "aurelionsol"]:
		var unit := _spawn(card)
		var id := unit.active_ability_id
		var skill: Dictionary = _main.runtime._active_skills.entry(id).skill
		for ratio in [0.0, 0.5, 1.0]:
			unit.skill_resource_value = unit.skill_resource_max * ratio
			_sync()
			var resource: Dictionary = bar._buttons[0].resource
			_expect(resource.visible == unit.is_skill_resource_visible() and resource.segments == unit.get_skill_resource_segment_count() and resource.stacks == unit.get_skill_resource_stacks() and resource.color == unit.get_skill_resource_fill_color() and resource.ratio == unit.get_skill_resource_ratio(), card + "按钮共用头顶资源分类、层数、颜色与比例")
			_expect(bar._buttons[0].disabled == not _main._can_submit_active_skill(id), card + "资源按钮权限复用原查询")
			if not bool(skill.get("requires_full_resource", false)):
				_expect(not bar._buttons[0].disabled, card + "有资源条不添加满层门槛")
		_main.runtime._active_skills.replace_replica(id, 0 if bool(skill.get("unlimited_uses", false)) else 1, 3.7)
		_sync()
		_expect(bar._buttons[0].resource.color == unit.skill_resource_full_color and bar._buttons[0].cooldown_label.visible, card + "满层+CD独立表现")
		if bool(skill.get("unlimited_uses", false)):
			_expect(bar.is_slot_visible(0) and bar._buttons[0].uses_label.text == "∞", "无限次数即使付费计数归零也不隐藏")
		unit.skill_resource_value = 0
		_sync()
		_expect(bar._buttons[0].resource.ratio == 0, "消费/清空立即显示实际资源")
		unit.free()
	var no_resource := _spawn("garen")
	_sync()
	_expect(not bar._buttons[0].resource.visible, "无积累机制不显示外圈")
	no_resource.free()

func _check_replica_and_corrections() -> void:
	_main.runtime.mode = "server"
	_main.runtime.account(0).elixir = 10
	var unit := _spawn("pantheon")
	var id := unit.active_ability_id
	unit.skill_resource_value = 2
	unit.control.refresh_stun(1)
	var packet: PackedByteArray = _main._snapshot_system.capture(0)
	var decoded = _main._snapshot_system.decode_validated(packet)
	_expect(decoded != null, "当前70字段快照校验通过")
	var client = preload("res://tests/fixtures/authority_battle.gd").new()
	_harness.root.add_child(client)
	client.runtime.mode = "client"
	client.runtime.local_team = 0
	var wallet := ElixirManager.new()
	client.add_child(wallet)
	client.runtime.bind_account(0, wallet)
	client.runtime._match_started = true
	client.runtime._deck = _main.runtime._deck.duplicate()
	client.runtime.session.phase = MatchSession.Phase.RUNNING
	client._snapshot_system.lifecycle.reset(_main._snapshot_system.lifecycle.session_id)
	client._active_skill_bar = ActiveSkillBar.new()
	client._active_skill_bar.can_submit = client._can_submit_active_skill
	client.add_child(client._active_skill_bar)
	_expect(client._snapshot_system.apply_decoded(decoded), "真实快照创建客户端副本")
	client._sync_active_skill_deployment_readiness()
	var replica = client.world.find_replica_unit(unit.net_id)
	var host_view: Dictionary = _main._skill_button_presentation(unit, _main.runtime._active_skills.entry(id).skill)
	var replica_view: Dictionary = client._skill_button_presentation(replica, client.runtime._active_skills.entry(id).skill)
	_expect(host_view == replica_view and replica_view.locked and client._active_skill_bar._buttons[0].lock_mark.visible, "客户端共用资源数据且锁来自主机起手结果")
	# 未变化期间不自行推进倒计时；暂停、终局或断续快照没有第二时钟。
	client.runtime.apply_skill_replica(id, 1, 0.05)
	client._sync_active_skill_deployment_readiness()
	var button = client._active_skill_bar._buttons[0]
	var text_before: String = button.cooldown_label.text
	# 该夹具没有音频节点；只推进正式客户端状态同步及纯按钮自然帧，避免调用对局音频更新。
	client._sync_active_skill_deployment_readiness()
	button.notification(Node.NOTIFICATION_PROCESS)
	_expect(button.cooldown_label.text == text_before and button.cooldown_label.text == "0.1" and button.disabled, "客户端帧间不提前解锁或让最后0.1消失")
	client.runtime.game_over = true
	client._process(1.0)
	_expect(button.cooldown_label.text == text_before, "终局不自行推进CD")
	client.runtime.game_over = false
	client.runtime.apply_skill_replica(id, 1, 0)
	client._sync_active_skill_deployment_readiness()
	_expect(not button.cooldown_label.visible and not button.skill_icon.material.get_shader_parameter("cooldown_active"), "新快照校正为完成立即清除遮罩数字")
	var raw: Array = decoded.packet.duplicate(true)
	raw[NetworkSnapshotSystem.S_UNITS][0][NetworkSnapshotSystem.U_ACTIVE_SKILL_START_READY] = 1
	_expect(_main._snapshot_system.decode_validated(var_to_bytes(raw).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "新起手字段拒绝错误类型，整包校验")
	client.free()
	unit.free()
	_main.runtime.mode = "local"

func _check_layout() -> void:
	var unit := _spawn("garen")
	for viewport in [Vector2(720, 1280), Vector2(480, 720), Vector2(1280, 720)]:
		bar.apply_layout(viewport)
		var left: Vector2 = bar.offset + bar._buttons[0].position * bar.scale
		_expect(left.x >= 0 and left.y >= 0 and left.x + 65 * bar.scale.x < viewport.x, "窗口%s角标与点击位置同变换" % viewport)
	_expect(bar._buttons[0]._has_point(Vector2(29, 29)) and not bar._buttons[0]._has_point(Vector2.ZERO), "命中区域匹配圆形按钮")
	var tooltip: Label = bar._buttons[0]._make_custom_tooltip(bar._buttons[0].tooltip_text)
	_expect(tooltip.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and tooltip.text.contains("消耗"), "名称说明与原因的悬停提示自动换行")
	tooltip.free()
	unit.free()
