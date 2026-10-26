extends RefCounted
## 纯表现布局。输入按当前最大生命归一化，等价于 k=W/max(M,(H+S)/1.5)。
## 不保留历史盾容量，不读取战斗状态，也不截断任何一段。
static func calculate(width: float, health_ratio: float, shield_health_ratio: float) -> Dictionary:
	assert(is_finite(width) and width > 0.0, "血条基础宽度必须为有限正数")
	assert(is_finite(health_ratio) and health_ratio >= 0.0, "血条生命比例必须为有限非负数")
	assert(is_finite(shield_health_ratio) and shield_health_ratio >= 0.0, "血条护盾比例必须为有限非负数")
	var pixels := width / maxf(1.0, (health_ratio + shield_health_ratio) / 1.5)
	return {
		"normal_width": minf(health_ratio, 1.0) * pixels,
		"overflow_width": maxf(health_ratio - 1.0, 0.0) * pixels,
		"shield_width": shield_health_ratio * pixels,
		"shield_start": health_ratio * pixels,
		"full_health_x": pixels,
		"background_width": maxf(1.0, health_ratio + shield_health_ratio) * pixels,
	}
