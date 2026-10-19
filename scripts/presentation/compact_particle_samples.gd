extends RefCounted
## Offline little-endian int64 IDs + float64 values. Runtime never expands the source JSON.
const MAGIC := "CLPS0001"
var data := {}
var offsets := PackedInt64Array()
var ids := PackedInt64Array()
var values := PackedFloat64Array()
var frames := 0
var layers := 0
var width := 0
var errors := PackedStringArray()

func read(path: String, source: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail("缺少紧凑粒子采样: " + path)
	if file.get_buffer(8).get_string_from_ascii() != MAGIC: return _fail("紧凑粒子文件标识错误")
	var header_size := file.get_32()
	if header_size < 2 or header_size > 1048576 or file.get_length() < 12 + header_size: return _fail("紧凑采样头长度错误")
	var header: Variant = JSON.parse_string(file.get_buffer(header_size).get_string_from_utf8())
	if not header is Dictionary: return _fail("紧凑采样头不是字典")
	for field in ["schema", "frames", "layers", "rows", "width", "payload_bytes"]:
		if typeof(header.get(field)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(header[field])) or float(header[field]) != floor(float(header[field])): return _fail("紧凑采样数字错误: " + field)
	if int(header.schema) != 1 or header.get("source") != source or not header.get("source_sha256") is String or not header.get("payload_sha256") is String: return _fail("紧凑采样schema/来源错误")
	frames = int(header.frames)
	layers = int(header.layers)
	width = int(header.width)
	var rows := int(header.rows)
	if frames <= 0 or frames > 1000000 or layers <= 0 or layers > 1024 or rows < 0 or rows > 10000000 or width < 4 or width > 256: return _fail("紧凑采样维度越界")
	var expected := (frames * layers + 1 + rows * width) * 8
	if frames <= 0 or layers <= 0 or width < 4 or rows < 0 or expected != int(header.payload_bytes) or expected > 268435456: return _fail("紧凑采样维度/载荷长度错误")
	if not header.get("data") is Dictionary or not header.data.get("emitters") is Array or header.data.emitters.size() != layers: return _fail("紧凑采样发射器错误")
	if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != header.source_sha256: return _fail("紧凑采样源SHA失配，需离线重新生成")
	var compressed := file.get_buffer(file.get_length() - file.get_position())
	var payload := compressed.decompress(expected, FileAccess.COMPRESSION_ZSTD)
	compressed.clear()
	if payload.size() != expected: return _fail("紧凑采样解压长度错误")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	if hash.finish().hex_encode() != header.payload_sha256: return _fail("紧凑采样载荷SHA错误")
	var offset_end := (frames * layers + 1) * 8
	var id_end := offset_end + rows * 8
	offsets = payload.slice(0, offset_end).to_int64_array()
	ids = payload.slice(offset_end, id_end).to_int64_array()
	values = payload.slice(id_end).to_float64_array()
	payload.clear()
	if offsets[0] != 0 or offsets[-1] != rows: return _fail("紧凑采样偏移端点错误")
	for index in range(1, offsets.size()):
		if offsets[index] < offsets[index - 1] or offsets[index] > rows: return _fail("紧凑采样偏移越界")
	data = header.data
	return true

func _fail(message: String) -> bool:
	errors.append(message)
	data.clear()
	offsets.clear()
	ids.clear()
	values.clear()
	return false

func begin(frame: int, layer: int) -> int:
	return offsets[frame * layers + layer]

func count(frame: int, layer: int) -> int:
	var slot := frame * layers + layer
	return offsets[slot + 1] - offsets[slot]

func row(index: int) -> Array:
	var result: Array = [ids[index]]
	var start := index * (width - 1)
	for column in width - 1: result.append(values[start + column])
	return result

func sample_ages() -> Array[float]:
	var ages: Array[float] = []
	for age in [0.025, 0.05, 0.1, 0.2, 0.4, 0.8, 1.5, 2.5, 4.0]:
		if age <= float(data.duration): ages.append(age)
	var pending: Array = range(layers)
	for frame in frames:
		for layer in pending.duplicate():
			var minimum := 2 if data.emitters[layer].get("trail") != null else 1
			if count(frame, layer) < minimum: continue
			var age := minf((float(frame) + 0.25) / float(data.fps), float(data.duration))
			if age not in ages: ages.append(age)
			pending.erase(layer)
		if pending.is_empty(): break
	ages.sort()
	return ages
