extends ActiveBuffVisual3D
## 使用 ExaltedWithBaronNashorMinion.preload 的小兵专用粒子，不再借用英雄脚底符文。
@export var aura_name := ""
@export var order_aura_name := ""
@export var aura_offset := Vector3.ZERO
var _factor := 0.0072
var _fade := 0.0
var _elapsed := 0.0
var _aura: LolParticleEffect3D
var _bursts: Array[LolParticleEffect3D] = []
var _selected_aura := ""

func configure(visual_radius: float, team: int = 0) -> void:
	_factor = 0.0072 * maxf(visual_radius / 16.5, 1.0)
	_selected_aura = order_aura_name if team == 0 and not order_aura_name.is_empty() else aura_name
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = preload("res://assets/effects/baron_minion/overlay.gdshader")
	overlay_material.set_shader_parameter("overlay_texture", preload("res://assets/effects/baron_minion/sru_junglebuff_baron_meleemin_avataroverlay.png"))
	visible = false

func advance(enabled: bool, delta: float) -> void:
	if enabled and not active:
		_elapsed = 0.0
		if not _selected_aura.is_empty():
			_aura = _effect(_selected_aura, true)
			_aura.position = aura_offset
	if not enabled and active and is_instance_valid(_aura):
		_aura.stop_emitting()
	active = enabled
	_elapsed += delta
	_fade = move_toward(_fade, 1.0 if active else 0.0, delta * 5.0)
	for material in overlay_instances:
		material.set_shader_parameter("elapsed", _elapsed)
		material.set_shader_parameter("strength", _fade)
	for i in range(_bursts.size() - 1, -1, -1):
		var effect := _bursts[i]
		effect.advance(delta)
		if effect.finished() or (not active and _fade <= 0):
			if effect == _aura: _aura = null
			effect.free()
			_bursts.remove_at(i)
	visible = active or _fade > 0 or not _bursts.is_empty()

func on_hit() -> void:
	if active:
		_effect("sru_junglebuff_baron_meleemin_shield_hit")

func _effect(system: String, looping: bool = false) -> LolParticleEffect3D:
	var effect := LolParticleEffect3D.new()
	add_child(effect)
	effect.setup(system, _factor, looping)
	_bursts.append(effect)
	return effect
