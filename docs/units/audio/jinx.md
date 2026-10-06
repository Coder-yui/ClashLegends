# 金克丝音频

[返回金克丝](../jinx.md) · [轻机枪](../jinx_minigun.md) · [总索引](../README.md)

使用本地Jinx基础皮肤SFX、zh_CN语音银行及共享init.bnk，通过wwiser显式-gv=0dB生成完整事件，vgmstream重新解码，无后期音量归一化。19条正式声音逐文件来源与哈希见assets/audio/units/jinx/source_manifest.json。

| 发生时机 | 声音与归属 |
| --- | --- |
| 部署 | Respawn动画图明确绑定Jinx_Respawn3D_buffactivate；原2.801秒音效按2.5667倍保调变速约1.10秒，对齐1秒部署并保留尾音；不再播放英雄部署语音 |
| 火箭发射 / 命中 | JinxQAttack_OnMissileLaunch三变体 / JinxQAttack_hit三变体；命中声只在真实命中播放 |
| 机枪发射 | JinxBasicAttack_OnMissileLaunch三变体；使用独立机枪音色 |
| 切换武器 | 转火箭使用JinxQ_OnBuffActivate，转机枪使用JinxQIcon_OnBuffActivate；归属transform动作，冰冻/凝滞停声且不续播，眩晕/击退继续 |
| 罪恶快感 | JinxPassiveKill_OnBuffActivate；获得时一次，刷新不重播，跟随单位位置，到期/死亡/清场停止；冻结与凝滞不截断已有Buff声音 |
| 死亡 | 中文Death3D三变体，按通用规则截至1.5秒，1秒后线性淡出 |

已发弹体的发射与命中声保持出手形态，不被换枪改变。机枪命中选用原OnHit的Flesh三变体（Wwise FNV1哈希1153642577）；当前通用命中声音接口不区分目标材质。走路有意静音。实际对局播放和录音用于核对事件与清理，主观混音仍待用户试听。
