extends Camera3D
class_name IsometricCamera
# Isometric camera controller for tile-based view

@export var move_speed: float = 20.0
@export var zoom_speed: float = 5.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 150.0
@export var rotation_speed: float = 90.0  # Degrees per second

var current_zoom: float = 30.0
var target_position: Vector3 = Vector3.ZERO
var camera_rotation: float = 45.0  # Degrees around Y axis

# Panning with middle mouse
var is_panning: bool = false
var last_mouse_pos: Vector2

var is_mouse_over_ui: bool = false

func _ready():
	_update_camera_transform()

func _process(delta):
	_handle_input(delta)
	_update_camera_position(delta)

func _handle_input(delta):
	# WASD movement - relative to camera rotation (RTS-style)
	var forward = Vector3.ZERO
	var right = Vector3.ZERO
	
	# Calculate forward and right vectors based on camera rotation
	var angle_rad = deg_to_rad(camera_rotation)
	forward = Vector3(-sin(angle_rad), 0, -cos(angle_rad))
	right = Vector3(cos(angle_rad), 0, -sin(angle_rad))
	
	var movement = Vector3.ZERO
	
	if Input.is_action_pressed("camera_up"):
		movement += forward
	if Input.is_action_pressed("camera_down"):
		movement -= forward
	if Input.is_action_pressed("camera_left"):
		movement -= right
	if Input.is_action_pressed("camera_right"):
		movement += right
	
	if movement.length() > 0:
		movement = movement.normalized()
		target_position += movement * move_speed * delta
	
	# Q/E rotation
	if Input.is_action_pressed("camera_rotate_left"):
		camera_rotation += rotation_speed * delta
	if Input.is_action_pressed("camera_rotate_right"):
		camera_rotation -= rotation_speed * delta
	
	# Normalize rotation
	camera_rotation = fmod(camera_rotation, 360.0)
	
	# Mouse wheel zoom - only if not over UI
	if not is_mouse_over_ui:
		if Input.is_action_just_pressed("camera_zoom_in"):
			current_zoom = clamp(current_zoom - zoom_speed, min_zoom, max_zoom)
		if Input.is_action_just_pressed("camera_zoom_out"):
			current_zoom = clamp(current_zoom + zoom_speed, min_zoom, max_zoom)

func _input(event):
	# Middle mouse button panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				last_mouse_pos = event.position
			else:
				is_panning = false
	
	if event is InputEventMouseMotion and is_panning:
		var delta_mouse = event.position - last_mouse_pos
		last_mouse_pos = event.position
		
		# Calculate forward and right based on camera rotation
		var angle_rad = deg_to_rad(camera_rotation)
		var forward = Vector3(-sin(angle_rad), 0, -cos(angle_rad))
		var right = Vector3(cos(angle_rad), 0, -sin(angle_rad))
		
		# Pan based on mouse movement
		var pan_speed = current_zoom * 0.015
		target_position -= right * delta_mouse.x * pan_speed
		target_position += forward * delta_mouse.y * pan_speed

func _update_camera_position(delta):
	"""Smoothly update camera transform"""
	# Lerp position
	position = position.lerp(target_position, delta * 5.0)
	
	_update_camera_transform()

func _update_camera_transform():
	"""Update camera orientation based on zoom and rotation"""
	# Isometric angle (45 degrees down)
	var angle_down = deg_to_rad(45.0)
	var angle_around = deg_to_rad(camera_rotation)
	
	# Calculate camera offset from target
	var offset = Vector3(
		sin(angle_around) * cos(angle_down),
		sin(angle_down),
		cos(angle_around) * cos(angle_down)
	) * current_zoom
	
	position = target_position + offset
	look_at(target_position, Vector3.UP)

func focus_on_position(world_pos: Vector3):
	"""Move camera to focus on a specific position"""
	target_position = world_pos

func get_mouse_world_position() -> Vector3:
	"""Get the world position under the mouse cursor"""
	var mouse_pos = get_viewport().get_mouse_position()
	var from = project_ray_origin(mouse_pos)
	var to = from + project_ray_normal(mouse_pos) * 1000.0
	
	# Raycast to find intersection with ground plane (y=0)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	else:
		# If no collision, calculate intersection with y=0 plane
		var t = -from.y / (to.y - from.y)
		return from + (to - from) * t
