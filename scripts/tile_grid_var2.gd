extends TileGrid
class_name TileGridVar2

const HEIGHT_LEVELS := {
	"deep_water": -3.0,
	"shallow_water": -1.5,
	"beach": 0.0,
	"marsh": 0.5,
	"grassland": 1.0,
	"lowland": 1.0,
	"forest": 1.5,
	"ground": 1.0,
	"highland": 2.0,
	"mountain": 3.0
}

const TILE_SUBDIVISIONS := 3
const WATER_LEVEL := 0.25

@export var water_texture: Texture2D
const WATER_SHADER := preload("res://shaders/water.gdshader")

func _create_visual_grid():
	var cx := ceili(grid_width / float(CHUNK_SIZE))
	var cy := ceili(grid_height / float(CHUNK_SIZE))
	print("Creating %d chunks" % (cx * cy))

	for x in range(cx):
		for y in range(cy):
			var coord := Vector2i(x, y)
			var mesh := _create_chunk_mesh(coord)
			chunk_meshes[coord] = mesh
			add_child(mesh)


func _create_chunk_mesh(chunk: Vector2i) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sx := chunk.x * CHUNK_SIZE
	var sy := chunk.y * CHUNK_SIZE
	var ex = min(sx + CHUNK_SIZE, grid_width)
	var ey = min(sy + CHUNK_SIZE, grid_height)

	for x in range(sx, ex):
		for y in range(sy, ey):
			var tile_pos = Vector2i(x, y)

			if terrain_atlas:
				var layer_data = _get_tile_layer_data(tile_pos)
				_add_subdivided_tile(
					st,
					tile_pos,
					layer_data["base_uv"],
					layer_data["transition_uv"],
					layer_data["mask_index"]
				)
			else:
				var color := _get_tile_color(grid[x][y])
				_add_subdivided_tile_with_color(st, tile_pos, color)

	st.index()
	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()

	if terrain_atlas:
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = TERRAIN_SHADER
		shader_mat.set_shader_parameter("terrain_atlas", terrain_atlas)
		mi.material_override = shader_mat
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mi.material_override = mat

	return mi


func _add_subdivided_tile(
	st: SurfaceTool,
	tile_pos: Vector2i,
	base_uv: Array,
	transition_uv: Array,
	mask_index: int
):
	var h := TILE_SIZE * 0.5
	var center := grid_to_world(tile_pos)
	var x0 := center.x - h
	var z0 := center.z - h
	var x1 := center.x + h
	var z1 := center.z + h

	var h00 = _get_corner_height(tile_pos.x, tile_pos.y)
	var h10 = _get_corner_height(tile_pos.x + 1, tile_pos.y)
	var h11 = _get_corner_height(tile_pos.x + 1, tile_pos.y + 1)
	var h01 = _get_corner_height(tile_pos.x, tile_pos.y + 1)

	var mask_encoded := Color(mask_index / 16.0, 0.0, 0.0, 1.0)
	var steps := TILE_SUBDIVISIONS
	var inv_steps := 1.0 / float(steps)

	for i in range(steps):
		for j in range(steps):
			var u0 = i * inv_steps
			var v0 = j * inv_steps
			var u1 = (i + 1) * inv_steps
			var v1 = (j + 1) * inv_steps

			var vtx00 := _build_vertex(x0, z0, x1, z1, h00, h10, h01, h11, u0, v0)
			var vtx10 := _build_vertex(x0, z0, x1, z1, h00, h10, h01, h11, u1, v0)
			var vtx11 := _build_vertex(x0, z0, x1, z1, h00, h10, h01, h11, u1, v1)
			var vtx01 := _build_vertex(x0, z0, x1, z1, h00, h10, h01, h11, u0, v1)

			var uv00 := _bilerp_uv(base_uv, u0, v0)
			var uv10 := _bilerp_uv(base_uv, u1, v0)
			var uv11 := _bilerp_uv(base_uv, u1, v1)
			var uv01 := _bilerp_uv(base_uv, u0, v1)

			var uv2_00 := _bilerp_uv(transition_uv, u0, v0)
			var uv2_10 := _bilerp_uv(transition_uv, u1, v0)
			var uv2_11 := _bilerp_uv(transition_uv, u1, v1)
			var uv2_01 := _bilerp_uv(transition_uv, u0, v1)

			st.set_color(mask_encoded)
			st.set_uv(uv00)
			st.set_uv2(uv2_00)
			st.add_vertex(vtx00)

			st.set_color(mask_encoded)
			st.set_uv(uv10)
			st.set_uv2(uv2_10)
			st.add_vertex(vtx10)

			st.set_color(mask_encoded)
			st.set_uv(uv11)
			st.set_uv2(uv2_11)
			st.add_vertex(vtx11)

			st.set_color(mask_encoded)
			st.set_uv(uv00)
			st.set_uv2(uv2_00)
			st.add_vertex(vtx00)

			st.set_color(mask_encoded)
			st.set_uv(uv11)
			st.set_uv2(uv2_11)
			st.add_vertex(vtx11)

			st.set_color(mask_encoded)
			st.set_uv(uv01)
			st.set_uv2(uv2_01)
			st.add_vertex(vtx01)

func _add_subdivided_tile_with_color(st: SurfaceTool, tile_pos: Vector2i, color: Color):
	var h := TILE_SIZE * 0.5
	var center := grid_to_world(tile_pos)
	var x0 := center.x - h
	var z0 := center.z - h
	var x1 := center.x + h
	var z1 := center.z + h

	var h00 = _get_corner_height(tile_pos.x, tile_pos.y)
	var h10 = _get_corner_height(tile_pos.x + 1, tile_pos.y)
	var h11 = _get_corner_height(tile_pos.x + 1, tile_pos.y + 1)
	var h01 = _get_corner_height(tile_pos.x, tile_pos.y + 1)

	var steps := TILE_SUBDIVISIONS
	var inv_steps := 1.0 / float(steps)

	for i in range(steps):
		for j in range(steps):
			var u0 = i * inv_steps
			var v0 = j * inv_steps
			var u1 = (i + 1) * inv_steps
			var v1 = (j + 1) * inv_steps

			var vtx00 := _build_vertex(x0, z0, x1, z1, h00, h10, h01, h11, u0, v0)
			var vtx10 := _build_vertex(x0, z0, x1, z1, h00, h10, h01, h11, u1, v0)
			var vtx11 := _build_vertex(x0, z0, x1, z1, h00, h10, h01, h11, u1, v1)
			var vtx01 := _build_vertex(x0, z0, x1, z1, h00, h10, h01, h11, u0, v1)

			st.set_color(color)
			st.add_vertex(vtx00)
			st.add_vertex(vtx10)
			st.add_vertex(vtx11)

			st.set_color(color)
			st.add_vertex(vtx00)
			st.add_vertex(vtx11)
			st.add_vertex(vtx01)

func _build_vertex(
	x0: float,
	z0: float,
	x1: float,
	z1: float,
	h00: float,
	h10: float,
	h01: float,
	h11: float,
	u: float,
	v: float
) -> Vector3:
	var x = lerp(x0, x1, u)
	var z = lerp(z0, z1, v)
	var height = _bilerp_height(h00, h10, h01, h11, u, v)
	return Vector3(x, height, z)

func _bilerp_height(h00: float, h10: float, h01: float, h11: float, u: float, v: float) -> float:
	return (1.0 - u) * (1.0 - v) * h00 \
		+ u * (1.0 - v) * h10 \
		+ u * v * h11 \
		+ (1.0 - u) * v * h01

func _bilerp_uv(uvs: Array, u: float, v: float) -> Vector2:
	var uv00: Vector2 = uvs[0]
	var uv10: Vector2 = uvs[1]
	var uv11: Vector2 = uvs[2]
	var uv01: Vector2 = uvs[3]

	var top = uv00.lerp(uv10, u)
	var bottom = uv01.lerp(uv11, u)
	return top.lerp(bottom, v)

func _get_corner_height(cx: int, cy: int) -> float:
	var total := 0.0
	var count := 0.0

	for dx in [-1, 0]:
		for dy in [-1, 0]:
			var tx = cx + dx
			var ty = cy + dy
			if tx < 0 or ty < 0 or tx >= grid_width or ty >= grid_height:
				continue
			total += _get_height_for_terrain(grid[tx][ty]["type"])
			count += 1.0

	return total / max(1.0, count)

func _get_height_for_terrain(terrain_type: String) -> float:
	return HEIGHT_LEVELS.get(terrain_type, 0.0)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var base = Vector3(
		grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		0.0,
		grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	)
	base.y = _get_height_for_terrain(grid[grid_pos.x][grid_pos.y]["type"])
	return base
