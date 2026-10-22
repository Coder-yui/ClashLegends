extends ActiveBuffVisual3D
## 只采样同步的领域时钟；不修改战斗状态。
const GEOMETRY = preload("res://assets/effects/hecarim/geometry.gd")
const PLAYER = preload("res://assets/effects/hecarim/player.gd")
var parts: Array[Node3D] = []
var _model: WeakRef

func bind_model(model: Node3D) -> void:
	_model = weakref(model)

func configure(_radius: float, _team: int = 0) -> void:
	position = Vector3(0.0, GEOMETRY.GROUND_CLEARANCE, 0.0)
	status_source = "active_buff_clock"
	for kind in ["aoe", "cas"]:
		var part := PLAYER.new()
		add_child(part)
		part.load_kind(kind)
		part.setup_native(GEOMETRY.W_SCALE)
		parts.append(part)
func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active and status_state.y > 0.0 and status_state.x < status_state.y + 0.7
	visible = shown and active
	if active:
		for part in parts:
			part.seek(status_state.x)
			if part._kind == "aoe" and _model != null:
				var model = _model.get_ref()
				var unit = model._unit.get_ref() if is_instance_valid(model) and model._unit != null else null
				if is_instance_valid(unit):
					var viewer: int = unit.battle_context.local_player_team()
					var tint := Color(0.28,0.68,1.0,0.9) if unit.team == viewer else Color(1.0,0.34,0.24,0.9)
					for particle in part._pools[15]: particle.material_override.set_shader_parameter("boundary_tint",tint)
