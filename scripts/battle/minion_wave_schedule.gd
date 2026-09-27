class_name MinionWaveSchedule
extends RefCounted
## 固定 Tick 兵线规则，只输出待生成条目，不创建实体。
const MATCH_TIME := MatchRules.REGULATION_TIME
const OVERTIME_TIME := MatchRules.OVERTIME_TIME
const DOUBLE_ELIXIR_START_TIME := MATCH_TIME - 60.0
const FIRST_MINION_WAVE_TIME := 5.0
const NORMAL_MINION_WAVE_INTERVAL := 45.0
const DOUBLE_MINION_WAVE_INTERVAL := 30.0
const MINION_WAVE_STAGGER := 0.5
const MINION_WAVE_NORMAL := "normal"
const MINION_WAVE_SIEGE := "siege"
var elapsed := 0.0
var next_wave_time := FIRST_MINION_WAVE_TIME
var pending: Array[Dictionary] = []

func begin_overtime() -> void:
	elapsed = maxf(elapsed, MATCH_TIME)
	next_wave_time = MATCH_TIME + DOUBLE_MINION_WAVE_INTERVAL

func clear() -> void:
	pending.clear()

func advance(dt: float, overtime: bool, enemy_tower_destroyed: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	var ready: Array[Dictionary] = []
	for minion in pending:
		var time_left := float(minion.time_left) - dt
		if time_left > 0.001:
			minion.time_left = time_left
			waiting.append(minion)
		else:
			ready.append(minion)
	pending = waiting
	for minion in ready:
		result.append(minion)

	elapsed += dt
	while true:
		# 双倍金币阶段是独立的兵线事件：取消普通阶段原本会落在 2:20 的下一波，
		# 在 2:05 立即出炮车线，之后再从 2:05 以 30 秒为周期排程。
		if not overtime and elapsed + 0.001 >= DOUBLE_ELIXIR_START_TIME \
			and next_wave_time >= DOUBLE_ELIXIR_START_TIME \
			and next_wave_time < DOUBLE_ELIXIR_START_TIME + DOUBLE_MINION_WAVE_INTERVAL:
			result.append_array(wave(MINION_WAVE_SIEGE, enemy_tower_destroyed))
			next_wave_time = DOUBLE_ELIXIR_START_TIME + DOUBLE_MINION_WAVE_INTERVAL
			continue
		if elapsed + 0.001 < next_wave_time:
			break
		# 正赛结束和加时结束都是硬边界：自动 scheduler 不能生成 3:05/5:05 兵线。
		if not overtime and next_wave_time >= MATCH_TIME:
			break
		if overtime and next_wave_time >= MATCH_TIME + OVERTIME_TIME:
			break
		var wave_type := MINION_WAVE_SIEGE if overtime or next_wave_time >= DOUBLE_ELIXIR_START_TIME else MINION_WAVE_NORMAL
		if is_equal_approx(next_wave_time, FIRST_MINION_WAVE_TIME):
			result.append({"announcement": "minions_spawn"})
		result.append_array(wave(wave_type, enemy_tower_destroyed))
		next_wave_time += DOUBLE_MINION_WAVE_INTERVAL if wave_type == MINION_WAVE_SIEGE else NORMAL_MINION_WAVE_INTERVAL

	return result

func wave(wave_type: String, enemy_tower_destroyed: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var second_card := "siege_minion" if wave_type == MINION_WAVE_SIEGE else "ranged_minion"
	# 固定顺序保证相同 tick 的出生与碰撞结果不依赖节点遍历或随机数。
	for team in [0, 1]:
		for lane in [0, 1]:
			var front_card := "super_minion" if enemy_tower_destroyed.call(team, lane) else "melee_minion"
			result.append({"team": team, "lane": lane, "card_id": front_card})
			pending.append({
				"team": team,
				"lane": lane,
				"card_id": second_card,
				"time_left": MINION_WAVE_STAGGER,
			})
	return result
