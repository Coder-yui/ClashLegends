> 2026-09-14 整理前快照，可能含已纠正的说明。当前入口见 [文档首页](../../../README.md)。

# 新卡实现与素材接入清单

任务路由与五阶段顺序由 [AGENT_WORKFLOW](../../../AGENT_WORKFLOW.md) 定义；本页是一次接卡的执行和交付清单。只接某类素材时执行对应阶段。普通新卡先找同类型定义复用，不为每个英雄新建 Unit 子类。

## 开工与素材去向

1. 检查 `git status --short --branch`，记录已有修改；阅读对应专项手册。
2. 确定唯一 `snake_case` card_id、可选卡/系统对象、单位/建筑/法术、主动候选与复用机制。
3. 建立 `docs/units/<card_id>.md`，使用 [卡牌文档模板](../../../templates/card.md)。标明未开始、已接入、已验证、不适用或缺素材，不能提前写“全部完成”。
4. 用户指定待开发队列素材时，逐项记录源路径、目标路径及依赖。将模型及同组纹理**移动**到 `assets/units/<id>/source/`，卡面到 `assets/cards/`，声音到相应音频目录。确认目标可用、源已消失后记“已移动”；共享外部原始库只读提取，不能把两种来源混为复制流程。

| 内容 | 当前入口 | 完成条件 |
| --- | --- | --- |
| 2D 权威逻辑 | `scripts/data/cards/<id>.gd` 四域 + CardDB.DEFINITIONS | 正式 play_card → spawn/cast 链可用；生成、目标、伤害、时序与必要 Snapshot 已验证 |
| 新通用机制 | `scripts/battle/` → schema/validator → 领域回归 | 新字段有读取方；不靠动画、音效回调结算；未知配置被拒绝 |
| 3D 模型与动画 | `assets/units/<id>/source/` + 包装场景 + visual 映射 | 双阵营/形态、脚底、朝向、部署/移动/普攻/技能/死亡连续目视；权威半径保持独立 |
| 卡面 | `assets/cards/<id>_loading.jpg/png/webp` | 优先现成 Loading Screen，其次模型摄影，最后才生成；牌库、详情与手牌可见 |
| 音频 | audio 域 + 选定 WAV + 来源 manifest | 真实 cue 有派发/消费入口，变体可追溯，实际运行试听去重/暂停/恢复/死亡/清场 |
| 联合验收 | 工作台 + 正式单机 + 必要 host/join | 自动回归通过，记录人工验收与未完成项，补卡牌索引和当前状态 |

## 音频工具的使用范围

通用音频工具在 `tools/audio/`。`prepare_lol_card_audio.py` 只准备项目外只读来源的解码工作目录；`import_card_audio.py` 只导入明确指定的卡牌计划，先预览：

```sh
python3 tools/audio/import_card_audio.py --source /absolute/path/to/prepared_library --cards <card_id> --dry-run
```

移除 `--dry-run` 才会写选中卡的音频域、素材及映射。可用 `--plan /absolute/path/to/reviewed_plan.json` 提供独立白名单；纳尔大形态使用显式 `gnar_mega`。预览只展示计划与目标，不证明源 TXTP 可解码。

既有逐卡导入器保存当次加工配方，部分带本机源路径、额外裁剪/混音或后续补丁。通用白名单不是当前完整音频库的无损重建入口，重导已有卡前须对照当前 audio 域及 manifest；不要为接一张卡批量重写全部卡。具体要求见 [音频手册](../../../AUDIO_INTEGRATION.md) 和 [工具目录](../../../../tools/README.md)。

## 交付检查

```sh
python3 tools/maintenance/audit_project.py
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script tests/mechanics_check.gd
git diff --check
```

必须检查最终“全部通过”与日志，不只看退出码。改网络事件时按 [测试手册](../../../../tests/README.md) 运行双方实例；美术和音频分别实际观察、试听。记录采用的模型/纹理、卡面来源、音频原始事件、加工参数及缺口。确定已结束的设计过程移到 `docs/archive/<日期>/`；可再生截图与录音放 `builds/` 或 `/tmp`，源模型和来源清单不当缓存删除。

普通卡自动进入内容契约；只为独特玩法、时序、联网或资源生命周期新增领域断言。修改映射时同步 schema/validator 和当前手册，避免在文末追加互相冲突的“最新版”。

## 文档收口

- 使用 [模板](../../../templates/card.md)，在 [单位手册](../../../units/README.md) 建立总览，直接写中文数值与技能规则。
- 动画、音频和适用的特效说明分别链接；蓝红版本合篇，独立形态分篇，强关联双向链接。
- 手工核对当前定义与文档中的数值；不粘贴源码或自动生成字段表。素材迁移、详细处理与历史验收放对应素材记录或归档。
