extends Node3D
class_name TileGrid
# TileGrid - Manages the tile-based grid for building placement

const TILE_SIZE = 2.0  # Size of each tile in world units
const CHUNK_SIZE = 16  # 16x16 tiles per chunk
var chunk_meshes: Dictionary = {}  # Replaces tile_meshes

@export var grid_width: int = 256
@export var grid_height: int = 256

# Grid data: grid[x][y] = {type, resource, building, etc}
var grid: Array = []

# Visual tile meshes
var tile_meshes: Dictionary = {}  # {Vector2i: MeshInstance3D}

# Resource deposits on this planet
var resource_deposits: Dictionary = {}  # {Vector2i: resource_id}

func _ready():
	_initialize_grid()
	_generate_terrain()
	_assign_terrain_types()
	_place_resource_deposits()
	_create_visual_grid()

func _initialize_grid():
	"""Create empty grid"""
	grid = []
	for x in range(grid_width):
		var column = []
		for y in range(grid_height):
			column.append({
				"type": "ground",
				"building": null,
				"resource": null,
				"building_origin": null,  # Where the building actually starts
				"occupied": false
			})
		grid.append(column)

func _generate_terrain():
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.015
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	var center = Vector2(grid_width / 2.0, grid_height / 2.0)
	var max_dist = center.length()

	for x in range(grid_width):
		for y in range(grid_height):
			var nx = float(x)
			var ny = float(y)

			# Base height noise
			var height = noise.get_noise_2d(nx, ny)

			# Radial falloff for planet shape
			var dist = Vector2(nx, ny).distance_to(center) / max_dist
			height -= dist * 0.6

			# Store height temporarily
			grid[x][y]["height"] = height

func _assign_terrain_types():
	for x in range(grid_width):
		for y in range(grid_height):
			var h = grid[x][y]["height"]

			if h < -0.35:
				grid[x][y].type = "deep_water"
			elif h < -0.1:
				grid[x][y].type = "shallow_water"
			elif h < 0.25:
				grid[x][y].type = "lowland"
			elif h < 0.55:
				grid[x][y].type = "ground"
			else:
				grid[x][y].type = "highland"

func _place_resource_deposits():
	"""Place resource deposits with GUARANTEED spawning of all types"""
	print("=== RESOURCE GENERATION START ===")

	# GUARANTEED minimum counts for each resource (Anno-style distribution)
	var guaranteed_deposits = {
		"minerals": 50,        # Very common - basic material
		"wood": 50,            # Very common - basic material
		"ore": 40,             # Common - quality alloys
		"water": 50,           # Uncommon - essential
		"hydrogen": 30,        # Uncommon - energy/fuel
		"biomatter": 20,       # Uncommon - growth
		"rare_minerals": 10    # Rare - high-tech
	}
	
	print("Guaranteed deposits per resource (Anno-style):")
	for res_id in guaranteed_deposits:
		print("  %s: %d clusters minimum" % [res_id, guaranteed_deposits[res_id]])
	
	# Place each resource type with guaranteed counts
	for resource_id in guaranteed_deposits:
		var cluster_count = guaranteed_deposits[resource_id]
		_place_resource_type_guaranteed(resource_id, cluster_count)
	
	print("=== RESOURCE GENERATION COMPLETE ===")

func _place_resource_type_guaranteed(resource_id: String, cluster_count: int):
	"""Place a specific number of clusters for a resource - GUARANTEED"""
	var placed_clusters = 0
	var attempts = 0
	var max_attempts = cluster_count * 20  # Give plenty of attempts
	
	var cluster_size_range = [3, 4, 5, 6, 7, 8]  # Decent sized clusters
	
	print("Placing %s: target %d clusters" % [resource_id, cluster_count])
	
	while placed_clusters < cluster_count and attempts < max_attempts:
		attempts += 1
		
		# Pick random position (avoid center spawn area)
		var x = randi() % grid_width
		var y = randi() % grid_height
		var start_pos = Vector2i(x, y)
		
		var center = Vector2i(grid_width / 2, grid_height / 2)
		if start_pos.distance_to(center) < 10:
			continue  # Too close to spawn
		
		# Check if position is free
		if start_pos in resource_deposits:
			continue
		var tile_type = grid[start_pos.x][start_pos.y].type
		if tile_type in ["deep_water", "shallow_water"]:
			continue
		
		# Check minimum spacing (3 tiles) from other deposits
		var too_close = false
		for existing_pos in resource_deposits:
			if start_pos.distance_to(existing_pos) < 3:
				too_close = true
				break
		
		if too_close:
			continue
		
		# Create cluster
		var size = cluster_size_range[randi() % cluster_size_range.size()]
		var cluster = _grow_organic_cluster(start_pos, size)
		if cluster.size() < 3:
			continue
		
		# Place cluster
		for tile_pos in cluster:
			if tile_pos not in resource_deposits:
				resource_deposits[tile_pos] = resource_id
				grid[tile_pos.x][tile_pos.y].resource = resource_id
		
		placed_clusters += 1
	
	print("  ✓ Placed %d/%d clusters of %s (attempts: %d)" % [placed_clusters, cluster_count, resource_id, attempts])

func _grow_organic_cluster(start: Vector2i, target_size: int) -> Array[Vector2i]:
	"""Grow a natural-looking resource cluster"""
	var cluster: Array[Vector2i] = [start]
	var frontier: Array[Vector2i] = [start]
	
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
	]
	
	while cluster.size() < target_size and frontier.size() > 0:
		# Pick random tile from frontier
		var idx = randi() % frontier.size()
		var current = frontier[idx]
		
		# Try to expand
		directions.shuffle()
		var expanded = false
		
		for dir in directions:
			var new_pos = current + dir
			
			# Validate
			if not is_valid_pos(new_pos):
				continue
			if new_pos in cluster:
				continue
			if new_pos in resource_deposits:
				continue
			var tile_type = grid[new_pos.x][new_pos.y].type
			if tile_type in ["deep_water", "shallow_water"]:
				continue
			
			# Add with some randomness (70% chance to keep organic shape)
			if randf() < 0.7:
				cluster.append(new_pos)
				frontier.append(new_pos)
				expanded = true
				break
		
		# Remove from frontier if couldn't expand or randomly
		if not expanded or randf() < 0.4:
			frontier.remove_at(idx)
	
	return cluster

func _add_quad_to_mesh(st: SurfaceTool, pos: Vector3, color: Color):
	"""Add single tile quad to mesh"""
	var h = TILE_SIZE * 0.475  # Small gap between tiles
	
	var v0 = Vector3(pos.x - h, 0, pos.z - h)
	var v1 = Vector3(pos.x + h, 0, pos.z - h)
	var v2 = Vector3(pos.x + h, 0, pos.z + h)
	var v3 = Vector3(pos.x - h, 0, pos.z + h)
	
	# Triangle 1
	st.set_color(color)
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	
	# Triangle 2
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

func _get_tile_color_fast(tile_data: Dictionary) -> Color:
	"""Fast color lookup"""
	# Resource color takes priority
	if tile_data.resource:
		var res = GameData.get_resource_by_id(tile_data.resource)
		if res:
			return res.color * 1.0  # Bright
	
	# Terrain color
	match tile_data.type:
		"deep_water": return Color(0.05, 0.1, 0.2)
		"shallow_water": return Color(0.1, 0.2, 0.3)
		"lowland": return Color(0.25, 0.4, 0.25)
		"ground": return Color(0.35, 0.35, 0.35)
		"highland": return Color(0.5, 0.45, 0.4)
	
	return Color(0.35, 0.35, 0.35)

func _create_chunk_mesh(chunk_coord: Vector2i) -> MeshInstance3D:
	"""Build single mesh for entire chunk"""
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var sx = chunk_coord.x * CHUNK_SIZE
	var sy = chunk_coord.y * CHUNK_SIZE
	var ex = min(sx + CHUNK_SIZE, grid_width)
	var ey = min(sy + CHUNK_SIZE, grid_height)
	
	for x in range(sx, ex):
		for y in range(sy, ey):
			var tile_data = grid[x][y]
			var color = _get_tile_color_fast(tile_data)
			var world_pos = grid_to_world(Vector2i(x, y))
			_add_quad_to_mesh(st, world_pos, color)
	
	st.generate_normals()
	var mesh = st.commit()
	
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	
	return mi

func _create_visual_grid():
	"""Create optimized chunked grid"""
	var chunks_x = ceili(grid_width / float(CHUNK_SIZE))
	var chunks_y = ceili(grid_height / float(CHUNK_SIZE))
	
	print("🚀 Creating %d chunks instead of %d tiles!" % [chunks_x * chunks_y, grid_width * grid_height])
	
	for chunk_x in range(chunks_x):
		for chunk_y in range(chunks_y):
			var chunk_coord = Vector2i(chunk_x, chunk_y)
			var chunk_mesh = _create_chunk_mesh(chunk_coord)
			if chunk_mesh:
				chunk_meshes[chunk_coord] = chunk_mesh
				add_child(chunk_mesh)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	"""Convert grid coordinates to world position"""
	return Vector3(
		grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		0,
		grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	"""Convert world position to grid coordinates"""
	var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	return Vector2i(x, y)

func is_valid_pos(grid_pos: Vector2i) -> bool:
	"""Check if grid position is within bounds"""
	return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   grid_pos.y >= 0 and grid_pos.y < grid_height

func can_place_building(grid_pos: Vector2i, building_size: Vector2i) -> bool:
	"""Check if a building can be placed at position"""
	# Check all tiles the building would occupy
	for dx in range(building_size.x):
		for dy in range(building_size.y):
			var check_pos = grid_pos + Vector2i(dx, dy)
			
			if not is_valid_pos(check_pos):
				return false
			
			if grid[check_pos.x][check_pos.y].occupied:
				return false
			if grid[check_pos.x][check_pos.y].type in ["deep_water", "shallow_water"]:
				return false
	
	return true

func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	"""Place a building on the grid"""
	var building = GameData.get_building_by_id(building_id)
	if building.is_empty():
		return false
	
	var size = building.size
	
	if not can_place_building(grid_pos, size):
		return false
	
	# Mark tiles as occupied and store origin
	for dx in range(size.x):
		for dy in range(size.y):
			var tile_pos = grid_pos + Vector2i(dx, dy)
			grid[tile_pos.x][tile_pos.y].occupied = true
			grid[tile_pos.x][tile_pos.y].building = building_id
			grid[tile_pos.x][tile_pos.y].building_origin = grid_pos  # Store where building actually is!
	
	return true

func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	"""Get information about a specific tile"""
	if not is_valid_pos(grid_pos):
		return {}
	
	return grid[grid_pos.x][grid_pos.y].duplicate()

func highlight_tile(grid_pos: Vector2i, color: Color):
	"""Highlight a tile (for cursor preview)"""
	if grid_pos in tile_meshes:
		var tile = tile_meshes[grid_pos]
		var material = tile.material_override as StandardMaterial3D
		if material:
			material = material.duplicate()
			material.emission_enabled = true
			material.emission = color
			material.emission_energy = 0.5
			tile.material_override = material

func clear_highlight(grid_pos: Vector2i):
	"""Remove highlight from tile"""
	if grid_pos in tile_meshes:
		# Recreate original material
		var tile_data = grid[grid_pos.x][grid_pos.y]
		var tile = tile_meshes[grid_pos]
		
		var material = StandardMaterial3D.new()
		if tile_data.type == "deep_water":
			material.albedo_color = Color(0.05, 0.1, 0.2)
		elif tile_data.type == "shallow_water":
			material.albedo_color = Color(0.1, 0.2, 0.3)
		elif tile_data.type == "lowland":
			material.albedo_color = Color(0.25, 0.4, 0.25)
		elif tile_data.type == "ground":
			material.albedo_color = Color(0.35, 0.35, 0.35)
		elif tile_data.type == "highland":
			material.albedo_color = Color(0.5, 0.45, 0.4)
		
		if tile_data.resource:
			var resource = GameData.get_resource_by_id(tile_data.resource)
			if resource:
				material.albedo_color = resource.color * 0.5
				material.emission_enabled = true
				material.emission = resource.color * 0.3
		
		tile.material_override = material

func clear_tile(grid_pos: Vector2i):
	"""Clear a tile - remove building and reset to ground"""
	if not is_valid_pos(grid_pos):
		return
	
	grid[grid_pos.x][grid_pos.y].occupied = false
	grid[grid_pos.x][grid_pos.y].building = ""
	grid[grid_pos.x][grid_pos.y].building_origin = null
###########################################################################
#extends Node3D
#class_name TileGrid
## TileGrid - Manages the tile-based grid for building placement
#
#const TILE_SIZE = 2.0  # Size of each tile in world units
#
#@export var grid_width: int = 50
#@export var grid_height: int = 50
#
## Grid data: grid[x][y] = {type, resource, building, etc}
#var grid: Array = []
#
## Visual tile meshes
#var tile_meshes: Dictionary = {}  # {Vector2i: MeshInstance3D}
#
## Resource deposits on this planet
#var resource_deposits: Dictionary = {}  # {Vector2i: resource_id}
#
#func _ready():
	#_initialize_grid()
	#_generate_terrain()
	#_place_resource_deposits()
	#_create_visual_grid()
#
#func _initialize_grid():
	#"""Create empty grid"""
	#grid = []
	#for x in range(grid_width):
		#var column = []
		#for y in range(grid_height):
			#column.append({
				#"type": "ground",
				#"building": null,
				#"resource": null,
				#"occupied": false
			#})
		#grid.append(column)
#
#func _generate_terrain():
	#"""Generate basic terrain variation"""
	#var noise = FastNoiseLite.new()
	#noise.seed = randi()
	#noise.frequency = 0.05
	#
	#for x in range(grid_width):
		#for y in range(grid_height):
			#var height = noise.get_noise_2d(x, y)
			#
			## Assign terrain type based on height
			#if height > 0.3:
				#grid[x][y].type = "highland"
			#elif height < -0.3:
				#grid[x][y].type = "lowland"
			#else:
				#grid[x][y].type = "ground"
#
#func _place_resource_deposits():
	#"""Place resource deposits with GUARANTEED spawning of all types"""
	#print("=== RESOURCE GENERATION START ===")
	#
	## GUARANTEED minimum counts for each resource
	#var guaranteed_deposits = {
		#"minerals": 30,    # Very common
		#"ore": 25,         # Common
		#"hydrogen": 20,    # Needed for energy!
		#"biomatter": 15,   # Needed for growth!
		#"water": 12,       # Medium
		#"crystals": 8      # Rare but guaranteed
	#}
	#
	#print("Guaranteed deposits per resource:")
	#for res_id in guaranteed_deposits:
		#print("  %s: %d clusters minimum" % [res_id, guaranteed_deposits[res_id]])
	#
	## Place each resource type with guaranteed counts
	#for resource_id in guaranteed_deposits:
		#var cluster_count = guaranteed_deposits[resource_id]
		#_place_resource_type_guaranteed(resource_id, cluster_count)
	#
	#print("=== RESOURCE GENERATION COMPLETE ===")
#
#func _place_resource_type_guaranteed(resource_id: String, cluster_count: int):
	#"""Place a specific number of clusters for a resource - GUARANTEED"""
	#var placed_clusters = 0
	#var attempts = 0
	#var max_attempts = cluster_count * 10  # Give plenty of attempts
	#
	#var cluster_size_range = [3, 4, 5, 6, 7, 8]  # Decent sized clusters
	#
	#print("Placing %s: target %d clusters" % [resource_id, cluster_count])
	#
	#while placed_clusters < cluster_count and attempts < max_attempts:
		#attempts += 1
		#
		## Pick random position (avoid center spawn area)
		#var x = randi() % grid_width
		#var y = randi() % grid_height
		#var start_pos = Vector2i(x, y)
		#
		#var center = Vector2i(grid_width / 2, grid_height / 2)
		#if start_pos.distance_to(center) < 10:
			#continue  # Too close to spawn
		#
		## Check if position is free
		#if start_pos in resource_deposits:
			#continue
		#
		## Check minimum spacing (3 tiles) from other deposits
		#var too_close = false
		#for existing_pos in resource_deposits:
			#if start_pos.distance_to(existing_pos) < 3:
				#too_close = true
				#break
		#
		#if too_close:
			#continue
		#
		## Create cluster
		#var size = cluster_size_range[randi() % cluster_size_range.size()]
		#var cluster = _grow_organic_cluster(start_pos, size)
		#
		## Place cluster
		#for tile_pos in cluster:
			#if tile_pos not in resource_deposits:
				#resource_deposits[tile_pos] = resource_id
				#grid[tile_pos.x][tile_pos.y].resource = resource_id
		#
		#placed_clusters += 1
	#
	#print("  ✓ Placed %d/%d clusters of %s (attempts: %d)" % [placed_clusters, cluster_count, resource_id, attempts])
#
#func _grow_organic_cluster(start: Vector2i, target_size: int) -> Array[Vector2i]:
	#"""Grow a natural-looking resource cluster"""
	#var cluster: Array[Vector2i] = [start]
	#var frontier: Array[Vector2i] = [start]
	#
	#var directions = [
		#Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		#Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
	#]
	#
	#while cluster.size() < target_size and frontier.size() > 0:
		## Pick random tile from frontier
		#var idx = randi() % frontier.size()
		#var current = frontier[idx]
		#
		## Try to expand
		#directions.shuffle()
		#var expanded = false
		#
		#for dir in directions:
			#var new_pos = current + dir
			#
			## Validate
			#if not is_valid_pos(new_pos):
				#continue
			#if new_pos in cluster:
				#continue
			#if new_pos in resource_deposits:
				#continue
			#
			## Add with some randomness (70% chance to keep organic shape)
			#if randf() < 0.7:
				#cluster.append(new_pos)
				#frontier.append(new_pos)
				#expanded = true
				#break
		#
		## Remove from frontier if couldn't expand or randomly
		#if not expanded or randf() < 0.4:
			#frontier.remove_at(idx)
	#
	#return cluster
#
#func _create_visual_grid():
	#"""Create visual representation of tiles"""
	#for x in range(grid_width):
		#for y in range(grid_height):
			#var pos = Vector2i(x, y)
			#var tile_mesh = _create_tile_visual(pos)
			#tile_meshes[pos] = tile_mesh
			#add_child(tile_mesh)
#
#func _create_tile_visual(grid_pos: Vector2i) -> MeshInstance3D:
	#"""Create a single tile mesh"""
	#var mesh_instance = MeshInstance3D.new()
	#var plane = PlaneMesh.new()
	#plane.size = Vector2(TILE_SIZE * 0.95, TILE_SIZE * 0.95)  # Small gap between tiles
	#mesh_instance.mesh = plane
	#
	## Position in world
	#var world_pos = grid_to_world(grid_pos)
	#mesh_instance.position = world_pos
	## Tiles are naturally horizontal planes in Godot
	#
	## Color based on terrain and resources
	#var material = StandardMaterial3D.new()
	#var tile_data = grid[grid_pos.x][grid_pos.y]
	#
	## Base color by terrain
	#if tile_data.type == "highland":
		#material.albedo_color = Color(0.4, 0.35, 0.3)
	#elif tile_data.type == "lowland":
		#material.albedo_color = Color(0.25, 0.3, 0.25)
	#else:
		#material.albedo_color = Color(0.35, 0.35, 0.35)
	#
	## Highlight if has resources
	#if tile_data.resource:
		#var resource = GameData.get_resource_by_id(tile_data.resource)
		#if resource:
			#material.albedo_color = resource.color * 0.6  # Brighter base
			#material.emission_enabled = true
			#material.emission = resource.color * 0.8  # Much brighter glow
			#material.emission_energy = 1.5  # Even more visible
	#
	#mesh_instance.material_override = material
	#
	## Store grid position for raycasting
	#mesh_instance.set_meta("grid_pos", grid_pos)
	#
	#return mesh_instance
#
#func grid_to_world(grid_pos: Vector2i) -> Vector3:
	#"""Convert grid coordinates to world position"""
	#return Vector3(
		#grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2),
		#0,
		#grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2)
	#)
#
#func world_to_grid(world_pos: Vector3) -> Vector2i:
	#"""Convert world position to grid coordinates"""
	#var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	#var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	#return Vector2i(x, y)
#
#func is_valid_pos(grid_pos: Vector2i) -> bool:
	#"""Check if grid position is within bounds"""
	#return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   #grid_pos.y >= 0 and grid_pos.y < grid_height
#
#func can_place_building(grid_pos: Vector2i, building_size: Vector2i) -> bool:
	#"""Check if a building can be placed at position"""
	## Check all tiles the building would occupy
	#for dx in range(building_size.x):
		#for dy in range(building_size.y):
			#var check_pos = grid_pos + Vector2i(dx, dy)
			#
			#if not is_valid_pos(check_pos):
				#return false
			#
			#if grid[check_pos.x][check_pos.y].occupied:
				#return false
	#
	#return true
#
#func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	#"""Place a building on the grid"""
	#var building = GameData.get_building_by_id(building_id)
	#if building.is_empty():
		#return false
	#
	#var size = building.size
	#
	#if not can_place_building(grid_pos, size):
		#return false
	#
	## Mark tiles as occupied
	#for dx in range(size.x):
		#for dy in range(size.y):
			#var tile_pos = grid_pos + Vector2i(dx, dy)
			#grid[tile_pos.x][tile_pos.y].occupied = true
			#grid[tile_pos.x][tile_pos.y].building = building_id
	#
	#return true
#
#func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	#"""Get information about a specific tile"""
	#if not is_valid_pos(grid_pos):
		#return {}
	#
	#return grid[grid_pos.x][grid_pos.y].duplicate()
#
#func highlight_tile(grid_pos: Vector2i, color: Color):
	#"""Highlight a tile (for cursor preview)"""
	#if grid_pos in tile_meshes:
		#var tile = tile_meshes[grid_pos]
		#var material = tile.material_override as StandardMaterial3D
		#if material:
			#material = material.duplicate()
			#material.emission_enabled = true
			#material.emission = color
			#material.emission_energy = 0.5
			#tile.material_override = material
#
#func clear_highlight(grid_pos: Vector2i):
	#"""Remove highlight from tile"""
	#if grid_pos in tile_meshes:
		## Recreate original material
		#var tile_data = grid[grid_pos.x][grid_pos.y]
		#var tile = tile_meshes[grid_pos]
		#
		#var material = StandardMaterial3D.new()
		#if tile_data.type == "highland":
			#material.albedo_color = Color(0.4, 0.35, 0.3)
		#elif tile_data.type == "lowland":
			#material.albedo_color = Color(0.25, 0.3, 0.25)
		#else:
			#material.albedo_color = Color(0.35, 0.35, 0.35)
		#
		#if tile_data.resource:
			#var resource = GameData.get_resource_by_id(tile_data.resource)
			#if resource:
				#material.albedo_color = resource.color * 0.5
				#material.emission_enabled = true
				#material.emission = resource.color * 0.3
		#
		#tile.material_override = material
