extends RefCounted
## 共享测试绑定与断言转发；场景生命周期仍由统一入口持有。
var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func _run_main_ticks(count: int) -> void:
	for _tick in count:
		_main._sim_step(_main.SIM_DT)

func _spawn_test_unit(card_id: String, p_team: int, pos: Vector2) -> Unit:
	var stats := CardDB.get_card(card_id).duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = pos
	unit.setup(p_team, stats, stats.name)
	_main.add_child(unit)
	return unit

## 只查找既有表现代理，不创建模型或改变模拟状态。
func _view_for(unit: Unit) -> UnitModel3D:
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			return child as UnitModel3D
	return null
