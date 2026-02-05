extends Node3D
class_name TileGridVar2

const TILE_SIZE := 2.0
const CHUNK_SIZE := 16

# Tile subdivision: each tile is split into SUB x SUB quads for smooth slopes
const TILE_SUBDIVISIONS := 3

@export var grid_width := 256
@export var grid_height := 256

var grid: Array = []
var resource_deposits: Dictionary = {}
var chunk_meshes: Dictionary = {}
var corner_grid: Array = []

# Height grid: stores world-Y at each corner (grid_width+1 x grid_height+1)
var height_grid: Array = []

# Terrain noise layers
var height_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var temperature_noise: FastNoiseLite
var ridge_noise: FastNoiseLite

# =========================
# 3D TERRAIN HEIGHT CONFIG
# =========================

# Discrete height levels per terrain type (world-Y units)
const TERRAIN_HEIGHT := {
	"deep_water": -3.0,
	"shallow_water": -1.5,
	"beach": 0.0,
	"marsh": 0.3,
	"lowland": 1.5,
	"grassland": 1.5,
	"forest": 2.0,
	"ground": 3.0,
	"highland": 5.0,
	"mountain": 7.0
}

# How much continuous height variation to blend in (0 = pure discrete, 1 = pure continuous)
const HEIGHT_BLEND_FACTOR := 0.3

# Water surface Y level (slightly below beach)
const WATER_LEVEL := -0.2

# =========================
# RESOURCE DEFINITIONS
# =========================

const RESOURCE_CONFIGS := {
	"minerals": {
		"count": 50,
		"min_size": 3,
		"max_size": 8,
		"allowed_types": ["ground", "highland", "mountain"],
		"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		"shape": "blob",
		"min_distance_from_water": 2
	},
	"biomatter": {
		"count": 50,
		"min_size": 3,
		"max_size": 8,
		"allowed_types": ["ground", "highland", "mountain"],
		"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		"shape": "blob",
		"min_distance_from_water": 2
	},
	"hydrogen": {
		"count": 50,
		"min_size": 3,
		"max_size": 8,
		"allowed_types": ["ground", "highland", "mountain"],
		"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		"shape": "blob",
		"min_distance_from_water": 2
	},
	"crystals": {
		"count": 25,
		"min_size": 1,
		"max_size": 4,
		"allowed_types": ["ground", "highland", "mountain"],
		"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		"shape": "blob",
		"min_distance_from_water": 2
	},
	"wood": {
		"count": 150,
		"min_size": 10,
		"max_size": 30,
		"allowed_types": ["lowland", "forest"],
		"forbidden_types": ["deep_water", "shallow_water", "beach", "highland", "mountain"],
		"shape": "blob",
		"min_distance_from_water": 3,
		"prefer_near_rivers": true
	},
	"ore": {
		"count": 40,
		"min_size": 4,
		"max_size": 10,
		"allowed_types": ["highland", "mountain"],
		"forbidden_types": ["deep_water", "shallow_water", "beach", "lowland"],
		"shape": "vein",
		"min_distance_from_water": 0
	},
	"rare_minerals": {
		"count": 10,
		"min_size": 4,
		"max_size": 10,
		"allowed_types": ["highland", "mountain"],
		"forbidden_types": ["deep_water", "shallow_water", "beach", "lowland"],
		"shape": "vein",
		"min_distance_from_water": 0
	}
}

# =========================
# TERRAIN AUTOTILING CONFIG
# =========================

const TERRAIN_PRIORITY := {
	"deep_water": 100,
	"shallow_water": 90,
	"beach": 80,
	"marsh": 70,
	"grassland": 60,
	"lowland": 60,
	"forest": 50,
	"ground": 40,
	"highland": 30,
	"mountain": 20
}

const ATLAS_CONFIG := {
	"deep_water": { "row": 0, "variations": 16 },
	"shallow_water": { "row": 1, "variations": 16 },
	"beach": { "row": 2, "variations": 16 },
	"marsh": { "row": 3, "variations": 16 },
	"grassland": { "row": 4, "variations": 16 },
	"lowland": { "row": 4, "variations": 16 },
	"forest": { "row": 5, "variations": 16 },
	"ground": { "row": 6, "variations": 16 },
	"highland": { "row": 7, "variations": 16 },
	"mountain": { "row": 8, "variations": 16 }
}

const MASK_ROW := 9

const ATLAS_TILE_SIZE := 16
const ATLAS_TILES_PER_ROW := 16
@export var terrain_atlas: Texture2D
@export var cliff_texture: Texture2D
const TERRAIN_SHADER_3D := preload("res://shaders/terrain_blend_3d.gdshader")

# =========================
# LIFECYCLE
# =========================

func _ready():
	_initialize_grid()
	_setup_noise()
	_generate_terrain()
	_assign_terrain_types()

	_smooth_terrain()

	_place_major_rivers()
	_add_beaches()
	_build_corner_grid()
	_build_height_grid()
	_place_resource_deposits()
	_create_visual_grid()

# =========================
# HEIGHT GRID
# =========================

func _build_height_grid():
	"""Build corner height grid (grid_width+1 x grid_height+1).
	Each corner averages the terrain heights of surrounding tiles."""
	height_grid.clear()
	height_grid.resize(grid_width + 1)

	for cx in range(grid_width + 1):
		height_grid[cx] = []
		for cy in range(grid_height + 1):
			height_grid[cx].append(_compute_corner_height(cx, cy))

func _compute_corner_height(cx: int, cy: int) -> float:
	"""Average the discrete terrain height of up to 4 tiles sharing this corner.
	Also blends in a fraction of the raw continuous height for natural variation."""
	var total_discrete := 0.0
	var total_continuous := 0.0
	var count := 0

	for dx in [-1, 0]:
		for dy in [-1, 0]:
			var tx = cx + dx
			var ty = cy + dy
			if tx < 0 or ty < 0 or tx >= grid_width or ty >= grid_height:
				continue

			var tile = grid[tx][ty]
			var terrain_type: String = tile["type"]
			var discrete_h: float = TERRAIN_HEIGHT.get(terrain_type, 0.0)
			var continuous_h: float = tile["height"]

			total_discrete += discrete_h
			# Map continuous height (-0.5..1.2) into a similar range as discrete
			total_continuous += continuous_h * 5.0
			count += 1

	if count == 0:
		return 0.0

	var avg_discrete = total_discrete / count
	var avg_continuous = total_continuous / count

	# Blend discrete levels with continuous variation
	return lerp(avg_discrete, avg_continuous, HEIGHT_BLEND_FACTOR)

func get_height_at_corner(cx: int, cy: int) -> float:
	"""Public accessor for height at a corner position."""
	cx = clampi(cx, 0, grid_width)
	cy = clampi(cy, 0, grid_height)
	return height_grid[cx][cy]

func get_height_at_world(world_x: float, world_z: float) -> float:
	"""Get interpolated terrain height at an arbitrary world XZ position.
	Uses bilinear interpolation of the corner height grid."""
	# Convert world to fractional grid position
	var fx = (world_x + (grid_width * TILE_SIZE / 2.0)) / TILE_SIZE
	var fz = (world_z + (grid_height * TILE_SIZE / 2.0)) / TILE_SIZE

	# Clamp to valid range
	fx = clampf(fx, 0.0, float(grid_width))
	fz = clampf(fz, 0.0, float(grid_height))

	# Get the 4 surrounding corner indices
	var ix := int(fx)
	var iy := int(fz)
	ix = clampi(ix, 0, grid_width - 1)
	iy = clampi(iy, 0, grid_height - 1)

	# Fractional position within the cell
	var u = fx - float(ix)
	var v = fz - float(iy)

	# Bilinear interpolation of 4 corner heights
	var h00 = height_grid[ix][iy]
	var h10 = height_grid[ix + 1][iy]
	var h01 = height_grid[ix][iy + 1]
	var h11 = height_grid[ix + 1][iy + 1]

	var h_top = lerp(h00, h10, u)
	var h_bot = lerp(h01, h11, u)
	return lerp(h_top, h_bot, v)

# =========================
# GRID SETUP
# =========================

func _build_corner_grid():
	corner_grid.clear()
	corner_grid.resize(grid_width + 1)

	for x in range(grid_width + 1):
		corner_grid[x] = []
		for y in range(grid_height + 1):
			corner_grid[x].append(_resolve_corner_type(x, y))

func _resolve_corner_type(cx: int, cy: int) -> String:
	var best_type := ""
	var best_priority := -INF

	for dx in [-1, 0]:
		for dy in [-1, 0]:
			var tx = cx + dx
			var ty = cy + dy
			if tx < 0 or ty < 0 or tx >= grid_width or ty >= grid_height:
				continue

			var t = grid[tx][ty]["type"]
			var p = TERRAIN_PRIORITY.get(t, 0)

			if p > best_priority:
				best_priority = p
				best_type = t

	return best_type

func _initialize_grid():
	grid.clear()
	for x in range(grid_width):
		var column := []
		for y in range(grid_height):
			column.append({
				"type": "ground",
				"height": 0.0,
				"moisture": 0.0,
				"temperature": 0.0,
				"resource": null,
				"occupied": false,
				"building": null,
				"building_origin": null,
				"is_river": false
			})
		grid.append(column)

func _setup_noise():
	height_noise = FastNoiseLite.new()
	height_noise.seed = randi()
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	height_noise.frequency = 0.012
	height_noise.fractal_octaves = 5
	height_noise.fractal_gain = 0.5
	height_noise.fractal_lacunarity = 2.0

	ridge_noise = FastNoiseLite.new()
	ridge_noise.seed = randi()
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge_noise.frequency = 0.008
	ridge_noise.fractal_octaves = 3
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = randi()
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.02
	moisture_noise.fractal_octaves = 3

	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = randi()
	temperature_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	temperature_noise.frequency = 0.008
	temperature_noise.fractal_octaves = 2

# =========================
# TERRAIN
# =========================

func _generate_terrain():
	var center := Vector2(grid_width / 2.0, grid_height / 2.0)
	var max_dist := center.length()

	for x in range(grid_width):
		for y in range(grid_height):
			var h := height_noise.get_noise_2d(x, y)
			h *= 1.25

			var ridge := ridge_noise.get_noise_2d(x, y)
			ridge = abs(ridge)
			ridge = 1.0 - ridge
			ridge = pow(ridge, 2.0)

			if h > 0.4:
				var ridge_blend = (h - 0.4) / 0.6
				h = lerp(h, h + ridge * 0.4, ridge_blend)

			var dist := Vector2(x, y).distance_to(center) / max_dist
			var falloff = pow(dist, 2.2)
			h -= falloff * 0.5

			var moisture := moisture_noise.get_noise_2d(x, y)
			var temp := temperature_noise.get_noise_2d(x, y)

			grid[x][y]["height"] = h
			grid[x][y]["moisture"] = moisture
			grid[x][y]["temperature"] = temp

func _assign_terrain_types():
	var height_stats = {"min": INF, "max": -INF}

	for x in range(grid_width):
		for y in range(grid_height):
			var h: float = grid[x][y]["height"]
			var moisture: float = grid[x][y]["moisture"]

			height_stats["min"] = min(height_stats["min"], h)
			height_stats["max"] = max(height_stats["max"], h)

			if h < -0.40:
				grid[x][y]["type"] = "deep_water"
			elif h < -0.15:
				grid[x][y]["type"] = "shallow_water"
			elif h < 0.0:
				grid[x][y]["type"] = "beach"
			elif h < 0.30:
				if moisture > 0.3:
					grid[x][y]["type"] = "forest"
				elif moisture < -0.2:
					grid[x][y]["type"] = "grassland"
				else:
					grid[x][y]["type"] = "lowland"
			elif h < 0.60:
				if moisture > 0.4:
					grid[x][y]["type"] = "forest"
				else:
					grid[x][y]["type"] = "ground"
			elif h < 0.75:
				grid[x][y]["type"] = "highland"
			else:
				grid[x][y]["type"] = "mountain"

	print("Height range: %.3f to %.3f" % [height_stats["min"], height_stats["max"]])

func _add_beaches():
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y]["type"] in ["deep_water", "shallow_water"]:
				continue

			var near_water = false
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var check_pos = Vector2i(x + dx, y + dy)
					if is_valid_pos(check_pos):
						if grid[check_pos.x][check_pos.y]["type"] in ["shallow_water", "deep_water"]:
							near_water = true
							break
				if near_water:
					break

			if near_water and grid[x][y]["height"] < 0.15:
				grid[x][y]["type"] = "beach"

func _smooth_terrain():
	var changes := []

	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			var tile_type = grid[x][y]["type"]
			var neighbors = _get_neighbor_types(Vector2i(x, y))

			var same_count = 0
			for neighbor_type in neighbors:
				if neighbor_type == tile_type:
					same_count += 1

			if same_count < 2:
				var most_common = _get_most_common_type(neighbors)
				if most_common != tile_type:
					changes.append({"pos": Vector2i(x, y), "type": most_common})

	for change in changes:
		grid[change.pos.x][change.pos.y]["type"] = change.type

# =========================
# MAJOR RIVER GENERATION
# =========================

func _place_major_rivers():
	print("=== GENERATING MAJOR RIVERS ===")

	var target_water_tiles = 500
	var current_water_tiles = 0
	var river_count = 0
	var max_rivers = 12
	var attempts = 0
	var max_attempts = 100

	while river_count < max_rivers and attempts < max_attempts:
		attempts += 1

		var start = _find_random_high_point()
		if start == Vector2i(-1, -1):
			continue

		var end = _find_nearest_ocean(start)
		if end == Vector2i(-1, -1):
			continue

		var river_path = _find_river_path_astar(start, end)

		var min_length = 20 if river_count < 4 else 15

		if river_path.size() >= min_length:
			var tiles_added = _carve_river(river_path)
			current_water_tiles += tiles_added
			river_count += 1
			print("River %d: %d tiles long (%d water tiles total)" % [river_count, river_path.size(), current_water_tiles])

	print("Total rivers created: %d" % river_count)
	print("Water tiles from rivers: %d" % current_water_tiles)

	if current_water_tiles < target_water_tiles:
		var needed = target_water_tiles - current_water_tiles
		print("Need %d more water tiles - generating lakes..." % needed)
		var lakes_added = _generate_lakes(needed)
		current_water_tiles += lakes_added
		print("Added %d lake tiles (total water: %d)" % [lakes_added, current_water_tiles])

	print("=== WATER GENERATION COMPLETE: %d tiles ===" % current_water_tiles)

func _find_random_high_point() -> Vector2i:
	var high_points := []
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y]["type"] in ["mountain", "highland"] and not grid[x][y]["is_river"]:
				high_points.append(Vector2i(x, y))
	if high_points.is_empty():
		return Vector2i(-1, -1)
	return high_points.pick_random()

func _find_nearest_ocean(start: Vector2i) -> Vector2i:
	var min_dist = INF
	var best = Vector2i(-1, -1)
	var edge_points := []

	for x in range(grid_width):
		edge_points.append(Vector2i(x, 0))
		edge_points.append(Vector2i(x, grid_height - 1))
	for y in range(grid_height):
		edge_points.append(Vector2i(0, y))
		edge_points.append(Vector2i(grid_width - 1, y))

	for point in edge_points:
		if grid[point.x][point.y]["type"] in ["deep_water", "shallow_water"]:
			var dist = start.distance_to(point)
			if dist < min_dist:
				min_dist = dist
				best = point

	if best == Vector2i(-1, -1):
		for i in range(500):
			var x = randi_range(0, grid_width - 1)
			var y = randi_range(0, grid_height - 1)
			if grid[x][y]["type"] in ["deep_water", "shallow_water"]:
				var dist = start.distance_to(Vector2i(x, y))
				if dist < min_dist:
					min_dist = dist
					best = Vector2i(x, y)

	return best

func _find_river_path_astar(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var open_set := [start]
	var came_from := {}
	var g_score := {start: 0.0}
	var f_score := {start: start.distance_to(goal)}

	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1)
	]

	var iterations = 0
	var max_iterations = 10000

	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1

		var current = open_set[0]
		var lowest_f = f_score.get(current, INF)
		for node in open_set:
			var f = f_score.get(node, INF)
			if f < lowest_f:
				lowest_f = f
				current = node

		if grid[current.x][current.y]["type"] in ["shallow_water", "deep_water"]:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for d in dirs:
			var neighbor = current + d
			if not is_valid_pos(neighbor):
				continue

			var current_height = grid[current.x][current.y]["height"]
			var neighbor_height = grid[neighbor.x][neighbor.y]["height"]
			var height_diff = current_height - neighbor_height

			var cost = 1.0
			if height_diff > 0.1:
				cost = 0.3
			elif height_diff > 0.05:
				cost = 0.6
			elif height_diff > 0.01:
				cost = 0.9
			elif height_diff > -0.02:
				cost = 1.5
			elif height_diff > -0.05:
				cost = 3.0
			else:
				cost = 10.0

			if grid[neighbor.x][neighbor.y]["is_river"]:
				cost *= 2.0

			if grid[neighbor.x][neighbor.y]["type"] in ["deep_water", "shallow_water"]:
				if neighbor.distance_to(goal) > 5:
					cost *= 0.5

			var tentative_g = g_score.get(current, INF) + cost

			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + neighbor.distance_to(goal) * 0.5

				if neighbor not in open_set:
					open_set.append(neighbor)

	return []

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while current in came_from:
		current = came_from[current]
		path.push_front(current)
	return path

func _carve_river(path: Array[Vector2i]) -> int:
	var tiles_added = 0

	for i in range(path.size()):
		var pos = path[i]
		grid[pos.x][pos.y]["is_river"] = true

		if grid[pos.x][pos.y]["type"] not in ["deep_water", "shallow_water"]:
			var river_width = 1
			var progress = float(i) / float(path.size())
			if progress > 0.7:
				river_width = 2
			elif progress > 0.5:
				river_width = 1 if randf() > 0.5 else 2

			grid[pos.x][pos.y]["type"] = "shallow_water"
			grid[pos.x][pos.y]["resource"] = "water"
			resource_deposits[pos] = "water"
			tiles_added += 1

			if river_width > 1:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var adj = pos + Vector2i(dx, dy)
						if is_valid_pos(adj) and randf() > 0.4:
							if grid[adj.x][adj.y]["type"] not in ["deep_water", "shallow_water", "mountain", "highland"]:
								if adj not in resource_deposits:
									grid[adj.x][adj.y]["type"] = "shallow_water"
									grid[adj.x][adj.y]["resource"] = "water"
									resource_deposits[adj] = "water"
									tiles_added += 1

	return tiles_added

func _generate_lakes(target_tiles: int) -> int:
	var tiles_added = 0
	var lakes_created = 0
	var attempts = 0
	var max_attempts = 200

	while tiles_added < target_tiles and attempts < max_attempts:
		attempts += 1
		var lake_center = _find_lake_location()
		if lake_center == Vector2i(-1, -1):
			continue
		var remaining = target_tiles - tiles_added
		var lake_size = clampi(randi_range(15, 40), 10, remaining + 10)
		var lake_tiles = _create_lake(lake_center, lake_size)
		if lake_tiles.size() >= 10:
			for tile in lake_tiles:
				if tile not in resource_deposits:
					grid[tile.x][tile.y]["type"] = "shallow_water"
					grid[tile.x][tile.y]["resource"] = "water"
					resource_deposits[tile] = "water"
					tiles_added += 1
			lakes_created += 1
			print("Lake %d: %d tiles" % [lakes_created, lake_tiles.size()])
	return tiles_added

func _find_lake_location() -> Vector2i:
	for attempt in range(100):
		var x = randi_range(20, grid_width - 20)
		var y = randi_range(20, grid_height - 20)
		var pos = Vector2i(x, y)
		if grid[x][y]["type"] in ["lowland", "grassland", "marsh"]:
			if grid[x][y]["height"] < 0.15:
				if pos not in resource_deposits:
					var water_nearby = _count_nearby_type(pos, ["shallow_water", "deep_water"], 5)
					if water_nearby < 3:
						return pos
	return Vector2i(-1, -1)

func _create_lake(center: Vector2i, target_size: int) -> Array[Vector2i]:
	var lake: Array[Vector2i] = [center]
	var frontier: Array[Vector2i] = [center]
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1)
	]

	var center_height = grid[center.x][center.y]["height"]

	while lake.size() < target_size and frontier.size() > 0:
		var current = frontier.pick_random()
		dirs.shuffle()
		for d in dirs:
			var np = current + d
			if not is_valid_pos(np):
				continue
			if np in lake:
				continue
			var height_diff = abs(grid[np.x][np.y]["height"] - center_height)
			if height_diff > 0.1:
				continue
			if grid[np.x][np.y]["type"] in ["mountain", "highland", "deep_water"]:
				continue
			if randf() < 0.8:
				lake.append(np)
				frontier.append(np)
				break

		if randf() < 0.2:
			frontier.erase(current)

	return lake

# =========================
# RESOURCE GENERATION
# =========================

func _place_resource_deposits():
	print("=== RESOURCE GENERATION ===")
	for res_id in RESOURCE_CONFIGS.keys():
		var cfg = RESOURCE_CONFIGS[res_id]
		_place_resource_type(
			res_id,
			cfg.count,
			cfg.min_size,
			cfg.max_size,
			cfg.allowed_types,
			cfg.get("forbidden_types", []),
			cfg.shape,
			cfg.get("min_distance_from_water", 0),
			cfg.get("prefer_near_rivers", false)
		)

func _place_resource_type(
	resource_id: String,
	cluster_count: int,
	min_size: int,
	max_size: int,
	allowed_types: Array,
	forbidden_types: Array,
	shape: String,
	min_dist_water: int,
	prefer_rivers: bool
):
	var placed := 0
	var attempts := 0
	var max_attempts := cluster_count * 50

	while placed < cluster_count and attempts < max_attempts:
		attempts += 1
		var start := Vector2i(randi() % grid_width, randi() % grid_height)
		if start in resource_deposits:
			continue
		if not grid[start.x][start.y]["type"] in allowed_types:
			continue
		if grid[start.x][start.y]["type"] in forbidden_types:
			continue
		if min_dist_water > 0:
			var water_dist = _distance_to_water(start)
			if water_dist < min_dist_water:
				continue
		if prefer_rivers:
			var water_dist = _distance_to_water(start)
			if water_dist < 3 or water_dist > 15:
				if randf() > 0.3:
					continue
		var size := randi_range(min_size, max_size)
		var cluster: Array[Vector2i] = []
		match shape:
			"blob":
				cluster = _grow_blob_cluster(start, size, allowed_types, forbidden_types)
			"vein":
				cluster = _grow_vein_cluster(start, size, allowed_types, forbidden_types)
			"river":
				continue
		if cluster.size() < min_size:
			continue

		for p in cluster:
			resource_deposits[p] = resource_id
			grid[p.x][p.y]["resource"] = resource_id

		placed += 1

	print("%s: %d/%d clusters" % [resource_id, placed, cluster_count])

# =========================
# CLUSTER SHAPES
# =========================

func _grow_blob_cluster(start: Vector2i, target: int, allowed: Array, forbidden: Array) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = [start]
	var frontier: Array[Vector2i] = [start]
	var dirs := [
		Vector2i(1,0), Vector2i(-1,0),
		Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(-1,-1),
		Vector2i(1,-1), Vector2i(-1,1)
	]

	while cluster.size() < target and frontier.size() > 0:
		var current = frontier.pick_random()
		dirs.shuffle()

		for d in dirs:
			var np: Vector2i = current + d
			if not is_valid_pos(np):
				continue
			if np in cluster:
				continue
			if not grid[np.x][np.y]["type"] in allowed:
				continue
			if grid[np.x][np.y]["type"] in forbidden:
				continue
			if randf() < 0.75:
				cluster.append(np)
				frontier.append(np)
				break

		if randf() < 0.3:
			frontier.erase(current)

	return cluster

func _grow_vein_cluster(start: Vector2i, target: int, allowed: Array, forbidden: Array) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = [start]
	var current := start
	var direction := Vector2i(
		[-1, 0, 1].pick_random(),
		[-1, 0, 1].pick_random()
	)

	var dirs := [
		Vector2i(1,0), Vector2i(-1,0),
		Vector2i(0,1), Vector2i(0,-1)
	]

	while cluster.size() < target:
		if randf() < 0.8:
			var next = current + direction
			if is_valid_pos(next) and grid[next.x][next.y]["type"] in allowed and not grid[next.x][next.y]["type"] in forbidden:
				if next not in cluster:
					cluster.append(next)
					current = next
				continue

		dirs.shuffle()
		var found = false
		for d in dirs:
			var next = current + d
			if not is_valid_pos(next):
				continue
			if next in cluster:
				continue
			if not grid[next.x][next.y]["type"] in allowed:
				continue
			if grid[next.x][next.y]["type"] in forbidden:
				continue

			cluster.append(next)
			current = next
			direction = d
			found = true
			break

		if not found:
			break

	return cluster

# =========================
# AUTOTILING FUNCTIONS
# =========================

func _corner_filled(
	corner_pos: Vector2i,
	base_type: String,
	base_priority: int
) -> bool:
	if corner_pos.x < 0 or corner_pos.y < 0 \
	or corner_pos.x > grid_width or corner_pos.y > grid_height:
		return true

	var t = corner_grid[corner_pos.x][corner_pos.y]
	var p = TERRAIN_PRIORITY.get(t, 0)

	return t == base_type or p < base_priority

func _get_autotile_index(pos: Vector2i) -> int:
	var base_type = grid[pos.x][pos.y]["type"]
	var base_priority = TERRAIN_PRIORITY[base_type]
	var mask := 0

	if _corner_filled(pos + Vector2i(0, 0), base_type, base_priority):
		mask |= 1
	if _corner_filled(pos + Vector2i(1, 0), base_type, base_priority):
		mask |= 2
	if _corner_filled(pos + Vector2i(1, 1), base_type, base_priority):
		mask |= 4
	if _corner_filled(pos + Vector2i(0, 1), base_type, base_priority):
		mask |= 8

	if mask == 5 or mask == 10:
		var center_priority := 0
		var count := 0

		for dx in [0, 1]:
			for dy in [0, 1]:
				var p = pos + Vector2i(dx, dy)
				if is_valid_pos(p):
					center_priority += TERRAIN_PRIORITY.get(grid[p.x][p.y]["type"], 0)
					count += 1

		if count > 0:
			center_priority /= count

		if center_priority < base_priority:
			mask = 15 - mask

	if mask == 15:
		return 15

	return mask

func _get_terrain_variation(pos: Vector2i, tile_type: String) -> int:
	if not tile_type in ATLAS_CONFIG:
		return 0

	var config = ATLAS_CONFIG[tile_type]
	if config["variations"] <= 0:
		return 0

	var seed_value = (pos.x * 73856093) ^ (pos.y * 19349663) ^ tile_type.hash()
	seed_value = abs(seed_value)
	var variation = seed_value % config["variations"]

	return variation

func _get_transition_terrain(pos: Vector2i, base_type: String) -> String:
	var base_priority = TERRAIN_PRIORITY.get(base_type, 0)
	var best_type := base_type
	var best_priority = base_priority

	for corner_offset in [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1)
	]:
		var corner_pos = pos + corner_offset
		if corner_pos.x < 0 or corner_pos.y < 0 \
		or corner_pos.x > grid_width or corner_pos.y > grid_height:
			continue
		var corner_type = corner_grid[corner_pos.x][corner_pos.y]
		var corner_priority = TERRAIN_PRIORITY.get(corner_type, 0)

		if corner_priority > best_priority:
			best_priority = corner_priority
			best_type = corner_type

	return best_type

func _get_tile_layer_data(pos: Vector2i) -> Dictionary:
	var base_type = grid[pos.x][pos.y]["type"]
	var transition_type = _get_transition_terrain(pos, base_type)
	var mask_index = _get_autotile_index(pos)

	if not base_type in ATLAS_CONFIG:
		return {
			"base_uv": _calculate_uv_for_tile(0, 0),
			"transition_uv": _calculate_uv_for_tile(0, 0),
			"mask_index": 15
		}

	var base_row = ATLAS_CONFIG[base_type]["row"]
	var transition_row = ATLAS_CONFIG.get(transition_type, ATLAS_CONFIG[base_type])["row"]
	var base_variation = _get_terrain_variation(pos, base_type)
	var transition_variation = _get_terrain_variation(pos, transition_type)

	return {
		"base_uv": _calculate_uv_for_tile(base_variation, base_row),
		"transition_uv": _calculate_uv_for_tile(transition_variation, transition_row),
		"mask_index": mask_index
	}

func _calculate_uv_for_tile(tile_index: int, atlas_row: int) -> Array:
	var tiles_per_row = ATLAS_TILES_PER_ROW
	var col = tile_index % tiles_per_row
	var row = atlas_row

	var tile_uv_size = 1.0 / float(tiles_per_row)

	var u_left = col * tile_uv_size
	var u_right = (col + 1) * tile_uv_size
	var v_top = row * tile_uv_size
	var v_bottom = (row + 1) * tile_uv_size

	return [
		Vector2(u_left+0.0001, v_bottom-0.0001),
		Vector2(u_right-0.0001, v_bottom-0.0001),
		Vector2(u_right-0.0001, v_top+0.0001),
		Vector2(u_left+0.0001, v_top+0.0001),
	]

# =========================
# 3D CHUNK MESH GENERATION
# =========================

func _create_visual_grid():
	var cx := ceili(grid_width / float(CHUNK_SIZE))
	var cy := ceili(grid_height / float(CHUNK_SIZE))
	print("Creating %d chunks (3D heightmapped terrain)" % (cx * cy))

	for x in range(cx):
		for y in range(cy):
			var coord := Vector2i(x, y)
			var mesh := _create_chunk_mesh_3d(coord)
			chunk_meshes[coord] = mesh
			add_child(mesh)

func _create_chunk_mesh_3d(chunk: Vector2i) -> MeshInstance3D:
	"""Create a 3D heightmapped chunk mesh with subdivided tiles."""
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
				_add_subdivided_tile_color(st, tile_pos, color)

	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()

	if terrain_atlas:
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = TERRAIN_SHADER_3D
		shader_mat.set_shader_parameter("terrain_atlas", terrain_atlas)
		if cliff_texture:
			shader_mat.set_shader_parameter("cliff_texture", cliff_texture)
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
	"""Add a subdivided tile with height-mapped vertices.
	Each tile is split into TILE_SUBDIVISIONS x TILE_SUBDIVISIONS quads.
	Heights are bilinearly interpolated from the 4 corner heights."""
	var world_center = grid_to_world(tile_pos)
	var h := TILE_SIZE * 0.5
	var mask_encoded := Color(mask_index / 16.0, 0.0, 0.0, 1.0)

	# Get the 4 corner heights for this tile
	var h00 = get_height_at_corner(tile_pos.x, tile_pos.y)       # top-left
	var h10 = get_height_at_corner(tile_pos.x + 1, tile_pos.y)   # top-right
	var h01 = get_height_at_corner(tile_pos.x, tile_pos.y + 1)   # bottom-left
	var h11 = get_height_at_corner(tile_pos.x + 1, tile_pos.y + 1) # bottom-right

	var n = TILE_SUBDIVISIONS

	for sx in range(n):
		for sy in range(n):
			# Fractional positions within the tile [0..1]
			var u0 = float(sx) / float(n)
			var u1 = float(sx + 1) / float(n)
			var v0 = float(sy) / float(n)
			var v1 = float(sy + 1) / float(n)

			# World positions for the 4 sub-quad corners
			var x0 = world_center.x - h + u0 * TILE_SIZE
			var x1 = world_center.x - h + u1 * TILE_SIZE
			var z0 = world_center.z - h + v0 * TILE_SIZE
			var z1 = world_center.z - h + v1 * TILE_SIZE

			# Bilinear interpolation of heights at each sub-vertex
			var y00 = _bilerp(h00, h10, h01, h11, u0, v0)
			var y10 = _bilerp(h00, h10, h01, h11, u1, v0)
			var y01 = _bilerp(h00, h10, h01, h11, u0, v1)
			var y11 = _bilerp(h00, h10, h01, h11, u1, v1)

			var sv0 = Vector3(x0, y00, z0)  # top-left
			var sv1 = Vector3(x1, y10, z0)  # top-right
			var sv2 = Vector3(x1, y11, z1)  # bottom-right
			var sv3 = Vector3(x0, y01, z1)  # bottom-left

			# Interpolate UVs for this sub-quad
			var buv0 = _lerp_uv(base_uv, u0, v0)
			var buv1 = _lerp_uv(base_uv, u1, v0)
			var buv2 = _lerp_uv(base_uv, u1, v1)
			var buv3 = _lerp_uv(base_uv, u0, v1)

			var tuv0 = _lerp_uv(transition_uv, u0, v0)
			var tuv1 = _lerp_uv(transition_uv, u1, v0)
			var tuv2 = _lerp_uv(transition_uv, u1, v1)
			var tuv3 = _lerp_uv(transition_uv, u0, v1)

			# Triangle 1: sv0, sv1, sv2
			st.set_color(mask_encoded)
			st.set_uv(buv0)
			st.set_uv2(tuv0)
			st.add_vertex(sv0)
			st.set_color(mask_encoded)
			st.set_uv(buv1)
			st.set_uv2(tuv1)
			st.add_vertex(sv1)
			st.set_color(mask_encoded)
			st.set_uv(buv2)
			st.set_uv2(tuv2)
			st.add_vertex(sv2)

			# Triangle 2: sv0, sv2, sv3
			st.set_color(mask_encoded)
			st.set_uv(buv0)
			st.set_uv2(tuv0)
			st.add_vertex(sv0)
			st.set_color(mask_encoded)
			st.set_uv(buv2)
			st.set_uv2(tuv2)
			st.add_vertex(sv2)
			st.set_color(mask_encoded)
			st.set_uv(buv3)
			st.set_uv2(tuv3)
			st.add_vertex(sv3)

func _add_subdivided_tile_color(st: SurfaceTool, tile_pos: Vector2i, color: Color):
	"""Fallback: subdivided tile with vertex colors (no atlas)."""
	var world_center = grid_to_world(tile_pos)
	var h := TILE_SIZE * 0.5

	var h00 = get_height_at_corner(tile_pos.x, tile_pos.y)
	var h10 = get_height_at_corner(tile_pos.x + 1, tile_pos.y)
	var h01 = get_height_at_corner(tile_pos.x, tile_pos.y + 1)
	var h11 = get_height_at_corner(tile_pos.x + 1, tile_pos.y + 1)

	var n = TILE_SUBDIVISIONS

	for sx in range(n):
		for sy in range(n):
			var u0 = float(sx) / float(n)
			var u1 = float(sx + 1) / float(n)
			var v0 = float(sy) / float(n)
			var v1 = float(sy + 1) / float(n)

			var x0 = world_center.x - h + u0 * TILE_SIZE
			var x1 = world_center.x - h + u1 * TILE_SIZE
			var z0 = world_center.z - h + v0 * TILE_SIZE
			var z1 = world_center.z - h + v1 * TILE_SIZE

			var y00 = _bilerp(h00, h10, h01, h11, u0, v0)
			var y10 = _bilerp(h00, h10, h01, h11, u1, v0)
			var y01 = _bilerp(h00, h10, h01, h11, u0, v1)
			var y11 = _bilerp(h00, h10, h01, h11, u1, v1)

			st.set_color(color)
			st.add_vertex(Vector3(x0, y00, z0))
			st.add_vertex(Vector3(x1, y10, z0))
			st.add_vertex(Vector3(x1, y11, z1))
			st.set_color(color)
			st.add_vertex(Vector3(x0, y00, z0))
			st.add_vertex(Vector3(x1, y11, z1))
			st.add_vertex(Vector3(x0, y01, z1))

func _bilerp(v00: float, v10: float, v01: float, v11: float, u: float, v: float) -> float:
	"""Bilinear interpolation of 4 corner values at fractional position (u, v)."""
	var top = lerp(v00, v10, u)
	var bot = lerp(v01, v11, u)
	return lerp(top, bot, v)

func _lerp_uv(uv_corners: Array, u: float, v: float) -> Vector2:
	"""Bilinear interpolation of UV coordinates.
	uv_corners = [top_left, top_right, bottom_right, bottom_left]"""
	var tl: Vector2 = uv_corners[0]
	var tr: Vector2 = uv_corners[1]
	var br: Vector2 = uv_corners[2]
	var bl: Vector2 = uv_corners[3]

	var top = tl.lerp(tr, u)
	var bot = bl.lerp(br, u)
	return top.lerp(bot, v)

func _get_tile_color(tile: Dictionary) -> Color:
	if tile["resource"]:
		if has_node("/root/GameData"):
			var res = GameData.get_resource_by_id(tile["resource"])
			if res:
				return res.color
		else:
			match tile["resource"]:
				"minerals": return Color(0.6, 0.6, 0.7)
				"biomatter": return Color(0.4, 0.6, 0.3)
				"hydrogen": return Color(0.7, 0.8, 0.9)
				"crystals": return Color(0.8, 0.6, 0.9)
				"wood": return Color(0.15, 0.45, 0.15)
				"ore": return Color(0.7, 0.5, 0.3)
				"rare_minerals": return Color(0.9, 0.7, 0.3)
				"water": return Color(0.2, 0.4, 0.8)

	match tile["type"]:
		"deep_water": return Color(0.05, 0.1, 0.25)
		"shallow_water": return Color(0.1, 0.25, 0.4)
		"beach": return Color(0.8, 0.75, 0.6)
		"marsh": return Color(0.2, 0.3, 0.25)
		"lowland": return Color(0.3, 0.5, 0.3)
		"grassland": return Color(0.4, 0.55, 0.3)
		"forest": return Color(0.2, 0.4, 0.2)
		"ground": return Color(0.4, 0.4, 0.35)
		"highland": return Color(0.5, 0.45, 0.4)
		"mountain": return Color(0.55, 0.5, 0.45)

	return Color.GRAY

# =========================
# COORDINATE UTILS
# =========================

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	"""Convert grid position to world position, including terrain height."""
	var wx = grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2
	var wz = grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2

	# Return height at tile center (average of 4 corners)
	var wy := 0.0
	if height_grid.size() > 0:
		var h00 = get_height_at_corner(grid_pos.x, grid_pos.y)
		var h10 = get_height_at_corner(grid_pos.x + 1, grid_pos.y)
		var h01 = get_height_at_corner(grid_pos.x, grid_pos.y + 1)
		var h11 = get_height_at_corner(grid_pos.x + 1, grid_pos.y + 1)
		wy = (h00 + h10 + h01 + h11) * 0.25

	return Vector3(wx, wy, wz)

func grid_to_world_flat(grid_pos: Vector2i) -> Vector3:
	"""Convert grid position to world position at Y=0 (for compatibility)."""
	return Vector3(
		grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		0,
		grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	return Vector2i(x, y)

func is_valid_pos(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   grid_pos.y >= 0 and grid_pos.y < grid_height

func _distance_to_water(pos: Vector2i) -> int:
	var max_check = 15
	for dist in range(1, max_check + 1):
		for dx in range(-dist, dist + 1):
			for dy in range(-dist, dist + 1):
				if abs(dx) != dist and abs(dy) != dist:
					continue
				var check_pos = pos + Vector2i(dx, dy)
				if not is_valid_pos(check_pos):
					continue
				if grid[check_pos.x][check_pos.y]["type"] in ["shallow_water", "deep_water"]:
					return dist
	return max_check

func _count_nearby_type(pos: Vector2i, types: Array, radius: int) -> int:
	var count = 0
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var check_pos = pos + Vector2i(dx, dy)
			if not is_valid_pos(check_pos):
				continue
			if grid[check_pos.x][check_pos.y]["type"] in types:
				count += 1
	return count

func _get_neighbor_types(pos: Vector2i) -> Array:
	var types := []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var check_pos = pos + Vector2i(dx, dy)
			if is_valid_pos(check_pos):
				types.append(grid[check_pos.x][check_pos.y]["type"])
	return types

func _get_most_common_type(types: Array) -> String:
	var counts := {}
	for t in types:
		if t in counts:
			counts[t] += 1
		else:
			counts[t] = 1
	var most_common = ""
	var max_count = 0
	for t in counts.keys():
		if counts[t] > max_count:
			max_count = counts[t]
			most_common = t
	return most_common

# =========================
# BUILDING PLACEMENT
# =========================

func can_place_building(grid_pos: Vector2i, building_size: Vector2i, building_id: String = "") -> bool:
	var building_data = {}
	var size = building_size
	var forbidden_terrain: Array = []
	var required_terrain: Array = []
	var required_resource: Array = []

	if building_id != "":
		if has_node("/root/GameData"):
			building_data = GameData.get_building_by_id(building_id)
			if not building_data.is_empty():
				size = building_data.get("size", building_size)
				forbidden_terrain = building_data.get("forbidden_terrain", [])
				required_terrain = building_data.get("required_terrain", [])
				required_resource = building_data.get("required_resource", [])

		if forbidden_terrain.is_empty() and required_terrain.is_empty():
			forbidden_terrain = ["deep_water", "marsh"]
	else:
		forbidden_terrain = ["deep_water", "shallow_water", "marsh"]

	var has_required_terrain = required_terrain.is_empty()
	var has_required_resource = required_resource.is_empty()

	for dx in range(size.x):
		for dy in range(size.y):
			var check_pos = grid_pos + Vector2i(dx, dy)
			if not is_valid_pos(check_pos):
				return false
			var tile = grid[check_pos.x][check_pos.y]
			if tile.occupied:
				return false
			if tile.type in forbidden_terrain:
				return false
			if not required_terrain.is_empty():
				if tile.type in required_terrain:
					has_required_terrain = true
			if not required_resource.is_empty():
				if tile.get("resource") in required_resource:
					has_required_resource = true

	if not has_required_terrain:
		return false
	if not has_required_resource:
		return false
	return true

func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	if not has_node("/root/GameData"):
		return false
	var building = GameData.get_building_by_id(building_id)
	if building.is_empty():
		return false
	var size = building.size
	if not can_place_building(grid_pos, size, building_id):
		return false
	for dx in range(size.x):
		for dy in range(size.y):
			var tile_pos = grid_pos + Vector2i(dx, dy)
			grid[tile_pos.x][tile_pos.y].occupied = true
			grid[tile_pos.x][tile_pos.y].building = building_id
			grid[tile_pos.x][tile_pos.y].building_origin = grid_pos
	return true

func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	if not is_valid_pos(grid_pos):
		return {}
	return grid[grid_pos.x][grid_pos.y].duplicate()

func clear_tile(grid_pos: Vector2i):
	if not is_valid_pos(grid_pos):
		return
	grid[grid_pos.x][grid_pos.y].occupied = false
	grid[grid_pos.x][grid_pos.y].building = ""
	grid[grid_pos.x][grid_pos.y].building_origin = null
