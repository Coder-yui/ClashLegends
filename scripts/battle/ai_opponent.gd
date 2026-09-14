class_name AIOpponent
extends Node
## 占位电脑对手：独立金币，攒够费用随机出牌。
## 只是阶段 2 的过渡形态，阶段 3 联机 1v1 后移除，不追求强度。

const THINK_INTERVAL := 1.0   # 每秒决策一次
const PLAY_THRESHOLD := 6.0   # 金币攒到这个数才开始出牌

var enabled := true
var _main: Node
var _elixir: ElixirManager
var _think_timer := 0.0
var _deck: Array = []

func setup(main: Node, deck: Array = []) -> void:
	_main = main
	_deck = deck
	_elixir = ElixirManager.new()
	add_child(_elixir)

func sim_tick(delta: float) -> void:
	if _main == null or _main.game_over:
		return
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = THINK_INTERVAL
	# 金币不够或没有打得起的牌就继续攒
	if _elixir.elixir < PLAY_THRESHOLD:
		return
	var affordable := []
	# AI 也是玩家命令来源，候选牌必须来自主机维护的当前 4 张手牌。
	var candidate_ids: Array = _main.get_authoritative_hand(1)
	for card_id in candidate_ids:
		var stats: Dictionary = CardDB.get_card(card_id)
		# 主动槽法术（包括治疗术的两个主动选项）按提升后的费用判定是否打得起。
		if _elixir.can_afford(_main.card_cost_for_team(1, card_id)):
			affordable.append(card_id)
	if affordable.is_empty():
		return
	# 随机出一张
	var card_id: String = affordable[randi() % affordable.size()]
	var stats: Dictionary = CardDB.get_card(card_id)
	_play(card_id, stats)

func _play(card_id: String, stats: Dictionary) -> void:
	var type: String = stats.get("type", "unit")
	var pos: Vector2
	match type:
		"spell":
			# 法术丢向玩家单位最密集处
			pos = _main._find_player_cluster()
		"building":
			# 建筑放在己方半场内靠前的位置
			var bx: float = ArenaRules.BRIDGE_X_LEFT if randi() % 2 == 0 else ArenaRules.BRIDGE_X_RIGHT
			pos = Vector2(bx + randf_range(-20.0, 20.0), 420.0)
		_:
			# 单位在公主塔前方的合法格出兵；旧坐标 y=250 会与新塔位直接重叠。
			var bx: float = ArenaRules.BRIDGE_X_LEFT if randi() % 2 == 0 else ArenaRules.BRIDGE_X_RIGHT
			pos = Vector2(bx + randf_range(-30.0, 30.0), 460.0)
	_main.play_card(1, card_id, pos, {"elixir": _elixir})
