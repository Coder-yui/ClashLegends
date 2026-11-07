# 虚空遁地兽音频

[返回单位](../reksai.md) · [总索引](../README.md)

普通攻击两段分别使用原版BasicAttack/BasicAttack2 OnCast，实际命中播放BasicAttack OnHit；强化三击依次使用QAttack、QAttack2、QAttack3的OnCast/OnHit，实际施放播放Q OnCast（刷新也播放），强化状态获得与消耗完毕分别播放Q OnBuffActivate / OnBuffDeactivate。出土播放W buffdeactivate，实际击中播放W hit。死亡包含Death3D_cast音效和zh_CN Death3D咆哮，两者均执行最长1.5秒包络。

全部事件由wwiser显式0dB生成、重新解码，保留原事件增益；每池最多3个变体，不逐文件归一化。来源与SHA-256见[资源清单](../../../assets/audio/units/reksai/event_manifest.json)。部署咆哮选用Move2DStandard事件的3个原始变体；地下路径使用原版W movement_trail持续声，按用户反馈增加12dB播放增益，音源跟随同一曲线；抵达、取消、清场和终局停止，工作台暂停时暂停。地上普通行走无持续声。47项事件变体中12项PCM及导入参数相同，合并为35个文件，原事件身份保存在equivalent_sources。

实战试听状态见[交付记录](../../deliveries/2026-11-07_虚空遁地兽新卡.md)。

正式目录35个WAV均有实际事件引用；没有接入未使用的E、R或地上行走声音。
