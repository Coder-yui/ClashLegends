extends Node3D
## 只消费隐身切换表现事件；短烟雾不参与感知、伤害或计时。
var elapsed := 0.0
var entering := true
var puffs: Array[MeshInstance3D] = []
var material: ShaderMaterial

func setup(is_entering: bool) -> void:
	entering = is_entering
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
uniform vec3 tint = vec3(0.28, 0.65, 0.25);
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 float r = length(UV - vec2(0.5)) * 2.0;
 ALBEDO = tint;
 ALPHA = pow(max(1.0-r, 0.0), 1.8) * fade * 0.65;
}
"""
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", Vector3(0.30, 0.65, 0.38) if entering else Vector3(0.66, 0.83, 0.24))
	for i in 9:
		var puff := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.9
		puff.mesh = quad
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		puffs.append(puff)
	_update_puffs(0.0)

func _process(delta: float) -> void:
	elapsed += delta
	var t := elapsed / (0.65 if entering else 0.4)
	if t >= 1.0:
		queue_free()
		return
	_update_puffs(t)

func _update_puffs(t: float) -> void:
	material.set_shader_parameter("fade", 1.0 - t)
	for i in puffs.size():
		var angle := TAU * float(i) / puffs.size()
		var radius := lerpf(0.48, 0.15, t) if entering else lerpf(0.12, 0.85, t)
		puffs[i].position = Vector3(cos(angle) * radius, 0.22 + (i % 3) * 0.3 + t * 0.3, sin(angle) * radius)
