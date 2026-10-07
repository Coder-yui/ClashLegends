# 开发工具

从项目根目录执行以下命令。日常优先用统一入口 `python3 tools/dev.py`；`--help` 查看各工具参数。工具不参与游戏权威模拟。

开发素材库和宣传素材目录是本地工作区，已整体加入 `.gitignore`；工具产生的候选、摄影棚截图和验证产物应按任务导航放入这些目录，正式运行资源仍必须复制到 `assets/` 并在改动记录记录。

## 按任务找工具

| 想做什么 | 入口 | 说明 |
| --- | --- | --- |
| 检查本机依赖 | `python3 tools/dev.py doctor` | 检查源库、Godot 与转换工具，不安装软件 |
| 建立/继续隔离联调 | `python3 tools/dev.py stage` / `stage --reuse <副本路径> --open` | 保留导入设置，记录初始文件哈希；不覆盖副本编辑 |
| 从 LoL 源库找素材 | `python3 tools/dev.py source` | [素材提取与转换](assets/README.md)：模型、动画、纹理、音频、特效定义、卡面 |
| 临时看模型、动作 | `python3 tools/dev.py model` | [模型展台](viewers/README.md)：项目单位或外部 glTF；播放、暂停、拖动时间、旋转、缩放 |
| 自己调机位拍卡面 | `python3 tools/dev.py studio --card garen` | [3D 摄影棚](viewers/README.md)：拖拽相机、编排多单位、调投影/灯光/背景、保存方案并按 `308×560` 卡面规格输出 PNG |
| 拍真实峡谷封面 | `python3 tools/dev.py cover` | [封面摄影台](viewers/README.md)：多单位、多特效独立布景与定格，自由透视相机，横竖版构图与成片预览，布景手动保存/打开恢复，PNG 保存到桌面 |
| 没有卡面时拍摄 | `python3 tools/dev.py model --capture …` | 同一个展台拍透明 PNG；先预览候选，已有卡面不覆盖 |
| 临时听一批声音 | `python3 tools/dev.py audio` | [声音展台](audio_review/README.md)：目录或 manifest；筛选、波形、选段循环 |
| 按中文台词找本地语音 | `python3 tools/audio/find_lol_voice.py --help` | [目录、事件解码与本地转写](audio/README.md) |
| 准备或导入声音 | `audio-prepare` / `audio-import` | [音频工具](audio/README.md)，原始声音与游戏事件需明确对应 |
| 看技能、特效与实战 | `python3 tools/dev.py workbench` | [开发工作台](../docs/DEVELOPMENT_WORKBENCH.md) |
| 执行可追溯自动验证 | `python3 tools/dev.py verify` | 审计、导入、机制、超时清理与版本/日志归档；见 [测试手册](../tests/README.md) |
| 测量 Mac 性能与声音拥挤 | `python3 tools/performance/benchmark.py --render` | [基准说明](performance/README.md) |
| 导出当前 Mac 应用 | `python3 tools/release/export_macos.py` | [发布说明](release/README.md) |
| 查项目资源和文档 | `python3 tools/dev.py audit` | 只读审计；重复文件和无字面引用只是人工检查线索 |

## 目录职责

- `lib/`：外部工具定位与子进程调用。可用 `LOL_TOOLS_BIN` 指定转换工具目录，`GODOT_BIN` 指定 Godot。
- `assets/`、`audio/`：素材准备与加工；通用入口和专门配方的区别见各目录说明。
- `viewers/`、`audio_review/`：可复用的临时展台。
- `capture/`：已有卡面的固定构图配方、地图及宣传拍摄，见 [索引](capture/README.md)。
- `demos/`：具体问题的复现场景，见 [索引](demos/README.md)；不是通用展台，也不是第二套自动测试。
- `arena/`：候选地图的源素材准备、Blender 构建和共用材质处理。
- `maintenance/`：仓库审计；`tests/`：通用工具的自动检查。
- `run_local_multiplayer.sh`：本机独立服务器与两个客户端窗口启动，退出自动清理本组进程。

游戏运行代码在 [scripts](../scripts/README.md)，不要把离线提取、摄影或批量加工塞进运行时。新工具先复用上述入口；只有不同职责才新增脚本。

## 素材开发

- 通用展台留在本目录；一次展示使用路径、清单或参数，不新建重复播放器。
- 模型：`python3 tools/dev.py model --scene /绝对路径/候选模型.glb`。
- 音频：`python3 tools/dev.py audio --directory /绝对路径/候选音频`。
- 联调：`python3 tools/dev.py stage` 创建当前工作区副本（不含 `.godot`），保留 `.import` 配置和初始 `stage_manifest.json` 哈希；加 `--arena --open` 导入制作中地图。继续同一实验用 `stage --reuse <副本绝对路径> --open`，不会复制或覆盖修改；要测试新一轮正式代码才创建新副本。
- 默认验证、发布和性能产物在根目录素材库 `04-中间产物/构建与验证/`；专项截图录音在 `04-中间产物/预览与验证/<批次>/`，共用输出工具按进程创建新批次，保留旧版本。加工和验证的手动输出使用开发素材库；封面摄影台的成片通过保存对话框输出到桌面，宣传场景批次使用独立宣传素材目录。
- 阶段分类与迁移以 [任务导航](../docs/AGENT_WORKFLOW.md) 为准。

## 产物与清理

| 类别 | 位置与处理 |
| --- | --- |
| 正式资源和运行依赖 | `assets/`；必须保留，不以缺少字面引用作为删除依据 |
| 待开发、候选、制作源件 | 分类见 [任务导航](../docs/AGENT_WORKFLOW.md#素材与迭代边界)；唯一源件和地图制作内容保留 |
| 联调副本 | `04-中间产物/联调副本/`；先对比 `stage_manifest.json` 和正式源文件，确认最终修改同步，再决定整份移除；旧副本无基线时不能假定没有独特改动 |
| 缓存与旧构建 | `.godot/imported` 可由源资源重新导入；主项目缓存保留以免打断开发；副本缓存、已替代导出可按任务清理 |
| 截图、录音与转换中间件 | `04-中间产物/` 对应任务；保留必要证据、加工参数与来源，只清确认被替代或可再生成的批次 |
| 宣传、个人需求、外部共享库 | 宣传原始录像/剪辑工程、`需求文档/`、项目外共享素材库不自动清理 |

清理前列候选、依据和预计空间；确认无用的产物移入废纸篓并记录原路径与恢复位置，不清空废纸篓。不可恢复删除或用途不明的唯一文件先询问。移出工作区和释放磁盘分别计量；同卷移入废纸篓只算移出，不能宣称释放空间。符号链接不跟随删除，保留历史路径兼容。不要为整理复制整份项目，也不要把废弃物换目录继续堆放。

## 工具保留与验证

通用入口保持 `dev.py`；素材加工（assets/audio/arena）、通用展台（viewers/audio_review）、摄影配方（capture）、独特问题复现（demos）、性能/发布及审计/测试各保留现有职责。旧双进程配方已退役，具体替代范围见 [专项索引](demos/README.md)。网络验证只使用当前三进程执行器；不把删除旧配方当作新的专项联网通过证据。


原始共享库只读；提取和转换输出到 根目录素材库 `04-中间产物/`，并保存来源清单。正式接入按 [新卡清单](../docs/NEW_CARD_CHECKLIST.md) 执行。用户指定的待开发队列素材仍按该清单**移动**，不能与共享源库混淆。

卡面优先使用原版素材；没有时才摄影。模型转换不等于完成材质、动画、特效或实战验收；试听原声也不等于游戏混音完成。

```sh
python3 -m unittest discover -s tools/tests
python3 -m unittest discover -s tools/maintenance -p 'test_*.py'
python3 tools/dev.py audit
```
