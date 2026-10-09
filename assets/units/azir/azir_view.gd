extends Node3D
## 原版动画 CAST 事件只创建武器特效；真实伤害仍由 20Hz 攻击时间线决定。
const CAST_PLAYER = preload("res://assets/effects/azir/player.gd")
const ATTACKS := ["Azir_Attack1_anm", "Azir_Attack2_anm"]
const CAST_FRAME_TIME := 1.0 / 30.0
var _source: Unit
var _animation: AnimationPlayer
var _weapon: BoneAttachment3D
var _seen_serial := -1
var _casts: Array[Dictionary] = []

func configure_unit_visual(source: Unit) -> void:
	_clear_casts()
	_source = source
	_seen_serial = -1
	for player: AnimationPlayer in find_children("*", "AnimationPlayer", true, false):
		_animation = player
		break
	if not is_instance_valid(_weapon):
		_weapon = _bone_anchor("Weapon", "AttackCastAnchor")

func _process(delta: float) -> void:
	if not is_instance_valid(_source) or _source.hp <= 0.0:
		_clear_casts()
		return
	if _source.is_frozen() or _source.is_stunned(): return
	for index in range(_casts.size() - 1, -1, -1):
		var cast := _casts[index]
		cast.age += delta
		if cast.age >= 0.8:
			cast.player.free()
			_casts.remove_at(index)
		else: cast.player.seek(cast.age)
	if not is_instance_valid(_animation) or not is_instance_valid(_weapon): return
	var serial := _source.get_attack_visual_serial()
	if serial <= 0 or serial == _seen_serial or _source.get_visual_state_code() != 3: return
	var attack_index := ATTACKS.find(String(_animation.current_animation))
	if attack_index < 0: return
	var position := _animation.current_animation_position
	if position < CAST_FRAME_TIME: return
	_seen_serial = serial
	# 快照补帧若已错过短时起手，不从头闪播；来源模型已带 0.011 比例。
	var age := maxf(_source.get_attack_elapsed_visual() - CAST_FRAME_TIME, 0.0)
	if age >= 0.8: return
	var player := CAST_PLAYER.new()
	_weapon.add_child(player)
	player.load_kind("cast1" if attack_index == 0 else "cast2")
	player.setup_native(1.0)
	player.seek(age)
	_casts.append({"player": player, "age": age})

func _clear_casts() -> void:
	for cast in _casts:
		if is_instance_valid(cast.player): cast.player.free()
	_casts.clear()

func _bone_anchor(bone: String, label: String) -> BoneAttachment3D:
	for skeleton: Skeleton3D in find_children("*", "Skeleton3D", true, false):
		var index := skeleton.find_bone(bone)
		if index < 0: continue
		var anchor := BoneAttachment3D.new()
		anchor.name = label
		anchor.bone_idx = index
		skeleton.add_child(anchor)
		return anchor
	return null

func create_projectile_anchor() -> Node3D:
	return _bone_anchor("Buffbone_Glb_Weapon_1", "ProjectileModelAnchor")
