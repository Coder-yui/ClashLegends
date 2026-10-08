# 腐蚀法术 / 莫甘娜W地面

来源为本机只读 Morgana.wad.client 的基础皮肤 W，原系统 `Morgana_Base_W_Tar_Update`。原文件路径、SHA-256及转换结果见 source_manifest.json；systems.json保留11层原版曲线。TEX由ltk-tex-utils解码，SCB由既有LeagueToolkit导出器转换。未使用新绘制纹理替代原版W。

运行由 scripts/presentation/corrosion_ground_3d.gd 创建原生粒子播放器，复用潘森已有的 particle_player.gd 和材质；传入显式W定义，不读取潘森粒子配置。原版5秒时钟直接匹配5秒区域，统一尺度按原边环实际半径284.64396（网格499.37537×出生缩放0.57）映射到权威范围，贴地投影校正；range.gdshader只绘制项目阵营判定圈。清场释放全部实例。

播放器覆盖现有支持的原生曲线/粒子子集；未宣称逐像素复现LoL渲染、原生导航遮罩和完整所有附着子系统。原始源件与转换脚本保存在本地开发素材库的腐蚀法术目录，运行仅依赖本目录及现有共享播放器。

2026-10-08 重制：systems.json 保留 source_pass，按源顺序映射到 -30..-16，避免 -1910/-1900/-1800/-1700 被夹成同一优先级；修复余烬 emitOffset 的 ValueVector3/概率表解析，恢复全生命周期 isUniformScale。保留原版 LingerErosionDriveCurve，表现脚本在最后0.4秒侵蚀并淡出，到期立即释放。未修改共享粒子播放器。
