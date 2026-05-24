class_name PlasmaBolt
extends Area2D

const PROJECTILE_LAYER := 8
const ENEMY_LAYER := 2

var velocity := Vector2.RIGHT * 680.0
var damage := 1
var pierce := 0
var radius := 5.5
var lifetime := 1.25
var trail_color := Color(0.35, 0.85, 1.0)
var _hit_bodies := {}
var _age := 0.0

func setup(origin: Vector2, direction: Vector2, new_damage: int, speed: float, new_pierce: int, color: Color = Color(0.35, 0.85, 1.0)) -> void:
    global_position = origin
    velocity = direction.normalized() * speed
    damage = new_damage
    pierce = new_pierce
    trail_color = color
    rotation = direction.angle()

func _ready() -> void:
    z_index = 18
    collision_layer = PROJECTILE_LAYER
    collision_mask = ENEMY_LAYER
    monitoring = true
    monitorable = false
    _ensure_collision_shape()
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    _age += delta
    global_position += velocity * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()
    else:
        queue_redraw()

func _on_body_entered(body: Node) -> void:
    if _hit_bodies.has(body):
        return
    if body.has_method("apply_damage"):
        _hit_bodies[body] = true
        var knockback := velocity.normalized() * (180.0 + 45.0 * float(damage))
        body.apply_damage(damage, knockback)
        pierce -= 1
        if pierce < 0:
            set_deferred("monitoring", false)
            set_deferred("monitorable", false)
            call_deferred("queue_free")

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
    circle.radius = radius + 2.0

func _draw() -> void:
    var tail := -velocity.normalized() * 22.0
    draw_line(tail, Vector2.ZERO, Color(trail_color.r, trail_color.g, trail_color.b, 0.28), radius * 2.2, true)
    draw_circle(Vector2.ZERO, radius + 5.0, Color(trail_color.r, trail_color.g, trail_color.b, 0.22))
    draw_circle(Vector2.ZERO, radius, Color(trail_color.r, trail_color.g, trail_color.b, 0.95))
    draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 1.0, 1.0, 0.95))
