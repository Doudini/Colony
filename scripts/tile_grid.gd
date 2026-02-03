extends Node3D
class_name TileGrid

# =========================
# CONFIG
# =========================

const TILE_SIZE := 2.0
const CHUNK_SIZE := 16

@export var grid_width := 256
@export var grid_height := 256

# =========================
# DATA
# =========================

var grid: Array = []
var resource_deposits: Dictionary = {}
var chunk_meshes: Dictionary = {}

# Terrain noise layers
var height_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var temperature_noise: FastNoiseLite
var ridge_noise: FastNoiseLite  # For mountain ridges

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
		"shape": "vein",  # New shape for minerals in mountains
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

# Terrain priority for transitions (higher = more dominant)
const TERRAIN_PRIORITY := {
	"deep_water": 100,
	"shallow_water": 90,
	"beach": 80,
	"marsh": 70,
	"grassland": 60,
	"lowland": 60,  # Same as grassland
	"forest": 50,
	"ground": 40,
	"highland": 30,
	"mountain": 20
}

# Each terrain type transitions to a higher-priority terrain
const TERRAIN_TRANSITIONS := {
	"grassland": "beach",
	"lowland": "beach",
	"forest": "grassland",
	"ground": "grassland",
	"highland": "ground",
	"mountain": "highland",
	"marsh": "shallow_water",
	"beach": "shallow_water"
}

# Texture atlas configuration
# Each terrain needs a tileset in the atlas
const ATLAS_CONFIG := {
	"beach": {
		"row": 0,
		"has_transitions": true,
		"tile_count": 16,
		"variations": 3
	},
	"grassland": {
		"row": 1,
		"has_transitions": true,
		"tile_count": 16,
		"variations": 5
	},
	"lowland": {
		"row": 1,  # Same as grassland
		"has_transitions": true,
		"tile_count": 16,
		"variations": 5
	},
	"forest": {
		"row": 2,
		"has_transitions": true,
		"tile_count": 16,
		"variations": 5
	},
	"ground": {
		"row": 3,
		"has_transitions": true,
		"tile_count": 16,
		"variations": 3
	},
	"highland": {
		"row": 4,
		"has_transitions": true,
		"tile_count": 16,
		"variations": 3
	},
	"mountain": {
		"row": 5,
		"has_transitions": true,
		"tile_count": 16,
		"variations": 3
	},
	"marsh": {
		"row": 6,
		"has_transitions": true,
		"tile_count": 16,
		"variations": 3
	},
	"shallow_water": {
		"row": 7,
		"has_transitions": false,
		"tile_count": 4,
		"variations": 2
	},
	"deep_water": {
		"row": 7,
		"has_transitions": false,
		"tile_count": 4,
		"variations": 2
	}
}

# Texture atlas settings
const ATLAS_TILE_SIZE := 128  # Size of each tile in pixels
const ATLAS_TILES_PER_ROW := 16  # 16 tiles per row (marching squares + variations)
@export var terrain_atlas: Texture2D  # Assigned in editor

# =========================
# LIFECYCLE
# =========================

func _ready():
	_initialize_grid()
	_setup_noise()
	_generate_terrain()
	_assign_terrain_types()
	_add_beaches()
	_add_marshes()
	_smooth_terrain()
	_place_major_rivers()  # New: Place long rivers first
	_place_resource_deposits()
	_create_visual_grid()

# =========================
# GRID SETUP
# =========================

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
				"is_river": false  # Track river tiles
			})
		grid.append(column)

func _setup_noise():
	# Height/elevation noise with ridged multifractal for mountains
	height_noise = FastNoiseLite.new()
	height_noise.seed = randi()
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	height_noise.frequency = 0.012
	height_noise.fractal_octaves = 5
	height_noise.fractal_gain = 0.5
	height_noise.fractal_lacunarity = 2.0
	
	# Ridge noise for mountain ranges
	ridge_noise = FastNoiseLite.new()
	ridge_noise.seed = randi()
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge_noise.frequency = 0.008  # Lower frequency for large features
	ridge_noise.fractal_octaves = 3
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	
	# Moisture noise
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = randi()
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.02
	moisture_noise.fractal_octaves = 3
	
	# Temperature noise
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
			# Base height
			var h := height_noise.get_noise_2d(x, y)
			h *= 1.25
			
			# Add ridged multifractal for mountain ridges
			var ridge := ridge_noise.get_noise_2d(x, y)
			ridge = abs(ridge)  # Create ridges
			ridge = 1.0 - ridge  # Invert so peaks are high
			ridge = pow(ridge, 2.0)  # Sharpen peaks
			
			# Blend ridge noise into height in high areas
			if h > 0.4:
				var ridge_blend = (h - 0.4) / 0.6  # 0 to 1 in high areas
				h = lerp(h, h + ridge * 0.4, ridge_blend)
			
			# Island falloff
			var dist := Vector2(x, y).distance_to(center) / max_dist
			var falloff = pow(dist, 2.2)
			h -= falloff * 0.5
			
			# Moisture and temperature
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

func _add_marshes():
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y]["type"] != "lowland":
				continue
			
			if grid[x][y]["height"] < 0.05 and grid[x][y]["moisture"] > 0.2:
				var water_nearby = _count_nearby_type(Vector2i(x, y), ["shallow_water", "deep_water"], 3)
				if water_nearby >= 2:
					grid[x][y]["type"] = "marsh"

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
	"""Generate long rivers using A* pathfinding from mountains to ocean"""
	print("=== GENERATING MAJOR RIVERS ===")
	
	var target_water_tiles = 800  # Minimum water resource tiles we want
	var current_water_tiles = 0
	
	var river_count = 0
	var max_rivers = 12  # Try more rivers
	var attempts = 0
	var max_attempts = 100  # More attempts
	
	while river_count < max_rivers and attempts < max_attempts:
		attempts += 1
		
		# Find a mountain/highland start point
		var start = _find_random_high_point()
		if start == Vector2i(-1, -1):
			continue
		
		# Find nearest ocean point
		var end = _find_nearest_ocean(start)
		if end == Vector2i(-1, -1):
			continue
		
		# Use A* to find downhill path
		var river_path = _find_river_path_astar(start, end)
		
		# Accept shorter rivers if we're struggling (but still need reasonable length)
		var min_length = 20 if river_count < 4 else 15
		
		if river_path.size() >= min_length:
			var tiles_added = _carve_river(river_path)
			current_water_tiles += tiles_added
			river_count += 1
			print("✓ River %d: %d tiles long (%d water tiles total)" % [river_count, river_path.size(), current_water_tiles])
	
	print("Total rivers created: %d" % river_count)
	print("Water tiles from rivers: %d" % current_water_tiles)
	
	# If we don't have enough water, add lakes as fallback
	if current_water_tiles < target_water_tiles:
		var needed = target_water_tiles - current_water_tiles
		print("⚠ Need %d more water tiles - generating lakes..." % needed)
		var lakes_added = _generate_lakes(needed)
		current_water_tiles += lakes_added
		print("✓ Added %d lake tiles (total water: %d)" % [lakes_added, current_water_tiles])
	
	print("=== WATER GENERATION COMPLETE: %d tiles ===" % current_water_tiles)

func _find_random_high_point() -> Vector2i:
	"""Find a random point on a mountain or highland"""
	var high_points := []
	
	# Collect all valid high points
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y]["type"] in ["mountain", "highland"] and not grid[x][y]["is_river"]:
				high_points.append(Vector2i(x, y))
	
	if high_points.is_empty():
		return Vector2i(-1, -1)
	
	return high_points.pick_random()

func _find_nearest_ocean(start: Vector2i) -> Vector2i:
	"""Find nearest ocean/deep water point"""
	var min_dist = INF
	var best = Vector2i(-1, -1)
	
	# Check all edges of map for ocean
	var edge_points := []
	
	# Top and bottom edges
	for x in range(grid_width):
		edge_points.append(Vector2i(x, 0))
		edge_points.append(Vector2i(x, grid_height - 1))
	
	# Left and right edges
	for y in range(grid_height):
		edge_points.append(Vector2i(0, y))
		edge_points.append(Vector2i(grid_width - 1, y))
	
	# Find nearest ocean point on edges
	for point in edge_points:
		if grid[point.x][point.y]["type"] in ["deep_water", "shallow_water"]:
			var dist = start.distance_to(point)
			if dist < min_dist:
				min_dist = dist
				best = point
	
	# If no ocean on edges, find any ocean
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
	"""Use A* pathfinding with downhill preference to create natural river"""
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
	var max_iterations = 10000  # Prevent infinite loops
	
	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		
		# Find node with lowest f_score
		var current = open_set[0]
		var lowest_f = f_score.get(current, INF)
		for node in open_set:
			var f = f_score.get(node, INF)
			if f < lowest_f:
				lowest_f = f
				current = node
		
		# Reached ocean
		if grid[current.x][current.y]["type"] in ["shallow_water", "deep_water"]:
			return _reconstruct_path(came_from, current)
		
		open_set.erase(current)
		
		# Check neighbors
		for d in dirs:
			var neighbor = current + d
			
			if not is_valid_pos(neighbor):
				continue
			
			# Calculate cost with strong downhill preference
			var current_height = grid[current.x][current.y]["height"]
			var neighbor_height = grid[neighbor.x][neighbor.y]["height"]
			
			var height_diff = current_height - neighbor_height
			
			# Rivers strongly prefer downhill but can handle slight uphill
			var cost = 1.0
			if height_diff > 0.1:
				cost = 0.3  # Strong downhill = very low cost
			elif height_diff > 0.05:
				cost = 0.6  # Moderate downhill
			elif height_diff > 0.01:
				cost = 0.9  # Gentle downhill
			elif height_diff > -0.02:
				cost = 1.5  # Nearly flat
			elif height_diff > -0.05:
				cost = 3.0  # Slight uphill - possible but expensive
			else:
				cost = 10.0  # Strong uphill - very expensive (but not impossible)
			
			# Avoid existing rivers
			if grid[neighbor.x][neighbor.y]["is_river"]:
				cost *= 2.0
			
			# Prefer staying on land (not going through ocean early)
			if grid[neighbor.x][neighbor.y]["type"] in ["deep_water", "shallow_water"]:
				if neighbor.distance_to(goal) > 5:  # Unless close to goal
					cost *= 0.5  # Actually prefer water when close to ocean
			
			var tentative_g = g_score.get(current, INF) + cost
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + neighbor.distance_to(goal) * 0.5  # Reduced heuristic weight
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	return []  # No path found

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	"""Reconstruct path from A* came_from dict"""
	var path: Array[Vector2i] = [current]
	
	while current in came_from:
		current = came_from[current]
		path.push_front(current)
	
	return path

func _carve_river(path: Array[Vector2i]) -> int:
	"""Carve river into terrain along path, returns number of water tiles added"""
	var tiles_added = 0
	
	for i in range(path.size()):
		var pos = path[i]
		
		# Mark as river
		grid[pos.x][pos.y]["is_river"] = true
		
		# Convert to water if not already
		if grid[pos.x][pos.y]["type"] not in ["deep_water", "shallow_water"]:
			# Rivers get wider near the end (ocean)
			var river_width = 1
			var progress = float(i) / float(path.size())
			if progress > 0.7:
				river_width = 2  # Wider near mouth
			elif progress > 0.5:
				river_width = 1 if randf() > 0.5 else 2  # Sometimes wider mid-section
			
			# Carve main river
			grid[pos.x][pos.y]["type"] = "shallow_water"
			grid[pos.x][pos.y]["resource"] = "water"
			resource_deposits[pos] = "water"
			tiles_added += 1
			
			# Widen river
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
	"""Generate lakes in low-lying areas to ensure minimum water availability"""
	print("=== GENERATING LAKES ===")
	
	var tiles_added = 0
	var lakes_created = 0
	var attempts = 0
	var max_attempts = 200
	
	while tiles_added < target_tiles and attempts < max_attempts:
		attempts += 1
		
		# Find a suitable lake location (lowland, not too high, not already water)
		var lake_center = _find_lake_location()
		if lake_center == Vector2i(-1, -1):
			continue
		
		# Determine lake size based on how much water we still need
		var remaining = target_tiles - tiles_added
		var lake_size = clampi(randi_range(15, 40), 10, remaining + 10)
		
		# Create lake using flood fill from center
		var lake_tiles = _create_lake(lake_center, lake_size)
		
		if lake_tiles.size() >= 10:  # Minimum lake size
			for tile in lake_tiles:
				if tile not in resource_deposits:
					grid[tile.x][tile.y]["type"] = "shallow_water"
					grid[tile.x][tile.y]["resource"] = "water"
					resource_deposits[tile] = "water"
					tiles_added += 1
			
			lakes_created += 1
			print("✓ Lake %d: %d tiles" % [lakes_created, lake_tiles.size()])
	
	print("Total lakes created: %d" % lakes_created)
	return tiles_added

func _find_lake_location() -> Vector2i:
	"""Find a good location for a lake (low elevation, inland)"""
	for attempt in range(100):
		var x = randi_range(20, grid_width - 20)  # Not on edges
		var y = randi_range(20, grid_height - 20)
		var pos = Vector2i(x, y)
		
		# Good lake conditions
		if grid[x][y]["type"] in ["lowland", "grassland", "marsh"]:
			if grid[x][y]["height"] < 0.15:  # Low elevation
				if pos not in resource_deposits:
					# Check not too close to existing water
					var water_nearby = _count_nearby_type(pos, ["shallow_water", "deep_water"], 5)
					if water_nearby < 3:  # Not right next to ocean/river
						return pos
	
	return Vector2i(-1, -1)

func _create_lake(center: Vector2i, target_size: int) -> Array[Vector2i]:
	"""Create a lake using flood fill, staying in low areas"""
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
			
			# Lakes prefer flat areas
			var height_diff = abs(grid[np.x][np.y]["height"] - center_height)
			if height_diff > 0.1:  # Don't climb hills
				continue
			
			# Don't flood into mountains/highlands
			if grid[np.x][np.y]["type"] in ["mountain", "highland", "deep_water"]:
				continue
			
			# Good lake tile
			if randf() < 0.8:  # 80% expansion rate
				lake.append(np)
				frontier.append(np)
				break
		
		# Sometimes remove from frontier to create more circular lakes
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
				continue  # Skip, rivers are handled separately now

		if cluster.size() < min_size:
			continue

		for p in cluster:
			resource_deposits[p] = resource_id
			grid[p.x][p.y]["resource"] = resource_id

		placed += 1

	print("✓ %s: %d/%d clusters" % [resource_id, placed, cluster_count])

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
	"""Create linear vein-like deposits (good for ore in mountains)"""
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
		# Mostly continue in same direction (80%), sometimes turn (20%)
		if randf() < 0.8:
			var next = current + direction
			if is_valid_pos(next) and grid[next.x][next.y]["type"] in allowed and not grid[next.x][next.y]["type"] in forbidden:
				if next not in cluster:
					cluster.append(next)
					current = next
				continue
		
		# Pick new direction
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
# RENDERING
# =========================

# =========================
# AUTOTILING FUNCTIONS
# =========================

func _get_autotile_index(pos: Vector2i) -> int:
	"""
	Returns the marching squares tile index (0-15) based on neighbors.
	Checks 4 cardinal directions against the transition target.
	"""
	var tile_type = grid[pos.x][pos.y]["type"]

	# If this terrain doesn't transition, use solid tile (all neighbors match)
	if not tile_type in TERRAIN_TRANSITIONS:
		# For water and other non-transitioning types, add variation
		if tile_type in ["shallow_water", "deep_water"]:
			return _get_water_variation(pos)
		return 15  # Solid tile

	var transition_to = TERRAIN_TRANSITIONS[tile_type]
	var my_priority = TERRAIN_PRIORITY.get(tile_type, 0)

	# Check 4 cardinal neighbors (N, E, S, W) for marching squares
	var neighbors = [
		Vector2i(0, -1),  # North
		Vector2i(1, 0),   # East
		Vector2i(0, 1),   # South
		Vector2i(-1, 0)   # West
	]

	var bitmask = 0
	for i in range(4):
		var check_pos = pos + neighbors[i]

		# Edge of map counts as matching (prevents edge artifacts)
		if not is_valid_pos(check_pos):
			bitmask |= (1 << (3 - i))
			continue

		var neighbor_type = grid[check_pos.x][check_pos.y]["type"]
		var neighbor_priority = TERRAIN_PRIORITY.get(neighbor_type, 0)

		# If neighbor is same type OR lower priority, we don't transition
		# If neighbor is our transition target OR higher priority, we do transition
		if neighbor_type == tile_type or neighbor_priority < my_priority:
			bitmask |= (1 << (3 - i))

	# For fully surrounded tiles (all neighbors same), add variation
	if bitmask == 15:
		return _get_tile_variation(pos, tile_type)

	return bitmask

func _get_tile_variation(pos: Vector2i, tile_type: String) -> int:
	"""
	Returns a tile index with variation for fully surrounded tiles.
	Uses position-based pseudo-random selection for consistency.
	"""
	if not tile_type in ATLAS_CONFIG:
		return 15

	var config = ATLAS_CONFIG[tile_type]
	if config["variations"] <= 0:
		return 15

	# Hash position for consistent pseudo-random variation
	var seed_value = (pos.x * 73856093) ^ (pos.y * 19349663)
	seed_value = abs(seed_value)
	var variation = seed_value % config["variations"]

	# Variation tiles start after the base 16 tiles
	return 15 + variation

func _get_water_variation(pos: Vector2i) -> int:
	"""
	Simple variation for water tiles (no transitions, just visual variety).
	"""
	var seed_value = (pos.x * 73856093) ^ (pos.y * 19349663)
	seed_value = abs(seed_value)
	return seed_value % 4  # Water has 4 simple variations

func _get_tile_uv_coords(pos: Vector2i) -> Array:
	"""
	Returns UV coordinates [top_left, top_right, bottom_right, bottom_left]
	for the tile at the given position based on its autotile index.
	"""
	var tile_type = grid[pos.x][pos.y]["type"]

	if not tile_type in ATLAS_CONFIG:
		# Fallback to a default tile
		return _calculate_uv_for_tile(0, 0)

	var config = ATLAS_CONFIG[tile_type]
	var autotile_index = _get_autotile_index(pos)
	var row = config["row"]

	return _calculate_uv_for_tile(autotile_index, row)

func _calculate_uv_for_tile(tile_index: int, atlas_row: int) -> Array:
	"""
	Calculates UV coordinates for a specific tile in the atlas.
	Atlas layout: 16 tiles per row, multiple rows for different terrains.
	Returns [top_left, top_right, bottom_right, bottom_left] UVs.
	"""
	# Calculate tile position in atlas
	var tiles_per_row = ATLAS_TILES_PER_ROW
	var col = tile_index % tiles_per_row
	var row = atlas_row

	# Assume atlas is square with tiles_per_row tiles in each direction
	var tile_uv_size = 1.0 / float(tiles_per_row)

	# Calculate UV coordinates (0,0 is top-left in UV space)
	var u_left = col * tile_uv_size
	var u_right = (col + 1) * tile_uv_size
	var v_top = row * tile_uv_size
	var v_bottom = (row + 1) * tile_uv_size

	# Return as [TL, TR, BR, BL]
	return [
		Vector2(u_left, v_top),      # Top-left
		Vector2(u_right, v_top),     # Top-right
		Vector2(u_right, v_bottom),  # Bottom-right
		Vector2(u_left, v_bottom)    # Bottom-left
	]

# =========================
# CHUNK MESH GENERATION
# =========================

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

			# Use UV mapping if texture atlas is available
			if terrain_atlas:
				var uv_coords = _get_tile_uv_coords(tile_pos)
				_add_quad_with_uv(st, grid_to_world(tile_pos), uv_coords)
			else:
				# Fallback to vertex colors if no atlas
				var color := _get_tile_color(grid[x][y])
				_add_quad_with_color(st, grid_to_world(tile_pos), color)

	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()

	var mat := StandardMaterial3D.new()

	# Use texture atlas if available
	if terrain_atlas:
		mat.albedo_texture = terrain_atlas
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Pixel art style
		mat.texture_repeat = false
	else:
		# Fallback to vertex colors
		mat.vertex_color_use_as_albedo = true

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = mat

	return mi

func _add_quad_with_uv(st: SurfaceTool, pos: Vector3, uv_coords: Array):
	"""
	Adds a quad with UV texture coordinates.
	uv_coords should be [top_left, top_right, bottom_right, bottom_left].
	"""
	var h := TILE_SIZE * 0.475
	var v0 := Vector3(pos.x - h, 0, pos.z - h)  # Top-left
	var v1 := Vector3(pos.x + h, 0, pos.z - h)  # Top-right
	var v2 := Vector3(pos.x + h, 0, pos.z + h)  # Bottom-right
	var v3 := Vector3(pos.x - h, 0, pos.z + h)  # Bottom-left

	# First triangle (v0, v1, v2)
	st.set_uv(uv_coords[0])  # Top-left UV
	st.add_vertex(v0)
	st.set_uv(uv_coords[1])  # Top-right UV
	st.add_vertex(v1)
	st.set_uv(uv_coords[2])  # Bottom-right UV
	st.add_vertex(v2)

	# Second triangle (v0, v2, v3)
	st.set_uv(uv_coords[0])  # Top-left UV
	st.add_vertex(v0)
	st.set_uv(uv_coords[2])  # Bottom-right UV
	st.add_vertex(v2)
	st.set_uv(uv_coords[3])  # Bottom-left UV
	st.add_vertex(v3)

func _add_quad_with_color(st: SurfaceTool, pos: Vector3, color: Color):
	"""
	Adds a quad with vertex color (fallback when no texture atlas is available).
	"""
	var h := TILE_SIZE * 0.475
	var v0 := Vector3(pos.x - h, 0, pos.z - h)
	var v1 := Vector3(pos.x + h, 0, pos.z - h)
	var v2 := Vector3(pos.x + h, 0, pos.z + h)
	var v3 := Vector3(pos.x - h, 0, pos.z + h)

	st.set_color(color)
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

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
# UTILS
# =========================

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

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		0,
		grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	return Vector2i(x, y)

func can_place_building(grid_pos: Vector2i, building_size: Vector2i, building_id: String = "") -> bool:
	"""Check if a building can be placed at position
	
	Args:
		grid_pos: Top-left position to place building
		building_size: Size of the building (can be omitted if building_id provided)
		building_id: ID to lookup building data for size and placement rules
	"""
	
	# Get building data if ID provided
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
		
		# Default forbidden terrain if not specified in building data
		if forbidden_terrain.is_empty() and required_terrain.is_empty():
			# Most buildings can't be placed on deep water or marsh
			forbidden_terrain = ["deep_water", "marsh"]
	else:
		# Legacy behavior: no building_id provided, use old hardcoded rules
		forbidden_terrain = ["deep_water", "shallow_water", "marsh"]
	
	# Track if we found required terrain/resource
	var has_required_terrain = required_terrain.is_empty()  # True if not required
	var has_required_resource = required_resource.is_empty()  # True if not required
	
	# Check all tiles the building would occupy
	for dx in range(size.x):
		for dy in range(size.y):
			var check_pos = grid_pos + Vector2i(dx, dy)
			
			# Out of bounds check
			if not is_valid_pos(check_pos):
				return false
			
			var tile = grid[check_pos.x][check_pos.y]
			
			# Already occupied check
			if tile.occupied:
				return false
			
			# Forbidden terrain check
			if tile.type in forbidden_terrain:
				return false
			
			# Check for required terrain
			if not required_terrain.is_empty():
				if tile.type in required_terrain:
					has_required_terrain = true
			
			# Check for required resource
			if not required_resource.is_empty():
				if tile.get("resource") in required_resource:
					has_required_resource = true
	
	# Must have found required terrain (if specified)
	if not has_required_terrain:
		return false
	
	# Must have found required resource (if specified)
	if not has_required_resource:
		return false
	
	return true

func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	"""Place a building on the grid"""
	if not has_node("/root/GameData"):
		return false
	
	var building = GameData.get_building_by_id(building_id)
	if building.is_empty():
		return false
	
	var size = building.size
	
	# Use the improved can_place_building with building_id
	if not can_place_building(grid_pos, size, building_id):
		return false
	
	# Mark tiles as occupied and store origin
	for dx in range(size.x):
		for dy in range(size.y):
			var tile_pos = grid_pos + Vector2i(dx, dy)
			grid[tile_pos.x][tile_pos.y].occupied = true
			grid[tile_pos.x][tile_pos.y].building = building_id
			grid[tile_pos.x][tile_pos.y].building_origin = grid_pos
	
	return true
	
#func can_place_building(grid_pos: Vector2i, building_size: Vector2i, building_id: String = "") -> bool:
	#"""Check if a building can be placed at position
	#
	#Args:
		#grid_pos: Top-left position to place building
		#building_size: Size of the building (can be omitted if building_id provided)
		#building_id: ID to lookup building data for size and placement rules
	#"""
	#
	## Get building data if ID provided
	#var building_data = {}
	#var size = building_size
	#var forbidden_terrain: Array = []
	#var required_terrain: Array = []
	#print(building_id)
	#if building_id != "":
		#if has_node("/root/GameData"):
			#building_data = GameData.get_building_by_id(building_id)
			#if not building_data.is_empty():
				#size = building_data.get("size", building_size)
				#forbidden_terrain = building_data.get("forbidden_terrain", [])
				#required_terrain = building_data.get("required_terrain", [])
		#
		## Default forbidden terrain if not specified in building data
		#if forbidden_terrain.is_empty() and required_terrain.is_empty():
			## Most buildings can't be placed on deep water or marsh
			#forbidden_terrain = ["deep_water", "marsh"]
	#else:
		## Legacy behavior: no building_id provided, use old hardcoded rules
		#forbidden_terrain = ["deep_water", "shallow_water", "marsh"]
	#
	## Check all tiles the building would occupy
	#for dx in range(size.x):
		#for dy in range(size.y):
			#var check_pos = grid_pos + Vector2i(dx, dy)
			#
			## Out of bounds check
			#if not is_valid_pos(check_pos):
				#return false
			#
			#var tile = grid[check_pos.x][check_pos.y]
			#
			## Already occupied check
			#if tile.occupied:
				#return false
			#
			## Required terrain check (if specified, AT LEAST ONE tile must match)
			#if not required_terrain.is_empty():
				#var has_required = false
				#for dx2 in range(size.x):
					#for dy2 in range(size.y):
						#var check_pos2 = grid_pos + Vector2i(dx2, dy2)
						#if is_valid_pos(check_pos2):
							#if grid[check_pos2.x][check_pos2.y].type in required_terrain:
								#has_required = true
								#break
					#if has_required:
						#break
				#
				#if not has_required:
					#return false
			#
			## Forbidden terrain check
			#if tile.type in forbidden_terrain:
				#return false
	#
	#return true
#
#func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	#"""Place a building on the grid"""
	#if not has_node("/root/GameData"):
		#return false
	#
	#var building = GameData.get_building_by_id(building_id)
	#if building.is_empty():
		#return false
	#
	#var size = building.size
	#
	## Use the improved can_place_building with building_id
	#if not can_place_building(grid_pos, size, building_id):
		#return false
	#
	## Mark tiles as occupied and store origin
	#for dx in range(size.x):
		#for dy in range(size.y):
			#var tile_pos = grid_pos + Vector2i(dx, dy)
			#grid[tile_pos.x][tile_pos.y].occupied = true
			#grid[tile_pos.x][tile_pos.y].building = building_id
			#grid[tile_pos.x][tile_pos.y].building_origin = grid_pos
	#
	#return true

func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	if not is_valid_pos(grid_pos):
		return {}
	
	return grid[grid_pos.x][grid_pos.y].duplicate()
func clear_tile(grid_pos: Vector2i):
	"""Clear a tile - remove building and reset to ground"""
	if not is_valid_pos(grid_pos):
		return
	
	grid[grid_pos.x][grid_pos.y].occupied = false
	grid[grid_pos.x][grid_pos.y].building = ""
	grid[grid_pos.x][grid_pos.y].building_origin = null

##extends Node3D
##class_name TileGrid
##
### =========================
### CONFIG
### =========================
##
##const TILE_SIZE := 2.0
##const CHUNK_SIZE := 16
##
##@export var grid_width := 256
##@export var grid_height := 256
##
### =========================
### DATA
### =========================
##
##var grid: Array = []
##var resource_deposits: Dictionary = {}
##var chunk_meshes: Dictionary = {}
##
### Terrain noise layers
##var height_noise: FastNoiseLite
##var moisture_noise: FastNoiseLite
##var temperature_noise: FastNoiseLite
##var ridge_noise: FastNoiseLite  # For mountain ridges
##
### =========================
### RESOURCE DEFINITIONS
### =========================
##
##const RESOURCE_CONFIGS := {
	##"minerals": {
		##"count": 50,
		##"min_size": 3,
		##"max_size": 8,
		##"allowed_types": ["ground", "highland", "mountain"],
		##"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		##"shape": "blob",
		##"min_distance_from_water": 2
	##},
	##"biomatter": {
		##"count": 50,
		##"min_size": 3,
		##"max_size": 8,
		##"allowed_types": ["ground", "highland", "mountain"],
		##"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		##"shape": "blob",
		##"min_distance_from_water": 2
	##},
	##"hydrogen": {
		##"count": 50,
		##"min_size": 3,
		##"max_size": 8,
		##"allowed_types": ["ground", "highland", "mountain"],
		##"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		##"shape": "blob",
		##"min_distance_from_water": 2
	##},
	##"crystals": {
		##"count": 25,
		##"min_size": 1,
		##"max_size": 4,
		##"allowed_types": ["ground", "highland", "mountain"],
		##"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		##"shape": "blob",
		##"min_distance_from_water": 2
	##},
	##"wood": {
		##"count": 150,
		##"min_size": 10,
		##"max_size": 30,
		##"allowed_types": ["lowland", "forest"],
		##"forbidden_types": ["deep_water", "shallow_water", "beach", "highland", "mountain"],
		##"shape": "blob",
		##"min_distance_from_water": 3,
		##"prefer_near_rivers": true
	##},
	##"ore": {
		##"count": 40,
		##"min_size": 4,
		##"max_size": 10,
		##"allowed_types": ["highland", "mountain"],
		##"forbidden_types": ["deep_water", "shallow_water", "beach", "lowland"],
		##"shape": "vein",  # New shape for minerals in mountains
		##"min_distance_from_water": 0
	##},
	##"rare_minerals": {
		##"count": 10,
		##"min_size": 4,
		##"max_size": 10,
		##"allowed_types": ["highland", "mountain"],
		##"forbidden_types": ["deep_water", "shallow_water", "beach", "lowland"],
		##"shape": "vein",
		##"min_distance_from_water": 0
	##}
##}
##
### =========================
### LIFECYCLE
### =========================
##
##func _ready():
	##_initialize_grid()
	##_setup_noise()
	##_generate_terrain()
	##_assign_terrain_types()
	##_add_beaches()
	##_add_marshes()
	##_smooth_terrain()
	##_place_major_rivers()  # New: Place long rivers first
	##_place_resource_deposits()
	##_create_visual_grid()
##
### =========================
### GRID SETUP
### =========================
##
##func _initialize_grid():
	##grid.clear()
	##for x in range(grid_width):
		##var column := []
		##for y in range(grid_height):
			##column.append({
				##"type": "ground",
				##"height": 0.0,
				##"moisture": 0.0,
				##"temperature": 0.0,
				##"resource": null,
				##"occupied": false,
				##"building": null,
				##"building_origin": null,
				##"is_river": false  # Track river tiles
			##})
		##grid.append(column)
##
##func _setup_noise():
	### Height/elevation noise with ridged multifractal for mountains
	##height_noise = FastNoiseLite.new()
	##height_noise.seed = randi()
	##height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	##height_noise.frequency = 0.012
	##height_noise.fractal_octaves = 5
	##height_noise.fractal_gain = 0.5
	##height_noise.fractal_lacunarity = 2.0
	##
	### Ridge noise for mountain ranges
	##ridge_noise = FastNoiseLite.new()
	##ridge_noise.seed = randi()
	##ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	##ridge_noise.frequency = 0.008  # Lower frequency for large features
	##ridge_noise.fractal_octaves = 3
	##ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	##
	### Moisture noise
	##moisture_noise = FastNoiseLite.new()
	##moisture_noise.seed = randi()
	##moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	##moisture_noise.frequency = 0.02
	##moisture_noise.fractal_octaves = 3
	##
	### Temperature noise
	##temperature_noise = FastNoiseLite.new()
	##temperature_noise.seed = randi()
	##temperature_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	##temperature_noise.frequency = 0.008
	##temperature_noise.fractal_octaves = 2
##
### =========================
### TERRAIN
### =========================
##
##func _generate_terrain():
	##var center := Vector2(grid_width / 2.0, grid_height / 2.0)
	##var max_dist := center.length()
##
	##for x in range(grid_width):
		##for y in range(grid_height):
			### Base height
			##var h := height_noise.get_noise_2d(x, y)
			##h *= 1.25
			##
			### Add ridged multifractal for mountain ridges
			##var ridge := ridge_noise.get_noise_2d(x, y)
			##ridge = abs(ridge)  # Create ridges
			##ridge = 1.0 - ridge  # Invert so peaks are high
			##ridge = pow(ridge, 2.0)  # Sharpen peaks
			##
			### Blend ridge noise into height in high areas
			##if h > 0.4:
				##var ridge_blend = (h - 0.4) / 0.6  # 0 to 1 in high areas
				##h = lerp(h, h + ridge * 0.4, ridge_blend)
			##
			### Island falloff
			##var dist := Vector2(x, y).distance_to(center) / max_dist
			##var falloff = pow(dist, 2.2)
			##h -= falloff * 0.5
			##
			### Moisture and temperature
			##var moisture := moisture_noise.get_noise_2d(x, y)
			##var temp := temperature_noise.get_noise_2d(x, y)
			##
			##grid[x][y]["height"] = h
			##grid[x][y]["moisture"] = moisture
			##grid[x][y]["temperature"] = temp
##
##func _assign_terrain_types():
	##var height_stats = {"min": INF, "max": -INF}
	##
	##for x in range(grid_width):
		##for y in range(grid_height):
			##var h: float = grid[x][y]["height"]
			##var moisture: float = grid[x][y]["moisture"]
			##
			##height_stats["min"] = min(height_stats["min"], h)
			##height_stats["max"] = max(height_stats["max"], h)
			##
			##if h < -0.40:
				##grid[x][y]["type"] = "deep_water"
			##elif h < -0.15:
				##grid[x][y]["type"] = "shallow_water"
			##elif h < 0.0:
				##grid[x][y]["type"] = "beach"
			##elif h < 0.30:
				##if moisture > 0.3:
					##grid[x][y]["type"] = "forest"
				##elif moisture < -0.2:
					##grid[x][y]["type"] = "grassland"
				##else:
					##grid[x][y]["type"] = "lowland"
			##elif h < 0.60:
				##if moisture > 0.4:
					##grid[x][y]["type"] = "forest"
				##else:
					##grid[x][y]["type"] = "ground"
			##elif h < 0.75:
				##grid[x][y]["type"] = "highland"
			##else:
				##grid[x][y]["type"] = "mountain"
	##
	##print("Height range: %.3f to %.3f" % [height_stats["min"], height_stats["max"]])
##
##func _add_beaches():
	##for x in range(grid_width):
		##for y in range(grid_height):
			##if grid[x][y]["type"] in ["deep_water", "shallow_water"]:
				##continue
			##
			##var near_water = false
			##for dx in range(-1, 2):
				##for dy in range(-1, 2):
					##if dx == 0 and dy == 0:
						##continue
					##var check_pos = Vector2i(x + dx, y + dy)
					##if is_valid_pos(check_pos):
						##if grid[check_pos.x][check_pos.y]["type"] in ["shallow_water", "deep_water"]:
							##near_water = true
							##break
				##if near_water:
					##break
			##
			##if near_water and grid[x][y]["height"] < 0.15:
				##grid[x][y]["type"] = "beach"
##
##func _add_marshes():
	##for x in range(grid_width):
		##for y in range(grid_height):
			##if grid[x][y]["type"] != "lowland":
				##continue
			##
			##if grid[x][y]["height"] < 0.05 and grid[x][y]["moisture"] > 0.2:
				##var water_nearby = _count_nearby_type(Vector2i(x, y), ["shallow_water", "deep_water"], 3)
				##if water_nearby >= 2:
					##grid[x][y]["type"] = "marsh"
##
##func _smooth_terrain():
	##var changes := []
	##
	##for x in range(1, grid_width - 1):
		##for y in range(1, grid_height - 1):
			##var tile_type = grid[x][y]["type"]
			##var neighbors = _get_neighbor_types(Vector2i(x, y))
			##
			##var same_count = 0
			##for neighbor_type in neighbors:
				##if neighbor_type == tile_type:
					##same_count += 1
			##
			##if same_count < 2:
				##var most_common = _get_most_common_type(neighbors)
				##if most_common != tile_type:
					##changes.append({"pos": Vector2i(x, y), "type": most_common})
	##
	##for change in changes:
		##grid[change.pos.x][change.pos.y]["type"] = change.type
##
### =========================
### MAJOR RIVER GENERATION
### =========================
##
##func _place_major_rivers():
	##"""Generate long rivers using A* pathfinding from mountains to ocean"""
	##print("=== GENERATING MAJOR RIVERS ===")
	##
	##var target_water_tiles = 800  # Minimum water resource tiles we want
	##var current_water_tiles = 0
	##
	##var river_count = 0
	##var max_rivers = 12  # Try more rivers
	##var attempts = 0
	##var max_attempts = 100  # More attempts
	##
	##while river_count < max_rivers and attempts < max_attempts:
		##attempts += 1
		##
		### Find a mountain/highland start point
		##var start = _find_random_high_point()
		##if start == Vector2i(-1, -1):
			##continue
		##
		### Find nearest ocean point
		##var end = _find_nearest_ocean(start)
		##if end == Vector2i(-1, -1):
			##continue
		##
		### Use A* to find downhill path
		##var river_path = _find_river_path_astar(start, end)
		##
		### Accept shorter rivers if we're struggling (but still need reasonable length)
		##var min_length = 20 if river_count < 4 else 15
		##
		##if river_path.size() >= min_length:
			##var tiles_added = _carve_river(river_path)
			##current_water_tiles += tiles_added
			##river_count += 1
			##print("✓ River %d: %d tiles long (%d water tiles total)" % [river_count, river_path.size(), current_water_tiles])
	##
	##print("Total rivers created: %d" % river_count)
	##print("Water tiles from rivers: %d" % current_water_tiles)
	##
	### If we don't have enough water, add lakes as fallback
	##if current_water_tiles < target_water_tiles:
		##var needed = target_water_tiles - current_water_tiles
		##print("⚠ Need %d more water tiles - generating lakes..." % needed)
		##var lakes_added = _generate_lakes(needed)
		##current_water_tiles += lakes_added
		##print("✓ Added %d lake tiles (total water: %d)" % [lakes_added, current_water_tiles])
	##
	##print("=== WATER GENERATION COMPLETE: %d tiles ===" % current_water_tiles)
##
##func _find_random_high_point() -> Vector2i:
	##"""Find a random point on a mountain or highland"""
	##var high_points := []
	##
	### Collect all valid high points
	##for x in range(grid_width):
		##for y in range(grid_height):
			##if grid[x][y]["type"] in ["mountain", "highland"] and not grid[x][y]["is_river"]:
				##high_points.append(Vector2i(x, y))
	##
	##if high_points.is_empty():
		##return Vector2i(-1, -1)
	##
	##return high_points.pick_random()
##
##func _find_nearest_ocean(start: Vector2i) -> Vector2i:
	##"""Find nearest ocean/deep water point"""
	##var min_dist = INF
	##var best = Vector2i(-1, -1)
	##
	### Check all edges of map for ocean
	##var edge_points := []
	##
	### Top and bottom edges
	##for x in range(grid_width):
		##edge_points.append(Vector2i(x, 0))
		##edge_points.append(Vector2i(x, grid_height - 1))
	##
	### Left and right edges
	##for y in range(grid_height):
		##edge_points.append(Vector2i(0, y))
		##edge_points.append(Vector2i(grid_width - 1, y))
	##
	### Find nearest ocean point on edges
	##for point in edge_points:
		##if grid[point.x][point.y]["type"] in ["deep_water", "shallow_water"]:
			##var dist = start.distance_to(point)
			##if dist < min_dist:
				##min_dist = dist
				##best = point
	##
	### If no ocean on edges, find any ocean
	##if best == Vector2i(-1, -1):
		##for i in range(500):
			##var x = randi_range(0, grid_width - 1)
			##var y = randi_range(0, grid_height - 1)
			##
			##if grid[x][y]["type"] in ["deep_water", "shallow_water"]:
				##var dist = start.distance_to(Vector2i(x, y))
				##if dist < min_dist:
					##min_dist = dist
					##best = Vector2i(x, y)
	##
	##return best
##
##func _find_river_path_astar(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	##"""Use A* pathfinding with downhill preference to create natural river"""
	##var open_set := [start]
	##var came_from := {}
	##var g_score := {start: 0.0}
	##var f_score := {start: start.distance_to(goal)}
	##
	##var dirs := [
		##Vector2i(1, 0), Vector2i(-1, 0),
		##Vector2i(0, 1), Vector2i(0, -1),
		##Vector2i(1, 1), Vector2i(-1, -1),
		##Vector2i(1, -1), Vector2i(-1, 1)
	##]
	##
	##var iterations = 0
	##var max_iterations = 10000  # Prevent infinite loops
	##
	##while open_set.size() > 0 and iterations < max_iterations:
		##iterations += 1
		##
		### Find node with lowest f_score
		##var current = open_set[0]
		##var lowest_f = f_score.get(current, INF)
		##for node in open_set:
			##var f = f_score.get(node, INF)
			##if f < lowest_f:
				##lowest_f = f
				##current = node
		##
		### Reached ocean
		##if grid[current.x][current.y]["type"] in ["shallow_water", "deep_water"]:
			##return _reconstruct_path(came_from, current)
		##
		##open_set.erase(current)
		##
		### Check neighbors
		##for d in dirs:
			##var neighbor = current + d
			##
			##if not is_valid_pos(neighbor):
				##continue
			##
			### Calculate cost with strong downhill preference
			##var current_height = grid[current.x][current.y]["height"]
			##var neighbor_height = grid[neighbor.x][neighbor.y]["height"]
			##
			##var height_diff = current_height - neighbor_height
			##
			### Rivers strongly prefer downhill but can handle slight uphill
			##var cost = 1.0
			##if height_diff > 0.1:
				##cost = 0.3  # Strong downhill = very low cost
			##elif height_diff > 0.05:
				##cost = 0.6  # Moderate downhill
			##elif height_diff > 0.01:
				##cost = 0.9  # Gentle downhill
			##elif height_diff > -0.02:
				##cost = 1.5  # Nearly flat
			##elif height_diff > -0.05:
				##cost = 3.0  # Slight uphill - possible but expensive
			##else:
				##cost = 10.0  # Strong uphill - very expensive (but not impossible)
			##
			### Avoid existing rivers
			##if grid[neighbor.x][neighbor.y]["is_river"]:
				##cost *= 2.0
			##
			### Prefer staying on land (not going through ocean early)
			##if grid[neighbor.x][neighbor.y]["type"] in ["deep_water", "shallow_water"]:
				##if neighbor.distance_to(goal) > 5:  # Unless close to goal
					##cost *= 0.5  # Actually prefer water when close to ocean
			##
			##var tentative_g = g_score.get(current, INF) + cost
			##
			##if tentative_g < g_score.get(neighbor, INF):
				##came_from[neighbor] = current
				##g_score[neighbor] = tentative_g
				##f_score[neighbor] = tentative_g + neighbor.distance_to(goal) * 0.5  # Reduced heuristic weight
				##
				##if neighbor not in open_set:
					##open_set.append(neighbor)
	##
	##return []  # No path found
##
##func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	##"""Reconstruct path from A* came_from dict"""
	##var path: Array[Vector2i] = [current]
	##
	##while current in came_from:
		##current = came_from[current]
		##path.push_front(current)
	##
	##return path
##
##func _carve_river(path: Array[Vector2i]) -> int:
	##"""Carve river into terrain along path, returns number of water tiles added"""
	##var tiles_added = 0
	##
	##for i in range(path.size()):
		##var pos = path[i]
		##
		### Mark as river
		##grid[pos.x][pos.y]["is_river"] = true
		##
		### Convert to water if not already
		##if grid[pos.x][pos.y]["type"] not in ["deep_water", "shallow_water"]:
			### Rivers get wider near the end (ocean)
			##var river_width = 1
			##var progress = float(i) / float(path.size())
			##if progress > 0.7:
				##river_width = 2  # Wider near mouth
			##elif progress > 0.5:
				##river_width = 1 if randf() > 0.5 else 2  # Sometimes wider mid-section
			##
			### Carve main river
			##grid[pos.x][pos.y]["type"] = "shallow_water"
			##grid[pos.x][pos.y]["resource"] = "water"
			##resource_deposits[pos] = "water"
			##tiles_added += 1
			##
			### Widen river
			##if river_width > 1:
				##for dx in range(-1, 2):
					##for dy in range(-1, 2):
						##if dx == 0 and dy == 0:
							##continue
						##
						##var adj = pos + Vector2i(dx, dy)
						##if is_valid_pos(adj) and randf() > 0.4:
							##if grid[adj.x][adj.y]["type"] not in ["deep_water", "shallow_water", "mountain", "highland"]:
								##if adj not in resource_deposits:
									##grid[adj.x][adj.y]["type"] = "shallow_water"
									##grid[adj.x][adj.y]["resource"] = "water"
									##resource_deposits[adj] = "water"
									##tiles_added += 1
	##
	##return tiles_added
##
##func _generate_lakes(target_tiles: int) -> int:
	##"""Generate lakes in low-lying areas to ensure minimum water availability"""
	##print("=== GENERATING LAKES ===")
	##
	##var tiles_added = 0
	##var lakes_created = 0
	##var attempts = 0
	##var max_attempts = 200
	##
	##while tiles_added < target_tiles and attempts < max_attempts:
		##attempts += 1
		##
		### Find a suitable lake location (lowland, not too high, not already water)
		##var lake_center = _find_lake_location()
		##if lake_center == Vector2i(-1, -1):
			##continue
		##
		### Determine lake size based on how much water we still need
		##var remaining = target_tiles - tiles_added
		##var lake_size = clampi(randi_range(15, 40), 10, remaining + 10)
		##
		### Create lake using flood fill from center
		##var lake_tiles = _create_lake(lake_center, lake_size)
		##
		##if lake_tiles.size() >= 10:  # Minimum lake size
			##for tile in lake_tiles:
				##if tile not in resource_deposits:
					##grid[tile.x][tile.y]["type"] = "shallow_water"
					##grid[tile.x][tile.y]["resource"] = "water"
					##resource_deposits[tile] = "water"
					##tiles_added += 1
			##
			##lakes_created += 1
			##print("✓ Lake %d: %d tiles" % [lakes_created, lake_tiles.size()])
	##
	##print("Total lakes created: %d" % lakes_created)
	##return tiles_added
##
##func _find_lake_location() -> Vector2i:
	##"""Find a good location for a lake (low elevation, inland)"""
	##for attempt in range(100):
		##var x = randi_range(20, grid_width - 20)  # Not on edges
		##var y = randi_range(20, grid_height - 20)
		##var pos = Vector2i(x, y)
		##
		### Good lake conditions
		##if grid[x][y]["type"] in ["lowland", "grassland", "marsh"]:
			##if grid[x][y]["height"] < 0.15:  # Low elevation
				##if pos not in resource_deposits:
					### Check not too close to existing water
					##var water_nearby = _count_nearby_type(pos, ["shallow_water", "deep_water"], 5)
					##if water_nearby < 3:  # Not right next to ocean/river
						##return pos
	##
	##return Vector2i(-1, -1)
##
##func _create_lake(center: Vector2i, target_size: int) -> Array[Vector2i]:
	##"""Create a lake using flood fill, staying in low areas"""
	##var lake: Array[Vector2i] = [center]
	##var frontier: Array[Vector2i] = [center]
	##var dirs := [
		##Vector2i(1, 0), Vector2i(-1, 0),
		##Vector2i(0, 1), Vector2i(0, -1),
		##Vector2i(1, 1), Vector2i(-1, -1),
		##Vector2i(1, -1), Vector2i(-1, 1)
	##]
	##
	##var center_height = grid[center.x][center.y]["height"]
	##
	##while lake.size() < target_size and frontier.size() > 0:
		##var current = frontier.pick_random()
		##dirs.shuffle()
		##
		##for d in dirs:
			##var np = current + d
			##
			##if not is_valid_pos(np):
				##continue
			##if np in lake:
				##continue
			##
			### Lakes prefer flat areas
			##var height_diff = abs(grid[np.x][np.y]["height"] - center_height)
			##if height_diff > 0.1:  # Don't climb hills
				##continue
			##
			### Don't flood into mountains/highlands
			##if grid[np.x][np.y]["type"] in ["mountain", "highland", "deep_water"]:
				##continue
			##
			### Good lake tile
			##if randf() < 0.8:  # 80% expansion rate
				##lake.append(np)
				##frontier.append(np)
				##break
		##
		### Sometimes remove from frontier to create more circular lakes
		##if randf() < 0.2:
			##frontier.erase(current)
	##
	##return lake
##
### =========================
### RESOURCE GENERATION
### =========================
##
##func _place_resource_deposits():
	##print("=== RESOURCE GENERATION ===")
	##for res_id in RESOURCE_CONFIGS.keys():
		##var cfg = RESOURCE_CONFIGS[res_id]
		##_place_resource_type(
			##res_id,
			##cfg.count,
			##cfg.min_size,
			##cfg.max_size,
			##cfg.allowed_types,
			##cfg.get("forbidden_types", []),
			##cfg.shape,
			##cfg.get("min_distance_from_water", 0),
			##cfg.get("prefer_near_rivers", false)
		##)
##
##func _place_resource_type(
	##resource_id: String,
	##cluster_count: int,
	##min_size: int,
	##max_size: int,
	##allowed_types: Array,
	##forbidden_types: Array,
	##shape: String,
	##min_dist_water: int,
	##prefer_rivers: bool
##):
	##var placed := 0
	##var attempts := 0
	##var max_attempts := cluster_count * 50
##
	##while placed < cluster_count and attempts < max_attempts:
		##attempts += 1
		##var start := Vector2i(randi() % grid_width, randi() % grid_height)
##
		##if start in resource_deposits:
			##continue
		##
		##if not grid[start.x][start.y]["type"] in allowed_types:
			##continue
		##
		##if grid[start.x][start.y]["type"] in forbidden_types:
			##continue
		##
		##if min_dist_water > 0:
			##var water_dist = _distance_to_water(start)
			##if water_dist < min_dist_water:
				##continue
		##
		##if prefer_rivers:
			##var water_dist = _distance_to_water(start)
			##if water_dist < 3 or water_dist > 15:
				##if randf() > 0.3:
					##continue
##
		##var size := randi_range(min_size, max_size)
		##var cluster: Array[Vector2i] = []
##
		##match shape:
			##"blob":
				##cluster = _grow_blob_cluster(start, size, allowed_types, forbidden_types)
			##"vein":
				##cluster = _grow_vein_cluster(start, size, allowed_types, forbidden_types)
			##"river":
				##continue  # Skip, rivers are handled separately now
##
		##if cluster.size() < min_size:
			##continue
##
		##for p in cluster:
			##resource_deposits[p] = resource_id
			##grid[p.x][p.y]["resource"] = resource_id
##
		##placed += 1
##
	##print("✓ %s: %d/%d clusters" % [resource_id, placed, cluster_count])
##
### =========================
### CLUSTER SHAPES
### =========================
##
##func _grow_blob_cluster(start: Vector2i, target: int, allowed: Array, forbidden: Array) -> Array[Vector2i]:
	##var cluster: Array[Vector2i] = [start]
	##var frontier: Array[Vector2i] = [start]
	##var dirs := [
		##Vector2i(1,0), Vector2i(-1,0),
		##Vector2i(0,1), Vector2i(0,-1),
		##Vector2i(1,1), Vector2i(-1,-1),
		##Vector2i(1,-1), Vector2i(-1,1)
	##]
##
	##while cluster.size() < target and frontier.size() > 0:
		##var current = frontier.pick_random()
		##dirs.shuffle()
##
		##for d in dirs:
			##var np: Vector2i = current + d
			##if not is_valid_pos(np):
				##continue
			##if np in cluster:
				##continue
			##if not grid[np.x][np.y]["type"] in allowed:
				##continue
			##if grid[np.x][np.y]["type"] in forbidden:
				##continue
			##if randf() < 0.75:
				##cluster.append(np)
				##frontier.append(np)
				##break
##
		##if randf() < 0.3:
			##frontier.erase(current)
##
	##return cluster
##
##func _grow_vein_cluster(start: Vector2i, target: int, allowed: Array, forbidden: Array) -> Array[Vector2i]:
	##"""Create linear vein-like deposits (good for ore in mountains)"""
	##var cluster: Array[Vector2i] = [start]
	##var current := start
	##var direction := Vector2i(
		##[-1, 0, 1].pick_random(),
		##[-1, 0, 1].pick_random()
	##)
	##
	##var dirs := [
		##Vector2i(1,0), Vector2i(-1,0),
		##Vector2i(0,1), Vector2i(0,-1)
	##]
	##
	##while cluster.size() < target:
		### Mostly continue in same direction (80%), sometimes turn (20%)
		##if randf() < 0.8:
			##var next = current + direction
			##if is_valid_pos(next) and grid[next.x][next.y]["type"] in allowed and not grid[next.x][next.y]["type"] in forbidden:
				##if next not in cluster:
					##cluster.append(next)
					##current = next
				##continue
		##
		### Pick new direction
		##dirs.shuffle()
		##var found = false
		##for d in dirs:
			##var next = current + d
			##if not is_valid_pos(next):
				##continue
			##if next in cluster:
				##continue
			##if not grid[next.x][next.y]["type"] in allowed:
				##continue
			##if grid[next.x][next.y]["type"] in forbidden:
				##continue
			##
			##cluster.append(next)
			##current = next
			##direction = d
			##found = true
			##break
		##
		##if not found:
			##break
	##
	##return cluster
##
### =========================
### RENDERING
### =========================
##
##func _create_visual_grid():
	##var cx := ceili(grid_width / float(CHUNK_SIZE))
	##var cy := ceili(grid_height / float(CHUNK_SIZE))
	##print("Creating %d chunks" % (cx * cy))
##
	##for x in range(cx):
		##for y in range(cy):
			##var coord := Vector2i(x, y)
			##var mesh := _create_chunk_mesh(coord)
			##chunk_meshes[coord] = mesh
			##add_child(mesh)
##
##func _create_chunk_mesh(chunk: Vector2i) -> MeshInstance3D:
	##var st := SurfaceTool.new()
	##st.begin(Mesh.PRIMITIVE_TRIANGLES)
##
	##var sx := chunk.x * CHUNK_SIZE
	##var sy := chunk.y * CHUNK_SIZE
	##var ex = min(sx + CHUNK_SIZE, grid_width)
	##var ey = min(sy + CHUNK_SIZE, grid_height)
##
	##for x in range(sx, ex):
		##for y in range(sy, ey):
			##var color := _get_tile_color(grid[x][y])
			##_add_quad(st, grid_to_world(Vector2i(x, y)), color)
##
	##st.generate_normals()
##
	##var mi := MeshInstance3D.new()
	##mi.mesh = st.commit()
##
	##var mat := StandardMaterial3D.new()
	##mat.vertex_color_use_as_albedo = true
	##mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	##mi.material_override = mat
##
	##return mi
##
##func _add_quad(st: SurfaceTool, pos: Vector3, color: Color):
	##var h := TILE_SIZE * 0.475
	##var v0 := Vector3(pos.x - h, 0, pos.z - h)
	##var v1 := Vector3(pos.x + h, 0, pos.z - h)
	##var v2 := Vector3(pos.x + h, 0, pos.z + h)
	##var v3 := Vector3(pos.x - h, 0, pos.z + h)
##
	##st.set_color(color)
	##st.add_vertex(v0)
	##st.add_vertex(v1)
	##st.add_vertex(v2)
	##st.add_vertex(v0)
	##st.add_vertex(v2)
	##st.add_vertex(v3)
##
##func _get_tile_color(tile: Dictionary) -> Color:
	##if tile["resource"]:
		##if has_node("/root/GameData"):
			##var res = GameData.get_resource_by_id(tile["resource"])
			##if res:
				##return res.color
		##else:
			##match tile["resource"]:
				##"minerals": return Color(0.6, 0.6, 0.7)
				##"biomatter": return Color(0.4, 0.6, 0.3)
				##"hydrogen": return Color(0.7, 0.8, 0.9)
				##"crystals": return Color(0.8, 0.6, 0.9)
				##"wood": return Color(0.15, 0.45, 0.15)
				##"ore": return Color(0.7, 0.5, 0.3)
				##"rare_minerals": return Color(0.9, 0.7, 0.3)
				##"water": return Color(0.2, 0.4, 0.8)
##
	##match tile["type"]:
		##"deep_water": return Color(0.05, 0.1, 0.25)
		##"shallow_water": return Color(0.1, 0.25, 0.4)
		##"beach": return Color(0.8, 0.75, 0.6)
		##"marsh": return Color(0.2, 0.3, 0.25)
		##"lowland": return Color(0.3, 0.5, 0.3)
		##"grassland": return Color(0.4, 0.55, 0.3)
		##"forest": return Color(0.2, 0.4, 0.2)
		##"ground": return Color(0.4, 0.4, 0.35)
		##"highland": return Color(0.5, 0.45, 0.4)
		##"mountain": return Color(0.55, 0.5, 0.45)
##
	##return Color.GRAY
##
### =========================
### UTILS
### =========================
##
##func is_valid_pos(grid_pos: Vector2i) -> bool:
	##return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   ##grid_pos.y >= 0 and grid_pos.y < grid_height
##
##func _distance_to_water(pos: Vector2i) -> int:
	##var max_check = 15
	##
	##for dist in range(1, max_check + 1):
		##for dx in range(-dist, dist + 1):
			##for dy in range(-dist, dist + 1):
				##if abs(dx) != dist and abs(dy) != dist:
					##continue
				##
				##var check_pos = pos + Vector2i(dx, dy)
				##if not is_valid_pos(check_pos):
					##continue
				##
				##if grid[check_pos.x][check_pos.y]["type"] in ["shallow_water", "deep_water"]:
					##return dist
	##
	##return max_check
##
##func _count_nearby_type(pos: Vector2i, types: Array, radius: int) -> int:
	##var count = 0
	##
	##for dx in range(-radius, radius + 1):
		##for dy in range(-radius, radius + 1):
			##var check_pos = pos + Vector2i(dx, dy)
			##if not is_valid_pos(check_pos):
				##continue
			##
			##if grid[check_pos.x][check_pos.y]["type"] in types:
				##count += 1
	##
	##return count
##
##func _get_neighbor_types(pos: Vector2i) -> Array:
	##var types := []
	##
	##for dx in range(-1, 2):
		##for dy in range(-1, 2):
			##if dx == 0 and dy == 0:
				##continue
			##
			##var check_pos = pos + Vector2i(dx, dy)
			##if is_valid_pos(check_pos):
				##types.append(grid[check_pos.x][check_pos.y]["type"])
	##
	##return types
##
##func _get_most_common_type(types: Array) -> String:
	##var counts := {}
	##
	##for t in types:
		##if t in counts:
			##counts[t] += 1
		##else:
			##counts[t] = 1
	##
	##var most_common = ""
	##var max_count = 0
	##
	##for t in counts.keys():
		##if counts[t] > max_count:
			##max_count = counts[t]
			##most_common = t
	##
	##return most_common
##
##func grid_to_world(grid_pos: Vector2i) -> Vector3:
	##return Vector3(
		##grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		##0,
		##grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	##)
##
##func world_to_grid(world_pos: Vector3) -> Vector2i:
	##var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	##var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	##return Vector2i(x, y)
##
##
##func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	##"""Place a building on the grid"""
	##if not has_node("/root/GameData"):
		##return false
	##
	##var building = GameData.get_building_by_id(building_id)
	##if building.is_empty():
		##return false
	##
	##var size = building.size
	##
	### Use the improved can_place_building with building_id
	##if not can_place_building(grid_pos, size, building_id):
		##return false
	##
	### Mark tiles as occupied and store origin
	##for dx in range(size.x):
		##for dy in range(size.y):
			##var tile_pos = grid_pos + Vector2i(dx, dy)
			##grid[tile_pos.x][tile_pos.y].occupied = true
			##grid[tile_pos.x][tile_pos.y].building = building_id
			##grid[tile_pos.x][tile_pos.y].building_origin = grid_pos
	##
	##return true
	##
##func can_place_building(grid_pos: Vector2i, building_size: Vector2i, building_id: String = "") -> bool:
	##"""Check if a building can be placed at position
	##
	##Args:
		##grid_pos: Top-left position to place building
		##building_size: Size of the building (can be omitted if building_id provided)
		##building_id: ID to lookup building data for size and placement rules
	##"""
	##
	### Get building data if ID provided
	##var building_data = {}
	##var size = building_size
	##var forbidden_terrain: Array = []
	##var required_terrain: Array = []
	##
	##if building_id != "":
		##if has_node("/root/GameData"):
			##building_data = GameData.get_building_by_id(building_id)
			##if not building_data.is_empty():
				##size = building_data.get("size", building_size)
				##forbidden_terrain = building_data.get("forbidden_terrain", [])
				##required_terrain = building_data.get("required_terrain", [])
		##
		### Default forbidden terrain if not specified in building data
		##if forbidden_terrain.is_empty() and required_terrain.is_empty():
			### Most buildings can't be placed on deep water or marsh
			##forbidden_terrain = ["deep_water", "marsh"]
	##else:
		### Legacy behavior: no building_id provided, use old hardcoded rules
		##forbidden_terrain = ["deep_water", "marsh"]
	##
	### Check all tiles the building would occupy
	##for dx in range(size.x):
		##for dy in range(size.y):
			##var check_pos = grid_pos + Vector2i(dx, dy)
			##
			### Out of bounds check
			##if not is_valid_pos(check_pos):
				##return false
			##
			##var tile = grid[check_pos.x][check_pos.y]
			##
			### Already occupied check
			##if tile.occupied:
				##return false
			##
			### Required terrain check (if specified, AT LEAST ONE tile must match)
			##if not required_terrain.is_empty():
				##var has_required = false
				##for dx2 in range(size.x):
					##for dy2 in range(size.y):
						##var check_pos2 = grid_pos + Vector2i(dx2, dy2)
						##if is_valid_pos(check_pos2):
							##if grid[check_pos2.x][check_pos2.y].type in required_terrain:
								##has_required = true
								##break
					##if has_required:
						##break
				##
				##if not has_required:
					##return false
			##
			### Forbidden terrain check
			##if tile.type in forbidden_terrain:
				##return false
	##
	##return true
###func can_place_building(grid_pos: Vector2i, building_size: Vector2i) -> bool:
	###for dx in range(building_size.x):
		###for dy in range(building_size.y):
			###var check_pos = grid_pos + Vector2i(dx, dy)
			###
			###if not is_valid_pos(check_pos):
				###return false
			###
			###if grid[check_pos.x][check_pos.y].occupied:
				###return false
			###if grid[check_pos.x][check_pos.y].type in ["deep_water", "shallow_water", "marsh"]:
				###return false
	###
	###return true
##
###func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	###var building = GameData.get_building_by_id(building_id)
	###if building.is_empty():
		###return false
	###
	###var size = building.size
	###
	###if not can_place_building(grid_pos, size):
		###return false
	###
	###for dx in range(size.x):
		###for dy in range(size.y):
			###var tile_pos = grid_pos + Vector2i(dx, dy)
			###grid[tile_pos.x][tile_pos.y].occupied = true
			###grid[tile_pos.x][tile_pos.y].building = building_id
			###grid[tile_pos.x][tile_pos.y].building_origin = grid_pos
	###
	###return true
##
##func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	##if not is_valid_pos(grid_pos):
		##return {}
	##
	##return grid[grid_pos.x][grid_pos.y].duplicate()
##
###extends Node3D
###class_name TileGrid
###
#### =========================
#### CONFIG
#### =========================
###
###const TILE_SIZE := 2.0
###const CHUNK_SIZE := 16
###
###@export var grid_width := 256
###@export var grid_height := 256
###
#### =========================
#### DATA
#### =========================
###
###var grid: Array = []
###var resource_deposits: Dictionary = {}
###var chunk_meshes: Dictionary = {}
###
#### Terrain noise layers
###var height_noise: FastNoiseLite
###var moisture_noise: FastNoiseLite
###var temperature_noise: FastNoiseLite
###var ridge_noise: FastNoiseLite  # For mountain ridges
###
#### =========================
#### RESOURCE DEFINITIONS
#### =========================
###
###const RESOURCE_CONFIGS := {
	###"minerals": {
		###"count": 50,
		###"min_size": 3,
		###"max_size": 8,
		###"allowed_types": ["ground", "highland", "mountain"],
		###"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		###"shape": "blob",
		###"min_distance_from_water": 2
	###},
	###"biomatter": {
		###"count": 50,
		###"min_size": 3,
		###"max_size": 8,
		###"allowed_types": ["ground", "highland", "mountain"],
		###"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		###"shape": "blob",
		###"min_distance_from_water": 2
	###},
	###"hydrogen": {
		###"count": 50,
		###"min_size": 3,
		###"max_size": 8,
		###"allowed_types": ["ground", "highland", "mountain"],
		###"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		###"shape": "blob",
		###"min_distance_from_water": 2
	###},
	###"crystals": {
		###"count": 25,
		###"min_size": 1,
		###"max_size": 4,
		###"allowed_types": ["ground", "highland", "mountain"],
		###"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		###"shape": "blob",
		###"min_distance_from_water": 2
	###},
	###"wood": {
		###"count": 200,
		###"min_size": 20,
		###"max_size": 50,
		###"allowed_types": ["lowland", "forest"],
		###"forbidden_types": ["deep_water", "shallow_water", "beach", "highland", "mountain"],
		###"shape": "blob",
		###"min_distance_from_water": 3,
		###"prefer_near_rivers": true
	###},
	###"ore": {
		###"count": 40,
		###"min_size": 4,
		###"max_size": 10,
		###"allowed_types": ["highland", "mountain"],
		###"forbidden_types": ["deep_water", "shallow_water", "beach", "lowland"],
		###"shape": "vein",  # New shape for minerals in mountains
		###"min_distance_from_water": 0
	###},
	###"rare_minerals": {
		###"count": 10,
		###"min_size": 4,
		###"max_size": 10,
		###"allowed_types": ["highland", "mountain"],
		###"forbidden_types": ["deep_water", "shallow_water", "beach", "lowland"],
		###"shape": "vein",
		###"min_distance_from_water": 0
	###}
###}
###
#### =========================
#### LIFECYCLE
#### =========================
###
###func _ready():
	###_initialize_grid()
	###_setup_noise()
	###_generate_terrain()
	###_assign_terrain_types()
	###_add_beaches()
	###_add_marshes()
	###_smooth_terrain()
	###_place_major_rivers()  # New: Place long rivers first
	###_place_resource_deposits()
	###_create_visual_grid()
###
#### =========================
#### GRID SETUP
#### =========================
###
###func _initialize_grid():
	###grid.clear()
	###for x in range(grid_width):
		###var column := []
		###for y in range(grid_height):
			###column.append({
				###"type": "ground",
				###"height": 0.0,
				###"moisture": 0.0,
				###"temperature": 0.0,
				###"resource": null,
				###"occupied": false,
				###"building": null,
				###"building_origin": null,
				###"is_river": false  # Track river tiles
			###})
		###grid.append(column)
###
###func _setup_noise():
	#### Height/elevation noise with ridged multifractal for mountains
	###height_noise = FastNoiseLite.new()
	###height_noise.seed = randi()
	###height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	###height_noise.frequency = 0.012
	###height_noise.fractal_octaves = 5
	###height_noise.fractal_gain = 0.5
	###height_noise.fractal_lacunarity = 2.0
	###
	#### Ridge noise for mountain ranges
	###ridge_noise = FastNoiseLite.new()
	###ridge_noise.seed = randi()
	###ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	###ridge_noise.frequency = 0.008  # Lower frequency for large features
	###ridge_noise.fractal_octaves = 3
	###ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	###
	#### Moisture noise
	###moisture_noise = FastNoiseLite.new()
	###moisture_noise.seed = randi()
	###moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	###moisture_noise.frequency = 0.02
	###moisture_noise.fractal_octaves = 3
	###
	#### Temperature noise
	###temperature_noise = FastNoiseLite.new()
	###temperature_noise.seed = randi()
	###temperature_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	###temperature_noise.frequency = 0.008
	###temperature_noise.fractal_octaves = 2
###
#### =========================
#### TERRAIN
#### =========================
###
###func _generate_terrain():
	###var center := Vector2(grid_width / 2.0, grid_height / 2.0)
	###var max_dist := center.length()
###
	###for x in range(grid_width):
		###for y in range(grid_height):
			#### Base height
			###var h := height_noise.get_noise_2d(x, y)
			###h *= 1.25
			###
			#### Add ridged multifractal for mountain ridges
			###var ridge := ridge_noise.get_noise_2d(x, y)
			###ridge = abs(ridge)  # Create ridges
			###ridge = 1.0 - ridge  # Invert so peaks are high
			###ridge = pow(ridge, 2.0)  # Sharpen peaks
			###
			#### Blend ridge noise into height in high areas
			###if h > 0.4:
				###var ridge_blend = (h - 0.4) / 0.6  # 0 to 1 in high areas
				###h = lerp(h, h + ridge * 0.4, ridge_blend)
			###
			#### Island falloff
			###var dist := Vector2(x, y).distance_to(center) / max_dist
			###var falloff = pow(dist, 2.2)
			###h -= falloff * 0.5
			###
			#### Moisture and temperature
			###var moisture := moisture_noise.get_noise_2d(x, y)
			###var temp := temperature_noise.get_noise_2d(x, y)
			###
			###grid[x][y]["height"] = h
			###grid[x][y]["moisture"] = moisture
			###grid[x][y]["temperature"] = temp
###
###func _assign_terrain_types():
	###var height_stats = {"min": INF, "max": -INF}
	###
	###for x in range(grid_width):
		###for y in range(grid_height):
			###var h: float = grid[x][y]["height"]
			###var moisture: float = grid[x][y]["moisture"]
			###
			###height_stats["min"] = min(height_stats["min"], h)
			###height_stats["max"] = max(height_stats["max"], h)
			###
			###if h < -0.40:
				###grid[x][y]["type"] = "deep_water"
			###elif h < -0.15:
				###grid[x][y]["type"] = "shallow_water"
			###elif h < 0.0:
				###grid[x][y]["type"] = "beach"
			###elif h < 0.30:
				###if moisture > 0.3:
					###grid[x][y]["type"] = "forest"
				###elif moisture < -0.2:
					###grid[x][y]["type"] = "grassland"
				###else:
					###grid[x][y]["type"] = "lowland"
			###elif h < 0.60:
				###if moisture > 0.4:
					###grid[x][y]["type"] = "forest"
				###else:
					###grid[x][y]["type"] = "ground"
			###elif h < 0.75:
				###grid[x][y]["type"] = "highland"
			###else:
				###grid[x][y]["type"] = "mountain"
	###
	###print("Height range: %.3f to %.3f" % [height_stats["min"], height_stats["max"]])
###
###func _add_beaches():
	###for x in range(grid_width):
		###for y in range(grid_height):
			###if grid[x][y]["type"] in ["deep_water", "shallow_water"]:
				###continue
			###
			###var near_water = false
			###for dx in range(-1, 2):
				###for dy in range(-1, 2):
					###if dx == 0 and dy == 0:
						###continue
					###var check_pos = Vector2i(x + dx, y + dy)
					###if is_valid_pos(check_pos):
						###if grid[check_pos.x][check_pos.y]["type"] in ["shallow_water", "deep_water"]:
							###near_water = true
							###break
				###if near_water:
					###break
			###
			###if near_water and grid[x][y]["height"] < 0.15:
				###grid[x][y]["type"] = "beach"
###
###func _add_marshes():
	###for x in range(grid_width):
		###for y in range(grid_height):
			###if grid[x][y]["type"] != "lowland":
				###continue
			###
			###if grid[x][y]["height"] < 0.05 and grid[x][y]["moisture"] > 0.2:
				###var water_nearby = _count_nearby_type(Vector2i(x, y), ["shallow_water", "deep_water"], 3)
				###if water_nearby >= 2:
					###grid[x][y]["type"] = "marsh"
###
###func _smooth_terrain():
	###var changes := []
	###
	###for x in range(1, grid_width - 1):
		###for y in range(1, grid_height - 1):
			###var tile_type = grid[x][y]["type"]
			###var neighbors = _get_neighbor_types(Vector2i(x, y))
			###
			###var same_count = 0
			###for neighbor_type in neighbors:
				###if neighbor_type == tile_type:
					###same_count += 1
			###
			###if same_count < 2:
				###var most_common = _get_most_common_type(neighbors)
				###if most_common != tile_type:
					###changes.append({"pos": Vector2i(x, y), "type": most_common})
	###
	###for change in changes:
		###grid[change.pos.x][change.pos.y]["type"] = change.type
###
#### =========================
#### MAJOR RIVER GENERATION
#### =========================
###
###func _place_major_rivers():
	###"""Generate long rivers using A* pathfinding from mountains to ocean"""
	###print("=== GENERATING MAJOR RIVERS ===")
	###
	###var river_count = 0
	###var max_rivers = 8
	###var attempts = 0
	###var max_attempts = 50
	###
	###while river_count < max_rivers and attempts < max_attempts:
		###attempts += 1
		###
		#### Find a mountain/highland start point
		###var start = _find_random_high_point()
		###if start == Vector2i(-1, -1):
			###continue
		###
		#### Find nearest ocean point
		###var end = _find_nearest_ocean(start)
		###if end == Vector2i(-1, -1):
			###continue
		###
		#### Use A* to find downhill path
		###var river_path = _find_river_path_astar(start, end)
		###
		###if river_path.size() > 30:  # Only accept long rivers
			###_carve_river(river_path)
			###river_count += 1
			###print("✓ River %d: %d tiles long" % [river_count, river_path.size()])
	###
	###print("Total rivers created: %d" % river_count)
###
###func _find_random_high_point() -> Vector2i:
	###"""Find a random point on a mountain or highland"""
	###for i in range(100):
		###var x = randi_range(0, grid_width - 1)
		###var y = randi_range(0, grid_height - 1)
		###var pos = Vector2i(x, y)
		###
		###if grid[x][y]["type"] in ["mountain", "highland"] and not grid[x][y]["is_river"]:
			###return pos
	###
	###return Vector2i(-1, -1)
###
###func _find_nearest_ocean(start: Vector2i) -> Vector2i:
	###"""Find nearest ocean/deep water point"""
	###var min_dist = INF
	###var best = Vector2i(-1, -1)
	###
	#### Sample ocean points to find nearest
	###for i in range(200):
		###var x = randi_range(0, grid_width - 1)
		###var y = randi_range(0, grid_height - 1)
		###
		###if grid[x][y]["type"] == "deep_water":
			###var dist = start.distance_to(Vector2i(x, y))
			###if dist < min_dist:
				###min_dist = dist
				###best = Vector2i(x, y)
	###
	###return best
###
###func _find_river_path_astar(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	###"""Use A* pathfinding with downhill preference to create natural river"""
	###var open_set := [start]
	###var came_from := {}
	###var g_score := {start: 0.0}
	###var f_score := {start: start.distance_to(goal)}
	###
	###var dirs := [
		###Vector2i(1, 0), Vector2i(-1, 0),
		###Vector2i(0, 1), Vector2i(0, -1),
		###Vector2i(1, 1), Vector2i(-1, -1),
		###Vector2i(1, -1), Vector2i(-1, 1)
	###]
	###
	###while open_set.size() > 0:
		#### Find node with lowest f_score
		###var current = open_set[0]
		###var lowest_f = f_score.get(current, INF)
		###for node in open_set:
			###var f = f_score.get(node, INF)
			###if f < lowest_f:
				###lowest_f = f
				###current = node
		###
		#### Reached ocean
		###if grid[current.x][current.y]["type"] in ["shallow_water", "deep_water"]:
			###return _reconstruct_path(came_from, current)
		###
		###open_set.erase(current)
		###
		#### Check neighbors
		###for d in dirs:
			###var neighbor = current + d
			###
			###if not is_valid_pos(neighbor):
				###continue
			###
			#### Calculate cost with strong downhill preference
			###var current_height = grid[current.x][current.y]["height"]
			###var neighbor_height = grid[neighbor.x][neighbor.y]["height"]
			###
			###var height_diff = current_height - neighbor_height
			###
			#### Rivers can't flow uphill
			###if height_diff < -0.01:
				###continue
			###
			#### Cost: prefer downhill, penalize flat
			###var cost = 1.0
			###if height_diff > 0.05:
				###cost = 0.5  # Strong downhill = low cost
			###elif height_diff > 0.01:
				###cost = 0.8  # Gentle downhill
			###else:
				###cost = 2.0  # Flat = high cost
			###
			#### Avoid existing rivers slightly
			###if grid[neighbor.x][neighbor.y]["is_river"]:
				###cost *= 1.5
			###
			###var tentative_g = g_score.get(current, INF) + cost
			###
			###if tentative_g < g_score.get(neighbor, INF):
				###came_from[neighbor] = current
				###g_score[neighbor] = tentative_g
				###f_score[neighbor] = tentative_g + neighbor.distance_to(goal)
				###
				###if neighbor not in open_set:
					###open_set.append(neighbor)
	###
	###return []  # No path found
###
###func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	###"""Reconstruct path from A* came_from dict"""
	###var path: Array[Vector2i] = [current]
	###
	###while current in came_from:
		###current = came_from[current]
		###path.push_front(current)
	###
	###return path
###
###func _carve_river(path: Array[Vector2i]):
	###"""Carve river into terrain along path"""
	###for i in range(path.size()):
		###var pos = path[i]
		###
		#### Mark as river
		###grid[pos.x][pos.y]["is_river"] = true
		###
		#### Convert to water if not already
		###if grid[pos.x][pos.y]["type"] not in ["deep_water", "shallow_water"]:
			#### Rivers get wider near the end (ocean)
			###var river_width = 1
			###var progress = float(i) / float(path.size())
			###if progress > 0.7:
				###river_width = 2  # Wider near mouth
			###
			#### Carve main river
			###grid[pos.x][pos.y]["type"] = "shallow_water"
			###grid[pos.x][pos.y]["resource"] = "water"
			###resource_deposits[pos] = "water"
			###
			#### Widen river near mouth
			###if river_width > 1:
				###for dx in range(-1, 2):
					###for dy in range(-1, 2):
						###var adj = pos + Vector2i(dx, dy)
						###if is_valid_pos(adj) and randf() > 0.3:
							###if grid[adj.x][adj.y]["type"] not in ["deep_water", "shallow_water", "mountain", "highland"]:
								###grid[adj.x][adj.y]["type"] = "shallow_water"
###
#### =========================
#### RESOURCE GENERATION
#### =========================
###
###func _place_resource_deposits():
	###print("=== RESOURCE GENERATION ===")
	###for res_id in RESOURCE_CONFIGS.keys():
		###var cfg = RESOURCE_CONFIGS[res_id]
		###_place_resource_type(
			###res_id,
			###cfg.count,
			###cfg.min_size,
			###cfg.max_size,
			###cfg.allowed_types,
			###cfg.get("forbidden_types", []),
			###cfg.shape,
			###cfg.get("min_distance_from_water", 0),
			###cfg.get("prefer_near_rivers", false)
		###)
###
###func _place_resource_type(
	###resource_id: String,
	###cluster_count: int,
	###min_size: int,
	###max_size: int,
	###allowed_types: Array,
	###forbidden_types: Array,
	###shape: String,
	###min_dist_water: int,
	###prefer_rivers: bool
###):
	###var placed := 0
	###var attempts := 0
	###var max_attempts := cluster_count * 50
###
	###while placed < cluster_count and attempts < max_attempts:
		###attempts += 1
		###var start := Vector2i(randi() % grid_width, randi() % grid_height)
###
		###if start in resource_deposits:
			###continue
		###
		###if not grid[start.x][start.y]["type"] in allowed_types:
			###continue
		###
		###if grid[start.x][start.y]["type"] in forbidden_types:
			###continue
		###
		###if min_dist_water > 0:
			###var water_dist = _distance_to_water(start)
			###if water_dist < min_dist_water:
				###continue
		###
		###if prefer_rivers:
			###var water_dist = _distance_to_water(start)
			###if water_dist < 3 or water_dist > 15:
				###if randf() > 0.3:
					###continue
###
		###var size := randi_range(min_size, max_size)
		###var cluster: Array[Vector2i] = []
###
		###match shape:
			###"blob":
				###cluster = _grow_blob_cluster(start, size, allowed_types, forbidden_types)
			###"vein":
				###cluster = _grow_vein_cluster(start, size, allowed_types, forbidden_types)
			###"river":
				###continue  # Skip, rivers are handled separately now
###
		###if cluster.size() < min_size:
			###continue
###
		###for p in cluster:
			###resource_deposits[p] = resource_id
			###grid[p.x][p.y]["resource"] = resource_id
###
		###placed += 1
###
	###print("✓ %s: %d/%d clusters" % [resource_id, placed, cluster_count])
###
#### =========================
#### CLUSTER SHAPES
#### =========================
###
###func _grow_blob_cluster(start: Vector2i, target: int, allowed: Array, forbidden: Array) -> Array[Vector2i]:
	###var cluster: Array[Vector2i] = [start]
	###var frontier: Array[Vector2i] = [start]
	###var dirs := [
		###Vector2i(1,0), Vector2i(-1,0),
		###Vector2i(0,1), Vector2i(0,-1),
		###Vector2i(1,1), Vector2i(-1,-1),
		###Vector2i(1,-1), Vector2i(-1,1)
	###]
###
	###while cluster.size() < target and frontier.size() > 0:
		###var current = frontier.pick_random()
		###dirs.shuffle()
###
		###for d in dirs:
			###var np: Vector2i = current + d
			###if not is_valid_pos(np):
				###continue
			###if np in cluster:
				###continue
			###if not grid[np.x][np.y]["type"] in allowed:
				###continue
			###if grid[np.x][np.y]["type"] in forbidden:
				###continue
			###if randf() < 0.75:
				###cluster.append(np)
				###frontier.append(np)
				###break
###
		###if randf() < 0.3:
			###frontier.erase(current)
###
	###return cluster
###
###func _grow_vein_cluster(start: Vector2i, target: int, allowed: Array, forbidden: Array) -> Array[Vector2i]:
	###"""Create linear vein-like deposits (good for ore in mountains)"""
	###var cluster: Array[Vector2i] = [start]
	###var current := start
	###var direction := Vector2i(
		###[-1, 0, 1].pick_random(),
		###[-1, 0, 1].pick_random()
	###)
	###
	###var dirs := [
		###Vector2i(1,0), Vector2i(-1,0),
		###Vector2i(0,1), Vector2i(0,-1)
	###]
	###
	###while cluster.size() < target:
		#### Mostly continue in same direction (80%), sometimes turn (20%)
		###if randf() < 0.8:
			###var next = current + direction
			###if is_valid_pos(next) and grid[next.x][next.y]["type"] in allowed and not grid[next.x][next.y]["type"] in forbidden:
				###if next not in cluster:
					###cluster.append(next)
					###current = next
				###continue
		###
		#### Pick new direction
		###dirs.shuffle()
		###var found = false
		###for d in dirs:
			###var next = current + d
			###if not is_valid_pos(next):
				###continue
			###if next in cluster:
				###continue
			###if not grid[next.x][next.y]["type"] in allowed:
				###continue
			###if grid[next.x][next.y]["type"] in forbidden:
				###continue
			###
			###cluster.append(next)
			###current = next
			###direction = d
			###found = true
			###break
		###
		###if not found:
			###break
	###
	###return cluster
###
#### =========================
#### RENDERING
#### =========================
###
###func _create_visual_grid():
	###var cx := ceili(grid_width / float(CHUNK_SIZE))
	###var cy := ceili(grid_height / float(CHUNK_SIZE))
	###print("Creating %d chunks" % (cx * cy))
###
	###for x in range(cx):
		###for y in range(cy):
			###var coord := Vector2i(x, y)
			###var mesh := _create_chunk_mesh(coord)
			###chunk_meshes[coord] = mesh
			###add_child(mesh)
###
###func _create_chunk_mesh(chunk: Vector2i) -> MeshInstance3D:
	###var st := SurfaceTool.new()
	###st.begin(Mesh.PRIMITIVE_TRIANGLES)
###
	###var sx := chunk.x * CHUNK_SIZE
	###var sy := chunk.y * CHUNK_SIZE
	###var ex = min(sx + CHUNK_SIZE, grid_width)
	###var ey = min(sy + CHUNK_SIZE, grid_height)
###
	###for x in range(sx, ex):
		###for y in range(sy, ey):
			###var color := _get_tile_color(grid[x][y])
			###_add_quad(st, grid_to_world(Vector2i(x, y)), color)
###
	###st.generate_normals()
###
	###var mi := MeshInstance3D.new()
	###mi.mesh = st.commit()
###
	###var mat := StandardMaterial3D.new()
	###mat.vertex_color_use_as_albedo = true
	###mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	###mi.material_override = mat
###
	###return mi
###
###func _add_quad(st: SurfaceTool, pos: Vector3, color: Color):
	###var h := TILE_SIZE * 0.475
	###var v0 := Vector3(pos.x - h, 0, pos.z - h)
	###var v1 := Vector3(pos.x + h, 0, pos.z - h)
	###var v2 := Vector3(pos.x + h, 0, pos.z + h)
	###var v3 := Vector3(pos.x - h, 0, pos.z + h)
###
	###st.set_color(color)
	###st.add_vertex(v0)
	###st.add_vertex(v1)
	###st.add_vertex(v2)
	###st.add_vertex(v0)
	###st.add_vertex(v2)
	###st.add_vertex(v3)
###
###func _get_tile_color(tile: Dictionary) -> Color:
	###if tile["resource"]:
		###if has_node("/root/GameData"):
			###var res = GameData.get_resource_by_id(tile["resource"])
			###if res:
				###return res.color
		###else:
			###match tile["resource"]:
				###"minerals": return Color(0.6, 0.6, 0.7)
				###"biomatter": return Color(0.4, 0.6, 0.3)
				###"hydrogen": return Color(0.7, 0.8, 0.9)
				###"crystals": return Color(0.8, 0.6, 0.9)
				###"wood": return Color(0.15, 0.45, 0.15)
				###"ore": return Color(0.7, 0.5, 0.3)
				###"rare_minerals": return Color(0.9, 0.7, 0.3)
				###"water": return Color(0.2, 0.4, 0.8)
###
	###match tile["type"]:
		###"deep_water": return Color(0.05, 0.1, 0.25)
		###"shallow_water": return Color(0.1, 0.25, 0.4)
		###"beach": return Color(0.8, 0.75, 0.6)
		###"marsh": return Color(0.2, 0.3, 0.25)
		###"lowland": return Color(0.3, 0.5, 0.3)
		###"grassland": return Color(0.4, 0.55, 0.3)
		###"forest": return Color(0.2, 0.4, 0.2)
		###"ground": return Color(0.4, 0.4, 0.35)
		###"highland": return Color(0.5, 0.45, 0.4)
		###"mountain": return Color(0.55, 0.5, 0.45)
###
	###return Color.GRAY
###
#### =========================
#### UTILS
#### =========================
###
###func is_valid_pos(grid_pos: Vector2i) -> bool:
	###return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   ###grid_pos.y >= 0 and grid_pos.y < grid_height
###
###func _distance_to_water(pos: Vector2i) -> int:
	###var max_check = 15
	###
	###for dist in range(1, max_check + 1):
		###for dx in range(-dist, dist + 1):
			###for dy in range(-dist, dist + 1):
				###if abs(dx) != dist and abs(dy) != dist:
					###continue
				###
				###var check_pos = pos + Vector2i(dx, dy)
				###if not is_valid_pos(check_pos):
					###continue
				###
				###if grid[check_pos.x][check_pos.y]["type"] in ["shallow_water", "deep_water"]:
					###return dist
	###
	###return max_check
###
###func _count_nearby_type(pos: Vector2i, types: Array, radius: int) -> int:
	###var count = 0
	###
	###for dx in range(-radius, radius + 1):
		###for dy in range(-radius, radius + 1):
			###var check_pos = pos + Vector2i(dx, dy)
			###if not is_valid_pos(check_pos):
				###continue
			###
			###if grid[check_pos.x][check_pos.y]["type"] in types:
				###count += 1
	###
	###return count
###
###func _get_neighbor_types(pos: Vector2i) -> Array:
	###var types := []
	###
	###for dx in range(-1, 2):
		###for dy in range(-1, 2):
			###if dx == 0 and dy == 0:
				###continue
			###
			###var check_pos = pos + Vector2i(dx, dy)
			###if is_valid_pos(check_pos):
				###types.append(grid[check_pos.x][check_pos.y]["type"])
	###
	###return types
###
###func _get_most_common_type(types: Array) -> String:
	###var counts := {}
	###
	###for t in types:
		###if t in counts:
			###counts[t] += 1
		###else:
			###counts[t] = 1
	###
	###var most_common = ""
	###var max_count = 0
	###
	###for t in counts.keys():
		###if counts[t] > max_count:
			###max_count = counts[t]
			###most_common = t
	###
	###return most_common
###
###func grid_to_world(grid_pos: Vector2i) -> Vector3:
	###return Vector3(
		###grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		###0,
		###grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	###)
###
###func world_to_grid(world_pos: Vector3) -> Vector2i:
	###var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	###var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	###return Vector2i(x, y)
###
###func can_place_building(grid_pos: Vector2i, building_size: Vector2i) -> bool:
	###for dx in range(building_size.x):
		###for dy in range(building_size.y):
			###var check_pos = grid_pos + Vector2i(dx, dy)
			###
			###if not is_valid_pos(check_pos):
				###return false
			###
			###if grid[check_pos.x][check_pos.y].occupied:
				###return false
			###if grid[check_pos.x][check_pos.y].type in ["deep_water", "marsh"]:
				###return false
	###
	###return true
###
###func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	###var building = GameData.get_building_by_id(building_id)
	###if building.is_empty():
		###return false
	###
	###var size = building.size
	###
	###if not can_place_building(grid_pos, size):
		###return false
	###
	###for dx in range(size.x):
		###for dy in range(size.y):
			###var tile_pos = grid_pos + Vector2i(dx, dy)
			###grid[tile_pos.x][tile_pos.y].occupied = true
			###grid[tile_pos.x][tile_pos.y].building = building_id
			###grid[tile_pos.x][tile_pos.y].building_origin = grid_pos
	###
	###return true
###
###func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	###if not is_valid_pos(grid_pos):
		###return {}
	###
	###return grid[grid_pos.x][grid_pos.y].duplicate()
###
###
###
####extends Node3D
####class_name TileGrid
####
##### =========================
##### CONFIG
##### =========================
####
####const TILE_SIZE := 2.0
####const CHUNK_SIZE := 16
####
####@export var grid_width := 256
####@export var grid_height := 256
####
##### =========================
##### DATA
##### =========================
####
####var grid: Array = []                     # grid[x][y] -> Dictionary
####var resource_deposits: Dictionary = {}   # Vector2i -> resource_id
####var chunk_meshes: Dictionary = {}        # Vector2i -> MeshInstance3D
####
##### Terrain noise layers
####var height_noise: FastNoiseLite
####var moisture_noise: FastNoiseLite
####var temperature_noise: FastNoiseLite
####
##### =========================
##### RESOURCE DEFINITIONS
##### =========================
####
####const RESOURCE_CONFIGS := {
	####"minerals": {
		####"count": 50,
		####"min_size": 3,
		####"max_size": 8,
		####"allowed_types": ["ground", "highland", "mountain"],
		####"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		####"shape": "blob",
		####"min_distance_from_water": 2
	####},
	####"biomatter": {
		####"count": 50,
		####"min_size": 3,
		####"max_size": 8,
		####"allowed_types": ["ground", "highland", "mountain"],
		####"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		####"shape": "blob",
		####"min_distance_from_water": 2
	####},
	####"hydrogen": {
		####"count": 50,
		####"min_size": 3,
		####"max_size": 8,
		####"allowed_types": ["ground", "highland", "mountain"],
		####"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		####"shape": "blob",
		####"min_distance_from_water": 2
	####},
	####"crystals": {
		####"count": 25,
		####"min_size": 1,
		####"max_size": 4,
		####"allowed_types": ["ground", "highland", "mountain"],
		####"forbidden_types": ["deep_water", "shallow_water", "beach", "marsh"],
		####"shape": "blob",
		####"min_distance_from_water": 2
	####},
	####
	####"wood": {
		####"count": 150,
		####"min_size": 20,
		####"max_size": 30,
		####"allowed_types": ["lowland", "forest"],
		####"forbidden_types": ["deep_water", "shallow_water", "beach", "highland", "mountain"],
		####"shape": "blob",
		####"min_distance_from_water": 3,  # No forests directly on beaches
		####"prefer_near_rivers": true
	####},
	####"ore": {
		####"count": 40,
		####"min_size": 4,
		####"max_size": 10,
		####"allowed_types": ["highland", "mountain"],
		####"forbidden_types": ["deep_water", "shallow_water", "beach", "lowland"],
		####"shape": "blob",
		####"min_distance_from_water": 0
	####},
	####"rare_minerals": {
		####"count": 10,
		####"min_size": 4,
		####"max_size": 10,
		####"allowed_types": ["highland", "mountain"],
		####"forbidden_types": ["deep_water", "shallow_water", "beach", "lowland"],
		####"shape": "blob",
		####"min_distance_from_water": 0
	####},
	####"water": {
		####"count": 100,
		####"min_size": 30,
		####"max_size": 40,
		####"allowed_types": ["lowland", "shallow_water", "marsh"],
		####"forbidden_types": [],
		####"shape": "river",
		####"min_distance_from_water": 0
	####}
####}
####
##### =========================
##### LIFECYCLE
##### =========================
####
####func _ready():
	####_initialize_grid()
	####_setup_noise()
	####_generate_terrain()
	####_assign_terrain_types()
	####_add_beaches()
	####_add_marshes()
	####_smooth_terrain()
	####_place_resource_deposits()
	####_create_visual_grid()
####
##### =========================
##### GRID SETUP
##### =========================
####
####func _initialize_grid():
	####grid.clear()
	####for x in range(grid_width):
		####var column := []
		####for y in range(grid_height):
			####column.append({
				####"type": "ground",
				####"height": 0.0,
				####"moisture": 0.0,
				####"temperature": 0.0,
				####"resource": null,
				####"occupied": false,
				####"building": null,
				####"building_origin": null
			####})
		####grid.append(column)
####
####func _setup_noise():
	##### Height/elevation noise
	####height_noise = FastNoiseLite.new()
	####height_noise.seed = randi()
	####height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	####height_noise.frequency = 0.012  # Slightly lower for smoother terrain
	####height_noise.fractal_octaves = 5  # More detail
	####height_noise.fractal_gain = 0.5
	####height_noise.fractal_lacunarity = 2.0
	####
	##### Moisture noise (for forests, marshes)
	####moisture_noise = FastNoiseLite.new()
	####moisture_noise.seed = randi()
	####moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	####moisture_noise.frequency = 0.02
	####moisture_noise.fractal_octaves = 3
	####
	##### Temperature noise (for biome variation)
	####temperature_noise = FastNoiseLite.new()
	####temperature_noise.seed = randi()
	####temperature_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	####temperature_noise.frequency = 0.008
	####temperature_noise.fractal_octaves = 2
####
##### =========================
##### TERRAIN
##### =========================
####
####func _generate_terrain():
	####var center := Vector2(grid_width / 2.0, grid_height / 2.0)
	####var max_dist := center.length()
####
	####for x in range(grid_width):
		####for y in range(grid_height):
			##### Base height
			####var h := height_noise.get_noise_2d(x, y)
			####h *= 1.25
			##### Island falloff (softer edges)
			####var dist := Vector2(x, y).distance_to(center) / max_dist
			####var falloff = pow(dist, 2.2)  # Exponential falloff for natural islands
			####h -= falloff * 0.5
			####
			##### Moisture and temperature
			####var moisture := moisture_noise.get_noise_2d(x, y)
			####var temp := temperature_noise.get_noise_2d(x, y)
			####
			####grid[x][y]["height"] = h
			####grid[x][y]["moisture"] = moisture
			####grid[x][y]["temperature"] = temp
####
####func _assign_terrain_types():
	####for x in range(grid_width):
		####for y in range(grid_height):
			####var h: float = grid[x][y]["height"]
			####var moisture: float = grid[x][y]["moisture"]
			####var temp: float = grid[x][y]["temperature"]
			####
			##### Base terrain by height
			####if h < -0.40:
				####grid[x][y]["type"] = "deep_water"
			####elif h < -0.15:
				####grid[x][y]["type"] = "shallow_water"
			####elif h < 0.0:
				##### Transition zone - will become beach or marsh
				####grid[x][y]["type"] = "beach"
			####elif h < 0.30:
				##### Low areas - could be forest if moist enough
				####if moisture > 0.3:
					####grid[x][y]["type"] = "forest"
				####elif moisture < -0.2:
					####grid[x][y]["type"] = "grassland"
				####else:
					####grid[x][y]["type"] = "lowland"
			####elif h < 0.60:
				##### Mid elevation
				####if moisture > 0.4:
					####grid[x][y]["type"] = "forest"
				####else:
					####grid[x][y]["type"] = "ground"
			####elif h < 0.80:
				##### Highlands
				####grid[x][y]["type"] = "highland"
			####else:
				##### Mountains
				####grid[x][y]["type"] = "mountain"
####
####func _add_beaches():
	####"""Add beach zones between land and water"""
	####for x in range(grid_width):
		####for y in range(grid_height):
			####if grid[x][y]["type"] in ["deep_water", "shallow_water"]:
				####continue
			####
			##### Check if adjacent to water
			####var near_water = false
			####for dx in range(-1, 2):
				####for dy in range(-1, 2):
					####if dx == 0 and dy == 0:
						####continue
					####var check_pos = Vector2i(x + dx, y + dy)
					####if is_valid_pos(check_pos):
						####if grid[check_pos.x][check_pos.y]["type"] in ["shallow_water", "deep_water"]:
							####near_water = true
							####break
				####if near_water:
					####break
			####
			##### Land tiles adjacent to water become beach (unless already high elevation)
			####if near_water and grid[x][y]["height"] < 0.15:
				####grid[x][y]["type"] = "beach"
####
####func _add_marshes():
	####"""Add marsh/wetland zones in low-lying areas near water"""
	####for x in range(grid_width):
		####for y in range(grid_height):
			####if grid[x][y]["type"] != "lowland":
				####continue
			####
			##### Low elevation + high moisture + near water = marsh
			####if grid[x][y]["height"] < 0.05 and grid[x][y]["moisture"] > 0.2:
				####var water_nearby = _count_nearby_type(Vector2i(x, y), ["shallow_water", "deep_water"], 3)
				####if water_nearby >= 2:
					####grid[x][y]["type"] = "marsh"
####
####func _smooth_terrain():
	####"""Smooth out single-tile anomalies for more natural terrain"""
	####var changes := []
	####
	####for x in range(1, grid_width - 1):
		####for y in range(1, grid_height - 1):
			####var tile_type = grid[x][y]["type"]
			####var neighbors = _get_neighbor_types(Vector2i(x, y))
			####
			##### If surrounded by different terrain, convert to most common neighbor
			####var same_count = 0
			####for neighbor_type in neighbors:
				####if neighbor_type == tile_type:
					####same_count += 1
			####
			##### Isolated tile (less than 2 same neighbors)
			####if same_count < 2:
				####var most_common = _get_most_common_type(neighbors)
				####if most_common != tile_type:
					####changes.append({"pos": Vector2i(x, y), "type": most_common})
	####
	##### Apply changes
	####for change in changes:
		####grid[change.pos.x][change.pos.y]["type"] = change.type
####
##### =========================
##### RESOURCE GENERATION
##### =========================
####
####func _place_resource_deposits():
	####print("=== RESOURCE GENERATION ===")
	####for res_id in RESOURCE_CONFIGS.keys():
		####var cfg = RESOURCE_CONFIGS[res_id]
		####_place_resource_type(
			####res_id,
			####cfg.count,
			####cfg.min_size,
			####cfg.max_size,
			####cfg.allowed_types,
			####cfg.get("forbidden_types", []),
			####cfg.shape,
			####cfg.get("min_distance_from_water", 0),
			####cfg.get("prefer_near_rivers", false)
		####)
####
####func _place_resource_type(
	####resource_id: String,
	####cluster_count: int,
	####min_size: int,
	####max_size: int,
	####allowed_types: Array,
	####forbidden_types: Array,
	####shape: String,
	####min_dist_water: int,
	####prefer_rivers: bool
####):
	####var placed := 0
	####var attempts := 0
	####var max_attempts := cluster_count * 50
####
	####while placed < cluster_count and attempts < max_attempts:
		####attempts += 1
		####var start := Vector2i(randi() % grid_width, randi() % grid_height)
####
		##### Skip if already has resource
		####if start in resource_deposits:
			####continue
		####
		##### Check terrain type
		####if not grid[start.x][start.y]["type"] in allowed_types:
			####continue
		####
		##### Check forbidden types
		####if grid[start.x][start.y]["type"] in forbidden_types:
			####continue
		####
		##### Check distance from water
		####if min_dist_water > 0:
			####var water_dist = _distance_to_water(start)
			####if water_dist < min_dist_water:
				####continue
		####
		##### For forests, prefer areas near rivers but not beaches
		####if prefer_rivers:
			####var water_dist = _distance_to_water(start)
			##### Sweet spot: 3-8 tiles from water
			####if water_dist < 3 or water_dist > 15:
				####if randf() > 0.3:  # 70% chance to skip if not in preferred zone
					####continue
####
		####var size := randi_range(min_size, max_size)
		####var cluster: Array[Vector2i] = []
####
		####match shape:
			####"blob":
				####cluster = _grow_blob_cluster(start, size, allowed_types, forbidden_types)
			####"river":
				####cluster = _grow_river_cluster(start, size, allowed_types)
####
		####if cluster.size() < min_size:
			####continue
####
		####for p in cluster:
			####resource_deposits[p] = resource_id
			####grid[p.x][p.y]["resource"] = resource_id
####
		####placed += 1
####
	####print("✓ %s: %d/%d clusters" % [resource_id, placed, cluster_count])
####
##### =========================
##### CLUSTER SHAPES
##### =========================
####
####func _grow_blob_cluster(start: Vector2i, target: int, allowed: Array, forbidden: Array) -> Array[Vector2i]:
	####var cluster: Array[Vector2i] = [start]
	####var frontier: Array[Vector2i] = [start]
	####var dirs := [
		####Vector2i(1,0), Vector2i(-1,0),
		####Vector2i(0,1), Vector2i(0,-1),
		####Vector2i(1,1), Vector2i(-1,-1),
		####Vector2i(1,-1), Vector2i(-1,1)
	####]
####
	####while cluster.size() < target and frontier.size() > 0:
		####var current = frontier.pick_random()
		####dirs.shuffle()
####
		####for d in dirs:
			####var np: Vector2i = current + d
			####if not is_valid_pos(np):
				####continue
			####if np in cluster:
				####continue
			####if not grid[np.x][np.y]["type"] in allowed:
				####continue
			####if grid[np.x][np.y]["type"] in forbidden:
				####continue
			####if randf() < 0.75:
				####cluster.append(np)
				####frontier.append(np)
				####break
####
		####if randf() < 0.3:
			####frontier.erase(current)
####
	####return cluster
####
####func _grow_river_cluster(start: Vector2i, target: int, allowed: Array) -> Array[Vector2i]:
	####var cluster: Array[Vector2i] = [start]
	####var current := start
	####var dirs := [
		####Vector2i(1,0), Vector2i(-1,0),
		####Vector2i(0,1), Vector2i(0,-1)
	####]
####
	####while cluster.size() < target:
		####var best: Array[Vector2i] = []
		####var lowest := INF
####
		####for d in dirs:
			####var np = current + d
			####if not is_valid_pos(np):
				####continue
			####if not grid[np.x][np.y]["type"] in allowed:
				####continue
####
			####var h = grid[np.x][np.y]["height"]
			####if h < lowest:
				####lowest = h
				####best = [np]
			####elif abs(h - lowest) < 0.01:
				####best.append(np)
####
		####if best.is_empty():
			####break
####
		####current = best.pick_random()
		####cluster.append(current)
####
		####if grid[current.x][current.y]["type"] in ["shallow_water", "deep_water"]:
			####break
####
	####return cluster
####
##### =========================
##### RENDERING
##### =========================
####
####func _create_visual_grid():
	####var cx := ceili(grid_width / float(CHUNK_SIZE))
	####var cy := ceili(grid_height / float(CHUNK_SIZE))
	####print("Creating %d chunks" % (cx * cy))
####
	####for x in range(cx):
		####for y in range(cy):
			####var coord := Vector2i(x, y)
			####var mesh := _create_chunk_mesh(coord)
			####chunk_meshes[coord] = mesh
			####add_child(mesh)
####
####func _create_chunk_mesh(chunk: Vector2i) -> MeshInstance3D:
	####var st := SurfaceTool.new()
	####st.begin(Mesh.PRIMITIVE_TRIANGLES)
####
	####var sx := chunk.x * CHUNK_SIZE
	####var sy := chunk.y * CHUNK_SIZE
	####var ex = min(sx + CHUNK_SIZE, grid_width)
	####var ey = min(sy + CHUNK_SIZE, grid_height)
####
	####for x in range(sx, ex):
		####for y in range(sy, ey):
			####var color := _get_tile_color(grid[x][y])
			####_add_quad(st, grid_to_world(Vector2i(x, y)), color)
####
	####st.generate_normals()
####
	####var mi := MeshInstance3D.new()
	####mi.mesh = st.commit()
####
	####var mat := StandardMaterial3D.new()
	####mat.vertex_color_use_as_albedo = true
	####mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	####mi.material_override = mat
####
	####return mi
####
####func _add_quad(st: SurfaceTool, pos: Vector3, color: Color):
	####var h := TILE_SIZE * 0.475
	####var v0 := Vector3(pos.x - h, 0, pos.z - h)
	####var v1 := Vector3(pos.x + h, 0, pos.z - h)
	####var v2 := Vector3(pos.x + h, 0, pos.z + h)
	####var v3 := Vector3(pos.x - h, 0, pos.z + h)
####
	####st.set_color(color)
	####st.add_vertex(v0)
	####st.add_vertex(v1)
	####st.add_vertex(v2)
	####st.add_vertex(v0)
	####st.add_vertex(v2)
	####st.add_vertex(v3)
####
####func _get_tile_color(tile: Dictionary) -> Color:
	####if tile["resource"]:
		##### Check if GameData autoload exists before using it
		####if has_node("/root/GameData"):
			####var res = GameData.get_resource_by_id(tile["resource"])
			####if res:
				####return res.color
		####else:
			##### Fallback colors for resources if GameData doesn't exist
			####match tile["resource"]:
				####"minerals": return Color(0.6, 0.6, 0.7)
				####"wood": return Color(0.15, 0.45, 0.15)
				####"ore": return Color(0.7, 0.5, 0.3)
				####"water": return Color(0.2, 0.4, 0.8)
####
	####match tile["type"]:
		####"deep_water": return Color(0.05, 0.1, 0.25)
		####"shallow_water": return Color(0.1, 0.25, 0.4)
		####"beach": return Color(0.8, 0.75, 0.6)
		####"marsh": return Color(0.2, 0.3, 0.25)
		####"lowland": return Color(0.3, 0.5, 0.3)
		####"grassland": return Color(0.4, 0.55, 0.3)
		####"forest": return Color(0.2, 0.4, 0.2)
		####"ground": return Color(0.4, 0.4, 0.35)
		####"highland": return Color(0.5, 0.45, 0.4)
		####"mountain": return Color(0.55, 0.5, 0.45)
####
	####return Color.GRAY
####
##### =========================
##### UTILS
##### =========================
####
####func is_valid_pos(grid_pos: Vector2i) -> bool:
	####"""Check if grid position is within bounds"""
	####return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   ####grid_pos.y >= 0 and grid_pos.y < grid_height
####
####func _distance_to_water(pos: Vector2i) -> int:
	####"""Calculate minimum distance to nearest water tile"""
	####var max_check = 15  # Don't check too far for performance
	####
	####for dist in range(1, max_check + 1):
		####for dx in range(-dist, dist + 1):
			####for dy in range(-dist, dist + 1):
				####if abs(dx) != dist and abs(dy) != dist:
					####continue  # Only check perimeter
				####
				####var check_pos = pos + Vector2i(dx, dy)
				####if not is_valid_pos(check_pos):
					####continue
				####
				####if grid[check_pos.x][check_pos.y]["type"] in ["shallow_water", "deep_water"]:
					####return dist
	####
	####return max_check
####
####func _count_nearby_type(pos: Vector2i, types: Array, radius: int) -> int:
	####"""Count tiles of specific types within radius"""
	####var count = 0
	####
	####for dx in range(-radius, radius + 1):
		####for dy in range(-radius, radius + 1):
			####var check_pos = pos + Vector2i(dx, dy)
			####if not is_valid_pos(check_pos):
				####continue
			####
			####if grid[check_pos.x][check_pos.y]["type"] in types:
				####count += 1
	####
	####return count
####
####func _get_neighbor_types(pos: Vector2i) -> Array:
	####"""Get terrain types of all 8 neighbors"""
	####var types := []
	####
	####for dx in range(-1, 2):
		####for dy in range(-1, 2):
			####if dx == 0 and dy == 0:
				####continue
			####
			####var check_pos = pos + Vector2i(dx, dy)
			####if is_valid_pos(check_pos):
				####types.append(grid[check_pos.x][check_pos.y]["type"])
	####
	####return types
####
####func _get_most_common_type(types: Array) -> String:
	####"""Get most common terrain type from array"""
	####var counts := {}
	####
	####for t in types:
		####if t in counts:
			####counts[t] += 1
		####else:
			####counts[t] = 1
	####
	####var most_common = ""
	####var max_count = 0
	####
	####for t in counts.keys():
		####if counts[t] > max_count:
			####max_count = counts[t]
			####most_common = t
	####
	####return most_common
####
####func grid_to_world(grid_pos: Vector2i) -> Vector3:
	####"""Convert grid coordinates to world position"""
	####return Vector3(
		####grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		####0,
		####grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	####)
####
####func world_to_grid(world_pos: Vector3) -> Vector2i:
	####"""Convert world position to grid coordinates"""
	####var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	####var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	####return Vector2i(x, y)
####
####func can_place_building(grid_pos: Vector2i, building_size: Vector2i) -> bool:
	####"""Check if a building can be placed at position"""
	##### Check all tiles the building would occupy
	####for dx in range(building_size.x):
		####for dy in range(building_size.y):
			####var check_pos = grid_pos + Vector2i(dx, dy)
			####
			####if not is_valid_pos(check_pos):
				####return false
			####
			####if grid[check_pos.x][check_pos.y].occupied:
				####return false
			####if grid[check_pos.x][check_pos.y].type in ["deep_water", "shallow_water", "marsh"]:
				####return false
	####
	####return true
####
####func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	####"""Place a building on the grid"""
	####var building = GameData.get_building_by_id(building_id)
	####if building.is_empty():
		####return false
	####
	####var size = building.size
	####
	####if not can_place_building(grid_pos, size):
		####return false
	####
	##### Mark tiles as occupied and store origin
	####for dx in range(size.x):
		####for dy in range(size.y):
			####var tile_pos = grid_pos + Vector2i(dx, dy)
			####grid[tile_pos.x][tile_pos.y].occupied = true
			####grid[tile_pos.x][tile_pos.y].building = building_id
			####grid[tile_pos.x][tile_pos.y].building_origin = grid_pos
	####
	####return true
####
####func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	####"""Get information about a specific tile"""
	####if not is_valid_pos(grid_pos):
		####return {}
	####
	####return grid[grid_pos.x][grid_pos.y].duplicate()
#####extends Node3D
#####class_name TileGrid
#####
###### =========================
###### CONFIG
###### =========================
#####
#####const TILE_SIZE := 2.0
#####const CHUNK_SIZE := 16
#####
#####@export var grid_width := 256
#####@export var grid_height := 256
#####
###### =========================
###### DATA
###### =========================
#####
#####var grid: Array = []                     # grid[x][y] -> Dictionary
#####var resource_deposits: Dictionary = {}   # Vector2i -> resource_id
#####var chunk_meshes: Dictionary = {}        # Vector2i -> MeshInstance3D
#####
###### =========================
###### RESOURCE DEFINITIONS
###### =========================
#####
#####const RESOURCE_CONFIGS := {
	#####"minerals": {
		#####"count": 50,
		#####"min_size": 3,
		#####"max_size": 8,
		#####"allowed_types": ["ground", "highland"],
		#####"shape": "blob"
	#####},
	#####"wood": {
		#####"count": 150,
		#####"min_size": 10,
		#####"max_size": 30,
		#####"allowed_types": ["lowland", "ground"],
		#####"shape": "blob"
	#####},
	#####"ore": {
		#####"count": 40,
		#####"min_size": 4,
		#####"max_size": 10,
		#####"allowed_types": ["highland"],
		#####"shape": "blob"
	#####},
	#####"water": {
		#####"count": 100,
		#####"min_size": 12,
		#####"max_size": 40,
		#####"allowed_types": ["lowland", "shallow_water"],
		#####"shape": "river"
	#####}
#####}
#####
###### =========================
###### LIFECYCLE
###### =========================
#####
#####func _ready():
	#####_initialize_grid()
	#####_generate_terrain()
	#####_assign_terrain_types()
	#####_place_resource_deposits()
	#####_create_visual_grid()
#####
###### =========================
###### GRID SETUP
###### =========================
####
####func _initialize_grid():
	####grid.clear()
	####for x in range(grid_width):
		####var column := []
		####for y in range(grid_height):
			####column.append({
				####"type": "ground",
				####"height": 0.0,
				####"resource": null,
				####"occupied": false,
				####"building": null,
				####"building_origin": null
			####})
		####grid.append(column)
####
##### =========================
##### TERRAIN
##### =========================
####
####func _generate_terrain():
	####var noise := FastNoiseLite.new()
	####noise.seed = randi()
	####noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	####noise.frequency = 0.015
	####noise.fractal_octaves = 4
	####noise.fractal_gain = 0.5
	####noise.fractal_lacunarity = 2.0
####
	####var center := Vector2(grid_width / 2.0, grid_height / 2.0)
	####var max_dist := center.length()
####
	####for x in range(grid_width):
		####for y in range(grid_height):
			####var h := noise.get_noise_2d(x, y)
			####var dist := Vector2(x, y).distance_to(center) / max_dist
			####h -= dist * 0.6
			####grid[x][y]["height"] = h
####
####func _assign_terrain_types():
	####for x in range(grid_width):
		####for y in range(grid_height):
			####var h: float = grid[x][y]["height"]
			####if h < -0.35:
				####grid[x][y]["type"] = "deep_water"
			####elif h < -0.1:
				####grid[x][y]["type"] = "shallow_water"
			####elif h < 0.25:
				####grid[x][y]["type"] = "lowland"
			####elif h < 0.55:
				####grid[x][y]["type"] = "ground"
			####else:
				####grid[x][y]["type"] = "highland"
####
##### =========================
##### RESOURCE GENERATION
##### =========================
####
####func _place_resource_deposits():
	####print("=== RESOURCE GENERATION ===")
	####for res_id in RESOURCE_CONFIGS.keys():
		####var cfg = RESOURCE_CONFIGS[res_id]
		####_place_resource_type(
			####res_id,
			####cfg.count,
			####cfg.min_size,
			####cfg.max_size,
			####cfg.allowed_types,
			####cfg.shape
		####)
####
####func _place_resource_type(
	####resource_id: String,
	####cluster_count: int,
	####min_size: int,
	####max_size: int,
	####allowed_types: Array,
	####shape: String
####):
	####var placed := 0
	####var attempts := 0
	####var max_attempts := cluster_count * 30
####
	####while placed < cluster_count and attempts < max_attempts:
		####attempts += 1
		####var start := Vector2i(randi() % grid_width, randi() % grid_height)
####
		####if start in resource_deposits:
			####continue
		####if not grid[start.x][start.y]["type"] in allowed_types:
			####continue
####
		####var size := randi_range(min_size, max_size)
		####var cluster: Array[Vector2i] = []
####
		####match shape:
			####"blob":
				####cluster = _grow_blob_cluster(start, size, allowed_types)
			####"river":
				####cluster = _grow_river_cluster(start, size, allowed_types)
####
		####if cluster.size() < min_size:
			####continue
####
		####for p in cluster:
			####resource_deposits[p] = resource_id
			####grid[p.x][p.y]["resource"] = resource_id
####
		####placed += 1
####
	####print("✓ %s: %d/%d clusters" % [resource_id, placed, cluster_count])
####
##### =========================
##### CLUSTER SHAPES
##### =========================
####
####func _grow_blob_cluster(start: Vector2i, target: int, allowed: Array) -> Array[Vector2i]:
	####var cluster: Array[Vector2i] = [start]
	####var frontier: Array[Vector2i] = [start]
	####var dirs := [
		####Vector2i(1,0), Vector2i(-1,0),
		####Vector2i(0,1), Vector2i(0,-1),
		####Vector2i(1,1), Vector2i(-1,-1),
		####Vector2i(1,-1), Vector2i(-1,1)
	####]
####
	####while cluster.size() < target and frontier.size() > 0:
		####var current = frontier.pick_random()
		####dirs.shuffle()
####
		####for d in dirs:
			####var np: Vector2i = current + d
			####if not is_valid_pos(np):
				####continue
			####if np in cluster:
				####continue
			####if not grid[np.x][np.y]["type"] in allowed:
				####continue
			####if randf() < 0.75:
				####cluster.append(np)
				####frontier.append(np)
				####break
####
		####if randf() < 0.3:
			####frontier.erase(current)
####
	####return cluster
####
####func _grow_river_cluster(start: Vector2i, target: int, allowed: Array) -> Array[Vector2i]:
	####var cluster: Array[Vector2i] = [start]
	####var current := start
	####var dirs := [
		####Vector2i(1,0), Vector2i(-1,0),
		####Vector2i(0,1), Vector2i(0,-1)
	####]
####
	####while cluster.size() < target:
		####var best: Array[Vector2i] = []
		####var lowest := INF
####
		####for d in dirs:
			####var np = current + d
			####if not is_valid_pos(np):
				####continue
			####if not grid[np.x][np.y]["type"] in allowed:
				####continue
####
			####var h = grid[np.x][np.y]["height"]
			####if h < lowest:
				####lowest = h
				####best = [np]
			####elif abs(h - lowest) < 0.01:
				####best.append(np)
####
		####if best.is_empty():
			####break
####
		####current = best.pick_random()
		####cluster.append(current)
####
		####if grid[current.x][current.y]["type"] in ["shallow_water", "deep_water"]:
			####break
####
	####return cluster
####
##### =========================
##### RENDERING
##### =========================
####
####func _create_visual_grid():
	####var cx := ceili(grid_width / float(CHUNK_SIZE))
	####var cy := ceili(grid_height / float(CHUNK_SIZE))
	####print("Creating %d chunks" % (cx * cy))
####
	####for x in range(cx):
		####for y in range(cy):
			####var coord := Vector2i(x, y)
			####var mesh := _create_chunk_mesh(coord)
			####chunk_meshes[coord] = mesh
			####add_child(mesh)
####
####func _create_chunk_mesh(chunk: Vector2i) -> MeshInstance3D:
	####var st := SurfaceTool.new()
	####st.begin(Mesh.PRIMITIVE_TRIANGLES)
####
	####var sx := chunk.x * CHUNK_SIZE
	####var sy := chunk.y * CHUNK_SIZE
	####var ex = min(sx + CHUNK_SIZE, grid_width)
	####var ey = min(sy + CHUNK_SIZE, grid_height)
####
	####for x in range(sx, ex):
		####for y in range(sy, ey):
			####var color := _get_tile_color(grid[x][y])
			####_add_quad(st, grid_to_world(Vector2i(x, y)), color)
####
	####st.generate_normals()
####
	####var mi := MeshInstance3D.new()
	####mi.mesh = st.commit()
####
	####var mat := StandardMaterial3D.new()
	####mat.vertex_color_use_as_albedo = true
	####mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL ## BaseMaterial3D.SHADING_MODE_UNSHADED
	####mi.material_override = mat
####
	####return mi
####
####func _add_quad(st: SurfaceTool, pos: Vector3, color: Color):
	####var h := TILE_SIZE * 0.475
	####var v0 := Vector3(pos.x - h, 0, pos.z - h)
	####var v1 := Vector3(pos.x + h, 0, pos.z - h)
	####var v2 := Vector3(pos.x + h, 0, pos.z + h)
	####var v3 := Vector3(pos.x - h, 0, pos.z + h)
####
	####st.set_color(color)
	####st.add_vertex(v0)
	####st.add_vertex(v1)
	####st.add_vertex(v2)
	####st.add_vertex(v0)
	####st.add_vertex(v2)
	####st.add_vertex(v3)
####
####func _get_tile_color(tile: Dictionary) -> Color:
	####if tile["resource"]:
		##### Check if GameData autoload exists before using it
		####if has_node("/root/GameData"):
			####var res = GameData.get_resource_by_id(tile["resource"])
			####if res:
				####return res.color
		####else:
			##### Fallback colors for resources if GameData doesn't exist
			####match tile["resource"]:
				####"minerals": return Color(0.6, 0.6, 0.7)
				####"wood": return Color(0.2, 0.5, 0.2)
				####"ore": return Color(0.7, 0.5, 0.3)
				####"water": return Color(0.2, 0.4, 0.8)
####
	####match tile["type"]:
		####"deep_water": return Color(0.05, 0.1, 0.2)
		####"shallow_water": return Color(0.1, 0.2, 0.3)
		####"lowland": return Color(0.25, 0.4, 0.25)
		####"ground": return Color(0.35, 0.35, 0.35)
		####"highland": return Color(0.5, 0.45, 0.4)
####
	####return Color.GRAY
####
##### =========================
##### UTILS
##### =========================
####func grid_to_world(grid_pos: Vector2i) -> Vector3:
	####"""Convert grid coordinates to world position"""
	####return Vector3(
		####grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		####0,
		####grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	####)
####
####func world_to_grid(world_pos: Vector3) -> Vector2i:
	####"""Convert world position to grid coordinates"""
	####var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	####var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	####return Vector2i(x, y)
####
####func is_valid_pos(grid_pos: Vector2i) -> bool:
	####"""Check if grid position is within bounds"""
	####return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   ####grid_pos.y >= 0 and grid_pos.y < grid_height
####
####func can_place_building(grid_pos: Vector2i, building_size: Vector2i) -> bool:
	####"""Check if a building can be placed at position"""
	##### Check all tiles the building would occupy
	####for dx in range(building_size.x):
		####for dy in range(building_size.y):
			####var check_pos = grid_pos + Vector2i(dx, dy)
			####
			####if not is_valid_pos(check_pos):
				####return false
			####
			####if grid[check_pos.x][check_pos.y].occupied:
				####return false
			####if grid[check_pos.x][check_pos.y].type in ["deep_water", "shallow_water"]:
				####return false
	####
	####return true
####
####func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	####"""Place a building on the grid"""
	####var building = GameData.get_building_by_id(building_id)
	####if building.is_empty():
		####return false
	####
	####var size = building.size
	####
	####if not can_place_building(grid_pos, size):
		####return false
	####
	##### Mark tiles as occupied and store origin
	####for dx in range(size.x):
		####for dy in range(size.y):
			####var tile_pos = grid_pos + Vector2i(dx, dy)
			####grid[tile_pos.x][tile_pos.y].occupied = true
			####grid[tile_pos.x][tile_pos.y].building = building_id
			####grid[tile_pos.x][tile_pos.y].building_origin = grid_pos  # Store where building actually is!
	####
	####return true
####
####func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	####"""Get information about a specific tile"""
	####if not is_valid_pos(grid_pos):
		####return {}
	####
	####return grid[grid_pos.x][grid_pos.y].duplicate()
	####
	####
#####func is_valid_pos(p: Vector2i) -> bool:
	#####return p.x >= 0 and p.x < grid_width and p.y >= 0 and p.y < grid_height
####
#####func grid_to_world(p: Vector2i) -> Vector3:
	#####return Vector3(
		#####p.x * TILE_SIZE - (grid_width * TILE_SIZE / 2) + TILE_SIZE / 2,
		#####0,
		#####p.y * TILE_SIZE - (grid_height * TILE_SIZE / 2) + TILE_SIZE / 2
	#####)
####
####
####
#####extends Node3D
#####class_name TileGrid
###### TileGrid - Manages the tile-based grid for building placement
#####
#####const TILE_SIZE = 2.0  # Size of each tile in world units
#####const CHUNK_SIZE = 16  # 16x16 tiles per chunk
#####var chunk_meshes: Dictionary = {}  # Replaces tile_meshes
#####
#####@export var grid_width: int = 256
#####@export var grid_height: int = 256
#####
###### Grid data: grid[x][y] = {type, resource, building, etc}
#####var grid: Array = []
#####
###### Visual tile meshes
#####var tile_meshes: Dictionary = {}  # {Vector2i: MeshInstance3D}
#####
###### Resource deposits on this planet
#####var resource_deposits: Dictionary = {}  # {Vector2i: resource_id}
#####
#####func _ready():
	#####_initialize_grid()
	#####_generate_terrain()
	#####_assign_terrain_types()
	#####_place_resource_deposits()
	#####_create_visual_grid()
#####
#####func _initialize_grid():
	#####"""Create empty grid"""
	#####grid = []
	#####for x in range(grid_width):
		#####var column = []
		#####for y in range(grid_height):
			#####column.append({
				#####"type": "ground",
				#####"building": null,
				#####"resource": null,
				#####"building_origin": null,  # Where the building actually starts
				#####"occupied": false
			#####})
		#####grid.append(column)
#####
#####func _generate_terrain():
	#####var noise = FastNoiseLite.new()
	#####noise.seed = randi()
	#####noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	#####noise.frequency = 0.015
	#####noise.fractal_octaves = 4
	#####noise.fractal_gain = 0.5
	#####noise.fractal_lacunarity = 2.0
#####
	#####var center = Vector2(grid_width / 2.0, grid_height / 2.0)
	#####var max_dist = center.length()
#####
	#####for x in range(grid_width):
		#####for y in range(grid_height):
			#####var nx = float(x)
			#####var ny = float(y)
#####
			###### Base height noise
			#####var height = noise.get_noise_2d(nx, ny)
#####
			###### Radial falloff for planet shape
			#####var dist = Vector2(nx, ny).distance_to(center) / max_dist
			#####height -= dist * 0.6
#####
			###### Store height temporarily
			#####grid[x][y]["height"] = height
#####
#####func _assign_terrain_types():
	#####for x in range(grid_width):
		#####for y in range(grid_height):
			#####var h = grid[x][y]["height"]
#####
			#####if h < -0.35:
				#####grid[x][y].type = "deep_water"
			#####elif h < -0.1:
				#####grid[x][y].type = "shallow_water"
			#####elif h < 0.25:
				#####grid[x][y].type = "lowland"
			#####elif h < 0.55:
				#####grid[x][y].type = "ground"
			#####else:
				#####grid[x][y].type = "highland"
#####
#####func _place_resource_deposits():
	#####"""Place resource deposits with GUARANTEED spawning of all types"""
	#####print("=== RESOURCE GENERATION START ===")
#####
	###### GUARANTEED minimum counts for each resource (Anno-style distribution)
	#####var guaranteed_deposits = {
		#####"minerals": 50,        # Very common - basic material
		#####"wood": 50,            # Very common - basic material
		#####"ore": 40,             # Common - quality alloys
		#####"water": 50,           # Uncommon - essential
		#####"hydrogen": 30,        # Uncommon - energy/fuel
		#####"biomatter": 20,       # Uncommon - growth
		#####"rare_minerals": 10    # Rare - high-tech
	#####}
	#####
	#####print("Guaranteed deposits per resource (Anno-style):")
	#####for res_id in guaranteed_deposits:
		#####print("  %s: %d clusters minimum" % [res_id, guaranteed_deposits[res_id]])
	#####
	###### Place each resource type with guaranteed counts
	#####for resource_id in guaranteed_deposits:
		#####var cluster_count = guaranteed_deposits[resource_id]
		#####_place_resource_type_guaranteed(resource_id, cluster_count)
	#####
	#####print("=== RESOURCE GENERATION COMPLETE ===")
#####
#####func _place_resource_type_guaranteed(resource_id: String, cluster_count: int):
	#####"""Place a specific number of clusters for a resource - GUARANTEED"""
	#####var placed_clusters = 0
	#####var attempts = 0
	#####var max_attempts = cluster_count * 20  # Give plenty of attempts
	#####
	#####var cluster_size_range = [3, 4, 5, 6, 7, 8]  # Decent sized clusters
	#####
	#####print("Placing %s: target %d clusters" % [resource_id, cluster_count])
	#####
	#####while placed_clusters < cluster_count and attempts < max_attempts:
		#####attempts += 1
		#####
		###### Pick random position (avoid center spawn area)
		#####var x = randi() % grid_width
		#####var y = randi() % grid_height
		#####var start_pos = Vector2i(x, y)
		#####
		#####var center = Vector2i(grid_width / 2, grid_height / 2)
		#####if start_pos.distance_to(center) < 10:
			#####continue  # Too close to spawn
		#####
		###### Check if position is free
		#####if start_pos in resource_deposits:
			#####continue
		#####var tile_type = grid[start_pos.x][start_pos.y].type
		#####if tile_type in ["deep_water", "shallow_water"]:
			#####continue
		#####
		###### Check minimum spacing (3 tiles) from other deposits
		#####var too_close = false
		#####for existing_pos in resource_deposits:
			#####if start_pos.distance_to(existing_pos) < 3:
				#####too_close = true
				#####break
		#####
		#####if too_close:
			#####continue
		#####
		###### Create cluster
		#####var size = cluster_size_range[randi() % cluster_size_range.size()]
		#####var cluster = _grow_organic_cluster(start_pos, size)
		#####if cluster.size() < 3:
			#####continue
		#####
		###### Place cluster
		#####for tile_pos in cluster:
			#####if tile_pos not in resource_deposits:
				#####resource_deposits[tile_pos] = resource_id
				#####grid[tile_pos.x][tile_pos.y].resource = resource_id
		#####
		#####placed_clusters += 1
	#####
	#####print("  ✓ Placed %d/%d clusters of %s (attempts: %d)" % [placed_clusters, cluster_count, resource_id, attempts])
#####
#####func _grow_organic_cluster(start: Vector2i, target_size: int) -> Array[Vector2i]:
	#####"""Grow a natural-looking resource cluster"""
	#####var cluster: Array[Vector2i] = [start]
	#####var frontier: Array[Vector2i] = [start]
	#####
	#####var directions = [
		#####Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		#####Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
	#####]
	#####
	#####while cluster.size() < target_size and frontier.size() > 0:
		###### Pick random tile from frontier
		#####var idx = randi() % frontier.size()
		#####var current = frontier[idx]
		#####
		###### Try to expand
		#####directions.shuffle()
		#####var expanded = false
		#####
		#####for dir in directions:
			#####var new_pos = current + dir
			#####
			###### Validate
			#####if not is_valid_pos(new_pos):
				#####continue
			#####if new_pos in cluster:
				#####continue
			#####if new_pos in resource_deposits:
				#####continue
			#####var tile_type = grid[new_pos.x][new_pos.y].type
			#####if tile_type in ["deep_water", "shallow_water"]:
				#####continue
			#####
			###### Add with some randomness (70% chance to keep organic shape)
			#####if randf() < 0.7:
				#####cluster.append(new_pos)
				#####frontier.append(new_pos)
				#####expanded = true
				#####break
		#####
		###### Remove from frontier if couldn't expand or randomly
		#####if not expanded or randf() < 0.4:
			#####frontier.remove_at(idx)
	#####
	#####return cluster
#####
#####func _add_quad_to_mesh(st: SurfaceTool, pos: Vector3, color: Color):
	#####"""Add single tile quad to mesh"""
	#####var h = TILE_SIZE * 0.475  # Small gap between tiles
	#####
	#####var v0 = Vector3(pos.x - h, 0, pos.z - h)
	#####var v1 = Vector3(pos.x + h, 0, pos.z - h)
	#####var v2 = Vector3(pos.x + h, 0, pos.z + h)
	#####var v3 = Vector3(pos.x - h, 0, pos.z + h)
	#####
	###### Triangle 1
	#####st.set_color(color)
	#####st.add_vertex(v0)
	#####st.add_vertex(v1)
	#####st.add_vertex(v2)
	#####
	###### Triangle 2
	#####st.add_vertex(v0)
	#####st.add_vertex(v2)
	#####st.add_vertex(v3)
#####
#####func _get_tile_color_fast(tile_data: Dictionary) -> Color:
	#####"""Fast color lookup"""
	###### Resource color takes priority
	#####if tile_data.resource:
		#####var res = GameData.get_resource_by_id(tile_data.resource)
		#####if res:
			#####return res.color * 1.0  # Bright
	#####
	###### Terrain color
	#####match tile_data.type:
		#####"deep_water": return Color(0.05, 0.1, 0.2)
		#####"shallow_water": return Color(0.1, 0.2, 0.3)
		#####"lowland": return Color(0.25, 0.4, 0.25)
		#####"ground": return Color(0.35, 0.35, 0.35)
		#####"highland": return Color(0.5, 0.45, 0.4)
	#####
	#####return Color(0.35, 0.35, 0.35)
#####
#####func _create_chunk_mesh(chunk_coord: Vector2i) -> MeshInstance3D:
	#####"""Build single mesh for entire chunk"""
	#####var st = SurfaceTool.new()
	#####st.begin(Mesh.PRIMITIVE_TRIANGLES)
	#####
	#####var sx = chunk_coord.x * CHUNK_SIZE
	#####var sy = chunk_coord.y * CHUNK_SIZE
	#####var ex = min(sx + CHUNK_SIZE, grid_width)
	#####var ey = min(sy + CHUNK_SIZE, grid_height)
	#####
	#####for x in range(sx, ex):
		#####for y in range(sy, ey):
			#####var tile_data = grid[x][y]
			#####var color = _get_tile_color_fast(tile_data)
			#####var world_pos = grid_to_world(Vector2i(x, y))
			#####_add_quad_to_mesh(st, world_pos, color)
	#####
	#####st.generate_normals()
	#####var mesh = st.commit()
	#####
	#####var mi = MeshInstance3D.new()
	#####mi.mesh = mesh
	#####
	#####var mat = StandardMaterial3D.new()
	#####mat.vertex_color_use_as_albedo = true
	#####mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	#####mi.material_override = mat
	#####
	#####return mi
#####
#####func _create_visual_grid():
	#####"""Create optimized chunked grid"""
	#####var chunks_x = ceili(grid_width / float(CHUNK_SIZE))
	#####var chunks_y = ceili(grid_height / float(CHUNK_SIZE))
	#####
	#####print("🚀 Creating %d chunks instead of %d tiles!" % [chunks_x * chunks_y, grid_width * grid_height])
	#####
	#####for chunk_x in range(chunks_x):
		#####for chunk_y in range(chunks_y):
			#####var chunk_coord = Vector2i(chunk_x, chunk_y)
			#####var chunk_mesh = _create_chunk_mesh(chunk_coord)
			#####if chunk_mesh:
				#####chunk_meshes[chunk_coord] = chunk_mesh
				#####add_child(chunk_mesh)
#####
####
####
#####func highlight_tile(grid_pos: Vector2i, color: Color):
	#####"""Highlight a tile (for cursor preview)"""
	#####if grid_pos in tile_meshes:
		#####var tile = tile_meshes[grid_pos]
		#####var material = tile.material_override as StandardMaterial3D
		#####if material:
			#####material = material.duplicate()
			#####material.emission_enabled = true
			#####material.emission = color
			#####material.emission_energy = 0.5
			#####tile.material_override = material
#####
#####func clear_highlight(grid_pos: Vector2i):
	#####"""Remove highlight from tile"""
	#####if grid_pos in tile_meshes:
		###### Recreate original material
		#####var tile_data = grid[grid_pos.x][grid_pos.y]
		#####var tile = tile_meshes[grid_pos]
		#####
		#####var material = StandardMaterial3D.new()
		#####if tile_data.type == "deep_water":
			#####material.albedo_color = Color(0.05, 0.1, 0.2)
		#####elif tile_data.type == "shallow_water":
			#####material.albedo_color = Color(0.1, 0.2, 0.3)
		#####elif tile_data.type == "lowland":
			#####material.albedo_color = Color(0.25, 0.4, 0.25)
		#####elif tile_data.type == "ground":
			#####material.albedo_color = Color(0.35, 0.35, 0.35)
		#####elif tile_data.type == "highland":
			#####material.albedo_color = Color(0.5, 0.45, 0.4)
		#####
		#####if tile_data.resource:
			#####var resource = GameData.get_resource_by_id(tile_data.resource)
			#####if resource:
				#####material.albedo_color = resource.color * 0.5
				#####material.emission_enabled = true
				#####material.emission = resource.color * 0.3
		#####
		#####tile.material_override = material
#####
#####func clear_tile(grid_pos: Vector2i):
	#####"""Clear a tile - remove building and reset to ground"""
	#####if not is_valid_pos(grid_pos):
		#####return
	#####
	#####grid[grid_pos.x][grid_pos.y].occupied = false
	#####grid[grid_pos.x][grid_pos.y].building = ""
	#####grid[grid_pos.x][grid_pos.y].building_origin = null
################################################################################
######extends Node3D
######class_name TileGrid
####### TileGrid - Manages the tile-based grid for building placement
######
######const TILE_SIZE = 2.0  # Size of each tile in world units
######
######@export var grid_width: int = 50
######@export var grid_height: int = 50
######
####### Grid data: grid[x][y] = {type, resource, building, etc}
######var grid: Array = []
######
####### Visual tile meshes
######var tile_meshes: Dictionary = {}  # {Vector2i: MeshInstance3D}
######
####### Resource deposits on this planet
######var resource_deposits: Dictionary = {}  # {Vector2i: resource_id}
######
######func _ready():
	######_initialize_grid()
	######_generate_terrain()
	######_place_resource_deposits()
	######_create_visual_grid()
######
######func _initialize_grid():
	######"""Create empty grid"""
	######grid = []
	######for x in range(grid_width):
		######var column = []
		######for y in range(grid_height):
			######column.append({
				######"type": "ground",
				######"building": null,
				######"resource": null,
				######"occupied": false
			######})
		######grid.append(column)
######
######func _generate_terrain():
	######"""Generate basic terrain variation"""
	######var noise = FastNoiseLite.new()
	######noise.seed = randi()
	######noise.frequency = 0.05
	######
	######for x in range(grid_width):
		######for y in range(grid_height):
			######var height = noise.get_noise_2d(x, y)
			######
			####### Assign terrain type based on height
			######if height > 0.3:
				######grid[x][y].type = "highland"
			######elif height < -0.3:
				######grid[x][y].type = "lowland"
			######else:
				######grid[x][y].type = "ground"
######
######func _place_resource_deposits():
	######"""Place resource deposits with GUARANTEED spawning of all types"""
	######print("=== RESOURCE GENERATION START ===")
	######
	####### GUARANTEED minimum counts for each resource
	######var guaranteed_deposits = {
		######"minerals": 30,    # Very common
		######"ore": 25,         # Common
		######"hydrogen": 20,    # Needed for energy!
		######"biomatter": 15,   # Needed for growth!
		######"water": 12,       # Medium
		######"crystals": 8      # Rare but guaranteed
	######}
	######
	######print("Guaranteed deposits per resource:")
	######for res_id in guaranteed_deposits:
		######print("  %s: %d clusters minimum" % [res_id, guaranteed_deposits[res_id]])
	######
	####### Place each resource type with guaranteed counts
	######for resource_id in guaranteed_deposits:
		######var cluster_count = guaranteed_deposits[resource_id]
		######_place_resource_type_guaranteed(resource_id, cluster_count)
	######
	######print("=== RESOURCE GENERATION COMPLETE ===")
######
######func _place_resource_type_guaranteed(resource_id: String, cluster_count: int):
	######"""Place a specific number of clusters for a resource - GUARANTEED"""
	######var placed_clusters = 0
	######var attempts = 0
	######var max_attempts = cluster_count * 10  # Give plenty of attempts
	######
	######var cluster_size_range = [3, 4, 5, 6, 7, 8]  # Decent sized clusters
	######
	######print("Placing %s: target %d clusters" % [resource_id, cluster_count])
	######
	######while placed_clusters < cluster_count and attempts < max_attempts:
		######attempts += 1
		######
		####### Pick random position (avoid center spawn area)
		######var x = randi() % grid_width
		######var y = randi() % grid_height
		######var start_pos = Vector2i(x, y)
		######
		######var center = Vector2i(grid_width / 2, grid_height / 2)
		######if start_pos.distance_to(center) < 10:
			######continue  # Too close to spawn
		######
		####### Check if position is free
		######if start_pos in resource_deposits:
			######continue
		######
		####### Check minimum spacing (3 tiles) from other deposits
		######var too_close = false
		######for existing_pos in resource_deposits:
			######if start_pos.distance_to(existing_pos) < 3:
				######too_close = true
				######break
		######
		######if too_close:
			######continue
		######
		####### Create cluster
		######var size = cluster_size_range[randi() % cluster_size_range.size()]
		######var cluster = _grow_organic_cluster(start_pos, size)
		######
		####### Place cluster
		######for tile_pos in cluster:
			######if tile_pos not in resource_deposits:
				######resource_deposits[tile_pos] = resource_id
				######grid[tile_pos.x][tile_pos.y].resource = resource_id
		######
		######placed_clusters += 1
	######
	######print("  ✓ Placed %d/%d clusters of %s (attempts: %d)" % [placed_clusters, cluster_count, resource_id, attempts])
######
######func _grow_organic_cluster(start: Vector2i, target_size: int) -> Array[Vector2i]:
	######"""Grow a natural-looking resource cluster"""
	######var cluster: Array[Vector2i] = [start]
	######var frontier: Array[Vector2i] = [start]
	######
	######var directions = [
		######Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		######Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
	######]
	######
	######while cluster.size() < target_size and frontier.size() > 0:
		####### Pick random tile from frontier
		######var idx = randi() % frontier.size()
		######var current = frontier[idx]
		######
		####### Try to expand
		######directions.shuffle()
		######var expanded = false
		######
		######for dir in directions:
			######var new_pos = current + dir
			######
			####### Validate
			######if not is_valid_pos(new_pos):
				######continue
			######if new_pos in cluster:
				######continue
			######if new_pos in resource_deposits:
				######continue
			######
			####### Add with some randomness (70% chance to keep organic shape)
			######if randf() < 0.7:
				######cluster.append(new_pos)
				######frontier.append(new_pos)
				######expanded = true
				######break
		######
		####### Remove from frontier if couldn't expand or randomly
		######if not expanded or randf() < 0.4:
			######frontier.remove_at(idx)
	######
	######return cluster
######
######func _create_visual_grid():
	######"""Create visual representation of tiles"""
	######for x in range(grid_width):
		######for y in range(grid_height):
			######var pos = Vector2i(x, y)
			######var tile_mesh = _create_tile_visual(pos)
			######tile_meshes[pos] = tile_mesh
			######add_child(tile_mesh)
######
######func _create_tile_visual(grid_pos: Vector2i) -> MeshInstance3D:
	######"""Create a single tile mesh"""
	######var mesh_instance = MeshInstance3D.new()
	######var plane = PlaneMesh.new()
	######plane.size = Vector2(TILE_SIZE * 0.95, TILE_SIZE * 0.95)  # Small gap between tiles
	######mesh_instance.mesh = plane
	######
	####### Position in world
	######var world_pos = grid_to_world(grid_pos)
	######mesh_instance.position = world_pos
	####### Tiles are naturally horizontal planes in Godot
	######
	####### Color based on terrain and resources
	######var material = StandardMaterial3D.new()
	######var tile_data = grid[grid_pos.x][grid_pos.y]
	######
	####### Base color by terrain
	######if tile_data.type == "highland":
		######material.albedo_color = Color(0.4, 0.35, 0.3)
	######elif tile_data.type == "lowland":
		######material.albedo_color = Color(0.25, 0.3, 0.25)
	######else:
		######material.albedo_color = Color(0.35, 0.35, 0.35)
	######
	####### Highlight if has resources
	######if tile_data.resource:
		######var resource = GameData.get_resource_by_id(tile_data.resource)
		######if resource:
			######material.albedo_color = resource.color * 0.6  # Brighter base
			######material.emission_enabled = true
			######material.emission = resource.color * 0.8  # Much brighter glow
			######material.emission_energy = 1.5  # Even more visible
	######
	######mesh_instance.material_override = material
	######
	####### Store grid position for raycasting
	######mesh_instance.set_meta("grid_pos", grid_pos)
	######
	######return mesh_instance
######
######func grid_to_world(grid_pos: Vector2i) -> Vector3:
	######"""Convert grid coordinates to world position"""
	######return Vector3(
		######grid_pos.x * TILE_SIZE - (grid_width * TILE_SIZE / 2),
		######0,
		######grid_pos.y * TILE_SIZE - (grid_height * TILE_SIZE / 2)
	######)
######
######func world_to_grid(world_pos: Vector3) -> Vector2i:
	######"""Convert world position to grid coordinates"""
	######var x = int((world_pos.x + (grid_width * TILE_SIZE / 2)) / TILE_SIZE)
	######var y = int((world_pos.z + (grid_height * TILE_SIZE / 2)) / TILE_SIZE)
	######return Vector2i(x, y)
######
######func is_valid_pos(grid_pos: Vector2i) -> bool:
	######"""Check if grid position is within bounds"""
	######return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   ######grid_pos.y >= 0 and grid_pos.y < grid_height
######
######func can_place_building(grid_pos: Vector2i, building_size: Vector2i) -> bool:
	######"""Check if a building can be placed at position"""
	####### Check all tiles the building would occupy
	######for dx in range(building_size.x):
		######for dy in range(building_size.y):
			######var check_pos = grid_pos + Vector2i(dx, dy)
			######
			######if not is_valid_pos(check_pos):
				######return false
			######
			######if grid[check_pos.x][check_pos.y].occupied:
				######return false
	######
	######return true
######
######func place_building(grid_pos: Vector2i, building_id: String) -> bool:
	######"""Place a building on the grid"""
	######var building = GameData.get_building_by_id(building_id)
	######if building.is_empty():
		######return false
	######
	######var size = building.size
	######
	######if not can_place_building(grid_pos, size):
		######return false
	######
	####### Mark tiles as occupied
	######for dx in range(size.x):
		######for dy in range(size.y):
			######var tile_pos = grid_pos + Vector2i(dx, dy)
			######grid[tile_pos.x][tile_pos.y].occupied = true
			######grid[tile_pos.x][tile_pos.y].building = building_id
	######
	######return true
######
######func get_tile_info(grid_pos: Vector2i) -> Dictionary:
	######"""Get information about a specific tile"""
	######if not is_valid_pos(grid_pos):
		######return {}
	######
	######return grid[grid_pos.x][grid_pos.y].duplicate()
######
######func highlight_tile(grid_pos: Vector2i, color: Color):
	######"""Highlight a tile (for cursor preview)"""
	######if grid_pos in tile_meshes:
		######var tile = tile_meshes[grid_pos]
		######var material = tile.material_override as StandardMaterial3D
		######if material:
			######material = material.duplicate()
			######material.emission_enabled = true
			######material.emission = color
			######material.emission_energy = 0.5
			######tile.material_override = material
######
######func clear_highlight(grid_pos: Vector2i):
	######"""Remove highlight from tile"""
	######if grid_pos in tile_meshes:
		####### Recreate original material
		######var tile_data = grid[grid_pos.x][grid_pos.y]
		######var tile = tile_meshes[grid_pos]
		######
		######var material = StandardMaterial3D.new()
		######if tile_data.type == "highland":
			######material.albedo_color = Color(0.4, 0.35, 0.3)
		######elif tile_data.type == "lowland":
			######material.albedo_color = Color(0.25, 0.3, 0.25)
		######else:
			######material.albedo_color = Color(0.35, 0.35, 0.35)
		######
		######if tile_data.resource:
			######var resource = GameData.get_resource_by_id(tile_data.resource)
			######if resource:
				######material.albedo_color = resource.color * 0.5
				######material.emission_enabled = true
				######material.emission = resource.color * 0.3
		######
		######tile.material_override = material
