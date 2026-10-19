extends SceneTree
## 两模型、每次两实例；不启动战斗、不建库存、不测性能。
const OWNER = preload("res://scripts/presentation/model_animation_instance.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var pulse: RefCounted
var failures: Array[String] = []
var checks := 0
var output := ""
var reports := {}
var compile_render_only := false

class FixedTemplate extends Node3D:
	var player: AnimationPlayer
	var libraries := {}
	func visual_animation_contract() -> Dictionary:
		return {"version": 1, "player": player, "libraries": libraries}

func plain_fixture() -> Node3D:
	var model := Node3D.new()
	var player := AnimationPlayer.new()
	model.add_child(player)
	var library := AnimationLibrary.new()
	for clip in ["first", "second", "unused"]: library.add_animation(clip, Animation.new())
	player.add_animation_library("", library)
	return model

func check_requirements() -> void:
	var model := plain_fixture()
	var record: RefCounted = OWNER.begin(model, {"first": true, "second": true})
	while not record.step(): pass
	check(OWNER.begin(model, {"first": true}) == record and record.errors.is_empty(), "filtered: subset rebind compatible")
	check(not OWNER.begin(model, {"first": true, "unused": true}).errors.is_empty() and record.errors.is_empty(), "filtered: expanded request rejected without poisoning valid record")
	check(not OWNER.begin(model).errors.is_empty(), "filtered: unfiltered request cannot silently reuse subset")
	check(OWNER.begin(model, {"attack": true, "first": true}) == record, "configuration field keys are not clip requirements")
	model.free()
	var fixed := FixedTemplate.new()
	var original := plain_fixture()
	fixed.player = original.get_child(0) as AnimationPlayer
	original.remove_child(fixed.player)
	fixed.add_child(fixed.player)
	original.free()
	var template := AnimationLibrary.new()
	for clip in ["first", "second"]: template.add_animation(clip, Animation.new())
	fixed.libraries[&""] = template
	record = OWNER.begin(fixed, {"first": true})
	while not record.step(): pass
	check(record.errors.is_empty() and record.player.has_animation("second"), "fixed: first subset request prepares entire declared closure")
	check(OWNER.begin(fixed) == record and OWNER.begin(fixed, {"second": true}) == record, "fixed: empty or another declared subset reuses full closure")
	check(not OWNER.begin(fixed, {"unused": true}).errors.is_empty() and record.errors.is_empty(), "fixed: source clip outside declared closure rejected")
	fixed.libraries[&""] = AnimationLibrary.new()
	check(not OWNER.begin(fixed).errors.is_empty(), "fixed: replaced template source rejected")
	fixed.free()
	model = plain_fixture()
	var owner := ModelVisualResources.new()
	owner.begin_bind(model, {"first": true, "second": true}, ModelVisualResources.tool_material_states())
	var player := model.get_child(0) as AnimationPlayer
	player.remove_animation_library("")
	player.add_animation_library("", AnimationLibrary.new())
	check(owner.step_bind() and not owner.errors.is_empty() and owner.animation_player() == null, "pending: step rejects replaced library and propagates late errors")
	owner.clear()
	model.free()
	model = plain_fixture()
	record = OWNER.begin(model, {"first": true, "second": true})
	player = model.get_child(0) as AnimationPlayer
	player.remove_animation_library("")
	player.add_animation_library("", AnimationLibrary.new())
	check(not OWNER.begin(model, {"first": true}).errors.is_empty(), "pending: repeated begin detects replaced library before complete")
	model.free()

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--compile-render": compile_render_only = true
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func check_model(path: String, id: String) -> void:
	pulse.set_phase("contract:" + id)
	var packed := load(path) as PackedScene
	var pool := MatchModelPool.new()
	var world := Node3D.new()
	root.add_child(world)
	pool._world = world
	pool.capacity[path] = 1
	pool.instances[path] = []
	# 摄影：直接wrapper入树，随后重复prepare/bind。
	var direct := packed.instantiate() as Node3D
	world.add_child(direct)
	direct.process_mode = Node.PROCESS_MODE_DISABLED
	direct.call("prepare_visual_animations")
	var first: RefCounted = direct.get_meta(OWNER.SLOT)
	var first_player: AnimationPlayer = first.player
	var clip := "Idle1" if id == "aatrox" else "Idle1_Base"
	var first_animation := first_player.get_animation(clip)
	var direct_owner := ModelVisualResources.new()
	direct_owner.bind_model(direct, {clip: true}, ModelVisualResources.tool_material_states())
	check(direct_owner.errors.is_empty() and first_player.get_animation(clip) == first_animation and direct.get_meta(OWNER.SLOT) == first, id + ": photography handoff does not recopy")
	# 池创建：ready只装模板，随后按clip分步bind。
	var second := pool.instantiate_visual(packed) as Node3D
	world.add_child(second)
	second.process_mode = Node.PROCESS_MODE_DISABLED
	second.call("prepare_visual_animations")
	check(not second.has_meta(OWNER.SLOT), id + ": pool defers ownership until bind")
	var second_owner := ModelVisualResources.new()
	second_owner.begin_bind(second, {clip: true}, ModelVisualResources.tool_material_states())
	var steps := 0
	while true:
		steps += 1
		if second_owner.step_bind(): break
	check(second_owner.errors.is_empty() and steps > 1, id + ": incremental bind completes")
	var second_record: RefCounted = second.get_meta(OWNER.SLOT)
	var second_player := second_owner.animation_player()
	var template: Resource = direct.visual_template
	var template_animation: Animation = template.libraries[&""].get_animation(clip)
	check(first.complete and second_record.complete and first.policy == "generated-template-v1" and first.copied_animations == second_record.copied_animations, id + ": same explicit ownership for direct/incremental")
	check(first_player != second_player and first_player.get_animation_library("") != second_player.get_animation_library("") and first_animation != second_player.get_animation(clip) and first_animation != template_animation, id + ": player/library/animation isolated")
	var template_loop := template_animation.loop_mode
	var other_loop := second_player.get_animation(clip).loop_mode
	var template_key: Variant = template_animation.track_get_key_value(0, 0)
	var other_key: Variant = second_player.get_animation(clip).track_get_key_value(0, 0)
	first_animation.loop_mode = Animation.LOOP_PINGPONG
	var changed: Variant = Vector3(123, 456, 789) if typeof(template_key) == TYPE_VECTOR3 else Quaternion(0, 0, 0, 1)
	if changed == template_key: changed = Quaternion(1, 0, 0, 0)
	first_animation.track_set_key_value(0, 0, changed)
	check(template_animation.loop_mode == template_loop and second_player.get_animation(clip).loop_mode == other_loop and template_animation.track_get_key_value(0, 0) == template_key and second_player.get_animation(clip).track_get_key_value(0, 0) == other_key, id + ": unilateral loop/key mutation cannot reach other/template")
	first_player.play("Death")
	first_player.advance(0.1)
	check(not second_player.is_playing(), id + ": action/pose state independent")
	var first_skeleton := direct.find_child("Skeleton3D", true, false) as Skeleton3D
	var second_skeleton := second.find_child("Skeleton3D", true, false) as Skeleton3D
	var other_pose := second_skeleton.get_bone_pose_position(0)
	first_skeleton.set_bone_pose_position(0, Vector3(4, 5, 6))
	check(first_skeleton != second_skeleton and second_skeleton.get_bone_pose_position(0) == other_pose, id + ": skeleton independent")
	if id == "aatrox":
		check(not template.meshes.has("full") and template.meshes.size() == 2, "aatrox: full mesh absent from template")
		direct.set_visual_form(1)
		direct.set_visual_clip("Passive_Attack_Ult")
		check(direct._mesh.mesh == direct._full_mesh and second._mesh.mesh == template.meshes.normal, "aatrox: original full mesh form independent")
		check(direct._full_mesh == second._full_mesh, "aatrox: full mesh reuses shared imported source")
		direct._update_surfaces("ULT_out", 0.0)
		check(direct._mesh.mesh == template.meshes.wing, "aatrox: revert early wing mesh")
		direct._update_surfaces("ULT_out", 0.5)
		check(direct._mesh.mesh == template.meshes.normal, "aatrox: revert later normal mesh")
		var ult: Animation = template.libraries[&""].get_animation("Passive_Attack_Ult")
		var track := ult.get_track_count() - 1
		check(ult.track_get_key_value(track, 0).is_equal_approx(Vector3(0, 0.998591, 0)), "aatrox: generated passive height")
		var first_modifiers := direct.find_children("*", "SkeletonModifier3D", true, false).filter(func(node): return node.get_script() == load("res://assets/units/aatrox/weapon_snap.gd"))
		var second_modifiers := second.find_children("*", "SkeletonModifier3D", true, false).filter(func(node): return node.get_script() == load("res://assets/units/aatrox/weapon_snap.gd"))
		check(first_modifiers.size() == 1 and second_modifiers.size() == 1 and first_modifiers[0] != second_modifiers[0], "aatrox: one independent modifier per instance " + str(first_modifiers) + " / " + str(second_modifiers))
	else:
		for attack in ["Attack1_BASE", "Attack2_BASE"]:
			var animation: Animation = template.libraries[&""].get_animation(attack)
			var valid := animation.get_track_count() > 0
			for track in animation.get_track_count():
				valid = valid and String(animation.track_get_path(track).get_concatenated_subnames()) in ["C_Buffbone_Glb_Chest_Loc", "Buffbone_Cstm_Obelisk_Tip"]
			check(valid, "sun_disc: generated attack bone mask " + attack)
		second.finish_visual_death()
		check(not second.get_node("RuinBase").visible and direct.get_node("RuinBase").visible, "sun_disc: death visibility independent")
		second.get_node("RuinBase").show()
	# 使用正式recycle/acquire，回池不会换掉活体资源或重复制。
	check(pool._can_recycle(second), id + ": reset contract supports production recycle")
	second.set_meta("pool_path", path)
	second.set_meta("pool_state", pool._capture_state(second))
	if id == "sun_disc": second.finish_visual_death()
	else:
		second.set_visual_form(1)
		second.set_visual_clip("Passive_Attack_Ult")
	check(pool.recycle(second, second_owner, second_player), id + ": production recycle")
	var returned: Node3D = pool.take(packed)
	check(returned == second and returned.get_meta(OWNER.SLOT) == second_record and second_record.copied_animations == first.copied_animations, id + ": acquire preserves animation ownership")
	if id == "sun_disc": check(second.get_node("RuinBase").visible, "sun_disc: recycle restores ruin visibility")
	else: check(not second.ultimate_form and second._mesh.mesh == template.meshes.normal, "aatrox: recycle restores normal form")
	reports[id] = {"clips": first_player.get_animation_list(), "copies_per_instance": first.copied_animations, "step_bind_calls": steps}
	returned.free()
	direct_owner.clear()
	second_owner.clear()
	direct.free()
	pool.release_sources()
	world.free()
	await process_frame

func check_failures() -> void:
	var wrong := Node3D.new()
	wrong.set_meta(OWNER.SLOT, RefCounted.new())
	check(not OWNER.begin(wrong).errors.is_empty(), "unknown ownership state explicitly rejected")
	wrong.free()
	var root_model := Node3D.new()
	var player := AnimationPlayer.new()
	root_model.add_child(player)
	var source := Animation.new()
	var library := AnimationLibrary.new()
	library.add_animation("first", source)
	library.add_animation("alias", source)
	library.add_animation("unused", Animation.new())
	player.add_animation_library("", library)
	var owner := ModelVisualResources.new()
	owner.begin_bind(root_model, {"first": true, "alias": true}, ModelVisualResources.tool_material_states())
	while not owner.step_bind(): pass
	check(player.has_animation("first") and not player.has_animation("unused") and player.get_animation("first") == player.get_animation("alias") and player.get_animation("first") != source and library.has_animation("unused"), "plain scene filter preserves alias and source")
	player.remove_animation_library("")
	check(not OWNER.begin(root_model).errors.is_empty(), "externally replaced owned animation set rejected")
	owner.clear()
	root_model.free()

func run() -> void:
	if not pulse.enabled or output.is_empty(): quit(2); return
	var render_script := load("res://tools/maintenance/model_template_render.gd") as GDScript
	check(render_script != null and render_script.can_instantiate(), "dedicated render script compiles before single render")
	if compile_render_only:
		pulse.set_phase("compile-only:done", true)
		FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "render script compile only; no model instances"}))
		await process_frame
		quit(0 if failures.is_empty() else 1)
		return
	check_requirements()
	check_failures()
	await check_model("res://assets/units/aatrox/normal_view.tscn", "aatrox")
	await check_model("res://assets/units/sun_disc/sun_disc_blue_view.tscn", "sun_disc")
	pulse.set_phase("done", true)
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "models": reports}))
	await process_frame
	quit(0 if failures.is_empty() else 1)
