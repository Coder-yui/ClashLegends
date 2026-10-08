# 符文电刑原始组织

源包：`Global.wad.client`，原始条目 `perks`（无扩展名，提取工具输出 `perks.ltk.bin`）。符文 `Perks/Styles/Domination/Electrocute` 直接引用 `Perks/Styles/Domination/Electrocute/Particles/Perks_Electrocute_AOE`。

八个发射器全部保留，七张原始纹理按包内路径解码为 PNG。`source_manifest.json` 保存源件哈希、读取器版本和纹理来源；`sampled.json` 是原始定义以固定种子79、120Hz采样的逐粒子位置/方向、大小、颜色、UV与侵蚀参数，不是手工重画轨迹。出生随机值固定，运行中每击播放同一份可重现采样。

上级目录的 `player.gd` 使用逐粒子材质和三维四边形重播；`add_no_depth.gdshader` / `mix_no_depth.gdshader` 对应原始混合模式4/1。渲染适配复用项目已有的原生粒子采样路径，不驱动权威状态。原始 pass 转换为保序 rank；地面以 Flash 的原始550尺度换算至90像素参考半径；天空落雷层单独按相机投影拉高。原始烟影/焦痕最多约1.03秒，1.1秒清理。Godot深度、相机及固定随机样本属于适配边界，不声称逐像素复刻LoL。

源件及再生成脚本保存在本地 `ClashLegends-开发素材库/05-已完成/电击法术/源件/2026-10-08-原版重组/`；本目录仅存正式运行依赖及来源说明。
