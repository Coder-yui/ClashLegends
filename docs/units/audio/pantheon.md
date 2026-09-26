# 潘森声音

[返回潘森](../pantheon.md) · [总索引](../README.md)

| 时机 | 原版声音 |
| --- | --- |
| 预部署开始 | RMissile3发射；0.2秒R_land插地与RMissile俯冲 |
| 后方3格着地与滑行 | 0.65秒R_buffactivate + R_impact，1.3秒到点R_shockwave |
| 实体拿起长矛 | 无额外落地声音；前段自然尾音继续 |
| 普攻出手 / 真命中 | BasicAttack → BasicAttack2 → BasicAttack3 → BasicAttack2，对应OnCast / OnHit |
| 普通短Q开始 / 真命中 | QTap_cast_lua / QTap_hit_vfx |
| 满怒短Q开始 / 真命中 | QTap_cast_empowered_lua / QTap_hit_empowered_vfx |
| 红怒由未满进入4层 | PantheonPassiveReady_OnBuffActivate |
| 死亡 | Death3D原生SFX + 中文Death3D语音，分别走Combat / Voice |

满怒提示复用通用resource_full事件：普攻或三层普通Q叠满时触发一次，满层继续攻击不重播，消耗后重新叠满可以再次触发；未携带技能不响。双方均消费已同步的资源状态。短Q命中声只跟随0.30秒真实命中，不在起手或空刺时伪造命中。

已接入36个WAV（33个SFX、3个中文语音）。一条R登场成品由六个原始TXTP浮点解码事件组合，撞地声位于0.65秒后方着地，收尾冲击波声位于1.3秒到点；总长3.45秒含尾音。保持音高和原始采样速度，整条混音统一-4.797360dB，峰值约-1dB，末0.12秒淡出。音轨不驱动模拟。

其余原SFX保留既有统一-2.320351dB量化前加工；死亡SFX遵循前1.5秒包络，中文语音保持既有0.8秒加工。

来源为本地只读LoL基础皮肤SFX及中文VO。不接走路、蓄力、投矛或大招起跳音。源事件、媒体、加工和哈希见[素材记录](../../../assets/audio/units/pantheon/README.md)。原生Wwise实时RTPC、滤波与未知材质Switch未完整复现，不能将所选Switch声称为指定材质。

实际运行已核查双方事件、录制混音并本机播放；听感仍待用户确认。

登场统一使用pre_deploy:start，移除潘森的deploy:start落地音轨；纯特效节点不创建播放器。清场、结束与暂停由通用音频管理器处理。
