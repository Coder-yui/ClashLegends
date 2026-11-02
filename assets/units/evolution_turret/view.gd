extends Node3D
const PLAYER = preload("res://assets/effects/evolution_turret/player.gd")
var _source: Unit
var _repair: Node3D
var _repair_age := 0.0
func configure_unit_visual(unit: Unit) -> void:
	_source = unit
	if not unit.presentation_cue.is_connected(_on_cue): unit.presentation_cue.connect(_on_cue)
func _on_cue(cue: StringName) -> void:
	if cue != &"active:cast": return
	if is_instance_valid(_repair): _repair.free()
	_repair = _effect()
	_repair_age = 0.0
func _effect() -> Node3D:
	var effect := PLAYER.new()
	add_child(effect)
	effect.load_kind("spawn")
	effect.setup_native(0.022)
	return effect
func sync_combat_visual(_state: UnitPresentationState, delta: float, dying: bool) -> void:
	if not is_instance_valid(_repair): return
	_repair.visible = PresentationConfig.status_indicators_visible(_source)
	_repair_age += delta
	_repair.seek(_repair_age)
	if dying or _repair_age >= 2.0:
		_repair.free()
		_repair = null
## 自制彗星直接从炮口骨骼发出，没有原版粒子的载体高度偏移。
func create_projectile_anchor() -> Node3D:
	var skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]
	var anchor := BoneAttachment3D.new()
	anchor.name = "ProjectileModelAnchor"
	anchor.bone_idx = skeleton.find_bone("Rocket")
	skeleton.add_child(anchor)
	return anchor
