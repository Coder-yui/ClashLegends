# 主动技能图标

返回 [正式资源](../README.md)。信息面板名称前与战斗主动按钮共用 `visual.active_skills[].icon_path`。缺省字段保留文字占位；字段由 schema、类型检查与资源校验约束，不参与战斗结算。

| 卡牌 | 技能 / 原版图标 |
| --- | --- |
| 剑魔 | 大灭 R（aatrox_r） |
| 盖伦 | 致命打击 Q；审判 E（garen_e1） |
| 艾希 / 腕豪 / 格温 | 万箭齐发 W / 蓄意轰拳 W / 快刀乱剪 Q |
| 纳尔 | 怒气爆发使用大纳尔 W（当前前方重击对应技能） |
| 艾尼维亚 / 奥瑞利安·索尔 | 冰雪风暴 R / 星落 R1 |
| 赵信 / 崔斯特 | 新月护卫 R / 万能牌 Q（cardmaster_powercard） |
| 易 / 厄运小姐 / 提莫 | 高原血统 R / 大步流星 W / 致盲 Q |
| 奥恩 | 熔铸冲锋 E（ornne） |
| 太阳圆盘 | 日耀庇护使用装备钢铁烈阳之匣（3190） |
| 恕瑞玛卫队 | 黄沙庇护使用沙漠皇帝 E（azir_e） |
| H-28Q尖端炮台 | 海克斯穿透激光使用大发明家 R 强化 Q（heimerdinger_q2；QUlt 元数据确认） |
| 近战兵 / 远程兵 / 炮车 / 超级兵 | 男爵之力分别使用本兵种当前蓝方128×128方形头像，固定蓝方图；不扩展至组合卡 |
| 近战兵小队 / 远程兵小队 / 攻城部队 / 炮车部队 | 对应当前红方近战 / 远程 / 超级 / 炮车128×128头像，固定红方图 |
| 小兵分队 / 重装部队 | 玩家头像“小兵觉得很赞 图标”（5116）/“禁魔石小兵 图标”（7066），原生300×300 |
| 峡谷先锋 | 旋转重拳使用旋转/冲锋共用图标（sruriftherald_death_recap_square） |
| 皮克斯 | 仙灵汲取使用璐璐被动（lulu_pixfaeriecompanion） |
| 墓碑 | 亡者集结使用牧魂人 W（yorick_w） |
| 治疗术 | 强化治疗使用召唤师治疗术；过量治疗使用同名精密系符文 |

49 张 PNG 的逐文件来源、源包、原路径与 SHA-256 见 [来源清单](source_manifest.json)。48 张来自本机只读 LoL 素材库；DDS 由 Pillow 解码为 RGBA PNG，不重绘、不放大。客户端 PNG 直接复制。过量治疗在本地包中未找到，补自 [Riot Data Dragon 官方图标](https://ddragon.leagueoflegends.com/cdn/img/perk-images/Styles/Precision/Overheal.png)。

提取原件、批次脚本和渲染截图保存在本地开发素材库 `04-中间产物/技能图标/2026-09-22/`。正式目录仅保留已接入图标。

当前所有带主动技能的卡牌均已配图标；缺省图标的通用文字占位能力保留。法术延续随出牌应用选中主动效果的规则，不新增独立战斗释放按钮。

凯隐新增凯隐/影流刺客/拉亚斯特Q原生图标（kayn_q_primary / kayn_q_ass / kayn_q_slay），均从本地Kayn基础角色包提取DDS后解码，逐文件来源见清单。

潘森贯星长枪使用基础皮肤原版 `pantheon_q1.dds`，转换为 `pantheon_q.png`；来源和哈希见 source_manifest.json。

电击法术使用电刑符文原图，大型电击法术使用风暴狂涌装备原图；均从本地客户端default-assets2.wad直接提取PNG，未重绘。

冰冻的“强化冰冻”使用Global包中的`6662_tank_t3_iceborngauntlet.dds`装备图标，原画解码为`freeze_0.png`，来源见同目录清单。

2026-10-02 四张图标均为本地英雄包的 64×64 DDS 原画，直接解码 RGBA PNG。源件、技能元数据与验收截图归档在 `04-中间产物/技能图标/2026-10-02/`。

峡谷先锋图标由本地 `Map11.wad.client` 的 64×64 DDS 原图解码；`HeraldSpinAttack` 与 `HeraldLeapAttack` 均引用该图。原件、元数据及渲染证据归档在 `04-中间产物/技能图标/2026-10-02-herald/`。

四张单兵图标来自本地 Map11 包的 `sru_orderminion*/hud/` 当前 `iconSquare` TEX，使用 `ltk-tex-utils` 原尺寸解码。原件、skin0元数据和验收证据位于 `04-中间产物/技能图标/2026-10-02-minions/`。

六张组合卡原图全部来自本地素材库：红方四图由Map11当前skin0的iconSquare核对；两个玩家头像由中文客户端summoner-icons.json精确名称/ID核对，从default-assets.wad提取JPEG并原尺寸解码PNG。证据位于 `04-中间产物/技能图标/2026-10-02-squads/`。
