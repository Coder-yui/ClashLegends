# fiddlesticks 音频映射

W范围持续汲取；持续层随停止攻击、控制、死亡与清场停止。不接原版W最后一跳音效，因为本卡没有最后一跳爆发。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `continuous_attack:start` | `Play_sfx_Fiddlesticks_FiddlesticksW_OnCast` |
| `continuous_attack:sustain` | `Play_sfx_Fiddlesticks_FiddlesticksWdrain_OnBuffActivate` |
| `death` | `Play_sfx_Fiddlesticks_Death3D_buffactivate` |
| `death:voice` | `Play_vo_Fiddlesticks_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。

部署使用本地客户端zh_CN-assets.wad内champion-choose-vo/9.ogg，原文件直接复制，SHA-256与原路径见../../original_gain_manifest.json。中文死亡语音亦按1.5秒上限加工。
