extends Node3D
## 原版护盾获得/破碎粒子和有盾/无盾贴图；只消费权威表现状态。
const Native = preload("res://assets/effects/malphite/player.gd")
const SIZING = preload("res://assets/units/malphite/visual_scale.gd")
const ROCK = preload("res://assets/units/malphite/source/rock.png")
const MOLTEN = preload("res://assets/units/malphite/source/molten.png")
var _unit: WeakRef
var _shield: Node3D
var _skeleton: Skeleton3D
var _hand := -1
var _pending_cast := false
var _materials: Array[StandardMaterial3D] = []
var _age := 0.0

var _had_shield := true
var _serial := -1
var _dead := false

func _ready() -> void:
	$Model.scale = Vector3.ONE * SIZING.MODEL_SCALE
	$Model.position.y = SIZING.GROUND_OFFSET
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null:
		_hand = _skeleton.find_bone("R_BUFFBONE_GLB_HAND_LOC")

func configure_unit_visual(unit: Unit) -> void:
	set_meta("visual_generation", int(get_meta("visual_generation", 0)) + 1)
	_unit = weakref(unit)
	_dead = false
	_age = 0.0
	_pending_cast = false
	_serial = -1
	_had_shield = unit.deployment_shield_active_visual()
	_ensure_visuals()
	_shield.bind_motion(self)
	_set_surface(_had_shield)

func _ensure_visuals() -> void:
	if is_instance_valid(_shield): return
	for node in $Model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i)
			var material := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
			mesh.set_surface_override_material(i, material)
			_materials.append(material)
	_shield = _make("shield")
	for node in $Model.find_children("*", "MeshInstance3D", true, false):
		for i in node.mesh.get_surface_count():
			node.set_surface_override_material(i, _shield.make_overlay(node.get_active_material(i)))

func _make(kind: String) -> Node3D:
	var player := Native.new()
	add_child(player)
	player.load_kind(kind)
	player.setup_native(Native.NATIVE_SCALE)
	return player

func _set_surface(shielded: bool) -> void:
	for material in _materials:
		material.albedo_texture = ROCK if shielded else MOLTEN

## The presentation world owns released particles; the pooled model owns only attachments.
func _release(kind: String, origin: Vector3, age: float = 0.0) -> void:
	var world := get_parent().get_parent()
	var owner_ref = world.get_meta("malphite_effect_owner", null)
	var effect_owner = owner_ref.get_ref() if owner_ref is WeakRef else null
	if not is_instance_valid(effect_owner): return
	var transform := Transform3D(global_basis.orthonormalized(), origin)
	effect_owner.spawn_detached(kind, transform, self if kind == "break" else null, age)

func _sync_shield_state() -> void:
	var unit = _unit.get_ref() if _unit != null else null
	if not is_instance_valid(unit): return
	var shielded: bool = unit.deployment_shield_active_visual()
	if shielded == _had_shield: return
	_set_surface(shielded)
	if not shielded: _release("break", global_position)
	_had_shield = shielded

func advance_ambient_visual(delta: float) -> void:
	if _dead: return
	_ensure_visuals()
	var unit = _unit.get_ref() if _unit != null else null
	_sync_shield_state()
	var shielded := _had_shield
	if is_instance_valid(unit):
		if unit.get_visual_action_serial() != _serial:
			_serial = unit.get_visual_action_serial()
			_pending_cast = unit.get_visual_action_name() == &"active"
		if _pending_cast and unit.get_visual_action_name() == &"active":
			var duration: float = unit.get_visual_action_duration()
			var age: float = maxf(0.0, duration - unit.get_visual_action_time_left())
			var trigger := duration * SIZING.E_EVENT_RATIO
			if age >= trigger:
				_pending_cast = false
				if is_instance_valid(_skeleton) and _hand >= 0:
					var origin := _skeleton.to_global(_skeleton.get_bone_global_pose(_hand).origin)
					_release("cas", origin, age - trigger)
		_age += maxf(delta, 0.0)
	_shield.visible = shielded and _age <= 4.0
	_shield.seek(_age)
	_shield.update_attached(shielded and _age <= 4.0)

func begin_visual_death(_duration: float) -> void:
	if not _dead: _sync_shield_state() # Consume a lethal shield break before stopping updates.
	set_meta("visual_generation", int(get_meta("visual_generation", 0)) + 1)
	_dead = true
	_pending_cast = false
	if is_instance_valid(_shield):
		_shield.hide()
		_shield.update_attached(false)

func reset_pool_visual() -> void:
	_unit = null
	begin_visual_death(0.0)
