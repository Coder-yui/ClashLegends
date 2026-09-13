class_name CommandSchedule
extends RefCounted
## 命令与施法排程的唯一状态所有者。入队资格/费用由 Main 校验，排程不读取 Main。
var card_commands: Array[Dictionary] = []
var skill_commands: Array[Dictionary] = []
var pre_deployments: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var next_pre_deploy_id := 1
var impact: Callable
var cast_end: Callable

func take_card_commands(tick: int) -> Array[Dictionary]:
	return _take_due(card_commands, tick)

func take_skill_commands(tick: int) -> Array[Dictionary]:
	return _take_due(skill_commands, tick)

func _take_due(queue: Array[Dictionary], tick: int) -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for entry in queue:
		if int(entry.execute_tick) <= tick:
			ready.append(entry)
		else:
			waiting.append(entry)
	queue.assign(waiting)
	return ready

func take_pre_deployments(dt: float) -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for entry in pre_deployments:
		entry.time_left = maxf(float(entry.get("time_left", 0.0)) - dt, 0.0)
		if float(entry.time_left) <= 0.001:
			ready.append(entry)
		else:
			waiting.append(entry)
	pre_deployments.assign(waiting)
	return ready

func tick_impacts(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	for pending in impacts:
		var source = (pending.source_ref as WeakRef).get_ref()
		if not source is Unit or not is_instance_valid(source) or source.hp <= 0.0:
			continue
		var unit := source as Unit
		if unit.is_frozen() or unit.is_stunned():
			waiting.append(pending)
			continue
		pending.time_left = maxf(0.0, float(pending.time_left) - dt)
		if float(pending.time_left) > 0.001:
			waiting.append(pending)
			continue
		if StringName(pending.get("phase", &"impact")) == &"cast_end":
			cast_end.call(unit, pending.skill)
		else:
			impact.call(unit, pending.skill)
	impacts = waiting
