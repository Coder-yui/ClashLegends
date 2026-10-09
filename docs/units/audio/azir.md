# 沙漠皇帝 · 音频接入

[← 返回沙漠皇帝](../azir.md) · [总索引](../README.md)

| 时机 | 当前声音 |
| --- | --- |
| 部署语音 | 原版中文客户端选人语音，原始OGG |
| 两段普攻出手 | 基础皮肤BasicAttack与BasicAttack2原生cast，各1个 |
| 两段真实命中 | 对应OnHit事件，每段2个随机变体 |
| 沙兵召唤 / 转化 | 实际生成的士兵播放W出生声，生成圆盘则播放圆盘出生声；施法者不重复叠加 |
| 死亡 | 基础皮肤Death3D音效，按通用死亡包络处理 |
| 走路 | 有意静音 |

源银行只读；wwiser显式0dB，重新vgmstream解码，不逐文件归一化。事件音量0dB，沿用通用总线压缩与限幅。命中声仅在攻击节点直接结算有效时发生，与纯表现光束同刻触发。

[来源和处理](../../../assets/audio/units/azir/README.md) · [逐文件清单](../../../assets/audio/units/azir/event_manifest.json)
