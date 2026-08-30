# 手牌部署与出场动画

所有手牌先经 `play_card()` 的权威校验并等待 `0.5` 秒；窗口结束后单位/建筑生成或法术生效。单位生成后再进入自己的 `deploy_time`（默认 1 秒）：不能索敌、移动、攻击，但已有碰撞、可被索敌/命中/施加状态。召唤物和水晶兵线不经过手牌等待；兵线通过 `deploy_time_override = 0` 即时行动。

`visual_animations.deploy` 必须写素材真实动画名：优先 Respawn，其次 Recall WindDown，最后 Idle。单段会适配 `deploy_time`；多段使用动画数组和等长 `deploy_durations`，总时长应等于部署锁。

赵信是当前特殊样例：`deploy_time = 1.5`，`Spell4 → Spell4_To_Idle` 分别 1.0/0.5 秒；生成当帧由权威逻辑结算横扫击退，动画不驱动效果。

验收：普通单位约 1 秒不自主行动但能被命中/推挤；玩家单位/建筑/法术均在 0.5 秒生效；赵信横扫和 1.5 秒锁正确；兵线即时行动；本地、host、client 顺序一致。
