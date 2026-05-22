extends CanvasLayer

@onready var score_label: Label = $Panel/ScoreLabel
@onready var health_label: Label = $Panel/HealthLabel
@onready var message_label: Label = $Panel/MessageLabel

func set_score(value: int) -> void:
    score_label.text = "Score: %d" % value

func set_health(value: int) -> void:
    health_label.text = "Health: %d" % value

func show_message(text: String) -> void:
    message_label.text = text
