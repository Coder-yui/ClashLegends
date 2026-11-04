class_name BallisticAttack
extends RefCounted
## 固定落点投掷；仅权威 Tick 前进，模型与动画不参与命中。
static func initialize(p: Dictionary, destination: Vector2, effects: Dictionary) -> void:
	p.ballistic = true
	if float(effects.get("splash_radius", 0.0)) > 0.0:
		p.splash = float(effects.splash_radius)
	p.visual = &"ziggs_bounce" if int(effects.get("bounce_count", 1)) > 1 else p.visual
	p.landing = destination
	p.hop_index = 0
	p.hops_left = int(effects.get("bounce_count", 1))
	p.bounce_distance = float(effects.get("bounce_distance", 0.0))
	p.hop_start = p.pos
	p.hop_elapsed = 0.0
	p.hop_duration = maxf((p.pos as Vector2).distance_to(destination) / float(p.speed), 0.15)
	p.launch_height = float(p.visual_height)
	p.visual_path = {}
	p.target = null

static func tick(p: Dictionary, dt: float, context: BattleContext, system: ProjectileSystem) -> bool:
	p.hop_elapsed = minf(float(p.hop_elapsed) + dt, float(p.hop_duration))
	var t := float(p.hop_elapsed) / float(p.hop_duration)
	p.pos = (p.hop_start as Vector2).lerp(p.landing, t)
	p.visual_height = lerpf(float(p.launch_height), 0.0, t) + sin(t * PI) * 42.0
	if t < 0.99999: return false
	var source = p.get("attacker")
	if not is_instance_valid(source): source = null
	var effects: Dictionary = p.effects.duplicate(true)
	effects.impact_center = p.landing
	context.resolve_attack_hit(int(p.team), p.landing, null, float(p.damage), float(p.splash), 0.0, source, p.source_pos, int(p.source_form_index), effects)
	context.show_projectile_impact(p.landing, float(p.splash), p.color, StringName(p.impact_visual))
	system.wave_audio.emit(effects.get("presentation_source", {}), "bomb", p.landing, "impact" if String(p.visual).begins_with("ziggs_bounce") else "basic_impact")
	p.hops_left -= 1
	if p.hops_left <= 0: return true
	system.wave_audio.emit(effects.get("presentation_source", {}), "bomb", p.landing, "second_launch" if p.hops_left == 2 else "third_launch")
	p.hop_index += 1
	p.visual = StringName("ziggs_bounce_%d" % mini(int(p.hop_index) + 1, 3))
	p.hop_start = p.landing
	p.landing += (p.direction as Vector2) * float(p.bounce_distance)
	p.hop_duration = maxf(float(p.bounce_distance) / float(p.speed), 0.15)
	p.hop_elapsed = 0.0
	p.launch_height = 0.0
	return false
