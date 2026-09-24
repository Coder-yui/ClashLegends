# 正义天使音频

来源为本地LoL Kayle.wad.client（音效）、Kayle.zh_CN.wad.client（中文语音）。wwiser按事件及形态状态展开，再由vgmstream解码。部署六句从Attack2DGeneral事件按状态与随机分支挑选；完整对应、原路径及文件哈希见event_manifest.json。

语音浮点解码转16位PCM；音效先浮点解码，原始最大峰值1.293；所有音效统一降低4dB后转16位PCM，避免整数解码削波，保留相对响度，不逐条归一化。配置在两张形态定义的audio域，实际卡组只有kayle。台词通过网站文本和本地转写交叉定位，主观听感未冒充人工确认。工作台音频页可逐条试听，实际对战已生成主混音录音。
