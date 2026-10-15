# 虚空迅捷蟹：特效

[返回单位](../void_scuttle_crab.md) · [总索引](../README.md)

死亡及主动自尽使用原版 Skin05 的 Z_VisionRing_Green/Red、antenna_wake，区域中心由 Skin05 原单位骨骼连续播放沉没、run_toground、spawn、idle及tohide，沿用1.25缩放与死亡朝向，包含蟹耳朵。按观察者阵营切换圈色，以150像素权威半径缩放，第2秒开始展开、第4.8秒开始持续6秒的治疗，不附加加速或视野。

敌方实际收到赏金时，在死亡位置显示上浮“+2”及其后紧接的金币UI图标（不足2时显示实际入账值），持续1.2秒。自尽、清场、满金币没有收益提示。表现使用可靠固定区域事件 gold_reward，team 为受益方；音频使用可靠卡牌事件 bounty:gain。祭坛使用 scuttle_void_shrine，声明 Skin05 粒子与完整死亡序列模型依赖。均不改变快照布局。

按用户反馈停用原版 Ward Shadow 黑影层，仅保留圈、中央波纹和蟹耳朵。
