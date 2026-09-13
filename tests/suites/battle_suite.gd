extends RefCounted
## 共享测试绑定与断言转发；场景生命周期仍由统一入口持有。
var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func _run_main_ticks(count: int) -> void:
	for _tick in count:
		_main._sim_step(_main.SIM_DT)
