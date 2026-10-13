# 虚空先知音频

[返回虚空先知](../malzahar.md)

原版Malzahar基础皮肤事件：普攻发射与真实命中各3个变体，死亡3个变体；R引导循环跟随channel动作停止，R区域循环独立持续5秒，清场/终局停止。来源和SHA256见assets/audio/units/malzahar/source_manifest.json。

wwiser使用-gv=0dB，vgmstream重新解码，无归一化。中文部署使用原版客户端选人语音（90.ogg，固定播放补偿-12.5dB）。W创建声音已由原始W_cas定义确认，接在先知每批一次的summon:start；9种原随机层组合保留4.5秒自然尾音，三只虚灵共用一次施法声。来源见assets/audio/units/malzahar/spawn_source_manifest.json；虚灵真实死亡声见[虚灵音频](voidling.md)。实际运行会播放这些事件，人工听感验收尚未完成。

主动W与被动的批次共用summon:start，均在第一只出生/裂隙开启时播放一次完整W_cas事件。原始Portal_Start/End、VoidlingSpawn及Override未另声明创建音效，不把完整施法声重复播放三次。已有9种组合保留原事件所有固定层与两个随机层；虚灵攻击和死亡声继续由各自真实事件触发。
