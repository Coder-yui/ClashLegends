extends SceneTree
## 阶段 3 核心机制回归编排入口：初始化测试场景 → 调用各领域 suite → 汇总失败 → 清理 → quit。
## 领域测试实现位于 tests/suites/，统一运行命令保持不变：
## Godot --headless --path . --script tests/mechanics_check.gd

var _failed := 0
var _main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_main = scene.instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame
	CardDBValidationSuite.new().run(self)
	await DeckBuilderSuite.new().run(self, _main)
	_main._start_local()
	_main.set_process(false)
	_main._ai.set_process(false)
	# 常规机制用例手动推进大量固定 tick，关闭自动兵线避免跨用例污染；兵线有独立回归。
	_main._minion_waves_enabled = false

	ArenaDeploymentSuite.new().run(self, _main)
	PresentationSuite.new().run(self, _main)
	BuildingMinionSuite.new().run(self, _main)
	NavigationCollisionSuite.new().run(self, _main)
	ActiveSkillSuite.new().run(self, _main)
	AnimationStateSuite.new().run(self, _main)
	CombatTargetingSuite.new().run(self, _main)
	GnarSuite.new().run(self, _main)
	XinSuite.new().run(self, _main)
	GwenSuite.new().run(self, _main)
	AurelionSolSuite.new().run(self, _main)
	var projectiles := ProjectileSuite.new(self, _main)
	projectiles._check_projectile_travel()
	projectiles._check_tower_projectile_visual()
	projectiles._check_imp_tower_damage()
	projectiles._check_splash_and_knockback()

	if _failed == 0:
		print("[机制检查] 全部通过")
	else:
		push_error("[机制检查] %d 项失败" % _failed)
	var result := _failed
	_main.free()
	_main = null
	await process_frame
	quit(result)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[通过] ", message)
	else:
		_failed += 1
		push_error("[失败] " + message)
