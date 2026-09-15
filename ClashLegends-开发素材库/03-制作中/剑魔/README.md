# 剑魔制作素材

当前玩法、动作与声音以 [单位手册](../../../docs/units/aatrox.md) 为准。此目录保存可继续加工的源件及来源记录；运行依赖在assets/。

| 目录 | 内容 |
| --- | --- |
| model/ | 用户指定的暗裔剑魔.glb主文件；两份已被替代的形态导出归档至04-中间产物/剑魔整理/20260915 |
| animation-source/ | LoL原生动画图与提取清单 |
| card-art/ | 原版卡面来源与转换记录 |
| audio-source/ | 本地批量提取文件；只提交来源说明 |
| audio-preview/ | 51条已接入声音的本地试听副本，提交清单与峰值记录 |
| voice-selection/ | 台词目录、最终选句、来源哈希和Small本地转写；候选音频与客户端提取文件仅保留本地 |

模型预览：`python3 tools/dev.py model --card aatrox`，大灭加`--form 1`。正式声音可直接用`python3 tools/dev.py audio --cards aatrox`试听；本机原试听目录仍保留，可通过`--directory`打开。最终运行模型为assets/units/aatrox/source/ultimate.glb，同模型通过动作与翅膀显隐换形。

原版武器拖尾、被动剑气和大灭粒子尚未接入。日志、录音、截图、联调副本、未采用声音与旧模型统一位于04-中间产物；这些本地过程产物不随代码提交。
