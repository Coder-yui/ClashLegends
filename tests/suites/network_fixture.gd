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
