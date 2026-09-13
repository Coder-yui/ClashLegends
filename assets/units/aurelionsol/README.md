# 龙王模型包装

`aurelionsol_view.tscn` 保留原有源模型、缩放和脚底偏移。`aurelionsol_view.gd` 只把素材 Jaw 骨骼映射为 `get_beam_origin_world()`，不参与权威攻击或移动。通用 UnitModel3D 不再认识龙王骨骼名。动画字段位于 `scripts/data/cards/aurelionsol.gd` 的 visual 域。

实际渲染已检查空军离地与朝向；持续吐息端点有 mechanics 和 host/join 回归。未新增音频素材。
