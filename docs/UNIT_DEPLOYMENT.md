# 手牌部署与出场动画

所有手牌先经 `play_card()` 的权威校验并进入 20Hz 的 10 Tick（0.5 秒）Command Buffer。客户端请求携带点击时观察到的 `input_tick`，Host 计算 `execute_tick = input_tick + 10`；网络传输时间消耗这段 Buffer，不在收到请求后重新追加 10 Tick。若 `execute_tick <= current_host_tick`，按 late policy 拒绝并恢复客户端 pending UI；明显过旧或来自未来的 `input_tick` 也直接拒绝。Host 本地玩家和单机 AI 以当前 Host Tick 作为 `input_tick`，保持 `current + 10`。目标 `execute_tick` 到达后单位/建筑生成或法术生效。单位生成后再进入自己的 `deploy_time`（默认 1 秒）：不能索敌、移动、攻击，但已有碰撞、可被索敌/命中/施加状态。召唤物和水晶兵线不经过手牌等待；兵线通过 `deploy_time_override = 0` 即时行动。

`visual_animations.deploy` 必须写素材真实动画名：优先 Respawn，其次 Recall WindDown，最后 Idle。单段会适配 `deploy_time`；多段使用动画数组和等长 `deploy_durations`，总时长应等于部署锁。

赵信是当前特殊样例：`deploy_time = 1.0`，部署阶段只播放 `Spell4`；生成当帧由权威逻辑结算新月护卫的地面范围伤害与击退，动画不驱动效果。部署后进入移动使用 `Spell4_To_Run`，直接攻击则由统一 Pose 衔接机制过渡。

验收：普通单位约 1 秒不自主行动但能被命中/推挤；玩家单位/建筑/法术均在 0.5 秒生效；赵信新月护卫部署伤害、击退和 1 秒锁正确；兵线即时行动；本地、host、client 顺序一致。
