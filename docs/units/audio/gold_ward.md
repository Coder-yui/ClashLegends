# 金币守卫声音

[返回金币守卫](../gold_ward.md) · [总索引](../README.md)

默认侦查守卫出生声3个原事件随机分支、死亡声1条（2.642秒，建筑保留完整摧毁声）。无普攻及部署语音；周期产出和死亡收益复用公共金币图标/飘字及河蟹、火药桶的bounty:gain三条原版金币音效（0dB）。账户满额、实际增加为0时不播放收益提示或声音。

凝滞进入时播放中亚沙漏原始 Play_sfx_ZhonyasHourglass_OnCast（3秒），由目标凝滞音层持有，解除/死亡/清场即停止，暂停同步暂停，不叠加巴德目标音。不使用18秒的ZhonyasRingShield声冒充主动施放声。

来源为Common.wad.client，事件名由data/maps/shipping/common/common.bin核对，items_global事件及音频银行经wwiser -gv=0dB生成，再由vgmstream解码；不归一化、不额外增益。源清单见assets/audio/units/gold_ward/source_manifest.json与公共original_gain_manifest.json。

实际工作台双方部署、主动凝滞、解除、死亡已运行并录制runtime_audio.wav；主观听感仍待用户确认。
