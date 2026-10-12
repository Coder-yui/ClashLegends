extends ActiveBuffVisual3D
## 原版基础皮肤 W：双枪持续粒子与结束火星。只读快照时钟。
const PLAYER = preload("res://assets/effects/missfortune_w/player.gd")
var _players: Dictionary = {}
var _skeleton: Skeleton3D
var _bones: Dictionary = {}

func configure(_radius: float, _team: int = 0) -> void:
	for kind in ["left", "right", "end_left", "end_right"]:
		var effect := PLAYER.new()
		add_child(effect)
		effect.load_kind(kind)
		effect.setup_native(0.014)
		_players[kind] = effect
	visible = false

func bind_model(model: Node3D) -> void:
	for node: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		for index in node.get_bone_count():
			var bone := node.get_bone_name(index).to_lower()
			if bone == "l_weapon": _bones["left"] = index
			if bone == "r_weapon": _bones["right"] = index
		if _bones.size() == 2:
			_skeleton = node
			return

func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active
	visible = shown
	var age := status_state.x
	var duration := status_state.y
	for kind: String in _players:
		var effect: Node3D = _players[kind]
		var ending := kind.begins_with("end_")
		var side := kind.trim_prefix("end_")
		effect.visible = shown and ((age >= duration and age < duration + 2.1) if ending else age < duration)
		if not effect.visible: continue
		if is_instance_valid(_skeleton) and _bones.has(side):
			# Keep the native weapon-bone frame, with model scale inherited exactly once.
			effect.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_bones[side]) * Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
		effect.seek(maxf(age - duration, 0.0) if ending else minf(age, 3.0))

func prepare_resource_sample(_skills: Array, draw: Callable) -> void:
	for age in [0.1, 0.5, 1.5, 3.1, 3.5]:
		status_state = Vector2(age, 3.0)
		advance_status(true, true, 0.0)
		draw.call()
