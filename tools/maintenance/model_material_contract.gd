extends SceneTree
## 本批小合同：合成材质夹具及逐模型两实例，不启动战斗或建库存。
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
const OWNER = preload("res://scripts/presentation/model_animation_instance.gd")
var pulse: RefCounted
var output := ""
var failures: Array[String] = []
var checks := 0
var reports := {}

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func material_fixture() -> Node3D:
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var original := StandardMaterial3D.new()
	original.albedo_color = Color(0.1, 0.2, 0.3)
	mesh.set_surface_override_material(0, original)
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_overlay = StandardMaterial3D.new()
	model.add_child(mesh)
	return model

func material_checks() -> void:
	var model := material_fixture()
	var mesh := model.get_child(0) as MeshInstance3D
	var original := mesh.get_surface_override_material(0)
	var override := mesh.material_override
	var overlay := mesh.material_overlay
	var shadow := mesh.cast_shadow
	var owner := ModelVisualResources.new()
	owner.bind_model(model, {}, ModelVisualResources.tool_material_states())
	check(owner._surface_ghosts.is_empty() and not owner._frost_prepared and owner._overlays[0][2] == overlay and owner._overlays[0][5] == overlay, "unreachable: no ghost/frost candidates; six slots preserve base aliases")
	check(owner._surface_originals[0][0] == original and owner._override_originals[0] == override, "original material snapshot retained")
	owner.apply_overlays(true, true, false)
	check(mesh.material_overlay == owner._overlays[0][1] and owner._frost_prepared, "hit takes precedence while reachable freeze prepared")
	owner.apply_overlays(false, true, false)
	check(mesh.material_overlay.albedo_color == Color(0.3, 0.7, 1.0, 0.28) and mesh.material_overlay.next_pass == overlay and owner._overlays[0][5] == owner._overlays[0][2], "ordinary freeze equals legacy tint; buff aliases base")
	var tint := mesh.material_overlay
	owner.apply_overlays(false, false, false, false, true)
	check(mesh.material_override == null and mesh.get_surface_override_material(0) != original and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "late stealth request creates private ghost and switches")
	var ghost := mesh.get_surface_override_material(0)
	owner.apply_overlays(false, false, false)
	check(mesh.material_override == override and mesh.get_surface_override_material(0) == original and mesh.cast_shadow == shadow, "stealth exit restores all original references/shadow")
	owner.apply_overlays(false, false, false, false, true)
	check(mesh.get_surface_override_material(0) == ghost and owner._overlays[0][2] == tint, "repeat states reuse candidates")
	owner.clear()
	check(mesh.material_override == override and mesh.get_surface_override_material(0) == original and mesh.material_overlay == overlay, "clear while hidden restores original snapshot")
	model.free()
	model = material_fixture()
	mesh = model.get_child(0) as MeshInstance3D
	owner.bind_model(model, {}, {"mode": "tool", "freeze": true, "building": true, "stealth": true})
	check(owner._frost_prepared and owner._surface_ghosts.size() == 1 and owner._overlays[0][2] is ShaderMaterial, "known reachable building freeze/stealth eagerly prepared")
	owner.configure_buff(func(base):
		var buff := StandardMaterial3D.new()
		buff.next_pass = base
		return buff)
	check(owner._overlays[0][2].next_pass == owner._originals[0] and owner._overlays[0][5].next_pass == owner._buffs[0] and owner._overlays[0][2] != owner._overlays[0][5], "buff rebuild keeps frost chains distinct")
	mesh.set_meta("exclude_hit_flash", true)
	owner.apply_overlays(true, true, true)
	check(mesh.material_overlay == owner._overlays[0][5], "excluded hit-flash mesh still freezes with buff")
	owner.reset_overlays()
	check(owner._buffs.is_empty() and owner._overlays[0][5] == owner._overlays[0][2], "recycle clears buff and preserves reachable frost alias")
	owner.clear()
	owner.bind_model(model, {}, ModelVisualResources.tool_material_states())
	owner.apply_overlays(false, true, false, true)
	check(owner._gold != null and not owner._frost_prepared, "stasis consumes gold without unreachable ordinary freeze candidate")
	owner.clear()
	model.free()
	var plan: RefCounted = load("res://scripts/presentation/match_resource_plan.gd").for_match([["mirror", "freeze", "twitch", "kayn", "belveth"], ["stasis", "azir"]], [{}, {}])
	var specs := MatchModelPool.build_specs(plan.cards, plan)
	check(plan.errors.is_empty() and plan.target_states.has("freeze") and plan.target_states.has("stasis") and plan.cards.has("voidfish") and plan.cards.has("sand_soldier") and plan.cards.has("sun_disc") and plan.cards.has("kayn_assassin") and plan.cards.has("kayn_slayer"), "plan: mirror/forms/summons/conversion/revival closure retained")
	var fish := MatchModelPool.material_states_for(specs["res://assets/units/voidfish/voidfish_view.tscn"], plan)
	var twitch := MatchModelPool.material_states_for(specs["res://assets/units/twitch/twitch_view.tscn"], plan)
	check(fish.freeze and not fish.stealth and twitch.freeze and twitch.stealth, "target freeze reaches descendants; stealth stays with actual capability")
	plan = load("res://scripts/presentation/match_resource_plan.gd").for_match([["stasis", "anivia"], ["ornn"]], [{}, {}])
	check(not MatchModelPool.material_states_for([], plan).freeze and plan.cards.has("anivia_egg"), "stasis-only has no ordinary frost; death replacement/revival remains closed")

func same_arrays(a: Array, b: Array) -> bool:
	return var_to_bytes(a) == var_to_bytes(b)

func animation_data(animation: Animation) -> Array:
	var result := [animation.length, animation.loop_mode, animation.step, animation.resource_name]
	for track in animation.get_track_count():
		var values := [animation.track_get_type(track), animation.track_get_path(track), animation.track_get_interpolation_type(track), animation.track_get_interpolation_loop_wrap(track), animation.track_is_enabled(track), animation.track_is_imported(track)]
		for key in animation.track_get_key_count(track):
			values.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key), animation.track_get_key_transition(track, key)])
		result.append(values)
	return result

func material_data(material: Material) -> Dictionary:
	var result := {}
	if material == null: return result
	for property in material.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name in ["resource_path", "resource_scene_unique_id"]: continue
		var value: Variant = material.get(property.name)
		result[property.name] = value.resource_path if value is Resource else value
	return result

func geometry_checks(id: String) -> void:
	pulse.set_phase("geometry:" + id, true)
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/source_assets/model_recipes/" + id + ".json"))
	var source: Node = load(recipe.source).instantiate()
	var original := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var generated: Node3D = load("res://assets/units/" + id + "/" + id + "_view.tscn").instantiate()
	root.add_child(generated)
	generated.process_mode = Node.PROCESS_MODE_DISABLED
	var template: Resource = generated.visual_template
	var spec: Dictionary = recipe.mesh_filters[0] if not recipe.mesh_filters.is_empty() else {"exclude_materials": []}
	var filtered: ArrayMesh = template.meshes[spec.output] if spec.has("output") else original.mesh
	var src := original.mesh as ArrayMesh
	var kept := []
	for index in src.get_surface_count():
		var material := src.surface_get_material(index)
		if material == null or String(material.resource_name).to_lower() not in spec.exclude_materials: kept.append(index)
	check(filtered.get_surface_count() == kept.size() and (kept.size() < src.get_surface_count() if id != "voidfish" else template.meshes.is_empty()), id + ": exact kept surface count")
	check(filtered.get_blend_shape_count() == src.get_blend_shape_count() and filtered.blend_shape_mode == src.blend_shape_mode and filtered.custom_aabb == src.custom_aabb and filtered.shadow_mesh == src.shadow_mesh, id + ": blendshape/AABB/shadow properties preserved")
	for index in filtered.get_blend_shape_count(): check(filtered.get_blend_shape_name(index) == src.get_blend_shape_name(index), id + ": blendshape name")
	for index in kept.size():
		var old: int = kept[index]
		check(filtered.surface_get_format(index) == src.surface_get_format(old) and filtered.surface_get_name(index) == src.surface_get_name(old) and filtered.surface_get_primitive_type(index) == src.surface_get_primitive_type(old) and same_arrays(filtered.surface_get_arrays(index), src.surface_get_arrays(old)) and same_arrays(filtered.surface_get_blend_shape_arrays(index), src.surface_get_blend_shape_arrays(old)) and filtered.get("_surfaces")[index].get("lods", {}) == src.get("_surfaces")[old].get("lods", {}), id + ": full surface data " + str(index))
		var material := filtered.surface_get_material(index)
		var previous := src.surface_get_material(old)
		if id == "belveth" and String(previous.resource_name).to_lower() == "body":
			check(material.albedo_texture.resource_path == "res://assets/units/belveth/source/ultimate_body.png" and material != previous, id + ": static ultimate texture cloned once")
		else: check(material_data(material) == material_data(previous), id + ": material values preserved across template serialization " + str(index))
	var player: AnimationPlayer = generated.get_meta(OWNER.SLOT).player
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in player.get_animation_list():
		check(same_arrays(animation_data(player.get_animation(clip)), animation_data(source_player.get_animation(clip))), id + ": source animation unchanged " + String(clip))
	var mesh := generated.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	check(mesh.skin == original.skin and mesh.skeleton == original.skeleton and mesh.transform == original.transform, id + ": skin/node transform/bone path unchanged")
	reports[id] = {"source_surfaces": src.get_surface_count(), "source_mesh_reused": template.meshes.is_empty(), "kept_surfaces": kept, "clips": Array(player.get_animation_list()), "shadow_mesh": src.shadow_mesh != null, "custom_aabb": str(src.custom_aabb), "template_bytes": FileAccess.get_file_as_bytes(recipe.output).size()}
	if id == "voidfish": check(mesh.mesh == original.mesh, "voidfish: already-final imported mesh reused without serialized copy")
	source.free()
	var second: Node3D = load("res://assets/units/" + id + "/" + id + "_view.tscn").instantiate()
	root.add_child(second)
	second.process_mode = Node.PROCESS_MODE_DISABLED
	var other_player: AnimationPlayer = second.get_meta(OWNER.SLOT).player
	var clip := player.get_animation_list()[0]
	var own := player.get_animation(clip)
	check(own != other_player.get_animation(clip) and generated.visual_template == second.visual_template, id + ": private animation/shared immutable template")
	if id == "sion":
		generated.set_visual_form(1)
		check(mesh.mesh == filtered and second._mesh.mesh == second._full and not template.meshes.has("full"), "sion: berserk instance independent; full mesh only source reference")
		generated.reset_pool_visual()
		generated.set_visual_clip("Passive_Death")
		player.play("Passive_Death")
		player.seek(23.0 / 30.0, true)
		generated._update_weapon()
		check(mesh.mesh == filtered, "sion: passive death frame23 selects unarmed")
		generated.reset_pool_visual()
		check(mesh.mesh == generated._full and generated._full == second._full, "sion: pool reset restores shared imported full")
	if id.begins_with("voidfish"):
		generated._spawn_started = true
		generated._spawn_age = 0.5
		generated.reset_pool_visual()
		check(not generated._spawn_started and generated._spawn_age == 0.0 and not second._spawn_started, id + ": deployment state/reset independent")
	generated.free()
	second.free()

func run() -> void:
	if not pulse.enabled or output.is_empty(): quit(2); return
	if "--compile-render" in OS.get_cmdline_user_args():
		pulse.set_phase("compile-render", true)
		var script := load("res://tools/maintenance/model_material_render.gd") as Script
		check(script != null and script.can_instantiate(), "batch2 renderer compiles")
		var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
		file.close()
		quit(0 if failures.is_empty() else 1)
		return
	pulse.set_phase("materials", true)
	material_checks()
	for id in [] if "--materials-only" in OS.get_cmdline_user_args() else ["ornn", "belveth", "sion", "voidfish", "voidfish_ranged"]:
		geometry_checks(id)
		await process_frame
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "models": reports}, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)
