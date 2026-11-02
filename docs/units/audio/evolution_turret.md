# H-28G进化炮台 · 音频

[← 总览](../evolution_turret.md)

两套普攻分别使用原版HeimerTYellowBasicAttack/BasicAttack2的OnCast、OnMissileLaunch和OnHit，每个独立事件最多三个变体；出手、发射、真正命中分别触发。部署和修复使用QSpawnDestroyAudio的OnBuffActivate，死亡使用OnBuffDeactivate。没有接入英雄部署语音，不使用大炮台的引擎或强化激光音效。

源事件按0dB工具主增益重新解码，保持事件增益；死亡当前沿用通用最多1.5秒淡出加工。来源、时长与SHA-256见[事件清单](../../../assets/audio/units/evolution_turret/event_manifest.json)。收缩与展开分别使用HeimerTurretShutdown的OnBuffActivate/OnBuffDeactivate，每个事件三个变体，由权威状态变化派发一次并同步到客户端。两套攻击中相同PCM已共享文件，独立事件映射仍保留。展开与部署/修复也使用相同的三份源WEM，原版展开事件低6dB：现共享生成声WAV，由dormant:exit的-6dB播放偏移保持响度，正式资源共18份，不再保存三份低音量副本。

素材解码与触发检查不等于实际听感验收，结果见[本次记录](../../deliveries/2026-11-02_H-28G进化炮台.md)。

[← 总览](../evolution_turret.md)
