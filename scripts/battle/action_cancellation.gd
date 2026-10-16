class_name ActionCancellation
extends RefCounted
## 权威取消原因与网络载荷共用的严格合同；增加生产原因时同步扩展此处。
const FREEZE := &"freeze"
const STASIS := &"stasis"
const STUN := &"stun"
const KNOCKBACK := &"knockback"
const DEATH_FORM := &"death_form"
const EMPOWERED_RESET := &"empowered_reset"
const SILENCE := &"silence"
const TAUNT := &"taunt"
const TERRAIN_EXIT := &"terrain_exit"
const REASONS: Array[StringName] = [FREEZE, STASIS, STUN, KNOCKBACK, DEATH_FORM, EMPOWERED_RESET, SILENCE, TAUNT, TERRAIN_EXIT]

static func valid_reason(reason: StringName) -> bool:
	return reason in REASONS

static func valid_payload(payload: Dictionary) -> bool:
	if payload.is_empty(): return true
	for key in ["serial", "attack", "action", "form"]:
		if not payload.get(key) is int or int(payload[key]) < 0: return false
	if payload.has("cancelled_action") and (not payload.cancelled_action is int or int(payload.cancelled_action) < -1): return false
	if payload.has("cancelled_deployment") and not payload.cancelled_deployment is bool: return false
	return payload.get("reason") is String and valid_reason(StringName(payload.reason))
