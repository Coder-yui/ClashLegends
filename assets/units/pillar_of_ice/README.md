# 凛冬之柱

基础皮肤E的可见柱体由assets/effects/pillar_of_ice原版粒子网格提供。旧TrundleWall皮肤在源配置为scale=0，未把隐藏旧模型叠加进去。场景的Rise/Idle/Death含真实粒子源时间轨道；升起0～0.36秒、稳定保持0.36秒、死亡从5.625秒起原速下沉。主体与持续特效分别取样，不再用1～3秒循环代替主体待机。统一缩放0.01，顶端锚点3.4世界单位；不压平或抵消相机角度。

原始WAD提取、VFX解析、加工脚本、录音和截图保存在开发素材库03-制作中/凛冬之柱；运行依赖全部放assets。素材来源详见../../effects/pillar_of_ice/source_manifest.json。
