extends RefCounted
## 可选三进程专项：不改变正式卡组、金币与请求队列。
var started := false
var target: Unit
var initial_hp := 0.0
var stun_seen := false
var cage_seen := false
var meteor_seen := false
var damaged := false
var replica_only := true
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 12 and not started:
		started = true
		target = main._spawn_unit(UnitSpawnRequest.new(1,"anivia",Vector2(660,700),{"deploy_time_override":0.0}))
		target.can_attack = false
		target.root(12.0)
		initial_hp = target.hp
		main.runtime._cast_spell(0,"event_horizon",Vector2(540,700),true,0)
	var spells: SpellSystem = main.get("_spell_system")
	if main.runtime.mode == "client":
		replica_only = replica_only and spells.horizon_zones.is_empty() and spells.dark_matters.is_empty()
		for effect in spells.horizon_effects:
			if effect.kind == "event_horizon": cage_seen = true
			if effect.kind == "dark_matter": meteor_seen = true
		for unit in main.world.replica_units_snapshot().values():
			if unit.card_id == "anivia":
				stun_seen = stun_seen or unit.is_stunned()
				damaged = damaged or unit.hp == float(CardDB.get_unit_stats("anivia").hp) - 220.0
	elif is_instance_valid(target):
		stun_seen = stun_seen or target.is_stunned()
		damaged = damaged or target.hp == initial_hp - 220.0
		cage_seen = cage_seen or not spells.horizon_zones.is_empty()
		meteor_seen = meteor_seen or not spells.dark_matters.is_empty()
func result() -> Dictionary:
	return {"passed": stun_seen and cage_seen and meteor_seen and damaged and replica_only, "stun": stun_seen, "cage": cage_seen, "meteor": meteor_seen, "damage": damaged, "replica_only": replica_only}
