# 小菊特效

[返回单位](../daisy.md) · [单位索引](../README.md)

落地使用原版Spawn_GroundSlam扬尘，按原版出生动作第29/40帧触发（1.3秒部署时约0.943秒），部署期间跟随部署时钟，取消部署清除；第三击真实命中使用BA_1_FistSlam地面反馈，缩放0.012。目标眩晕复用通用特效，不添加原版击飞与冲击波伤害。

原生粒子逐层深度标志保留，20层映射检查通过。

本轮核对源动画还含第0帧R_Spawn及第29帧ReadyFlash事件；当前正式配置仅接入上述落地扬尘和拳击反馈，不宣称完整复刻这两个额外事件。原始事件定义保留在素材库翠神/source-defs/data/characters/ivernminion/animations/skin0.ritobin。
