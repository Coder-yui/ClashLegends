extends Node3D
## 按原Skin0的idleParticlesEffects挂点组织，仅读取强化/控制状态。
const PLAYER = preload("res://assets/effects/airdrop_bear/player.gd")
const BINDINGS := [["body", "spine1"], ["arm", "R_Elbow"], ["arm", "L_Elbow"],
	["hand", "R_Buffbone_Glb_hand_Loc"], ["hand", "L_Buffbone_Glb_hand_Loc"],
	["leg", "R_KneeLower"], ["leg", "L_KneeLower"], ["foot", "R_foot"], ["foot", "L_foot"]]
var _source: WeakRef
var _fire: Array[Dictionary] = []
var _age := 0.0
func configure_unit_visual(unit: Unit) -> void:
	for entry in _fire: entry.attachment.free()
	_fire.clear()
	_source = weakref(unit)
	_age = 0.0
func sync_combat_visual(_state: UnitPresentationState, delta: float, dying: bool) -> void:
	var unit: Unit = _source.get_ref() if _source != null else null
	var enabled := unit != null and unit.burning_aura and not dying and unit.hp > 0
	if enabled and _fire.is_empty(): _create_fire()
	var shown := enabled and not CombatInteraction.in_stasis(unit)
	if shown: _age += maxf(delta, 0.0)
	for entry in _fire:
		entry.player.visible = shown
		if shown: entry.player.seek(_age)
func _create_fire() -> void:
	var skeletons := find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return
	var skeleton: Skeleton3D = skeletons[0]
	for binding in BINDINGS:
		var bone := -1
		for index in skeleton.get_bone_count():
			if String(skeleton.get_bone_name(index)).to_lower() == String(binding[1]).to_lower():
				bone = index
				break
		if bone < 0:
			push_error("提伯斯原版火焰挂点缺失: " + binding[1])
			continue
		var attachment := BoneAttachment3D.new()
		attachment.bone_idx = bone
		skeleton.add_child(attachment)
		var player := PLAYER.new()
		attachment.add_child(player)
		player.load_kind(binding[0])
		player.setup_native(1.0)
		_fire.append({"player": player, "attachment": attachment})
