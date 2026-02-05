extends MeshInstance3D

@export var tile_size := 2.0
@export var line_width_px := 2.0
@export var line_color := Color(0, 0, 0, 0.25)
@export var visible_grid := true

func _ready():
	# Big quad covering the entire map
	var quad := QuadMesh.new()
	quad.size = Vector2(10000, 10000)
	mesh = quad

	rotation_degrees.x = -90
	position.y = 0.01  # Slightly above terrain to avoid z-fighting

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grid_overlay.gdshader")
	material_override = mat

	_update_shader()

func _update_shader():
	if not material_override:
		return
	var mat := material_override as ShaderMaterial
	mat.set_shader_parameter("tile_size", tile_size)
	mat.set_shader_parameter("line_width_px", line_width_px)
	mat.set_shader_parameter("line_color", line_color)
	mat.set_shader_parameter("enabled", visible_grid)

func set_visible_grid(value: bool):
	visible_grid = value
	_update_shader()

func toggle():
	set_visible_grid(!visible_grid)
