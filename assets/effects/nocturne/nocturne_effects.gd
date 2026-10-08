extends ActiveBuffVisual3D
## 原版P/W粒子只消费模型代理发布的动作序号、状态和表现时钟。
const PLAYER = preload("res://assets/units/pantheon/arrival/particle_player.gd")
var definitions: Dictionary
var shield: Node3D
var bursts: Array[Dictionary] = []

func configure(_radius: float, _team: int = 0) -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/nocturne/native/systems.json"))

func make_player(key: String) -> Node3D:
	var player := PLAYER.new()
	add_child(player)
	# P匹配70像素伤害圈；护盾/抵挡独立贴合1.8模型，不共用大范围旋斩比例。
	var effect_scale := 0.007 if key == "P" else 0.0105
	var layers: Array = definitions[key].duplicate(true)
	player.setup(key, effect_scale, false, "", false, false, layers)
	return player

func _retire_shield() -> void:
	if not is_instance_valid(shield): return
	shield.stop_emitting()
	bursts.append({"node": shield, "left": 1.0})
	shield = null

func on_cue(cue: StringName) -> void:
	if cue == &"effect_shield:start":
		_retire_shield()
		shield = make_player("W")
		active = true
	if cue == &"cleave:hit": bursts.append({"node": make_player("P"), "left": 2.0})
	if cue == &"effect_shield:block": bursts.append({"node": make_player("block"), "left": 1.5})

func advance(enabled: bool, delta: float) -> void:
	if enabled and not active: shield = make_player("W")
	if not enabled and active and is_instance_valid(shield):
		_retire_shield()
	active = enabled
	if is_instance_valid(shield): shield.advance(delta)
	for index in range(bursts.size() - 1, -1, -1):
		bursts[index].node.advance(delta)
		bursts[index].left -= delta
		if bursts[index].left <= 0.0:
			bursts[index].node.queue_free()
			bursts.remove_at(index)
	visible = active or not bursts.is_empty()

static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["shield", "cleave"]: return {}
	return {"shader_providers": ["res://assets/units/pantheon/arrival/particle_player.gd"], "json": ["res://assets/effects/nocturne/native/systems.json"], "systems": ["W", "block"] if variant == "shield" else ["P"]}

## 附属播放器自己决定如何采样，模型池不识别英雄身份。
func prepare_resource_sample(skills: Array, draw: Callable) -> void:
	var shield_enabled := skills.any(func(skill): return skill.get("kind") == "effect_shield")
	if skills.any(func(skill): return skill.get("kind") == "empowered_attack"): on_cue(&"cleave:hit")
	if shield_enabled: on_cue(&"effect_shield:block")
	for step in 20:
		advance(shield_enabled, 0.1)
		draw.call()
