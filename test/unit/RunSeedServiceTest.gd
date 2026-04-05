extends GdUnitTestSuite
## Unit tests for deterministic named RNG streams.

const RunSeedServiceScript: GDScript = preload("res://Scripts/RunSeedService.gd")


func test_same_seed_produces_same_stream_values() -> void:
	var service_a: RefCounted = RunSeedServiceScript.new()
	var service_b: RefCounted = RunSeedServiceScript.new()
	service_a.configure("fixed-seed", RunSeedServiceScript.SEED_VERSION)
	service_b.configure("fixed-seed", RunSeedServiceScript.SEED_VERSION)
	var values_a: Array[int] = []
	var values_b: Array[int] = []
	for _i in range(6):
		values_a.append(service_a.randi_range_stream("map", 0, 9999))
		values_b.append(service_b.randi_range_stream("map", 0, 9999))
	assert_array(values_a).is_equal(values_b)


func test_snapshot_restore_resumes_stream_sequence() -> void:
	var service: RefCounted = RunSeedServiceScript.new()
	service.configure("resume-seed", RunSeedServiceScript.SEED_VERSION)
	var _first_value: int = service.randi_stream("shop")
	var snapshot: Dictionary = service.snapshot_stream_states()
	var expected_next: int = service.randi_stream("shop")
	var restored: RefCounted = RunSeedServiceScript.new()
	restored.configure("resume-seed", RunSeedServiceScript.SEED_VERSION)
	restored.restore_stream_states(snapshot)
	assert_int(restored.randi_stream("shop")).is_equal(expected_next)


func test_pick_index_handles_empty_array_size() -> void:
	var service: RefCounted = RunSeedServiceScript.new()
	service.configure("fixed-seed", RunSeedServiceScript.SEED_VERSION)
	assert_int(service.pick_index("event", 0)).is_equal(-1)
