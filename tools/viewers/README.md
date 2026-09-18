# 模型动作展台与 3D 摄影棚

返回 [工具索引](../README.md)。复用游戏开发工作台的模型加载、灯光和动画预览；不启动战斗。摄影棚截图和方案保存在本地开发素材库，该目录已整体被 `.gitignore` 忽略。

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
python3 tools/dev.py model --card garen --animation Attack1 --time 0.4 --capture ClashLegends-开发素材库/04-中间产物/构建与验证/garen-candidate.png --size 308x560
```

摄影需要实际渲染，不能加 `--headless`。默认透明背景、308×560，双倍渲染后按可见轮廓居中，保留边距并缩小；动作与角度可重新指定，输出不会覆盖。通用取景按模型包围盒适配，特殊构图可参考 [既有拍摄配方](../capture/README.md)。

确认没有原版卡面且候选构图合适后，用相同参数将 `--capture …` 换成 `--install-missing-art`，会写 `assets/cards/<id>_loading.png`；已有同名 PNG/JPG/JPEG/WebP 时拒绝写入。最后在卡组与工作台验收显示效果，并记录来源与拍摄参数。

## 可交互 3D 摄影棚

当固定命令行构图不合适时，使用独立摄影棚自己找机位：

```sh
python3 tools/dev.py studio --card garen
python3 tools/dev.py studio --card gnar --form 1 --team 1
python3 tools/dev.py studio --card heavy_minion_squad
python3 tools/dev.py studio --cards garen,gnar --formation line
python3 tools/dev.py studio --scene /绝对路径/model.glb
```

预览区左键拖拽可环绕相机，滚轮可推拉。默认镜头自动朝向主体；右侧可在此基础上细调相机朝向的水平偏移、垂直偏移和滚转角，也可调水平环绕、俯仰、距离、目标高度、模型朝向、透视/正交投影、FOV/正交画幅，以及主光、辅光、轮廓光、环境光、背景色和透明背景。摄影灯关闭阴影，但地面默认可见，用来保留卡面构图中的落脚关系；需要纯背景时可手动关闭地面。预设按钮适合快速找方向，方案区可将当前参数写入 `ClashLegends-开发素材库/04-中间产物/3D摄影棚/camera_studio_presets.json`，以后在同一工具中复用。

### 多单位卡面

卡面包含多个单位时，不需要重新依赖 Agent 猜构图：先在“来源”中选择卡牌、阵营和形态，点击“添加成员”逐个加入组合；成员列表可以选中任意一个单位，分别调整横向 X、高度 Y、纵深 Z、朝向和缩放。每个成员也有独立的动画、暂停和时间定位。`横排`、`三角`、`环绕`三种起始编队旁边都有统一的`编队间距`滑杆，调整时会按当前方案重新布局；应用后仍可逐个微调。`替换当前成员`、`删除成员`和`清空组合`用于快速重组。

包含多个部署成员的组合卡（例如 `heavy_minion_squad`）会按普通组合处理，可直接使用横排、三角、环绕和编队间距重新布局；之后由你自己调整相机朝向和机位。

“拍摄卡面 PNG”固定输出项目卡面规格 `308×560`，只写入 `ClashLegends-开发素材库/04-中间产物/3D摄影棚/shots/`，不覆盖已有文件。预览画布也使用同样的卡面比例，避免两侧黑边造成构图误判。拍摄的是纯 3D 预览画面，不会自动写入正式卡面；确认构图后再按美术流程迁移和接入。
