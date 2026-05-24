class_name EnemyUnit
extends CharacterBody2D

signal died(enemy: Node, score_value: int)

const ENEMY_LAYER := 2
const WALL_LAYER := 4
const FULL_CIRCLE := PI * 2.0

enum EnemyKind { DRONE, SENTINEL, WRAITH, TANK, BOSS }

var kind: int = EnemyKind.DRONE
var target: Node2D
var max_health := 3
var health := 3
var speed := 120.0
var contact_damage := 1
var score_value := 50
var radius := 17.0
var accent := Color(1.0, 0.22, 0.32)
var title := "Drone"
var is_boss := false
var is_dead := false

var _touch_cooldown := 0.0
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector2.ZERO
var _knockback := Vector2.ZERO
var _flash_timer := 0.0
var _orbit_sign := 1.0
var _age := 0.0
var _death_scheduled := false

func setup(new_kind: int, new_target: Node2D, wave_number: int) -> void:
    kind = new_kind
    target = new_target
    _orbit_sign = 1.0 if randi() % 2 == 0 else -1.0

    match kind:
        EnemyKind.DRONE:
            title = "Drone"
            max_health = 2 + wave_number
            speed = 142.0 + wave_number * 8.0
            contact_damage = 1
            score_value = 40 + wave_number * 8
            radius = 16.0
            accent = Color(1.0, 0.23, 0.36)
        EnemyKind.SENTINEL:
            title = "Sentinel"
            max_health = 4 + wave_number * 2
            speed = 108.0 + wave_number * 5.0
            contact_damage = 1
            score_value = 75 + wave_number * 12
            radius = 20.0
            accent = Color(1.0, 0.62, 0.15)
        EnemyKind.WRAITH:
            title = "Wraith"
            max_health = 3 + wave_number
            speed = 128.0 + wave_number * 8.0
            contact_damage = 2
            score_value = 95 + wave_number * 15
            radius = 18.0
            accent = Color(0.8, 0.36, 1.0)
            _dash_cooldown = 1.0 + randf() * 0.8
        EnemyKind.TANK:
            title = "Bulwark"
            max_health = 9 + wave_number * 3
            speed = 76.0 + wave_number * 4.0
            contact_damage = 2
            score_value = 140 + wave_number * 22
            radius = 27.0
            accent = Color(0.22, 1.0, 0.62)
        EnemyKind.BOSS:
            title = "The Anchor"
            max_health = 95 + wave_number * 12
            speed = 95.0
            contact_damage = 3
            score_value = 1400
            radius = 46.0
            accent = Color(1.0, 0.1, 0.85)
            is_boss = true

    health = max_health
    z_index = 12 if not is_boss else 14

func _ready() -> void:
    collision_layer = ENEMY_LAYER
    collision_mask = WALL_LAYER
    _ensure_collision_shape()
    queue_redraw()

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    _age += delta
    _touch_cooldown = maxf(_touch_cooldown - delta, 0.0)
    _flash_timer = maxf(_flash_timer - delta, 0.0)
    _dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
    _dash_timer = maxf(_dash_timer - delta, 0.0)

    if not is_instance_valid(target):
        velocity = _knockback
        move_and_slide()
        return

    var to_target := target.global_position - global_position
    var distance := maxf(to_target.length(), 1.0)
    var direction := to_target / distance
    var desired_velocity := Vector2.ZERO

    match kind:
        EnemyKind.DRONE:
            desired_velocity = direction * speed
        EnemyKind.SENTINEL:
            var tangent := Vector2(-direction.y, direction.x) * _orbit_sign
            var range_error := clampf((distance - 185.0) / 140.0, -1.0, 1.0)
            desired_velocity = direction * speed * range_error + tangent * speed * 0.72
        EnemyKind.WRAITH:
            if _dash_timer > 0.0:
                desired_velocity = _dash_direction * speed * 3.2
            elif _dash_cooldown <= 0.0 and distance < 560.0:
                _dash_direction = direction
                _dash_timer = 0.22
                _dash_cooldown = 1.55 + randf() * 0.7
                desired_velocity = _dash_direction * speed * 3.2
            else:
                var sidestep := Vector2(-direction.y, direction.x) * sin(_age * 4.0) * 0.55
                desired_velocity = (direction + sidestep).normalized() * speed
        EnemyKind.TANK:
            desired_velocity = direction * speed
        EnemyKind.BOSS:
            var tangent := Vector2(-direction.y, direction.x) * sin(_age * 0.85)
            var surge := 1.0 + 0.26 * sin(_age * 1.7)
            desired_velocity = (direction * surge + tangent * 0.55).normalized() * speed

    velocity = desired_velocity + _knockback
    _knockback = _knockback.move_toward(Vector2.ZERO, 780.0 * delta)
    move_and_slide()
    queue_redraw()

func apply_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> bool:
    if is_dead:
        return false

    health -= amount
    _knockback += knockback
    _flash_timer = 0.11

    if health <= 0 and not _death_scheduled:
        _death_scheduled = true
        is_dead = true
        set_deferred("collision_layer", 0)
        set_deferred("collision_mask", 0)
        call_deferred("_finish_death")
        return true

    queue_redraw()
    return false

func _finish_death() -> void:
    if not is_inside_tree():
        return
    died.emit(self, score_value)
    queue_free()

func can_deal_contact_damage() -> bool:
    if _touch_cooldown > 0.0 or is_dead:
        return false
    _touch_cooldown = 0.82 if not is_boss else 0.68
    return true

func get_health_ratio() -> float:
    return clampf(float(health) / float(max_health), 0.0, 1.0)

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
    circle.radius = radius

func _draw() -> void:
    var flash_color := Color(1.0, 1.0, 1.0, 0.95)
    var core_color := flash_color if _flash_timer > 0.0 else accent
    var shadow := Color(0.0, 0.0, 0.0, 0.28)

    draw_circle(Vector2(3, 5), radius + 3.0, shadow)

    match kind:
        EnemyKind.DRONE:
            draw_circle(Vector2.ZERO, radius, Color(core_color.r, core_color.g, core_color.b, 0.78))
            draw_arc(Vector2.ZERO, radius + 4.0, _age * 2.4, _age * 2.4 + PI * 1.35, 24, Color(1, 1, 1, 0.55), 2.0, true)
        EnemyKind.SENTINEL:
            var points := PackedVector2Array()
            for i in range(6):
                var angle := FULL_CIRCLE * float(i) / 6.0 + _age * 0.45
                points.append(Vector2(cos(angle), sin(angle)) * radius)
            draw_colored_polygon(points, Color(core_color.r, core_color.g, core_color.b, 0.78))
            draw_polyline(_closed(points), Color(1.0, 0.95, 0.55, 0.9), 2.0, true)
        EnemyKind.WRAITH:
            var wing := radius * (1.0 + 0.12 * sin(_age * 8.0))
            var points := PackedVector2Array([Vector2(0, -wing), Vector2(wing, 0), Vector2(0, wing), Vector2(-wing, 0)])
            draw_colored_polygon(points, Color(core_color.r, core_color.g, core_color.b, 0.68))
            draw_arc(Vector2.ZERO, radius + 6.0, -_age * 4.0, -_age * 4.0 + PI, 20, Color(0.95, 0.7, 1.0, 0.85), 2.0, true)
        EnemyKind.TANK:
            draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0)), Color(core_color.r, core_color.g, core_color.b, 0.74), true)
            draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0)), Color(0.75, 1.0, 0.88, 0.9), false, 2.5)
        EnemyKind.BOSS:
            draw_circle(Vector2.ZERO, radius, Color(core_color.r, core_color.g, core_color.b, 0.72))
            for i in range(8):
                var angle := FULL_CIRCLE * float(i) / 8.0 + _age * 0.55
                draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * (radius + 18.0), Color(1.0, 0.55, 1.0, 0.55), 3.0, true)
            draw_arc(Vector2.ZERO, radius + 8.0, -_age, -_age + FULL_CIRCLE * get_health_ratio(), 64, Color(1.0, 0.9, 1.0, 0.95), 4.0, true)

    if not is_boss:
        var bar_width := radius * 2.1
        draw_rect(Rect2(Vector2(-bar_width / 2.0, -radius - 13.0), Vector2(bar_width, 4.0)), Color(0.05, 0.04, 0.08, 0.8), true)
        draw_rect(Rect2(Vector2(-bar_width / 2.0, -radius - 13.0), Vector2(bar_width * get_health_ratio(), 4.0)), Color(0.5, 1.0, 0.55, 0.95), true)

func _closed(points: PackedVector2Array) -> PackedVector2Array:
    var closed := PackedVector2Array(points)
    if closed.size() > 0:
        closed.append(closed[0])
    return closed
