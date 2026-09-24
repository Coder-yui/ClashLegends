# 赛恩原版音频

来源：本地LOL_Asset_Source/Game/DATA/FINAL/Champions/Sion.wad.client与Sion.zh_CN.wad.client，外部源包只读。wwiser恢复事件分支，vgmstream-cli -i解码PCM16并保留事件增益；中文部署候选经float WAV转PCM16，不做逐文件归一化。最终死亡中文语音取前0.8秒，最后0.2秒淡出；Death3D_cast音效取前2.5秒无变调压缩至0.8秒，末尾0.1秒淡出，分别接death:voice与death。复生开始用PassiveDelay，2秒后开启PassiveZombie；不接PassiveSpeed加速事件。

文件、原事件、变体、哈希和加工见event_manifest.json。部署三句由原事件文字索引与本地转写定位；verified_by_listening字段不宣称人工确认。护盾/狂暴原版持续循环跟随对应状态，破盾单独播放原版解除声；清场与死亡释放全部音轨。
