# 重装部队

[← 返回总索引](README.md)

## 总览

一次出牌生成1只超级兵和1只炮车兵，超级兵在前、炮车兵在后，沿战场纵向间隔2.5格（100像素）。两名成员是独立单位，共享本次部署的主动技能资格。

[查看3D摄影卡面](../../assets/cards/heavy_minion_squad_loading.png)

## 数值

| 项目 | 当前数值 |
| --- | --- |
| 出牌费用 / 数量 | 5金币 / 2名（超级兵、炮车兵各1） |
| 站位 | 前后纵列，中心间距100像素（2.5格） |
| 成员战斗数据 | 分别复用[超级兵](super_minion.md)与[炮车兵](siege_minion.md) |
| 部署 | 常规命令等待0.5秒，生成后部署1秒 |

## 男爵之力

共用施放门槛沿用超级兵男爵之力：2金币，可用1次，冷却7秒。施放后按成员分别复用自身效果：超级兵获得移速135%、伤害135%与140点护盾，炮车兵获得伤害150%，均持续5秒。超级兵阵亡后，主动技能资格转交仍存活的炮车兵。

## 动画、声音与特效

- [超级兵动画接入](animations/super_minion.md) · [炮车兵动画接入](animations/siege_minion.md)
- [超级兵音频](audio/super_minion.md) · [炮车兵音频](audio/siege_minion.md) · [本卡音频复用说明](audio/heavy_minion_squad.md)
- [超级兵特效](effects/super_minion.md) · [炮车兵特效](effects/siege_minion.md)

[← 返回单位总览](README.md)
