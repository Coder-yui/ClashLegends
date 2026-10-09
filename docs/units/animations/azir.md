# 沙漠皇帝 · 动画接入

[← 返回沙漠皇帝](../azir.md) · [总索引](../README.md)

使用用户指定沙漠皇帝GLB，源坐标量级为百单位，包装统一缩放0.011。源皮肤没有默认隐藏子网格，仅一个Azir_Mat材质；Buffbones为原生默认静态辅助动作。

部署使用Respawn原片前6秒，以3倍速压缩到2秒；权威部署时间同步设为2秒（40Tick）。待机Idle1_Base，移动Run，普攻Azir_Attack1_anm与Azir_Attack2_anm循环，W使用Azir_Spell2_anm（0.8秒），死亡Death（表现持续1.2秒）。

两种攻击原片均2.3秒；原始azir.bin的AttackSlotData明确指定1.6秒周期和0.25秒出手。前0.25秒按原速播放，剩余动作映射到1.35秒收势，分段处无混合跳变。不能将原版出手时间再按完整片长压缩。权威第5Tick直接结算伤害，动画不驱动伤害。

原始animations/skin0.bin中两套Attack的CAST事件均位于第1帧（30fps下约0.033秒），绑定weapon骨骼，分别调用Azir_BA_cas和Azir_BA2_cas。表现包装在对应动作到达此处时播放原版起手层；命中事件再播放光束和目标受击层。光束起点沿用模型原生Buffbone_Glb_Weapon_1武器端挂点；原包未包含可验证其原游戏脚本端点选择的证据，不据此宣称完全一致。

W原片0.8秒；原始AzirW与AzirWSpawnSoldier给出mCastTime=0.25及castFrame=7.5，动画图Spell2没有额外召唤事件。当前第5Tick生成四兵与该时点一致，完整施法锁0.8秒；士兵自身随后经历默认1秒部署。

部署结束到Run使用0.18秒姿态混合，到两种普攻使用0.12秒混合，到Idle1_Base使用0.18秒混合。混合不延长部署锁；普攻内部切片继续保持零混合。Respawn原片长度10.5秒，`deploy_clip_ratio=6/10.5`。

同场以艾希和黄沙士兵核对主体大小、脚底与朝向。素材、源哈希与验收见[模型记录](../../../assets/units/azir/README.md)。
