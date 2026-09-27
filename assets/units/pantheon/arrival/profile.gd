@static_unload
extends RefCounted
## Project-only adaptation. Imported curves and asset hashes remain separate.
const PATH := "res://assets/units/pantheon/arrival/integration.json"
static var _profile: Dictionary = {}
static var _native: Dictionary = {}

static func native_composition() -> Dictionary:
	if _native.is_empty(): _native = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/pantheon/arrival/native_composition.json"))
	return _native

static func data() -> Dictionary:
	if _profile.is_empty():
		_profile = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _profile

static func layer(system: String, emitter: String) -> Dictionary:
	return data().layers[system + "/" + emitter]

static func frame(kind: String, forward: Vector3, rise: float = 0.5) -> Basis:
	var side := forward.cross(Vector3.UP).normalized()
	match kind:
		"flight":
			var flight := (forward - Vector3.UP * rise).normalized()
			return Basis(side, flight, side.cross(flight).normalized())
		"spear":
			var spear_direction := (forward - Vector3.UP * rise).normalized()
			return Basis(side, spear_direction, side.cross(spear_direction).normalized())
		"slide": return Basis(side, forward, Vector3.UP)
		"ending": return Basis(forward, Vector3.UP, side)
	return Basis(Vector3.UP, atan2(forward.x, forward.z))

static func path_forward(kind: String, basis: Basis) -> Vector3:
	if kind == "ending": return basis.x.normalized()
	if kind in ["flight", "slide"]:
		return Vector3(basis.y.x, 0, basis.y.z).normalized()
	return basis.z.normalized()
