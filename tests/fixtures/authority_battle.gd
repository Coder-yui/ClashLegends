extends "res://scripts/main.gd"
class ResizeTrackedWorld extends "res://scripts/battle/battle_world.gd":
	var footprint_releases: Array[int] = []
	func release_structure_footprint(structure: Node2D) -> void:
		if not structure.nav_cells.is_empty(): footprint_releases.append(structure.get_instance_id())
		super.release_structure_footprint(structure)

	var resize_requests := 0
	func ensure_unit_form_resize_safe(unit: Unit) -> void:
		resize_requests += 1
		super.ensure_unit_form_resize_safe(unit)

var resize_requests: int:
	get: return world.resize_requests

## 小型权威夹具：复用正式服务装配，不创建 UI、模型、音频或资源预热。
## 不更改生产加载入口，不监听网络端口，不自动推进模拟。
func _init() -> void:
	runtime.mode = "server"
	world = ResizeTrackedWorld.new(self)

func has_presentation() -> bool:
	return false

func _show_menu() -> void:
	pass

func _ready() -> void:
	super._ready()
	set_process(false)
	runtime._minion_waves_enabled = false
	_create_towers()
	world.build_navigation()
	for tower in world.towers_snapshot(): tower.can_attack = false
