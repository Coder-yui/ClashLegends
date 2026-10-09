extends RefCounted
## 原版 W 地面范围；伤害、预警和冲击共用 1/4 等比缩放，结果均为整数。
const SOURCE_ORIGIN_Z := 47.0
const SOURCE_RANGE := Vector4(732.0, 316.0, 776.0, 148.0)
const SCALE := 0.25
const LENGTH := SOURCE_RANGE.x * SCALE
const NEAR_WIDTH := SOURCE_RANGE.y * SCALE
const FAR_WIDTH := SOURCE_RANGE.z * SCALE
const CENTER_WIDTH := SOURCE_RANGE.w * SCALE
const RANGE := SOURCE_RANGE * SCALE
