extends Node3D
## 原版ShacoBoxSpell从head骨发射；挂点仅用于表现。
func create_projectile_anchor() -> Node3D:
	for skeleton in find_children("*", "Skeleton3D", true, false):
		for index in skeleton.get_bone_count():
			if String(skeleton.get_bone_name(index)).to_lower() != "head": continue
			var anchor := BoneAttachment3D.new()
			anchor.name = "ProjectileModelAnchor"
			anchor.bone_idx = index
			skeleton.add_child(anchor)
			return anchor
	return null

const PLAYER = preload("res://assets/effects/jack_in_the_box/player.gd")
var _unit: Node2D
var _effects: Array[Dictionary] = []

func handles_stealth_transition() -> bool:
	return true

func configure_unit_visual(unit: Node2D) -> void:
	if is_instance_valid(_unit) and _unit.presentation_cue.is_connected(_on_cue):
		_unit.presentation_cue.disconnect(_on_cue)
	_clear_effects()
	_unit = unit
	_unit.presentation_cue.connect(_on_cue)

func _on_cue(cue: StringName) -> void:
	if cue not in [&"stealth:exit", &"active:impact"]: return
	if not is_instance_valid(_unit) or _unit.hp <= 0: return
	var fx := PLAYER.new()
	add_child(fx)
	fx.load_kind("aoe")
	# 用户指定主可见范围半径4格；统一XYZ缩放，不改变权威判定。
	fx.setup_native(PLAYER.ACTIVATION_PROJECT_RADIUS / 40.0 / PLAYER.ACTIVATION_VISIBLE_RADIUS)
	_effects.append({"player": fx, "age": 0.0})

func sync_combat_visual(_state: UnitPresentationState, delta: float, dying: bool) -> void:
	if dying:
		_clear_effects()
		return
	for i in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[i]
		effect.age += delta
		if effect.age >= PLAYER.ACTIVATION_DURATION:
			_free_effect(effect)
			_effects.remove_at(i)
			continue
		effect.player.seek(effect.age)

func _free_effect(effect: Dictionary) -> void:
	if is_instance_valid(effect.player): effect.player.free()

func _clear_effects() -> void:
	for effect in _effects: _free_effect(effect)
	_effects.clear()
