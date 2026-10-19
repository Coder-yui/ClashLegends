extends RefCounted
## 现有 resources --write 的模型加工步骤。只实例化离树源模型，不执行包装器。
const TEMPLATE = preload("res://scripts/presentation/model_visual_template.gd")
const COPY = preload("res://scripts/presentation/model_animation_copy.gd")
const OPS = preload("res://tools/maintenance/model_animation_ops.gd")
const RECIPE_DIR := "res://tools/source_assets/model_recipes"

static func generate(pulse: RefCounted, tree: SceneTree, errors: PackedStringArray, dirty_recipes: Array) -> Dictionary:
	var artifacts := {}
	var reports := {}
	for filename in DirAccess.get_files_at(RECIPE_DIR):
		if not filename.ends_with(".json"): continue
		if filename not in dirty_recipes: continue
		pulse.set_phase("model-template:" + filename)
		var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECIPE_DIR.path_join(filename)))
		if recipe.get("schema") != 1:
			errors.append("Unknown model recipe schema: " + filename)
			continue
		var packed := load(recipe.source) as PackedScene
		if packed == null:
			errors.append("Missing model recipe source: " + filename)
			continue
		var root := packed.instantiate()
		var template := TEMPLATE.new()
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player == null:
			errors.append("Model recipe requires AnimationPlayer: " + filename)
			root.free()
			continue
		var needed := {}
		# 同一模型的全部已声明形态构成clip闭包，不能按当前形态裁剪。
		for card in recipe.cards:
			var stats := CardDB.get_card(card)
			for form in range(2 if stats.has("transformed_stats") else 1):
				ModelVisualResources.collect_clip_names(PresentationConfig.for_form(stats, form).get("visual_animations", {}), needed)
		for clip in recipe.get("extra_clips", []): needed[clip] = true
		for name in player.get_animation_library_list():
			var library := COPY.copy_library(player.get_animation_library(name))
			for operation in recipe.animation_operations:
				match operation.kind:
					"reset_root_position":
						var target := player.get_node(player.root_node).get_path_to(root)
						for clip in library.get_animation_list():
							var animation := library.get_animation(clip)
							var track := animation.add_track(Animation.TYPE_POSITION_3D)
							animation.track_set_path(track, target)
							animation.position_track_insert_key(track, 0.0, Vector3.ZERO)
					"alias_root_position":
						if not library.has_animation(operation.source):
							errors.append("Missing source clip: " + String(operation.source))
							continue
						var animation := COPY.copy_animation(library.get_animation(operation.source))
						var target := player.get_node(player.root_node).get_path_to(root)
						var track := animation.find_track(target, Animation.TYPE_POSITION_3D)
						animation.track_set_key_value(track, 0, Vector3(0, operation.height, 0))
						library.add_animation(operation.output, animation)
					"filter_bones":
						for clip in operation.clips:
							if not library.has_animation(clip):
								errors.append("Missing masked clip: " + String(clip))
								continue
							var animation := library.get_animation(clip)
							for track in range(animation.get_track_count() - 1, -1, -1):
								if String(animation.track_get_path(track).get_concatenated_subnames()) not in operation.bones: animation.remove_track(track)
					"clip_settings":
						var clip: Animation = library.get_animation(operation.clip)
						if clip == null: errors.append("Missing settings clip: " + String(operation.clip))
						else:
							clip.length = float(operation.length)
							if operation.has("loop_mode"): clip.loop_mode = int(operation.loop_mode)
					"absolute_delta":
						if not library.has_animation(operation.clip) or not library.has_animation(operation.base): errors.append("Missing absolute delta clip")
						else: OPS.absolute_delta(library.get_animation(operation.clip), library.get_animation(operation.base), player.get_animation(operation.clip))
					_:
						errors.append("Unknown model animation operation: " + String(operation.kind))
			for clip in library.get_animation_list():
				var full := String(clip) if String(name).is_empty() else String(name) + "/" + String(clip)
				if clip != &"RESET" and not needed.has(full): library.remove_animation(clip)
			template.libraries[name] = library
		for operation in recipe.get("composed_animations", []):
			var scale := player.get_animation(operation.scale)
			var base := player.get_animation(operation.base)
			var pose := player.get_animation(operation.pose)
			if scale == null or base == null or pose == null:
				errors.append("Missing composed animation input: " + filename)
				continue
			var name: String = operation.library
			if not template.libraries.has(name): template.libraries[name] = AnimationLibrary.new()
			template.libraries[name].add_animation(operation.output, OPS.compose_animation(scale, base, pose, operation.get("scale_start_overrides", {})))
		for spec in recipe.get("mesh_filters", []):
			var instance := (root.get_node_or_null(NodePath(spec.node)) if String(spec.node).contains("/") else root.find_child(spec.node, true, false)) as MeshInstance3D
			if instance == null or not instance.mesh is ArrayMesh:
				errors.append("Missing mesh source: " + filename + ":" + String(spec.node))
				continue
			var processed: Dictionary
			if spec.has("hidden_bone"):
				var bind := -1
				if instance.skin != null:
					for index in instance.skin.get_bind_count():
						if String(instance.skin.get_bind_name(index)) == spec.hidden_bone: bind = index
				processed = process_bone_mesh(instance.mesh as ArrayMesh, bind)
			else: processed = process_mesh(instance.mesh as ArrayMesh, spec)
			errors.append_array(processed.errors)
			if processed.mesh != null: template.meshes[spec.output] = processed.mesh
		var clips := {}
		for name in template.libraries:
			clips[name] = Array(template.libraries[name].get_animation_list())
		if errors.is_empty():
			var destination: String = recipe.output
			DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
			var status := ResourceSaver.save(template, destination, ResourceSaver.FLAG_COMPRESS)
			if status != OK: errors.append("Cannot save model template: " + destination)
			else:
				artifacts[destination.trim_prefix("res://")] = FileAccess.get_sha256(destination)
				reports[filename] = {"source": recipe.source, "output": destination, "clips": clips, "meshes": template.meshes.keys()}
		root.free()
		await tree.process_frame
	return {"artifacts": artifacts, "models": reports}

## 无变化不输出mesh键，消费者继续引用导入源；未知影子拓扑不默默沿用。
static func process_mesh(source: ArrayMesh, spec: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var removed := []
	var replacements := {}
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		var label := String(material.resource_name).to_lower() if material != null else ""
		if spec.get("exclude_surfaces", []).any(func(value): return int(value) == surface) or (spec.has("include_materials") and not spec.include_materials.any(func(value): return String(value).to_lower() == label)) or spec.get("exclude_materials", []).any(func(value): return String(value).to_lower() == label):
			removed.append(surface)
			continue
		var texture: String = spec.get("material_textures", {}).get(label, "")
		if not texture.is_empty():
			if not material is BaseMaterial3D:
				errors.append("Texture replacement requires BaseMaterial3D: " + label)
				continue
			var loaded := load(texture) as Texture2D
			if loaded == null:
				errors.append("Invalid mesh replacement texture: " + texture)
			elif material.albedo_texture != loaded: replacements[surface] = loaded
	if not errors.is_empty(): return {"mesh": null, "errors": errors}
	if removed.is_empty() and replacements.is_empty(): return {"mesh": null, "errors": errors}
	if source.shadow_mesh != null:
		errors.append("Mesh processing requires explicit non-empty shadow_mesh mapping")
		return {"mesh": null, "errors": errors}
	var result := source.duplicate(false) as ArrayMesh
	for surface in replacements:
		var material := source.surface_get_material(surface).duplicate(false) as BaseMaterial3D
		material.albedo_texture = replacements[surface]
		result.surface_set_material(surface, material)
	for index in range(removed.size() - 1, -1, -1): result.surface_remove(removed[index])
	return {"mesh": result, "errors": errors}

## 只改原生索引字节；压缩顶点、蒙皮、blendshape、AABB和其余surface字段原样保留。
## 所有LOD用与主表面相同的四权重公式；未知布局显式拒绝，不能默默丢LOD。
static func process_bone_mesh(source: ArrayMesh, bind: int) -> Dictionary:
	var errors := PackedStringArray()
	if bind < 0 or source.shadow_mesh != null:
		errors.append("Bone filter requires resolved bind and explicit shadow topology mapping")
		return {"mesh": null, "errors": errors}
	var surfaces: Array = source.get("_surfaces").duplicate(true)
	for index in source.get_surface_count():
		var arrays := source.surface_get_arrays(index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var surface: Dictionary = surfaces[index]
		var width := 2 if vertices.size() < 65536 else 4
		if source.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES or bones.size() != vertices.size() * 4 or weights.size() != bones.size() or surface.index_data.size() != int(surface.index_count) * width or int(surface.index_count) % 3 != 0:
			errors.append("Bone filter requires indexed triangles and original four-influence layout")
			continue
		var kept := OPS.filter_bone_indices(arrays[Mesh.ARRAY_INDEX], bones, weights, bind)
		if kept.is_empty():
			errors.append("Bone filter refuses empty surface; explicit removal required")
			continue
		surface.index_count = kept.size()
		surface.index_data = encode_indices(kept, width)
		var lods: Array = surface.get("lods", [])
		if lods.size() % 2 != 0:
			errors.append("Unknown native LOD layout")
			continue
		var filtered_lods := []
		for lod in range(0, lods.size(), 2):
			var bytes: PackedByteArray = lods[lod + 1]
			if bytes.size() % (3 * width) != 0:
				errors.append("Invalid native LOD indices")
				continue
			var indices := PackedInt32Array()
			for offset in range(0, bytes.size(), width): indices.append(bytes.decode_u16(offset) if width == 2 else bytes.decode_u32(offset))
			var selected := OPS.filter_bone_indices(indices, bones, weights, bind)
			if selected.is_empty():
				errors.append("Bone filter requires explicit empty LOD policy")
				continue
			filtered_lods.append_array([lods[lod], encode_indices(selected, width)])
		surface.lods = filtered_lods
	if not errors.is_empty(): return {"mesh": null, "errors": errors}
	var result := source.duplicate(false) as ArrayMesh
	result.clear_surfaces()
	result.set("_surfaces", surfaces)
	return {"mesh": result, "errors": errors}

static func encode_indices(indices: PackedInt32Array, width: int) -> PackedByteArray:
	if width == 4: return indices.to_byte_array()
	var bytes := PackedByteArray()
	bytes.resize(indices.size() * 2)
	for index in indices.size(): bytes.encode_u16(index * 2, indices[index])
	return bytes
