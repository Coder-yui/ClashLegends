extends RefCounted
const PLAN = preload("res://scripts/presentation/match_resource_plan.gd")
const WARMUP = preload("res://scripts/presentation/spell_effect_warmup.gd")

func count_for(plan: RefCounted, id: String, team: int) -> int:
	var ledger: RefCounted = MatchModelPool.DEMAND.build(plan.cards, plan)
	var path := PresentationConfig.scene_path(CardDB.get_card(id), team)
	var count := 0
	for source in ledger.policy_paths.get(path, {}).get("sources", []):
		if source.team == team: count += int(source.quantity)
	return count

func run(harness: Object) -> void:
	_declaration_contracts(harness)
	var groups := ["minion_squad", "melee_minion_squad", "ranged_minion_squad", "heavy_minion_squad", "super_minion_squad", "siege_minion_squad"]
	var plan: RefCounted = PLAN.for_match([groups, []], [{}, {}])
	var expected := {"melee_minion": 18, "ranged_minion": 16, "super_minion": 10, "siege_minion": 12}
	for id in expected:
		harness._expect(count_for(plan, id, 0) == expected[id], "六编队两次部署成员与独立两波兵线相加：" + id)
		harness._expect(count_for(plan, id, 1) == 4, "敌方只有系统兵线，不继承本方编队预算：" + id)
	var ordinary: RefCounted = PLAN.for_match([["tombstone"], ["garen"]], [{}, {}])
	var mirrored: RefCounted = PLAN.for_match([["mirror", "tombstone"], ["garen"]], [{}, {}])
	harness._expect(count_for(mirrored, "imp", 0) == 2 * count_for(ordinary, "imp", 0), "镜像仍扩大本方召唤物库存")
	harness._expect(count_for(mirrored, "garen", 1) == count_for(ordinary, "garen", 1), "镜像不扩大敌方英雄库存")
	for id in MatchResources.SYSTEM_UNIT_BUDGET:
		for team in 2:
			harness._expect(count_for(mirrored, id, team) == 4, "镜像不扩大自动兵线库存：%s/%d" % [id, team])
	var both: RefCounted = PLAN.for_match([["tombstone"], ["tombstone"]], [{}, {}])
	harness._expect(count_for(both, "imp", 0) == count_for(both, "imp", 1) and count_for(both, "imp", 0) == count_for(ordinary, "imp", 0), "双方相同召唤来源分别计算，共享模型路径只在最终合并容量")
	# Small in-tree geometry: no imported game models, particles or forced draw.
	var world := Node3D.new()
	harness.root.add_child(world)
	var node := MeshInstance3D.new()
	var box := ArrayMesh.new()
	box.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().surface_get_arrays(0))
	node.mesh = box
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform float opacity = 1.0; void fragment() { ALBEDO = vec3(opacity); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material_override = material
	world.add_child(node)
	var first := WARMUP.visible_shader_resources(world)
	harness._expect(first.size() == 1 and not first.has("force"), "可见Shader材质及网格进入绘制资源集合")
	material.set_shader_parameter("opacity", 0.5)
	harness._expect(WARMUP.visible_shader_resources(world) == first, "同一资源的粒子参数变化保留相同管线身份")
	node.material_override = material.duplicate()
	harness._expect(WARMUP.visible_shader_resources(world) != first, "新粒子独立材质必须再次绘制")
	node.material_override = material
	var alternative_shader := Shader.new()
	alternative_shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(0.0); }"
	material.shader = alternative_shader
	harness._expect(WARMUP.visible_shader_resources(world) != first, "同材质切换Shader资源必须重新绘制")
	material.shader = shader
	material.next_pass = ShaderMaterial.new()
	harness._expect(WARMUP.visible_shader_resources(world).has("force"), "多遍材质保守逐采样绘制")
	material.next_pass = null
	node.mesh = ImmediateMesh.new()
	harness._expect(WARMUP.visible_shader_resources(world).has("force"), "同RID内更新顶点的ImmediateMesh拖尾逐采样绘制")
	node.mesh = BoxMesh.new()
	harness._expect(WARMUP.visible_shader_resources(world).has("force"), "可变PrimitiveMesh保守逐采样绘制")
	var sphere := ArrayMesh.new()
	sphere.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, SphereMesh.new().surface_get_arrays(0))
	node.mesh = sphere
	harness._expect(WARMUP.visible_shader_resources(world) != first, "新网格必须绘制")
	node.hide()
	harness._expect(WARMUP.visible_shader_resources(world).is_empty(), "隐藏层不冒充已绘制资源")
	node.show()
	node.material_override = StandardMaterial3D.new()
	harness._expect(WARMUP.visible_shader_resources(world).has("force"), "未知/标准材质不推断管线等价")
	var polygon := Polygon2D.new()
	harness._expect(WARMUP.visible_shader_resources(polygon).has("force"), "2D采样保留全部绘制")
	polygon.free()
	world.free()

## 新卡静态门禁：定义全部形态/阵营与死亡替身须声明构造能力，不加载全库模型。
func _declaration_contracts(harness: Object) -> void:
	var paths := {}
	for base in CardDB.all().values():
		for form in range(2 if base.has("transformed_stats") else 1):
			var stats := PresentationConfig.for_form(base, form)
			for team in 2:
				var path := PresentationConfig.scene_path(stats, team)
				if not path.is_empty(): paths[path] = true
			var followup := String(stats.get("visual_animations", {}).get("death_followup_scene_path", ""))
			if not followup.is_empty(): paths[followup] = true
	for path in paths:
		var value: Variant = null
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("metadata/model_pool_construction = "): value = str_to_var(line.trim_prefix("metadata/model_pool_construction = "))
		harness._expect(MatchModelPool.valid_construction_declaration(value), "模型构造声明schema：" + path)
		if value is Dictionary:
			for script_path in value.get("scripts", []): harness._expect(FileAccess.file_exists(script_path), "声明构造脚本存在：" + script_path)
	harness._expect(not MatchModelPool.valid_construction_declaration({}) and not MatchModelPool.valid_construction_declaration({"version": 2, "mode": "step-bind", "scripts": []}) and not MatchModelPool.valid_construction_declaration({"version": 1, "mode": "unknown", "scripts": []}), "缺失/未知版本/不支持构造能力显式拒绝")
