extends "res://tests/suites/battle_suite.gd"
const WARMUP = preload("res://scripts/presentation/spell_effect_warmup.gd")

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	await _selection_boundaries()
	_declaration_contract()
	var cards := {"anivia": true, "sion": true, "aurelionsol": true, "kayle_ranged": true, "gwen": true, "tristana": true, "sun_disc": true, "lightning": true, "zap": true, "stasis": true, "explosive_cask": true}
	var resources := MatchResources.new()
	resources.prepare(cards.keys())
	_expect(resources.errors.is_empty(), "调整后的法术资源完整加载")
	var paths := WARMUP.dependency_paths(cards)
	_expect(paths.size() > 20, "JSON内部纹理依赖纳入收集")
	for path in paths: _expect(resources.resources.has(path), "本局强引用法术依赖：" + path)
	_expect(WARMUP.dependency_paths({"garen": true}).is_empty(), "非本局法术不额外收集")
	var presentation: BattlePresentation3D = main._battle_presentation
	var warm = WARMUP.new()
	var child_count := presentation._world_root.get_child_count()
	var viewport_children := presentation._viewport.get_child_count()
	var event_id: int = main._presentation_event_id
	await warm.prepare(cards, presentation._world_root, presentation._camera)
	_expect(warm.prepared.size() == cards.size() and not warm.retained.is_empty(), "法术与烈阳技能播放器完成绘制准备并保留资源")
	_expect(presentation._world_root.get_child_count() == child_count, "预热样本清理无残留节点")
	_expect(main._presentation_event_id == event_id and main._spell_system.stasis_effects.is_empty() and main._spell_system.cask_effects.is_empty() and main._skill_presentation.shield_effects.is_empty(), "预热不发布战斗事件或权威法术")
	_expect(presentation._viewport.get_child_count() == viewport_children, "天使2D预热样本清理无残留")
	var failures := PackedStringArray()
	for request in WARMUP.MANIFEST.requests(cards, null, CardDB.all()):
		var manifest: Dictionary = WARMUP.MANIFEST.resolve(request, failures)
		if not manifest.has("sample"): continue
		var recipe: Dictionary = manifest.sample
		var player: Script = load(recipe.player)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest.json[0]))
		var expected := 0
		for layer in data.emitters.size():
			if player.has_method("layer_enabled") and not player.layer_enabled(recipe.kind, String(data.emitters[layer].name)): continue
			var minimum := 2 if data.emitters[layer].get("trail") != null else 1
			if data.frames.any(func(frame): return frame[layer].size() >= minimum): expected += 1
		var key: String = request.card + "/" + recipe.kind
		_expect(int(warm.sampled_layers.get(key, -1)) == expected, "原版层逐层完成预热：" + key)
	_expect(failures.is_empty(), "效果声明全部可解析")
	var retained_count: int = warm.retained.size()
	await warm.prepare(cards, presentation._world_root, presentation._camera)
	_expect(warm.retained.size() == retained_count, "重复准备不重建粒子资源")
	var partial = WARMUP.new()
	var calls := [0]
	await partial.prepare({"anivia":true}, presentation._world_root, presentation._camera, func(): calls[0] += 1; return calls[0] > 4)
	_expect(partial.prepared.is_empty() and presentation._viewport.get_child_count() == viewport_children and presentation._world_root.get_child_count() == child_count, "采样中途取消清理2D/3D节点且不标为完成")
	var cancelled = WARMUP.new()
	await cancelled.prepare(cards, presentation._world_root, presentation._camera, func(): return true)
	_expect(cancelled.prepared.is_empty() and cancelled.retained.is_empty(), "取消加载不创建预热资源")

func _selection_boundaries() -> void:
	var planner = load("res://scripts/presentation/match_resource_plan.gd")
	var blue := ["gwen", "tristana", "sion", "anivia", "freeze", "sun_disc", "aatrox", "mirror"]
	var red := ["gwen", "nocturne", "kayle", "jinx", "darius", "tombstone", "gnar", "garen"]
	var plan: RefCounted = planner.for_match([blue, red], [{"gwen": 0}, {"gwen": 1, "nocturne": 1}])
	_expect(plan.allows("gwen", 0) and plan.allows("gwen", 1), "双方同卡不同技能取并集")
	_expect(not plan.allows("sion") and not plan.allows("freeze"), "普通槽镜像不扩展任何技能")
	_expect(plan.cards.has("kayle_ranged") and plan.cards.has("anivia_egg") and plan.cards.has("imp"), "升级、死亡替身与召唤物闭包保留")
	_expect(not plan.definition("aatrox").has("transformed_stats") and not plan.definition("jinx").has("transformed_stats"), "未携带主动不加载主动专属形态")
	_expect(plan.definition("gnar").has("transformed_stats") and plan.definition("sion").has("transformed_stats"), "被动变形与复活仍保留")
	_expect(plan.definition("darius").has("visual_active_buff_scene") and plan.definition("jinx").has("visual_active_buff_scene"), "被动表现不随主动资格移除")
	_expect(not plan.definition("melee_minion").has("visual_active_buff_scene"), "系统兵线不预热未携带的男爵之力")
	var resources := MatchResources.new()
	resources.plan = plan
	resources.prepare(blue + red + MatchResources.SYSTEM_UNIT_BUDGET.keys())
	_expect(resources.errors.is_empty(), "有限计划资源完整加载")
	_expect(resources.cards.size() == plan.cards.size(), "资源收集与可达闭包一致")
	_expect(not resources.resources.has("res://assets/units/aatrox/ultimate_view.tscn"), "未选主动形态未进入实际资源集合")
	var forbidden := {"sion": true, "sun_disc": true}
	for path in WARMUP.dependency_paths(forbidden):
		# 允许其他本局特效引用同一文件；按资源路径去重，不按技能强删共享素材。
		if path not in WARMUP.dependency_paths(plan.cards, plan):
			_expect(not resources.resources.has(path), "未携带技能独占依赖未加载：" + path)
	_expect(not plan.definition("anivia").audio.events.has("frost_storm:start"), "未选风暴的专属声音不加载")
	_expect(plan.definition("anivia").audio.events.has("attack_launch"), "普通攻击声音保留")
	_expect(not plan.definition("gwen", 0).audio.events.has("sanctuary:sustain") and plan.definition("gwen", 1).audio.events.has("sanctuary:sustain"), "双方技能声音按各自选择过滤")
	_expect("res://assets/effects/stasis/bard_swirl.png" not in WARMUP.dependency_paths(plan.cards, plan), "没有凝滞不加载金身纹理")
	var gold_plan: RefCounted = planner.for_match([["gwen", "tristana", "stasis"], []], [{}, {}])
	_expect(not gold_plan.allows("stasis") and "res://assets/effects/stasis/bard_swirl.png" in WARMUP.dependency_paths(gold_plan.cards, gold_plan), "普通槽凝滞也需要金身资源")
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var owner := ModelVisualResources.new()
	owner.bind_model(root)
	_expect(owner._gold == null and owner._gold_overlays.is_empty(), "模型初始化不创建金身材质")
	owner.apply_overlays(false, false, false, true)
	_expect(owner._gold != null and owner._gold_overlays.size() == 1, "凝滞采样时才创建金身材质")
	owner.clear()
	root.free()
	var presentation: BattlePresentation3D = _main._battle_presentation
	var warm = WARMUP.new()
	await warm.prepare(plan.cards, presentation._world_root, presentation._camera, Callable(), plan)
	_expect(not warm.sampled_layers.has("sion/Cas") and not warm.sampled_layers.has("anivia/storm"), "未携带技能未创建实际预热粒子")
	_expect(warm.sampled_layers.has("tristana/missile") and warm.sampled_layers.has("tristana/rapid") and warm.sampled_layers.has("anivia/missile"), "普攻始终保留而主动按槽选择")
	_expect(not warm.prepared.has("sun_disc"), "未携带烈阳不预热护盾")
	var specs := MatchModelPool.build_specs(resources.cards, plan)
	_expect(not specs.has("res://assets/units/aatrox/ultimate_view.tscn"), "模型池同样排除不可达形态")
	for uses in specs.values():
		for use in uses:
			_expect(int(use.team) in plan.cards[use.id], "模型池仅准备可出现的阵营")
	blue = ["mirror", "tristana", "sion", "anivia", "freeze", "sun_disc", "aatrox", "gwen"]
	var mirrored: RefCounted = planner.for_match([blue, red], [{"gwen": 1}, {"gwen": 0, "nocturne": 1}])
	_expect(mirrored.allows("sion", 0) and mirrored.allows("freeze", 0) and mirrored.allows("gwen", 1), "主动槽镜像扩展本方各卡确定的技能选择")
	_expect(not mirrored.allows("jinx") and not mirrored.allows("nocturne", 0), "主动镜像不扩展敌方牌或未选候选")
	_expect(mirrored.definition("aatrox").has("transformed_stats"), "主动镜像可达形态进入加载")
	var squad: RefCounted = planner.for_match([["melee_minion_squad", "kayn", "kayle"], []], [{}, {}])
	_expect(squad.allows("melee_minion") and squad.allows("kayn_assassin") and squad.allows("kayn_slayer"), "编队与成长继承主动资格")
	_expect(not squad.allows("kayle_ranged"), "普通槽升级卡不会凭空获得主动资格")
	_expect(CardDB.get_card("aatrox").has("transformed_stats") and CardDB.active_skills_for("gwen").size() == 2, "资源过滤不修改共享战斗定义")

func _declaration_contract() -> void:
	var planner = load("res://scripts/presentation/match_resource_plan.gd")
	var ordinary: RefCounted = planner.for_match([["garen", "ashe", "stasis", "tombstone"], ["gnar"]], [{}, {}])
	_expect(ordinary.errors.is_empty() and ordinary.target_states.has("stasis") and not ordinary.target_states.has("freeze"), "普通槽凝滞声明全场金身能力，不依赖主动资格")
	_expect(ordinary.cards.imp == [0] and not ordinary.allows("imp"), "墓碑依赖自动展开本方雾行者且不赋予主动技能")
	var without: RefCounted = planner.for_match([["garen", "ashe", "tombstone"], ["gnar"]], [{}, {}])
	_expect(without.target_states.is_empty(), "没有状态来源时不准备金身或冰冻")
	var resources := MatchResources.new()
	resources.plan = ordinary
	resources.prepare(ordinary.cards.keys())
	_expect(resources.errors.is_empty() and resources.raw_files.has("res://assets/effects/stasis/native/flight/sampled.json"), "原始JSON也进入本局可检查文件清单")
	var before := resources.resources.size()
	resources.prepare(["anivia"])
	_expect(not resources.cards.has("anivia") and resources.resources.size() == before and not resources.errors.is_empty(), "固定计划拒绝局中静默扩展未声明卡牌")
	var validator = load("res://scripts/data/card_validator.gd")
	var shapes = load("res://scripts/data/card_shape_validator.gd")
	var failures := PackedStringArray()
	shapes.validate("bad", {"resource_dependencies": {"effects": [{"provider": 3, "variant": "default"}]}}, failures)
	_expect(not failures.is_empty(), "效果提供者类型错误被前置校验拒绝")
	failures.clear()
	validator._validate_resource_dependencies("bad", {"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/stasis_spell_effect_3d.gd", "variant": "missing"}]}}, failures, true)
	_expect(not failures.is_empty(), "不存在的效果变体不能静默漏加载")
	failures.clear()
	validator._validate_resource_dependencies("bad", {"resource_dependencies": {"fields": ["hp"]}}, failures, false, {"hp": 100}, true)
	_expect(not failures.is_empty(), "资源字段所有权不能修改权威生命字段")
	failures.clear()
	validator._validate_resource_dependencies("bad", {"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/match_resource_plan.gd", "variant": "default"}]}}, failures, true)
	_expect(not failures.is_empty(), "没有提供者接口的脚本声明被拒绝")
	# 不以英雄名单识别金身来源：同一效果模块可由新的能力声明引用。
	var declared: Array[Dictionary] = []
	WARMUP.MANIFEST.collect_requests({"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/stasis_spell_effect_3d.gd", "variant": "default"}]}}, "future_card", declared)
	failures.clear()
	_expect("stasis" in WARMUP.MANIFEST.resolve(declared[0], failures).target_states and failures.is_empty(), "新卡复用效果契约即可声明金身，不修改中央规划器")
	var presentation: BattlePresentation3D = _main._battle_presentation
	presentation.prepare_target_states(ordinary.target_states)
	var towers := 0
	for child in presentation._world_root.get_children():
		if child is TowerModel3D and not child._source.is_king:
			towers += 1
			_expect(not child._stasis_visible and not CombatInteraction.in_stasis(child._source), "防御塔金身预热不修改战斗状态")
			for materials in child._surface_materials_by_name.values():
				for material in materials:
					_expect(material.get_shader_parameter("stasis_swirl") != null and is_zero_approx(float(material.get_shader_parameter("stasis_amount"))), "防御塔金身纹理准备后恢复正常显示")
	_expect(towers == 4, "双方四座防御塔参与金身准备，水晶排除")
