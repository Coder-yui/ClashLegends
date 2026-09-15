# 剑魔音频来源

只读来源：LOL_Asset_Source/Game/DATA/FINAL/Champions/Aatrox.wad.client，基础皮肤SFX Events/Audio banks；使用项目现有Init bank和wwiser v20260909恢复事件图，vgmstream浮点解码后统一-6dB转换至PCM16。

处理目的为避免解码输出削波，不做逐文件归一化。普通死亡采用共用1.5秒包络。事件、候选条件、源试听文件与加工参数见event_manifest.json；完整TXTP和原包提取记录保留在开发素材库03-制作中/剑魔。

部分材质条件ID未恢复名称，本版固定选用一个条件下的随机变化；未将不同条件混成随机池。主观混音仍待用户确认。

2026-09-15音频修订：增加zh_CN的Death3D三种语音，与死亡SFX同时播放；大灭起手裁至2秒，最后0.5秒线性淡出，并复用到击杀刷新事件。每个攻击Cast/Hit池最多5条。原始及多余候选移至素材库中间产物，详见单位音频手册。

部署随机三句：让我带来终结。/我回来了。/你无法摧毁我。保留完整时长，统一-6dB；来源与哈希见 event_manifest.json。
