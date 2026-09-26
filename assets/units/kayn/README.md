# 凯隐共享模型

正式资源仅source/kayn.glb；普通、蓝凯、红凯包装各选择对应网格节点。所有包装共享一份源资源，只实例化一套骨骼。kayn_view.gd控制显隐、镰刀混合修饰器及模型池重置，无模拟逻辑。

原始三份GLB均为SHA-256 53521247d4f2e77e1a83b11c5f5b20241d45434dac8639eb4f6b70e454a7139b，各10,497,424字节。来源LoL Kayn基础皮肤；skin0.bin初始隐藏红凯、蓝凯及蓝凯头发，Transform_Assassin显示蓝凯与头发，Transform_Slayer显示红凯。完整四表面都属于三形态所需部件，运行时按形态隐藏，不永久删除某种形态。

加工：四surface拆为具名网格节点，共享原骨架/纹理；53段动画筛为21段，压紧不再使用的accessor与bufferView。追加3段部署裁剪产物后共24段，输出9,887,456字节。包装缩放0.013；动画和卡面检查见[手册](../../../docs/units/animations/kayn.md)。原始文件及解析BIN留在本地开发素材库。

2026-09-25补回原表Q出口使用的Idle1_In、Idle1_In_Assassin、Idle1_In_Slayer、Spell2_Slayer_Run。仅追加这四段所需采样数据，没有复制整组原始缓冲；源模型、纹理及骨骼不重复。转场依据与规则见动画手册。

同日后续按用户要求取消三种Idle1_In绑定；这些片段仍可独立观察。地形内移动正式绑定Spell3_Run。随后按用户指定把Spell1_Stop接在Dash与Circle之间，段间零混合；不把本项目序列宣称为静态BIN已证明的原版运行时调用条件。

weapon_blend.gd只修正动作混合窗口内C_Weapon的轨迹：从已显示模型空间姿态插值到源动画目标姿态，绕过Godot经Rest参考方向的长弧。保留GLB原始骨骼层级与所有动画数据，不把武器挂到另一只手，不改判定和时序。

2026-09-26：部署按用户指定从 Idle1_In2 全片、Idle1_In_Assassin 前2秒、Idle1_In_Slayer 第1–3秒分别生成 Deploy_Base / Deploy_Assassin / Deploy_Slayer，均1秒。加工范围见 source_manifest.json 的 deployment_clips；本地重建脚本在开发素材库 `04-中间产物/凯隐/20260926部署片段/build.py`。包装另提供只读展台焦点，围绕人物主体取景。

红凯 Run_Slayer→Spell3_Run 使用固定外侧旋转方向的例外分支，防止近180度过渡随相位选到穿身路线；其他动作继续默认最短路径。没有修改源GLB或增加战斗碰撞查询。

反向 Spell3_Run→Run_Slayer 同样使用外侧路径，沿入地形参考旋转轴的相反方向返回。
