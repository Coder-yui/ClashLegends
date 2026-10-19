extends RefCounted

func run(harness: Object) -> void:
	var compact_script = preload("res://scripts/presentation/compact_particle_samples.gd")
	var fixture := "/tmp/clash-compact-invalid-%d.clps" % OS.get_process_id()
	for header in [{}, {"schema":1, "frames":1e20, "layers":1, "rows":0, "width":4, "payload_bytes":16, "source":"res://tests/suite_catalog.json", "source_sha256":"bad", "payload_sha256":"bad", "data":{"emitters":[{}]}}, {"schema":1, "frames":1, "layers":1, "rows":0, "width":4, "payload_bytes":16, "source":"res://tests/suite_catalog.json", "source_sha256":"bad", "payload_sha256":"bad", "data":{"emitters":[{}]}}]:
		var file := FileAccess.open(fixture, FileAccess.WRITE)
		var bytes := JSON.stringify(header).to_utf8_buffer()
		file.store_buffer("CLPS0001".to_ascii_buffer())
		file.store_32(bytes.size())
		file.store_buffer(bytes)
		file.close()
		var invalid: RefCounted = compact_script.new()
		harness._expect(not invalid.read(fixture, "res://tests/suite_catalog.json") and not invalid.errors.is_empty() and invalid.values.is_empty(), "坏头/维度/源SHA在解压之前拒绝且不保留半成品")
	DirAccess.remove_absolute(fixture)
	var saved: Dictionary = CardArt._textures.duplicate()
	CardArt._textures.clear()
	var keep := GradientTexture1D.new()
	var unused := GradientTexture1D.new()
	CardArt._textures["anivia"] = keep
	CardArt._textures["garen"] = unused
	var result := CardArt.retain_match_textures(["anivia"])
	harness._expect(result.before == 2 and result.after == 1 and CardArt._textures.get("anivia") == keep and not CardArt._textures.has("garen"), "本局保留已选卡面，仅删除未选缓存所有权")
	CardArt._textures = saved
	var world := Node3D.new()
	harness.root.add_child(world)
	var pool := MatchModelPool.new()
	var packed := load("res://assets/units/aatrox/normal_view.tscn") as PackedScene
	var first: Node3D = pool.instantiate_visual(packed)
	var second: Node3D = pool.instantiate_visual(packed)
	first.process_mode = Node.PROCESS_MODE_DISABLED
	second.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(first)
	world.add_child(second)
	harness._expect(pool._wrapper_templates.size() == 1 and first._normal_mesh == second._normal_mesh and first._wing_mesh == second._wing_mesh, "剑魔本局只生成一组共享派生网格模板")
	var a: AnimationPlayer = first._player
	var b: AnimationPlayer = second._player
	harness._expect(a != b and first._mesh.get_parent() != second._mesh.get_parent(), "播放器与骨骼节点独立")
	for clip in a.get_animation_list():
		var left: Animation = a.get_animation(clip)
		var right: Animation = b.get_animation(clip)
		harness._expect(left != right and left.get_track_count() == right.get_track_count(), "每个活体动画独立：" + String(clip))
	var clip: Animation = a.get_animation("Passive_Attack_Ult")
	var target: NodePath = a.get_node(a.root_node).get_path_to(first.get_node("Model"))
	var track := clip.find_track(target, Animation.TYPE_POSITION_3D)
	harness._expect(track >= 0 and clip.track_get_key_value(track, 0) == Vector3(0, first.NATIVE_AIR_LIFT, 0), "保留大灭被动浮空高度轨道")
	clip.track_set_key_value(track, 0, Vector3(0, 99, 0))
	harness._expect(b.get_animation("Passive_Attack_Ult").track_get_key_value(track, 0) == Vector3(0, first.NATIVE_AIR_LIFT, 0), "修改一个实例动画不会污染其他实例")
	var owner_a := ModelVisualResources.new()
	var owner_b := ModelVisualResources.new()
	owner_a.bind_model(first)
	owner_b.bind_model(second)
	owner_a.apply_overlays(true, false, false)
	owner_b.apply_overlays(false, false, false)
	harness._expect(first._mesh.material_overlay != second._mesh.material_overlay, "共享网格不共享可变材质覆盖状态")
	world.free()
	pool.release_sources()
	harness._expect(pool._wrapper_templates.is_empty(), "本场模板随模型池清理，不形成跨局缓存")
