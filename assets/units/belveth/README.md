# 虚空女皇模型来源

需求指定模型从待开发队列移至本地 `ClashLegends-开发素材库/03-制作中/卑尔维斯/models/`，正式运行副本为本目录source下GLB。原始GLB保留在制作中，未改动外部LoL源库。

包装说明及动画映射见 [动画页](../../../docs/units/animations/belveth.md)。原模型约538单位展开宽，统一缩放0.011。 飞行高度由通用表现层处理。

SHA256：`9724e50cdc0c8781f9d6c980fdd566ee1231cc2b8387d79a60dcafa5b45187c8`。

卡面使用同源包 `assets/characters/belveth/skins/base/belvethloadscreen_0.tex`，经现有纹理解码器转换成 `assets/cards/belveth_loading.png`，不生成或重绘原画。Q图标为同源HUD中 `bv_q_15.dds`，来源哈希登记在 `assets/skills/source_manifest.json`。

2026-10-01：固定采用大招形态；按原生GearSkinUpgrade隐藏Head、Body改用 `assets/characters/belveth/skins/base/belveth_base_ult_main_tx.tex`。大招贴图解码为source/ultimate_body.png。待机、移动、出场、普攻和Q使用大招素材，死亡使用原生共用Death。包装只加工实例网格与材质；普攻直接映射原生AttackSwipe1/2完整片段，不再拆分、拼接或重排动画。
