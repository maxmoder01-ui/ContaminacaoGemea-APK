extends CharacterBody3D

var walk_speed := 4.8
var sprint_speed := 7.4
var gravity_strength := 18.0
var visual_root: Node3D
var body_material: StandardMaterial3D
var limb_nodes: Array[MeshInstance3D] = []
var anim_time := 0.0
var stamina := 100.0
var stamina_max := 100.0
var stamina_drain := 27.0
var stamina_recovery := 17.0

func _ready() -> void:
    name = "Player"
    var shape := CapsuleShape3D.new()
    shape.radius = 0.34
    shape.height = 1.62
    var collision := CollisionShape3D.new()
    collision.shape = shape
    collision.position.y = 0.82
    add_child(collision)
    visual_root = Node3D.new()
    visual_root.name = "Visual"
    add_child(visual_root)
    _build_character()

func _build_character() -> void:
    # Usa o modelo GLB de referência enviado pelo usuário. Mantém fallback procedural
    # caso a importação ainda não tenha sido processada pelo editor Godot.
    var model_scene: PackedScene = load("res://assets/characters/torajo_base.glb") as PackedScene
    if model_scene != null:
        var model_instance := model_scene.instantiate()
        model_instance.name = "TorajoModel"
        model_instance.scale = Vector3(0.22, 0.22, 0.22)
        model_instance.position = Vector3(0, 0.02, 0)
        visual_root.add_child(model_instance)
        return
    body_material = _mat(Color(0.12, 0.58, 0.36))
    _part(CapsuleMesh.new(), Vector3(0, 0.78, 0), body_material, Vector3(0.62, 1.0, 0.62))
    _part(SphereMesh.new(), Vector3(0, 1.48, 0), _mat(Color(0.20, 0.78, 0.46)), Vector3(0.88, 0.88, 0.88))
    _part(BoxMesh.new(), Vector3(0, 0.83, -0.32), _mat(Color(0.08, 0.12, 0.12)), Vector3(0.54, 0.40, 0.12))
    for side in [-1.0, 1.0]:
        _part(SphereMesh.new(), Vector3(side * 0.105, 1.52, -0.375), _mat(Color(0.94, 1.0, 0.91)), Vector3(0.15, 0.18, 0.10))
        _part(SphereMesh.new(), Vector3(side * 0.105, 1.52, -0.425), _mat(Color(0.025, 0.055, 0.045)), Vector3(0.07, 0.09, 0.04))
        var arm := _part(CapsuleMesh.new(), Vector3(side * 0.39, 0.83, 0), _mat(Color(0.12, 0.58, 0.36)), Vector3(0.34, 0.72, 0.34))
        limb_nodes.append(arm)
        var leg := _part(CapsuleMesh.new(), Vector3(side * 0.16, 0.27, 0), _mat(Color(0.08, 0.22, 0.20)), Vector3(0.34, 0.60, 0.34))
        limb_nodes.append(leg)
    _part(BoxMesh.new(), Vector3(0, 0.25, -0.03), _mat(Color(0.04, 0.10, 0.10)), Vector3(0.58, 0.18, 0.70))

func _part(mesh: Mesh, pos: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = pos
    node.scale = scale_value
    node.material_override = material
    visual_root.add_child(node)
    return node

func _physics_process(delta: float) -> void:
    if get_tree().get_meta("game_ended", false):
        velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
        move_and_slide()
        return
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var camera := get_viewport().get_camera_3d()
    var direction := Vector3.ZERO
    if camera:
        var forward := -camera.global_basis.z
        forward.y = 0
        forward = forward.normalized()
        var right := camera.global_basis.x
        right.y = 0
        right = right.normalized()
        direction = (right * input_vec.x + forward * -input_vec.y).normalized()
    var wants_sprint := Input.is_action_pressed("sprint") and stamina > 0.5 and direction.length() > 0.1
    if wants_sprint:
        stamina = maxf(0.0, stamina - stamina_drain * delta)
    else:
        stamina = minf(stamina_max, stamina + stamina_recovery * delta)
    var speed := sprint_speed if wants_sprint else walk_speed
    var game := get_tree().current_scene
    if game and game.has_method("set_stamina_value"):
        game.set_stamina_value(stamina, stamina_max)
    velocity.x = move_toward(velocity.x, direction.x * speed, 22.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 22.0 * delta)
    if not is_on_floor(): velocity.y -= gravity_strength * delta
    else: velocity.y = -0.2
    if direction.length() > 0.1:
        visual_root.rotation.y = atan2(direction.x, direction.z)
        anim_time += delta * (13.0 if speed == sprint_speed else 8.0)
        visual_root.position.y = 0.025 + absf(sin(anim_time * 2.0)) * 0.035
        if limb_nodes.size() >= 4:
            limb_nodes[0].rotation.x = sin(anim_time) * 0.48
            limb_nodes[2].rotation.x = -sin(anim_time) * 0.48
            limb_nodes[1].rotation.x = -sin(anim_time) * 0.55
            limb_nodes[3].rotation.x = sin(anim_time) * 0.55
    else:
        visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 0.12)
        for limb in limb_nodes: limb.rotation.x = move_toward(limb.rotation.x, 0.0, delta * 5.0)
    move_and_slide()

func restore_stamina(amount: float) -> void:
    stamina = minf(stamina_max, stamina + amount)

func _mat(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.75
    return material
