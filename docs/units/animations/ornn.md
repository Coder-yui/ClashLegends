# 奥恩 · 动画接入

[← 返回奥恩总览](../ornn.md) · [总索引](../README.md)

## 已使用动作

动作名保留 GLB 原片段大小写；战斗只用完整 GLB 中的模型和动作。

| 看到的动作 | 素材片段 | 原片时长 | 使用方式 |
| --- | --- | --- | --- |
| 部署 | `Respawn` | 1.467 秒 | 对齐项目1秒部署展示 |
| 待机 | `Idle1_Base` | 3.967 秒 | 循环 |
| 移动 | `Run_Base` | 1.033 秒 | 循环 |
| 普通攻击 | `Attack1` / `Attack2` / `Attack3` | 2.133 / 2.200 / 2.133 秒 | 三段按顺序轮换，命中时序仍由固定Tick决定 |
| 蓄力 | `Spell3` | 原片片段 | 对齐0.35秒蓄力，禁止位移 |
| 冲锋 | `Spell3_Dash` | 0.433 秒 | 对齐0.5秒权威冲锋 |
| 停顿 | `Spell3_Hit` → `Spell3_hit_toIdle` | 0.333 / 1.533 秒 | 分别对齐0.3 / 0.25秒；提前碰撞直接进入停顿 |
| 死亡 | `Death` | 原片4.300秒 | 项目使用1秒死亡表现 |

动作、特效和音频都不能决定冲锋位移、碰撞或伤害。未撞到障碍时不播放 Spell3_Hit，使用0.2秒 Idle1_Base 混合收势，无爆炸伤害或范围标识。

## 普攻命中节点映射

从只读的本机 `Ornn.wad.client` 原包提取 `data/characters/ornn/ornn.bin`，配置中的 `OrnnBasicAttack`、`OrnnBasicAttack2` 和 `OrnnBasicAttack3` 均带 `castFrame=8.5`；攻击循环绑定的命中节点一致。GLB 中对应三段分别有65、67、65个采样点，时长与30fps吻合。按 [原生命中节点映射规则](../../reference/ANIMATION_CONFIGURATION.md#原生命中节点映射) 使用 `8.5 ÷ 30 ÷ 原片长 × 2秒攻击间隔`：

| 动作 | 节点秒数 | 映射前摇 |
| --- | ---: | ---: |
| `Attack1` | 0.2833 | 0.2656 秒 |
| `Attack2` | 0.2833 | 0.2576 秒 |
| `Attack3` | 0.2833 | 0.2656 秒 |

多段共用近似前摇0.26秒，最大差约0.0056秒。20Hz模拟在越过该节点的第一个Tick结算命中；`mCastTime=0.3667` 不是这三段攻击对应的 `castFrame` 命中节点。

## 来源与观看

- [模型包装场景](../../../assets/units/ornn/ornn_view.tscn)
- [用户提供的完整 GLB 和依赖](../../../assets/units/ornn/README.md)
- 原生节点源：本地素材库 `ClashLegends-开发素材库/04-中间产物/奥恩/2026-09-27/ornn_native_data/ornn.ritobin`；原包仅读。

进入“卡牌开发工作台”查看奥恩模型，再连续观察部署、三种普攻、冲锋撞击和退出移动。重点确认脚底贴地、锤子没有穿插、移动方向正确以及蓄力、冲锋、停顿依次播放。

[← 返回奥恩总览](../ornn.md)

## 原生 E 组织方式复核（2026-09-28）

本地原生 `animations/skin0.bin` 独立定义 Spell3（GLB 0.5333秒）、Spell3_Dash（0.4333秒）、Spell3_Hit（0.3333秒）、Spell3_hit_toIdle（1.5333秒），BlendDataTable 用 TransitionClipBlendData 引用最后一个片段。Dash 上的 E_fs 是脚步声音节点，不能充当伤害节点。

原始 OrnnE 定义记录 DashRange=650、DashSpeed=1600（约0.406秒）、mCastTime=0.35、spellCastTime=0.25；它们是原版世界单位及不同时间字段，不能整套直接复制到本项目。当前按3.5格适配0.5秒冲锋，动作由权威分段驱动；碰撞立即进入Hit分支，未碰撞走短收势。客户端同步动作序号和权威时钟。

普通攻击再次核对三个 SpellObject 的 castFrame 均为8.5，GLB 三段按30fps采样，沿本项目整段缩放得到0.2656 / 0.2576 / 0.2656秒，公共前摇0.26秒保持。20Hz结算在跨越节点的Tick执行（通常0.30秒），动画不回写伤害。E路径命中是扫掠首次接触，范围命中是地形碰撞当Tick，均不绑定动画脚步或结束帧。
