extends ActiveBuffVisual3D
## 原版基础皮肤 W：加速拖尾、双枪持续粒子与结束火星。只读快照时钟。
const PLAYER = preload("res://assets/effects/missfortune_w/player.gd")
var _players: Dictionary = {}
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _previous_origin := Vector3.INF

func configure(_radius: float, _team: int = 0) -> void:
	for kind in ["trail", "left", "right", "end_left", "end_right"]:
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
			if bone == "buffbone_cstm_weapon_2": _bones["left"] = index
			if bone == "buffbone_glb_weapon_1": _bones["right"] = index
		if _bones.size() == 2:
			_skeleton = node
			return

func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active
	visible = shown
	var age := status_state.x
	var duration := status_state.y
	var origin := _skeleton.global_position if is_instance_valid(_skeleton) else global_position
	var moving := _previous_origin.is_finite() and origin.distance_squared_to(_previous_origin) > 0.0000001
	_previous_origin = origin
	for kind: String in _players:
		var effect: Node3D = _players[kind]
		if kind == "trail":
			effect.visible = shown and duration > 0.0 and age < duration + 1.1
			effect.emitting = (moving or age <= 0.05) and age < duration
			if is_instance_valid(_skeleton): effect.global_transform = _skeleton.global_transform
			if effect.visible: effect.seek(age)
			continue
		var ending := kind.begins_with("end_")
		var side := kind.trim_prefix("end_")
		effect.visible = shown and ((age >= duration and age < duration + 2.1) if ending else age < duration)
		if not effect.visible: continue
		if is_instance_valid(_skeleton) and _bones.has(side):
			# 模型自带特效挂点的 +Z 沿枪管；L/R_WEAPON 的长轴是 X，不能直接用。
			# 模型缩放只继承一次，保留原版网格和发射器比例。
			effect.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_bones[side]) * Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
		effect.seek(maxf(age - duration, 0.0) if ending else minf(age, 3.0))

func prepare_resource_sample(_skills: Array, draw: Callable) -> void:
	for age in [0.1, 0.5, 1.5, 3.1, 3.5]:
		status_state = Vector2(age, 3.0)
		advance_status(true, true, 0.0)
		draw.call()

func reset_prepared_visual() -> void:
	_previous_origin = Vector3.INF
	super.reset_prepared_visual()
