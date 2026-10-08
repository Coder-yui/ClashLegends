# 凝滞法术特效

[返回凝滞法术](../stasis.md) · [通用投影约定](../../reference/SPELL_EFFECT_PROJECTION.md)

读取本地Bard.wad.client基础皮肤R原始定义，以120fps、种子79离线采样，在Godot按权威表现年龄重播。正式纹理、网格及逐系统来源清单在 `assets/effects/stasis/native/`。

| 系统/发射器 | 当前接入方式 |
| --- | --- |
| warning：Reticle_01 / DEcal_01 | 地面范围形状按屏幕圆校准，旋转与叠层沿用原版 |
| impact：light / nova_ground / Black_Ground / distort | 地面形状跟随范围投影 |
| impact：up_glow | 原SCB柱体底座按范围投影，竖直高度保留原比例 |
| impact：Energy1 / cast_orbit / symbol / spark_shoot_up / spark_circle_ground | 中心分布映射范围，粒子自身尺寸、朝向保留原版，不整体拉伸符文和火花 |
| flight：stars / Basic | 原绑定粒子随弹体；原版Basic纹理作为光球主体，不额外叠加自制亮核 |
| flight：lingers / flat / flat1 | 根据原始出生时刻保留世界空间位置，不随当前弹体整体移动 |
| flight：Basic1 / Basic2 | 原ArbitraryTrail，以活粒子构造连续带状网格；原纹理、颜色、宽度和寿命 |
| 金身 | 通用模型附着两层与权威姿势冻结，沿用模型变换 |

范围层XZ采用相机反投影，Y保留世界竖直和原版相对尺度；面向相机的粒子保持原Billboard尺寸。飞行采用独立单位换算（110/350屏幕像素每源单位），不随法术范围或俯角额外拉伸；水晶至落点的项目弧线独立于粒子局部坐标。

原版采样额外保留粒子出生时刻，结合bindWeight将未绑定粒子放在历史弹体位置，形成自然遗留微粒和拖尾。两条原Trail采用Godot带状几何适配，保留曲线和纹理，不宣称LoL拖尾平滑、细分、UV平铺和cutoff算法逐项一致。当前统一金色预警，没有完整移植敌我预警切换或LoL运行器。

权威抵达Tick切换爆炸；爆炸尾迹保留2秒，普通凝滞3秒、强化友军2秒。特效不决定范围、伤害、状态或音频时长。暂停时表现年龄停止，抵达、清场和终局回收特效。

金身使用原版Bard swirl与中娅swirl两层：Temp_Avatar放大1.02、UV纵向每秒滚动0.4；Gold_Avatar1放大1.01；透明度0.700008²。防御塔沿用原裁切shader，碎块独立。原版特殊英雄子网格过滤、金身入退场曲线及附着周边发射器未扩展。

旧2D纹理和被替代的自制飞行亮核/短尾均移回本地制作源件，运行目录只留当前依赖。制作、验证和限制见[同一任务记录](../../deliveries/2026-10-08_凝滞法术原版特效重制.md)。

本局卡组包含此法术时，纹理由MatchResources提前收集，加载阶段通过SpellEffectWarmup实际绘制完整时序样本，保留材质/网格后清理样本；原生JSON进入导出包。见[加载职责](../../MAINTENANCE_ARCHITECTURE.md#法术加载与绘制准备)。
