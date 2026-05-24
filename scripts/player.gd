class_name Player
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal player_died
signal pulse_blast(origin: Vector2, radius: float, damage: int)

const COLLISION_RADIUS := 18.0
const PLAYER_LAYER := 1
const WALL_LAYER := 4
const FULL_CIRCLE := PI * 2.0

@export var base_speed: float = 285.0
@export var base_max_health: int = 5
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 1.15
@export var pulse_radius: float = 150.0
@export var pulse_damage: int = 3
@export var pulse_cooldown: float = 4.6
@export var fire_interval: float = 0.36
@export var projectile_damage: int = 1
@export var projectile_pierce: int = 0
@export var projectile_speed: float = 680.0
@export var multishot: int = 1
@export var magnet_radius: float = 150.0

var health: int = base_max_health
var max_health: int = base_max_health
var speed_bonus: float = 1.0
var dash_cooldown_bonus: float = 1.0
var pulse_cooldown_bonus: float = 1.0
var pulse_radius_bonus: float = 1.0
var is_dead := false
var world_bounds := Rect2(Vector2.ZERO, Vector2(1800, 1100))

var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _pulse_cooldown_timer := 0.0
var _invulnerable_timer := 0.0
var _dash_direction := Vector2.RIGHT
var _facing := Vector2.RIGHT
var _camera: Camera2D

func _ready() -> void:
    z_index = 20
    collision_layer = PLAYER_LAYER
    collision_mask = WALL_LAYER
    _ensure_collision_shape()
    _ensure_camera()
    reset_for_new_run(world_bounds)

func _physics_process(delta: float) -> void:
    if is_dead:
        velocity = Vector2.ZERO
        move_and_slide()
        return

    _tick_timers(delta)
    _handle_pulse_input()
    _handle_dash_and_movement(delta)
    _clamp_to_world()
    queue_redraw()

func reset_for_new_run(bounds: Rect2) -> void:
    world_bounds = bounds
    max_health = base_max_health
    health = max_health
    speed_bonus = 1.0
    dash_cooldown_bonus = 1.0
    pulse_cooldown_bonus = 1.0
    pulse_radius_bonus = 1.0
    fire_interval = 0.36
    projectile_damage = 1
    projectile_pierce = 0
    projectile_speed = 680.0
    multishot = 1
    magnet_radius = 150.0
    dash_speed = 760.0
    _dash_timer = 0.0
    _dash_cooldown_timer = 0.0
    _pulse_cooldown_timer = 0.0
    _invulnerable_timer = 0.0
    is_dead = false
    visible = true
    set_physics_process(true)
    health_changed.emit(health, max_health)
    queue_redraw()

func configure_world(bounds: Rect2) -> void:
    world_bounds = bounds
    if is_instance_valid(_camera):
        _camera.limit_left = int(bounds.position.x)
        _camera.limit_top = int(bounds.position.y)
        _camera.limit_right = int(bounds.position.x + bounds.size.x)
        _camera.limit_bottom = int(bounds.position.y + bounds.size.y)

func take_damage(amount: int = 1) -> bool:
    if is_dead or _invulnerable_timer > 0.0:
        return false

    health = maxi(health - amount, 0)
    _invulnerable_timer = 0.85
    health_changed.emit(health, max_health)

    if health <= 0:
        is_dead = true
        velocity = Vector2.ZERO
        player_died.emit()
    queue_redraw()
    return true

func heal(amount: int) -> void:
    if is_dead:
        return
    health = mini(health + amount, max_health)
    health_changed.emit(health, max_health)
    queue_redraw()

func add_max_health(amount: int) -> void:
    max_health += amount
    health = mini(health + amount, max_health)
    health_changed.emit(health, max_health)
    queue_redraw()

func get_dash_ready_ratio() -> float:
    var cooldown := get_dash_cooldown()
    if cooldown <= 0.0:
        return 1.0
    return 1.0 - clampf(_dash_cooldown_timer / cooldown, 0.0, 1.0)

func get_pulse_ready_ratio() -> float:
    var cooldown := get_pulse_cooldown()
    if cooldown <= 0.0:
        return 1.0
    return 1.0 - clampf(_pulse_cooldown_timer / cooldown, 0.0, 1.0)

func get_dash_cooldown() -> float:
    return maxf(0.25, dash_cooldown * dash_cooldown_bonus)

func get_pulse_cooldown() -> float:
    return maxf(1.0, pulse_cooldown * pulse_cooldown_bonus)

func get_pulse_radius() -> float:
    return pulse_radius * pulse_radius_bonus

func get_facing() -> Vector2:
    return _facing

func get_speed() -> float:
    return base_speed * speed_bonus

func _tick_timers(delta: float) -> void:
    _dash_timer = maxf(_dash_timer - delta, 0.0)
    _dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
    _pulse_cooldown_timer = maxf(_pulse_cooldown_timer - delta, 0.0)
    _invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)

func _handle_pulse_input() -> void:
    if Input.is_action_just_pressed("pulse") and _pulse_cooldown_timer <= 0.0:
        var radius := get_pulse_radius()
        pulse_blast.emit(global_position, radius, pulse_damage)
        _pulse_cooldown_timer = get_pulse_cooldown()
        _invulnerable_timer = maxf(_invulnerable_timer, 0.12)

func _handle_dash_and_movement(_delta: float) -> void:
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if direction.length_squared() > 0.01:
        _facing = direction.normalized()

    if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
        _dash_direction = _facing
        if direction.length_squared() > 0.01:
            _dash_direction = direction.normalized()
        _dash_timer = dash_duration
        _dash_cooldown_timer = get_dash_cooldown()
        _invulnerable_timer = maxf(_invulnerable_timer, dash_duration + 0.08)

    if _dash_timer > 0.0:
        velocity = _dash_direction * dash_speed
    else:
        velocity = direction.normalized() * get_speed()

    move_and_slide()

func _clamp_to_world() -> void:
    global_position.x = clampf(global_position.x, world_bounds.position.x + COLLISION_RADIUS, world_bounds.position.x + world_bounds.size.x - COLLISION_RADIUS)
    global_position.y = clampf(global_position.y, world_bounds.position.y + COLLISION_RADIUS, world_bounds.position.y + world_bounds.size.y - COLLISION_RADIUS)

func _ensure_collision_shape() -> void:
    var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if shape_node == null:
        shape_node = CollisionShape2D.new()
        shape_node.name = "CollisionShape2D"
        add_child(shape_node)

    var circle := shape_node.shape as CircleShape2D
    if circle == null:
        circle = CircleShape2D.new()
        shape_node.shape = circle
    circle.radius = COLLISION_RADIUS

func _ensure_camera() -> void:
    _camera = get_node_or_null("Camera2D") as Camera2D
    if _camera == null:
        _camera = Camera2D.new()
        _camera.name = "Camera2D"
        add_child(_camera)
    _camera.enabled = true
    _camera.zoom = Vector2(0.86, 0.86)
    _camera.position_smoothing_enabled = true
    _camera.position_smoothing_speed = 8.0

func _draw() -> void:
    var invulnerable := _invulnerable_timer > 0.0
    var flicker := invulnerable and int(Time.get_ticks_msec() / 70) % 2 == 0
    var body_color := Color(0.18, 0.95, 1.0, 0.95)
    if flicker:
        body_color.a = 0.45

    var back := -_facing * 13.0
    var right := Vector2(-_facing.y, _facing.x)
    var ship := PackedVector2Array([
        _facing * 24.0,
        back + right * 15.0,
        back - right * 15.0
    ])

    draw_circle(Vector2.ZERO, COLLISION_RADIUS + 8.0, Color(0.03, 0.2, 0.33, 0.65))
    draw_colored_polygon(ship, body_color)
    draw_polyline(PackedVector2Array([ship[0], ship[1], ship[2], ship[0]]), Color(0.75, 1.0, 1.0, 0.95), 2.5, true)
    draw_line(back, back - _facing * 18.0, Color(1.0, 0.46, 0.12, 0.85), 5.0, true)

    if invulnerable:
        draw_arc(Vector2.ZERO, COLLISION_RADIUS + 13.0, 0.0, FULL_CIRCLE, 48, Color(0.8, 1.0, 1.0, 0.75), 3.0, true)

    var dash_ratio := get_dash_ready_ratio()
    var pulse_ratio := get_pulse_ready_ratio()
    draw_arc(Vector2.ZERO, COLLISION_RADIUS + 18.0, -PI / 2.0, -PI / 2.0 + FULL_CIRCLE * dash_ratio, 36, Color(0.3, 0.65, 1.0, 0.95), 2.0, true)
    draw_arc(Vector2.ZERO, COLLISION_RADIUS + 22.0, -PI / 2.0, -PI / 2.0 + FULL_CIRCLE * pulse_ratio, 36, Color(1.0, 0.72, 0.18, 0.95), 2.0, true)
