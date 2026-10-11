# 训练木桩 · 余震表现

[返回建筑卡](../target_dummy.md) · [总索引](../README.md)

使用 `Global.wad.client` 无扩展名 `perks` 条目中的原版 `Perks_Aftershock_Buff` 与 `Perks_Aftershock_AOE` 定义。按原始发射器、网格、颜色/尺寸/UV曲线、侵蚀和混合模式采样并在Godot重播，不再用两张贴图拼接爆炸，也不加入自制裂纹或岩块。

- 护体六层：`RimLighting` 附着实际模型蒙皮网格；`decalOuter`、`decalInner`、`lightRays`、`decalGlow`、`decalGlow1` 由原版播放器消费。附着层使用原版纹理、采样颜色/UV、白色反射图与Fresnel参数。
- 爆炸八层：`GroundCracks`、`splosionFlash`、`lightRays`、`circleOut`、`GroundCracksShadows`、`GroundCracksGlow`、`smoke`、`DarkChunks`。两种原生SCB网格、烟尘乘色纹理、地裂侵蚀与逐层混合分别保留。
- 主冲击波原生外沿为163.89645×1.9＝311.40326源单位，投影到110像素权威半径；地面分布适配战场圆形范围，竖直高度与面向相机的粒子保持源比例。护体与爆炸按同一原始尺度比整体缩放。
- 爆炸显示1.8秒，覆盖原版最长约1.7秒的地面阴影尾迹；80伤害仍只在2.5秒减伤结束时结算一次。目标身体与110像素范围相交即命中。

表现只读取权威/快照状态与已派发的范围事件。凝滞隐藏护体但年龄继续，解除不重播启动闪光；到期、死亡或清场隐藏。死亡和凝滞到期沿用既有取消爆炸规则。原版粒子不驱动伤害或战斗时钟。原版Buff末尾受2.5秒权威状态窗口裁切，避免状态到期后仍显示护体。

卡牌声明护体场景与两个效果提供器；八层爆炸和五层独立护体粒子逐层预热，附着网格材质随模型预热。原始定义、依赖、加工脚本和哈希保留在开发素材库；正式运行数据在 `assets/effects/aftershock/native/`。

[资源与加工记录](../../../assets/units/target_dummy/README.md)
