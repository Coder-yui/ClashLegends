extends Node3D
## 原版Q通道挂点只用于绘制；权威弹体从单位中心发射。
func create_projectile_anchor() -> Node3D:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons := find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty(): skeleton = skeletons[0]
	if skeleton == null: return null
	var anchor := BoneAttachment3D.new()
	anchor.name = "ProjectileModelAnchor"
	anchor.bone_idx = skeleton.find_bone("Buffbone_Glb_Channel_Loc")
	skeleton.add_child(anchor)
	return anchor

var _source: WeakRef
func configure_unit_visual(unit: Unit) -> void:
	_source = weakref(unit)

func sync_combat_visual(_state: UnitPresentationState, _delta: float, dying: bool) -> void:
	var unit: Unit = _source.get_ref() if _source != null else null
	var weapon := find_child("ReturningWeapon", true, false) as Node3D
	if weapon == null: return
	weapon.visible = dying or unit == null or unit.battle_context == null or not unit.battle_context.has_owned_projectile_visual(unit, &"sivir_blade")
