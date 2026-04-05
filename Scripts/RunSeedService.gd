class_name RunSeedService
extends RefCounted
## Deterministic run RNG with named streams and save/restore support.

const SEED_VERSION: int = 1
const DEFAULT_STREAM_NAMES: Array[String] = [
	"map",
	"roll",
	"shop",
	"reward",
	"event",
	"forge",
	"contract",
	"misc",
]

var root_seed_text: String = ""
var seed_version: int = SEED_VERSION

var _streams: Dictionary = {}


func configure(seed_text: String, version: int = SEED_VERSION) -> void:
	root_seed_text = normalize_seed_text(seed_text)
	if root_seed_text.is_empty():
		root_seed_text = make_random_seed_text()
	seed_version = version
	_streams.clear()
	for stream_name: String in DEFAULT_STREAM_NAMES:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = _derive_stream_seed(stream_name)
		_streams[stream_name] = rng


func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = _derive_stream_seed(stream_name)
		_streams[stream_name] = rng
	return _streams[stream_name] as RandomNumberGenerator


func randf_stream(stream_name: String) -> float:
	return stream(stream_name).randf()


func randi_stream(stream_name: String) -> int:
	return int(stream(stream_name).randi())


func randi_range_stream(stream_name: String, min_value: int, max_value: int) -> int:
	return stream(stream_name).randi_range(min_value, max_value)


func randf_range_stream(stream_name: String, min_value: float, max_value: float) -> float:
	return stream(stream_name).randf_range(min_value, max_value)


func pick_index(stream_name: String, size: int) -> int:
	if size <= 0:
		return -1
	return randi_range_stream(stream_name, 0, size - 1)


func shuffle_copy(stream_name: String, values: Array) -> Array:
	var copied: Array = values.duplicate()
	shuffle_in_place(stream_name, copied)
	return copied


func shuffle_in_place(stream_name: String, values: Array) -> void:
	if values.size() <= 1:
		return
	var rng: RandomNumberGenerator = stream(stream_name)
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp


func snapshot_stream_states() -> Dictionary:
	var states: Dictionary = {}
	for stream_name: String in _streams.keys():
		var rng: RandomNumberGenerator = _streams[stream_name] as RandomNumberGenerator
		states[stream_name] = int(rng.state)
	return states


func restore_stream_states(states: Dictionary) -> void:
	for stream_name: Variant in states.keys():
		var key: String = str(stream_name)
		var rng: RandomNumberGenerator = stream(key)
		rng.state = int(states.get(stream_name, 0))


func _derive_stream_seed(stream_name: String) -> int:
	var seed_material: String = "%s|%d|%s" % [root_seed_text, seed_version, stream_name]
	return _stable_hash(seed_material)


static func normalize_seed_text(seed_text: String) -> String:
	return seed_text.strip_edges()


static func make_random_seed_text() -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return "AUTO-%X-%X" % [
		int(Time.get_unix_time_from_system()),
		int(rng.randi()),
	]


static func _stable_hash(value: String) -> int:
	# FNV-1a 64-bit hash for stable deterministic seeds across sessions.
	var hash_value: int = 1469598103934665603
	for byte_value: int in value.to_utf8_buffer():
		hash_value = hash_value ^ byte_value
		hash_value = int(hash_value * 1099511628211)
	if hash_value == 0:
		hash_value = 1
	return hash_value
