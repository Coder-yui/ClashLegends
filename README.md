# Clash Legends

Clash Legends 是 Godot 4.x / GDScript 的类皇室战争 1v1 卡牌即时对战学习项目，仅供个人本地学习。项目采用 2D 固定 20Hz 主机权威模拟与独立 3D 表现层。

实际窗口为 `720×1400`：战场 `720×1280`，底部 120px 为手牌/UI。用 Godot 打开 `project.godot`，F5 运行 `scenes/main.tscn`。

```bash
Godot --headless --path . --script tests/mechanics_check.gd
Godot --headless --path . --quit-after 2 -- --mode=local
Godot --headless --path . --quit-after 20 -- --mode=host --auto-test
Godot --headless --path . --quit-after 20 -- --mode=join --ip=127.0.0.1 --auto-test
```

验收时同时检查输出中没有 `SCRIPT ERROR`；美术接入还必须实际渲染。

## 架构

```text
scripts/main.gd                          Battle Controller 与 RPC 端点
scripts/battle/                          战场服务、AI、金币、寻路、弹体与网络快照
scripts/ui/                              备战、手牌、主动技能与美术开发界面
scripts/data/card_db.gd                  数据唯一来源、查询 API、validator
scripts/unit.gd                          数据驱动通用单位机制
scripts/presentation/                    3D 表现代理
tests/mechanics_check.gd                 统一回归入口；领域套件在 tests/suites/
tools/capture/                           卡面与宣传素材摄影脚本
tools/demos/                             需要实际渲染的交互演示场景
```

玩家、AI、部署 RPC 和 ArtDevPanel 进入 `play_card()`；主动请求进入 `use_active_skill()`。权威单位仍由 `_spawn_unit()` 生成，法术由 `_cast_spell()` 结算。Unit 通过注入的 `BattleContext` 请求路径、地形、召唤、攻击与网络表现通知。

新增普通卡通常只需 CardDB、自动发现的 `<card_id>_loading.*` 卡面和可选 3D 包装场景。任务阅读入口见 `docs/AGENT_WORKFLOW.md`。

macOS 本地双端冒烟可运行 `tools/run_local_multiplayer.sh`；如果 Godot 不在默认应用目录，通过 `GODOT_BIN` 指定可执行文件。
