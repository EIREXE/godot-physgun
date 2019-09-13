extends Spatial

var physics_moving_object : RigidBody
var _pmo_local_hit_diff : Vector3
var _pmo_rotation_diff : Quat
var _pmo_distance : float

const ROTATION_TOLERANCE = 0.8
const ARC_RESOLUTION = 12

onready var line_renderer : LineRenderer = get_node("LineRenderer")
const ROTATION_SENSITIVITY = 0.0025

const GRAB_MAX = 10.0
const GRAB_MIN = 1.5

var _scrollwheel_input : float = 0.0
var _rotation_input := Vector3()
var uv_animation_rate := Vector3(1.0, 0.0, 0.0)

func _ready():
	var line_mat := line_renderer.material_override
	line_mat.albedo_color = Color(0.0, 0.7, 1.0, 0.8)
	line_mat.uv1_scale = Vector3(5.0, 1.0, 1.0)
	line_renderer.points = []
	
	for line in range(ARC_RESOLUTION):
		line_renderer.points.append(Vector3())
	line_renderer.hide()
	
func update_arc_points(a: Vector3, b: Vector3 , c: Vector3):
	b = lerp(a,b, 0.6)
	for i in range(line_renderer.points.size()):
		var t = float(i)/float(line_renderer.points.size())
		
		line_renderer.points[i] = lerp(lerp(a, b ,t), lerp(b, c, t), t)
		
	line_renderer.points[line_renderer.points.size()-1] = c

func _input(event):
	if event.is_action("phys_back"):
		_scrollwheel_input -= 1.0
	elif event.is_action("phys_forward"):
		_scrollwheel_input += 1.0
		
	if event is InputEventMouseMotion and Input.is_action_pressed("phys_rotate"):

		if abs(event.relative.y) > ROTATION_TOLERANCE:
			_rotation_input.y = event.relative.y * ROTATION_SENSITIVITY
		if abs(event.relative.x) > ROTATION_TOLERANCE:
			if Input.is_action_pressed("rotate_z"):
				_rotation_input.x = -event.relative.x * ROTATION_SENSITIVITY
				_rotation_input.y = 0
			else:
				_rotation_input.z = event.relative.x * ROTATION_SENSITIVITY
	if event.is_action("fire1"):
		fire(event)

func fire(event: InputEvent):
	if event.is_pressed():
		var screen_middle = get_viewport().size / 2
		var camera = get_viewport().get_camera()
		var from = camera.project_ray_origin(screen_middle)
		var to = from + camera.project_ray_normal(screen_middle) * GRAB_MAX
		var space_state = get_world().direct_space_state
		var result : Dictionary = space_state.intersect_ray(from, to, [self, get_parent()])
	
		if result.has("collider"):
	
			if result.collider is RigidBody:
				var collider := result.collider as RigidBody
				if collider.mode == RigidBody.MODE_RIGID:
					physics_moving_object = collider
					_pmo_rotation_diff = Quat(camera.get_camera_transform().basis).inverse() * Quat(physics_moving_object.global_transform.basis)
					_pmo_local_hit_diff = physics_moving_object.to_local(result.position)
		
					_pmo_distance = (camera.get_camera_transform().origin - result.position).length()

					line_renderer.show()
	if not event.is_pressed() and physics_moving_object:
		
		physics_moving_object = null
		line_renderer.hide()
	
func _physics_process(delta):

	if physics_moving_object:
		var camera = get_viewport().get_camera()
		var forward = camera.get_camera_transform().basis.z
		var right = camera.get_camera_transform().basis.x
		var up = camera.get_camera_transform().basis.y
	
		var relative_to_camera_rotation = Quat(camera.get_camera_transform().basis) * _pmo_rotation_diff
		
		var desired_rotation = relative_to_camera_rotation

		desired_rotation = Quat(forward, _rotation_input.x) * Quat(up, _rotation_input.z) * Quat(right, _rotation_input.y) * relative_to_camera_rotation
	
		
		_pmo_rotation_diff = Quat(camera.get_camera_transform().basis).inverse() * desired_rotation
		
		var screen_middle = get_viewport().size / 2
		var from = camera.project_ray_origin(screen_middle)
		var scroll_wheel_input = (5.0 * delta) * _scrollwheel_input
		var hold_point = from + camera.project_ray_normal(screen_middle) * clamp((_pmo_distance + scroll_wheel_input), GRAB_MIN, GRAB_MAX)
		var center_destination = hold_point - (physics_moving_object.global_transform.xform(_pmo_local_hit_diff) - physics_moving_object.global_transform.origin)
		var to_destination = center_destination - physics_moving_object.global_transform.origin
		var force = to_destination / delta * 0.6 / physics_moving_object.mass
		

		physics_moving_object.linear_velocity = Vector3()
		physics_moving_object.angular_velocity = Vector3()
		
		var rot_diff = desired_rotation * Quat(physics_moving_object.global_transform.basis).inverse()
		
		physics_moving_object.linear_velocity = force
		
		physics_moving_object.angular_velocity = rot_diff.get_euler() * 0.5 / delta
		# Distance to object recalculated
		
		_pmo_distance = (from - hold_point).length()

		# Laser beam variables

		var laser_start_point = $LaserStartPosition.global_transform.origin
		var laser_mid_point = hold_point
		var laser_end_point = physics_moving_object.global_transform.xform(_pmo_local_hit_diff)
	
		update_arc_points(laser_start_point, laser_mid_point, laser_end_point)
		
		# Laser animation
		
		line_renderer.material_override.uv1_offset += uv_animation_rate * delta

		# Input passby reset

		_scrollwheel_input = 0.0
		_rotation_input = Vector3()
