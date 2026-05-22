extends Node2D

var score: int = 0

@onready var player: CharacterBody2D = $Player
@onready var enemy: CharacterBody2D = $Enemy
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
    enemy.target = player
    hud.set_score(score)
    hud.set_health(player.max_health)

    player.health_changed.connect(hud.set_health)
    player.player_died.connect(_on_player_died)

    for coin in get_tree().get_nodes_in_group("coins"):
        coin.collected.connect(_on_coin_collected)

func _on_coin_collected(value: int) -> void:
    score += value
    hud.set_score(score)

    if score >= 5:
        hud.show_message("Prototype complete: all pickups collected.")

func _on_player_died() -> void:
    hud.show_message("Game over. Restart to try again.")
