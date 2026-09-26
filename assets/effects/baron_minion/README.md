# 小兵男爵之力：自制特效

四类小兵共用 `minion_buff.gd` 与 `overlay.gdshader`。紫色半透明覆层贴合模型，使用程序流动条纹和轮廓亮边，不依赖提取纹理、网格或原版粒子。双方使用同一紫色，仍保留底层阵营色。

- 覆层只读取 `ActiveBuffVisual3D` 的权威/快照状态，持续时间内显示，到期或死亡立即移除。冰冻、受击闪白通过现有材质链叠加及恢复。
- 远程兵 `baron_ranged`、炮车兵 `baron_siege` 弹体由 `scripts/presentation/baron_projectile_effect.gd` 程序绘制：原弹体色芯、紫色光晕、亮边与短尾迹；出膛和命中使用自制短暂扩散光环。
- 外观在发射时确定，经已有 Snapshot 和表现事件同步。在途弹不随来源 Buff 到期变色，后续新弹恢复普通外观。特效不改变伤害、碰撞半径、速度、轨迹或状态时长。
- 旧版提取资源、粒子解释器及说明归档到本机 `ClashLegends-开发素材库/04-中间产物/男爵之力/2026-09-26-旧版提取特效/`，正式运行不再加载或预热。
- 沿用现有音频，本次未新增声音。

验证入口：`tests/mechanics_check.gd`；渲染复用 `tools/demos/baron_minion_preview.gd` 与 `tools/demos/baron_projectile_preview.gd -- --card=ranged_minion`（默认炮车兵）。
