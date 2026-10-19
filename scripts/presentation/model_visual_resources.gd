class_name ModelVisualResources
extends RefCounted
## 单模型的可变资源。只管理动画库副本和叠加材质，不选择动作或读取战斗状态。
var _meshes: Array[MeshInstance3D] = []
var _originals: Array[Material] = []
var _buffs: Array[Material] = []
var _overlays: Array = []
var _last_state := -1
var _loops := {}
var _player: AnimationPlayer
var _stealth_active := false
var _surface_originals: Array = []
var _surface_ghosts: Array = []
var _override_originals: Array = []
var _shadow_originals: Array = []
var _gold_overlays: Array[Material] = []
var _gold: ShaderMaterial
var _gold_ruins: Array[MeshInstance3D] = []
var _flash: StandardMaterial3D
var _building_frost := false
var _frost_prepared := false
var _frost_requested := false
var _material_plan := {}
var _model: WeakRef
var _base_overlays: Array = []
var _buff_bank := {}
var _selected_buff := ""
var _tool_factory: Callable
var material_creations := {"hit": 0, "frost": 0, "ghost": 0, "gold": 0, "buff": 0}
var _counted_materials := {}

static func is_model_geometry(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current.is_in_group("prepared_buff_bank") or current.is_in_group("prepared_buff_aux"): return false
		current = current.get_parent()
	return true

static func tool_material_states() -> Dictionary:
	return {"mode": "tool"}

static func buff_key(scene: String, radius: float, team: int) -> String:
	return var_to_str([scene, radius, team])

func _count_material(kind: String, material: Material, base: Material = null) -> void:
	while material != null and material != base and not _counted_materials.has(material.get_instance_id()):
		_counted_materials[material.get_instance_id()] = true
		material_creations[kind] += 1
		material = material.next_pass

func _fail(message: String) -> bool:
	if message not in errors: errors.append(message)
	return false

func _allows(state: String) -> bool:
	return _material_plan.get("mode") == "tool" or bool(_material_plan.get(state, false))

func require_material_states(states: Dictionary) -> bool:
	if states.get("mode") != _material_plan.get("mode"): return _fail("Material preparation mode mismatch")
	for state in ["freeze", "stealth", "stasis"]:
		if bool(states.get(state, false)) and not _allows(state): return _fail("Material plan exceeds prepared closure: " + state)
	for descriptor in states.get("buffs", []):
		if not _buff_bank.has(descriptor.key): return _fail("Buff plan exceeds prepared closure: " + String(descriptor.key))
	return true

const ANIMATIONS = preload("res://scripts/presentation/model_animation_instance.gd")
const ANIMATION_COPY = preload("res://scripts/presentation/model_animation_copy.gd")
var errors := PackedStringArray()
var _animations: RefCounted

func bind_model(root: Node, allowed: Dictionary = {}, material_states: Dictionary = {}) -> AnimationPlayer:
	begin_bind(root, allowed, material_states)
	while not step_bind(): pass
	return _player

## 场景树/材质仍在主线程；动画按单片段分步复制，未完成者不交给表现代理。
func begin_bind(root: Node, allowed: Dictionary = {}, material_states: Dictionary = {}) -> void:
	clear()
	if material_states.get("mode") not in ["tool", "match"]:
		_fail("Explicit material preparation mode required")
		return
	_material_plan = material_states.duplicate(true)
	_model = weakref(root)
	_collect_meshes(root)
	_capture_material_originals()
	_building_frost = bool(material_states.get("building", false))
	_gold_ruins.clear()
	for mesh in _meshes:
		if String(root.get_path_to(mesh)).begins_with("RuinBase/"): _gold_ruins.append(mesh)
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1.0, 1.0, 1.0, 0.22)
	_animations = ANIMATIONS.begin(root, allowed)
	errors.append_array(_animations.errors)
	_player = _animations.player if errors.is_empty() else null
	_prepare_overlays()
	_prepare_buff_bank(root)
	prepare_material_states(material_states)

## 本局可达闭包只决定提前准备；独立预览/运行新状态仍可按需创建。
func prepare_material_states(states: Dictionary) -> void:
	if bool(states.get("stasis", false)) and _gold == null: _prepare_gold()
	if bool(states.get("stealth", false)): _prepare_stealth_materials()
	if bool(states.get("freeze", false)) and not _frost_prepared: _prepare_frost()

func step_bind() -> bool:
	if _animations == null: return true
	var done: bool = _animations.step()
	errors.append_array(_animations.errors)
	if not errors.is_empty():
		_player = null
		return true
	if not done: return false
	if _player != null:
		for name in _player.get_animation_list(): _loops[name] = _player.get_animation(name).loop_mode
	return true

## 摄影直接使用包装器时，也走同一记录；后续bind复用，不再复制。
static func prepare_visual_root(root: Node) -> PackedStringArray:
	if root.has_method("prepare_visual_animations"):
		var result: Variant = root.call("prepare_visual_animations")
		if result is PackedStringArray: return result
	return PackedStringArray()

static func prepare_instance_animations(root: Node) -> AnimationPlayer:
	var owner := ANIMATIONS.begin(root)
	while not owner.step(): pass
	if not owner.errors.is_empty():
		for error in owner.errors: push_error(error)
		return null
	return owner.player

func animation_player() -> AnimationPlayer:
	return _player

## 已迁移包装按显式模板闭包；其他脚本保留可识别的legacy策略，待逐类迁移。
static func supports_clip_filter(node: Node) -> bool:
	return ANIMATIONS.supports_clip_filter(node)

static func collect_clip_names(value: Variant, result: Dictionary) -> void:
	if value is String or value is StringName: result[String(value)] = true
	elif value is Dictionary:
		for key in value:
			collect_clip_names(key, result)
			collect_clip_names(value[key], result)
	elif value is Array or value is PackedStringArray:
		for child in value: collect_clip_names(child, result)

func has_meshes() -> bool:
	return not _meshes.is_empty()

func meshes() -> Array[MeshInstance3D]:
	return _meshes.duplicate()

func original_overlay(index: int) -> Material:
	return _originals[index]

## 正式对局只选择加载阶段准备的私有候选；工具才允许现场factory。
func configure_buff(factory: Callable = Callable(), key: String = "") -> bool:
	if not key.is_empty(): return select_buff(key)
	if not factory.is_valid(): return select_buff("")
	if _material_plan.get("mode") != "tool": return _fail("Runtime buff factory forbidden by match plan")
	if factory != _tool_factory:
		_tool_factory = factory
		var buffs: Array[Material] = []
		for original in _originals:
			var material: Material = factory.call(original)
			_count_material("buff", material, original)
			buffs.append(material)
		_buff_bank["tool"] = {"node": null, "overlays": buffs, "variants": _buff_variants(buffs)}
	return select_buff("tool")

func configure_frost(building: bool) -> bool:
	if _building_frost == building: return true
	if _material_plan.get("mode") == "match": return _fail("Building frost type differs from prepared plan")
	_building_frost = building
	_base_overlays.clear()
	_prepare_overlays()
	for key in _buff_bank: _buff_bank[key].variants = _buff_variants(_buff_bank[key].overlays)
	return select_buff(_selected_buff)

func _overlay_variants(base: Material) -> Array:
	var hit := _flash.duplicate() as StandardMaterial3D
	hit.next_pass = base
	_count_material("hit", hit, base)
	return [base, hit, base]

func _frost(base: Material) -> Material:
	var frost: Material
	if _building_frost:
		var attached := ShaderMaterial.new()
		attached.shader = load("res://assets/effects/freeze/attached_frost.gdshader")
		frost = attached
	else:
		var tinted := _flash.duplicate() as StandardMaterial3D
		tinted.albedo_color = Color(0.3, 0.7, 1.0, 0.28)
		frost = tinted
	frost.next_pass = base
	_count_material("frost", frost, base)
	return frost

func _buff_variants(buffs: Array) -> Array:
	var result := []
	for index in _meshes.size():
		if buffs[index] == _originals[index]:
			result.append(_base_overlays[index])
		else:
			var variants := _overlay_variants(buffs[index])
			if _frost_requested: variants[2] = _frost(buffs[index])
			result.append(variants)
	return result

func _prepare_overlays() -> void:
	if _base_overlays.is_empty():
		for original in _originals: _base_overlays.append(_overlay_variants(original))
	_frost_prepared = false
	if _frost_requested: _prepare_frost()
	select_buff(_selected_buff)

func select_buff(key: String) -> bool:
	if not key.is_empty() and not _buff_bank.has(key): return _fail("Unprepared buff requested: " + key)
	_selected_buff = key
	_buffs.clear()
	if not key.is_empty(): _buffs.assign(_buff_bank[key].overlays)
	_overlays.clear()
	for index in _meshes.size():
		var variants: Array = _base_overlays[index].duplicate()
		variants.append_array(_base_overlays[index] if key.is_empty() else _buff_bank[key].variants[index])
		_overlays.append(variants)
	_last_state = -1
	return true

func _prepare_buff_bank(root: Node) -> void:
	for descriptor in _material_plan.get("buffs", []):
		var key: String = descriptor.key
		if _buff_bank.has(key): continue
		var packed := load(descriptor.scene) as PackedScene
		var node := packed.instantiate() as ActiveBuffVisual3D if packed != null else null
		if node == null:
			_fail("Invalid planned buff: " + String(descriptor.scene))
			return
		var initial_transform := node.transform
		var existing := {}
		for child in root.find_children("*", "Node", true, false): existing[child] = true
		node.add_to_group("prepared_buff_bank")
		root.add_child(node)
		node.configure(float(descriptor.radius), int(descriptor.team))
		node.bind_model(root)
		for child in root.find_children("*", "Node", true, false):
			if existing.has(child) or child == node: continue
			if child is GeometryInstance3D: child.add_to_group("presentation_fx")
			if not node.is_ancestor_of(child): child.add_to_group("prepared_buff_aux")
		node.top_level = true
		node.hide()
		node.process_mode = Node.PROCESS_MODE_DISABLED
		var buffs: Array[Material] = []
		for original in _originals:
			var material: Material = node.make_overlay(original)
			_count_material("buff", material, original)
			buffs.append(material)
		_buff_bank[key] = {"node": node, "transform": initial_transform, "overlays": buffs, "variants": _buff_variants(buffs)}

func buff_node(key: String) -> ActiveBuffVisual3D:
	if not _buff_bank.has(key):
		_fail("Unprepared buff node requested: " + key)
		return null
	return _buff_bank[key].node

func buff_transform(key: String) -> Transform3D:
	return _buff_bank[key].transform

func park_buff(node: ActiveBuffVisual3D, reset: bool = true) -> void:
	if not is_instance_valid(node): return
	if reset: node.reset_prepared_visual()
	node.hide()
	node.process_mode = Node.PROCESS_MODE_DISABLED

## 当前preserve能力仅允许没有模型overlay的附属节点，交换已准备节点保持时钟。
func preserve_buff(previous: ModelVisualResources, node: ActiveBuffVisual3D, key: String) -> bool:
	if not node.can_preserve_prepared_state(): return _fail("Buff has no explicit prepared-state preservation contract")
	if not _buff_bank.has(key): return _fail("Preserved buff absent from new plan")
	var old_key := ""
	for candidate in previous._buff_bank:
		if previous._buff_bank[candidate].node == node: old_key = candidate
	if old_key.is_empty(): return _fail("Preserved buff absent from old owner")
	for owner in [self, previous]:
		var selected: String = key if owner == self else old_key
		for index in owner._meshes.size():
			if owner._buff_bank[selected].overlays[index] != owner._originals[index]: return _fail("Preserved model-overlay transfer requires explicit support")
	var replacement: ActiveBuffVisual3D = _buff_bank[key].node
	previous._buff_bank[old_key].node = replacement
	_buff_bank[key].node = node
	replacement.reparent(previous._model.get_ref(), false)
	node.reparent(_model.get_ref(), false)
	node.remove_meta("preserve_prepared_buff")
	replacement.bind_model(previous._model.get_ref())
	previous.park_buff(replacement)
	node.bind_model(_model.get_ref())
	return true

## _prepare_overlays 在没有强化材质时，后三态直接复用前三态的引用。
## apply_overlays 只切换引用，不修改资源参数；任何强化材质均保守保留六次绘制。
func overlay_state_repeats_base(state: int) -> bool:
	return state >= 3 and state < 6 and _buffs.is_empty()

func _prepare_frost() -> void:
	_frost_requested = true
	if _frost_prepared: return
	for index in _meshes.size(): _base_overlays[index][2] = _frost(_originals[index])
	for key in _buff_bank:
		for index in _meshes.size():
			var bank: Dictionary = _buff_bank[key]
			if bank.overlays[index] != _originals[index]: bank.variants[index][2] = _frost(bank.overlays[index])
	_frost_prepared = true
	select_buff(_selected_buff)

func _prepare_gold() -> void:
	_gold = ShaderMaterial.new()
	_gold.shader = load("res://assets/effects/stasis/attached_mesh.gdshader")
	_gold.set_shader_parameter("swirl", load("res://assets/effects/stasis/bard_swirl.png"))
	var gold_layer := ShaderMaterial.new()
	gold_layer.shader = load("res://assets/effects/stasis/attached_gold.gdshader")
	gold_layer.set_shader_parameter("swirl", load("res://assets/effects/stasis/zhonya_swirl.png"))
	_gold.next_pass = gold_layer
	_gold_overlays.clear()
	for mesh in _meshes:
		var overlay := _gold
		# 烘焙废墟包含内凹面；绕原点扩张会让覆盖面埋回原网格。
		# 保持顶点完全贴合，仅向相机偏移深度，不改变轮廓或遮挡关系。
		if mesh in _gold_ruins:
			overlay = _gold.duplicate() as ShaderMaterial
			overlay.set_shader_parameter("mesh_scale", 1.0)
			overlay.set_shader_parameter("depth_bias", 0.00001)
			var attached_gold := gold_layer.duplicate() as ShaderMaterial
			attached_gold.set_shader_parameter("mesh_scale", 1.0)
			attached_gold.set_shader_parameter("depth_bias", 0.00002)
			overlay.next_pass = attached_gold
		_gold_overlays.append(overlay)
		_count_material("gold", overlay)

func apply_overlays(hit: bool, frozen: bool, buff_visible: bool, stasis: bool = false, stealth: bool = false) -> bool:
	for requested in [[frozen and not stasis, "freeze"], [stasis, "stasis"], [stealth and not stasis, "stealth"]]:
		if requested[0] and not _allows(requested[1]): return _fail("Unplanned material state: " + String(requested[1]))
	if frozen and not stasis and not _frost_prepared: _prepare_frost()
	if stasis and _gold == null: _prepare_gold()
	apply_stealth(stealth and not stasis)
	var state := 6 if stasis else (3 if buff_visible else 0) + (1 if hit else (2 if frozen else 0))
	# 跳过闪白的网格仍需响应同一受击窗口内的冰冻边沿。
	var cache_state := state + (8 if hit and frozen and not stasis else 0)
	if cache_state == _last_state: return true
	_last_state = cache_state
	for index in _meshes.size():
		if not is_instance_valid(_meshes[index]): continue
		var mesh_state := state
		if not stasis and hit and bool(_meshes[index].get_meta("exclude_hit_flash", false)):
			mesh_state = (3 if buff_visible else 0) + (2 if frozen else 0)
		_meshes[index].material_overlay = _gold_overlays[index] if stasis else _overlays[index][mesh_state]
	return true

func reset_overlays() -> void:
	if is_instance_valid(_player):
		for name in _loops: _player.get_animation(name).loop_mode = _loops[name]
	select_buff("")
	for bank in _buff_bank.values():
		if is_instance_valid(bank.node) and not bool(bank.node.get_meta("preserve_prepared_buff", false)): park_buff(bank.node)
	apply_overlays(false, false, false)

func _capture_material_originals() -> void:
	# 原始快照始终保留；没有隐身能力时不创建ghost材料。
	for mesh in _meshes:
		var originals: Array = []
		_override_originals.append(mesh.material_override)
		_shadow_originals.append(mesh.cast_shadow)
		for surface in mesh.get_surface_override_material_count():
			originals.append(mesh.get_surface_override_material(surface))
		_surface_originals.append(originals)

func _prepare_stealth_materials() -> void:
	if not _surface_ghosts.is_empty(): return
	for mesh in _meshes:
		var ghosts: Array = []
		for surface in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(surface)
			var ghost := material.duplicate() as BaseMaterial3D if material is BaseMaterial3D else StandardMaterial3D.new()
			ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost.albedo_color = Color(0.75, 0.95, 0.90, 0.42)
			ghost.emission_enabled = true
			ghost.emission = Color(0.035, 0.10, 0.08)
			ghost.next_pass = null
			ghosts.append(ghost)
			_count_material("ghost", ghost)
		_surface_ghosts.append(ghosts)

func apply_stealth(enabled: bool) -> bool:
	if enabled and not _allows("stealth"): return _fail("Unplanned material state: stealth")
	if enabled == _stealth_active: return true
	if enabled: _prepare_stealth_materials()
	_stealth_active = enabled
	for index in _meshes.size():
		var mesh := _meshes[index]
		if not is_instance_valid(mesh): continue
		mesh.material_override = null if enabled else _override_originals[index]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if enabled else _shadow_originals[index]
		for surface in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(surface, _surface_ghosts[index][surface] if enabled else _surface_originals[index][surface])
	return true

func clear() -> void:
	for bank in _buff_bank.values():
		if is_instance_valid(bank.node):
			bank.node.release_prepared_visual()
			bank.node.free()
	_buff_bank.clear()
	_base_overlays.clear()
	_material_plan.clear()
	_model = null
	_selected_buff = ""
	_tool_factory = Callable()
	_counted_materials.clear()
	for kind in material_creations: material_creations[kind] = 0
	_animations = null
	errors.clear()
	apply_stealth(false)
	_surface_originals.clear()
	_surface_ghosts.clear()
	_override_originals.clear()
	_shadow_originals.clear()
	for index in _meshes.size():
		if is_instance_valid(_meshes[index]): _meshes[index].material_overlay = _originals[index]
	_meshes.clear()
	_originals.clear()
	_buffs.clear()
	_player = null
	_loops.clear()
	_gold = null
	_gold_overlays.clear()
	_gold_ruins.clear()
	_flash = null
	_building_frost = false
	_frost_prepared = false
	_frost_requested = false
	_overlays.clear()
	_last_state = -1

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D and not node.is_in_group("presentation_fx"):
		_meshes.append(node)
		_originals.append(node.material_overlay)
	for child in node.get_children(): _collect_meshes(child)

static func copy_animation(source: Animation) -> Animation:
	return ANIMATION_COPY.copy_animation(source)

static func copy_library(source: AnimationLibrary) -> AnimationLibrary:
	return ANIMATION_COPY.copy_library(source)
