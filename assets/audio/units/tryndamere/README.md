# 蛮族之王音频来源


> 客户端部署语音混音例外（2026-10-04）：`deploy_1.ogg` 固定播放 -18.5 dB。原素材不变，同池游戏内语音仍为 0 dB；此说明优先于下文历史的“全部播放补偿为 0 dB”。

> 2026-10-04 原版增益重导：当前文件与加工参数以 `assets/audio/original_gain_manifest.json` 为准；下面历史文字中的额外增益、制作余量及旧哈希说明已被本次重导替代。工具主增益、后期固定增益和事件播放补偿均为 0 dB；原事件内部增益保留。


只读原包：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/Tryndamere.wad.client`及`Tryndamere.zh_CN.wad.client`。prepare_lol_card_audio.py与find_lol_voice.py还原Wwise事件，vgmstream-cli以float渲染（防止提前削波），全组统一衰减2.216dB后由ffmpeg转PCM16，峰值不高于0.89；仅死亡截到1秒并在0.8秒开始0.2秒淡出，其他音轨未裁剪、未改音高。

源银行、TXTP和未采用变体留在素材库`03-制作中/蛮族之王/audio`与`deploy_voice`。source_manifest.json登记33个输出及来源哈希。

[当前声音与验证范围](../../../../docs/units/audio/tryndamere.md)。

三句部署语音：LCU中文选人23.ogg、Attack2DGeneral r4、r3。完整播放，不截断到1秒部署动画；互斥Voice规则仍由统一音频管理器控制。旧的单句部署语音已退出运行资源。
