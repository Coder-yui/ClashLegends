extends SceneTree
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
const BUILDER = preload("res://tools/maintenance/model_template_builder.gd")
const MODEL := "res://tests/fixtures/material_plan_model.tscn"
const BUFF := "res://tests/fixtures/material_plan_buff.tscn"
var pulse: RefCounted
var output := ""
var checks := 0
var failures: Array[String] = []
var results := {}

class Tracker extends Node3D:
	func track(_unit: Unit, _view: Node = null) -> void: pass

class FixturePlan extends RefCounted:
	var model_path := MODEL
	var source: RefCounted
	var cards: Dictionary
	var decks: Array
	var target_states: Dictionary
	func _init(plan: RefCounted) -> void:
		source = plan
		cards = plan.cards
		decks = plan.decks
		target_states = plan.target_states
	func definition(id: String, team: int = -1, active_enabled: bool = true) -> Dictionary:
		return fixture(source.definition(id, team, active_enabled))
	func fixture(original: Dictionary) -> Dictionary:
		var result := original.duplicate(true)
		result.visual_scene_path = model_path
		result.visual_scene_paths = [model_path, model_path]
		result.visual_animations = {"idle": "Idle", "move": "Idle", "death": "Death"}
		result.show_team_ring = false
		if not String(result.get("visual_active_buff_scene", "")).is_empty(): result.visual_active_buff_scene = BUFF
		if result.has("transformed_stats"): result.transformed_stats = fixture(result.transformed_stats)
		return result

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func prepared(world: Node3D, states: Dictionary) -> Dictionary:
	var model: Node3D = load(MODEL).instantiate()
	world.add_child(model)
	model.process_mode = Node.PROCESS_MODE_DISABLED
	var owner := ModelVisualResources.new()
	var player := owner.bind_model(model, {}, states)
	check(owner.errors.is_empty(), "prepared fixture owner valid")
	return {"node": model, "owner": owner, "player": player}

func counts(owner: ModelVisualResources) -> Dictionary:
	return owner.material_creations.duplicate()

func state_checks(world: Node3D) -> void:
	var desc := {"scene": BUFF, "radius": 20.0, "team": 0, "key": ModelVisualResources.buff_key(BUFF, 20.0, 0)}
	var states := {"mode": "match", "freeze": true, "stasis": true, "stealth": true, "building": false, "buffs": [desc]}
	var a := prepared(world, states)
	var b := prepared(world, states)
	var owner: ModelVisualResources = a.owner
	var before := counts(owner)
	var prepared_counts := before.duplicate()
	check(before.ghost > 0 and before.frost > 0 and before.gold > 0 and before.buff > 0, "all reachable candidates exist before use")
	check(owner.select_buff(desc.key), "planned buff selection")
	for mask in 32:
		check(owner.apply_overlays(bool(mask & 1), bool(mask & 2), bool(mask & 4), bool(mask & 8), bool(mask & 16)), "legal combination " + str(mask))
	check(counts(owner) == before, "32 freeze/stealth/stasis/hit/buff combinations create zero candidates")
	var base_hit: Material = owner._base_overlays[0][1]
	var base_frost: Material = owner._base_overlays[0][2]
	var buff_hit: Material = owner._buff_bank[desc.key].variants[0][1]
	for cycle in 3:
		var node := owner.buff_node(desc.key)
		owner.park_buff(node)
		owner.reset_overlays()
		owner.configure_buff(Callable(), desc.key)
	check(counts(owner) == before and owner._base_overlays[0][1] == base_hit and owner._base_overlays[0][2] == base_frost and owner._buff_bank[desc.key].variants[0][1] == buff_hit, "buff attach/reset/reselect preserves candidate identities and counts")
	var material: Material = owner._buff_bank[desc.key].overlays[0]
	material.set_shader_parameter("strength", 0.75)
	check(b.owner._buff_bank[desc.key].overlays[0] != material, "buff uniforms private between stock instances")
	owner.clear()
	a.node.free()
	b.owner.clear()
	b.node.free()
	var plain := prepared(world, {"mode": "match", "freeze": false, "stasis": false, "stealth": false, "buffs": []})
	owner = plain.owner
	before = counts(owner)
	check(not owner.apply_overlays(false, true, false), "undeclared freeze explicitly fails")
	check(not owner.apply_overlays(false, false, false, true), "undeclared stasis explicitly fails")
	check(not owner.apply_stealth(true), "undeclared stealth explicitly fails")
	check(not owner.configure_buff(func(base): return StandardMaterial3D.new()), "runtime buff factory explicitly forbidden")
	check(not owner.select_buff("missing") and owner.errors.size() >= 5 and counts(owner) == before, "all invalid requests fail without creating candidates")
	owner.clear()
	plain.node.free()
	plain = prepared(world, ModelVisualResources.tool_material_states())
	check(plain.owner.apply_overlays(false, true, false, false, true) and plain.owner._frost_prepared and not plain.owner._surface_ghosts.is_empty(), "explicit tool mode permits lazy preparation")
	plain.owner.clear()
	plain.node.free()
	results.combinations = 32
	results.prepared_counts = prepared_counts

func closure_attach_checks(world: Node3D, camera: Camera3D) -> void:
	var real: RefCounted = load("res://scripts/presentation/match_resource_plan.gd").for_match([["mirror", "freeze", "twitch", "gnar", "belveth", "darius"], ["stasis", "azir"]], [{}, {}])
	check(real.errors.is_empty() and real.cards.has("voidfish") and real.cards.has("sand_soldier"), "real summon closure")
	check(real.allows("darius", 0, 0), "active mirror expands selected skill for ordinary source card")
	var plan := FixturePlan.new(real)
	var specs := MatchModelPool.build_specs(plan.cards, plan)
	var states := MatchModelPool.material_states_for(specs[MODEL], plan)
	var mixed := MatchModelPool.material_states_for([{ "team": 0, "stats": {"stealth_delay": 0.0, "type": "unit"}}, {"team": 1, "stats": {"stealth_delay": 2.0, "type": "unit"}}], plan, 1)
	check(mixed.stealth and mixed.freeze and mixed.stasis, "same path opposite teams take capability and target-state union")
	var noncombat := MatchModelPool.material_states_for([], plan)
	check(not noncombat.freeze and not noncombat.stasis and noncombat.buffs.is_empty(), "noncombat extra scenes do not create unreachable target candidates")
	var presentation := BattlePresentation3D.new()
	root.add_child(presentation)
	presentation.set_process(false)
	presentation._world_root = world
	presentation._camera = camera
	presentation.resource_plan = plan
	presentation._sion_w_effect = Tracker.new()
	presentation._sett_effect = Tracker.new()
	presentation.add_child(presentation._sion_w_effect)
	presentation.add_child(presentation._sett_effect)
	var pool := presentation.model_pool
	pool._world = world
	pool.strict_materials = true
	pool._material_states[MODEL] = states
	pool.capacity[MODEL] = 2
	pool.instances[MODEL] = []
	var identities := []
	for index in 2:
		var entry := prepared(world, states)
		var node: Node3D = entry.node
		node.set_meta("pool_path", MODEL)
		node.set_meta("prepared_model_resources", entry.owner)
		node.set_meta("prepared_animation_player", entry.player)
		node.set_meta("pool_state", pool._capture_state(node))
		node.hide()
		pool.instances[MODEL].append(node)
		identities.append({"owner": entry.owner, "counts": counts(entry.owner)})
	for id in ["voidfish", "gnar", "twitch", "darius", "darius"]:
		pulse.set_phase("actual-attach:" + id, true)
		var unit := Unit.new()
		var stats := plan.definition(id, 0)
		unit.setup(0, stats, id)
		unit.card_id = id
		# Last Darius is the same source card ID used by an active mirror copy.
		if id == "darius": unit.active_skill_card_id = id
		check(presentation.attach_unit(unit, stats), "actual production attach: " + id)
		var view: UnitModel3D
		for child in world.get_children():
			if child is UnitModel3D: view = child
		if view == null:
			unit.free()
			continue
		check(view.material_states == states, "formal attach receives full material plan: " + id)
		unit.control.refresh_freeze(1.0, &"enemy-fixture")
		view._set_hit_flash(true)
		unit.control.apply_replica_stasis(true)
		view._set_hit_flash(false)
		unit.control.apply_replica_stasis(false)
		if id == "gnar":
			unit.form_index = 1
			presentation._on_unit_form_changed(1, unit, view, stats)
			check(view._model_root != null, "actual form replacement attaches prepared second owner")
		view._release_model()
		view.free()
		unit.free()
		for identity in identities: check(counts(identity.owner) == identity.counts, "stock owner creates zero candidates after attach/control/recycle: " + id)
	check(pool._metric(MODEL).misses == 0 and pool._metric(MODEL).recycled >= 5, "actual attach/form/recycle uses stock with no miss")
	var invalid := Node3D.new()
	var unplanned := PackedScene.new()
	unplanned.pack(invalid)
	invalid.free()
	unplanned.take_over_path("res://tests/fixtures/" + "unplanned_model.tscn") # 仅内存中的拒绝夹具
	check(pool.take(unplanned) == null and not pool.errors.is_empty(), "unplanned path explicitly rejected before instantiation")
	var bad := Unit.new()
	bad.setup(0, CardDB.get_card("ornn"), "ornn")
	bad.card_id = "ornn"
	check(not presentation.attach_unit(bad, CardDB.get_card("ornn")) and not presentation.material_errors.is_empty(), "unplanned card error propagates through presentation")
	bad.free()
	for identity in identities: identity.owner.clear()
	for node in pool.instances[MODEL]: node.free()
	pool.instances.clear()
	presentation.free()
	results.misses = pool._metric(MODEL).misses

func pool_entry_checks(world: Node3D, camera: Camera3D) -> void:
	pulse.set_phase("pool-entry-contracts", true)
	var real: RefCounted = load("res://scripts/presentation/match_resource_plan.gd").for_match([["twitch", "freeze"], ["stasis"]], [{}, {}])
	var plan := FixturePlan.new(real)
	var path := "res://assets/units/" + "__material_fixture__/fixture.tscn" # 内存缓存别名，非磁盘素材引用
	var packed := load(MODEL).duplicate(false) as PackedScene
	packed.take_over_path(path)
	plan.model_path = path
	var pool := MatchModelPool.new()
	await pool.prepare({path: packed}, world, camera, {"twitch": [0]}, plan)
	check(pool.errors.is_empty() and not pool.instances.get(path, []).is_empty(), "real pool initial prepare completes tiny fixture")
	if not pool.errors.is_empty() or pool.instances.get(path, []).is_empty(): return
	var states := pool.states_for_path(path)
	check(states.freeze and states.stealth and states.stasis and states.mode == "match", "initial/sample plan has complete target states")
	var sample: UnitModel3D = pool._render_samples[0]
	check(sample.material_states == states and sample._model_resources._gold != null, "actual render sample uses identical strict plan and prebuilt gold")
	while pool.instances[path].size() > 1:
		var extra: Node3D = pool.instances[path].pop_back()
		extra.get_meta("prepared_model_resources").clear()
		extra.free()
	var taken := pool.take(packed) as Node3D
	var owner: ModelVisualResources = taken.get_meta("prepared_model_resources")
	var before := counts(owner)
	check(owner.apply_overlays(true, true, false, false, true) and counts(owner) == before, "initial stock combined state zero creation")
	# Tiny known-fast fixture only: exercise original refill state machine, no production capacity change.
	pool.initial_capacity[path] = 1
	pool.capacity[path] = 2
	pool._runtime_safe[path] = true
	for index in 8:
		pool.advance_refill(0.01)
		if pool.refill_metrics.completed > 0: break
	check(pool.refill_metrics.completed == 1 and pool.errors.is_empty(), "real incremental refill state machine completes")
	var refill := pool.take(packed) as Node3D
	var refill_owner: ModelVisualResources = refill.get_meta("prepared_model_resources")
	check(refill_owner._material_plan == states and refill_owner._gold != null and refill_owner._frost_prepared and not refill_owner._surface_ghosts.is_empty(), "refill prebuilds same complete plan")
	var missed := pool.take(packed) as Node3D
	var miss_owner: ModelVisualResources = missed.get_meta("prepared_model_resources")
	check(pool._metric(path).misses == 1 and miss_owner._material_plan == states and miss_owner._gold != null, "known inventory miss binds complete plan; allocation remains explicitly counted as miss")
	owner.clear()
	refill_owner.clear()
	miss_owner.clear()
	taken.free()
	refill.free()
	missed.free()
	pool.release_sources()
	for sample_node in world.get_children():
		if sample_node is UnitModel3D: sample_node.free()
	results.refill = 1
	results.inventory_miss = 1

func layered_buff_check(world: Node3D) -> void:
	pulse.set_phase("layered-buff", true)
	var scene := "res://assets/effects/tryndamere/undying_rage.tscn"
	var descriptor := {"scene": scene, "radius": 20.0, "team": 0, "key": ModelVisualResources.buff_key(scene, 20.0, 0)}
	var entry := prepared(world, {"mode": "match", "freeze": true, "stasis": true, "stealth": false, "buffs": [descriptor]})
	var owner: ModelVisualResources = entry.owner
	var before := counts(owner)
	var node := owner.buff_node(descriptor.key)
	check(node._layers.size() == 5 and before.buff == 5, "real custom five-layer factory prepared at load")
	owner.select_buff(descriptor.key)
	owner.apply_overlays(true, true, true)
	owner.reset_overlays()
	owner.select_buff(descriptor.key)
	check(counts(owner) == before and node._layers.size() == 5, "real layered buff handoff/reset reuses original handles")
	owner.clear()
	entry.node.free()

func preserve_check(world: Node3D) -> void:
	var scene := "res://assets/units/jinx/haste_view.tscn"
	var key := ModelVisualResources.buff_key(scene, 20.0, 0)
	var states := {"mode": "match", "buffs": [{"scene": scene, "radius": 20.0, "team": 0, "key": key}]}
	var a := prepared(world, states)
	var b := prepared(world, states)
	var old: ActiveBuffVisual3D = a.owner.buff_node(key)
	old.reparent(world, false)
	old._elapsed = 2.0
	var fresh: ActiveBuffVisual3D = b.owner.buff_node(key)
	var before_a := counts(a.owner)
	var before_b := counts(b.owner)
	check(b.owner.preserve_buff(a.owner, old, key) and b.owner.buff_node(key) == old and a.owner.buff_node(key) == fresh and old._elapsed == 2.0, "real preserve-on-form-change swaps prebuilt non-overlay nodes without losing clock")
	check(counts(a.owner) == before_a and counts(b.owner) == before_b, "preserve handoff allocates no candidate")
	a.owner.clear()
	b.owner.clear()
	a.node.free()
	b.node.free()

func bone_host_check(world: Node3D) -> void:
	var model: Node3D = load(MODEL).instantiate()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("Horn")
	model.add_child(skeleton)
	world.add_child(model)
	var scene := "res://assets/effects/void_spawn/empowered.tscn"
	var key := ModelVisualResources.buff_key(scene, 20.0, 0)
	var owner := ModelVisualResources.new()
	owner.bind_model(model, {}, {"mode": "match", "buffs": [{"scene": scene, "radius": 20.0, "team": 0, "key": key}]})
	var node := owner.buff_node(key)
	var attachment: BoneAttachment3D = node._attachment
	var before := counts(owner)
	var pool := MatchModelPool.new()
	pool._world = world
	pool.strict_materials = true
	pool._material_states[MODEL] = owner._material_plan
	pool.capacity[MODEL] = 1
	pool.instances[MODEL] = [model]
	model.set_meta("pool_path", MODEL)
	model.set_meta("prepared_model_resources", owner)
	model.set_meta("prepared_animation_player", owner.animation_player())
	model.set_meta("pool_state", pool._capture_state(model))
	var taken := pool.take(load(MODEL)) as Node3D
	var host := Node3D.new()
	world.add_child(host)
	host.add_child(taken)
	node.advance(true, 0.1)
	check(pool.recycle(taken, owner, owner.animation_player()), "bone effect model really recycles")
	taken = pool.take(load(MODEL)) as Node3D
	check(node.get_parent() == model and is_instance_valid(attachment) and not attachment.is_queued_for_deletion() and node._orb.get_parent() == attachment, "actual take/recycle/take retains cached bone attachment across tree exits")
	check(not ModelVisualResources.is_model_geometry(node._orb) and counts(owner) == before and node._elapsed == 0.0, "private bone effect excluded from bounds and reset without new candidate")
	owner.clear()
	check(not is_instance_valid(attachment), "explicit cache release frees external bone attachment")
	taken.free()
	host.free()
	model = load(MODEL).instantiate()
	world.add_child(model)
	scene = "res://assets/effects/darius/blood_rage.tscn"
	key = ModelVisualResources.buff_key(scene, 20.0, 0)
	owner = ModelVisualResources.new()
	owner.bind_model(model, {}, {"mode": "match", "buffs": [{"scene": scene, "radius": 20.0, "team": 0, "key": key}]})
	node = owner.buff_node(key)
	node._fade = 0.8
	node._elapsed = 8.0
	before = counts(owner)
	owner.park_buff(node)
	check(node._fade == 0.0 and node._elapsed == 0.0 and not node.visible and counts(owner) == before, "real fade buff reset cannot leak prior actor state")
	owner.clear()
	model.free()

func mesh_and_tool_checks() -> void:
	var primitive := BoxMesh.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive.get_mesh_arrays())
	var material := StandardMaterial3D.new()
	material.resource_name = "body"
	mesh.surface_set_material(0, material)
	var result := BUILDER.process_mesh(mesh, {"exclude_materials": [], "material_textures": {"body": "res://tests/fixtures/material_plan_texture.tres"}})
	check(result.errors.is_empty() and result.mesh != null and result.mesh.surface_get_material(0).albedo_texture != null and material.albedo_texture == null, "texture-only operation works and source stays unchanged")
	result = BUILDER.process_mesh(mesh, {"exclude_materials": ["absent"]})
	check(result.errors.is_empty() and result.mesh == null, "no-op omits redundant full mesh output")
	mesh.shadow_mesh = mesh.duplicate(false) as ArrayMesh
	result = BUILDER.process_mesh(mesh, {"exclude_materials": ["body"]})
	check(not result.errors.is_empty() and result.mesh == null, "non-empty shadow mesh explicitly rejected")
	var wrapper: Node3D = load("res://scripts/presentation/model_template_view.gd").new()
	check(not ModelVisualResources.prepare_visual_root(wrapper).is_empty(), "direct wrapper tool preparation returns structured failure")
	wrapper.free()
	wrapper = load("res://assets/units/sion/sion_view.gd").new()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	wrapper.add_child(player)
	var body := MeshInstance3D.new()
	body.name = "Meshes"
	body.mesh = BoxMesh.new()
	wrapper.add_child(body)
	var template: Resource = load("res://scripts/presentation/model_visual_template.gd").new()
	template.libraries[&""] = AnimationLibrary.new()
	template.meshes.unarmed = ArrayMesh.new()
	wrapper.visual_template = template
	check(not ModelVisualResources.prepare_visual_root(wrapper).is_empty(), "subclass geometry failure remains structured for direct tools")
	wrapper.free()
	for path in ["res://tests/suites/presentation/loading_assets_suite.gd", "res://scripts/main.gd", "res://scripts/ui/workbench/model_preview.gd", "res://tools/viewers/model_studio.gd", "res://tools/viewers/camera_studio.gd", "res://tools/viewers/cover_studio.gd"]:
		var script := load(path) as Script
		check(script != null and script.can_instantiate(), "changed consumer compiles: " + path)

func run() -> void:
	if not pulse.enabled or output.is_empty(): quit(2); return
	if "--compile-render" in OS.get_cmdline_user_args():
		pulse.set_phase("compile-render", true)
		var script := load("res://tools/maintenance/model_material_render.gd") as Script
		check(script != null and script.can_instantiate(), "strict renderer compiles")
		var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
		file.close()
		quit(0 if failures.is_empty() else 1)
		return
	pulse.set_phase("strict-material-fixtures", true)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 4, 8)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	state_checks(world)
	closure_attach_checks(world, camera)
	await pool_entry_checks(world, camera)
	layered_buff_check(world)
	preserve_check(world)
	bone_host_check(world)
	mesh_and_tool_checks()
	world.free()
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results}, "	"))
	file.close()
	quit(0 if failures.is_empty() else 1)
