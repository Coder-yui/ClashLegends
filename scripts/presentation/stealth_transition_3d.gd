extends Node3D
## 只消费隐身切换表现事件；收束／迸散不参与感知、伤害或计时。
const PUFF_COUNT := 12
const STREAK_COUNT := 9
var elapsed := 0.0
var entering := true
var puffs: Array[MeshInstance3D] = []
var streaks: Array[MeshInstance3D] = []
var material: ShaderMaterial
var streak_material: ShaderMaterial
var wave: MeshInstance3D
var wave_material: ShaderMaterial

func setup(is_entering: bool) -> void:
	entering = is_entering
	material = _shader_material("""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
uniform float progress = 0.0;
uniform vec3 tint;
void vertex() {
 VERTEX *= vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 vec2 p = (UV - vec2(0.5)) * 2.0;
 float ripple = sin(p.x * 12.0 + progress * 6.0) * sin(p.y * 9.0 - progress * 4.0);
 float cloud = pow(max(1.0 - length(p) + ripple * 0.10, 0.0), 1.5);
 ALBEDO = tint;
 ALPHA = cloud * fade * 0.48;
}
""")
	material.set_shader_parameter("tint", Vector3(0.20, 0.72, 0.40) if entering else Vector3(0.56, 0.82, 0.16))
	streak_material = _shader_material("""shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
uniform bool inward = true;
void fragment() {
 float across = pow(max(1.0 - abs(UV.x * 2.0 - 1.0), 0.0), 1.8);
 float head = inward ? 1.0 - UV.y : UV.y;
 float taper = smoothstep(0.0, 0.2, head) * (1.0 - smoothstep(0.75, 1.0, head));
 ALBEDO = mix(vec3(0.16, 0.68, 0.26), vec3(0.40, 0.78, 0.30), head);
 ALPHA = across * taper * fade * 0.46;
}
""")
	streak_material.set_shader_parameter("inward", entering)
	wave_material = _shader_material("""shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
void fragment() {
 vec2 p = (UV - vec2(0.5)) * 2.0;
 float r = length(p);
 float rim = exp(-pow((r - 0.82) * 19.0, 2.0));
 float wisps = 0.65 + 0.35 * sin(atan(p.y, p.x) * 9.0 + r * 16.0);
 ALBEDO = vec3(0.25, 0.72, 0.28);
 ALPHA = rim * wisps * fade * 0.22;
}
""")
	for i in PUFF_COUNT:
		puffs.append(_quad(Vector2.ONE, material))
	for i in STREAK_COUNT:
		var streak := _quad(Vector2(0.11, 0.55), streak_material)
		# Quad 的纵轴对齐径向，纹理 y 从近端指向远端。
		var angle := TAU * float(i) / STREAK_COUNT
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		streak.basis = Basis(Vector3(-sin(angle), 0.0, cos(angle)), -radial, Vector3.UP)
		streaks.append(streak)
	wave = _quad(Vector2.ONE * 2.0, wave_material)
	wave.rotation.x = -PI * 0.5
	wave.position.y = 0.08
	_update_puffs(0.0)

func _shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var result := ShaderMaterial.new()
	result.shader = shader
	return result

func _quad(size: Vector2, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh

func _process(delta: float) -> void:
	elapsed += delta
	var t := elapsed / (0.65 if entering else 0.45)
	if t >= 1.0:
		queue_free()
		return
	_update_puffs(t)

func _update_puffs(t: float) -> void:
	# 入隐加速吸向躯干；破隐快速向外喷发并减速消散。
	var travel := t * t if entering else 1.0 - pow(1.0 - t, 2.0)
	var fade := smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.58, 1.0, t))
	material.set_shader_parameter("fade", fade)
	material.set_shader_parameter("progress", t)
	streak_material.set_shader_parameter("fade", fade)
	wave_material.set_shader_parameter("fade", fade)
	for i in puffs.size():
		var angle := TAU * float(i) / puffs.size() + (0.20 * travel if entering else 0.06 * travel)
		var spread := 1.0 + 0.14 * sin(float(i) * 2.4)
		var radius := lerpf(1.05 * spread, 0.10, travel) if entering else lerpf(0.16, 1.20 * spread, travel)
		var height := lerpf(0.25 + (i % 4) * 0.27, 0.65, travel) if entering else 0.35 + (i % 4) * 0.22 + travel * 0.25
		puffs[i].position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		puffs[i].scale = Vector3.ONE * (lerpf(0.65, 0.30, travel) if entering else lerpf(0.40, 0.75, travel))
	for i in streaks.size():
		var angle := TAU * float(i) / streaks.size()
		var radius := lerpf(1.05, 0.12, travel) if entering else lerpf(0.25, 1.25, travel)
		streaks[i].position = Vector3(cos(angle) * radius, 0.3 + (i % 3) * 0.25, sin(angle) * radius)
		streaks[i].scale = Vector3(1.0, lerpf(1.2, 0.25, travel) if entering else lerpf(0.45, 1.25, travel), 1.0)
	var wave_radius := lerpf(1.35, 0.12, travel) if entering else lerpf(0.22, 1.45, travel)
	wave.scale = Vector3.ONE * wave_radius
