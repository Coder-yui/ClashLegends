# 声音试听台

返回 [工具索引](../README.md)。只读试听 WAV，不修改裁剪和游戏配置。

```sh
python3 tools/dev.py audio
python3 tools/dev.py audio --directory /绝对路径/候选声音
python3 tools/dev.py audio --cards garen anivia
python3 tools/dev.py audio --manifest assets/audio/units/garen/event_manifest.json
```

打开终端显示的本机地址（默认 `http://127.0.0.1:18765`）。可筛选、切换声音、看波形、拖动时间、设置片段循环与复制选段信息。`--directory` 和 `--manifest` 可重复；自定义端口用 `--port`。`--catalog-only` 只输出清单，方便检查来源和时长。

未指定目录或清单时读取项目 `assets/audio`；清单仅纳入实际存在的 WAV。网页只提供列入目录的声音，不暴露任意文件路径。结束时在终端按 Ctrl+C。

这里验证原始声音与选段；游戏中的音量、空间衰减、并发和触发时机仍需在 [工作台](../../docs/DEVELOPMENT_WORKBENCH.md) 试听。
