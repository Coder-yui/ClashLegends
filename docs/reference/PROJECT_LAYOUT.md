# 本机项目布局

返回 [任务导航](../AGENT_WORKFLOW.md)。截至 2026-10-21，三个业务板块平行放置：

| 板块 | 本机目录 | 内容 |
| --- | --- | --- |
| 游戏开发 | `/Users/czh/Projects/ClashLegends/` | 游戏源码、运行资源、需求文档与开发素材库 |
| 宣传制作 | `/Users/czh/Projects/ClashLegends-promo-materials/` | 文案、原始拍摄、封面、成片与制作记录 |
| 游戏介绍网站 | `/Users/czh/Projects/ClashLegendsWeb/` | 网站源码、独立内容快照与静态构建 |

游戏名称、窗口标题和新导出应用统一为 `ClashLegends`。网站导入默认从同级 `ClashLegends` 取源；日常构建使用网站自己的内容快照，不依赖游戏运行。宣传录制工具在游戏 `tools/capture/`，默认或限定输出到同级宣传目录。宣传拍摄 runner 的源码与导入缓存链接仍依赖游戏，不是可独立分发的游戏副本。

## 开发资料与历史归档

- 开发素材库保留 `01-待开发` 至 `05-已完成` 的分类；既有中间产物本轮未清理、未重排。
- 原先散落于 `Documents/Codex` 的游戏任务进入 `ClashLegends-开发素材库/04-中间产物/历史归档/Codex历史任务/<日期>/<任务>/`。
- Godot 用户目录中的历史截图和旧配置备份进入同一归档下 `Godot历史输出/`；当前配置、日志和缓存保留在系统用户目录。
- 下载目录的硬控规范草案进入 `需求文档/参考资料/`，保留个人需求目录的本地属性。
- 宣传目录中的历史稿、历史脚本及旧归档已按用户要求移入系统废纸篓；恢复映射在游戏素材库 `04-中间产物/工程整理/2026-10-21_三板块归位/宣传目录简化/trash-map.json`，未清空废纸篓。
- 回滚备份在游戏项目根目录 `ClashLegends-rollback-backups/`，由 `.gitignore` 和 `.gdignore` 排除；原校验和及备份正文保持原样。

本轮搬迁是同卷移动，核对移动前后的 SHA-256，不因归档产生第二份源文件。清单、文本修改前备份和原有脏文件快照在开发素材库 `04-中间产物/工程整理/2026-10-21_三板块归位/`。历史交付和冻结副本中的旧绝对路径保留当时事实，查阅时使用以下映射：

| 旧位置 | 当前位置 |
| --- | --- |
| `/Users/czh/Projects/Clash Legends/` | `/Users/czh/Projects/ClashLegends/` |
| 旧游戏根目录内 `ClashLegends-promo-materials/` | `/Users/czh/Projects/ClashLegends-promo-materials/` |
| `/Users/czh/Projects/ClashLegends-rollback-backups/` | 游戏根目录 `ClashLegends-rollback-backups/` |
| 原 `Documents/Codex` 游戏任务及历史截图 | 逐项查本轮 `moves.json` |
| Godot `app_userdata/Clash Legends/` | `app_userdata/ClashLegends/` |

## 项目外保留项

剪映和 iMovie 的可编辑工程继续由对应软件管理；皇室战争研究项目和 `/Users/czh/Downloads/LOL_Asset_Source/` 原始共享库继续保留在项目外。系统用户配置与缓存也留在系统目录。

宣传目录由用户直接操作，不放 README 和历史归档。各期直接位于宣传根目录：`Video01-玩法展示/`、`Video02-第一赛季CG起源/`、`Video03-技能介绍/`、`Video04-开发经历/`、`Video05-新3D竞技场和音效接入演示/`、`Video06-控制与状态机制/`、`Video07-卡牌数量翻倍/`。每期使用 `01-文案/`、`02-原始素材/`、`03-封面与成片/`、`04-制作记录/`；现有6期成片编号不变，Video4继续占位。公共素材和现用拍摄工具仍在宣传根目录的 `00-公共素材/`、`02-通用拍摄工具/`。

旧素材入口仅通过隐藏的 `.旧路径兼容/` 与符号链接维持访问，不存放历史文件副本；当前文档、脚本、索引和回放URL均使用上述新路径。剪映和 iMovie 工程保留原位且未修改。
