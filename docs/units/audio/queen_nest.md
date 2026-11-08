# 女王巢穴音频

[返回女王巢穴](../queen_nest.md) · [总索引](../README.md)

洞穴部署使用原版E结束音（endsound），摧毁使用原版E洞穴摧毁音；各选一个变体。主动唤醒播放一次原版W遁地强化语音（Play_vo_Reksai_RekSaiW_OnBuffActivate，用户选定1.68秒r1）。唤醒当刻不播放摧毁声；之后空巢被摧毁，仍播放与未唤醒洞穴相同的完整摧毁音。

巢穴被摧毁后出生的普通雷克塞复用雷克塞卡牌完整W破土声音池（3个变体，每次播放一个），不播放W命中声和额外部署语音。原版Respawn的RespawnParticle引用RekSai_Burrowed_W_cas，其皮肤映射绑定Play_sfx_Reksai_RekSaiW_buffdeactivate，因此不使用英雄选择音作为替代。普通攻击和死亡沿用现有雷克塞；主动唤醒的雷克塞没有部署音，Q前两段挥击声音循环，真实命中才播放命中音。死亡音效及语音复用已有1.5秒上限处理资源。

新增声音保留事件原增益，播放0dB，无归一化。来源见[清单](../../../assets/audio/units/queen_nest/event_manifest.json)。已在实战触发并录音；主动语音和Respawn复用方案已由用户确认。
