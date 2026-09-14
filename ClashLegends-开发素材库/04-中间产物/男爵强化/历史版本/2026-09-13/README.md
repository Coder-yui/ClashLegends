> 此目录为第一版英雄特效适配归档。四张小兵卡已切换到 `../baron_minion/` 的小兵专用资源；仅身体覆层 shader 仍复用。下文记录第一版历史状态。

# 男爵之力：四种小兵的 Godot 粒子适配

四种小兵共用 `baron_buff.tscn`。在开发工作台“实战·技能”放置任一种小兵，释放“男爵之力”即可查看；两种阵营均支持。现有工具足够，本轮没有额外安装或下载工具。

## 素材与追溯

原包：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Maps/Shipping/Map11.wad.client`（只读）。用本机 wadtools 0.5.7 定向提取，ltk-tex-utils 0.3.0 转成 RGBA PNG，工作目录 `/Users/czh/Tools/lol-asset-tools/baron_minion_review/`。未经过绘图、AI 重画或调色处理。

`source/manifest.json` 记录 WAD 内路径与 TEX SHA-256；`source/` 保存原 TEX 及两段可读 VfxSystemDefinitionData，以 `.gdignore` 阻止 Godot 将 LoL TEX 误识别为自身资源。PNG 为正式运行资源。原配置摘自已经解析的 `/Users/czh/Tools/lol-asset-tools/announcer_review/map11.rito`，对象路径为 `Maps/Shipping/Map11/Particles/Default/SRX_Buf_Baron` 与 `SRX_Buf_Baron_Child`。

| 原参数/素材 | Godot 实现 |
| --- | --- |
| `Decal_Proc`：0.5 秒、约 −300°/秒、尺寸 1.6→2.25→1 | 启动 PlaneMesh，独立透明叠加 Shader；缩放曲线保留，旋转取近似常速 |
| `Decal_Persist`：延后 0.5 秒、−40°/秒 | 持续旋转符文；`Jungle_Buff_Baron` 原 RGBA，保留透明边缘 |
| `Base_shield_Mult`：−45°/秒 | 第二纹理旋转遮罩 |
| `card-ground`：0.7 次/秒、尺寸 1→0.5 | `Ring_Soft_02` 低亮度软环脉动，复用原颜色 |
| 三个发射方向：0/120/240°；50 Hz；寿命约 0.8 秒；轨道速度 Y=2 | 三路相机朝向条带，每路 40 段；采用有界螺旋近似 LoL CameraTrail 的加速度与轨道组合 |
| 每路暗色混合 + 紫色叠加 | 同一动态网格双材质层，原暗/亮颜色；`SRX_Infernal_Smoke_Trail` UV 偏移 0.33、滚动 −0.5/秒 |
| `SRU_JungleBuff_Baron_MeleeMin_AvatarOverlay` | 模型材质覆盖，UV 滚动 (0.4, 0.2)，降低强度以保留蓝/红模型辨识度 |

## 复现范围

这是原男爵 Buff 粒子配置的手工适配，**不是任意 LoL 粒子自动转换器，也不是完整原版小兵强化的一比一复刻**。`SRX_Buf_Baron` 是已确认的男爵 Buff 通用配置；不能据此断言它就是四种小兵各自的专属配置。

身体覆盖 TEX 名称指向男爵小兵，但本机 Map11 中找到的使用点属于一个禁用的化学科技复用发射器；本轮主动将其作为小兵强化的覆盖材质，采用该使用点的 UV 速度。不把这个禁用发射器冒称为原版正在使用的男爵小兵实现。

Godot 单位位于透明 3D 视口，地面是 2D 图，因此未移植 LoL navmesh mask；用低高度平面避免闪烁。原概率加速度、完整轨道积分、暗层 0.85 秒与亮层 0.8 秒的差别、color-hold_2 查表与原始 CameraTrail 平滑均用简化表现代替。按本项目 visual_radius 缩放，并放大视觉范围 1.4 倍；不会扩大权威半径。

旧 `SRU_JungleBuff_Baron_MinionLines.troybin` 的 DDS 依赖未核实，未接入；强化专用炮弹、额外动画与强化 start/sustain/end 音效尚未确认，不使用其他技能素材代替。现有普通攻击和部署音不变。

## 技能与生命周期

四兵共用“男爵之力”名称，保留各自消耗/次数/CD。近战保留 4 秒移速 ×1.35/伤害 ×1.25；超级兵保留 5 秒移速/伤害 ×1.35 与 140 护盾。远程改为 5 秒伤害/攻速 ×1.25，炮车改为 5 秒伤害 ×1.5。这些是本项目第一版适配数值，未复刻 LoL 的减伤、射程或攻城规则。

视觉仅由 `UnitPresentationState.active_buff` 开关；主机 20 Hz 计算 Buff，客户端消费现有 `U_ACTIVE_BUFF_ACTIVE`，无需增加 RPC 或协议字段；客户端收到状态后从本地相位开始动画，未同步粒子随机种子或原始启动相位。启动、到期淡出、死亡清理和模型更换均由通用代理驱动。身体覆盖与原材质、受击闪白、冰冻层串联；不占用模型动画通道。

## 验收

实际渲染脚本：`tools/demos/baron_minion_preview.gd`，输出 `/tmp/clash-baron-minions/`，包含普通、启动、持续、移动/攻击、控制/受击、到期、死亡和清理八个阶段。核心回归：`tests/mechanics_check.gd`；双进程网络冒烟：`tools/demos/baron_minion_network.gd`。

2026-09-13 验收结果：

- 完整 mechanics 全部通过，新增四兵 × 双阵营的 8 组材质/生命周期用例通过，非法场景接口被拒绝。
- 真实 host/join：客户端记录 `on=8 off=8 passed=true`；沿用现有快照，Buff 结束后特效退出。
- Godot 4.7.1 Compatibility / Apple M5 实机：目视检查了双方八个阶段，脚下范围适配四兵、移动/攻击保持原动作、冰冻/受击覆盖恢复、到期恢复原色、死亡后无残留。最终渲染日志没有脚本或 Shader 错误。
- mechanics 退出仍有基线相同的 8 个 ObjectDB / 2 个资源未释放提示；改动前基线已存在，本轮没有增加。
- 未完成项：原版小兵专属完整粒子依赖、强化炮弹与专用音效。当前为可运行的原男爵 Buff 视觉适配，不宣称这些缺项已完成。
