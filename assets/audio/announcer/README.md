# 小兵生成与中文赛事播报

本轮接入：四种小兵的 spawn:start 共用三条 `Play_sfx_SRU_Spawn_MinionsSpawn_cast`，自动兵线与手牌部署都消费通用 attach_unit 首次生成事件，重绑不重播。两队音频覆盖均含生成池，红方炮车原 OnMissileCast 层保留。空间/Combat 总线照旧，源事件 −25 dB 保留，不自动归一化。

胜利与失败使用简体中文 Map11.zh_CN 默认 Female1 播报 `Play_vo_Announcer_Global_Female1_OnVictory / OnDefeat`，不是 VictoryBlue/Red 等按队伍播报候选。原包内部路径 en_us 是命名历史，语言由 zh_CN WAD 决定。全军出击使用 `Play_vo_Announcer_Female1_MinionSpawn`。

- 首波：20Hz 权威兵线调度在第 5 秒首次生成时派发可靠去重事件，只播一次；后续兵线只播放小兵生成 SFX。
- 结尾：_end_game 去重，根据本机胜负播放；客户端转换主机结果视角，主机胜利时客户端失败。平局没有匹配素材，暂不播放胜负播报。
- 全局 AudioStreamPlayer → Voice 总线，不受地图距离衰减；结尾可替换尚未结束的首波播报；退出场景释放声音。
- 播报不改变伤害、兵线时间、比赛判定或固定 Tick。客户端不根据本地计时器猜首波时间。

临时试听板读取 assets/audio/match_event_manifest.json，含26种事件45条播报样例，另有3条共享小兵生成 SFX。除上述3种播报外都只用于试听：欢迎/开局提示、击杀、第一滴血、双杀到五杀、连杀等级、终结、双方团灭、双方破塔、水晶兵营重生、掉线/重连。项目没有 LoL 水晶兵营重生、连杀等规则，不自行绑定这些候选。每条显示事件名、当前用途、时长，并保留拖动/选段时间标识。

来源：/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/announcer_review 中 Map11 原表与中文 Female1 BNK/WPK，WPK媒体按索引解包；wwiser -gv 0dB 导出，不做自动master增益；vgmstream保留原事件增益和完整时长。媒体ID、事件ID、hash及TXTP见 match_event_manifest.json。导入器 tools/audio/import_match_audio.py；共享初始事件导入完成后会重新执行后续接入，避免覆盖四兵生成配置。

验证：完整 mechanics 通过，覆盖4.95秒无首波播报、5.00秒恰好一次、可靠事件去重、客户端胜负反转，以及四兵双阵营3变体配置。tools/demos/match_audio_review.gd 本机主机/客户端通过：双方各收到一次 minions_spawn，主机 victory、客户端 defeat。实机录音与截图输出 /tmp/clash-match-audio；事件日志不冒充主观听感验收。
