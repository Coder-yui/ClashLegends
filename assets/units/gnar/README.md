# 纳尔素材特例

纳尔不是普通模型接入样例。玩法仍由 CardDB 双形态字段和通用 Unit 驱动，但素材需要小/大两套包装场景及 `gnar_view_filter.gd` 的运行时动画/网格处理。

- 小模型：`gnar_small_view.tscn`；普通攻击用非 Fast 的 `Gnar_Attack1/2`，Run_In 和变形时隐藏额外回旋镖。
- 大模型：`gnar_mega_view.tscn`；攻击建筑使用 Turret Attack，Spell2 与 Big Death 使用独立映射，Run_In/变形隐藏石头。
- 变大：将 Rage_Scale 相对 Base 叠加到 Rage_Move；主动变大叠加 Spell2_Tran。
- 变小：将 Revert_Scale 相对 Base 叠加到 Gnar_Revert。
- 大纳尔死亡先播短 Big Death，再切小模型播 Death；只属于表现链，权威单位已经死亡。

`visual_actions`、变形时长、双模型路径和 transformed_stats 均在 CardDB。不要把 Scale/Base 合成、网格过滤或双模型步骤复制进普通近战/远程教程，也不要让合成动画决定形态切换、Spell2 命中或死亡时刻。
