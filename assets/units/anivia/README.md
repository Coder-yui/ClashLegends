# 艾尼维亚（`anivia`）素材

本卡素材已从 `待开发卡牌美术素材/` **移动**到本目录的 `source/`，源队列中已不存在这两个文件：

- `冰晶凤凰.glb` → `source/anivia_order.glb`：凤凰本体，含 `Attack1`、`Attack2`、`Run`、`Death` 与 `Spell4`。
- `冰晶凤凰 (1).glb` → `source/anivia_chaos.glb`：复活蛋模型，含 `Idle1` 与 `Death`，材质名为 `RebirthEgg_`。

包装场景只负责缩放和脚底校正；复活、蛋的地面碰撞、血量和 3 秒计时均由通用 `Unit` 权威机制处理。没有专用过渡动画时，通用表现层会让蛋从空中落地，复生凤凰从较小比例升起；这两段不参与权威逻辑。
