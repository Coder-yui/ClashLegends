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

预算：当前 Mac 的目标为 60 渲染 FPS（16.67 ms）和 20 Hz 权威模拟（50 ms）。目标是评估阈值，不是已保证每种压力场景达标。统计包含启动后的首次显示及资源实例化尖峰；load 批量生成调用独立记录，不隐藏在初始化里。积压含不足一 Tick 的余数，另记最终值。

无界面模式用每帧 0.05 秒推进，只能用于逻辑成本，不能报告为实际 FPS。快照使用真实存活实体完整载荷，测的是构建、序列化、压缩和字节数；不等于网络往返延迟。RSS 每 0.25 秒取样，Godot 静态内存不含全部显存。保留深复制确保表现不拥有权威数据，是否优化由实测支持。
