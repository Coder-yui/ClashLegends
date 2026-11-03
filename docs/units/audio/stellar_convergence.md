# 星芒凝汇音频

[← 返回卡牌](../stellar_convergence.md)

| 事件 | 原版E声音 | 生命周期 |
| --- | --- | --- |
| 施放 | E_OnCast | 出牌结算时一次 |
| 区域持续 | E_buffactivate_aoe_other | 独立区域持有，持续5秒，短音轨循环 |
| 首次命中 | E_hit_start（3个随机变体） | 每个区域对每个目标首次实际命中后一次；护盾吸收算命中，免疫不算 |
| 成功斩杀 | EDebuff_buffdeactivate | 中心斩杀成功时一次，保留完整技能尾音 |
| 区域结束 | E_buffdeactivate | 自然到期播放；清场直接停止 |

原TXTP重新解码，源事件增益0dB基准，不归一化。没有英雄手部与飞行弹体，未引入对应事件；原版Execute_Player粒子明确绑定EDebuff_buffdeactivate，本卡将它用于成功斩杀。hit_start按本卡持续区域改造为每目标首次受击声，避免每0.25秒重复；StackProc绑定的hit_wave属于原版叠层反馈，本卡未引入，目标吸附循环EDebuff_hit_loop也未额外叠加。原版self/other空间分支本卡使用场地other版本。逐文件与事件映射见[资源清单](../../../assets/audio/units/stellar_convergence/event_manifest.json)。实际试听状态见交付记录。
