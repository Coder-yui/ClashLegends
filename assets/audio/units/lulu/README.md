# 璐璐声音来源

LoL基础皮肤原始事件，通过现有`card_audio_batch/lulu/txtp`与vgmstream-cli渲染为PCM WAV；来源批次位于本地开发素材库`04-中间产物/素材加工/`。大招采用已有`02-候选讨论/音频/lulu/`中的LuluR_OnCast三个变体，保持原始离线渲染结果，不归一化。运行时音量与事件详见璐璐音频手册，逐文件来源和SHA256见source_manifest.json。

部署语音来自LoL客户端zh_CN选角文件117.ogg，直接接入，不裁剪、不改音高。新增本地Move2DStandard r1/r8为“我建议滑着走。”、“大鼻子露珠。”，经本地中文ASR识别，与选角语音组成随机池。素材不裁剪、不改音高；新增混音听感仍待用户确认。
