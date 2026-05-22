extends CharacterBody2D

signal health_changed(value: int)
signal player_died

@export var speed: float = 240.0
@export var max_health: int = 3

var health: int

func _ready() -> void:
    health = max_health
    health_changed.emit(health)

func _physics_process(_delta: float) -> void:
    var direction := Vector2.ZERO
    direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

    velocity = direction.normalized() * speed
    move_and_slide()

func take_damage(amount: int = 1) -> void:
    health = max(health - amount, 0)
    health_changed.emit(health)

    if health == 0:
        player_died.emit()
        queue_free()
