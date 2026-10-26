extends RefCounted
## 可选三进程用例，仍通过标准握手、权威_cast_spell、可靠表现和快照链路。
var started := false
var cast_tick := -1
var damage_ok := false
var stun_seen := false
var overlap_applied := false
var disable_only_seen := false
var hidden_again_seen := false
var slow_seen := false
var shield_seen := false
var strike_seen := false
var disable_seen := false
var recovered := false
var tower_id := -1
var enemy_id := -1
var ally_id := -1
var _initial_hp := 0.0
var _initial_enemy_hp := 0.0
var warning_seen := false
var early_damage := false
var _tower: Tower
var _enemy: Unit
var _ally: Unit

func tick(main: Node2D) -> void:
	if not main.runtime._match_started: return
	var tick: int = main.get_authoritative_server_tick()
	if main.runtime.mode == "server" and tick >= 20 and not started:
		started = true
		for tower in main.world.towers_snapshot():
			if tower.team == 1 and not tower.is_king and tower.global_position.x > 360: _tower = tower
		if _tower == null: return
		_tower.can_attack = false
		for team in [0,1]:
			var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team,"garen",_tower.position+Vector2(90,-30+60*team),{"deploy_time_override":0.0}))
			unit.position = _tower.position+Vector2(90,-30+60*team)
			unit.can_attack = false
			unit.root(10.0)
			if team == 0: _ally = unit
			else: _enemy = unit
		_initial_hp = _tower.hp
		_initial_enemy_hp = _enemy.hp
		main._cast_spell(0,"medium_lightning",_tower.position + Vector2(140,0),true)
		cast_tick = tick
	if main.runtime.mode == "server" and started and _tower != null:
		if tick < cast_tick + 40: early_damage = early_damage or _tower.hp != _initial_hp
		else: damage_ok = damage_ok or (_tower.hp == _initial_hp - 72 and _enemy.hp == _initial_enemy_hp - 240)
	if main.runtime.mode == "server" and _tower != null and tick >= 72 and not overlap_applied:
		overlap_applied = true
		_tower.stun(0.5, &"network_other_stun")
	if main.runtime.mode == "client":
		for fx in main._spell_system.lightning_effects:
			warning_seen = warning_seen or fx.kind in ["medium_lightning_warning", "medium_lightning_warning_enemy"]
			strike_seen = strike_seen or fx.kind == "medium_lightning"
			disable_seen = disable_seen or fx.kind == "medium_lightning_disabled"
	var towers: Array = main.world.towers_snapshot()
	for tower in towers:
		if tower.team == 1 and not tower.is_king and tower.global_position.x > 360:
			stun_seen = stun_seen or tower.has_visible_stun()
			if tick >= 64 and tick < 72: disable_only_seen = disable_only_seen or not tower.has_visible_stun()
			if tick >= 88 and tick < 98: hidden_again_seen = hidden_again_seen or not tower.has_visible_stun()
			if tick >= 105 and tower.control.stun_timer == 0: recovered = true
	var units: Dictionary = main.world.replica_units_snapshot() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot()
	for unit in units.values():
		if unit.card_id != "garen" or unit.position.x < 560: continue
		if unit.team == 0: shield_seen = shield_seen or unit.get_shield_ratio() > 0
		else: slow_seen = slow_seen or unit.movement_slow_visual()

func result(server: bool) -> Dictionary:
	var passed := stun_seen and disable_only_seen and hidden_again_seen and shield_seen and slow_seen and recovered and (damage_ok and not early_damage if server else warning_seen and strike_seen and disable_seen)
	return {"passed":passed,"warning":warning_seen,"early_damage":early_damage,"damage":damage_ok,"stun":stun_seen,"disable_only_no_icon":disable_only_seen,"overlap_ended_no_icon":hidden_again_seen,"shield":shield_seen,"slow":slow_seen,"recovered":recovered,"strike_fx":strike_seen,"disable_fx":disable_seen}
