extends SceneTree
## Reusable review for sampled effect providers exposing load_kind/setup_native/seek.
var player: Node3D
var camera: Camera3D
var floor_mesh: MeshInstance3D
var viewport: SubViewport
var timeline: HSlider
var clock_label: Label
var play_button: Button
var layer_box: VBoxContainer
var time := 0.15
var duration := 3.0
var playing := false
var speed := 1.0
var yaw := 0.0
var elevation := 54.0
var zoom := 10.0
var height := 0.0
var hidden_layers := {}
var provider := "res://assets/effects/kassadin/player.gd"
var variants := PackedStringArray(["appear", "vanish"])
var capture_dir := ""
var check_only := false
var attachment_path := ""
var attachment: Node3D
var preview_motion := false
var model_scale := 1.0
var native_scale := 0.01
var trail_ghost_kind := ""
var trail_ghost: Node3D
var trail_ghost_fx: Node3D
var attachment_base: CheckBox
var attachment_meshes: Array[Dictionary]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--check-only": check_only=true
		if arg == "--motion": preview_motion=true
		if arg.begins_with("--native-scale="): native_scale=float(arg.trim_prefix("--native-scale="))
		if arg.begins_with("--zoom="): zoom=float(arg.trim_prefix("--zoom="))
		if arg.begins_with("--trail-ghost="): trail_ghost_kind=arg.trim_prefix("--trail-ghost=")
		if arg.begins_with("--model-scale="): model_scale=float(arg.trim_prefix("--model-scale="))
		if arg.begins_with("--attachment-model="): attachment_path=arg.trim_prefix("--attachment-model=")
		if arg == "--help":
			print("effect --provider=res://path/player.gd --variants=appear,vanish [--capture-dir=/absolute/path] [--attachment-model=res://model.glb] [--motion]")
			quit(); return
		if arg.begins_with("--provider="): provider = arg.trim_prefix("--provider=")
		if arg.begins_with("--variants="): variants = arg.trim_prefix("--variants=").split(",")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if check_only: call_deferred("_check_variants")
	else: call_deferred("_build")
func _build() -> void:
	root.size = Vector2i(1280,850)
	root.content_scale_size = Vector2i(1280,850)
	root.min_size = Vector2i(1100,760)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	DisplayServer.window_set_title("特效展台 · 时间轴 / 分层 / 地面遮挡")
	var layout := HBoxContainer.new(); layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(layout)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.x=340; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; layout.add_child(scroll)
	var panel := VBoxContainer.new(); panel.custom_minimum_size.x=320; scroll.add_child(panel)
	panel.add_theme_constant_override("separation",8)
	_label(panel,"特效展台")
	_label(panel,"拖动右侧旋转 · 滚轮缩放\n拖动时间轴会暂停，支持逐帧检查")
	var select := OptionButton.new(); panel.add_child(select)
	for variant in variants: select.add_item(variant)
	select.item_selected.connect(func(i): _load_variant(variants[i]))
	play_button = _button(panel,"播放",func(): playing=not playing; play_button.text="暂停" if playing else "播放")
	_button(panel,"重播",func(): time=0; playing=true; play_button.text="暂停")
	var speed_select := OptionButton.new(); panel.add_child(speed_select)
	for value in [0.25,0.5,1.0]: speed_select.add_item(str(value)+"×")
	speed_select.select(2); speed_select.item_selected.connect(func(i): speed=[0.25,0.5,1.0][i])
	clock_label = _label(panel,"")
	timeline=HSlider.new(); timeline.step=1.0/120.0; timeline.max_value=3; panel.add_child(timeline)
	timeline.value_changed.connect(func(v): time=v; playing=false; play_button.text="播放"; _seek())
	_button(panel,"上一帧（1/120秒）",func(): _jump(time-1.0/120.0))
	_button(panel,"下一帧（1/120秒）",func(): _jump(time+1.0/120.0))
	var ground := CheckBox.new(); ground.text="显示实体地面（深度遮挡）"; ground.button_pressed=true; panel.add_child(ground)
	ground.toggled.connect(func(v): floor_mesh.visible=v)
	_button(panel,"项目机位（54°）",func(): yaw=0; elevation=54; _camera())
	_button(panel,"俯视",func(): yaw=0; elevation=89.9; _camera())
	_button(panel,"侧视",func(): yaw=0; elevation=10; _camera())
	_label(panel,"整体抬高（诊断用，不保存到游戏）")
	var lift := HSlider.new(); lift.min_value=0; lift.max_value=2; lift.step=0.01; panel.add_child(lift)
	lift.value_changed.connect(func(v): height=v; player.position.y=height)
	attachment_base=CheckBox.new();attachment_base.text="显示附着对象原模型";panel.add_child(attachment_base)
	attachment_base.toggled.connect(func(_value): _update_attachment_base())
	_label(panel,"粒子层")
	layer_box=VBoxContainer.new();panel.add_child(layer_box)
	_label(panel,"读取现有项目播放器；不改源数据。\n未实现 load_kind/setup_native/seek\n接口的特效不能直接加载。")
	var container := SubViewportContainer.new();container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;container.size_flags_vertical=Control.SIZE_EXPAND_FILL;container.stretch=true;layout.add_child(container)
	viewport=SubViewport.new();viewport.size=Vector2i(960,850);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
	container.gui_input.connect(_input_view)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=0.01;camera.far=100;viewport.add_child(camera);camera.current=true
	var environment := WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0.045,0.06,0.09);environment.environment=env;viewport.add_child(environment)
	floor_mesh=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(20,20);floor_mesh.mesh=plane
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(0.20,0.28,0.22);floor_mesh.material_override=material;viewport.add_child(floor_mesh)
	_camera();_load_variant(variants[0])
	if not capture_dir.is_empty(): call_deferred("_captures")
func _label(parent: Node,text: String) -> Label:
	var label:=Label.new();label.text=text;parent.add_child(label);return label
func _button(parent: Node,text: String,action: Callable) -> Button:
	var button:=Button.new();button.text=text;parent.add_child(button);button.pressed.connect(action);return button
func _load_variant(kind: String) -> void:
	attachment_meshes.clear()
	if is_instance_valid(trail_ghost): trail_ghost.free()
	if is_instance_valid(trail_ghost_fx): trail_ghost_fx.free()
	if is_instance_valid(attachment): attachment.free()
	if is_instance_valid(player): player.free()
	player=null
	hidden_layers.clear()
	for child in layer_box.get_children(): child.free()
	var script = load(provider)
	if script == null: push_error("Cannot load provider: "+provider);return
	player=script.new()
	for method in ["load_kind","setup_native","seek"]:
		if not player.has_method(method): push_error("Unsupported provider: "+method);player.free();return
	viewport.add_child(player);player.load_kind(kind);player.setup_native(native_scale);player.position.y=height
	duration=float(player._data.duration);timeline.max_value=duration
	if not attachment_path.is_empty() and player.has_method("make_overlay") and player._data.emitters.any(func(e): return int(e.get("quadType",-1))in [5,11]):
		attachment=load(attachment_path).instantiate()
		viewport.add_child(attachment);attachment.scale=Vector3.ONE*model_scale
		_attach_layers(attachment)
		attachment_base.set_pressed_no_signal(kind in ["end","r-Tar_Impact"] or not player._data.emitters.any(func(e): return int(e.get("quadType",-1))==11))
		_update_attachment_base()
	if not trail_ghost_kind.is_empty() and is_instance_valid(attachment) and player._data.emitters.any(func(e): return int(e.get("quadType",-1))==5):
		trail_ghost=load(attachment_path).instantiate();viewport.add_child(trail_ghost);trail_ghost.scale=Vector3.ONE*model_scale
		trail_ghost_fx=script.new();viewport.add_child(trail_ghost_fx)
		trail_ghost_fx.load_kind(trail_ghost_kind+("_Red" if kind.ends_with("_Red") else ""));trail_ghost_fx.setup_native(native_scale)
		for animator in trail_ghost.find_children("*","AnimationPlayer",true,false):
			for animation in animator.get_animation_list():
				if "idle01" in String(animation).to_lower(): animator.play(animation);animator.seek(0.0,true);break
			animator.pause();animator.active=false
		for mesh in trail_ghost.find_children("*","MeshInstance3D",true,false):
			mesh.material_override=trail_ghost_fx.make_overlay(null)
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in player._data.emitters.size():
		var toggle:=CheckBox.new();toggle.text=String(player._data.emitters[i].name);toggle.button_pressed=true;layer_box.add_child(toggle)
		toggle.toggled.connect(func(v): hidden_layers[i]=not v;player._frame=-1;_seek())
	_jump(0.15)
func _attach_layers(node: Node) -> void:
	if node is AnimationPlayer:
		for animation in node.get_animation_list():
			if "idle01" in String(animation).to_lower():
				node.play(animation);node.seek(0.0,true);break
		node.pause();node.active=false
	if node is MeshInstance3D:
		attachment_meshes.append({"mesh":node,"layer":player.make_overlay(null)})
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): _attach_layers(child)

func _update_attachment_base() -> void:
	for entry in attachment_meshes:
		entry.mesh.material_override=null if attachment_base.button_pressed else entry.layer
		entry.mesh.material_overlay=entry.layer if attachment_base.button_pressed else null

func _camera() -> void:
	var angle:=deg_to_rad(elevation);var rotation:=deg_to_rad(yaw)
	camera.position=Vector3(sin(rotation)*cos(angle),sin(angle),cos(rotation)*cos(angle))*15.0
	camera.look_at(Vector3.ZERO,Vector3.UP);camera.size=zoom
func _input_view(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw-=event.relative.x*0.4;elevation=clampf(elevation+event.relative.y*0.3,5,89.9);_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom=maxf(2,zoom*0.9);_camera()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom=minf(20,zoom*1.1);_camera()
func _jump(value: float) -> void:
	time=clampf(value,0,duration);playing=false;play_button.text="播放";_seek()
func _process(delta: float) -> bool:
	if is_instance_valid(player):
		if playing: time=fmod(time+delta*speed,duration)
		_seek()
	return false
func _seek() -> void:
	if not is_instance_valid(player): return
	if preview_motion and "motion_history" in player and player._data.emitters.any(func(e): return int(e.get("quadType",-1))==5):
		var history: Array[Dictionary]=[]
		var travelled:=0.0
		for step in 161:
			var stamp:=time-8.0+float(step)*0.05
			var point:=Vector3(sin(stamp*0.65)*1.8,0,cos(stamp*0.65)*1.8)
			if not history.is_empty(): travelled+=point.distance_to(history[-1].position)
			history.append({"time":stamp,"position":point,"distance":travelled})
		player.motion_history=history;player.motion_time=time
		if "history_window" in player: player.history_window=4.0
		player.position=history[-1].position+Vector3.UP*height
	if is_instance_valid(attachment): attachment.position=player.position
	if is_instance_valid(trail_ghost):
		trail_ghost.position=player._motion_point(time-4.0)+Vector3.UP*height
		trail_ghost_fx.position=trail_ghost.position
		trail_ghost_fx.seek(float(trail_ghost_fx._data.duration));trail_ghost_fx.update_attached(true)
	if preview_motion and "history_window" in player and player.history_window>0.0: player.seek_history(4.0)
	else: player.seek(time)
	if player.has_method("update_attached"):
		player.update_attached(true)
		for entry in player._attached:
			if hidden_layers.get(entry.index,false): entry.material.set_shader_parameter("attached_enabled",false)
	if "_ribbons" in player:
		for index in player._ribbons:
			if hidden_layers.get(index,false): player._ribbons[index].hide()
	for i in player._pools.size():
		for item in player._pools[i]:
			if hidden_layers.get(i,false): item.visible=false
	timeline.set_value_no_signal(time);clock_label.text="%.3f / %.3f 秒" % [time,duration]
func _captures() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for label in ["ground","no-ground","raised","top"]:
		floor_mesh.visible=label!="no-ground";player.position.y=1.2 if label=="raised" else 0.0
		elevation=89.9 if label=="top" else 54.0;_camera();_jump(0.15)
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))
		print("[Effect studio] ",label)
	floor_mesh.visible=true;player.position.y=0;elevation=54;_camera()

## Compare source flags to the shader actually selected by the provider.
func _check_variants() -> void:
	var script = load(provider)
	var errors := 0
	var checked := 0
	if script == null or not script.has_method("resource_manifest") or not script.has_method("resource_shader_path"):
		push_error("Provider must expose resource_manifest and resource_shader_path");quit(1);return
	for kind in variants:
		var manifest: Dictionary = script.resource_manifest(kind)
		var variant_checked := 0
		for path in manifest.get("json", []):
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not data is Dictionary: errors+=1;continue
			for emitter in data.get("emitters", []):
				variant_checked+=1
				var shader_path: String = script.resource_shader_path(emitter)
				var shader = load(shader_path)
				var expected := (int(emitter.get("miscRenderFlags",0)) & 1) != 0
				if not shader is Shader or shader.code.contains("depth_test_disabled") != expected:
					errors+=1;push_error("Depth flag mismatch: %s/%s -> %s" % [kind,emitter.get("name","?"),shader_path])
		if variant_checked == 0: errors+=1;push_error("No sampled emitters checked: "+kind)
		checked+=variant_checked
	print("[Effect depth check] ", checked, " emitters, ",errors," errors")
	quit(0 if errors == 0 else 1)
