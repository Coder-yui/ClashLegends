extends ActiveBuffVisual3D
## 读取原版发射器/出生分布，跟随单位根变换；只读被动剩余时间。
const STREAK_TEXTURE = preload("res://assets/effects/jinx/overdrivelines_iblitz.png")
const CLOUD_TEXTURE = preload("res://assets/effects/jinx/jinx_base_p_buf.png")
const SOURCE_EMITTER_POSITION := Vector3(0, 50, 50)
# 本项目根挂载校正：出生在躯干略后方，保留原版分布和后向速度。
const BODY_MOUNT_OFFSET := Vector3(0, -50, -90)
const SOURCE_EMIT_OFFSET := Vector3(50, 1, 30)
const SOURCE_UNIT := 0.0085 * 1.12 # SKL→GLB实测0.0085；与模型一致的1.12×1.1缩放。
var _cloud: Sprite3D
var _particles: Array[Dictionary] = []
var _elapsed := 0.0
var _emission := 0.0
var _status_active := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	status_source = "structure_haste"
	_rng.randomize()
	_cloud = _sprite(CLOUD_TEXTURE, true)
	_cloud.position.y = 1.2
	_cloud.pixel_size = 0.007
	visible = false

func _sprite(texture: Texture2D, additive: bool) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	sprite.material_override = material
	add_child(sprite)
	return sprite

func advance(enabled: bool, delta: float) -> void:
	advance_status(enabled, enabled, delta)

func advance_status(status_active: bool, shown: bool, delta: float) -> void:
	if _cloud == null: return
	if status_active and not _status_active:
		_elapsed = 0.0
		_emission = 0.0
		_clear_particles()
	_status_active = status_active
	active = status_active
	visible = status_active and shown
	if not status_active:
		_clear_particles()
		return
	_elapsed += delta
	# 凝滞/隐藏继续表现时钟，不在恢复时重放触发闪光或积攒粒子。
	if not shown:
		_clear_particles()
		_emission = 0.0
		return
	_update_burst()
	for index in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		particle.age += delta
		if particle.age >= particle.life:
			particle.node.queue_free()
			_particles.remove_at(index)
			continue
		var progress: float = particle.age / particle.life
		particle.node.global_position += particle.velocity * delta
		particle.velocity *= exp(-delta) # 原版 birthDrag=(1,1,1)。
		particle.node.scale = particle.base_scale * Vector3(1, maxf(0.001, progress * 3.0), 1)
		particle.material.albedo_color = Color(0.65, 0.65, 1.0, 1.0 - progress)
	# 项目增强发射率24→0按权威剩余时间驱动；刷新恢复发射率，不重播触发笑脸。
	_emission += 24.0 * clampf(status_state.x / 6.0, 0.0, 1.0) * delta
	while _emission >= 1.0:
		_emission -= 1.0
		_emit_streak()

func _update_burst() -> void:
	_cloud.visible = _elapsed < 0.3
	(_cloud.material_override as StandardMaterial3D).albedo_color.a = maxf(0.0, 1.0 - _elapsed / 0.3)

func _emit_streak() -> void:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	# 源80×30任意四边形：贴图纵轴转向前后方向，避免错误的竖直白色条纹。
	quad.size = Vector2(36.0 * SOURCE_UNIT * _source_scale_y(), 80.0 * SOURCE_UNIT * _source_scale_x())
	node.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = STREAK_TEXTURE
	material.albedo_color = Color(0.65, 0.65, 1, 1)
	node.material_override = material
	add_child(node)
	node.top_level = true
	node.global_transform = global_transform * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), _source_spawn_position())
	var life := 0.3 * (_rng.randf_range(1.0, 2.0) if _rng.randf() > 0.9 else 1.0)
	_particles.append({"node": node, "material": material, "age": 0.0, "life": life,
		"base_scale": node.scale, "velocity": global_basis * Vector3(0, 0, -200.0 * SOURCE_UNIT * _rng.randf_range(0.8, 1.2))})
	node.scale.y *= 0.001

func _clear_particles() -> void:
	for particle in _particles: particle.node.queue_free()
	_particles.clear()

func _source_spawn_position() -> Vector3:
	# 原表X概率键(0,.2,.8,1)→(-1,-.3,.3,1)，Y为50→150，Z固定30。
	var x := _rng.randf()
	var spread := lerpf(-1.0, -0.3, x / 0.2) if x < 0.2 else (lerpf(-0.3, 0.3, (x - 0.2) / 0.6) if x < 0.8 else lerpf(0.3, 1.0, (x - 0.8) / 0.2))
	return (BODY_MOUNT_OFFSET + SOURCE_EMITTER_POSITION + SOURCE_EMIT_OFFSET * Vector3(spread, _rng.randf_range(50.0, 150.0), 1.0)) * SOURCE_UNIT

func _source_scale_x() -> float:
	var p := _rng.randf()
	return lerpf(1.0, 1.2, p / 0.8) if p < 0.8 else lerpf(1.2, 1.5, (p - 0.8) / 0.2)

func _source_scale_y() -> float:
	var p := _rng.randf()
	return lerpf(1.0, 1.2, p / 0.5) if p < 0.5 else lerpf(1.2, 2.0, (p - 0.5) / 0.5)
