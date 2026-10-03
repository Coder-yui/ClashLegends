# 训练木桩资源

正式卡牌target_dummy，蓝红包装分别加载source/blue.glb、source/red.glb。用户源文件为开发素材库01-待开发/卡牌模型/target_dummy.glb与target_dummy_(2).glb；正式验收后迁移归档，源哈希见source_manifest.json。两个GLB均内嵌纹理，单网格，无额外隐藏子网格配置。

原网格约0.690×1.446×0.793；XYZ统一2.25，脚底Y偏移−0.0209。实际战场与盖伦、赵信同镜头比较，本次较首版增加25%，保持细长木桩轮廓；权威半径21（稍大）独立维护。

当前卡面使用蓝方包装的Idle1_Base在0.3秒进行灰青底柔光摄影；精确参数见下文。没有使用原版加载图。技能图标来自Global.wad.client的assets/perks/styles/resolve/veteranaftershock/veteranaftershock.tex；见assets/skills/source_manifest.json。

余震运行纹理来自同包assets/perks/styles/resolve/aftershock/particles/：buff.png对应perks_aftershock_buff.tex，aoe_ground_crack.png对应perks_aftershock_aoe_ground_crack.tex，身体覆盖avatar_mult.png对应perks_aftershock_avatar_mult.tex。原版纹理解码无重绘，Godot原生平面与加色画布重建环/地裂；未接入完整原生岩块、烟尘、模型粒子系统。

音频来自Common.wad.client的misc_gameplay/misc_global音频与事件银行，按common.ritobin中的完整事件名经wwiser解析、vgmstream解码。15个变体，0dB，无归一化。源素材、解码TXTP与验证截图/录音保留开发素材库训练木桩目录。

[卡牌说明](../../../docs/units/target_dummy.md)

2026-10-04 卡面重拍：308×560，蓝版缩放2.25，Idle1_Base 0.3秒；摄影棚正交3.8、相机yaw0°/pitch7°、模型yaw12°，灰青底#526b70；主光1.4、补光1.15、轮廓光0.45、环境光1.7，无硬阴影。摄影副本将原版unlit材质改为受光、金属度0/粗糙度0.9，正式模型材质不变。通过tools/dev.py studio摄影，正式卡面替换旧透明摄影；旧版、候选、可复用摄影方案和实际UI截图保存在本机开发素材库05-已完成/训练木桩/卡面重拍。
