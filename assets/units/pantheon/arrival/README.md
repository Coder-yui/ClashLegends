# 潘森落地表现适配

此目录拥有Godot播放器、材质和项目适配配置。原版资源在 `../r_original/`。逐层角色、阶段、朝向和适配理由统一见[素材与接入设计](../../../../docs/units/effects/pantheon_arrival_resources.md)，不要在多份README重复维护当前参数。

`integration.json` 以系统/发射器名索引，`profile.gd`读取，`particle_player.gd`消费逐层规则，`original_comet.gd`组合预部署阶段。`pantheon_arrival.gd`和`pantheon_view.gd`分别拥有预部署与生成后的生命周期。纯表现，不派发游戏或音频事件。
