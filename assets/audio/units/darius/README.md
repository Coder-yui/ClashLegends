# 德莱厄斯原生音频来源

来源：只读本地`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/Darius.wad.client`和`Darius.zh_CN.wad.client`；基础皮肤事件由wwiser还原，vgmstream浮点解码，FFmpeg转PCM16。

部署语音来自Play_vo_Darius_Move2DStandard的r3/r4/r1，依次对应“诺克萨斯即将崛起。”、“懦弱之举，我绝不姑息。”、“我将死战不休。”。公开台词元数据仅用于定位事件；最终声音来自本地中文包。银行内部en_us路径不代表实际语言，中文包和本地ASR共同核对。`verified_by_listening: false`保留人工未确认状态。

34条选定资源全部有配置消费者。原浮点SFX最大峰值1.233859，统一衰减2.837511dB后峰值不超过0.89；保留原事件和随机变体相对响度，不逐文件归一化。语音保持原增益。加工源、TXTP、输出哈希与台词见[event_manifest.json](event_manifest.json)。

本地制作材料与候选：项目素材库`03-制作中/德莱厄斯/`。双阵营实战录音及截图位于素材库`04-中间产物/预览与验证/1790089034-99978/darius-review/`。

[单位音频手册](../../../../docs/units/audio/darius.md)
