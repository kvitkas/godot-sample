class_name Pickup
extends Area2D

signal collected(pickup: Node)

const PICKUP_LAYER := 16
const PLAYER_LAYER := 1
const FULL_CIRCLE := PI * 2.0

enum PickupKind { SCRAP, CORE, HEART, RELIC }

var kind: int = PickupKind.SCRAP
var value := 1
var target: Node2D
var radius := 13.0
var label := "Scrap"
var accent := Color(0.95, 0.76, 0.28)
var _age := 0.0
var _collected := false

func setup(new_kind: int, new_value: int, new_target: Node2D) -> void:
    kind = new_kind
    value = new_value
    target = new_target

    match kind:
        PickupKind.SCRAP:
            radius = 11.0
            label = "Scrap"
            accent = Color(1.0, 0.78, 0.25)
        PickupKind.CORE:
            radius = 16.0
            label = "Rift Core"
            accent = Color(0.3, 0.95, 1.0)
        PickupKind.HEART:
            radius = 14.0
            label = "Nanite Heart"
            accent = Color(1.0, 0.22, 0.44)
        PickupKind.RELIC:
            radius = 24.0
            label = "Star Relic"
            accent = Color(1.0, 0.9, 0.35)

func _ready() -> void:
    z_index = 8
    collision_layer = PICKUP_LAYER
    collision_mask = PLAYER_LAYER
    monitoring = true
    monitorable = false
    _ensure_collision_shape()
    body_entered.connect(_on_body_entered)
    queue_redraw()

func _process(delta: float) -> void:
    _age += delta

    if is_instance_valid(target):
        var player_magnet := 150.0
        var target_magnet = target.get("magnet_radius")
        if target_magnet != null:
            player_magnet = float(target_magnet)
        var offset := target.global_position - global_position
        var distance := offset.length()
        if distance < player_magnet and distance > 1.0:
            var pull := lerpf(280.0, 860.0, 1.0 - distance / player_magnet)
            global_position += offset.normalized() * pull * delta

    queue_redraw()

func _on_body_entered(body: Node) -> void:
    if _collected:
        return
    if body.name == "Player" or body.has_signal("player_died"):
        _collected = true
        set_deferred("monitoring", false)
        set_deferred("monitorable", false)
        collected.emit(self)
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
    circle.radius = radius + 4.0

func _draw() -> void:
    var bob := sin(_age * 5.5) * 3.0
    var alpha := 0.78 + 0.18 * sin(_age * 4.0)
    var center := Vector2(0, bob)

    draw_circle(center, radius + 9.0, Color(accent.r, accent.g, accent.b, 0.12))

    match kind:
        PickupKind.SCRAP:
            var points := PackedVector2Array([
                center + Vector2(0, -radius),
                center + Vector2(radius * 0.8, 0),
                center + Vector2(0, radius),
                center + Vector2(-radius * 0.8, 0)
            ])
            draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, alpha))
            draw_polyline(_closed(points), Color(1.0, 0.96, 0.65, 0.9), 1.8, true)
        PickupKind.CORE:
            draw_arc(center, radius + 7.0, _age * 2.0, _age * 2.0 + PI * 1.65, 32, Color(0.7, 1.0, 1.0, 0.75), 3.0, true)
            draw_circle(center, radius, Color(accent.r, accent.g, accent.b, alpha))
            draw_circle(center, radius * 0.44, Color(1.0, 1.0, 1.0, 0.85))
        PickupKind.HEART:
            draw_circle(center + Vector2(-radius * 0.38, -radius * 0.18), radius * 0.55, Color(accent.r, accent.g, accent.b, alpha))
            draw_circle(center + Vector2(radius * 0.38, -radius * 0.18), radius * 0.55, Color(accent.r, accent.g, accent.b, alpha))
            var points := PackedVector2Array([center + Vector2(-radius, 0), center + Vector2(radius, 0), center + Vector2(0, radius * 1.18)])
            draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, alpha))
        PickupKind.RELIC:
            var points := PackedVector2Array()
            for i in range(10):
                var r := radius if i % 2 == 0 else radius * 0.45
                var angle := -PI / 2.0 + FULL_CIRCLE * float(i) / 10.0 + _age * 0.35
                points.append(center + Vector2(cos(angle), sin(angle)) * r)
            draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, alpha))
            draw_polyline(_closed(points), Color(1.0, 1.0, 0.82, 0.95), 2.2, true)

func _closed(points: PackedVector2Array) -> PackedVector2Array:
    var closed := PackedVector2Array(points)
    if closed.size() > 0:
        closed.append(closed[0])
    return closed
