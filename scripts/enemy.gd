extends CharacterBody2D

@export var speed: float = 120.0
@export var contact_damage: int = 1
@export var retarget_distance: float = 16.0

var target: Node2D

func _physics_process(_delta: float) -> void:
    if not is_instance_valid(target):
        velocity = Vector2.ZERO
        move_and_slide()
        return

    var offset := target.global_position - global_position
    if offset.length() > retarget_distance:
        velocity = offset.normalized() * speed
    else:
        velocity = Vector2.ZERO

    move_and_slide()

func _on_hitbox_body_entered(body: Node) -> void:
    if body.has_method("take_damage"):
        body.take_damage(contact_damage)
