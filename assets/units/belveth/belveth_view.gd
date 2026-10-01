extends Node3D
## 将原生起手与收势拼成完整普攻；只加工表现片段。
var prepared := false
func _ready() -> void:
	prepare_visual_animations()

func prepare_visual_animations() -> void:
	if prepared: return
	prepared = true
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for index in [1, 2]:
		var first := player.get_animation("Attack_Slow%da" % index)
		var second := player.get_animation("Attack_Slow%db" % index)
		var combined := first.duplicate(true) as Animation
		combined.length = first.length + second.length
		combined.loop_mode = Animation.LOOP_NONE
		for track in second.get_track_count():
			var target := combined.find_track(second.track_get_path(track), second.track_get_type(track))
			if target < 0:
				target = combined.add_track(second.track_get_type(track))
				combined.track_set_path(target, second.track_get_path(track))
				combined.track_set_interpolation_type(target, second.track_get_interpolation_type(track))
			for key in second.track_get_key_count(track):
				combined.track_insert_key(target, first.length + second.track_get_key_time(track, key), second.track_get_key_value(track, key))
		library.add_animation("Attack%d" % index, combined)
