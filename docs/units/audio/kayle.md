# 正义天使声音

[近战](../kayle.md) · [远程](../kayle_ranged.md) · [总索引](../README.md)

部署每次从对应形态的三句中文台词中随机选择一条。

| 形态 | 台词 |
| --- | --- |
| 近战 | 正义绝不妥协。 / 正义荣耀。 / 我携来烈怒之光。 |
| 远程 | 卑琐之人，烈焰加身。 / 尽情享受你的救赎。 / 光明与荣耀。 |

台词依据用户指定的布锅锅目录匹配，从本地Kayle.zh_CN.wad.client提取；网站台词编号没有当作本地WEM编号使用。原版Attack2DGeneral状态分支987635873使用r4/r3/r17，1004413458使用r1/r2/r11。

近战使用BasicAttack/BasicAttack2挥击和命中声；远程使用BasicAttack3/4出手、发射、实际命中声。范围命中不会按每个受伤对象叠加同一命中声。W随机使用KayleWHeal_OnCast的4个原版变体；死亡使用Death3D_cast。走路有意静音。

素材来源与哈希见[声音清单](../../../assets/audio/units/kayle/event_manifest.json)。实机事件与主混音录制不等于用户听感确认，最终验收状态见对应交付。
