# 虚空蠕虫音频

[← 虚空蠕虫](../voidmite.md) · [总索引](../README.md)

已接入：出现、普攻出手、真实命中、死亡。来源为本地LoL Map11.wad.client原始Wwise事件银行，保留事件层叠和随机变体，不做逐文件归一化。

[打开本批试听台](http://127.0.0.1:18779/)；关闭后可运行 `python3 tools/dev.py audio --manifest "ClashLegends-开发素材库/02-候选讨论/峡谷先锋与虚空蠕虫全量音频/catalog.json" --port 18779`。游戏内在卡牌开发工作台选择本单位试听与实战检查。

出现声按用户确认使用`Play_sfx_SRU_Horde_Mini_Buff_cast`，三种原始变体组成deploy:start声音池，每只生成时随机播放一个；复用项目随机池的避免连续重复机制。声音保持原始增益、时长，不随动画变调。无走路音效。普攻、死亡声音沿用现有蠕虫原声事件。

[逐文件来源清单](../../../assets/audio/units/voidmite/event_manifest.json)

## 全量原声试听

[按事件分组试听](http://127.0.0.1:18779/)：本地Map11包内riftherald、riftherald_milkshake和horde_mini三组SFX银行，共68类事件、137条可试听输出（含条件分支和24条生成器标记的重复/别名输出，非137条独立录音）。先锋64类121条；蠕虫4类16条，其中死亡4变体归为一类。全量候选未裁剪，游戏仍只接当前动作需要的声音。

7个事件未恢复语义名，已按真实事件ID分组保留，未猜测用途；Stop等无声控制事件没有伪造音频。此处“全量”限定于已核对的本地源包三组银行，不代表LoL所有历史版本。

[完整时长与触发对照](../animations/rift_herald.md#时长与声音对照)
