extends RefCounted
## LoL emitter render flags. Use the same selector for runtime and resource manifests.
const DISABLE_Z_BUFFER := 0x1
static func shader_path(base_path: String, emitter: Dictionary) -> String:
	if (int(emitter.get("miscRenderFlags", 0)) & DISABLE_Z_BUFFER) != 0:
		return base_path.trim_suffix(".gdshader") + "_no_depth.gdshader"
	return base_path
