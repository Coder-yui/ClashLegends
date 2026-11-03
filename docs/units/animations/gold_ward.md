# 金币守卫动画

[返回金币守卫](../gold_ward.md) · [总索引](../README.md)

使用 LoL 默认 SightWard：部署 sightward_base_idlein（0.4秒），待机 sightward_base_idle（静态姿势），死亡 sightward_base_idle_death（约0.767秒，配置0.8秒上限，短片原速）。不含普攻。双方使用同一模型，队伍圈区分阵营。

源模型包围范围约136.50×98.95×46.86，包装统一缩放0.018；源皮肤未配置隐藏网格。凝滞使用公共金身与冻结姿势。模型不驱动产出或寿命。

原始提取和转换保存在开发素材库03-制作中/金币守卫；来源为Map11.wad.client的assets/characters/sightward/skins/base，正式GLB位于assets/units/gold_ward/source/ward.glb。

默认SightWard的skin0、root及角色定义、基础皮肤素材路径已核查：只有sightward.tex，纹理为金翼绿宝石，无红蓝替代材质或纹理配置。维持双方共用该原版模型，以既有队伍圈区分；不将其他侦查守卫皮肤冒充阵营版本。核查源件位于制作目录team-source/及root.ritobin、character.ritobin。
