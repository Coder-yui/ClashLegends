extends Node
## 临时演示：慢放复现公主塔阶段掉块演出（跳播语义）。
## 时序（游戏时间）：破 2/3 掉 Broken1 → Broken1 播到一半再破 1/3（直接切
## Stage2+Broken2，Broken1 立即消失）→ Broken2 播到一半被摧毁（直接切
## Stage3+Broken3）→ 演完定格 Rubble。每段碎块动画 2 秒，倒放原动画。
## 运行：Godot --path . res://tests/stage_debris_demo.tscn
## 操作：R 重播 / S 切换慢放速度（0.25 / 0.5 / 1.0）/ ESC 退出。

const TIME_SCALES := [0.25, 0.5, 1.0]
const DEMO_POSITION := Vector2(360.0, 800.0)

var _main: Node2D
var _demo_tower: Tower
var _status_label: Label
var _speed_label: Label
var _scale_index := 0
var _sequence_running := false

func _ready() -> void:
	Engine.time_scale = TIME_SCALES[_scale_index]
	var packed := load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main._start_local()
	# 冻结战斗模拟（金币/AI/单位），只保留表现层：镜头内只有演示塔和脚本伤害。
	_main.set_process(false)
	if _main._ai != null:
		_main._ai.set_process(false)
	_build_overlay()
	_run_sequence()

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 20.0)
	_status_label.add_theme_font_size_override("font_size", 26)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_status_label)
	_speed_label = Label.new()
	_speed_label.position = Vector2(24.0, 60.0)
	_speed_label.add_theme_font_size_override("font_size", 20)
	_speed_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_speed_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_speed_label)
	_update_speed_label()

func _update_speed_label() -> void:
	_speed_label.text = "慢放 %.2f 倍｜R 重播　S 切换速度　ESC 退出" % TIME_SCALES[_scale_index]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not _sequence_running:
			_run_sequence()
		elif event.keycode == KEY_S:
			_scale_index = (_scale_index + 1) % TIME_SCALES.size()
			Engine.time_scale = TIME_SCALES[_scale_index]
			_update_speed_label()

## 演出序列。计时器跟随 time_scale，节奏与正常对局一致，只是整体放慢。
func _run_sequence() -> void:
	_sequence_running = true
	if _demo_tower != null:
		_demo_tower.free()
		await get_tree().process_frame
		await get_tree().process_frame
	_demo_tower = Tower.new()
	_demo_tower.setup(0, _main.PRINCESS_STATS, false)
	_demo_tower.position = DEMO_POSITION
	_main.add_child(_demo_tower)
	_main._battle_presentation.attach_tower(_demo_tower, _main.PRINCESS_VISUAL_CONFIG)
	await get_tree().create_timer(0.8).timeout
	_status_label.text = "① 破 2/3 血：Base → Stage1+Broken1，播 Broken1 坠落（2 秒倒放）"
	_demo_tower.take_damage(_demo_tower.max_hp * 0.4)
	await get_tree().create_timer(1.0).timeout
	_status_label.text = "② Broken1 播到一半：再破 1/3 血，直接切 Stage2+Broken2 从头播，Broken1 立即消失"
	_demo_tower.take_damage(_demo_tower.max_hp * 0.3)
	await get_tree().create_timer(1.0).timeout
	_status_label.text = "③ Broken2 播到一半：塔被摧毁，直接切 Stage3+Broken3"
	_demo_tower.take_damage(_demo_tower.max_hp + 1.0)
	await get_tree().create_timer(2.5).timeout
	_status_label.text = "④ Broken3 演完：隐藏 Stage3 残核，定格 Rubble　——　按 R 重播"
	_sequence_running = false
