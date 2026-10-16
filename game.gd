extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/voluntaria.gd")

var player: CharacterBody3D
var enemy: CharacterBody3D
var camera: Camera3D
var status_label: Label
var stamina_bar: ProgressBar
var threat_label: Label
var message_label: Label
var records_found := 0
var ended := false
var record_areas: Array[Area3D] = []
var exit_area: Area3D
var pulse_cooldown := 0.0
var pulse_button: Button
var sfx_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var pulse_fx: MeshInstance3D
var pulse_fx_timer := 0.0
var active_decoy: Node3D
var ability_lock := 0.0
var focus_mode := false

func _ready() -> void:
    _setup_input()
    _setup_audio()
    get_tree().set_meta("game_ended", false)
    _make_environment()
    _make_map()
    _make_lab_details()
    _make_player()
    _make_enemy()
    _make_pulse_fx()
    _make_records()
    _make_exit()
    _make_hud()
    _update_status()

func _setup_input() -> void:
    var definitions := {
        "move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
        "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
        "sprint": [KEY_SHIFT], "pulse": [KEY_E, KEY_SPACE]
    }
    for action_name in definitions:
        if not InputMap.has_action(action_name): InputMap.add_action(action_name)
        for keycode in definitions[action_name]:
            var event := InputEventKey.new()
            event.keycode = keycode
            InputMap.action_add_event(action_name, event)

func _setup_audio() -> void:
    sfx_player = AudioStreamPlayer.new()
    sfx_player.name = "SFXPlayer"
    sfx_player.volume_db = -4.0
    add_child(sfx_player)
    ambience_player = AudioStreamPlayer.new()
    ambience_player.name = "AmbiencePlayer"
    ambience_player.stream = load("res://assets/audio/ambience.wav")
    ambience_player.volume_db = -23.0
    ambience_player.finished.connect(func():
        if not ended and ambience_player.stream != null: ambience_player.play()
    )
    add_child(ambience_player)
    ambience_player.play()

func _play_sfx(sound_name: String) -> void:
    if sfx_player == null: return
    var stream: AudioStream = load("res://assets/audio/%s.wav" % sound_name)
    if stream != null:
        sfx_player.stream = stream
        sfx_player.play()

func _process(delta: float) -> void:
    pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
    ability_lock = maxf(0.0, ability_lock - delta)
    if pulse_fx and pulse_fx_timer > 0.0:
        pulse_fx_timer = maxf(0.0, pulse_fx_timer - delta)
        var progress := 1.0 - pulse_fx_timer / 0.65
        pulse_fx.position = player.global_position + Vector3(0, 0.08, 0)
        pulse_fx.scale = Vector3.ONE * (0.2 + progress * 7.0)
        var fx_material := pulse_fx.material_override as StandardMaterial3D
        if fx_material:
            var pulse_color: Color = fx_material.albedo_color
            pulse_color.a = 1.0 - progress
            fx_material.albedo_color = pulse_color
            fx_material.emission_energy_multiplier = 1.4 - progress
        pulse_fx.visible = true
    elif pulse_fx:
        pulse_fx.visible = false
    if player and camera:
        var target_position := player.global_position + Vector3(0, 11.5, 10.0)
        camera.global_position = camera.global_position.lerp(target_position, 0.075)
        camera.look_at(player.global_position + Vector3(0, 0.65, 0), Vector3.UP)
    if pulse_button:
        pulse_button.disabled = pulse_cooldown > 0.0 or ended
        pulse_button.text = "PULSO" if pulse_cooldown <= 0.0 else "%.1f" % pulse_cooldown

func _make_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.012, 0.026, 0.033)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.35, 0.48, 0.52)
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -25, 0)
    sun.light_color = Color(0.55, 0.72, 0.75)
    sun.light_energy = 0.8
    sun.shadow_enabled = true
    add_child(sun)
    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.position = Vector3(0, 11.5, 10)
    camera.fov = 55
    camera.current = true
    add_child(camera)

func _make_map() -> void:
    _static_box("Piso", Vector3(0, -0.35, 0), Vector3(32, 0.7, 32), Color(0.055, 0.09, 0.105))
    var wall_color := Color(0.12, 0.19, 0.21)
    _static_box("ParedeNorte", Vector3(0, 1.5, -15.5), Vector3(32, 3, 1), wall_color)
    _static_box("ParedeSul", Vector3(0, 1.5, 15.5), Vector3(32, 3, 1), wall_color)
    _static_box("ParedeOeste", Vector3(-15.5, 1.5, 0), Vector3(1, 3, 32), wall_color)
    _static_box("ParedeLeste", Vector3(15.5, 1.5, 0), Vector3(1, 3, 32), wall_color)
    # Coberturas baixas em uma arena aberta: a perseguidora consegue contorná-las.
    _static_box("BancadaA", Vector3(-5.5, 0.6, -4.5), Vector3(3.2, 1.2, 2.0), Color(0.13, 0.23, 0.25))
    _static_box("BancadaB", Vector3(5.0, 0.6, 4.0), Vector3(2.8, 1.2, 2.4), Color(0.13, 0.23, 0.25))
    _static_box("CaixaA", Vector3(7.5, 0.5, -6.0), Vector3(1.5, 1.0, 1.5), Color(0.22, 0.18, 0.20))
    _static_box("CaixaB", Vector3(-8.0, 0.5, 6.0), Vector3(1.5, 1.0, 1.5), Color(0.22, 0.18, 0.20))
    for p in [Vector3(-12, 2.3, -12), Vector3(0, 2.3, -12), Vector3(12, 2.3, 2), Vector3(-12, 2.3, 12), Vector3(8, 2.3, 12)]:
        var lamp := OmniLight3D.new()
        lamp.position = p
        lamp.light_color = Color(0.18, 0.78, 0.88)
        lamp.light_energy = 0.8
        lamp.omni_range = 6.0
        add_child(lamp)
        var glow := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.12
        mesh.height = 0.24
        glow.mesh = mesh
        glow.position = p
        glow.material_override = _mat(Color(0.2, 0.85, 0.95), Color(0.1, 0.65, 0.85))
        add_child(glow)


func _make_lab_details() -> void:
    # Detalhes modulares de laboratório: consoles, cabos, suportes e cápsulas.
    var metal := _mat(Color(0.075, 0.13, 0.15))
    var trim := _mat(Color(0.18, 0.30, 0.32))
    var glass := _mat(Color(0.08, 0.34, 0.37), Color(0.02, 0.22, 0.28))
    var warning := _mat(Color(0.92, 0.43, 0.12), Color(0.42, 0.08, 0.01))
    # Consoles ao longo das paredes.
    for x in [-10.0, -4.0, 4.0, 10.0]:
        _static_box("ConsoleBase", Vector3(x, 0.65, -13.6), Vector3(2.2, 1.3, 0.8), metal)
        _static_box("ConsoleScreen", Vector3(x, 1.42, -13.12), Vector3(1.45, 0.62, 0.08), glass)
        _static_box("ConsoleLight", Vector3(x - 0.55, 1.0, -13.08), Vector3(0.16, 0.08, 0.06), warning)
        _static_box("ConsoleLight", Vector3(x - 0.25, 1.0, -13.08), Vector3(0.16, 0.08, 0.06), _mat(Color(0.1, 0.9, 0.62), Color(0.02, 0.6, 0.3)))
    # Cápsulas de contenção vazias, visualmente distintas da Voluntária.
    for pos in [Vector3(-11.0, 0, -3.0), Vector3(11.0, 0, 5.0), Vector3(2.0, 0, -8.0)]:
        _static_box("CapsuleBase", pos + Vector3(0, 0.28, 0), Vector3(2.0, 0.56, 1.6), metal)
        var column := MeshInstance3D.new()
        var cyl := CylinderMesh.new()
        cyl.top_radius = 0.48
        cyl.bottom_radius = 0.48
        cyl.height = 2.4
        column.mesh = cyl
        column.position = pos + Vector3(0, 1.5, 0)
        column.material_override = glass
        add_child(column)
        var cap := MeshInstance3D.new()
        var cap_mesh := CylinderMesh.new()
        cap_mesh.top_radius = 0.62
        cap_mesh.bottom_radius = 0.62
        cap_mesh.height = 0.16
        cap.mesh = cap_mesh
        cap.position = pos + Vector3(0, 2.75, 0)
        cap.material_override = trim
        add_child(cap)
    # Tubos industriais nas paredes e faixas de segurança no piso.
    for z in [-9.0, 0.0, 9.0]:
        _static_box("TuboParede", Vector3(-14.72, 2.25, z), Vector3(0.18, 0.18, 5.0), trim)
        _static_box("TuboParede", Vector3(14.72, 2.25, z), Vector3(0.18, 0.18, 5.0), trim)
    for x in [-7.0, 7.0]:
        _static_box("FaixaSeguranca", Vector3(x, 0.012, 0), Vector3(0.12, 0.025, 26.0), warning)
    # Vigas altas para dar escala e profundidade ao teto aberto.
    for x in [-10.0, 0.0, 10.0]:
        _static_box("VigaSuperior", Vector3(x, 3.35, 0), Vector3(0.28, 0.22, 30.0), metal)
    # Marcador visual de saída.
    _static_box("PlacaSaida", Vector3(13.0, 2.65, -12.0), Vector3(2.4, 0.42, 0.14), _mat(Color(0.03, 0.28, 0.18), Color(0.02, 0.85, 0.42)))

func _make_pulse_fx() -> void:
    pulse_fx = MeshInstance3D.new()
    pulse_fx.name = "PulseWave"
    var ring := TorusMesh.new()
    ring.inner_radius = 0.78
    ring.outer_radius = 1.0
    pulse_fx.mesh = ring
    pulse_fx.material_override = _mat(Color(0.12, 0.95, 1.0, 0.75), Color(0.08, 0.72, 1.0))
    (pulse_fx.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    pulse_fx.visible = false
    add_child(pulse_fx)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(-12, 0.1, 12)
    add_child(player)

func _make_enemy() -> void:
    enemy = CharacterBody3D.new()
    enemy.set_script(ENEMY_SCRIPT)
    enemy.position = Vector3(10, 0.1, 1)
    enemy.set("target", player)
    add_child(enemy)

func _make_records() -> void:
    _record(Vector3(-12, 0.7, -12), 1)
    _record(Vector3(0, 0.7, 0), 2)
    _record(Vector3(12, 0.7, 11), 3)

func _record(pos: Vector3, index: int) -> void:
    var area := Area3D.new()
    area.name = "Registro%d" % index
    area.position = pos
    var shape := SphereShape3D.new()
    shape.radius = 0.9
    var collision := CollisionShape3D.new()
    collision.shape = shape
    area.add_child(collision)
    var orb := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.48, 0.62, 0.14)
    orb.mesh = mesh
    orb.rotation_degrees = Vector3(0, 0, -10)
    orb.material_override = _mat(Color(0.62, 1.0, 0.75), Color(0.12, 0.7, 0.28))
    area.add_child(orb)
    var light := OmniLight3D.new()
    light.light_color = Color(0.18, 0.9, 0.45)
    light.light_energy = 0.65
    light.omni_range = 2.5
    area.add_child(light)
    area.body_entered.connect(_on_record_entered.bind(area))
    add_child(area)
    record_areas.append(area)

func _make_exit() -> void:
    exit_area = Area3D.new()
    exit_area.name = "Saida"
    exit_area.position = Vector3(13, 0.8, -12)
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.2, 2.2, 1.2)
    var collision := CollisionShape3D.new()
    collision.shape = shape
    exit_area.add_child(collision)
    var frame := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.8, 2.0, 0.18)
    frame.mesh = mesh
    frame.material_override = _mat(Color(0.12, 0.4, 0.42), Color(0.02, 0.2, 0.22))
    exit_area.add_child(frame)
    var top := MeshInstance3D.new()
    var top_mesh := BoxMesh.new()
    top_mesh.size = Vector3(2.2, 0.16, 0.4)
    top.mesh = top_mesh
    top.position.y = 1.05
    top.material_override = _mat(Color(0.12, 0.9, 0.65), Color(0.05, 0.55, 0.32))
    exit_area.add_child(top)
    exit_area.body_entered.connect(_on_exit_entered)
    add_child(exit_area)

func _make_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)
    status_label = Label.new()
    status_label.position = Vector2(20, 14)
    status_label.add_theme_font_size_override("font_size", 22)
    status_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.94))
    root.add_child(status_label)
    threat_label = Label.new()
    threat_label.position = Vector2(20, 48)
    threat_label.add_theme_font_size_override("font_size", 16)
    threat_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.48))
    threat_label.text = "AMEAÇA: VOLUNTÁRIA À SOLTA"
    root.add_child(threat_label)
    var stamina_title := Label.new()
    stamina_title.anchor_left = 0.0
    stamina_title.anchor_right = 0.0
    stamina_title.anchor_top = 1.0
    stamina_title.anchor_bottom = 1.0
    stamina_title.offset_left = 20
    stamina_title.offset_right = 190
    stamina_title.offset_top = -42
    stamina_title.offset_bottom = -20
    stamina_title.text = "ENERGIA PARA CORRER"
    stamina_title.add_theme_font_size_override("font_size", 13)
    stamina_title.add_theme_color_override("font_color", Color(0.72, 0.9, 0.9))
    root.add_child(stamina_title)
    stamina_bar = ProgressBar.new()
    stamina_bar.anchor_left = 0.0
    stamina_bar.anchor_right = 0.0
    stamina_bar.anchor_top = 1.0
    stamina_bar.anchor_bottom = 1.0
    stamina_bar.offset_left = 20
    stamina_bar.offset_right = 210
    stamina_bar.offset_top = -20
    stamina_bar.offset_bottom = -7
    stamina_bar.min_value = 0
    stamina_bar.max_value = 100
    stamina_bar.value = 100
    stamina_bar.show_percentage = false
    root.add_child(stamina_bar)
    var hint := Label.new()
    hint.text = "RECUPERE OS 3 REGISTROS E ALCANCE A SAÍDA"
    hint.anchor_left = 0.5
    hint.anchor_right = 0.5
    hint.offset_left = -280
    hint.offset_right = 280
    hint.offset_top = 14
    hint.offset_bottom = 48
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 16)
    hint.add_theme_color_override("font_color", Color(0.68, 0.82, 0.84))
    root.add_child(hint)
    message_label = Label.new()
    message_label.anchor_left = 0.5
    message_label.anchor_top = 0.40
    message_label.anchor_right = 0.5
    message_label.anchor_bottom = 0.60
    message_label.offset_left = -290
    message_label.offset_right = 290
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_size_override("font_size", 28)
    message_label.add_theme_color_override("font_color", Color(1, 0.86, 0.82))
    root.add_child(message_label)
    _add_touch_button(root, "▲", Vector2(108, -164), Vector2(64, 58), "move_forward")
    _add_touch_button(root, "▼", Vector2(108, -90), Vector2(64, 58), "move_back")
    _add_touch_button(root, "◀", Vector2(36, -90), Vector2(64, 58), "move_left")
    _add_touch_button(root, "▶", Vector2(180, -90), Vector2(64, 58), "move_right")
    _add_touch_button(root, "CORRER", Vector2(260, -92), Vector2(100, 58), "sprint")
    pulse_button = Button.new()
    pulse_button.text = "PULSO"
    pulse_button.anchor_left = 1.0
    pulse_button.anchor_right = 1.0
    pulse_button.anchor_top = 1.0
    pulse_button.anchor_bottom = 1.0
    pulse_button.offset_left = -158
    pulse_button.offset_right = -22
    pulse_button.offset_top = -160
    pulse_button.offset_bottom = -98
    pulse_button.add_theme_font_size_override("font_size", 17)
    pulse_button.pressed.connect(_use_pulse)
    root.add_child(pulse_button)
    _add_ability_button(root, "MAÇÃ", Vector2(-142, 16), _use_apple)
    _add_ability_button(root, "CLONE", Vector2(-142, 62), _use_clone)
    _add_ability_button(root, "OUVIR", Vector2(-142, 108), _use_hearing)
    _add_ability_button(root, "FOCO", Vector2(-142, 154), _use_zulmi_focus)
    _add_ability_button(root, "REGENERAR", Vector2(-142, 200), _use_linn_regen)
    var restart := Button.new()
    restart.text = "REINICIAR"
    restart.anchor_left = 1.0
    restart.anchor_right = 1.0
    restart.anchor_top = 1.0
    restart.anchor_bottom = 1.0
    restart.offset_left = -158
    restart.offset_right = -22
    restart.offset_top = -82
    restart.offset_bottom = -22
    restart.add_theme_font_size_override("font_size", 16)
    restart.pressed.connect(_restart_game)
    root.add_child(restart)

func _add_ability_button(root: Control, label_text: String, offset: Vector2, callback: Callable) -> void:
    var button := Button.new()
    button.text = label_text
    button.anchor_left = 1.0
    button.anchor_right = 1.0
    button.anchor_top = 0.0
    button.anchor_bottom = 0.0
    button.offset_left = offset.x
    button.offset_right = -12
    button.offset_top = offset.y
    button.offset_bottom = offset.y + 40
    button.add_theme_font_size_override("font_size", 13)
    button.pressed.connect(callback)
    root.add_child(button)

func _make_decoy(label_text: String, color: Color, duration: float) -> void:
    if ended or ability_lock > 0.0: return
    ability_lock = 1.0
    if is_instance_valid(active_decoy): active_decoy.queue_free()
    var decoy := Node3D.new()
    decoy.name = "Isca_%s" % label_text
    decoy.global_position = player.global_position + (-player.global_basis.z * 2.3)
    var mesh_node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.42
    mesh.height = 0.84
    mesh_node.mesh = mesh
    mesh_node.material_override = _mat(color, color)
    decoy.add_child(mesh_node)
    var light := OmniLight3D.new()
    light.light_color = color
    light.light_energy = 1.2
    light.omni_range = 3.0
    decoy.add_child(light)
    add_child(decoy)
    active_decoy = decoy
    enemy.target = decoy
    _show_message("%s: a Voluntária foi atraída pela isca." % label_text, 2.0)
    await get_tree().create_timer(duration).timeout
    if is_instance_valid(decoy): decoy_reached(decoy)

func _use_apple() -> void:
    _make_decoy("TOR AJO / MAÇÃ".replace(" ", ""), Color(0.95, 0.18, 0.12), 5.0)

func _use_clone() -> void:
    _make_decoy("PESSY / CLONE", Color(0.95, 0.55, 0.82), 4.0)

func _use_hearing() -> void:
    if ended: return
    if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 18.0:
        _show_message("JAY: passos detectados a %.1f metros!" % player.global_position.distance_to(enemy.global_position), 2.2)
        var marker := MeshInstance3D.new()
        var ring := TorusMesh.new()
        ring.inner_radius = 0.52
        ring.outer_radius = 0.68
        marker.mesh = ring
        marker.material_override = _mat(Color(0.35, 0.85, 1.0), Color(0.1, 0.55, 1.0))
        marker.global_position = enemy.global_position + Vector3(0, 0.08, 0)
        add_child(marker)
        await get_tree().create_timer(1.2).timeout
        if is_instance_valid(marker): marker.queue_free()
    else:
        _show_message("JAY: nenhum passo detectável por perto.", 1.8)

func _use_zulmi_focus() -> void:
    if ended or ability_lock > 0.0: return
    ability_lock = 2.0
    if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 9.0:
        enemy.stun(1.8)
        _show_message("ZULMI: contenção temporária ativada.", 2.0)
    else:
        _show_message("ZULMI: foco ampliado — investigue os registros e detalhes do laboratório.", 2.0)

func _use_linn_regen() -> void:
    if ended or ability_lock > 0.0: return
    ability_lock = 3.0
    if player.has_method("restore_stamina"): player.restore_stamina(45.0)
    _play_sfx("pickup")
    _show_message("LINN: regeneração ativada; energia recuperada.", 2.0)

func _show_message(value: String, duration: float) -> void:
    if not is_instance_valid(message_label): return
    message_label.text = value
    await get_tree().create_timer(duration).timeout
    if not ended and is_instance_valid(message_label) and message_label.text == value:
        message_label.text = ""

func decoy_reached(decoy: Node3D) -> void:
    if not is_instance_valid(decoy): return
    if active_decoy == decoy:
        active_decoy = null
        if is_instance_valid(enemy): enemy.target = player
    decoy.queue_free()

func _add_touch_button(root: Control, label_text: String, bottom_left: Vector2, size_value: Vector2, action: String) -> void:
    var button := Button.new()
    button.text = label_text
    button.size = size_value
    button.position = Vector2(bottom_left.x, 0)
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.offset_top = bottom_left.y
    button.offset_bottom = bottom_left.y + size_value.y
    button.add_theme_font_size_override("font_size", 19)
    button.modulate = Color(0.8, 1.0, 1.0, 0.9)
    button.button_down.connect(func(): Input.action_press(action))
    button.button_up.connect(func(): Input.action_release(action))
    root.add_child(button)

func _static_box(node_name: String, pos: Vector3, size_value: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = pos
    var shape := BoxShape3D.new()
    shape.size = size_value
    var collision := CollisionShape3D.new()
    collision.shape = shape
    body.add_child(collision)
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size_value
    visual.mesh = mesh
    visual.material_override = _mat(color)
    body.add_child(visual)
    add_child(body)

func _mat(color: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    if emission != Color.BLACK:
        material.emission_enabled = true
        material.emission = emission
    return material

func _on_record_entered(body: Node3D, area: Area3D) -> void:
    if body != player or not is_instance_valid(area) or not record_areas.has(area) or ended: return
    record_areas.erase(area)
    records_found += 1
    _play_sfx("pickup")
    area.queue_free()
    _update_status()
    message_label.text = "REGISTRO RECUPERADO" if records_found < 3 else "TODOS OS REGISTROS RECUPERADOS! VÁ À SAÍDA!"
    await get_tree().create_timer(1.8).timeout
    if not ended and is_instance_valid(message_label): message_label.text = ""

func _on_exit_entered(body: Node3D) -> void:
    if body != player or ended: return
    if records_found < 3:
        message_label.text = "SAÍDA BLOQUEADA — FALTAM REGISTROS!"
        return
    ended = true
    _play_sfx("door")
    _play_sfx("victory")
    get_tree().set_meta("game_ended", true)
    message_label.text = "VOCÊ ESCAPOU!\nMISSÃO CONCLUÍDA. TOQUE EM REINICIAR PARA JOGAR DE NOVO."

func player_caught() -> void:
    if ended: return
    ended = true
    _play_sfx("caught")
    get_tree().set_meta("game_ended", true)
    message_label.text = "A VOLUNTÁRIA TE ALCANÇOU.\nTENTE OUTRA ROTA OU USE O PULSO PARA GANHAR TEMPO."

func _use_pulse() -> void:
    if ended or pulse_cooldown > 0.0: return
    pulse_cooldown = 6.0
    pulse_fx_timer = 0.65
    _play_sfx("pulse")
    if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 8.0:
        enemy.stun(2.4)
        message_label.text = "PULSO ATIVADO — A VOLUNTÁRIA FOI ATORDOADA!"
        await get_tree().create_timer(1.6).timeout
        if not ended and is_instance_valid(message_label): message_label.text = ""
    else:
        message_label.text = "PULSO ATIVADO — NENHUMA AMEAÇA NO ALCANCE."
        await get_tree().create_timer(1.4).timeout
        if not ended and is_instance_valid(message_label): message_label.text = ""

func set_stamina_value(value: float, maximum: float) -> void:
    if is_instance_valid(stamina_bar):
        stamina_bar.max_value = maximum
        stamina_bar.value = value

func _update_status() -> void:
    if is_instance_valid(status_label):
        status_label.text = "REGISTROS: %d/3" % records_found
    if is_instance_valid(threat_label):
        var level := "CRÍTICA" if records_found >= 2 else ("ELEVADA" if records_found == 1 else "ATIVA")
        threat_label.text = "AMEAÇA: %s" % level

func _restart_game() -> void:
    get_tree().set_meta("game_ended", false)
    get_tree().reload_current_scene()
