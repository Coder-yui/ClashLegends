# 凯隐共享模型

正式资源仅source/kayn.glb；普通、蓝凯、红凯包装各选择对应网格节点。所有包装共享一份源资源，只实例化一套骨骼。kayn_view.gd仅控制显隐及模型池重置，无模拟逻辑。

原始三份GLB均为SHA-256 53521247d4f2e77e1a83b11c5f5b20241d45434dac8639eb4f6b70e454a7139b，各10,497,424字节。来源LoL Kayn基础皮肤；skin0.bin初始隐藏红凯、蓝凯及蓝凯头发，Transform_Assassin显示蓝凯与头发，Transform_Slayer显示红凯。完整四表面都属于三形态所需部件，运行时按形态隐藏，不永久删除某种形态。

加工：四surface拆为具名网格节点，共享原骨架/纹理；53段动画筛为17段，压紧不再使用的accessor与bufferView。输出8,627,784字节。包装缩放0.013；动画和卡面检查见[手册](../../../docs/units/animations/kayn.md)。原始文件及解析BIN留在本地开发素材库。
