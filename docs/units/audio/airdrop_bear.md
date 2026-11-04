# 空投熊音频

[单位索引](../README.md) · [空投熊](../airdrop_bear.md) · [提伯斯音频](tibbers.md)

采用A方案：公共0.5秒等待及随后1秒预警期间不播放R主音效；提伯斯开始下降时播放安妮R的OnCast（3变体），0.5秒后落地播放OnHitLocation（1个）。保留原版事件增益，不添加安妮语音。来源为本机Annie基础皮肤SFX银行，wwiser明确使用-gv=0dB，每次重新解码；具体文件与媒体见assets/audio/units/airdrop_bear/event_manifest.json。

强化落地额外播放 `AnnieR_tibbers_enraged_buffactivate`（3变体），与攻速增益获得同一权威Tick触发，通过可靠卡牌事件派发。普通落地不播，凝滞解除、攻速到期也不重播。它是一次性获得音，常驻燃烧另由提伯斯的持续音层管理；没有借用安妮其他技能声音补结束音。
