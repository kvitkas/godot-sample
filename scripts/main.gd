extends Node2D

const EnemyScript := preload("res://scripts/enemy.gd")
const PickupScript := preload("res://scripts/coin.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")

const WORLD_RECT := Rect2(Vector2.ZERO, Vector2(1800, 1100))
const TOTAL_WAVES := 5
const PLAYER_RADIUS := 18.0
const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const WALL_LAYER := 4
const SAVE_PATH := "user://starfall_salvage.cfg"
const FULL_CIRCLE := PI * 2.0

const ENEMY_DRONE := 0
const ENEMY_SENTINEL := 1
const ENEMY_WRAITH := 2
const ENEMY_TANK := 3
const ENEMY_BOSS := 4

const PICKUP_SCRAP := 0
const PICKUP_CORE := 1
const PICKUP_HEART := 2
const PICKUP_RELIC := 3

const UPGRADE_POOL := [
    {"id": "drive", "name": "Overclocked Drive", "description": "+12% movement speed. Stay ahead of the swarm.", "max": 5},
    {"id": "targeting", "name": "Targeting Matrix", "description": "+18% faster auto-blaster fire rate.", "max": 5},
    {"id": "splitter", "name": "Plasma Splitter", "description": "+1 simultaneous shot, up to a four-bolt spread.", "max": 3},
    {"id": "pierce", "name": "Phase-Tuned Rounds", "description": "Bolts pierce one additional enemy and fly faster.", "max": 4},
    {"id": "reactor", "name": "Pulse Reactor", "description": "Pulse blast recharges 20% faster and hits wider.", "max": 4},
    {"id": "magnet", "name": "Scrap Magnet", "description": "+90 pickup attraction radius. No scrap left behind.", "max": 4},
    {"id": "heart", "name": "Nanite Heart", "description": "+1 max hull and repair 2 hull immediately.", "max": 4},
    {"id": "capacitor", "name": "Kinetic Capacitor", "description": "Dash cools down 18% faster and launches harder.", "max": 4},
    {"id": "payload", "name": "Charged Payload", "description": "+1 bolt damage and +1 pulse damage.", "max": 4}
]

enum GameState { TITLE, PLAYING, UPGRADE, PAUSED, GAME_OVER, VICTORY }

@onready var player = $Player
@onready var hud = $HUD

var state: int = GameState.TITLE
var previous_state: int = GameState.PLAYING
var rng := RandomNumberGenerator.new()
var score := 0
var high_score := 0
var wave := 0
var cores_collected := 0
var cores_needed := 0
var kills := 0
var enemies_spawned_this_wave := 0
var remaining_wave_enemies := 0
var max_live_enemies := 7
var wave_spawn_timer := 0.0
var fire_timer := 0.0
var boss_minion_timer := 0.0
var relic_collected := false
var boss_defeated := false
var boss_ref
var current_upgrade_choices: Array[Dictionary] = []
var upgrade_counts := {}
var enemies: Array = []
var pickups: Array = []
var obstacles: Array[Rect2] = []
var stars: Array[Dictionary] = []
var effects: Array[Dictionary] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    rng.randomize()
    randomize()
    _ensure_runtime_input_actions()
    _load_save()
    _generate_stars()

    player.configure_world(WORLD_RECT)
    player.health_changed.connect(_on_player_health_changed)
    player.player_died.connect(_on_player_died)
    player.pulse_blast.connect(_on_player_pulse_blast)
    player.visible = false

    hud.set_high_score(high_score)
    hud.set_boss_health("", 0.0, false)
    hud.set_ability_ready(1.0, 1.0)
    hud.set_score(0)
    hud.set_wave(0, TOTAL_WAVES)
    hud.set_cores(0, 0)
    hud.set_health(player.health, player.max_health)
    hud.set_objective("Press R to launch.")
    hud.show_title(high_score)
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart"):
        new_game()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("pause_game"):
        _toggle_pause()
        get_viewport().set_input_as_handled()
        return

    if state == GameState.UPGRADE:
        if event.is_action_pressed("upgrade_1"):
            _choose_upgrade(0)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("upgrade_2"):
            _choose_upgrade(1)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("upgrade_3"):
            _choose_upgrade(2)
            get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    _update_effects(delta)

    if state != GameState.PLAYING:
        return

    _maintain_wave_spawns(delta)
    _handle_autofire(delta)
    _handle_contact_damage()
    _update_hud_runtime()
    _check_wave_completion()

func new_game() -> void:
    get_tree().paused = false
    state = GameState.PLAYING
    previous_state = GameState.PLAYING
    score = 0
    wave = 0
    cores_collected = 0
    cores_needed = 0
    kills = 0
    enemies_spawned_this_wave = 0
    remaining_wave_enemies = 0
    max_live_enemies = 7
    wave_spawn_timer = 0.0
    fire_timer = 0.35
    boss_minion_timer = 0.0
    relic_collected = false
    boss_defeated = false
    boss_ref = null
    current_upgrade_choices.clear()
    upgrade_counts.clear()
    enemies.clear()
    pickups.clear()
    effects.clear()

    _clear_dynamic_nodes()
    _spawn_obstacles()

    player.global_position = WORLD_RECT.position + WORLD_RECT.size * 0.5
    player.configure_world(WORLD_RECT)
    player.reset_for_new_run(WORLD_RECT)

    hud.hide_title()
    hud.hide_upgrade_choices()
    hud.show_pause(false)
    hud.set_high_score(high_score)
    hud.set_boss_health("", 0.0, false)
    _refresh_hud()
    _start_next_wave()
    _add_ring(player.global_position, 140.0, Color(0.3, 0.95, 1.0, 0.85), 0.6)

func _start_next_wave() -> void:
    wave += 1
    cores_collected = 0
    enemies_spawned_this_wave = 0
    boss_defeated = false
    boss_ref = null

    if wave > TOTAL_WAVES:
        _complete_run()
        return

    if wave < TOTAL_WAVES:
        cores_needed = mini(5, wave + 2)
        remaining_wave_enemies = 6 + wave * 4
        max_live_enemies = 6 + wave * 2
        wave_spawn_timer = 0.2
        _spawn_core_pickups(cores_needed)
        _spawn_initial_wave_enemies()
        hud.set_status("Sector %d opened. Recover every Rift Core, then clear the swarm." % wave, Color(0.72, 1.0, 1.0))
        hud.set_objective("Recover Rift Cores and survive the hostile salvage drones.")
    else:
        cores_needed = 1
        remaining_wave_enemies = 0
        max_live_enemies = 10
        boss_minion_timer = 1.5
        _spawn_boss()
        hud.set_status("The Anchor has arrived. Break it to expose the Star Relic!", Color(1.0, 0.66, 1.0))
        hud.set_objective("Defeat the Anchor, grab the Star Relic, and seal the rift.")

    _refresh_hud()

func _spawn_initial_wave_enemies() -> void:
    var initial_count := mini(remaining_wave_enemies, 4 + wave)
    for i in range(initial_count):
        _spawn_wave_enemy()
        remaining_wave_enemies -= 1

func _maintain_wave_spawns(delta: float) -> void:
    if wave < TOTAL_WAVES and remaining_wave_enemies > 0:
        wave_spawn_timer -= delta
        if wave_spawn_timer <= 0.0 and _live_enemy_count() < max_live_enemies:
            _spawn_wave_enemy()
            remaining_wave_enemies -= 1
            wave_spawn_timer = maxf(0.65, 1.8 - float(wave) * 0.18)

    if wave == TOTAL_WAVES and not boss_defeated and is_instance_valid(boss_ref):
        boss_minion_timer -= delta
        if boss_minion_timer <= 0.0 and _live_enemy_count() < max_live_enemies:
            var kind := ENEMY_WRAITH if rng.randf() < 0.35 else ENEMY_DRONE
            _spawn_enemy(kind, _random_safe_position(340.0))
            boss_minion_timer = maxf(1.1, 2.7 - boss_ref.get_health_ratio())

func _handle_autofire(delta: float) -> void:
    fire_timer -= delta
    if fire_timer > 0.0 or player.is_dead:
        return

    var targets := _get_nearest_targets(player.multishot, 760.0)
    if targets.is_empty():
        fire_timer = 0.1
        return

    _fire_at_targets(targets)
    fire_timer = maxf(0.08, player.fire_interval)

func _fire_at_targets(targets: Array) -> void:
    if targets.size() == 1 and player.multishot > 1:
        var direction: Vector2 = (targets[0].global_position - player.global_position).normalized()
        var base_angle: float = direction.angle()
        var spread: float = deg_to_rad(9.0)
        var total: int = player.multishot
        for i in range(total):
            var angle: float = base_angle + (float(i) - float(total - 1) / 2.0) * spread
            _spawn_projectile(Vector2(cos(angle), sin(angle)))
        return

    for target in targets:
        if is_instance_valid(target):
            _spawn_projectile((target.global_position - player.global_position).normalized())

func _spawn_projectile(direction: Vector2) -> void:
    if direction.length_squared() < 0.01:
        direction = player.get_facing()
    var bolt = ProjectileScript.new()
    var color := Color.from_hsv(fmod(0.52 + float(player.projectile_damage) * 0.035, 1.0), 0.72, 1.0)
    bolt.setup(player.global_position + direction.normalized() * 28.0, direction, player.projectile_damage, player.projectile_speed, player.projectile_pierce, color)
    bolt.add_to_group("dynamic")
    add_child(bolt)

func _handle_contact_damage() -> void:
    if player.is_dead:
        return

    for enemy_node in enemies.duplicate():
        var enemy = enemy_node
        if not is_instance_valid(enemy):
            enemies.erase(enemy_node)
            continue
        var distance: float = enemy.global_position.distance_to(player.global_position)
        if distance <= enemy.radius + PLAYER_RADIUS and enemy.can_deal_contact_damage():
            var damaged: bool = player.take_damage(enemy.contact_damage)
            if damaged:
                var away: Vector2 = (player.global_position - enemy.global_position).normalized()
                player.velocity += away * 140.0
                _add_ring(player.global_position, 62.0, Color(1.0, 0.24, 0.28, 0.72), 0.32)

func _on_player_pulse_blast(origin: Vector2, radius: float, damage: int) -> void:
    _add_ring(origin, radius, Color(1.0, 0.72, 0.18, 0.92), 0.42)
    for enemy_node in enemies.duplicate():
        var enemy = enemy_node
        if not is_instance_valid(enemy):
            enemies.erase(enemy_node)
            continue
        var offset: Vector2 = enemy.global_position - origin
        var distance: float = offset.length()
        if distance <= radius + enemy.radius:
            var knockback: Vector2 = offset.normalized() * lerpf(640.0, 180.0, clampf(distance / radius, 0.0, 1.0))
            enemy.apply_damage(damage, knockback)
    hud.set_status("Pulse blast discharged.", Color(1.0, 0.82, 0.45))

func _spawn_wave_enemy() -> void:
    _spawn_enemy(_choose_enemy_kind(), _random_safe_position(300.0))
    enemies_spawned_this_wave += 1

func _choose_enemy_kind() -> int:
    var roll := rng.randf()
    if wave >= 4 and roll < 0.16:
        return ENEMY_TANK
    if wave >= 3 and roll < 0.42:
        return ENEMY_WRAITH
    if wave >= 2 and roll < 0.62:
        return ENEMY_SENTINEL
    return ENEMY_DRONE

func _spawn_enemy(kind: int, position: Vector2) -> Node:
    var enemy = EnemyScript.new()
    enemy.setup(kind, player, wave)
    enemy.position = position
    enemy.add_to_group("dynamic")
    enemy.died.connect(_on_enemy_died)
    add_child(enemy)
    enemies.append(enemy)
    _add_ring(position, enemy.radius + 30.0, Color(1.0, 0.15, 0.4, 0.35), 0.35)
    return enemy

func _spawn_boss() -> void:
    boss_ref = _spawn_enemy(ENEMY_BOSS, _random_safe_position(520.0))
    boss_ref.name = "TheAnchor"
    enemies_spawned_this_wave += 1

func _on_enemy_died(enemy: Node, value: int) -> void:
    enemies.erase(enemy)
    kills += 1
    score += value
    _drop_scrap(enemy.global_position, value)

    if enemy.is_boss:
        boss_defeated = true
        boss_ref = null
        _spawn_pickup(PICKUP_RELIC, 1, enemy.global_position)
        hud.set_boss_health("", 0.0, false)
        hud.set_status("The Anchor cracked open. Claim the Star Relic!", Color(1.0, 0.9, 0.42))
    elif rng.randf() < 0.08 + float(wave) * 0.012:
        _spawn_pickup(PICKUP_HEART, 1, enemy.global_position + _random_offset(42.0))

    _add_ring(enemy.global_position, enemy.radius + 42.0, Color(0.42, 1.0, 0.72, 0.56), 0.36)
    _refresh_hud()
    _check_wave_completion()

func _drop_scrap(origin: Vector2, value: int) -> void:
    var pieces := mini(maxi(int(value / 65), 1), 6)
    for i in range(pieces):
        var scrap_value := maxi(10, int(value / pieces * rng.randf_range(0.55, 0.9)))
        _spawn_pickup(PICKUP_SCRAP, scrap_value, origin + _random_offset(rng.randf_range(22.0, 62.0)))

func _spawn_core_pickups(count: int) -> void:
    for i in range(count):
        _spawn_pickup(PICKUP_CORE, 250 + wave * 50, _random_safe_position(220.0))

func _spawn_pickup(kind: int, value: int, position: Vector2) -> Node:
    var pickup = PickupScript.new()
    pickup.setup(kind, value, player)
    pickup.position = _keep_inside_world(position)
    pickup.add_to_group("dynamic")
    pickup.collected.connect(_on_pickup_collected)
    add_child(pickup)
    pickups.append(pickup)
    return pickup

func _on_pickup_collected(pickup: Node) -> void:
    pickups.erase(pickup)

    match pickup.kind:
        PICKUP_SCRAP:
            score += pickup.value
            hud.set_status("Recovered %d scrap." % pickup.value, Color(1.0, 0.86, 0.45))
        PICKUP_CORE:
            cores_collected += 1
            score += pickup.value
            _add_ring(pickup.global_position, 110.0, Color(0.26, 0.95, 1.0, 0.72), 0.42)
            if cores_collected >= cores_needed:
                hud.set_status("All cores recovered. Clear the remaining hostiles!", Color(0.45, 1.0, 0.95))
            else:
                hud.set_status("Rift Core secured. Keep moving.", Color(0.45, 1.0, 0.95))
        PICKUP_HEART:
            player.heal(1)
            score += 35
            hud.set_status("Nanites restored one hull segment.", Color(1.0, 0.66, 0.76))
        PICKUP_RELIC:
            relic_collected = true
            cores_collected = cores_needed
            score += 2400
            _add_ring(pickup.global_position, 230.0, Color(1.0, 0.94, 0.32, 0.95), 0.8)
            _complete_run()

    _refresh_hud()
    _check_wave_completion()

func _check_wave_completion() -> void:
    if state != GameState.PLAYING:
        return

    if wave < TOTAL_WAVES:
        if cores_collected >= cores_needed and remaining_wave_enemies <= 0 and _live_enemy_count() == 0:
            _enter_upgrade_state()
    elif relic_collected:
        _complete_run()

func _enter_upgrade_state() -> void:
    state = GameState.UPGRADE
    get_tree().paused = true
    current_upgrade_choices = _roll_upgrades()
    hud.show_upgrade_choices(current_upgrade_choices)
    _add_ring(player.global_position, 180.0, Color(1.0, 0.84, 0.35, 0.7), 0.55)

func _roll_upgrades() -> Array[Dictionary]:
    var available: Array[Dictionary] = []
    for upgrade in UPGRADE_POOL:
        var id := str(upgrade["id"])
        var taken := int(upgrade_counts.get(id, 0))
        var limit := int(upgrade.get("max", 99))
        if taken < limit:
            available.append(upgrade)

    for i in range(available.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var temp := available[i]
        available[i] = available[j]
        available[j] = temp

    var selected: Array[Dictionary] = []
    for i in range(mini(3, available.size())):
        selected.append(available[i])
    return selected

func _choose_upgrade(index: int) -> void:
    if index < 0 or index >= current_upgrade_choices.size():
        return

    var upgrade := current_upgrade_choices[index]
    var id := str(upgrade["id"])
    upgrade_counts[id] = int(upgrade_counts.get(id, 0)) + 1

    match id:
        "drive":
            player.speed_bonus *= 1.12
        "targeting":
            player.fire_interval = maxf(0.11, player.fire_interval * 0.82)
        "splitter":
            player.multishot = mini(player.multishot + 1, 4)
        "pierce":
            player.projectile_pierce += 1
            player.projectile_speed += 55.0
        "reactor":
            player.pulse_cooldown_bonus *= 0.8
            player.pulse_radius_bonus *= 1.1
        "magnet":
            player.magnet_radius += 90.0
        "heart":
            player.add_max_health(1)
            player.heal(1)
        "capacitor":
            player.dash_cooldown_bonus *= 0.82
            player.dash_speed += 55.0
        "payload":
            player.projectile_damage += 1
            player.pulse_damage += 1

    hud.hide_upgrade_choices()
    hud.set_status("Installed %s." % str(upgrade["name"]), Color(0.72, 1.0, 0.72))
    current_upgrade_choices.clear()
    get_tree().paused = false
    state = GameState.PLAYING
    _refresh_hud()
    _start_next_wave()

func _toggle_pause() -> void:
    if state == GameState.PLAYING:
        previous_state = state
        state = GameState.PAUSED
        get_tree().paused = true
        hud.show_pause(true)
    elif state == GameState.PAUSED:
        state = previous_state
        get_tree().paused = false
        hud.show_pause(false)
        hud.set_status("Systems online.", Color(0.74, 1.0, 0.86))

func _on_player_health_changed(current: int, maximum: int) -> void:
    hud.set_health(current, maximum)

func _on_player_died() -> void:
    if state != GameState.PLAYING:
        return
    state = GameState.GAME_OVER
    get_tree().paused = true
    _commit_score()
    hud.show_game_over(score, wave, high_score, false)
    hud.set_status("Ship lost. Press R to restart.", Color(1.0, 0.38, 0.38))

func _complete_run() -> void:
    if state == GameState.VICTORY:
        return
    state = GameState.VICTORY
    get_tree().paused = true
    _commit_score()
    hud.show_game_over(score, wave, high_score, true)
    hud.set_status("Rift sealed. Press R for another run.", Color(1.0, 0.92, 0.42))

func _refresh_hud() -> void:
    hud.set_score(score)
    hud.set_wave(wave, TOTAL_WAVES)
    hud.set_cores(cores_collected, cores_needed)
    hud.set_health(player.health, player.max_health)
    hud.set_high_score(high_score)
    _update_hud_runtime()

func _update_hud_runtime() -> void:
    hud.set_ability_ready(player.get_dash_ready_ratio(), player.get_pulse_ready_ratio())
    if is_instance_valid(boss_ref):
        hud.set_boss_health(boss_ref.title, boss_ref.get_health_ratio(), true)
    else:
        hud.set_boss_health("", 0.0, false)

func _get_nearest_targets(limit: int, max_distance: float) -> Array:
    var candidates: Array[Dictionary] = []
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var distance: float = enemy.global_position.distance_to(player.global_position)
        if distance <= max_distance:
            candidates.append({"enemy": enemy, "distance": distance})

    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))

    var result: Array = []
    var target_count := mini(limit, candidates.size())
    for i in range(target_count):
        result.append(candidates[i]["enemy"])
    return result

func _live_enemy_count() -> int:
    var count := 0
    for enemy_node in enemies.duplicate():
        var enemy = enemy_node
        if is_instance_valid(enemy):
            count += 1
        else:
            enemies.erase(enemy_node)
    return count

func _random_safe_position(min_player_distance: float) -> Vector2:
    for attempt in range(160):
        var position := Vector2(
            rng.randf_range(WORLD_RECT.position.x + 80.0, WORLD_RECT.position.x + WORLD_RECT.size.x - 80.0),
            rng.randf_range(WORLD_RECT.position.y + 80.0, WORLD_RECT.position.y + WORLD_RECT.size.y - 80.0)
        )
        if position.distance_to(player.global_position) < min_player_distance:
            continue
        if _point_hits_obstacle(position, 56.0):
            continue
        return position

    return _keep_inside_world(player.global_position + _random_offset(min_player_distance + 160.0))

func _point_hits_obstacle(point: Vector2, margin: float) -> bool:
    for rect in obstacles:
        var expanded := Rect2(rect.position - Vector2.ONE * margin, rect.size + Vector2.ONE * margin * 2.0)
        if expanded.has_point(point):
            return true
    return false

func _keep_inside_world(point: Vector2) -> Vector2:
    return Vector2(
        clampf(point.x, WORLD_RECT.position.x + 36.0, WORLD_RECT.position.x + WORLD_RECT.size.x - 36.0),
        clampf(point.y, WORLD_RECT.position.y + 36.0, WORLD_RECT.position.y + WORLD_RECT.size.y - 36.0)
    )

func _random_offset(length: float) -> Vector2:
    var angle := rng.randf_range(0.0, FULL_CIRCLE)
    return Vector2(cos(angle), sin(angle)) * length

func _spawn_obstacles() -> void:
    obstacles.clear()
    var layout := [
        Rect2(240, 180, 290, 48),
        Rect2(690, 145, 62, 230),
        Rect2(1035, 250, 300, 56),
        Rect2(1440, 154, 72, 255),
        Rect2(330, 690, 380, 54),
        Rect2(1015, 690, 90, 255),
        Rect2(1240, 520, 310, 54),
        Rect2(760, 872, 280, 48)
    ]

    for rect in layout:
        obstacles.append(rect)
        var body := StaticBody2D.new()
        body.name = "RiftDebris"
        body.position = rect.position + rect.size * 0.5
        body.collision_layer = WALL_LAYER
        body.collision_mask = PLAYER_LAYER | ENEMY_LAYER
        body.z_index = 5
        body.add_to_group("dynamic")

        var collision := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = rect.size
        collision.shape = shape
        body.add_child(collision)

        var polygon := Polygon2D.new()
        polygon.polygon = PackedVector2Array([
            -rect.size * 0.5,
            Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
            rect.size * 0.5,
            Vector2(-rect.size.x * 0.5, rect.size.y * 0.5)
        ])
        polygon.color = Color(0.08, 0.15, 0.22, 0.96)
        body.add_child(polygon)

        add_child(body)

func _clear_dynamic_nodes() -> void:
    for node in get_tree().get_nodes_in_group("dynamic"):
        if is_instance_valid(node):
            node.queue_free()

func _generate_stars() -> void:
    stars.clear()
    for i in range(180):
        stars.append({
            "pos": Vector2(rng.randf_range(WORLD_RECT.position.x, WORLD_RECT.position.x + WORLD_RECT.size.x), rng.randf_range(WORLD_RECT.position.y, WORLD_RECT.position.y + WORLD_RECT.size.y)),
            "radius": rng.randf_range(0.8, 2.4),
            "alpha": rng.randf_range(0.28, 0.82)
        })

func _add_ring(position: Vector2, radius: float, color: Color, lifetime: float) -> void:
    effects.append({"pos": position, "radius": radius, "color": color, "age": 0.0, "life": lifetime})
    queue_redraw()

func _update_effects(delta: float) -> void:
    var changed := false
    for i in range(effects.size() - 1, -1, -1):
        effects[i]["age"] = float(effects[i]["age"]) + delta
        if float(effects[i]["age"]) >= float(effects[i]["life"]):
            effects.remove_at(i)
        changed = true
    if changed:
        queue_redraw()

func _draw() -> void:
    draw_rect(WORLD_RECT, Color(0.006, 0.01, 0.028), true)

    for star in stars:
        var pos: Vector2 = star["pos"]
        var radius: float = star["radius"]
        var alpha: float = star["alpha"]
        draw_circle(pos, radius, Color(0.6, 0.86, 1.0, alpha))

    for x in range(0, int(WORLD_RECT.size.x) + 1, 90):
        draw_line(Vector2(x, 0), Vector2(x, WORLD_RECT.size.y), Color(0.1, 0.24, 0.34, 0.22), 1.0)
    for y in range(0, int(WORLD_RECT.size.y) + 1, 90):
        draw_line(Vector2(0, y), Vector2(WORLD_RECT.size.x, y), Color(0.1, 0.24, 0.34, 0.22), 1.0)

    draw_circle(Vector2(280, 820), 360.0, Color(0.0, 0.28, 0.42, 0.08))
    draw_circle(Vector2(1420, 300), 300.0, Color(0.45, 0.0, 0.4, 0.09))
    draw_rect(WORLD_RECT, Color(0.25, 0.75, 1.0, 0.4), false, 4.0)

    for effect in effects:
        var age := float(effect["age"])
        var life := maxf(float(effect["life"]), 0.01)
        var t := clampf(age / life, 0.0, 1.0)
        var color: Color = effect["color"]
        var pos: Vector2 = effect["pos"]
        color.a *= 1.0 - t
        var radius := float(effect["radius"]) * lerpf(0.22, 1.0, t)
        draw_arc(pos, radius, 0.0, FULL_CIRCLE, 72, color, 5.0 * (1.0 - t) + 1.0, true)

func _load_save() -> void:
    var cfg := ConfigFile.new()
    var err := cfg.load(SAVE_PATH)
    if err == OK:
        high_score = int(cfg.get_value("scores", "high_score", 0))

func _commit_score() -> void:
    if score <= high_score:
        return
    high_score = score
    var cfg := ConfigFile.new()
    cfg.set_value("scores", "high_score", high_score)
    cfg.save(SAVE_PATH)
    hud.set_high_score(high_score)

func _ensure_runtime_input_actions() -> void:
    _ensure_key_action("dash", KEY_SPACE)
    _ensure_key_action("pulse", KEY_E)
    _ensure_key_action("restart", KEY_R)
    _ensure_key_action("pause_game", KEY_P)
    _ensure_key_action("upgrade_1", KEY_1)
    _ensure_key_action("upgrade_2", KEY_2)
    _ensure_key_action("upgrade_3", KEY_3)

func _ensure_key_action(action: StringName, physical_keycode: int) -> void:
    if InputMap.has_action(action):
        return
    InputMap.add_action(action)
    var event := InputEventKey.new()
    event.physical_keycode = physical_keycode
    InputMap.action_add_event(action, event)
