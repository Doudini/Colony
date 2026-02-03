extends Node3D
# PlanetSurface - Main scene for managing a planet colony

@onready var camera = $IsometricCamera
@onready var tile_grid = $TileGrid
@onready var building_manager = $BuildingManager
@onready var ui = $UI
@onready var hover_detector = $HoverDetector
@onready var upkeep_manager = $UpkeepManager
@onready var resource_tracker = $ResourceTracker
@onready var building_control = $BuildingControl

func _ready():
	# Setup references
	building_manager.tile_grid = tile_grid
	ui.setup(building_manager)
	
	# Setup resource tracker
	if resource_tracker:
		resource_tracker.building_manager = building_manager
		resource_tracker.upkeep_manager = upkeep_manager
	
	# Setup hover detector
	var tooltip = get_node_or_null("TooltipLayer/BuildingTooltip")
	if tooltip and hover_detector:
		hover_detector.setup(camera, tile_grid, building_manager, tooltip)
	
	# Setup debug overlay
	if has_node("DebugOverlay"):
		var debug = $DebugOverlay
		debug.setup(tile_grid, camera)
	
	# Connect building control signals
	if building_control:
		building_manager.building_right_clicked.connect(_on_building_right_clicked)
		building_manager.building_placed.connect(_on_building_placed_check)
	
	# Place starting landing pad
	_place_starting_building()
	
	print("==================================================")
	print("Colony Manager Ready!")
	print("==================================================")
	print("Controls:")
	print("  WASD - Move camera (relative to view)")
	print("  Q/E - Rotate camera")
	print("  Mouse Wheel - Zoom")
	print("  Middle Mouse - Pan")
	print("  Hover - Show building/tile info")
	print("  Right-click building - Pause/Resume/Demolish")
	print("==================================================")
	print("📊 Resources - Click '📊 Resources' button")
	print("🔬 Tech Tree - Build R&D to unlock")
	print("==================================================")

func _process(delta):
	GameState.tick_research(delta)

func _on_building_right_clicked(grid_pos: Vector2i, building_id: String, world_pos: Vector3):
	"""Handle building right-click - show context menu"""
	print("🖱️ Right-clicked building at %s" % grid_pos)
	var is_paused = building_control.is_paused(grid_pos)
	print("   Pause state from BuildingControl: %s" % is_paused)
	print("   Paused buildings dict: %s" % building_control.paused_buildings)
	ui.show_building_context_menu(grid_pos, building_id, world_pos, is_paused)

func _on_building_placed_check(building_id: String, grid_pos: Vector2i):
	"""Check if placed building is valid (for miners on empty tiles)"""
	var building_data = GameData.get_building_by_id(building_id)
	
	# Check if it's a miner/extractor
	if building_data.get("extraction_rate", 0) > 0:
		var tile_info = tile_grid.get_tile_info(grid_pos)
		var resource = tile_info.get("resource", null)
		
		if resource == null or resource == "":
			# Misplaced miner!
			ui.show_misplaced_miner_warning(grid_pos)

func _place_starting_building():
	"""Place the initial landing pad on LAND near ocean"""
	# Find a good spawn location
	var spawn_pos = _find_landing_spot()
	
	if spawn_pos == Vector2i(-1, -1):
		print("❌ ERROR: Could not find suitable landing spot!")
		spawn_pos = Vector2i(tile_grid.grid_width / 2, tile_grid.grid_height / 2)
	
	tile_grid.place_building(spawn_pos, "landing_pad")
	building_manager._create_building(spawn_pos, "landing_pad")
	
	# Focus camera on starting position
	var world_pos = tile_grid.grid_to_world(spawn_pos)
	# Center camera on the landing pad properly
	var building_data = GameData.get_building_by_id("landing_pad")
	if building_data.size.x > 1:
		world_pos.x += (building_data.size.x * tile_grid.TILE_SIZE) / 2.0
		world_pos.z += (building_data.size.y * tile_grid.TILE_SIZE) / 2.0
	camera.target_position = Vector3(world_pos.x, 0, world_pos.z)
	camera.focus_on_position(world_pos)
	
	print("🚀 Landing pad placed at grid position: %s" % spawn_pos)

func _find_landing_spot() -> Vector2i:
	"""Find a suitable landing spot: land tile near ocean, with space for landing pad"""
	var center = Vector2i(tile_grid.grid_width / 2, tile_grid.grid_height / 2)
	var building_data = GameData.get_building_by_id("landing_pad")
	var pad_size = building_data.size
	
	# Strategy: Spiral search from center, looking for land near water
	var search_radius = 50
	var best_pos = Vector2i(-1, -1)
	var best_score = -999999
	
	for radius in range(5, search_radius):
		for angle in range(0, 360, 10):  # Check every 10 degrees
			var rad = deg_to_rad(angle)
			var x = center.x + int(radius * cos(rad))
			var y = center.y + int(radius * sin(rad))
			var pos = Vector2i(x, y)
			
			# Check if landing pad can be placed here
			if not tile_grid.can_place_building(pos, pad_size):
				continue
			
			# Check if it's on land
			if not _is_land_area(pos, pad_size):
				continue
			
			# Score this position (prefer coastal locations)
			var score = _score_landing_position(pos, pad_size)
			
			if score > best_score:
				best_score = score
				best_pos = pos
				
				# If we found a really good spot, use it
				if score > 100:
					return best_pos
	
	return best_pos

func _is_land_area(grid_pos: Vector2i, size: Vector2i) -> bool:
	"""Check if entire area is on land (not water)"""
	for dx in range(size.x):
		for dy in range(size.y):
			var check_pos = grid_pos + Vector2i(dx, dy)
			if not tile_grid.is_valid_pos(check_pos):
				return false
			
			var tile_info = tile_grid.get_tile_info(check_pos)
			if tile_info.type in ["deep_water", "shallow_water"]:
				return false
	
	return true

func _score_landing_position(grid_pos: Vector2i, size: Vector2i) -> int:
	"""Score a landing position (higher = better)"""
	var score = 0
	
	# Check 10-tile radius around landing pad
	var search_radius = 10
	var water_tiles = 0
	var land_tiles = 0
	var resource_tiles = 0
	
	for dx in range(-search_radius, search_radius + 1):
		for dy in range(-search_radius, search_radius + 1):
			var check_pos = grid_pos + Vector2i(dx, dy)
			
			if not tile_grid.is_valid_pos(check_pos):
				continue
			
			var tile_info = tile_grid.get_tile_info(check_pos)
			
			# Count tile types
			if tile_info.type in ["deep_water", "shallow_water"]:
				water_tiles += 1
			else:
				land_tiles += 1
			
			# Bonus for nearby resources
			if tile_info.resource != null and tile_info.resource != "":
				resource_tiles += 1
	
	# Scoring criteria:
	# 1. Must have SOME water nearby (coastal feel)
	if water_tiles > 0 and water_tiles < 50:
		score += 50  # Coastal bonus
	
	# 2. Prefer more land (room to expand)
	score += land_tiles
	
	# 3. Bonus for nearby resources (but not too close)
	if resource_tiles > 0 and resource_tiles < 20:
		score += resource_tiles * 5
	
	# 4. Penalty if too much water (island too small)
	if water_tiles > 100:
		score -= 100
	
	return score
