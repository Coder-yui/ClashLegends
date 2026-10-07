# 金克丝原版特效适配

源包：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/Jinx.wad.client`，只读提取。

- 火箭模型：`assets/characters/jinx/skins/base/particles/jinx_q_rocket.scb`，v3.2，161顶点，292面；rocket_geometry.gd保留逐面顶点及UV（U三项、V三项），投影轴与纹理对应。`jinx_q_rocket.png`为同目录同名TEX。
- `jinx_basic_bullet.png`、`jinx_explosion_smoke.png`、`jinx_base_p_buf.png`、`jinx_base_q_trail01.png`均来自基础皮肤particles目录的同名TEX。
- `jinx_explosion_flat.png`、`overdrivelines_iblitz.png`来自`assets/particles/`同名TEX。
- TEX通过ltk-tex-utils原样解码；烟与火焰按原2×2图集绘制；发光贴图使用加法混合，火箭实体保持正常纹理混合。

原始粒子定义在共享BIN中，超长源文件名通过自定义哈希表缩短后读取。提取清单、哈希表、BIN、加工脚本与失败日志保留在本地金克丝素材目录。运行仅保留已使用资源；本次是原资源的Godot适配，完整粒子层差异见 [特效手册](../../../docs/units/effects/jinx.md)。

## 原版加速线与爆炸范围映射

原版定义：本地 `shared-bins/12d22b526a64fe59.ritobin`，`Jinx_Base_Passive_Buff` 的 Streaks 层。

- EmitterPosition=(0,50,50)，SpawnShape=(50,1,30)，X概率键(0,.2,.8,1)→(-1,-.3,.3,1)，Y概率50→150、Z固定；按0.00952源单位比例与包装1.1倍转换。
- BirthVelocity=(0,0,-200)，速度随机0.8–1.2；约0.3秒寿命，少量延至0.6秒，阻尼1；原80×30四边形沿运动方向拉长0→3，蓝色淡出。Godot平面方向属于渲染器坐标适配。
- 增强发射率24→0使用主机下发的6秒剩余时间；再次触发刷新发射密度，层数不会增加粒子套数。切枪、凝滞、到期由共用表现生命周期管理。
- 未找到原游戏挂点调用脚本；目前用单位根变换承载上述原参数，不将推测的骨骼绑定当作已核实事实。
- 火箭火焰与烟雾均按权威溅射半径绘制，最大半径45像素；原2×2图集加圆形软边裁切，烟雾正常透明、火焰加法混合，0.38秒收尾。

轻机枪保持用户已接受的金克丝原版贴图弹体。本轮无新增正式纹理，额外提取的共享烟雾纹理只作源件核对，保留于素材库。

2026-10-06挂载修正：保留原始发射器/概率参数，在Godot单位根上增加源单位(0,-50,-90)偏移，出生区域落在躯干略后方，负Z向后发射。旧的原参数直接挂根导致身前生成，不再采用。

2026-10-07调整：加速线尺寸、位置和速度保持SKL→GLB的0.0085换算，再随模型缩放；在此基础上宽度增加20%、发射率24→0、蓝白亮度略增，出生点仍在躯干后方。火箭爆炸按用户选择恢复烟雾与火焰2×2图集、0.38秒及45像素范围适配；撤回试验的三层命中效果。
