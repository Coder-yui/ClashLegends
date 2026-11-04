# 空投熊与提伯斯特效

[单位索引](../README.md) · [空投熊](../airdrop_bear.md) · [提伯斯](../tibbers.md)

按本机原版Skin0组织：落地使用Annie_Base_R_cas的14个发射器；脚下使用AnnieTibbers_Base_Idle_Ground的4个发射器；身体补齐body、arm、hand、leg、foot五组，各2个发射器。body挂spine1，其余左右各一处，共9个骨骼挂点。源head条目没有可绘制发射器，不伪造替代。原贴图、网格、颜色/尺寸/运动曲线与三维比例保留，眩晕复用通用状态表现。

落地与常驻灼烧的权威半径统一为100像素（2.5格）。表现由权威半径投影到地面世界空间，再以落地260、火圈280原生单位作可见环带的尺寸标定；不再使用初版的固定火圈缩放。已在正式机位把权威圆逐点投影为参考边线，同屏检查落地展开段、常驻稳定段和凝滞恢复；边线仅在诊断配方中显示。所有XYZ同比缩放，不抵消镜头产生的椭圆。火星、烟雾有自然软边，不把粒子像素作为命中判定。

预警读取权威半径，显示阵营色范围圆；先预警1秒，再下落0.5秒，预警在落地撤去。落地读取权威开始/落地Tick；地面与身体燃烧读取单位的灼烧快照，普通提伯斯不启用。骨骼名称按不区分大小写匹配原始绑定，兼容转换后的Spine1、R_Foot等名称。凝滞隐藏并暂停表现时钟；恢复后继续，死亡/清场释放，模型复用时重置挂点实例。

常驻采样按60Hz导出20秒原生模拟。前10秒保留自然启动；持续层选择前10秒出生的粒子，保留完整生命周期，并将跨边界的尾段周期拼接，而非截取某段画面整体回卷。每10秒复用同一批原生随机轨迹，接缝两侧同一粒子的位置、尺寸、颜色和纹理动画连续。ErodingSmoke源发射期3秒，含完整消散尾段仅在启动时出现，不进入持续循环。头部源空条目不接运行依赖。

每个实例持有独立表现时钟；按原bindWeight保留移动时的部分出生位置，避免所有烟火完全焊在单位当前位置。骨骼挂点火焰随姿态变化。粒子与动画均不参与伤害。

逐层miscRenderFlags的深度测试开关与预加载共用ParticleRenderPolicy。深度检查：`python3 tools/dev.py effect --provider=res://assets/effects/airdrop_bear/player.gd --variants=impact,aura,body,arm,hand,leg,foot --check-only`。共28个独立发射器定义；左右挂点复用同组资源。

原生定义、依赖和制作脚本位于开发素材库`03-制作中/空投熊/`；`prepare_body_vfx.py`提取绑定资源，`build_continuous_vfx.py`导出模拟，`periodic_vfx.py`按完整生命周期组织循环。运行资源位于assets/effects/airdrop_bear。

落地组织逐层核对14个发射器：BG、BrightShockwave、BurstNova、DarkShockwave、ErodingSmoke、Flames、Flash、Glow、Basic、scorchedGround、Temp_Ray、Temp_Ray_ALPHA、Temp_Ray2、Temp_Ray3。原版资源映射指向Annie_Base_R_cas；未另接无关的Frenzy或E护盾组。

`Flames`、地面`Flames1`和躯干`Flames`使用原`UV_MODE.lockAlpha=2`。RGB按源曲线滚动，Alpha固定在原始quad UV；原`quad_ps_fixedalphauv`不启用溶解和软粒子分支。此前错误使用普通滚动Alpha并叠加溶解，导致落地火焰层几乎空白；现已修正，并以同一机位逐层截图核对。共享着色器新增的模式默认关闭，仅空投熊播放器按源数据启用，其他卡牌保持原路径。源短促闪光/光束仅约0.17～0.27秒，不人为延长。
