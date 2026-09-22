# 网络协议契约

返回[参考索引](README.md)。版本由 [MatchSession](../../scripts/battle/match_session.gd) 统一拥有；字段顺序及编码/解码由 [NetworkSnapshotSystem](../../scripts/battle/network_snapshot_system.gd) 拥有。下表的显式当前事实由维护审计与代码核对。

| 契约 | 当前值 |
| --- | --- |
| 协议版本 | <!-- current-fact: scripts/battle/match_session.gd PROTOCOL_VERSION -->45 |
| 顶层快照项数 | <!-- current-fact: scripts/battle/network_snapshot_system.gd SNAPSHOT_PACKET_SIZE -->10 |
| 单位载荷项数 | <!-- current-fact: scripts/battle/network_snapshot_system.gd UNIT_PAYLOAD_SIZE -->40 |
| 塔载荷项数 | <!-- current-fact: scripts/battle/network_snapshot_system.gd TOWER_PAYLOAD_SIZE -->6 |
| 弹体载荷项数 | <!-- current-fact: scripts/battle/network_snapshot_system.gd PROJECTILE_PAYLOAD_SIZE -->13 |

双方先核对版本、内容指纹和完整合法卡组，再准备本局资源并确认就绪；加载期间不推进模拟。版本不匹配在握手拒绝，不提供旧载荷兼容槽位。内容指纹包含统一协议版本与四域编译内容。规则算法或消息结构变化均须提升版本。

单位载荷包含出生描述、部署剩余、权限、动作身份与累计取消；精确下标只维护在代码常量中。解码先检查顶层版本、固定长度与类型，再应用数据。NetworkEntityLifecycle 管理出生身份、同 Tick 生命周期序号、销毁屏障和会话隔离；快照可恢复未知实体，晚到动作不得复活已取消动作。

RPC 端点留在 Main，主客节点路径保持一致。运行请求只接受绑定对手、当前会话、正确阵营和单调请求序号。表现系统只产生通知，Main 决定本地播放和远端发送。

终局可靠信封携带最终快照；客户端先应用最终权威状态再显示结果，重复终态幂等，普通快照和实体事件随后不能恢复战斗。加载超时、断线、返回重开以及双进程验证见[测试手册](../../tests/README.md)。
