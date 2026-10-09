extends Node3D
## 预警跟随角色；冲击只消费结算时发布的固定位置事件。
const PLAYER = preload("res://assets/effects/sett/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
var _units: Array[WeakRef] = []
var _models: Dictionary = {}
var _casts: Dictionary = {}
var _seen: Dictionary = {}
var _released: Dictionary = {}
var _bursts: Dictionary = {}
var _bodies: Dictionary = {}
var _event_serial := 0

func track(unit: Unit, model: UnitModel3D) -> void:
	if unit.card_id != "sett": return
	_units.append(weakref(unit))
	_models[unit.get_instance_id()] = weakref(model)

func _player(kind: String) -> Node3D:
	var view := PLAYER.new()
	add_child(view)
	view.load_kind(kind)
	view.setup_native(1.0)
	return view

func _basis(camera: Camera3D, point: Vector2, forward: Vector2) -> Basis:
	var origin := PROJECTION.ground(camera, point)
	var across := PROJECTION.ground(camera, point + Vector2(-forward.y, forward.x)) - origin
	return Basis(across, Vector3.UP * across.length(), PROJECTION.ground(camera, point + forward) - origin)

func sync_effects(skills: RefCounted, camera: Camera3D, delta: float) -> void:
	_sync_impacts(skills, camera)
	var alive := {}
	for ref in _units.duplicate():
		var unit := ref.get_ref() as Unit
		if not is_instance_valid(unit):
			_units.erase(ref)
			continue
		var id := unit.get_instance_id()
		alive[id] = true
		_sync_body(unit, delta)
		var serial := unit.get_visual_action_serial()
		if unit.get_visual_action_name() not in [&"active", &"active_strong"] or unit.get_visual_action_time_left() <= 0.0: continue
		if serial <= unit.cancelled_visual_serial or unit.hp <= 0.0: continue
		if int(_seen.get(id, -1)) == serial or int(_released.get(id, -1)) >= serial: continue
		_seen[id] = serial
		if _casts.has(id): _remove_cast(id)
		_casts[id] = {"source":ref,"serial":serial,"warning":_player("warning")}
	for id in _models.keys():
		if not alive.has(id):
			_models.erase(id)
			_seen.erase(id)
			_released.erase(id)
			_remove_body(id)
	for id in _casts.keys():
		var state: Dictionary = _casts[id]
		var unit := state.source.get_ref() as Unit
		if not is_instance_valid(unit) or unit.hp <= 0.0 or int(state.serial) <= unit.cancelled_visual_serial or unit.is_frozen() or CombatInteraction.in_stasis(unit):
			_remove_cast(id)
			continue
		var age := unit.get_visual_action_duration() - unit.get_visual_action_time_left()
		var skill: Dictionary = CardDB.active_skills_for("sett")[0]
		if age + 0.0001 >= float(skill.impact_delay):
			_remove_cast(id)
			continue
		var forward := unit.get_visual_facing_direction().normalized()
		var point := unit.get_visual_screen_position() + forward * unit.body_radius
		state.warning.range_params = Vector4(skill.length, skill.near_width, skill.far_width, skill.center_width)
		state.warning.position = PROJECTION.ground(camera, point)
		state.warning.projection_basis = _basis(camera, point, forward)
		state.warning.visible = unit.visible_to_local_player()
		state.warning.seek(maxf(age, 1.0/60.0))

func _sync_impacts(skills: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.shape) not in ["sett_w_impact", "sett_w_impact_strong"]: continue
		if not effect.has("sett_view_id"):
			_event_serial += 1
			effect.sett_view_id = _event_serial
		var key := int(effect.sett_view_id)
		present[key] = true
		if not _bursts.has(key):
			var player := _player("max" if String(effect.shape).ends_with("strong") else "min")
			var point: Vector2 = effect.pos + effect.forward * float(effect.source_radius)
			player.position = PROJECTION.ground(camera, point)
			player.projection_basis = _basis(camera, point, effect.forward)
			player.range_params = Vector4(effect.length, effect.near_width, effect.far_width, effect.center_width)
			_bursts[key] = player
		var unit = skills.effect_source(effect)
		if is_instance_valid(unit):
			var id: int = unit.get_instance_id()
			_released[id] = int(effect.action_serial)
			if _casts.has(id) and int(_casts[id].serial) <= int(effect.action_serial): _remove_cast(id)
		_bursts[key].seek(maxf(float(effect.duration) - float(effect.timer), 1.0/60.0))
	for key in _bursts.keys():
		if not present.has(key):
			_bursts[key].free()
			_bursts.erase(key)

func _sync_body(unit: Unit, delta: float) -> void:
	var id := unit.get_instance_id()
	# 原版满豪意待机与 W 施法使用独立身体系统；资源在起手消耗不能撤去施法金光。
	var strong_cast := unit.get_visual_action_name() == &"active_strong" and unit.get_visual_action_time_left() > 0.0 and unit.get_visual_action_serial() > unit.cancelled_visual_serial and not unit.is_frozen() and not CombatInteraction.in_stasis(unit)
	var kind := "cast_body" if strong_cast else "full_body"
	if unit.hp <= 0.0 or (not strong_cast and unit.get_skill_resource_ratio() < 0.999):
		_remove_body(id)
		return
	if _bodies.has(id) and _bodies[id].kind != kind: _remove_body(id)
	if not _bodies.has(id):
		var model := _models[id].get_ref() as UnitModel3D
		if not is_instance_valid(model): return
		var meshes := model._model_resources.meshes()
		if meshes.is_empty(): return
		var player := PLAYER.new()
		add_child(player)
		player.attachment_target = meshes[0]
		player.load_kind(kind)
		player.setup_native(1.0)
		_bodies[id] = {"player":player,"age":0.0,"kind":kind}
	var body: Dictionary = _bodies[id]
	body.age += delta
	# 源 UV 滚动周期为 5 秒；只循环稳定段，不重播满层瞬间的爆闪。
	var age := float(body.age)
	if strong_cast:
		# 使用动作快照时间，晚到客户端从正确相位开始；出拳后继续源曲线至收招。
		body.player.seek(maxf(unit.get_visual_action_duration() - unit.get_visual_action_time_left(), 1.0/60.0))
	else:
		body.player.seek(age if age < 6.0 else 1.0 + fmod(age - 1.0, 5.0))
	var shown := unit.visible_to_local_player() and not CombatInteraction.in_stasis(unit)
	for pool in body.player._pools:
		for mesh in pool: mesh.visible = mesh.visible and shown

func _remove_body(id: int) -> void:
	if not _bodies.has(id): return
	if is_instance_valid(_bodies[id].player): _bodies[id].player.free()
	_bodies.erase(id)

func _remove_cast(id: int) -> void:
	if is_instance_valid(_casts[id].warning): _casts[id].warning.free()
	_casts.erase(id)
