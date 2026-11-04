extends Node3D
## 只消费落地事件与单位快照；下降模型没有权威身体。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
# 与权威100像素圆叠加，在落地展开段/常驻稳定段校准可见环带；不使用贴图透明外框。
const IMPACT_REFERENCE_RADIUS := 260.0
const AURA_REFERENCE_RADIUS := 280.0
const PLAYER_PATH := "res://assets/effects/airdrop_bear/player.gd"
var _views: Dictionary = {}
var _auras: Dictionary = {}

func _player(parent: Node3D, kind: String, size: float) -> Node3D:
	var player: Node3D = load(PLAYER_PATH).new()
	parent.add_child(player)
	player.load_kind(kind)
	player.setup_native(size)
	return player
func sync_effects(spells: RefCounted, camera: Camera3D, delta: float) -> void:
	var present := {}
	for effect in spells.bear_effects:
		present[effect.id] = true
		if not _views.has(effect.id):
			var container := Node3D.new()
			add_child(container)
			container.position = PROJECTION.ground(camera, effect.pos)
			var radius := PROJECTION.ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(container.position)
			var falling: Node3D = load("res://assets/units/tibbers/tibbers_view.tscn").instantiate()
			container.add_child(falling)
			falling.rotation.y = PI if int(effect.team) == 0 else 0.0
			var animation: AnimationPlayer = falling.find_child("AnimationPlayer", true, false)
			if animation != null:
				animation.play("annietibbers_idle1")
				animation.seek(0.1, true)
				animation.pause()
			_views[effect.id] = {"container": container, "impact": _player(container, "impact", radius / IMPACT_REFERENCE_RADIUS), "falling": falling}
		var view: Dictionary = _views[effect.id]
		var impact_time := float(int(effect.end_tick) - int(effect.start_tick)) * FixedStepClock.STEP
		var age := float(effect.age)
		var fall_duration := float(CardDB.get_card("airdrop_bear").duration)
		var fall_start := impact_time - fall_duration
		view.falling.visible = age >= fall_start and age < impact_time
		view.falling.position.y = 8.0 * (1.0 - pow(clampf((age - fall_start) / fall_duration, 0.0, 1.0), 2.0))
		view.impact.visible = age >= impact_time
		view.impact.seek(maxf(0.0, age - impact_time))
	for id in _views.keys():
		if not present.has(id):
			_views[id].container.free()
			_views.erase(id)
	var burning := {}
	for unit in get_tree().get_nodes_in_group("combatants"):
		if not unit is Unit or unit.hp <= 0 or not unit.burning_aura: continue
		var id: int = unit.get_instance_id()
		burning[id] = true
		if not _auras.has(id):
			var point := PROJECTION.ground(camera, unit.global_position)
			var aura_radius := float(CardDB.get_card("airdrop_bear").active_skills[0].radius)
			var world_radius := PROJECTION.ground(camera, unit.global_position + Vector2(aura_radius, 0)).distance_to(point)
			_auras[id] = {"player": _player(self, "aura", world_radius / AURA_REFERENCE_RADIUS), "age": 0.0}
		var state: Dictionary = _auras[id]
		var player: Node3D = state.player
		player.position = PROJECTION.ground(camera, unit.global_position)
		player.visible = not CombatInteraction.in_stasis(unit)
		# 启动层只播放一次；持续层按完整粒子寿命跨周期延续。
		if player.visible: state.age += maxf(delta, 0.0)
		player.seek(float(state.age))
	for id in _auras.keys():
		if not burning.has(id):
			_auras[id].player.free()
			_auras.erase(id)
