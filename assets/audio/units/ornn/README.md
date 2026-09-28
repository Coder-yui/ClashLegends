# 奥恩音频来源

部署使用本地 `LeagueClient/Plugins/rcp-be-lol-game-data/zh_CN-assets.wad` 中 `plugins/rcp-be-lol-game-data/global/zh_cn/v1/champion-choose-vo/516.ogg`，台词“好吧，我们走。”。解码PCM16，不剪辑、不归一化。

锻造使用原生 `Play_sfx_Ornn_OrnnP_forging`，事件3114075896，声音848756079，媒体515457883，基础皮肤SFX银行。wwiser事件图 → vgmstream完整事件解码 → PCM16，保留5.398秒原声。此前 allypurchasesitem_stinger_ornnonly 为购买提示，已退役。

三段普攻出手/真实命中、E起手与碰撞爆发、死亡保留原映射；本轮按用户要求接入E_fs脚步、EKnockAway路径命中、EKnockUp范围受击，范围仍造成眩晕。退役重生池、购买提示与路径击飞声归档到本地素材库“奥恩二轮/退役音频”。来源逐文件见 [清单](event_manifest.json)，当前用途见 [单位音频页](../../../../docs/units/audio/ornn.md)。通用银行导入计划不能恢复客户端选人语音，不可整批覆盖。

2026-09-28峰值复核：原事件浮点峰值最高+1.943dB，前次直接PCM16造成截断。全部21个SFX重新按原始TXTP解码为浮点，统一降低3dB再转PCM16，保持事件之间相对层次；语音保持原处理。

部署随机池补充：中文客户端禁用语音 `champion-ban-vo/516.ogg` 为“回炉去了。”；本地 `Play_vo_Ornn_OrnnP_allypurchasesitem` 的 r7 为“奥恩出品，必属精品。”，原台词目录与本地转写相互核对。三个文件独立进入deploy:voice随机池。

四轮补充：成功增幅抵达使用通用HUD `Play_sfx_hud_store_buy`，事件1989001022、媒体41429280，来自 Common.wad.client/hud_global_audio.bnk。新增SFX沿用浮点解码降低3dB转PCM16。锻造在发锤前3.6秒播放并接受眩晕/冰冻/凝滞取消。
