extends RefCounted
## 白盒表现回放也走正式会话门禁，临时身份不会泄漏到后续套件。
static func deliver(main: Node, method: StringName, args: Array) -> void:
	var previous = main._session
	var session := MatchSession.new()
	session.join("presentation-fixture")
	session.phase = MatchSession.Phase.RUNNING
	main._session = session
	main.callv(method, [session.session_id] + args)
	main._session = previous

## 与出牌排序无关的机制测试显式安装固定牌序；随机开局另由镜像套件覆盖。
static func fixed_cycle(main: Node, team: int, deck: Array) -> void:
	main._authoritative_card_cycles[team] = CardCycle.new(deck, false)
	main._sync_card_cycle_ui(team)
