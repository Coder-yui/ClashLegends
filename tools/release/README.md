# 当前 Mac 的可复现导出

仅验收当前 Apple M5 / 16 GiB Mac。使用 `godot-version.txt` 指定的 Godot 标准版，以及同版 `4.7.1.stable` 官方模板。预设使用 GL Compatibility 和官方 universal 二进制；Intel 未实测，手机不在本轮目标内。

```sh
python3 tools/release/export_macos.py
```

输出位于 `ClashLegends-开发素材库/04-中间产物/构建与验证/macos/<时间>/Clash Legends.app`；`result.json` 记录工作区身份、引擎版本、模板 SHA256、所有应用文件 SHA256、导出日志、签名校验和菜单/单机启动冒烟（必须收到发布包内 `--release-smoke=menu|match` 的结构化成功结果）。该脚本固定版本不匹配就失败；运行中不得改源文件。首次先让 Godot 完成资源导入。

`export_presets.cfg` 可入版本控制，未放密钥、密码或本机绝对路径。Godot 的 `.godot/export_credentials.cfg` 由 `.godot/` 忽略规则保护。预设使用内建 ad-hoc 签名，仅本机测试，不是已公证的公开发行包。使用 universal 模板需同时导入 S3TC/BPTC 和 ETC2/ASTC；官方模板只有 universal，单独 arm64 预设会报告缺少二进制。

官方来源：[4.7.1 模板与校验清单](https://github.com/godotengine/godot/releases/tag/4.7.1-stable)、[Mac 导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)。本轮下载的标准版模板 tpz SHA512：

```text
afcc83d8d3d298038f19c58744a0d660fa75dd4baa33cb55d1011bb2565a2a8c2381728924564cb909e37c205a23f21b521b23bd057993afd43ae4da0b2f9d47
```

已有素材来源记录仍保留。公开发行前的素材分发权限清单、Developer ID、公证与外部平台验收不由本机导出成功替代。

单机探针实际验证显示/权威手牌一致、扣费、轮换、单位生成和终局声音停止，然后释放场景并等待音频清理后退出。它仅由专用命令行参数启用，正常菜单不会运行探针。强制 `--quit-after` 在声音刚启动时退出可能产生引擎播放引用清理错误，不能据退出码 0 忽略日志。
