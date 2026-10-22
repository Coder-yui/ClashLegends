# 熔岩巨兽特效

[返回单位](../malphite.md)

原版E施放6层、范围冲击8层、护盾获得6层、破盾4层由源BIN提取，以120Hz采样播放；使用源贴图、网格、颜色与UV曲线及逐层深度标志。采样播放器是源数据的Godot重建，不等同Riot运行时。

模型及被动粒子使用0.0085×2.50÷1.75≈0.0121429换算；E的施放与地面冲击使用独立等比缩放0.01，以匹配160像素圆形范围。XYZ等比，projection_basis恒为单位基；斜视自然呈椭圆，正上方呈圆形，不作镜头补偿。伤害仍独立由2D权威结算。

源护盾常驻状态是动态材质：有盾使用原版malphite纹理，破盾切换malphite_base_z_malphite_molten纹理；获得护盾叠加短时Avatar附着层，破盾播放独立碎石。当前使用Godot基础材质完成源贴图切换，原动态材质的屏幕空间流火和Fresnel图尚未重建，不能视作完整材质一致。

受影响目标的移速/攻速提示复用通用软控特效，不另建英雄专属减速提示。死亡和模型回池清理附着层；落地冲击独立播放至结束，清场清理。

## 原生组织核对

| 系统 | 启用层 | 起点与时序 | 归属与移动 |
| --- | --- | --- | --- |
| E_cas | Trigger_2、Trigger_3、RingSmoke、clods、flame_up、spout | Spell3第8帧，原31fps；映射0.65秒动作约0.274秒；R_BUFFBONE_GLB_HAND_LOC的事件帧位置与旋转 | bindWeight=0，释放后留在世界空间，模型死亡不截断 |
| E_hit_aoe | GroundBurn1、RingSmoke、centerFlare、sparks_ornn、Flat1、ShellDistort、ShockwaveSecondary、praxis | 权威0.25秒落地事件的地面中心 | bindWeight=0，独立于单位，圆形地面组织 |
| P_Shield_Refresh | addMesh、alphaMesh、orbitSparks、flash、Avatar、Temp_GroundGlow | 部署获得盾 | Avatar叠加模型；其余保留源绑定曲线，含orbitSparks逐渐脱离的位移 |
| P_shield_break | Stone_Bits、Smoke、cast_orbit、impactStones_smoke | 专属盾从有到无，以模型根为系统基准保留源相对位置；同帧死亡也释放 | 独立所有者；源bindWeight由0.5衰减到0，部分继承位移；死亡/回池停止继承，余粒子继续 |

原版禁用层E的SplashesSlower与破盾的Slag、Slag1、Legs维持禁用，不擅自补回。位移绑定由采样播放器在渲染帧上积分；源粒子曲线、材质、层数和动画事件已核对，不把Godot适配宣称为Riot求解器逐帧等价。伤害、半径及减速仍由2D权威逻辑独立结算。

半径校准：E等比0.01，正上方主冲击圈约160像素。通用nova枪芒仅用于没有专属impact_visual_shape的技能；E已有原版粒子，禁止再叠加该兜底效果。

E以世界地面Y=0.06为基准（轻微抬高避免重叠闪烁）；源相对高度按0.01等比保留：GroundBurn1/praxis为0，Flat1为1，centerFlare为20，ShockwaveSecondary为25，换算后分别高于基准0、0.01、0.20、0.25世界单位。烟尘/火星保留上升轨迹，不把所有层压到地面。

部署播放的是P_Shield_Refresh（护盾获得），不是另一个P_ShieldRegen系统；项目部署盾没有再生。破盾保留源各层相对偏移，撤销人为添加的spine整体抬高；源调用挂点仍未得到完整证实。四层及其轨迹不变。位移衰减现按每颗源粒子的准确出生时间和随机寿命计算，避免以首次显示时间及统一寿命代替。

## 原版体型变化的证据与边界

源P_Shield_Refresh的FlexShapeDefinition逐层指定：addMesh、alphaMesh、Temp_GroundGlow使用scaleBirthScaleByBoundObjectSize=0.005；orbitSparks使用scaleEmitOffsetByBoundObjectSize=0.005；flash同时使用两项；Avatar是模型附着层。破盾四个启用层未显式声明这两项。可确认原版支持按层随绑定对象尺寸改变大小/发射分布，不能推断所有技能统一随模型等比变化，也不能由字段缺省断定破盾完全不缩放（调用方仍可能传入缩放）。

当前播放器保留源静态粒子组织，并用项目统一单位换算适配模型2.50。采样器未实现上述FlexShape动态绑定尺寸语义，且尚未取得Riot调用时的boundObjectSize及系统缩放，因此当前不是已证明与LoL变大/变小过程完全等价的运行时复刻。不凭0.005单独猜测尺寸公式，不为此改变E的160像素权威范围。

## E挂点与逐层旋转

E_cas从Spell3第8帧的完整右手变换释放。启动时从原动画骨骼链采样事件姿势，释放时结合模型的世界变换；只取单位换算后的等比0.01，不把骨骼/模型缩放重复乘入粒子。跨帧或延迟收到动作时仍使用事件姿势，并以已过时间推进粒子，不使用偏晚的手腕姿势。释放后不再跟随手部移动或旋转。

源`particleIsLocalOrientation`启用的Trigger_2/Trigger_3及`isLocalOrientation`启用的RingSmoke继承手部旋转；clods、flame_up、spout保留世界方向，碎石重力与火焰上升不随手腕翻转。两层碎石保留源网格、[180,180,80]初始旋转和背面裁剪，不删层、不双面化、不做镜头压平。此前只传递手部位置而使用单位根旋转，导致网格侧立，在部分朝向只露出细边。

Trigger_3补齐源Flame_trail_gradient调色板，按源红色通道选色、16行中的第9行中心取样，再应用原乘法纹理和颜色曲线；纹理纳入赛前资源清单。源调色板的选择与滚动在本层均为常量，当前接入只覆盖这一已核对配置。E_hit_aoe的8层、原禁用SplashesSlower、相对高度和权威0.25秒落地时刻保持不变。

源`isGroundLayer`用于地面层组织；本项目保留原生三维高度，不直接照搬第三方预览器将所有顶点压至固定Y的做法。以上为本机LoL源BIN/SCB与原动画的核对结果，未声称与当前LoL客户端逐像素一致。
