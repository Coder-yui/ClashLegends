# 剑魔本地音频源

批量提取的bank、WEM、TXTP保留本地，不提交。外部源包只读：LOL_Asset_Source/Game/DATA/FINAL/Champions/Aatrox.wad.client（音效）及Aatrox.zh_CN.wad.client（中文语音）；客户端中文英雄禁用语音来自LeagueClient/Plugins/rcp-be-lol-game-data/zh_CN-assets.wad。

复用tools/audio/prepare_lol_card_audio.py准备事件素材，台词定位用tools/audio/find_lol_voice.py。en_us内部路径是源包命名，不代表提取内容语言；中文来源以WAD语言包为准。最终事件、媒体编号和哈希见运行assets/audio/units/aatrox/event_manifest.json及相邻voice-selection/selected.json。
