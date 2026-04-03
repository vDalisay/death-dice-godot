extends Node
## Object pool for CPUParticles2D emitters to avoid per-frame allocation.
## Autoload singleton — access as ParticlePool.acquire(parent).
## Each pool entry is a pre-created CPUParticles2D that gets recycled.

const MAX_POOL_SIZE: int = 40
const INITIAL_POOL_SIZE: int = 12

## Active emitter budget — if this many are in-flight, skip new requests.
const MAX_ACTIVE_EMITTERS: int = 30

var _pool: Array[CPUParticles2D] = []
var _active_count: int = 0
var _pool_root: Node = null


func _ready() -> void:
	_ensure_pool_root()
	for i: int in INITIAL_POOL_SIZE:
		_pool.append(_create_emitter())


## Acquire a pooled emitter and reparent it under the given parent.
## Returns null if budget exceeded.
func acquire(parent: Node) -> CPUParticles2D:
	if _active_count >= MAX_ACTIVE_EMITTERS:
		return null
	_ensure_pool_root()
	var emitter: CPUParticles2D
	if _pool.size() > 0:
		emitter = _pool.pop_back()
	elif _active_count + _pool.size() < MAX_POOL_SIZE:
		emitter = _create_emitter()
	else:
		return null
	_active_count += 1
	emitter.emitting = false
	emitter.visible = true
	if emitter.get_parent():
		emitter.get_parent().remove_child(emitter)
	parent.add_child(emitter)
	return emitter


## Configure a pooled emitter with burst-style settings.
func configure_burst(emitter: CPUParticles2D, config: Dictionary) -> void:
	emitter.one_shot = config.get("one_shot", true)
	emitter.amount = config.get("amount", 16)
	emitter.lifetime = config.get("lifetime", 0.3)
	emitter.explosiveness = config.get("explosiveness", 0.8)
	emitter.direction = config.get("direction", Vector2.ZERO)
	emitter.spread = config.get("spread", 180.0)
	emitter.initial_velocity_min = config.get("initial_velocity_min", 60.0)
	emitter.initial_velocity_max = config.get("initial_velocity_max", 140.0)
	emitter.gravity = config.get("gravity", Vector2.ZERO)
	emitter.color = config.get("color", Color.WHITE)
	emitter.position = config.get("position", Vector2.ZERO)
	if config.has("color_ramp"):
		emitter.color_ramp = config.get("color_ramp")
	else:
		emitter.color_ramp = null
	if config.has("scale_amount_min"):
		emitter.scale_amount_min = config.get("scale_amount_min")
	else:
		emitter.scale_amount_min = 1.0
	if config.has("scale_amount_max"):
		emitter.scale_amount_max = config.get("scale_amount_max")
	else:
		emitter.scale_amount_max = 1.0


## Release an emitter back to the pool after a delay.
func release_after(emitter: CPUParticles2D, delay: float) -> void:
	if not is_instance_valid(emitter):
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(delay).timeout.connect(func() -> void:
		_return_emitter(emitter)
	)


func _return_emitter(emitter: CPUParticles2D) -> void:
	_active_count = max(_active_count - 1, 0)
	if not is_instance_valid(emitter):
		return
	_ensure_pool_root()
	emitter.emitting = false
	emitter.visible = false
	emitter.top_level = false
	if emitter.get_parent():
		emitter.get_parent().remove_child(emitter)
	if _pool.size() < MAX_POOL_SIZE:
		_pool_root.add_child(emitter)
		_pool.append(emitter)
	else:
		emitter.queue_free()


func _create_emitter() -> CPUParticles2D:
	var emitter := CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.visible = false
	_ensure_pool_root()
	_pool_root.add_child(emitter)
	return emitter


func _ensure_pool_root() -> void:
	if _pool_root != null and is_instance_valid(_pool_root):
		return
	_pool_root = Node.new()
	_pool_root.name = "PoolRoot"
	add_child(_pool_root)
