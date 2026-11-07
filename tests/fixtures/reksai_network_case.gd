extends RefCounted
var started := false
var built := false
var routes := {}
var durations := {}
var stable := true
var seen_units := {}
func poll(main: Node2D) -> void:
	if main.runtime.mode=="server" and main.runtime._match_started:
		if main.runtime._sim_tick_id>=12 and not started:
			started=true
			var obstacle: Unit = main._spawn_unit(UnitSpawnRequest.new(1,"thorn_spitter",Vector2(140,800),{"deploy_time_override":0.0}))
			obstacle.can_attack=false
			for team in 2:
				main.runtime._execute_card_deployment(team,"reksai",Vector2(50 if team==0 else 670,200 if team==0 else 1080),"reksai",{},-1)
		if main.runtime._sim_tick_id>=20 and not built:
			built=true
			var obstacle: Unit = main._spawn_unit(UnitSpawnRequest.new(1,"thorn_spitter",Vector2(580,800),{"deploy_time_override":0.0}))
			obstacle.can_attack=false
	for entry in main.runtime._commands.inspect_deployments():
		if entry.card_id!="reksai" or bool(entry.get("waiting_for_route",false)): continue
		var key := str(entry.team)
		var signature := var_to_bytes(entry.route).hex_encode().sha256_text()
		if routes.has(key): stable = stable and routes[key]==signature
		routes[key]=signature
		durations[key]=float(entry.duration)
	var units: Array = main.world.replica_units_snapshot().values() if main.runtime.mode=="client" else main.world.authoritative_units_snapshot().values()
	for unit in units:
		if is_instance_valid(unit) and unit.card_id=="reksai":
			seen_units[str(unit.team)]=true
			if main.runtime.mode=="server":
				unit.can_attack=false
				unit.move_speed=0.0
func result() -> Dictionary:
	return {"passed":stable and routes.size()==2 and seen_units.size()==2,"routes":routes,"durations":durations,"stable":stable,"spawned":seen_units}
