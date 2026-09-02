extends Node2D
## 赵信部署版「新月护卫」演示：生成首帧 Spell4 并立即击退四周敌人（按质量分级）；
## 整段 1 秒锁行动，结束后按权威状态衔接移动或三段普攻。
## 运行方式：Godot 编辑器打开 tools/demos/demo_xin_sweep.tscn 后按 F6，或命令行：
##   Godot --path . tools/demos/demo_xin_sweep.tscn
## 每轮时间线：生成并立即击退 → 1 秒 Spell4 → 普攻循环。
## 看点：
##   - 赵信生成就开始 Spell4，演出期间原地不动但仍拥有碰撞并可被攻击
##   - 质量 1 的小鬼最多承受基础 90px 击退，质量 8 的盖伦只被顶开一小步
##   - 圈内地面目标受到 90 伤害；圈外单位与空中单位（龙王）完全不受影响
##   - 演出结束后赵信追击木桩，三段普攻循环，第三击命中回血

const SIM_DT := 1.0 / 20.0
const FIELD_W := 720.0
const FIELD_H := 1280.0
const CENTER := Vector2(360.0, 660.0)
## 一轮 = 1s 部署 + 普攻观察约 4.5s。
const CYCLE_SECONDS := 5.5
## 木桩环绕半径：小于部署技能半径（90）+ 最大木桩半径，保证全部命中。
const RING_DISTANCE := 62.0
const FAR_DISTANCE := 175.0

var _units: Array[Unit] = []
var _anchors: Array[Vector2] = []
var _anchor_tags: Array[String] = []
var _sim_acc := 0.0
var _cycle_timer := 0.0
var _presentation: BattlePresentation3D = null

## 圈内地面木桩：显示名 → 卡牌 id（质量依次 1/2/3/4/6/8）。
const RING_DUMMIES := [
	["小鬼·质量1", "imp"],
	["提莫·质量2", "teemo"],
	["艾希·质量3", "ashe"],
	["剑圣·质量4", "masteryi"],
	["腕豪·质量6", "sett"],
	["盖伦·质量8", "garen"],
]

func _ready() -> void:
	_build_static_ui()
	# 3D 表现层：赵信出场播放 Spell4 新月护卫，木桩显示各自 3D 模型。
	_presentation = BattlePresentation3D.new()
	add_child(_presentation)
	_presentation.setup(Vector2(FIELD_W, FIELD_H), 40.0)
	spawn_round()

func _build_static_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.93, 0.93, 0.90)
	bg.size = Vector2(FIELD_W, FIELD_H)
	add_child(bg)
	var title := _make_caption("赵信 · 新月护卫（部署击退）", 30, Vector2(0, 46), Color(0.15, 0.15, 0.18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(FIELD_W, 40)
	add_child(title)
	var help := _make_caption(
		"生成首帧 Spell4，对圈内地面敌人造成 90 伤害并击退（共 1 秒无法行动）\n部署中仍可碰撞、被索敌和受伤；之后进入三段普攻，第三击回复 60 生命\n虚线圆 = 新月护卫半径 90px ｜ 每 5.5 秒重演一轮",
		17, Vector2(0, 96), Color(0.35, 0.35, 0.40)
	)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.size = Vector2(FIELD_W, 70)
	add_child(help)

func _process(delta: float) -> void:
	_cycle_timer += delta
	if _cycle_timer >= CYCLE_SECONDS:
		spawn_round()
	_sim_acc += delta
	while _sim_acc >= SIM_DT:
		_sim_acc -= SIM_DT
		for u in _units:
			u.sim_tick(SIM_DT)
		_apply_movement(SIM_DT)
		_separate_overlaps()
	queue_redraw()

## 一轮演示：清理旧单位，重新摆放赵信与木桩。
func spawn_round() -> void:
	_cycle_timer = 0.0
	for u in _units:
		u.queue_free()
	_units.clear()
	_anchors.clear()
	_anchor_tags.clear()

	# 敌人必须先进入 combatants；赵信随后生成的同一帧才能立即扫到它们。
	var angle_step := TAU / RING_DUMMIES.size()
	for i in RING_DUMMIES.size():
		var entry: Array = RING_DUMMIES[i]
		var angle := -PI * 0.5 + i * angle_step
		var pos := CENTER + Vector2(cos(angle), sin(angle)) * RING_DISTANCE
		_spawn_dummy(1, entry[1], pos, entry[0], Color(0.75, 0.25, 0.20))

	# 圈外地面木桩：部署技能半径之外
	_spawn_dummy(1, "ashe", CENTER + Vector2(0, -FAR_DISTANCE), "艾希·圈外", Color(0.45, 0.45, 0.50))
	# 空中木桩：圈内但飞在天上，部署击退扫不到
	_spawn_dummy(1, "aurelionsol", CENTER + Vector2(-52, 44), "龙王·空中", Color(0.45, 0.45, 0.50))

	# 赵信使用真实 1 秒部署，加入场景当帧结算部署版新月护卫。
	var xin_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var xin := _spawn_unit(0, xin_stats, CENTER, "赵信", Color(0.10, 0.35, 0.85))
	# 预扣部分生命，让三段循环第三击的回血在血条上可见。
	xin.take_damage(320.0)
	# 演示与验证脚本约定赵信为数组第 0 项；不改变节点实际生成先后。
	var xin_unit: Unit = _units.pop_back()
	var xin_anchor: Vector2 = _anchors.pop_back()
	var xin_tag: String = _anchor_tags.pop_back()
	_units.push_front(xin_unit)
	_anchors.push_front(xin_anchor)
	_anchor_tags.push_front(xin_tag)

## 静止木桩：不索敌、不移动、不还手，但保留质量与体型。
func _dummy_stats(base_id: String) -> Dictionary:
	var stats: Dictionary = CardDB.get_unit_stats(base_id).duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 999999.0
	stats["damage"] = 0.0
	stats["speed"] = 0.0
	stats["sight"] = 0.0
	return stats

func _spawn_dummy(team: int, base_id: String, pos: Vector2, label_text: String, label_color: Color) -> Unit:
	return _spawn_unit(team, _dummy_stats(base_id), pos, label_text, label_color)

func _spawn_unit(team: int, stats: Dictionary, pos: Vector2, label_text: String, label_color: Color) -> Unit:
	var u := Unit.new()
	u.position = pos
	u.setup(team, stats, stats.name)
	add_child(u)
	# 有 3D 模型的单位（赵信与多数木桩）挂上表现代理；无模型单位自动跳过。
	if _presentation != null and not stats.get("visual_scene_path", "").is_empty():
		_presentation.attach_unit(u, stats)
	_units.append(u)
	_anchors.append(pos)
	_anchor_tags.append(label_text)
	var tag := _make_caption(label_text, 15, Vector2(0, -u.visual_radius - 34), label_color)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(160, 20)
	tag.position -= Vector2(80, 0)
	u.add_child(tag)
	return u

## 简化版移动应用：直接按移动意图位移并限制在场地内，驱动击退与赵信的追击走位。
func _apply_movement(dt: float) -> void:
	for u in _units:
		if u.hp <= 0.0:
			continue
		if u._move_intent.length_squared() < 0.0001:
			u.on_movement_applied(0.0, dt)
			continue
		var old := u.global_position
		var next := u.global_position + u._move_intent * dt
		next.x = clampf(next.x, u.body_radius, FIELD_W - u.body_radius)
		next.y = clampf(next.y, u.body_radius, FIELD_H - u.body_radius)
		u.global_position = next
		u.on_movement_applied(u.global_position.distance_to(old), dt)

## 简化版两两分离：演示环境没有导航网格，仅按质量把重叠单位推开。
func _separate_overlaps() -> void:
	for i in range(_units.size()):
		for j in range(i + 1, _units.size()):
			var a := _units[i]
			var b := _units[j]
			if a.hp <= 0.0 or b.hp <= 0.0 or a.is_air != b.is_air:
				continue
			var delta := a.global_position - b.global_position
			var dist := delta.length()
			var min_dist := a.body_radius + b.body_radius
			if dist >= min_dist:
				continue
			var dir := (delta / dist) if dist > 0.01 else Vector2.RIGHT
			var push := (min_dist - dist) * 0.5
			var total := a.mass + b.mass
			a.global_position += dir * push * (b.mass / total)
			b.global_position -= dir * push * (a.mass / total)

func _draw() -> void:
	# 初始位置标记与击退轨迹
	for i in _units.size():
		var anchor := _anchors[i]
		var u := _units[i]
		if u == null or not is_instance_valid(u):
			continue
		var moved := u.global_position.distance_to(anchor)
		draw_circle(anchor, 4.0, Color(0.5, 0.5, 0.55, 0.5))
		if moved > 1.0:
			draw_line(anchor, u.global_position, Color(0.85, 0.35, 0.25, 0.45), 2.0)

func _make_caption(text: String, font_size: int, pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	return label
