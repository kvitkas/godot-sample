extends Area2D

signal collected(value: int)

@export var value: int = 1

func _on_body_entered(body: Node) -> void:
    if body.name == "Player":
        collected.emit(value)
        queue_free()
