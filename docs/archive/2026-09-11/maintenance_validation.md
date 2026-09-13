> 阶段验收记录，非当前操作手册。当前流程见 [文档首页](../../README.md)。文内 /tmp 日志是当时的本机证据，不保证永久存在。

# 结构收敛验收记录 · 2026-09-11

## 环境与范围

以开始时的实际工作区为准：`main`，HEAD `012e5e2`，初始 `git status --short --branch` 无本地修改。没有切回旧提交。运行环境为 macOS / Apple M5，Godot `4.7.1.stable.official.a13da4feb`；实际渲染使用 Compatibility / OpenGL。

本轮没有新增正式卡牌、调整卡牌数值或移动原始素材。旧 HEAD 定义与新注册表逐项比较：24 张对 24 张，除新增空 `card_art` 域外差异为零。最小接卡夹具复用已存在模型、卡面和死亡音，不进入正式注册表。

## 已执行验证

| 检查 | 结果与证据 |
| --- | --- |
| 改动前完整 mechanics | 444 项通过，无 SCRIPT ERROR；`/tmp/clash-baseline.log` |
| 先补回归再修复 | 原实现 5 项失败：同/弱倍率减攻速刷新、减攻速到期、加攻速刷新/到期、多周期金币；`/tmp/clash-regression-before.log` |
| 冰冻效果集合所有权 | 单独回归复现 Main 过滤数组后与 SpellSystem 脱离；`/tmp/clash-newreg-before.log`，最终通过 |
| 最终完整 mechanics | 466 项通过，无 SCRIPT ERROR；`/tmp/clash-final-official.log` |
| 编辑器导入 | 完成，无 SCRIPT ERROR；`/tmp/clash-final-import.log`。同时修正旧演示场景指向已不存在脚本的问题 |
| 全脚本加载 | 遍历 scripts、tests、tools、assets/units 内所有 GDScript；无法加载数 0，无 SCRIPT ERROR；`/tmp/clash-final-audit.log` |
| 24 卡配置对比 | 差异 `[]`；`/tmp/clash-final-compare.log` |
| 默认入口启动 | 运行约 14 秒后主动结束进程，无 SCRIPT ERROR；`/tmp/clash-final-startup.log` |
| host/join | 本机两个 headless 进程；客户端收到开局、单位生成、200 份以上快照、纳尔大小形态/动作、弹体、持续吐息端点和带 unit_id/card_id/form/serial 的独立命中来源事件；两端无 SCRIPT ERROR；`/tmp/clash-final-host.log`、`/tmp/clash-final-join.log` |
| 实际渲染 | 非 headless 执行 `tools/demos/maintenance_preview.gd`，检查攻击、控制叠加与变形、控制中死亡、恢复四张画面；无 SCRIPT ERROR；`/tmp/clash-final-render.log` |
| 差异格式 | `git diff --check` 通过 |

复跑命令见 `tests/README.md`。临时日志和图片保留在本机 `/tmp`，未把生成截图作为项目资源提交；四张截图位于 `/tmp/clash-maintenance-render/`。

新增回归覆盖缓存只读与运行副本、不同渲染安排下相同 120 Tick 的结果、前摇受控/恢复、冰冻与眩晕重叠、死亡接管、同类动画和材质隔离、死后弹体命中与禁止死者收益、变形前后音频来源、可选音频能力校验、动作/Buff 声音层并存与清理、晚到与重复客户端数据。眩晕专用片段使用测试映射验证播放能力，不代表正式素材包含 Stun 动画。

## 性能采样

使用 mechanics 的 `--profile-maintenance`，32/64/128 单位密集夹具，索敌/移动/碰撞取 10 Tick 平均；序列化与压缩为一次单位载荷采样。采样版本比最终回归少一条 AI 时钟断言，相关测量实现相同。日志 `/tmp/clash-final-mechanics.log`：468 项通过（含 3 条采样检查），无 SCRIPT ERROR。

| 单位数 | 索敌 μs | 移动 μs | 碰撞 μs | 序列化 μs | 压缩 μs | 原始/压缩字节 |
| --- | --- | --- | --- | --- | --- | --- |
| 32 | 420 | 915 | 185 | 241 | 70 | 9992 / 458 |
| 64 | 1535 | 3451 | 744 | 463 | 118 | 19976 / 802 |
| 128 | 5942 | 12999 | 2912 | 951 | 226 | 39944 / 1658 |

密集夹具中移动与索敌成本随单位数明显增长，后续优先在代表性实战和手机上复测这两个路径，再决定是否引入保序的空间查询。当前样本不足以证明需要增量快照或完整对象池；没有实现这些结构。以上数据不是完整帧时间，没有改动前对照，不报告 FPS 提升比例。预加载只保证资源引用已准备，不消除实例化成本。

## 未完成与保留限制

- 尚未实际试听：事件派发、资源和声音池生命周期自动验证通过，不能据此认证响度、音色、衔接和听感。
- 已检查实际渲染静帧；完整连续动作、所有卡牌控制组合的逐段人工验收尚未完成。
- 未做手机、广域网高延迟/丢包及长时间联机压力测试。快照协议已改为 13，host/join 必须使用同版代码。
- 可选声音缺配置即静音；本轮没有导入新法术或眩晕音频。缺素材、缺事件入口与有意静音的接入规则见 `docs/AUDIO_INTEGRATION.md`，不能把具备入口视为素材已接入。
- 控制保留既有最长持续时间/最强倍率聚合，不改为按来源分别到期。Main 仍保留部署资格、部分几何与兵线编排，技能效果/快照模块仍存在部分 Main 耦合。
- 死者收益保护在原实现已经存在，本轮仅补回归并保持；不把它当作新修复。未引入 ECS、通用技能语言、空间网格或每英雄 Unit 子类。

唯一的新内容流程、模块所有权和三类扩展位置见 `docs/MAINTENANCE_ARCHITECTURE.md`。
