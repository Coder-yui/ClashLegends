extends Node3D
## 原版时空断裂消失/落地；只读取可靠表现事件的位置和年龄。
const PLAYER = preload("res://assets/effects/ekko/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
# 项目视觉校准：源范围按375单位校准到配置半径，不改变权威范围。
const SOURCE_RADIUS := 375.0
var _views: Dictionary = {}
var _serial := 0
var _models: Array[Dictionary] = []
var _hit_meshes: Dictionary = {}

func track(unit: Unit, model: Node3D) -> void:
	_models = _models.filter(func(entry): return entry.unit.get_ref() != null and entry.view.get_ref() != null)
	_models.append({"unit":weakref(unit),"view":weakref(model)})

func _attach_hit(id: int, effect: Dictionary, player: Node3D) -> void:
	var best: Node3D
	var distance := 45.0
	for i in range(_models.size()-1,-1,-1):
		var unit = _models[i].unit.get_ref()
		var view = _models[i].view.get_ref()
		if not is_instance_valid(unit) or not is_instance_valid(view):
			_models.remove_at(i)
			continue
		if unit.team == int(effect.team): continue
		var d: float = unit.global_position.distance_to(effect.pos)
		if d < distance:
			distance = d
			best = view
	if best == null: return
	var overlays: Array[WeakRef] = []
	for mesh in best._model_resources.meshes():
		if mesh.has_meta("rewind_overlay"): continue
		var overlay := MeshInstance3D.new()
		mesh.add_child(overlay)
		overlay.set_meta("rewind_overlay",true)
		overlay.mesh = mesh.mesh
		overlay.skin = mesh.skin
		var skeleton = mesh.get_node_or_null(mesh.skeleton)
		if skeleton != null: overlay.skeleton = overlay.get_path_to(skeleton)
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overlay.material_override = player.make_overlay(null)
		overlays.append(weakref(overlay))
	_hit_meshes[id] = overlays

func sync_effects(skills: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.get("shape", "")) not in ["rewind_appear", "rewind_vanish", "rewind_hit"]: continue
		if not effect.has("rewind_view_id"):
			_serial += 1
			effect.rewind_view_id = _serial
		var id := int(effect.rewind_view_id)
		present[id] = true
		if not _views.has(id):
			var group := Node3D.new()
			add_child(group)
			var kinds: Array = ["r-Tar"] if effect.shape == "rewind_appear" else (["r-Tar_Impact"] if effect.shape == "rewind_hit" else ["vanish"])
			for kind in kinds:
				var player := PLAYER.new()
				group.add_child(player)
				player.load_kind(kind)
				player.setup_native(1.0)
			_views[id] = group
			if effect.shape == "rewind_hit": _attach_hit(id, effect, group.get_child(0))
		var view: Node3D = _views[id]
		var point: Vector2 = effect.pos
		var radius := float(effect.length)
		view.position = PROJECTION.ground(camera, point)
		var native_scale := PROJECTION.ground(camera, point + Vector2(radius, 0)).distance_to(view.position) / SOURCE_RADIUS
		if effect.shape == "rewind_hit": native_scale = 0.01345
		view.scale = Vector3.ONE * native_scale
		for player in view.get_children():
			player.projection_basis = PROJECTION.footprint_basis(camera, point, radius)
			player.seek(maxf(float(effect.duration) - float(effect.timer), 1.0 / 120.0))
			if effect.shape == "rewind_hit": player.update_attached(true)

	for id in _views.keys():
		if not present.has(id):
			for ref in _hit_meshes.get(id, []):
				var mesh = ref.get_ref()
				if is_instance_valid(mesh): mesh.queue_free()
			_hit_meshes.erase(id)
			_views[id].free()
			_views.erase(id)

func _exit_tree() -> void:
	for overlays in _hit_meshes.values():
		for ref in overlays:
			var mesh = ref.get_ref()
			if is_instance_valid(mesh): mesh.queue_free()
	_hit_meshes.clear()
