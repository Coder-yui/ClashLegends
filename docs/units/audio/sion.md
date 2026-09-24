# 赛恩音频

[返回赛恩](../sion.md) · [狂暴](../sion_berserk.md) · [总索引](../README.md)

使用本地LoL基础皮肤SFX和中文语音银行。素材、变体及加工记录见[来源清单](../../../assets/audio/units/sion/event_manifest.json)。

| 时机 | 内容 |
| --- | --- |
| 部署 | 随机“战斗，爽。”“粉碎吧。”“垂死之人的喧闹。”三选一 |
| 常态挥斧 / 命中 | 原版建筑攻击Tower2 → Tower两段各3种随机变体，与动画顺序一致 |
| 护盾开启 / 爆炸 | 原版W获得盾与命中事件 |
| 致死复生 / 狂暴开始 | 原版PassiveDelay与PassiveZombie启动声 |
| 狂暴拳击 / 命中 | 原版被动两段攻击各3种随机变体 |
| 最终死亡音效 | Death动画事件Play_sfx_Sion_Death3D_cast，前2.5秒无变调压至0.8秒、末尾0.1秒淡出 |
| 最终死亡语音 | 原版PassiveZombie_OnBuffDeactivate中文事件，独立death:voice层，截取0.8秒、末尾0.2秒淡出 |

三句台词以公开文字事件索引和本地MLX转写定位；转写不等同人工听感确认。走路声按项目约定不接。第一次死亡使用PassiveDelay事件，2秒后才触发PassiveZombie开启与狂暴循环；第二次死亡停止循环并同时播放Death动画音效和被动结束语音。未配置加速技能，因此不接PassiveSpeed_OnCast。普攻OnCast池随出手启动，OnHit池只跟随真实结算命中，按建筑攻击/被动拳击及两段选择。

已接入护盾循环、破盾声音及狂暴常驻循环，按独立盾层与狂暴生命周期停止。实际渲染、混音回放和检查结果见交付报告；用户听感尚未确认。

2026-09-23复核本地Wwise银行：PassiveDelay的SFX与中文VO均无事件延迟，首次致死同步开始；此前漏接的VO（649009447，2.890秒）已补齐。PassiveZombie OnBuffCast同样无额外延迟，在本项目2秒等待结束时触发；OnBuffActivate循环同时进入，按原版ActionPlay的250毫秒TransitionTime线性淡入，结束按Stop事件500毫秒淡出。暂停冻结渐变，清场立即清理尾音。PassiveDelay三种SFX长2.302～2.410秒，保留自然尾音，与2秒后的启动声短暂重叠，不截断或挪到复生结束才播放。声音银行可验证事件内部时序；游戏Buff的2秒切换采用本项目约定，并非从声音文件长度推断。
