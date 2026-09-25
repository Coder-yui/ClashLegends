# 网络协议契约

返回[参考索引](README.md)。版本由 [MatchSession](../../scripts/battle/match_session.gd) 统一拥有；字段顺序及编码/解码由 [NetworkSnapshotSystem](../../scripts/battle/network_snapshot_system.gd) 拥有。下表的显式当前事实由维护审计与代码核对。

| 契约 | 当前值 |
| --- | --- |
| 协议版本 | <!-- current-fact: scripts/battle/match_session.gd PROTOCOL_VERSION -->59 |
| 顶层快照项数 | <!-- current-fact: scripts/battle/network_snapshot_system.gd SNAPSHOT_PACKET_SIZE -->11 |
| 单位载荷项数 | <!-- current-fact: scripts/battle/network_snapshot_system.gd UNIT_PAYLOAD_SIZE -->47 |
| 塔载荷项数 | <!-- current-fact: scripts/battle/network_snapshot_system.gd TOWER_PAYLOAD_SIZE -->6 |
| 弹体载荷项数 | <!-- current-fact: scripts/battle/network_snapshot_system.gd PROJECTILE_PAYLOAD_SIZE -->14 |

双方先核对版本、内容指纹和完整合法卡组，再准备本局资源并确认就绪；加载期间不推进模拟。版本不匹配在握手拒绝，不提供旧载荷兼容槽位。内容指纹包含统一协议版本与四域编译内容。规则算法或消息结构变化均须提升版本。

单位载荷包含出生描述、部署剩余、权限、动作身份、累计取消，以及固定保护结界的中心/半径/剩余时间/代次；精确下标只维护在代码常量中。解码先检查顶层版本、固定长度与类型，再应用数据。NetworkEntityLifecycle 管理出生身份、同 Tick 生命周期序号、销毁屏障和会话隔离；快照可恢复未知实体，晚到动作不得复活已取消动作。

RPC 端点留在 Main，主客节点路径保持一致。运行请求只接受绑定对手、当前会话、正确阵营和单调请求序号。表现系统只产生通知，Main 决定本地播放和远端发送。

终局可靠信封携带最终快照；客户端先应用最终权威状态再显示结果，重复终态幂等，普通快照和实体事件随后不能恢复战斗。加载超时、断线、返回重开以及双进程验证见[测试手册](../../tests/README.md)。

单位新增致死换形状态 `[used, waiting_ticks]`，零血但仍等待复生的实体必须出现在快照内。客户端只应用状态，不自主衰血、倒数或复生；乱序快照不能回滚已完成的换形。

爆炸盾有效标记单独同步，不用总护盾量猜测专属持续音是否应播放。

动作取消原因新增 `death_form`：取消旧攻击与施法表现后发布新的复生动作序号；真实取消载荷必须同时通过RPC与快照校验。

随机首手由主机在可靠 running 消息携带 hand/queue 下发；accepted 消息同时携带本方最近成功卡牌的来源ID、已付费部署形态ID及基础费用。客户端据此显示镜像目标与费用，不能指定复制目标。镜像仍使用既有实体来源卡、技能槽和快照字段。

单位载荷追加免费追斩布尔值、最高流血层数、血怒剩余秒数；客户端仅用于按钮/表现，付费次数与后台冷却继续保留。技能开始RPC携带消费后的免费资格。新增字段做类型和非负值验证，旧协议拒绝握手。

持续吐息新增空中目标单位 ID；客户端用该 ID 找到本地 3D 模型锚点，绘制朝向空中目标身体的光柱。地面目标仍使用原战场位置；目标 ID 不参与索敌或伤害。

顶层新增索引10 `card_growth`：按阵营→来源卡保存ranged/melee计数与unlocked实际定义。内容类型、阵营、计数上限与允许形态经MatchCardGrowth.valid_snapshot校验，非法包拒绝。客户端仅替换主机状态，旧Tick/旧会话沿用现有快照屏障；单位形态身份继续走出生描述card_id，旧普通实体不改变。规则版本提升至52。

动作取消原因 `empowered_reset` 表示强化普攻刷新：取消旧挥击音与未完成攻击阶段，保留当前模型姿势供新强化动作混合。新攻击序号/进度仍由主机发布；晚到的取消不能覆盖更新的攻击。
