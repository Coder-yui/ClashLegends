# 正义天使声音

[近战](../kayle.md) · [远程](../kayle_ranged.md) · [总索引](../README.md)

部署每次从对应形态的三句中文台词中随机选择一条。

| 形态 | 台词 |
| --- | --- |
| 近战 | 正义绝不妥协。 / 正义荣耀。 / 我携来烈怒之光。 |
| 远程 | 卑琐之人，烈焰加身。 / 尽情享受你的救赎。 / 光明与荣耀。 |

台词依据用户指定的布锅锅目录匹配，从本地Kayle.zh_CN.wad.client提取；网站台词编号没有当作本地WEM编号使用。原版Attack2DGeneral状态分支987635873使用r4/r3/r17，1004413458使用r1/r2/r11。

近战使用BasicAttack/BasicAttack2挥击和命中声；远程使用BasicAttack3/4出手、发射、实际命中声。光剑命中声来自实际普攻结算；焰浪使用独立伤害结算，不触发这组声音。焰浪已接入原版 EnrageConeMis_OnMissileCast 的 4 个随机变体及 EnrageConeMis_hit：随波创建触发发射事件，保留原版声音内部 70ms 延迟；每道波首次有效命中时播放一次命中声，穿透后续目标不重复叠加。空波不播命中声，来源死亡不取消已出手焰浪的声音。Upgrade_cast 的原版使用条件尚未确认，未混入当前声音池。W随机使用KayleWHeal_OnCast的4个原版变体；死亡使用Death3D_cast。走路有意静音。

素材来源与哈希见[声音清单](../../../assets/audio/units/kayle/event_manifest.json)。实机事件与主混音录制不等于用户听感确认，最终验收状态见对应交付。
