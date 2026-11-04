extends ActiveBuffVisual3D
## 原版 E 粒子只消费模型代理发布的状态和表现时钟。
const EFFECT_SCALE := 0.0075
const SOURCE_CENTER := 85.0
var _model: Node3D
var _center_local := Vector3(0, 1.05, 0)
const PLAYER = preload("res://assets/units/pantheon/arrival/particle_player.gd")
var definitions: Dictionary
var shield: Node3D
var bursts: Array[Dictionary] = []
var _await_inactive := false

func configure(_radius: float, _team: int = 0) -> void:
	for key in ["shield", "block"]:
		definitions[key] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/sivir/native/" + key + ".json")).emitters

func bind_model(model: Node3D) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone("C_Buffbone_Glb_Center_Loc")
	if bone < 0: return
	_model = model
	# Shield follows the actor, not the bending attack pose. Convert the authored
	# rest center through the wrapper once; retain horizontal actor movement/yaw.
	_center_local = model.to_local(skeleton.to_global(skeleton.get_bone_global_rest(bone).origin))
	_update_anchor()

func _update_anchor() -> void:
	if is_instance_valid(_model):
		global_position = _model.to_global(_center_local) - Vector3.UP * SOURCE_CENTER * EFFECT_SCALE

func make_player(key: String) -> Node3D:
	var player := PLAYER.new()
	add_child(player)
	_update_anchor()
	var layers: Array = definitions[key].duplicate(true)
	# The shield is an attached status, including its fading shell. Native
	# spheredetail drops bind weight to zero and otherwise leaves a ghost behind.
	if key == "shield":
		for layer: Dictionary in layers: layer.bind = {"base": 1.0}
	player.setup(key, EFFECT_SCALE, false, "", false, false, layers)
	return player

func _retire_shield() -> void:
	if not is_instance_valid(shield): return
	# Buff-owned visuals end with the buff; they are not proc afterglow.
	shield.free()
	shield = null

func on_cue(cue: StringName) -> void:
	if cue == &"effect_shield:start":
		_await_inactive = false
		_retire_shield()
		shield = make_player("shield")
		active = true
	if cue in [&"effect_shield:block", &"effect_shield:end"]:
		_retire_shield()
		_await_inactive = true
		if cue == &"effect_shield:block":
			bursts.append({"node": make_player("block")})

func advance(enabled: bool, delta: float) -> void:
	_update_anchor()
	if not enabled: _await_inactive = false
	if enabled and not active and not _await_inactive: shield = make_player("shield")
	if not enabled and active and is_instance_valid(shield):
		_retire_shield()
	active = enabled
	if is_instance_valid(shield): shield.advance(delta)
	for index in range(bursts.size() - 1, -1, -1):
		bursts[index].node.advance(delta)
		# E_proc owns only its finite emitter schedule and live particles.
		var player: Node3D = bursts[index].node
		if player._time >= 0.3 and player._particles.is_empty():
			bursts[index].node.queue_free()
			bursts.remove_at(index)
	visible = is_instance_valid(shield) or not bursts.is_empty()

static func resource_manifest(variant: String) -> Dictionary:
	if variant == "blade": return {"paths": ["res://assets/effects/sivir/blade.png"]}
	if variant != "shield": return {}
	return {"shader_providers": ["res://assets/units/pantheon/arrival/particle_player.gd"], "json": ["res://assets/effects/sivir/native/shield.json", "res://assets/effects/sivir/native/block.json"]}

static func resource_shader_path(emitter: Dictionary) -> String:
	return PLAYER.resource_shader_path(emitter)

func prepare_resource_sample(_skills: Array, draw: Callable) -> void:
	on_cue(&"effect_shield:block")
	for step in 20:
		advance(true, 0.1)
		draw.call()
