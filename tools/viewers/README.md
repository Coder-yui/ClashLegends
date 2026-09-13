# 模型动作展台与摄影

返回 [工具索引](../README.md)。复用游戏开发工作台的模型加载、灯光和动画预览；不启动战斗。

```sh
python3 tools/dev.py model --card garen
python3 tools/dev.py model --card gnar --form 1
python3 tools/dev.py model --card princess_tower --team 1
python3 tools/dev.py model --scene /绝对路径/model.glb
python3 tools/dev.py model --card garen --list
```

`--team 0/1` 选择蓝红，`--form 1` 选择已配置的变身。法术没有独立模型时，请用实战工作台查看。外部 glTF 必须带齐纹理依赖。

展台可切换动作、暂停、拖动时间、逐步前进、旋转和缩放。指定动作名可复现某一姿态：

```sh
python3 tools/dev.py model --card garen --animation Attack1 --time 0.4 --yaw 20 --zoom 1.2
python3 tools/dev.py model --card garen --animation Attack1 --time 0.4 --capture builds/garen-candidate.png --size 308x560
```

摄影需要实际渲染，不能加 `--headless`。默认透明背景、308×560，双倍渲染后按可见轮廓居中，保留边距并缩小；动作与角度可重新指定，输出不会覆盖。通用取景按模型包围盒适配，特殊构图可参考 [既有拍摄配方](../capture/README.md)。

确认没有原版卡面且候选构图合适后，用相同参数将 `--capture …` 换成 `--install-missing-art`，会写 `assets/cards/<id>_loading.png`；已有同名 PNG/JPG/JPEG/WebP 时拒绝写入。最后在卡组与工作台验收显示效果，并记录来源与拍摄参数。
