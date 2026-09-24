extends "res://scripts/main.gd"
## 终局网络测试需要固定盖伦出牌；随机首手由 MirrorSuite 和双进程镜像配方覆盖。
func _initialize_authoritative_card_cycle(team: int, deck: Array) -> bool:
	if not super._initialize_authoritative_card_cycle(team, deck): return false
	preload("res://tests/suites/network_fixture.gd").fixed_cycle(self, team, deck)
	return true
