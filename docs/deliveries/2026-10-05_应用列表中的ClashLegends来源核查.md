# 交付合同：应用列表中的 Clash Legends 来源核查

- **需求 / 来源**：用户对话；解释开发中的 Clash Legends 为什么出现在电脑应用列表中。
- **完成结果**：确认本机有 2026-09-14 导出的六个 `Clash Legends.app` 包，位于开发素材库的 `04-中间产物/构建与验证/macos/`。名称、版本 `0.1.0` 和标识 `com.coderyui.clashlegends` 与项目 [导出预设](../../export_presets.cfg) 一致。[Mac 导出说明](../../tools/release/README.md) 明确其用途为本机测试。它们是开发工程导出的独立运行包；工程源码仍保留。
- **验证**：只读检查 `/Applications`、`~/Applications`、Spotlight 应用索引、应用 `Info.plist`、Launch Services 登记及末批次 `result.json`。两个应用安装目录未发现 Clash Legends；系统登记包含素材库内一个包及原 `builds/macos/` 下五条已失效的旧路径。构建记录包含 `--export-release` 及菜单、对局启动测试，确认其开发测试来源。历史构建成功记录不代表本轮重新验证游戏功能。
- **查看方式**：直接查看本文；包和日志位于 [构建批次目录](../../ClashLegends-开发素材库/04-中间产物/构建与验证/macos/20260914-144637-192616/)。本轮仅新增核查报告和交付索引，保留既有工作区修改。
- **遗留 / 未验证**：未操作用户正在查看的具体应用界面，无法区分它显示的是现存包还是旧路径缓存。本轮未启动、删除应用包或清理系统登记。
