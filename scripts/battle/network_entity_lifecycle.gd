class_name NetworkEntityLifecycle
extends RefCounted
## 每局实体的出生描述、销毁标记和快照屏障；不访问场景、表现或 Main。
var session_id := ""
var spawns: Dictionary = {}
var destroyed: Dictionary = {}
var revision := 0
var snapshot_revision := -1
var snapshot_tick := -1
var snapshot_ids: Dictionary = {}

func reset(id: String) -> void:
	session_id = id
	spawns.clear()
	destroyed.clear()
	revision = 0
	snapshot_revision = -1
	snapshot_tick = -1
	snapshot_ids.clear()

func accepts_session(id: String) -> bool:
	return id == session_id

func host_spawn(id: int, tick: int, args: Array) -> void:
	revision += 1
	register_spawn(id, tick, revision, args)

func host_death(id: int, tick: int) -> void:
	revision += 1
	mark_destroyed(id, tick)

func register_spawn(id: int, birth_tick: int, birth_revision: int, args: Array) -> void:
	spawns[id] = {"birth_tick": birth_tick, "birth_revision": birth_revision, "args": args.duplicate(true)}

func accepts_spawn(id: int, birth_revision: int) -> bool:
	return not destroyed.has(id) and (birth_revision > snapshot_revision or snapshot_ids.has(id))

func snapshot_is_new(tick: int, version: int) -> bool:
	return tick >= snapshot_tick and version >= snapshot_revision and (tick > snapshot_tick or version > snapshot_revision)

func accept_snapshot(tick: int, version: int, ids: Dictionary) -> bool:
	if not snapshot_is_new(tick, version):
		return false
	snapshot_tick = tick
	snapshot_revision = version
	snapshot_ids = ids.duplicate()
	return true

func snapshot_can_remove(id: int) -> bool:
	return not snapshot_ids.has(id) and int(spawns.get(id, {}).get("birth_revision", -1)) <= snapshot_revision

func mark_destroyed(id: int, tick: int) -> void:
	destroyed[id] = maxi(tick, int(destroyed.get(id, -1)))
	spawns.erase(id)
