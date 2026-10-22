extends RefCounted
## 原始网格实测半径与工程世界单位。仅用于表现，不回写权威范围。
const PIXELS_PER_WORLD := 40.0
const Q_SOURCE_RADIUS := 199.7413454464 * 1.6
const W_SOURCE_RADIUS := 517.7974672797 # Temp_Mesh指示线纹理亮度中心，而非烟雾/网格包围半径
const Q_SCALE := 85.0 / PIXELS_PER_WORLD / Q_SOURCE_RADIUS
const W_SCALE := 120.0 / PIXELS_PER_WORLD / W_SOURCE_RADIUS
const GROUND_CLEARANCE := 0.04
