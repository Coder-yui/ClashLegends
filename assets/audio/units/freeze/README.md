# 冰冻音频来源与当前映射

当前运行配置：[audio 域](../../../../scripts/data/cards/freeze.gd)。缺项与验收状态见 [音频覆盖表](../../../../docs/AUDIO_CARD_MAP.md)。

## 当前事件入口

| 形态/阵营 | 配置的事件与声音池 |
| --- | --- |
| 基础 | `spell:cast` |

## 源文件与加工证据

- `play_sfx_cr_freeze_spell_cast_first3s.wav`：来自用户指定的皇室战争冻结音效 WAV。
- 原文件：`/Users/czh/Downloads/部落冲突 皇室战争-交互音效-攻击音效-冰冻法术-冻结_爱给网_aigei_com.wav`。
- 原始文件：3.862857 秒、ADPCM IMA WAV、22050 Hz、单声道；源 SHA-256：`5efbdf87e9789e813b17ffcfebe7475542c13ffc9dce8d07ccec964aa5c6233f`。
- 当前文件：仅保留前 3.000 秒，转为 PCM 16-bit WAV；输出 SHA-256：`1ee13665da02de6694527bc2c501597f5dcaed3b3056a4261fba3fe02065b8ee`。
- 加工命令：`ffmpeg -i <source> -t 3 -c:a pcm_s16le <output>`；未额外归一化或变速。

只接入施放时机；冻结持续、结束和强化减速没有独立素材，不重复播放该段声音。
