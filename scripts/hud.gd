class_name GameHUD
extends CanvasLayer

var score_label: Label
var wave_label: Label
var core_label: Label
var health_label: Label
var objective_label: Label
var status_label: Label
var best_label: Label
var dash_bar: ProgressBar
var pulse_bar: ProgressBar
var boss_bar: ProgressBar
var boss_label: Label
var overlay: ColorRect
var overlay_label: Label
var upgrade_panel: ColorRect
var upgrade_title: Label
var upgrade_cards: Array[Label] = []
var pause_label: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()

func set_score(value: int) -> void:
    score_label.text = "SCRAP  %06d" % value

func set_wave(value: int, total: int) -> void:
    wave_label.text = "SECTOR  %d / %d" % [value, total]

func set_cores(current: int, needed: int) -> void:
    core_label.text = "RIFT CORES  %d / %d" % [current, needed]

func set_health(current: int, maximum: int) -> void:
    health_label.text = "HULL  %d / %d" % [current, maximum]

func set_objective(text: String) -> void:
    objective_label.text = text

func set_status(text: String, color: Color = Color(0.8, 0.95, 1.0)) -> void:
    status_label.text = text
    status_label.add_theme_color_override("font_color", color)

func set_high_score(value: int) -> void:
    best_label.text = "BEST  %06d" % value

func set_ability_ready(dash_ratio: float, pulse_ratio: float) -> void:
    dash_bar.value = clampf(dash_ratio, 0.0, 1.0) * 100.0
    pulse_bar.value = clampf(pulse_ratio, 0.0, 1.0) * 100.0

func set_boss_health(name: String, ratio: float, visible_bar: bool) -> void:
    boss_bar.visible = visible_bar
    boss_label.visible = visible_bar
    if visible_bar:
        boss_label.text = name
        boss_bar.value = clampf(ratio, 0.0, 1.0) * 100.0

func show_title(best_score: int) -> void:
    overlay.visible = true
    overlay_label.text = "STARFALL SALVAGE\n\nA neon survival run through a collapsing rift.\nCollect cores, choose upgrades, defeat the Anchor, and escape.\n\nWASD / Arrows: move    Space: dash    E: pulse blast\n1-3: choose upgrades    P: pause    R: restart\n\nBest scrap: %06d\n\nPress R to launch." % best_score
    set_status("Awaiting launch command.")

func hide_title() -> void:
    overlay.visible = false

func show_game_over(score: int, wave: int, best_score: int, won: bool) -> void:
    overlay.visible = true
    if won:
        overlay_label.text = "RIFT SEALED\n\nYou recovered the Star Relic and broke the Anchor's gravity well.\n\nFinal scrap: %06d\nBest scrap:  %06d\n\nPress R to run a new salvage route." % [score, best_score]
    else:
        overlay_label.text = "SHIP LOST\n\nSector reached: %d\nScrap recovered: %06d\nBest scrap:     %06d\n\nPress R to rebuild and launch again." % [wave, score, best_score]

func show_upgrade_choices(choices: Array[Dictionary]) -> void:
    upgrade_panel.visible = true
    upgrade_title.text = "FIELD UPGRADE AVAILABLE"
    for i in range(upgrade_cards.size()):
        if i < choices.size():
            var choice := choices[i]
            upgrade_cards[i].text = "%d  %s\n%s" % [i + 1, str(choice.get("name", "Upgrade")), str(choice.get("description", ""))]
            upgrade_cards[i].visible = true
        else:
            upgrade_cards[i].visible = false
    set_status("Choose a field upgrade with 1, 2, or 3.", Color(1.0, 0.88, 0.45))

func hide_upgrade_choices() -> void:
    upgrade_panel.visible = false

func show_pause(paused: bool) -> void:
    pause_label.visible = paused
    if paused:
        set_status("Paused. Press P to resume or R to restart.", Color(1.0, 0.9, 0.55))

func _build_ui() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()

    var root := Control.new()
    root.name = "Root"
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var top_panel := _make_rect("TopPanel", Vector2(18, 18), Vector2(430, 172), Color(0.015, 0.025, 0.055, 0.82))
    root.add_child(top_panel)

    score_label = _make_label("Score", Vector2(18, 12), Vector2(210, 28), 20, Color(0.74, 1.0, 1.0))
    wave_label = _make_label("Wave", Vector2(18, 42), Vector2(210, 24), 16, Color(0.9, 0.93, 1.0))
    core_label = _make_label("Cores", Vector2(18, 68), Vector2(220, 24), 16, Color(0.42, 1.0, 1.0))
    health_label = _make_label("Health", Vector2(238, 42), Vector2(170, 24), 16, Color(1.0, 0.72, 0.78))
    objective_label = _make_label("Objective", Vector2(18, 122), Vector2(390, 42), 15, Color(0.86, 0.95, 1.0))
    top_panel.add_child(score_label)
    top_panel.add_child(wave_label)
    top_panel.add_child(core_label)
    top_panel.add_child(health_label)
    top_panel.add_child(objective_label)

    dash_bar = _make_bar("DashBar", Vector2(238, 72), Vector2(160, 16), Color(0.18, 0.52, 1.0))
    pulse_bar = _make_bar("PulseBar", Vector2(238, 98), Vector2(160, 16), Color(1.0, 0.64, 0.18))
    top_panel.add_child(_make_label("DashText", Vector2(238, 54), Vector2(150, 18), 12, Color(0.65, 0.84, 1.0), "DASH"))
    top_panel.add_child(dash_bar)
    top_panel.add_child(_make_label("PulseText", Vector2(238, 82), Vector2(150, 18), 12, Color(1.0, 0.84, 0.55), "PULSE"))
    top_panel.add_child(pulse_bar)

    var right_panel := _make_rect("RightPanel", Vector2(1034, 18), Vector2(228, 64), Color(0.015, 0.025, 0.055, 0.76))
    root.add_child(right_panel)
    best_label = _make_label("Best", Vector2(14, 12), Vector2(200, 28), 18, Color(1.0, 0.86, 0.48))
    right_panel.add_child(best_label)

    status_label = _make_label("Status", Vector2(190, 654), Vector2(900, 44), 20, Color(0.78, 0.95, 1.0))
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(status_label)

    boss_label = _make_label("BossLabel", Vector2(390, 24), Vector2(500, 24), 18, Color(1.0, 0.58, 1.0))
    boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(boss_label)
    boss_bar = _make_bar("BossBar", Vector2(390, 52), Vector2(500, 20), Color(1.0, 0.18, 0.72))
    root.add_child(boss_bar)
    set_boss_health("", 0.0, false)

    pause_label = _make_label("Pause", Vector2(0, 0), Vector2(1280, 720), 54, Color(1.0, 1.0, 1.0), "PAUSED")
    pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    pause_label.visible = false
    root.add_child(pause_label)

    overlay = _make_rect("Overlay", Vector2.ZERO, Vector2(1280, 720), Color(0.0, 0.0, 0.0, 0.76))
    root.add_child(overlay)
    overlay_label = _make_label("OverlayLabel", Vector2(180, 92), Vector2(920, 540), 28, Color(0.88, 1.0, 1.0))
    overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    overlay.add_child(overlay_label)

    upgrade_panel = _make_rect("UpgradePanel", Vector2(220, 152), Vector2(840, 406), Color(0.015, 0.02, 0.06, 0.94))
    root.add_child(upgrade_panel)
    upgrade_title = _make_label("UpgradeTitle", Vector2(0, 22), Vector2(840, 36), 26, Color(1.0, 0.86, 0.44))
    upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    upgrade_panel.add_child(upgrade_title)

    upgrade_cards.clear()
    for i in range(3):
        var card_bg := _make_rect("Card%d" % i, Vector2(32 + i * 268, 88), Vector2(244, 260), Color(0.05, 0.09, 0.16, 0.96))
        upgrade_panel.add_child(card_bg)
        var card := _make_label("CardLabel%d" % i, Vector2(16, 18), Vector2(212, 220), 18, Color(0.88, 0.96, 1.0))
        card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        card_bg.add_child(card)
        upgrade_cards.append(card)
    upgrade_panel.visible = false

func _make_rect(node_name: String, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
    var rect := ColorRect.new()
    rect.name = node_name
    rect.position = pos
    rect.size = size
    rect.color = color
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rect

func _make_label(node_name: String, pos: Vector2, size: Vector2, font_size: int, color: Color, text: String = "") -> Label:
    var label := Label.new()
    label.name = node_name
    label.position = pos
    label.size = size
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

func _make_bar(node_name: String, pos: Vector2, size: Vector2, fill_color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.name = node_name
    bar.position = pos
    bar.size = size
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = 100.0
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.corner_radius_top_left = 3
    fill.corner_radius_top_right = 3
    fill.corner_radius_bottom_left = 3
    fill.corner_radius_bottom_right = 3
    bar.add_theme_stylebox_override("fill", fill)

    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.02, 0.03, 0.06, 0.82)
    background.corner_radius_top_left = 3
    background.corner_radius_top_right = 3
    background.corner_radius_bottom_left = 3
    background.corner_radius_bottom_right = 3
    bar.add_theme_stylebox_override("background", background)
    return bar
