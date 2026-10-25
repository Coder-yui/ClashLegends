extends Node3D
## 原生炮口骨骼仅驱动视觉出生点。
func create_projectile_anchor() -> Node3D:
	for skeleton in find_children("*", "Skeleton3D", true, false):
		var index: int = skeleton.find_bone("BUFFBONE_CSTM_WEAPON_1")
		if index >= 0:
			var anchor := BoneAttachment3D.new()
			anchor.bone_idx = index
			skeleton.add_child(anchor)
			return anchor
	push_error("杰斯缺少原生炮口骨骼")
	return null

## 原版Passive只接管武器遮罩；Default层持续播放Idle/Run/Attack。
func consumes_layered_action(action: StringName) -> bool:
	return action == &"transform"

const NATIVE_SCALE := 0.0095
const Native = preload("res://assets/effects/jayce/player.gd")
var _unit: WeakRef
var _skeleton: Skeleton3D
var _effects: Dictionary = {}
var _base_materials: Array[Dictionary] = []
var _ages: Dictionary = {}
var _enabled: Dictionary = {}
var _dead := false
var _pending_delta := 0.0
var _weapon_layer: SkeletonModifier3D
var _stance_serial := -1
var _stance_age := 10.0
var _stance_stop_time := 0.3
var _stance_stopped := false
var _stance_kinds: Array[String] = []

func can_reuse_visual(scene_path: String) -> bool:
	return scene_path == "res://assets/units/jayce/jayce_view.tscn"

func set_visual_form(_form: int) -> void:
	pass # 武器层直接读取同步形态；不重建模型与移动播放器。

func preserves_form_locomotion() -> bool:
	return true

func configure_unit_visual(unit: Unit) -> void:
	if _unit != null and _unit.get_ref() == unit and is_instance_valid(_weapon_layer): return
	_unit = weakref(unit)
	_skeleton = find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_dead = false
	_pending_delta = 0.0
	_stance_serial = -1
	_stance_age = 10.0
	_stance_kinds.clear()
	if not is_instance_valid(_weapon_layer):
		_weapon_layer = preload("res://assets/units/jayce/weapon_layer.gd").new()
		_skeleton.add_child(_weapon_layer)
		_weapon_layer.configure(self, find_children("*", "AnimationPlayer", true, false)[0])
	if not _skeleton.skeleton_updated.is_connected(_after_skeleton):
		_skeleton.skeleton_updated.connect(_after_skeleton)

func _effect(kind: String) -> Node3D:
	if not _effects.has(kind):
		var effect := Native.new()
		add_child(effect)
		effect.load_kind(kind.get_slice("@", 0))
		effect.setup_native(NATIVE_SCALE)
		_effects[kind] = effect
		if kind in ["swap_m", "swap_r"]:
			# Model_Swap 的 avatar 层沿用角色蒙皮，不创建替代球体。
			for mesh in find_children("*", "MeshInstance3D", true, false):
				if mesh.skin == null: continue
				for surface in mesh.mesh.get_surface_count():
					var known := false
					for saved in _base_materials:
						if saved.mesh == mesh and saved.surface == surface: known = true
					if not known:
						_base_materials.append({"mesh": mesh, "surface": surface, "material": mesh.get_surface_override_material(surface)})
					mesh.set_surface_override_material(surface, effect.make_overlay(mesh.get_active_material(surface)))
	return _effects[kind]

func _attach(effect: Node3D, bone: String) -> void:
	var index := _skeleton.find_bone(bone)
	if index < 0:
		push_error("杰斯特效挂点不存在: " + bone)
		return
	var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(index)
	effect.global_position = pose.origin
	# Both the exported particles and the Skeleton mirror X. Cancel the local
	# reflection for every weapon effect before seek_motion decomposes scale.
	effect.global_basis = (pose.basis.orthonormalized() * Basis.FLIP_X).scaled(Vector3.ONE * NATIVE_SCALE)

func _loop(kind: String, active: bool, bone: String, delta: float) -> void:
	if not active and not _effects.has(kind): return
	var effect := _effect(kind)
	if active and not _enabled.get(kind, false):
		effect.restart_emitting()
		_ages[kind] = 0.0
	elif not active and _enabled.get(kind, false): effect.stop_emitting()
	_enabled[kind] = active
	_ages[kind] = float(_ages.get(kind, 0.0)) + delta
	if active and float(_ages[kind]) >= 4.5:
		_ages[kind] = 2.0
		effect.restart_emitting()
	_attach(effect, bone)
	effect.seek_motion(float(_ages[kind]), effect.global_position, effect.global_basis.orthonormalized())
	effect.visible = active or effect.has_live_particles()

func advance_ambient_visual(delta: float) -> void:
	_pending_delta += delta

func _after_skeleton() -> void:
	var delta := _pending_delta
	_pending_delta = 0.0
	_advance_effects(delta)

func _advance_effects(delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	if _dead or not is_instance_valid(unit) or unit.hp <= 0.0:
		for effect in _effects.values():
			effect.hide()
			effect.update_attached(false)
		return
	var shown: bool = unit.visible_to_local_player() and not CombatInteraction.in_stasis(unit)
	var dt := 0.0 if unit.is_frozen() else delta
	var ranged: bool = unit.get_form_index() == 0
	_tick_stance(unit, delta, shown)
	var ready: bool = unit.is_empowered_attack_ready_visual() and shown
	_loop("ready_r", ready and ranged, "BUFFBONE_CSTM_WEAPON_1", dt)
	_loop("ready_r@gap1", ready and ranged, "BUFFBONE_CSTM_WEAPON_GAP_1", dt)
	_loop("ready_r@gap2", ready and ranged, "BUFFBONE_CSTM_WEAPON_GAP_2", dt)
	_loop("ready_m", ready and not ranged, "BUFFBONE_GLB_WEAPON_1", dt)
	# 换形直接撤去旧形态待发光，不能与新形态首击光并存。
	var old_ready := "ready_m" if ranged else "ready_r"
	for key in _effects:
		if String(key).get_slice("@", 0) == old_ready: _effects[key].hide()
	# Native GAP_1/2 are the two hammer-head vents; EXHAUST bones are handle-end vents.
	for side in 2:
		_loop("w_ready2" if side == 0 else "w_ready2@gap2", unit.get_active_buff_active_visual() and shown, "BUFFBONE_CSTM_WEAPON_GAP_%d" % (side + 1), dt)
	# Independent area clock is replicated and survives model replacement on form changes.
	var clock: Vector2 = unit.active_buff_clock_visual()
	if clock.y > 0.0 and clock.x <= clock.y + 1.0:
		var field := _effect("field")
		field.position = Vector3.ZERO
		field.global_basis = Basis.IDENTITY.scaled(Vector3.ONE * NATIVE_SCALE)
		field.seek_motion(clock.x, field.global_position, Basis.IDENTITY)
		field.visible = shown
	elif _effects.has("field"): _effects.field.hide()

func begin_visual_death(_duration: float) -> void:
	_dead = true
	for effect in _effects.values():
		effect.hide()
		effect.update_attached(false)

func reset_pool_visual() -> void:
	for saved in _base_materials:
		if is_instance_valid(saved.mesh): saved.mesh.set_surface_override_material(saved.surface, saved.material)
	_base_materials.clear()
	for effect in _effects.values(): effect.free()
	_effects.clear()
	_ages.clear()
	_enabled.clear()
	_dead = false
	_unit = null

func _tick_stance(unit: Unit, delta: float, shown: bool) -> void:
	var serial := unit.get_visual_action_serial()
	if unit.get_visual_action_name() == &"transform" and serial != _stance_serial and serial > unit.cancelled_visual_serial and unit.get_visual_action_time_left() > 0.0:
		_stance_serial = serial
		_stance_stopped = false
		_stance_stop_time = unit.get_visual_action_duration()
		_stance_age = maxf(unit.get_visual_action_duration() - unit.get_visual_action_time_left(), 0.0)
		for kind in _stance_kinds:
			if _effects.has(kind):
				_effects[kind].hide()
				_effects[kind].update_attached(false)
		_stance_kinds.assign(["stance_m", "swap_m"] if unit.get_form_index() == 1 else ["stance_r", "stance_hammer", "swap_r"])
		for kind in _stance_kinds: _effect(kind).restart_emitting()
	elif not unit.is_frozen():
		if serial == _stance_serial and unit.get_visual_action_time_left() > 0.0:
			_stance_age = unit.get_visual_action_duration() - unit.get_visual_action_time_left()
		else: _stance_age = maxf(_stance_age, _stance_stop_time) + delta
	if not _stance_stopped and (_stance_age >= _stance_stop_time or _stance_serial <= unit.cancelled_visual_serial):
		for kind in _stance_kinds:
			if kind.begins_with("swap_"): continue # 原始一次性整身闪光按自身曲线结束。
			var effect := _effect(kind)
			effect.seek(minf(_stance_age, _stance_stop_time))
			effect.stop_emitting()
		_stance_stopped = true
	for kind in _stance_kinds:
		var effect := _effect(kind)
		if kind.begins_with("swap_"):
			# 客户端包缺少双向调用函数；采用同形态强化命中配色匹配，挂角色根部。
			effect.global_position = global_position
			effect.global_basis = Basis.IDENTITY.scaled(Vector3.ONE * NATIVE_SCALE)
		else:
			_attach(effect, "BUFFBONE_GLB_WEAPON_1" if kind == "stance_m" else "BUFFBONE_CSTM_WEAPON_1")
		effect.seek_motion(_stance_age, effect.global_position, effect.global_basis.orthonormalized())
		effect.visible = shown and effect.has_live_particles()
		effect.update_attached(shown and _stance_serial > unit.cancelled_visual_serial)
