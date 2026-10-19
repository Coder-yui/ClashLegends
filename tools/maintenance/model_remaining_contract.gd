extends SceneTree
## 有限顺序模型合同，不建库存或启动战斗。
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
const OWNER = preload("res://scripts/presentation/model_animation_instance.gd")
const ORACLE = preload("res://tools/maintenance/model_remaining_oracle.gd")
const BUILDER = preload("res://tools/maintenance/model_template_builder.gd")
var pulse: RefCounted
var output := ""
var baseline := ""
var selected := ""
var checks := 0
var failures: Array[String] = []
var reports := {}
const SCENES := {
	"void_gate": "res://assets/units/void_gate/void_gate_view.tscn",
	"yorick": "res://assets/units/yorick/yorick_view.tscn",
	"kayle": "res://assets/units/kayle/melee_view.tscn",
	"kayle_ranged": "res://assets/units/kayle/ranged_view.tscn",
	"pantheon": "res://assets/units/pantheon/pantheon_view.tscn",
	"gnar_small": "res://assets/units/gnar/gnar_small_view.tscn",
	"gnar_mega": "res://assets/units/gnar/gnar_mega_view.tscn"}
func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--baseline="): baseline = arg.trim_prefix("--baseline=")
		if arg.begins_with("--select="): selected = arg.trim_prefix("--select=")
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func mesh_checks(id: String, subject: Node3D, old: Node3D, source: Node) -> void:
	var recipe_id := "kayle" if id == "kayle_ranged" else id
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/source_assets/model_recipes/" + recipe_id + ".json"))
	var source_mesh := source.find_child("Meshes", true, false) as MeshInstance3D
	if source_mesh == null: source_mesh = source.find_children("*", "MeshInstance3D", true, false)[0]
	var src := source_mesh.mesh as ArrayMesh
	var surfaces: Array = src.get("_surfaces")
	var report := {}
	for spec in recipe.mesh_filters:
		var mesh: ArrayMesh = subject.visual_template.meshes[spec.output]
		check(mesh.custom_aabb == src.custom_aabb and mesh.shadow_mesh == src.shadow_mesh and mesh.blend_shape_mode == src.blend_shape_mode and mesh.get_blend_shape_count() == src.get_blend_shape_count(), id + ": mesh properties " + spec.output)
		for shape in src.get_blend_shape_count(): check(mesh.get_blend_shape_name(shape) == src.get_blend_shape_name(shape), id + ": blendshape name")
		var kept := []
		for index in src.get_surface_count():
			var mat := src.surface_get_material(index)
			var label := String(mat.resource_name).to_lower() if mat != null else ""
			if spec.get("exclude_surfaces", []).any(func(value): return int(value) == index) or label in spec.get("exclude_materials", []).map(func(v): return String(v).to_lower()) or (spec.has("include_materials") and label not in spec.include_materials.map(func(v): return String(v).to_lower())): continue
			kept.append(index)
		check(mesh.get_surface_count() == kept.size(), id + ": exact surface selection " + spec.output)
		var outputs: Array = mesh.get("_surfaces")
		var lod_counts := []
		for index in kept.size():
			var original: Dictionary = surfaces[kept[index]].duplicate()
			var actual: Dictionary = outputs[index].duplicate()
			var old_material: Material = original.material
			var new_material: Material = actual.material
			original.erase("material"); actual.erase("material")
			if spec.has("hidden_bone"):
				var arrays := src.surface_get_arrays(kept[index])
				var bind := -1
				for slot in source_mesh.skin.get_bind_count():
					if String(source_mesh.skin.get_bind_name(slot)) == spec.hidden_bone: bind = slot
				var expected: Array = old._filter_bone_triangles(arrays, bind)
				check(ORACLE.equal(mesh.surface_get_arrays(index)[Mesh.ARRAY_INDEX], expected[Mesh.ARRAY_INDEX]), id + ": exact original triangle formula")
				var lods: Array = original.get("lods", [])
				var actual_lods: Array = actual.get("lods", [])
				check(lods.size() == actual_lods.size(), id + ": LOD count retained")
				var width := 2 if int(original.vertex_count) < 65536 else 4
				for lod in range(0, lods.size(), 2):
					var bytes: PackedByteArray = lods[lod + 1]
					var indices := PackedInt32Array()
					for offset in range(0, bytes.size(), width): indices.append(bytes.decode_u16(offset) if width == 2 else bytes.decode_u32(offset))
					arrays[Mesh.ARRAY_INDEX] = indices
					var filtered: Array = old._filter_bone_triangles(arrays, bind)
					check(actual_lods[lod] == lods[lod] and actual_lods[lod + 1] == BUILDER.encode_indices(filtered[Mesh.ARRAY_INDEX], width), id + ": LOD threshold and original formula " + str(lod / 2))
				for key in ["index_data", "index_count", "lods"]: original.erase(key); actual.erase(key)
			check(ORACLE.equal(original, actual), id + ": native vertex/skin/format/blendshape/AABB/LOD fields " + spec.output + str(index))
			var tex: String = spec.get("material_textures", {}).get(String(old_material.resource_name).to_lower(), "") if old_material != null else ""
			check(ORACLE.material_data(new_material) == ORACLE.material_data(old_material) if tex.is_empty() else new_material != old_material and new_material.albedo_texture.resource_path == tex, id + ": unchanged material ref or declared texture " + str(index))
			lod_counts.append(outputs[index].get("lods", []).size() / 2)
		report[spec.output] = {"kept_surfaces": kept, "lod_counts": lod_counts}
	if id == "void_gate": check(subject.visual_template.meshes.is_empty(), "VoidGate: no serialized source mesh or delta")
	reports[id] = {"meshes": report, "template_bytes": FileAccess.get_file_as_bytes(recipe.output).size()}
func private_checks(id: String, subject: Node3D, second: Node3D, old: Node3D) -> void:
	if id in ["yorick", "kayle", "kayle_ranged", "pantheon"]:
		var fresh := subject.find_children("*", "MeshInstance3D", true, false)
		var previous := old.find_children("*", "MeshInstance3D", true, false)
		check(fresh.size() == previous.size(), id + ": final mesh node count equals legacy")
		for index in mini(fresh.size(), previous.size()):
			check(fresh[index].skin == previous[index].skin and fresh[index].skeleton == previous[index].skeleton and fresh[index].transform == previous[index].transform and fresh[index].cast_shadow == previous[index].cast_shadow, id + ": node skin/transform/shadow equals legacy")
			for surface in fresh[index].mesh.get_surface_count():
				if id == "yorick" and fresh[index].name == "YorickCape":
					for layer in 2: old._cape_materials[layer].set_shader_parameter("uv_phase", subject._cape_materials[layer].get_shader_parameter("uv_phase"))
				check(ORACLE.material_chain(fresh[index].get_active_material(surface)) == ORACLE.material_chain(previous[index].get_active_material(surface)), id + ": complete private material chain equals legacy " + str(surface))
	if id == "void_gate":
		check(subject._spit_delta == second._spit_delta and subject._spit_delta != subject._animation.get_animation("Spit"), "VoidGate: shared imported delta separate from owned absolute Spit")
		subject._idle_age = 1.7; old._idle_age = 1.7
		subject._apply_additive_spit(0.35); old._apply_additive_spit(0.35)
		var same := true
		for index in subject._skeleton.get_bone_count(): same = same and subject._skeleton.get_bone_pose(index).is_equal_approx(old._skeleton.get_bone_pose(index))
		check(same and second._idle_age == 0.0, "VoidGate: live Idle phase delta pose equals original, independent clock")
		subject.reset_pool_visual(); check(subject._idle_age == 0.0, "VoidGate reset")
	if id == "yorick":
		check(subject._cape_path != second._cape_path and subject._weapon_blend != second._weapon_blend and subject._cape_materials[0] != second._cape_materials[0], "Yorick: modifiers and cape materials private")
		subject.advance_ambient_visual(0.4)
		check(subject._cape_materials[0].get_shader_parameter("age") == 0.4 and second._cape_materials[0].get_shader_parameter("age") == 0.0, "Yorick age independent")
		var phase: Variant = subject._cape_materials[0].get_shader_parameter("uv_phase")
		subject.reset_pool_visual()
		check(subject._age == 0.0 and subject._cape_materials[0].get_shader_parameter("uv_phase") != phase, "Yorick reset samples new private phase")
	if id.begins_with("kayle") or id == "pantheon":
		var materials: Array = subject._rage_materials if id == "pantheon" else subject._enrage_materials
		var other: Array = second._rage_materials if id == "pantheon" else second._enrage_materials
		check(materials.size() == other.size() and not materials.is_empty() and materials[0] != other[0], id + ": shader params private")
		if id == "pantheon": subject.advance_skill_resource_visual(true, 0.4)
		else: subject.advance_hit_haste_visual(true, 0.4)
		check(materials[0].get_shader_parameter("strength") > 0.0 and other[0].get_shader_parameter("strength") in [null, 0.0], id + ": rage isolated")
		if id == "pantheon":
			subject.update_animation_parts(&"Death", 77.0 / 30.0)
			check(subject._body_mesh.mesh == subject._death_mesh and second._body_mesh.mesh == second._living_mesh and subject._helmet_snap != second._helmet_snap, "Pantheon: frame77 and modifier private")
			check(subject._living_mesh != second._living_mesh and subject._living_mesh != subject.visual_template.meshes.living, "Pantheon: explicit private material mesh containers")
		subject.reset_pool_visual()
		check(float(materials[0].get_shader_parameter("strength")) == 0.0, id + ": reset rage")
	if id.begins_with("gnar"):
		subject.set_visual_clip(subject.filtered_clips[0])
		check(subject.is_filtered_clip_active() and not second.is_filtered_clip_active() and not subject.visual_template.meshes.has("full"), id + ": independent mesh choice, original not serialized")
		subject.reset_pool_visual(); check(not subject.is_filtered_clip_active() and subject._original_mesh == second._original_mesh, id + ": reset shared imported original")
func fixture_checks() -> void:
	pulse.set_phase("native-mesh-fixtures", true)
	var source := ArrayMesh.new()
	source.add_blend_shape("shape")
	source.custom_aabb = AABB(Vector3(-2, -3, -4), Vector3(6, 7, 8))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3(2, 0, 0), Vector3(3, 0, 0), Vector3(2, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([0.75,0.25,0,0, 0.75,0.25,0,0, 0.75,0.25,0,0, 0.49,0.51,0,0, 0.75,0.25,0,0, 0.75,0.25,0,0])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2, 3,4,5])
	var shape := []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = arrays[Mesh.ARRAY_VERTEX]
	shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape], {0.5: PackedInt32Array([3,4,5])})
	var result := BUILDER.process_bone_mesh(source, 0)
	check(result.errors.is_empty() and result.mesh != null, "fixture: native blendshape/LOD filtering accepted")
	if result.mesh != null:
		var mesh: ArrayMesh = result.mesh
		check(mesh.get_blend_shape_name(0) == "shape" and mesh.custom_aabb == source.custom_aabb and ORACLE.equal(mesh.surface_get_blend_shape_arrays(0), source.surface_get_blend_shape_arrays(0)), "fixture: blendshape and custom AABB retained")
		check(mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == PackedInt32Array([3,4,5]), "fixture: quantized .75 removes fully hidden triangle; .49 keeps mixed triangle")
		var a: Dictionary = source.get("_surfaces")[0].duplicate()
		var b: Dictionary = mesh.get("_surfaces")[0].duplicate()
		for key in ["index_data", "index_count", "lods"]: a.erase(key); b.erase(key)
		check(ORACLE.equal(a, b), "fixture: native packed channels unchanged")
	check(not BUILDER.process_bone_mesh(source, -1).errors.is_empty(), "fixture: unresolved bind rejected")
	source.shadow_mesh = ArrayMesh.new()
	check(not BUILDER.process_bone_mesh(source, 0).errors.is_empty(), "fixture: unknown shadow mapping rejected")
	check(BUILDER.encode_indices(PackedInt32Array([65535,65536]), 4).decode_u32(4) == 65536 and BUILDER.encode_indices(PackedInt32Array([65535]), 2).decode_u16(0) == 65535, "fixture: 16/32-bit native index width")

func consumer_checks() -> void:
	pulse.set_phase("actual-consumers", true)
	var plan: RefCounted = load("res://scripts/presentation/match_resource_plan.gd").for_match([["yorick", "kayle", "gnar", "void_gate"], ["freeze", "stasis"]], [{}, {}])
	check(plan.errors.is_empty() and plan.cards.has("kayle_ranged"), "consumer plan includes deployment upgrade closure")
	var specs := MatchModelPool.build_specs(plan.cards, plan)
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	camera.position = Vector3(0, 6, 12); camera.look_at(Vector3.ZERO); camera.current = true
	var count := 0
	for path in specs:
		if path not in SCENES.values() or path.contains("pantheon"): continue
		var use: Dictionary = specs[path][0]
		pulse.set_phase("consumer:" + String(use.id) + ":" + str(use.form), true)
		var states := MatchModelPool.material_states_for(specs[path], plan)
		var packed := load(path) as PackedScene
		var model: Node3D = packed.instantiate()
		model.set_meta("defer_animation_ownership", true)
		world.add_child(model); model.process_mode = Node.PROCESS_MODE_DISABLED
		var allowed := {}
		ModelVisualResources.collect_clip_names(use.stats.visual_animations, allowed)
		var resources := ModelVisualResources.new()
		var player := resources.bind_model(model, allowed, states)
		check(resources.errors.is_empty() and player != null, "real configuration clip closure prepares: " + path)
		if player == null:
			resources.clear(); model.free(); continue
		var initial := resources.material_creations.duplicate()
		model.set_meta("prepared_model_resources", resources)
		model.set_meta("prepared_animation_player", player)
		world.remove_child(model)
		var unit := Unit.new()
		unit.setup(int(use.team), use.stats, String(use.id)); unit.card_id = use.id; unit.form_index = use.form
		unit._deploy_timer = 0.0
		var view := UnitModel3D.new(); world.add_child(view); view.process_mode = Node.PROCESS_MODE_DISABLED
		view.material_states = states
		view.model_factory = func(_packed): return model
		check(view.setup(unit, packed, camera, use.stats.visual_animations, float(use.stats.get("visual_forward_yaw", 0.0)), String(use.stats.get("visual_active_buff_scene", ""))), "real UnitModel setup adopts prepared root: " + path)
		check(view._model_resources == resources and view._animation_player == player and not model.has_meta("prepared_model_resources"), "one owner handed off: " + path)
		resources.apply_overlays(true, true, false)
		resources.apply_overlays(false, false, false, true)
		resources.apply_overlays(false, false, false)
		check(resources.errors.is_empty() and resources.material_creations == initial, "real wrapper state transitions reuse prepared candidates: " + path)
		view._release_model(); view.free(); unit.free()
		count += 1
		await process_frame
	check(count == 6, "all six migrated source/form consumers attached sequentially")
	reports.consumers = {"count": count, "scope": "real model wrappers/UnitModel prepared adoption and material transitions; no inventory, authority battle or actual transformation command"}
	world.free()

func run() -> void:
	if not pulse.enabled or output.is_empty(): quit(2); return
	if "--compile-render" in OS.get_cmdline_user_args():
		pulse.set_phase("compile-render", true)
		var script := load("res://tools/maintenance/model_remaining_render.gd") as Script
		check(script != null and script.can_instantiate(), "remaining renderer compiles")
	elif "--consumers-only" in OS.get_cmdline_user_args():
		await consumer_checks()
	else:
		if baseline.is_empty(): quit(2); return
		if selected.is_empty(): fixture_checks()
		for id in SCENES:
			if not selected.is_empty() and id not in selected.split(","): continue
			pulse.set_phase("contracts:" + id, true)
			if id == "pantheon":
				var path := "assets/units/pantheon/pantheon_view.gd"
				check(FileAccess.get_sha256("res://" + path) == FileAccess.get_sha256(baseline.path_join(path)), "Pantheon: formal wrapper restored exactly to batch baseline")
				reports[id] = {"status": "retained", "reason": "14 strict pixels unresolved; candidate retained outside runtime assets", "wrapper_sha256": FileAccess.get_sha256("res://" + path)}
				continue
			var subject: Node3D = load(SCENES[id]).instantiate()
			root.add_child(subject); subject.process_mode = Node.PROCESS_MODE_DISABLED
			subject.prepare_visual_animations()
			var old := ORACLE.legacy(SCENES[id], baseline)
			check(old != null, id + ": baseline compiles")
			if old == null: subject.free(); continue
			root.add_child(old); old.process_mode = Node.PROCESS_MODE_DISABLED
			var second: Node3D = load(SCENES[id]).instantiate()
			root.add_child(second); second.process_mode = Node.PROCESS_MODE_DISABLED
			var owner: RefCounted = subject.get_meta(OWNER.SLOT, null)
			if owner == null:
				check(false, id + ": missing root ownership " + str(subject.preparation_errors) + " defer=" + str(subject.get_meta("defer_animation_ownership", false)))
				subject.free(); second.free(); old.free()
				continue
			check(subject.preparation_errors.is_empty() and owner.errors.is_empty() and owner.complete, id + ": generated ownership complete")
			var player: AnimationPlayer = subject.find_child("AnimationPlayer", true, false)
			var previous: AnimationPlayer = old.find_child("AnimationPlayer", true, false)
			for clip in player.get_animation_list(): check(previous.has_animation(clip) and ORACLE.equal(ORACLE.animation_data(player.get_animation(clip)), ORACLE.animation_data(previous.get_animation(clip))), id + ": complete animation data " + String(clip))
			check(player.get_animation(player.get_animation_list()[0]) != second.get_meta(OWNER.SLOT).player.get_animation(player.get_animation_list()[0]) and subject.visual_template == second.visual_template, id + ": private animation shared template")
			var recipe_id: String = "kayle" if id == "kayle_ranged" else id
			var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/source_assets/model_recipes/" + recipe_id + ".json"))
			var source: Node = load(recipe.source).instantiate()
			mesh_checks(id, subject, old, source)
			private_checks(id, subject, second, old)
			var count: int = owner.copied_animations
			subject.prepare_visual_animations()
			check(subject.get_meta(OWNER.SLOT) == owner and owner.copied_animations == count and owner.errors.is_empty(), id + ": repeated prepare does not recopy")
			source.free(); subject.free(); second.free(); old.free()
			await process_frame
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "models": reports}, "\t")); file.close()
	quit(0 if failures.is_empty() else 1)
