extends GdUnitTestSuite
## Unit tests for ParticlePool emitter pooling system.

const PoolScript: GDScript = preload("res://Scripts/ParticlePool.gd")

var _pool: Node = null


func before_test() -> void:
	_pool = PoolScript.new()
	_pool.name = "ParticlePool"
	add_child(_pool)
	await get_tree().process_frame


func after_test() -> void:
	if is_instance_valid(_pool):
		_pool.queue_free()
	_pool = null


func test_pool_constants_are_sensible() -> void:
	assert_int(_pool.MAX_POOL_SIZE).is_greater(0)
	assert_int(_pool.INITIAL_POOL_SIZE).is_greater(0)
	assert_int(_pool.MAX_ACTIVE_EMITTERS).is_greater(0)
	assert_int(_pool.INITIAL_POOL_SIZE).is_less_equal(_pool.MAX_POOL_SIZE)


func test_acquire_returns_emitter() -> void:
	var parent: Node2D = auto_free(Node2D.new())
	add_child(parent)
	await get_tree().process_frame
	var emitter: CPUParticles2D = _pool.acquire(parent)
	assert_object(emitter).is_not_null()
	assert_bool(emitter.visible).is_true()
	assert_object(emitter.get_parent()).is_same(parent)
	_pool.release_after(emitter, 0.0)
	await get_tree().create_timer(0.1).timeout


func test_configure_burst_sets_properties() -> void:
	var parent: Node2D = auto_free(Node2D.new())
	add_child(parent)
	await get_tree().process_frame
	var emitter: CPUParticles2D = _pool.acquire(parent)
	assert_object(emitter).is_not_null()
	_pool.configure_burst(emitter, {
		"amount": 42,
		"lifetime": 1.5,
		"color": Color.RED,
		"direction": Vector2.UP,
		"spread": 45.0,
	})
	assert_int(emitter.amount).is_equal(42)
	assert_float(emitter.lifetime).is_equal(1.5)
	assert_object(emitter.color).is_equal(Color.RED)
	assert_object(emitter.direction).is_equal(Vector2.UP)
	assert_float(emitter.spread).is_equal(45.0)
	_pool.release_after(emitter, 0.0)
	await get_tree().create_timer(0.1).timeout


func test_release_returns_emitter_to_pool() -> void:
	var parent: Node2D = auto_free(Node2D.new())
	add_child(parent)
	await get_tree().process_frame
	var emitter: CPUParticles2D = _pool.acquire(parent)
	assert_object(emitter).is_not_null()
	_pool.release_after(emitter, 0.01)
	await get_tree().create_timer(0.15).timeout
	assert_bool(emitter.visible).is_false()


func test_budget_limit_returns_null() -> void:
	var parent: Node2D = auto_free(Node2D.new())
	add_child(parent)
	await get_tree().process_frame
	var emitters: Array[CPUParticles2D] = []
	for i: int in _pool.MAX_ACTIVE_EMITTERS:
		var e: CPUParticles2D = _pool.acquire(parent)
		if e:
			emitters.append(e)
	var over_budget: CPUParticles2D = _pool.acquire(parent)
	assert_object(over_budget).is_null()
	for e: CPUParticles2D in emitters:
		_pool.release_after(e, 0.0)
	await get_tree().create_timer(0.15).timeout
