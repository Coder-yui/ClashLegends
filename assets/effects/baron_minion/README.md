# 小兵男爵之力（2026-09-13）

替换第一版借用英雄 Baron 符文的实现。本目录使用小兵专用原始资源，在 Godot 中重建可用的发射器子集；不是完整 LoL 粒子引擎或逐像素复刻。

## 来源与映射

外部只读素材库：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/`。`DATA.wad.client` 内含 TROYBIN 和全部 19 项 DDS/SCB 依赖；`Scripts.wad.client` 内含 `ExaltedWithBaronNashorMinion.preload` 与 `S5_BaronMinionSiegeAttack.preload`。此前只查 Map11 导致遗漏。原件保存在 `source/`（Godot 忽略），依赖路径及 SHA256 见 `source/manifest.json`。

| 项目 | 使用的原配置 |
| --- | --- |
| 四种兵身体强化覆层 | `SRU_JungleBuff_Baron_MeleeMin_Shield` 中 Avatar 贴图；适配现有模型材质 |
| 强化期间受击反馈 | `SRU_JungleBuff_Baron_MeleeMin_Shield_Hit` |
| 远程兵持续光效 | `Exalted_buf` / 蓝方 `Exalted_buf_order` |
| 炮车兵持续光效 | `Exalted_buf_siege` |
| 强化炮弹出膛、飞行、命中 | `SRU_JungleBuff_Baron_SiegeMin_Cas` / `_Mis` / `_Tar` |

超级兵没有单独确认到专用发射器映射，使用共同身体覆层与受击反馈，不套炮兵的光团。`MinionLines` 配置和依赖已归档，但当前是小兵自己施放技能，没有携带男爵 Buff 的英雄作为连线源，未显示英雄至小兵连线。

## 重建范围

`systems.json` 保留九套原始配置。`LolParticleEffect3D` 读取发射率、寿命、单粒子、原网格、纹理、UV 滚动、随机帧、颜色/缩放曲线、部分概率曲线、速度/加速度、朝向及发射器跟随；19 个依赖均已转换，没有占位贴图或占位网格。SCB→GLB 保留顶点与 UV，DDS→PNG 保留 alpha。

模型附着点、LoL 单位到 Godot 的比例、透明混合和材质覆层属于引擎适配；未实现完整骨骼挂点解析、所有概率/颜色查表语义、历史 Troy 的全部渲染模式。透明 SubViewport 中加法纹理以亮度约束 alpha，避免黑底方框。不能把“素材依赖完整”解释为“LoL 所有粒子语义完全复刻”。

`active_buff_projectile_visual = "baron_siege"` 只在发射时选择外观。飞行沿用正式弹体位置和 Snapshot；出膛/命中使用已有表现 RPC。到期后的新炮弹恢复普通外观，已发射的强化弹保持外观。没有新增伤害、范围伤害、碰撞或网络模拟规则。

## 音效核对

九套 TROY 配置、两份 preload 未发现可确认的专属声音事件。已解析的小兵共享声库（含双方炮兵）及事件名清单中没有确认的 Baron/Exalted/S5_BaronMinionSiegeAttack 事件；已确认的炮兵事件仍是普通 BasicAttack OnCast/OnHit/OnMissileCast。

**专属 Buff/炮弹音效：未确认，未新增。** 这不证明 LoL 没有专属音效：未命名 Wwise 事件仍有映射缺口。四卡沿用当前已核对的普通攻击/命中音频，不用大龙怪物攻击声替代，也不创建静音资源充数。

## 工具与重建

- [wadtools](https://github.com/LeagueToolkit/wadtools)：按原路径从 WAD 提取。
- [lolpytools](https://github.com/moonshadow565/lolpytools)：`troybin2troy.py input.troybin output.troy`。brew 无该包，源码位于 `/Users/czh/Tools/lolpytools`。
- [LeagueToolkit](https://github.com/LeagueToolkit/LeagueToolkit) 4.0.0-beta.52：`StaticMesh.ReadBinary(stream).ToGltf().SaveGLB(path)`；转换项目 `/Users/czh/Tools/lol-scb-export`，.NET 10。
- Pillow：DDS RGBA 转 PNG。`source/` 保留原件，运行资源无需安装以上工具。

## 验收

`tests/mechanics_check.gd`：四卡双阵营启停、受击/冻结覆层恢复、到期/死亡清理；强化炮弹快照类型、出膛无伤害、普通与强化弹速度/半径相同、到期后在途弹仍正常命中且只伤害一次。

真实 Godot Compatibility 渲染：`tools/demos/baron_minion_preview.gd`（八单位全生命周期）、`baron_projectile_preview.gd`（炮弹逐帧截图）。网络：`baron_minion_network.gd` 的 host/join 双进程检查八单位 Buff 开关、强化弹快照及出膛/命中表现事件。
