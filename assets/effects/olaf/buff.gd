extends ActiveBuffVisual3D
## 只读取同步后的增益时间与护盾状态；粒子不驱动战斗。
const PLAYER := preload("res://assets/effects/olaf/player.gd")
var _parts: Array[Node3D] = []
var _skeleton: Skeleton3D
var _bones: Array[int] = []
# Imported model uses 0.0085 metres per LoL unit; include its live wrapper scale.
const SOURCE_UNIT_SCALE := 0.0085
# Compact framing for this model: hand flash, shield, two axe layers, hand flash, skin.
const PART_FIT := [0.6, 0.75, 0.5, 0.5, 0.6, 1.0]
var _model: Node3D
var _unit_scale := SOURCE_UNIT_SCALE
# AutoBuffActivateEffect[1..4] from OlafFrenziedStrikes.luabin64.
# Shield/glow placement is retained as project adaptation; no source hook was found.
const PART_BONES := ["L_BUFFBONE_GLB_HAND_LOC", "", "L_weapon", "R_weapon", "R_BUFFBONE_GLB_HAND_LOC", ""]

func configure(_radius: float, _team: int = 0) -> void:
	status_source = "active_buff_clock"
	for kind in ["cas", "shield", "buf_glow", "buf_glow", "cas", "buf_blood"]:
		var part := PLAYER.new()
		add_child(part)
		part.load_kind(kind)
		part.setup_native(SOURCE_UNIT_SCALE)
		part.name = ["左手施放", "护盾", "左斧增益", "右斧增益", "右手施放", "体表增益"][_parts.size()]
		_parts.append(part)
	visible = false

func bind_model(model: Node3D) -> void:
	_model = model
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return
	_skeleton = skeletons[0]
	_bones.clear()
	for bone in PART_BONES:
		_bones.append(_skeleton.find_bone(bone) if not bone.is_empty() else -1)

func make_overlay(original: Material) -> Material:
	var chain := original
	for part in _parts: chain = part.make_overlay(chain)
	return chain

func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active and status_state.x < status_state.y
	visible = shown and active
	if not active:
		for part in _parts: part.update_attached(false)
		return
	_update_placement()
	var age := maxf(status_state.x, 0.0)
	for i in _parts.size():
		var part := _parts[i]
		part.seek(age)
		part.visible = shown and (i != 1 or shield_active)
		part.update_attached(part.visible)

func _update_placement() -> void:
	if not is_instance_valid(_skeleton) or not is_instance_valid(_model): return
	_unit_scale = SOURCE_UNIT_SCALE * _skeleton.global_basis.get_scale().abs().y
	for i in _parts.size():
		var part := _parts[i]
		var fitted_scale: float = _unit_scale * PART_FIT[i]
		part.global_basis = Basis.IDENTITY.scaled(Vector3.ONE * fitted_scale)
		if _bones.size() == _parts.size() and _bones[i] >= 0:
			var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(_bones[i])
			part.global_position = pose.origin
			# Source +Y runs along the axe; imported weapon handles run along -X.
			if i in [2, 3]:
				part.global_basis = (pose.basis.orthonormalized() * Basis(Vector3.FORWARD, -PI / 2.0)).scaled(Vector3.ONE * fitted_scale)
		else:
			part.global_position = _model.global_position
			if i == 1: part.global_position.y += 100.0 * fitted_scale
