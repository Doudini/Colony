extends Node
@export var grid_width := 256
@export var grid_height := 256
@export var water_texture: Texture2D
const WATER_SHADER := preload("res://shaders/water.gdshader")

const TILE_SIZE := 2.0
const CHUNK_SIZE := 16
const WATER_LEVEL := 0.25
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var water_mesh := _create_water_mesh()
	add_child(water_mesh)
	pass # Replace with function body.


func _create_water_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_width = (grid_width * TILE_SIZE) * 0.5
	var half_height = (grid_height * TILE_SIZE) * 0.5

	var v0 := Vector3(-half_width, WATER_LEVEL, -half_height)
	var v1 := Vector3(half_width, WATER_LEVEL, -half_height)
	var v2 := Vector3(half_width, WATER_LEVEL, half_height)
	var v3 := Vector3(-half_width, WATER_LEVEL, half_height)

	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(v0)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(v1)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(v2)

	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(v0)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(v2)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(v3)

	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = WATER_SHADER
	if water_texture:
		shader_mat.set_shader_parameter("water_texture", water_texture)
	shader_mat.set_shader_parameter("color", Color(0.133, 0.407, 0.572, 1.0))
	shader_mat.set_shader_parameter("deep_water", Color(0.04, 0.19, 0.44, 1.0))
	shader_mat.set_shader_parameter("edge_color", Color(0.0, 1.0, 1.0, 1.0))
	mi.material_override = shader_mat

	return mi
