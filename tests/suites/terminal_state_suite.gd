extends RefCounted
## 两个独立 Main 场景，经正式命中/终局与真实编码数据验证可靠终态。
func run(harness: Object) -> void:
	var host = load("res://scenes/main.tscn").instantiate()
	var client = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(host)
	harness.root.add_child(client)
	host._start_local()
	client._start_local()
	host.set_process(false)
	client.set_process(false)
	host._ai.enabled = false
	client._ai.enabled = false
	host._snapshot_system.reset_session("terminal")
	client.mode = "client"
	client._snapshot_system.reset_session("terminal")
	host._sim_tick_id = 100
	var before: PackedByteArray = host._snapshot_system.capture()
	client._rpc_snapshot(before)
	var initial_hp: float = client._king_enemy.hp
	var cues: Array[StringName] = []
	var listener := func(card: String, cue: StringName, _pos: Vector2):
		if card == "match": cues.append(cue)
	client._audio_manager.cue_played.connect(listener)
	# 双方动作/Buff、区域、飞行声与排程同时在场；终局必须统一收尾。
	for main in [host, client]:
		var unit := Unit.new()
		unit.card_id = "masteryi"
		unit.setup(0, CardDB.get_card("masteryi"), "终局音轨")
		main.add_child(unit)
		main._audio_manager.attach_unit(unit, CardDB.get_card("masteryi"))
		main._audio_manager._start_sustain(unit, main._audio_manager._unit_entries[unit.get_instance_id()], &"active_buff", &"buff")
		main._audio_manager.start_zone_audio(100, "anivia", 0, "frost_storm", Vector2(360, 640), 30.0)
		main._audio_manager.start_projectile_launch(100, {"card_id": "gnar", "form": 0, "serial": 1}, Vector2(360, 640))
		main._active_skill_effect_system.frontal_effects.append({"timer": 30.0})
		main._commands.enqueue_card(0, "garen", Vector2(300, 800), 1000)
		main._commands.enqueue_deployment(0, "", Vector2.ZERO, 10.0, -1, -1, -1.0)
		main._commands.enqueue_impact(unit, {}, 10.0, &"impact", -1)
		harness._expect(not main._audio_manager._sustain_players.is_empty() and not main._audio_manager._zone_players.is_empty() and not main._audio_manager._projectile_launch_players.is_empty(), "终局测试开始时确实同时存在 Buff、区域和飞行音轨")
	# 快照刚发出后，下一 Tick 的真实弹体击杀水晶。
	host._sim_tick_id = 101
	host.launch_attack(host._towers[0], host._king_enemy, 100000.0, 100000.0, 0.0, 0.0, Color.WHITE)
	host._tick_projectiles(0.05)
	host._tick_match_rules(0.05)
	harness._expect(host.game_over and host._king_enemy.hp == 0.0 and client._king_enemy.hp == initial_hp, "致胜一击发生在上次普通快照之后，客户端尚未知道伤害")
	var terminal: Dictionary = bytes_to_var(var_to_bytes(host._terminal_result))
	client._rpc_end(terminal)
	harness._expect(client.game_over and client._king_enemy.hp == host._king_enemy.hp and client._king_enemy.nav_cells.is_empty(), "可靠终态在结束 UI 前应用最终生命与塔摧毁/导航状态")
	harness._expect(terminal.winner_team == 0 and terminal.reason == "nexus" and terminal.final_tick == 101 and cues.is_empty(), "结果使用队伍/原因/最终 Tick，客户端爆炸第五秒前不播失败")
	for main in [host, client]:
		harness._expect(main._audio_manager._nexus_players.size() == 1, "主客各自保留本地水晶爆炸实例")
		var player: AudioStreamPlayer2D = main._audio_manager._nexus_players.values()[0]
		harness._expect(player.playing, "终局清理不停止当前水晶爆炸")
		main._audio_manager._tick_terminal_audio(5.0)
		player.finished.emit() # 第五秒播报后，爆炸自然结束不重复播报。
		player.finished.emit()
	harness._expect(cues == [&"defeat"], "爆炸第五秒只触发一次本地阵营失败播报")
	var child_count: int = client.get_child_count()
	client._rpc_end(terminal)
	client._rpc_snapshot(before)
	client._sim_step(0.05)
	harness._expect(client.get_child_count() == child_count and cues.size() == 1 and client._king_enemy.hp == 0.0 and client.get_authoritative_server_tick() == 101, "重复终局与旧快照不重复 UI/声音、不复活塔、不推进模拟")
	for main in [host, client]:
		harness._expect(main._commands.inspect_cards().is_empty() and main._commands.inspect_deployments().is_empty() and main._commands.inspect_impacts().is_empty() and main._projectile_system.projectiles.is_empty() and main._projectile_system.client_snapshot().is_empty() and main._active_skill_effect_system.frontal_effects.is_empty(), "终局清理所有待执行命令、区域和在途弹体")
		main._audio_manager._process(1.0)
		main._audio_manager.start_zone_audio(101, "anivia", 0, "frost_storm", Vector2.ZERO, 30.0)
		main._audio_manager.start_projectile_launch(101, {"card_id": "gnar", "form": 0, "serial": 1}, Vector2.ZERO)
		harness._expect(main._audio_manager.battle_audio_stopped(), "终局持续声、区域声、飞行声与建筑待机全部停止，轮询和迟到事件不重启")
		harness._expect(not main.play_card(0, "garen", Vector2(300, 800), {"immediate": true}), "终局后公共出牌入口拒绝新命令")
	# 终态必须覆盖相同 Tick 已收到的普通快照；最终 Tick/会话不匹配则拒绝。
	client.game_over = false
	client._match_rules.finished = false
	client._snapshot_system.reset_session("terminal2")
	client._audio_manager.begin_battle()
	var final_packet: Array = bytes_to_var(terminal.terminal_state.decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	final_packet[NetworkSnapshotSystem.S_SESSION] = "terminal2"
	var old_packet: Array = final_packet.duplicate(true)
	old_packet[NetworkSnapshotSystem.S_TOWERS][-1][NetworkSnapshotSystem.T_HP] = 10.0
	client._rpc_snapshot(var_to_bytes(old_packet).compress(FileAccess.COMPRESSION_DEFLATE))
	terminal.session_id = "terminal2"
	terminal.terminal_state = var_to_bytes(final_packet).compress(FileAccess.COMPRESSION_DEFLATE)
	var mismatched := terminal.duplicate(true)
	mismatched.final_tick = 102
	client._rpc_end(mismatched)
	harness._expect(not client.game_over, "终态信封与快照 Tick 不一致时整体拒绝")
	client._rpc_end(terminal)
	harness._expect(client.game_over and client._snapshot_system.terminal_applied, "相同 Tick 的可靠最终状态仍能覆盖普通快照")
	host.free()
	client.free()
	# 新场景与真实菜单重载相同生命周期：终局音频屏障不会污染下一局。
	var next = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(next)
	next._start_local()
	next.set_process(false)
	harness._expect(not next.game_over and not next._match_rules.finished and next._terminal_result.is_empty() and not next._snapshot_system.terminal_applied and not next._audio_manager._battle_ended, "退出后新局重建比赛、网络与音频生命周期")
	next.free()
