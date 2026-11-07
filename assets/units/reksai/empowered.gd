extends ActiveBuffVisual3D
const PLAYER = preload("res://assets/effects/reksai/player.gd")
var _effect: Node3D
var _age := 0.0
var _hands: Array[Node3D] = []
var _skeleton: Skeleton3D
var _bones: Array[int] = []
func configure(_radius: float, _team: int = 0) -> void:
	status_source = "empowered_attack"
	for index in 2:
		var effect := PLAYER.new()
		add_child(effect)
		effect.load_kind("buff")
		effect.setup_native(0.008)
		effect.hide()
		_hands.append(effect)
	_effect = _hands[0]

func bind_model(model: Node3D) -> void:
	var skeletons := model.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return
	_skeleton = skeletons[0]
	_bones.clear()
	for bone in ["L_Buffbone_Glb_Hand_Loc","R_Buffbone_Glb_Hand_Loc"]:
		_bones.append(_skeleton.find_bone(bone))

func advance_status(status_active: bool, shown: bool, delta: float) -> void:
	if not status_active: _age = 0.0
	elif shown: _age += maxf(delta, 0.0)
	active = status_active
	visible = shown
	# 原版Bright_glow、Dark_Spark、Dark_Swirl持续发射；启动 ini/ini1 只存在于前0.5秒，循环稳态不重播启动爆点。
	if shown and status_active:
		var sample_age := _age if _age <= 5.0 else 1.0 + fmod(_age - 1.0, 4.0)
		for index in _hands.size():
			if _skeleton == null or _bones.size() != 2 or _bones[index] < 0: continue
			var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(_bones[index])
			_hands[index].seek_motion(sample_age, pose.origin, pose.basis.orthonormalized())
	for effect in _hands: effect.visible = shown and status_active and _bones.size()==2


func on_cue(cue: StringName) -> void:
	if cue == &"active:cast": _age = 0.0
