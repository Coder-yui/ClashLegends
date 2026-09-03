# 卡牌大师（`twisted_fate`）

## 1. 属性数据

| 属性 | 数值 |
| --- | --- |
| 类型 / 费用 / 可选 | 单位 / 4 / 是 |
| 描述 | 远程法师，可攻击地面与空中目标；能在河道外的全图地面落点部署。 |
| 生命值 / 普攻伤害 | 460 / 62 |
| 攻击距离 | 190 |
| 移速 | 60 px/s（中） |
| 攻击间隔 / 首次命中 | 1.20 s / 0.25 s |
| 体型 / 权威半径 / 表现半径 | 中 / 18 / 22.5 |
| 质量 / 视野 | 3 / 250 |
| 空中单位 / 仅攻击建筑 / 可攻击空中 | 否 / 否 / 是 |
| 部署时间 | 预部署 1.0 s + 出现后部署 1.0 s |

费用和伤害是本次接入采用的初始平衡值，后续只需修改 `scripts/data/card_db.gd`。

## 2. 特殊部署

- `deploy_anywhere = true`：卡牌大师可在敌我双方任意地面区域落牌。
- 河道两行、桥面以及防御塔/水晶占用的格子仍不可部署。
- 通用 0.5 秒 Command Buffer 完成后，先进入 1.0 秒预部署：卡牌大师不生成，只在目标位置显示一圈卡牌提示。
- 预部署结束后由权威模拟生成单位，单位再进入普通 1.0 秒 `deploy_time`；此时已经出现，但不能移动或攻击。

## 3. 被动

### 五次攻击

- 普攻表现按 `Attack1` → `Attack2` → `Attack3` → `Attack4` → `Spell3` 循环。
- 第五次攻击在普通命中之外追加一次 `0.5 × 普攻伤害` 的额外命中，延迟 `0.12 s`。
- 额外命中通过通用 `attack_extra_hit_damage_multipliers` / `attack_extra_hit_delays` 配置，动画不参与伤害判定。

## 4. 主动技能：万能牌

- `kind = frontal`、`shape = fan`：朝锁定方向扇出 3 张牌，长度 `190`、角度 `54°`，命中敌方地面或空中单位造成 `100` 点伤害。
- 消耗 `1` 金币；每个实例最多使用 `2` 次；冷却 `8.0 s`。
- `Spell1` 的纯表现卡牌在施法 `0.25 s` 的出手 tick 才生成，随后用 `0.7177415 s` 飞向扇形末端；技能总时长仍为 `0.9677415 s`。Gameplay Impact 仍由固定 20Hz 权威模拟在同一出手 tick 结算，每个目标只结算一次，3 张牌不参与伤害判定。
- 施法锁定移动、攻击和朝向，表现动作使用 `Spell1`。

普攻也遵循同一时序：`first_hit = 0.25 s` 是 `Attack1/2/3/4/Spell3` 的出手/离弦点；攻击间隔仍为 `1.20 s`。固定 Tick 在这里生成权威弹体，弹体抵达目标后才结算伤害，第五击的额外命中也沿用这条权威路径。

## 5. 美术素材

- 正式包装场景：`res://assets/units/twisted_fate/twisted_fate_view.tscn`。
- 源素材已从 `待开发卡牌美术素材/卡牌大师.glb` 移动到 `assets/units/twisted_fate/source/twisted_fate.glb`，因此待开发队列少一个素材。
- 使用动画：部署 `twistedfate_2012_idle_enter_anm`，待机 `twistedfate_2012_idle1_anm`，移动 `Run1`，普攻 `Attack1/2/3/4` 与 `Spell3`，万能牌 `Spell1`，死亡 `Death`。
- 卡面：`res://assets/cards/twisted_fate_loading.png`，从 CommunityDragon 的基础皮肤加载图获取：<https://raw.communitydragon.org/latest/game/assets/characters/twistedfate/skins/base/twistedfateloadscreen.png>。
