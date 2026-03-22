---
name: godot-gdscript-patterns
description: Master Godot 4 GDScript patterns including signals, scenes, state machines, and optimization. Use when building Godot games, implementing game systems, or learning GDScript best practices.
---

# Godot GDScript Patterns

Production patterns for Godot 4.x game development with GDScript, covering architecture, signals, scenes, and optimization.

## When to Use This Skill

- Building games with Godot 4
- Implementing game systems in GDScript
- Designing scene architecture
- Managing game state
- Optimizing GDScript performance
- Learning Godot best practices

## Core Concepts

### 1. Godot Architecture

```
Node: Base building block
├── Scene: Reusable node tree (saved as .tscn)
├── Resource: Data container (saved as .tres)
├── Signal: Event communication
└── Group: Node categorization
```

### 2. GDScript Basics

```gdscript
class_name Player
extends CharacterBody2D

# Signals
signal health_changed(new_health: int)
signal died

# Exports (Inspector-editable)
@export var speed: float = 200.0
@export var max_health: int = 100
@export_range(0, 1) var damage_reduction: float = 0.0
@export_group("Combat")
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.5

# Onready (initialized when ready)
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox

# Private variables (convention: underscore prefix)
var _health: int
var _can_attack: bool = true

func _ready() -> void:
    _health = max_health

func _physics_process(delta: float) -> void:
    var direction := Input.get_vector("left", "right", "up", "down")
    velocity = direction * speed
    move_and_slide()

func take_damage(amount: int) -> void:
    var actual_damage := int(amount * (1.0 - damage_reduction))
    _health = max(_health - actual_damage, 0)
    health_changed.emit(_health)
    if _health <= 0:
        died.emit()
```

## Patterns

### Pattern 1: State Machine

```gdscript
# state_machine.gd
class_name StateMachine
extends Node

signal state_changed(from_state: StringName, to_state: StringName)

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
    for child in get_children():
        if child is State:
            states[child.name] = child
            child.state_machine = self
            child.process_mode = Node.PROCESS_MODE_DISABLED
    if initial_state:
        current_state = initial_state
        current_state.process_mode = Node.PROCESS_MODE_INHERIT
        current_state.enter()

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
    if current_state:
        current_state.handle_input(event)

func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
    if not states.has(state_name):
        push_error("State '%s' not found" % state_name)
        return
    var previous_state := current_state
    previous_state.exit()
    previous_state.process_mode = Node.PROCESS_MODE_DISABLED
    current_state = states[state_name]
    current_state.process_mode = Node.PROCESS_MODE_INHERIT
    current_state.enter(msg)
    state_changed.emit(previous_state.name, current_state.name)
```

```gdscript
# state.gd
class_name State
extends Node

var state_machine: StateMachine

func enter(_msg: Dictionary = {}) -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func handle_input(_event: InputEvent) -> void: pass
```

### Pattern 2: Autoload Singletons

```gdscript
# game_manager.gd (Add to Project Settings > Autoload)
extends Node

signal game_started
signal game_paused(is_paused: bool)
signal game_over(won: bool)
signal score_changed(new_score: int)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var state: GameState = GameState.MENU
var score: int = 0:
    set(value):
        score = value
        score_changed.emit(score)
var high_score: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_high_score()

func start_game() -> void:
    score = 0
    state = GameState.PLAYING
    game_started.emit()

func toggle_pause() -> void:
    var is_paused := state != GameState.PAUSED
    if is_paused:
        state = GameState.PAUSED
        get_tree().paused = true
    else:
        state = GameState.PLAYING
        get_tree().paused = false
    game_paused.emit(is_paused)

func end_game(won: bool) -> void:
    state = GameState.GAME_OVER
    if score > high_score:
        high_score = score
        _save_high_score()
    game_over.emit(won)

func add_score(points: int) -> void:
    score += points

func _load_high_score() -> void:
    if FileAccess.file_exists("user://high_score.save"):
        var file := FileAccess.open("user://high_score.save", FileAccess.READ)
        high_score = file.get_32()

func _save_high_score() -> void:
    var file := FileAccess.open("user://high_score.save", FileAccess.WRITE)
    file.store_32(high_score)
```

```gdscript
# event_bus.gd (Global signal bus)
extends Node

signal player_spawned(player: Node2D)
signal player_died(player: Node2D)
signal player_health_changed(health: int, max_health: int)
signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, position: Vector2)
signal item_collected(item_type: StringName, value: int)
signal powerup_activated(powerup_type: StringName)
signal level_started(level_number: int)
signal level_completed(level_number: int, time: float)
signal checkpoint_reached(checkpoint_id: int)
```

### Pattern 3: Resource-based Data

```gdscript
# weapon_data.gd
class_name WeaponData
extends Resource

@export var name: StringName
@export var damage: int
@export var attack_speed: float
@export var range: float
@export_multiline var description: String
@export var icon: Texture2D
@export var projectile_scene: PackedScene
@export var sound_attack: AudioStream
```

```gdscript
# character_stats.gd
class_name CharacterStats
extends Resource

signal stat_changed(stat_name: StringName, new_value: float)

@export var max_health: float = 100.0
@export var attack: float = 10.0
@export var defense: float = 5.0
@export var speed: float = 200.0

var _current_health: float

func _init() -> void:
    _current_health = max_health

func get_current_health() -> float:
    return _current_health

func take_damage(amount: float) -> float:
    var actual_damage := maxf(amount - defense, 1.0)
    _current_health = maxf(_current_health - actual_damage, 0.0)
    stat_changed.emit("health", _current_health)
    return actual_damage

func heal(amount: float) -> void:
    _current_health = minf(_current_health + amount, max_health)
    stat_changed.emit("health", _current_health)

func duplicate_for_runtime() -> CharacterStats:
    var copy := duplicate() as CharacterStats
    copy._current_health = copy.max_health
    return copy
```

### Pattern 4: Object Pooling

```gdscript
# object_pool.gd
class_name ObjectPool
extends Node

@export var pooled_scene: PackedScene
@export var initial_size: int = 10
@export var can_grow: bool = true

var _available: Array[Node] = []
var _in_use: Array[Node] = []

func _ready() -> void:
    for i in initial_size:
        _create_instance()

func _create_instance() -> Node:
    var instance := pooled_scene.instantiate()
    instance.process_mode = Node.PROCESS_MODE_DISABLED
    instance.visible = false
    add_child(instance)
    _available.append(instance)
    if instance.has_signal("returned_to_pool"):
        instance.returned_to_pool.connect(_return_to_pool.bind(instance))
    return instance

func get_instance() -> Node:
    var instance: Node
    if _available.is_empty():
        if can_grow:
            instance = _create_instance()
            _available.erase(instance)
        else:
            push_warning("Pool exhausted and cannot grow")
            return null
    else:
        instance = _available.pop_back()
    instance.process_mode = Node.PROCESS_MODE_INHERIT
    instance.visible = true
    _in_use.append(instance)
    if instance.has_method("on_spawn"):
        instance.on_spawn()
    return instance

func _return_to_pool(instance: Node) -> void:
    if not instance in _in_use:
        return
    _in_use.erase(instance)
    if instance.has_method("on_despawn"):
        instance.on_despawn()
    instance.process_mode = Node.PROCESS_MODE_DISABLED
    instance.visible = false
    _available.append(instance)

func return_all() -> void:
    for instance in _in_use.duplicate():
        _return_to_pool(instance)
```

### Pattern 5: Component System

```gdscript
# health_component.gd
class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: Node)
signal healed(amount: int)
signal died

@export var max_health: int = 100
@export var invincibility_time: float = 0.0

var current_health: int:
    set(value):
        var old := current_health
        current_health = clampi(value, 0, max_health)
        if current_health != old:
            health_changed.emit(current_health, max_health)

var _invincible: bool = false

func _ready() -> void:
    current_health = max_health

func take_damage(amount: int, source: Node = null) -> int:
    if _invincible or current_health <= 0:
        return 0
    var actual := mini(amount, current_health)
    current_health -= actual
    damaged.emit(actual, source)
    if current_health <= 0:
        died.emit()
    elif invincibility_time > 0:
        _start_invincibility()
    return actual

func heal(amount: int) -> int:
    var actual := mini(amount, max_health - current_health)
    current_health += actual
    if actual > 0:
        healed.emit(actual)
    return actual

func _start_invincibility() -> void:
    _invincible = true
    await get_tree().create_timer(invincibility_time).timeout
    _invincible = false
```

### Pattern 6: Scene Management

```gdscript
# scene_manager.gd (Autoload)
extends Node

signal scene_loading_started(scene_path: String)
signal scene_loading_progress(progress: float)
signal scene_loaded(scene: Node)
signal transition_started
signal transition_finished

var _current_scene: Node

func _ready() -> void:
    _current_scene = get_tree().current_scene

func change_scene(scene_path: String) -> void:
    scene_loading_started.emit(scene_path)
    if ResourceLoader.has_cached(scene_path):
        var scene := load(scene_path) as PackedScene
        _swap_scene(scene.instantiate())
        return
    ResourceLoader.load_threaded_request(scene_path)
    while true:
        var progress := []
        var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
        match status:
            ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                scene_loading_progress.emit(progress[0])
                await get_tree().process_frame
            ResourceLoader.THREAD_LOAD_LOADED:
                var scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
                _swap_scene(scene.instantiate())
                return
            _:
                push_error("Failed to load scene: %s" % scene_path)
                return

func _swap_scene(new_scene: Node) -> void:
    if _current_scene:
        _current_scene.queue_free()
    _current_scene = new_scene
    get_tree().root.add_child(_current_scene)
    get_tree().current_scene = _current_scene
    scene_loaded.emit(_current_scene)
```

### Pattern 7: Save System

```gdscript
# save_manager.gd (Autoload)
extends Node

const SAVE_PATH := "user://savegame.save"
const ENCRYPTION_KEY := "your_secret_key_here"

signal save_completed
signal load_completed
signal save_error(message: String)

func save_game(data: Dictionary) -> void:
    var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
    if file == null:
        save_error.emit("Could not open save file")
        return
    file.store_string(JSON.stringify(data))
    file.close()
    save_completed.emit()

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPTION_KEY)
    if file == null:
        save_error.emit("Could not open save file")
        return {}
    var json := file.get_as_text()
    file.close()
    var parsed := JSON.parse_string(json)
    if parsed == null:
        save_error.emit("Could not parse save data")
        return {}
    load_completed.emit()
    return parsed

func delete_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(SAVE_PATH)

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)
```

## Performance Tips

```gdscript
# 1. Cache node references
@onready var sprite := $Sprite2D  # Good — cached once
# $Sprite2D in _process()        # Bad  — repeated lookup

# 2. Use object pooling for frequent spawning (see Pattern 4)

# 3. Avoid allocations in hot paths
var _reusable_array: Array = []
func _process(_delta: float) -> void:
    _reusable_array.clear()  # Reuse instead of creating new

# 4. Use static typing
func calculate(value: float) -> float:
    return value * 2.0

# 5. Disable processing when not needed
func _on_off_screen() -> void:
    set_process(false)
    set_physics_process(false)
```

## Best Practices

### Do's
- **Use signals for decoupling** — Avoid direct references between scenes
- **Type everything** — Static typing catches errors early
- **Use resources for data** — Separate data from logic
- **Pool frequently spawned objects** — Avoid GC hitches
- **Use Autoloads sparingly** — Only for truly global systems

### Don'ts
- **Don't use `get_node()` in loops** — Cache references with `@onready`
- **Don't couple scenes tightly** — Use signals instead
- **Don't put logic in resources** — Keep them data-only
- **Don't ignore the Profiler** — Monitor performance regularly
- **Don't fight the scene tree** — Work with Godot's design
