extends CharacterBody3D

var target: Node3D
var chase_speed := 2.65
var base_chase_speed := 2.65
var active := true
var stun_timer := 0.0
var visual_root: Node3D
var limb_nodes: Array[MeshInstance3D] = []
var anim_time := 0.0

func _ready() -> void:
    name = "Voluntaria"
    var shape := CapsuleShape3D.new()
    shape.radius = 0.40
    shape.height = 1.88
    var collision := CollisionShape3D.new()
    collision.shape = shape
    collision.position.y = 0.94
    add_child(collision)
    visual_root = Node3D.new()
    add_child(visual_root)
    _build_model()

func _build_model() -> void:
    var dark := _mat(Color(0.035, 0.028, 0.055))
    var accent := _mat(Color(0.20, 0.035, 0.09), Color(0.08, 0.005, 0.025))
    _part(CapsuleMesh.new(), Vector3(0, 0.85, 0), dark, Vector3(0.74, 1.0, 0.74))
    _part(SphereMesh.new(), Vector3(0, 1.68, 0), _mat(Color(0.055, 0.035, 0.075)), Vector3(0.94, 1.0, 0.86))
    # Cabelo/sombra estilizada e marcas de contaminação provisórias.
    _part(SphereMesh.new(), Vector3(0, 1.93, 0.04), dark, Vector3(1.05, 0.58, 0.98))
    _part(BoxMesh.new(), Vector3(0, 0.84, -0.32), accent, Vector3(0.48, 0.38, 0.10))
    for side in [-1.0, 1.0]:
        _part(BoxMesh.new(), Vector3(side * 0.135, 1.70, -0.37), _mat(Color(0.18, 0.96, 1.0), Color(0.04, 0.75, 0.9)), Vector3(0.17, 0.055, 0.055))
        var arm := _part(CapsuleMesh.new(), Vector3(side * 0.43, 0.91, 0), dark, Vector3(0.34, 0.82, 0.34))
        limb_nodes.append(arm)
        var leg := _part(CapsuleMesh.new(), Vector3(side * 0.18, 0.27, 0.01), dark, Vector3(0.36, 0.62, 0.36))
        limb_nodes.append(leg)
    _part(BoxMesh.new(), Vector3(0, 0.25, -0.03), accent, Vector3(0.60, 0.18, 0.72))

func _part(mesh: Mesh, pos: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = pos
    node.scale = scale_value
    node.material_override = material
    visual_root.add_child(node)
    return node

func _physics_process(delta: float) -> void:
    if stun_timer > 0.0:
        stun_timer -= delta
        velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
        if not is_on_floor(): velocity.y -= 18.0 * delta
        else: velocity.y = -0.2
        move_and_slide()
        visual_root.scale = Vector3.ONE * (1.0 + sin(stun_timer * 18.0) * 0.04)
        return
    visual_root.scale = Vector3.ONE
    visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 0.12)
    if not active or target == null or get_tree().get_meta("game_ended", false):
        velocity.x = move_toward(velocity.x, 0.0, chase_speed * delta)
        velocity.z = move_toward(velocity.z, 0.0, chase_speed * delta)
        move_and_slide()
        return
    var game = get_tree().current_scene
    var recovered := 0
    if game != null:
        var value = game.get("records_found")
        if value != null: recovered = int(value)
    # A Voluntária fica mais agressiva conforme o jogador recupera evidências.
    chase_speed = base_chase_speed + float(recovered) * 0.22
    var offset: Vector3 = target.global_position - global_position
    offset.y = 0
    if offset.length() > 0.05:
        var dir := offset.normalized()
        velocity.x = dir.x * chase_speed
        velocity.z = dir.z * chase_speed
        visual_root.rotation.y = atan2(dir.x, dir.z)
        anim_time += delta * 8.0
        visual_root.position.y = 0.025 + absf(sin(anim_time * 2.0)) * 0.045
        if limb_nodes.size() >= 4:
            limb_nodes[0].rotation.x = sin(anim_time) * 0.55
            limb_nodes[2].rotation.x = -sin(anim_time) * 0.55
            limb_nodes[1].rotation.x = -sin(anim_time) * 0.6
            limb_nodes[3].rotation.x = sin(anim_time) * 0.6
    if not is_on_floor(): velocity.y -= 18.0 * delta
    else: velocity.y = -0.2
    move_and_slide()
    if global_position.distance_to(target.global_position) < 1.15:
        var game = get_tree().current_scene
        if game != null and game.get("active_decoy") == target:
            if game.has_method("decoy_reached"): game.decoy_reached(target)
        elif game != null and game.has_method("player_caught"):
            game.player_caught()

func stun(duration: float) -> void:
    stun_timer = maxf(stun_timer, duration)
    velocity = Vector3.ZERO

func _mat(color: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    if emission != Color.BLACK:
        material.emission_enabled = true
        material.emission = emission
    return material
