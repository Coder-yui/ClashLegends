# Mac 性能基准

从项目根目录执行，使用 `godot-version.txt` 的标准版引擎。正式结果须 `result.json` 中 `valid=true`，报告记录引擎、工作区内容指纹、M5/内存、参数、日志和实际渲染截图。截图主动绘制后读取，避免窗口不触发绘制信号时无限等待；测试窗口临时置顶。基准期间不要修改工作区或同时运行其他重负载。

```sh
python3 tools/performance/benchmark.py --render --counts 32,64,128
python3 tools/performance/benchmark.py --render --counts 64 --audio off
python3 tools/performance/benchmark.py --render --counts 64 --visual off --audio off
python3 tools/performance/benchmark.py --render --case burst --counts 32
python3 tools/performance/benchmark.py --render --case effects --counts 64 --record-audio
python3 tools/performance/benchmark.py --render --case match --counts 1
python3 tools/performance/benchmark.py --counts 32,64,128 --visual off --audio off
```

- `load`：确定位置、双方桥头拥挤，四分之一寒冰，其余近战兵；高生命、零基础伤害，保持负载。32/64/128 的布局不同，不能只从数量推断线性倍率。
- `burst`：第 60 帧同时生成指定数量纳尔，第 180 帧同时变形，单独记录同步调用耗时。
- `effects`：同 load，并每 120 帧通过真实 `play_card` 预览入口叠加 8 个冻结/治疗区域；绕过经济是压力场景，不代表正常可支付频率。
- `match`：双方每 40 Tick 按固定卡组/位置尝试真实出牌及主动技能，保留经济、手牌、兵线和比赛结束规则。最多 305 秒规则时间；失败/超时不是完整对局。
- Main 初始化后重新设置种子 12345。渲染帧与音频回调仍受操作系统调度，测量并非逐位确定性。
- `--record-audio` 录制 Godot Master 总线到 `master-mix.wav`，有额外开销，单列试听记录，不用于开关性能比较。

预算：当前 Mac 的目标为 60 渲染 FPS（16.67 ms）和 20 Hz 权威模拟（50 ms）。目标是评估阈值，不是已保证每种压力场景达标。默认走菜单的完整加载入口，加载完成后才开始局中统计；保留出牌、召唤及变形的慢帧。load批量生成调用另记，不能用该场景的帧分位数代表部署尖峰。积压含不足一 Tick 的余数，另记最终值。

无界面模式用每帧 0.05 秒推进，只能用于逻辑成本，不能报告为实际 FPS。快照使用真实存活实体完整载荷，测的是构建、序列化、压缩和字节数；不等于网络往返延迟。RSS 每 0.25 秒取样，Godot 静态内存不含全部显存。保留深复制确保表现不拥有权威数据，是否优化由实测支持。

## 准备路径与重复测量

`--prepare menu`（默认）调用真实菜单的`_start_local_with_loading`，保留准备就绪和最短展示时间。`--prepare none`显式跳过预建/绘制，只作无预热压力对照。`--entry fresh`为新进程首次进入；`--entry repeat`先在同进程完整加载、退出，再测第二次进入，并记录两次退出后的对象/静态内存。`--repeat 2`每种参数以两个独立进程重复运行。不要混用三类结果。

`--case herald --counts 12`每180帧复现双方先锋各六只召唤，上一批通过真实伤害死亡，保留死亡表现；直接调用权威冲撞命中入口，属于绕过经济的爆发压力，不能冒充正常出牌对局。正常完整对局继续用`--case match --counts 1`。

结果包含加载分段、模型各路径命中/缺货原因/回收/峰值并发与后备初始化耗时、逐帧慢帧索引和生成/变形事件，以及加载后/战斗峰值/退出后的内存和对象数。场景建立中含UI资源加载，resources_usec作为独立累计资源计时与其有重叠，不能直接将所有字段相加。render_usec为实际强制绘制耗时，动画准备与instantiate分别记录；操作系统RSS仍按整个进程取峰值。计数器默认不打印，诊断采样集中在现有性能入口。

图形测量使用当前Godot4.7.1及项目默认gl_compatibility，不降低阴影、分辨率或粒子数量。按[Godot预热说明](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html)，Compatibility仍要求相机内实际绘制；隐藏或仅加载不构成渲染预热。

截图只在计时结束后保存final.png；禁止在采样循环同步写PNG，否则会产生工具自身的慢帧和模拟追赶。结果capture_policy=after_measurement标记修正后的测量，旧第300帧截图数据仅作历史记录，不能据其最大帧判断游戏尖峰。

## 对局加载专项

GDScript 基准可追加 `--perf-deck=id1,id2,...` 与 `--perf-remote-deck=id1,id2,...` 固定双方样本；覆盖只存在于基准子类，在收集资源前应用。未指定时保留固定随机种子的既有样本。`metrics.json` 额外记录双方卡组、完整资源路径/卡牌闭包、模型池容量、加载帧间隔及引擎可报告的显存。基准中的无画面开关仍允许没有模型池。

图形 A/B 应交错顺序、同一设备/卡组/池容量，分别报告新进程和同进程第二局。未清理 OS 文件缓存和驱动缓存时，不能称为冷磁盘/冷着色器测试。不要把 ResourceLoader 总耗时拆成未经测量的磁盘、解码和上传数字。动画轨道快速复制曾因内存增量撤回，现按用户明确接受约78MiB额外静态内存的授权恢复；保留明确别名材质去重及首次冰面预热。历史约30%加载收益不等于当前组合的新测量，过程证据及精确局部回退见加载优化交付。


`tools/performance/first_events.gd` 固定每卡240帧、每帧1/60模拟步长，事件在第0帧部署、第60帧主动及冻结/治疗、第140帧死亡/召唤。记录每帧间隔、事件调用/模拟CPU耗时、前一完成帧的根及3D视口渲染CPU/GPU时间、引擎资源计数、内存、cue与模型池指标。帧间隔包含上一帧事件、表现回调、渲染及系统等待；GPU计时返回0可能表示不支持，不能解释成GPU零耗时；资源计数不是磁盘读取跟踪。高生命、绕过经济及手动先锋命中用于可重复诊断，不是正常对局密度。截图须显式`--capture`，在片段结束后保存。

通过`-- --output=/绝对证据目录 --perf-remote-deck=gnar,anivia,belveth,rift_herald,garen,ashe,freeze,heal`固定对手。cue记录不等于主观试听，也不隔离音频解码耗时。比较至少五轮交错A/B，并保留逐帧时间关联与所有反向指标，不将零池缺货写成无卡顿。
