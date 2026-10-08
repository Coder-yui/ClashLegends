extends "res://tests/suites/battle_suite.gd"
const WARMUP = preload("res://scripts/presentation/spell_effect_warmup.gd")

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var cards := {"lightning": true, "zap": true, "stasis": true, "explosive_cask": true}
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
	var event_id: int = main._presentation_event_id
	await warm.prepare(cards, presentation._world_root, presentation._camera)
	_expect(warm.prepared.size() == 4 and not warm.retained.is_empty(), "四种新播放器完成飞行命中绘制准备并保留资源")
	_expect(presentation._world_root.get_child_count() == child_count, "预热样本清理无残留节点")
	_expect(main._presentation_event_id == event_id and main._spell_system.stasis_effects.is_empty() and main._spell_system.cask_effects.is_empty(), "预热不发布战斗事件或权威法术")
	var cancelled = WARMUP.new()
	await cancelled.prepare(cards, presentation._world_root, presentation._camera, func(): return true)
	_expect(cancelled.prepared.is_empty() and cancelled.retained.is_empty(), "取消加载不创建预热资源")
