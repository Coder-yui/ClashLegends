extends Node3D
## 常驻粒子只跟随模型和骨骼，不影响地面分类或权威坐标。
const Native = preload("res://assets/effects/kassadin/player.gd")
const SOURCE_TO_MODEL := 0.0085
var _blade: Node3D
var _age := 0.0
var _dead := false
var _unit: WeakRef

func configure_unit_visual(unit: Unit) -> void:
	_unit = weakref(unit)
	_dead = false
	_age = 0.0

func _create_ambient() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null: return
	var index := skeleton.find_bone("BUFFBONE_GLB_WEAPON_1")
	if index < 0: return
	var attachment := BoneAttachment3D.new()
	attachment.name = "NativeIdleBladeBone"
	attachment.bone_name = "BUFFBONE_GLB_WEAPON_1"
	skeleton.add_child(attachment)
	attachment.bone_idx = index
	_blade = Native.new()
	attachment.add_child(_blade)
	_blade.load_kind("idle_blade")
	_blade.setup_native(SOURCE_TO_MODEL)

func advance_ambient_visual(delta: float) -> void:
	if _dead: return
	if not is_instance_valid(_blade): _create_ambient()
	if not is_instance_valid(_blade): return
	var unit = _unit.get_ref() if _unit != null else null
	var show: bool = not is_instance_valid(unit) or unit.hp > 0.0
	_blade.visible = show
	if not show: return
	_age += maxf(delta, 0.0)
	# 两秒预热后循环稳定样本，避免周期边界重回零粒子。
	var sample_age := 2.0 + fmod(_age, 10.0)
	_blade.seek(sample_age)

func begin_visual_death(_duration: float) -> void:
	_dead = true
	if is_instance_valid(_blade): _blade.hide()

func reset_pool_visual() -> void:
	_unit = null
	_dead = false
	_age = 0.0
	if is_instance_valid(_blade): _blade.hide()
