class_name PlayerPawn
extends CharacterBody3D

const WALK_SPEED := 4.5
const RUN_SPEED := 7.8
const LOOK_SENS := 0.0028

var yaw := 0.0
var facing := 0.0
var pitch := -0.22
var sitting := false
var pending_sit := false
var move_input := Vector2.ZERO
var sprinting := false
var script_driven := false
var stick_active := false
var visual_sit := 0.0
var camera: Camera3D

var _visual: Node3D
var _hips: Node3D
var _thigh_l: Node3D
var _thigh_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _phase := 0.0
var _half := 470.0
var _water_y := 3.35
var _frozen := false


func setup(shirt: Color) -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(52.0)
	safe_margin = 0.08
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.74
	shape.shape = capsule
	shape.position = Vector3(0, 0.87, 0)
	add_child(shape)
	_build_visual(shirt)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 1600.0
	camera.current = true
	camera.top_level = true
	add_child(camera)


func configure_world(map_half: float, water_y: float) -> void:
	_half = map_half
	_water_y = water_y


func set_frozen(value: bool) -> void:
	_frozen = value


func place(pos: Vector3, cam_yaw: float, face_yaw: float, look_pitch: float) -> void:
	global_position = pos
	yaw = cam_yaw
	facing = face_yaw
	pitch = clampf(look_pitch, -1.05, 0.62)
	velocity = Vector3.ZERO
	_sync_visual()


func add_look(dx: float, dy: float) -> void:
	yaw -= dx * LOOK_SENS
	pitch = clampf(pitch - dy * 0.0022, -1.05, 0.62)


func toggle_sit() -> bool:
	if sitting:
		sitting = false
		return true
	if not is_on_floor():
		return false
	sitting = true
	velocity.x = 0.0
	velocity.z = 0.0
	return true


static func planar_wish(move: Vector2, cam_yaw: float) -> Vector3:
	var local := Vector3(move.x, 0.0, -move.y)
	if local.length_squared() > 1.0:
		local = local.normalized()
	elif local.length_squared() < 0.0001:
		return Vector3.ZERO
	return Basis(Vector3.UP, cam_yaw) * local


func _physics_process(delta: float) -> void:
	if pending_sit and is_on_floor():
		sitting = true
		pending_sit = false
	if not script_driven:
		_read_devices()
	if _frozen:
		velocity = Vector3.ZERO
		return
	var wish := planar_wish(move_input, yaw)
	if sitting:
		wish = Vector3.ZERO
	elif wish.length_squared() > 0.04:
		var target_face := atan2(-wish.x, -wish.z)
		facing = lerp_angle(facing, target_face, 1.0 - exp(-12.0 * delta))
	var speed := RUN_SPEED if sprinting else WALK_SPEED
	if global_position.y < _water_y + 0.35:
		speed *= 0.55
	var target := wish * speed
	var blend := 1.0 - exp(-10.0 * delta)
	velocity.x = lerpf(velocity.x, target.x, blend)
	velocity.z = lerpf(velocity.z, target.z, blend)
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	else:
		velocity.y = -1.2
	move_and_slide()
	var limit := _half - 12.0
	if absf(global_position.x) > limit or absf(global_position.z) > limit:
		global_position.x = clampf(global_position.x, -limit, limit)
		global_position.z = clampf(global_position.z, -limit, limit)


func _process(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4 and not sitting
	if moving:
		_phase += delta * lerpf(7.0, 11.0, clampf(Vector2(velocity.x, velocity.z).length() / RUN_SPEED, 0.0, 1.0))
	visual_sit = lerpf(visual_sit, 1.0 if sitting else 0.0, 1.0 - exp(-8.0 * delta))
	_sync_visual()
	_apply_pose()
	_place_camera()


func _read_devices() -> void:
	var key := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key.x += 1.0
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if joy.length() < 0.18:
		joy = Vector2.ZERO
	if key != Vector2.ZERO:
		move_input = key
		sprinting = Input.is_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)
	elif joy != Vector2.ZERO:
		move_input = joy
		sprinting = joy.length() > 0.82
	elif not stick_active:
		move_input = Vector2.ZERO
		sprinting = false
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > 0.18:
		add_look(look.x * 16.0, look.y * 10.0)


func _sync_visual() -> void:
	if _visual:
		_visual.rotation.y = wrapf(facing - yaw, -PI, PI)


func _apply_pose() -> void:
	if _hips == null:
		return
	var sit := visual_sit
	_hips.position.y = lerpf(0.92, 0.48, sit)
	var swing := sin(_phase) * lerpf(0.65, 0.0, sit)
	_thigh_l.rotation.x = lerpf(swing, -1.25, sit)
	_thigh_r.rotation.x = lerpf(-swing, -1.25, sit)
	_shin_l.rotation.x = lerpf(maxf(-swing, 0.0) * 0.8, 1.35, sit)
	_shin_r.rotation.x = lerpf(maxf(swing, 0.0) * 0.8, 1.35, sit)
	_arm_l.rotation.x = lerpf(-swing * 0.7, -0.4, sit)
	_arm_r.rotation.x = lerpf(swing * 0.7, -0.4, sit)


func _place_camera() -> void:
	if camera == null:
		return
	var dist := lerpf(4.45, 3.05, visual_sit)
	var pivot := global_position + Vector3(0.0, lerpf(1.5, 0.92, visual_sit), 0.0)
	var offset := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0.0, 0.0, dist)
	var want := pivot + offset
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(pivot, want, 1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var normal := (pivot - want).normalized()
			want = hit.position + normal * 0.28
	camera.global_position = want
	if want.distance_squared_to(pivot) > 0.05:
		camera.look_at(pivot, Vector3.UP)


func _build_visual(shirt: Color) -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.92, 0)
	_visual.add_child(_hips)
	_mesh(_hips, BoxMesh.new(), shirt, Vector3(0.46, 0.52, 0.26), Vector3(0, 0.28, 0))
	var head := SphereMesh.new()
	head.radius = 0.16
	head.height = 0.32
	_mesh(_hips, head, Color(0.74, 0.58, 0.45), Vector3.ONE, Vector3(0, 0.66, 0))
	_arm_l = _limb(_hips, Vector3(-0.32, 0.42, 0), 0.42, shirt.darkened(0.15))
	_arm_r = _limb(_hips, Vector3(0.32, 0.42, 0), 0.42, shirt.darkened(0.15))
	_thigh_l = _limb(_hips, Vector3(-0.12, -0.02, 0), 0.44, Color(0.16, 0.17, 0.2))
	_thigh_r = _limb(_hips, Vector3(0.12, -0.02, 0), 0.44, Color(0.16, 0.17, 0.2))
	_shin_l = _limb(_thigh_l, Vector3(0, -0.44, 0), 0.42, Color(0.12, 0.13, 0.15))
	_shin_r = _limb(_thigh_r, Vector3(0, -0.44, 0), 0.42, Color(0.12, 0.13, 0.15))


func _limb(parent: Node3D, at: Vector3, length: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.07
	mesh.height = length
	_mesh(pivot, mesh, color, Vector3.ONE, Vector3(0, -length * 0.5, 0))
	return pivot


func _mesh(parent: Node3D, mesh: Mesh, color: Color, mesh_scale: Vector3, at: Vector3) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.scale = mesh_scale
	inst.position = at
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	inst.material_override = mat
	parent.add_child(inst)
