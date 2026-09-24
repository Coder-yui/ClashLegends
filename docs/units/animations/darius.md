# 德莱厄斯动画

[返回德莱厄斯](../darius.md) · [总索引](../README.md)

使用用户提供的“诺克萨斯之手.glb”。稍大体型21px，包装缩放0.013125；表现比例不参与权威碰撞。

| 时机 | 原片段与处理 |
| --- | --- |
| 部署 / 待机 | Idle1；无专用部署动作，使用待机回退 |
| 移动 | Run |
| 普攻 | Attack1、Attack2循环，整段等比缩放到1.2秒，统一0.30秒前摇 |
| 断头台 | Spell4，整段缩放到1.2秒，原生节点映射为0.33秒 |
| 死亡 | Death，表现窗口1秒 |

## 原生节点依据

本地原始库 `Darius.wad.client` 的 `data/characters/darius/darius.bin`：DariusBasicAttack castFrame=11、mCastTime=0.3667；DariusBasicAttack2 castFrame=9、mCastTime=0.3；DariusExecute（mAnimationName=Spell4）castFrame=11、mCastTime=0.3667。由对应帧/时间确认30fps。提取记录在开发素材库 `03-制作中/德莱厄斯/hit-timing-source/`。

| 动作 | GLB时长 / 30fps等效帧长 | 原始节点 | 缩放到1.2秒后的节点 |
| --- | --- | --- | --- |
| Attack1 | 1.333333秒 / 40 | 11 / 30秒 | 0.330秒 |
| Attack2 | 1.566667秒 / 47 | 9 / 30秒 | 0.229787秒 |
| Spell4 | 1.333333秒 / 40 | 11 / 30秒 | 0.330秒 |

按用户要求，普通攻击不随动作改变前摇，统一近似取0.30秒（距两段映射值分别30ms和约70ms）；不修改1.2秒攻击间隔。强化下一击单独使用0.33秒，20Hz首次起手在第7Tick结算；普攻第6Tick。攻速倍率同时缩放前摇、间隔和整段动作。

断头台生效时取消旧前摇、后摇及攻击冷却，从完整0.33秒劈砍前摇重新起手；从当前姿势混合到Spell4，结束接回普攻/移动。规则与公式见[命中节点映射](../../reference/ANIMATION_CONFIGURATION.md#原生命中节点映射)。
