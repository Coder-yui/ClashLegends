# 镜像法术卡面来源

2026-09-26，使用内置 imagegen，以旧卡面为参考生成简化版。正式文件 [mirror_loading.png](mirror_loading.png)，1024×1536 PNG。只保留银色椭圆镜、金色卡牌与青色倒影，减少小尺寸噪点；无文字、费用或外框。

旧版与来源记录归档于本地 `ClashLegends-开发素材库/04-中间产物/镜像法术/2026-09-26-简化前/`，不作为运行资源。

生成提示词：

> Use case: style-transfer. Edit target: attached existing Mirror spell card illustration. Replace with a MUCH simpler, bold readable mobile strategy game spell illustration, portrait 1024x1536. Keep only the idea of a magical mirror and the blue/cyan palette. One large plain oval silver mirror centered, slightly angled, with a thick smooth simple rim and luminous cyan glass; in front of its lower left edge a small simple golden card with a single diamond emblem, reflected inside the glass as a matching cyan card with the same diamond emblem. Three main shapes only: mirror, golden card, reflected cyan card. Broad clean painted color areas, restrained soft shading, friendly stylized game illustration. Background a quiet flat deep indigo with a subtle radial gradient and only two small simple sparkles. No warriors, no people, no landscape, no shards, no filigree, no ornate facets, no busy particles, no cosmic swirls. Clear silhouette legible when reduced to 60 pixels. Leave generous breathing room. No words, numbers, logo, watermark, or outer card UI frame.

动态卡面使用已付款锁定形态的原卡纹理，叠加玻璃 shader、双框与“镜·”名称。模型和声音继承规则见[镜像法术](../../docs/units/mirror.md)。
