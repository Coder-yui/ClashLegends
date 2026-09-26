extends "res://scripts/main.gd"
## 终局网络测试需要固定盖伦出牌；随机首手由 MirrorSuite 和双进程镜像配方覆盖。
func _ready() -> void:
	# 场景需要盖伦携带一费技能，不能依赖新增卡牌后的数据库注册顺序。
	_deck = ["garen", "ashe", "xin", "teemo", "gnar", "heal", "freeze", "tombstone"]
	_active_skill_choices = {"garen": 0}
	super._ready()

func _initialize_authoritative_card_cycle(team: int, deck: Array) -> bool:
	if not super._initialize_authoritative_card_cycle(team, deck): return false
	preload("res://tests/suites/network_fixture.gd").fixed_cycle(self, team, deck)
	return true
