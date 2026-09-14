# 临时建筑展示台

运行：`Godot --path . --script tools/demos/structure_showcase.gd`。本机 Godot 位于 /Applications/Godot.app/Contents/MacOS/Godot。

独立场景，不启动比赛、不修改卡牌数据。水晶/防御塔、蓝红双方可切换，模型放大 2.4 倍仅用于观察。支持重置、逐阶段破坏和自动演示；复用正式 TowerModel3D、GameAudioManager 及系统音频配置。水晶 10 秒时自动摧毁，防御塔在 2 / 5 / 8 秒进入阶段一、阶段二、摧毁。可反复重播。

加 `-- --capture` 自动截图并退出，输出 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/structure-showcase。完整回归位于 audio_presentation_suite，涵盖阈值去重、跨段伤害和死亡不补中间声音。
