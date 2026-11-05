# graves 音频映射

普攻发射/真实命中、换弹开始/完成、快速拔枪、死亡语音。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_hit` | `Play_sfx_Graves_GravesBasicAttack_OnHit` |
| `attack_launch` | `Play_sfx_Graves_GravesBasicAttack_OnMissileLaunch` |
| `reload:start` | `Play_sfx_Graves_GravesBasicAttackSpread_reload_open` |
| `reload:end` | `Play_sfx_Graves_GravesBasicAttackSpread_reload_close` |
| `active:start` | `Play_sfx_Graves_GravesMove_OnCast` |
| `death` | `Play_vo_Graves_Death3D` |
| `deploy:voice` | 移动事件r8、中文客户端104号选人语音（单条播放补偿−18dB）、移动事件r6 |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。
