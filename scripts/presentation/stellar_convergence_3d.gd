extends Node3D
## 原生外圈与中心分别按权威半径等比缩放，不补偿俯视角。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER_PATH := "res://assets/effects/stellar_convergence/player.gd"
## 外围主环网格中线：37.7428 × 出生缩放10；不以外缘淡出为边界。
const ZONE_RADIUS := 377.428
## Ring_Alpha1金色亮线：纹理V≈145.5/256映射网格半径，再乘出生缩放6.5。
const CORE_RADIUS := 255.28
var _views: Dictionary = {}

func sync_effects(spells: RefCounted, camera: Camera3D, viewer_team: int = 0) -> void:
	var present := {}
	for effect in spells.stellar_effects:
		present[effect.id] = true
		if not _views.has(effect.id):
			var container := Node3D.new()
			add_child(container)
			container.position = PROJECTION.ground(camera, effect.pos)
			var radius := PROJECTION.ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(container.position)
			var enemy := int(effect.team) != viewer_team
			var kinds: Array = (["zone_red", "core_red"] if enemy else ["zone", "core"]) if effect.kind == "stellar_convergence" else ["execute"]
			var players := []
			for kind in kinds:
				var player: Node3D = load(PLAYER_PATH).new()
				container.add_child(player)
				player.load_kind(kind)
				var native_scale := radius / ZONE_RADIUS
				if String(kind).begins_with("core"):
					native_scale = radius * float(CardDB.get_card("stellar_convergence").inner_radius) / float(CardDB.get_card("stellar_convergence").radius) / CORE_RADIUS
				elif kind == "execute": native_scale = radius / 80.0
				player.setup_native(native_scale)
				players.append(player)
			_views[effect.id] = {"container": container, "players": players}
		for player in _views[effect.id].players: player.seek(float(effect.age))
	for id in _views.keys():
		if not present.has(id):
			_views[id].container.free()
			_views.erase(id)
