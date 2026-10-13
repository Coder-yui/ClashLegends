# 虚灵音频

[返回虚灵](../voidling.md)

使用MalzaharVoidlingBasicAttack原版近战挥击和命中事件，各3个变体。挥击沿普攻动作，命中只在真实结算播放；空挥和取消不伪造命中声。原始事件保持0dB工具主增益。

死亡使用原版Play_sfx_Malzahar_MalzaharVoidling_buffdeactivate，原始Malzahar_Base_W_Voidling_Death.soundOnCreateDefault直接声明。两组随机层3×2形成6种组合，保留原节点增益，工具主增益0dB、无归一化；按统一死亡音频规则超过1.5秒则保留前1.5秒并在1–1.5秒淡出。仅真实死亡事件播放，来源见assets/audio/units/voidling/death_source_manifest.json。

W施法声属于先知的每批召唤，虚灵自身不再播放spawn:start。蓝红运行中6只虚灵真实死亡触发6次死亡声；素材实际播放与音频入口已检查，人工听感尚待用户确认。
