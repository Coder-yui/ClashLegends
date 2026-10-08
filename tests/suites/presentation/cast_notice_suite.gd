extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var notice = main._cast_notice
	notice.clear()
	_expect(main._cast_spell(0, "heal", Vector2(300, 800)), "成功法术释放")
	_expect(notice.entries.is_empty(), "普通法术未使用技能不提示")
	main._cast_spell(0, "heal", Vector2(300, 800), true, 1)
	_expect(notice.entries.size() == 1 and notice.entries[0].team == 0, "主动槽强化法术只提示一次")
	main._cast_spell(1, "freeze", Vector2(300, 800), true)
	_expect(notice.entries.size() == 2 and notice.entries[1].team == 1, "红方提示归属施放方")
	var count: int = notice.entries.size()
	main._play_card_event(main._last_card_event_id, "heal", "cast:notice", Vector2.ZERO)
	_expect(notice.entries.size() == count, "重复可靠事件不重播")
	_expect(not main._cast_spell(0, "mirror", Vector2.ZERO), "无复制源拒绝镜像")
	_expect(notice.entries.size() == count, "失败法术无提示")
	main._cast_spell(0, "mirror", Vector2(300, 800), false, 0, {"card_id": "heal", "generation": -1})
	_expect(notice.entries.size() == count, "普通镜像法术不提示")
	main._cast_spell(0, "mirror", Vector2(300, 800), true, 0, {"card_id": "heal", "generation": -1})
	_expect(notice.entries.size() == count + 1 and notice.entries[-1].texture == CardArt.skill_icon(CardDB.get_card("mirror")), "镜像法术只显示镜像图标一次")
	var unit := main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(300, 900), {"deploy_time_override": 0.0})) as Unit
	var skill: Dictionary = CardDB.active_skills_for("garen")[1]
	_expect(main._start_active_skill_cast(unit, skill), "主动技能成功起手")
	_expect(notice.entries[-1].texture == CardArt.skill_icon(skill), "主动技能显示实际候选图标")
	notice._process(1.4)
	_expect(notice.entries.is_empty(), "消散后释放提示数据")
	main._present_cast_notice(1, "heal", 1)
	main.clear_preview_battle()
	_expect(notice.entries.is_empty(), "清场清理提示")
	var blue: Color = notice.color_for(0)
	var red: Color = notice.color_for(1)
	notice.presentation.viewer_team = 1
	_expect(notice.color_for(1) == blue and notice.color_for(0) == red, "红方视角仍为己方蓝圈敌方红圈")
	notice.presentation.viewer_team = 0
	var old_mode: String = main.mode
	main.mode = "client"
	var event_id: int = main._last_card_event_id + 1
	var args := [event_id, "heal", "cast:notice", Vector2.ZERO, 1, 1]
	preload("res://tests/fixtures/network_fixture.gd").deliver(main, &"_rpc_card_event", args)
	_expect(notice.entries.size() == 1 and notice.entries[0].team == 1 and notice.entries[0].texture == CardArt.skill_icon(CardDB.active_skills_for("heal")[1]), "客户端可靠事件显示对方实际技能候选")
	preload("res://tests/fixtures/network_fixture.gd").deliver(main, &"_rpc_card_event", args)
	_expect(notice.entries.size() == 1, "客户端重复消息不重播")
	main._rpc_card_event("expired-session", event_id + 1, "heal", "cast:notice", Vector2.ZERO, 0, 0)
	_expect(notice.entries.size() == 1, "旧会话提示拒绝")
	main.mode = old_mode
	notice.clear()
