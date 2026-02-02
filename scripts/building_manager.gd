extends Node3D
class_name BuildingManager
# Manages building placement and visualization

@export var tile_grid: TileGrid

var placed_buildings: Dictionary = {}  # {grid_pos: Building instance}
var preview_building: Node3D = null
var current_building_id: String = ""
var is_placing: bool = false

var selected_building_pos: Vector2i = Vector2i(-1, -1)
var selected_building_id: String = ""

# Track extraction timers so we can stop them
var extraction_timers: Dictionary = {}  # {grid_pos: Timer}
var extraction_accumulators: Dictionary = {}  # {grid_pos: float}

# Store original building colors and emission for resume
var building_materials: Dictionary = {}  # {grid_pos: {albedo: Color, emission: Color, emission_enabled: bool}}

signal building_placed(building_id: String, grid_pos: Vector2i)
signal building_placement_failed(reason: String)
signal building_selected(grid_pos: Vector2i, building_id: String)
signal building_right_clicked(grid_pos: Vector2i, building_id: String, world_pos: Vector3)

func start_placement(building_id: String):
	"""Start placing a building"""
	current_building_id = building_id
	is_placing = true
	_create_preview()

func cancel_placement():
	"""Cancel current placement"""
	is_placing = false
	current_building_id = ""
	if preview_building:
		preview_building.queue_free()
		preview_building = null
	
	# Hide placement tooltip
	var ui = get_tree().root.get_node_or_null("PlanetSurface/UI")
	if ui:
		ui.hide_placement_tooltip()

func _create_preview():
	"""Create visual preview of building being placed"""
	if preview_building:
		preview_building.queue_free()
	
	var building_data = GameData.get_building_by_id(current_building_id)
	if building_data.is_empty():
		return
	
	preview_building = Node3D.new()
	
	# Create a mesh for the building footprint
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(
		building_data.size.x * tile_grid.TILE_SIZE,
		1.0,
		building_data.size.y * tile_grid.TILE_SIZE
	)
	mesh_instance.mesh = box
	mesh_instance.position.y = 0.5
	
	var material = StandardMaterial3D.new()
	material.albedo_color = building_data.color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.5
	mesh_instance.material_override = material
	
	preview_building.add_child(mesh_instance)
	add_child(preview_building)

func _process(_delta):
	if is_placing and preview_building:
		_update_preview()

func _update_preview():
	"""Update preview building position and color"""
	var camera = get_viewport().get_camera_3d() as IsometricCamera
	if not camera:
		return
	
	var mouse_pos = camera.get_mouse_world_position()
	var grid_pos = tile_grid.world_to_grid(mouse_pos)
	
	if tile_grid.is_valid_pos(grid_pos):
		# Get building data
		var building_data = GameData.get_building_by_id(current_building_id)
		
		# Position EXACTLY like the actual building
		var world_pos = tile_grid.grid_to_world(grid_pos)
		
		# For multi-tile, offset to center of footprint
		if building_data.size.x > 1 or building_data.size.y > 1:
			var extra_offset_x = (building_data.size.x - 1) / 2.0
			var extra_offset_z = (building_data.size.y - 1) / 2.0
			
			world_pos.x += extra_offset_x * tile_grid.TILE_SIZE
			world_pos.z += extra_offset_z * tile_grid.TILE_SIZE
		
		world_pos.y = 0.5
		preview_building.position = world_pos
		
		# Check if can place
		var can_place = tile_grid.can_place_building(grid_pos, building_data.size)
		var can_afford = GameData.can_afford_building(current_building_id, GameState.resources)
		
		# Check placement requirements
		var requirement = building_data.get("placement_requirement", "")
		var meets_requirement = true
		if requirement != "":
			meets_requirement = _check_placement_requirement(grid_pos, building_data.size, requirement)
		
		# Update preview color
		var mesh = preview_building.get_child(0) as MeshInstance3D
		var material = mesh.material_override as StandardMaterial3D
		
		if can_place and can_afford and meets_requirement:
			material.albedo_color = Color(0.3, 1.0, 0.3, 0.7)  # Green = OK
		elif not can_afford:
			material.albedo_color = Color(1.0, 0.5, 0.0, 0.7)  # Orange = Can't afford
		elif not meets_requirement:
			material.albedo_color = Color(1.0, 0.0, 1.0, 0.7)  # Purple = Wrong location
		else:
			material.albedo_color = Color(1.0, 0.3, 0.3, 0.7)  # Red = Can't place
		
		# Update placement tooltip
		var ui = get_tree().root.get_node_or_null("PlanetSurface/UI")
		if ui:
			var screen_mouse_pos = get_viewport().get_mouse_position()
			ui.show_placement_tooltip(current_building_id, can_place and meets_requirement, can_afford)
			ui.update_placement_tooltip_position(screen_mouse_pos)

func _input(event):
	if not is_placing:
		# Check for right-click on buildings when not placing
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				print("🖱️ Right-click event received!")
				# Don't show context menu if clicking on UI
				if _is_mouse_over_ui():
					print("⚠️ Mouse is over UI, ignoring")
					return
				print("✅ Processing right-click on game world")
				_check_building_right_click(event.position)
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if mouse is over UI
			if _is_mouse_over_ui():
				return  # Don't place if clicking on UI
			_try_place_building()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_placement()

func _check_building_right_click(mouse_pos: Vector2):
	"""Check if right-clicked on a building - using tile-based detection"""
	var camera = get_viewport().get_camera_3d() as IsometricCamera
	if not camera:
		print("❌ No camera")
		return
	
	# Use the same method as hover detection - much simpler!
	var mouse_world = camera.get_mouse_world_position()
	print("📍 Mouse world position: %s" % mouse_world)
	
	var grid_pos = tile_grid.world_to_grid(mouse_world)
	print("📐 Grid position: %s" % grid_pos)
	
	if not tile_grid.is_valid_pos(grid_pos):
		print("❌ Grid position invalid")
		return
	
	print("✅ Grid position is valid")
	
	# Get tile info
	var tile_info = tile_grid.get_tile_info(grid_pos)
	print("📋 Tile info: %s" % tile_info)
	
	var building_id = tile_info.get("building", "")
	print("🏢 Building ID: '%s'" % building_id)
	
	if building_id != "" and building_id != null:
		# Get the building origin (for multi-tile buildings)
		var building_origin = tile_info.get("building_origin", grid_pos)
		print("📍 Building origin: %s" % building_origin)
		print("✅✅✅ Emitting building_right_clicked signal!")
		building_right_clicked.emit(building_origin, building_id, mouse_world)
	else:
		print("❌ No building on this tile")

func _is_mouse_over_ui() -> bool:
	"""Check if mouse is over any UI element"""
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Get all UI panels
	var ui_root = get_tree().root.get_node_or_null("PlanetSurface/UI")
	if ui_root:
		var panel = ui_root.get_node_or_null("Panel")
		if panel and panel is Control:
			var rect = panel.get_global_rect()
			if rect.has_point(mouse_pos):
				return true
	
	# Check debug overlay
	var debug = get_tree().root.get_node_or_null("PlanetSurface/DebugOverlay")
	if debug:
		var debug_panel = debug.get_node_or_null("Panel")
		if debug_panel and debug_panel is Control:
			var rect = debug_panel.get_global_rect()
			if rect.has_point(mouse_pos):
				return true
	
	return false

func _try_place_building():
	"""Attempt to place the current building"""
	var camera = get_viewport().get_camera_3d() as IsometricCamera
	if not camera:
		return
	
	var mouse_pos = camera.get_mouse_world_position()
	var grid_pos = tile_grid.world_to_grid(mouse_pos)
	
	var building_data = GameData.get_building_by_id(current_building_id)
	if building_data.is_empty():
		return
	
	# Check placement validity
	if not tile_grid.can_place_building(grid_pos, building_data.size):
		building_placement_failed.emit("Cannot place building here - tiles occupied")
		return
	
	# Check special placement requirements
	var requirement = building_data.get("placement_requirement", "")
	if requirement != "":
		if not _check_placement_requirement(grid_pos, building_data.size, requirement):
			building_placement_failed.emit("Invalid location - check placement requirement")
			return
	
	# Check affordability
	if not GameState.has_resources(building_data.build_cost):
		building_placement_failed.emit("Not enough resources to build")
		return
	
	# Deduct resources
	GameState.deduct_resources(building_data.build_cost)
	
	# Place on grid
	tile_grid.place_building(grid_pos, current_building_id)
	
	# Create actual building
	_create_building(grid_pos, current_building_id)
	
	# Emit signal
	building_placed.emit(current_building_id, grid_pos)
	
	# Check for special buildings
	if building_data.get("special", "") == "enables_space_travel":
		GameState.unlock_space_travel()
	
	print("Built %s at %s" % [building_data.name, grid_pos])

func _create_building(grid_pos: Vector2i, building_id: String):
	"""Create the actual building in the world"""
	var building_data = GameData.get_building_by_id(building_id)
	if building_data.is_empty():
		return
	
	var building = Node3D.new()
	building.name = "%s_%s" % [building_id, grid_pos]
	
	# Create mesh
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(
		building_data.size.x * tile_grid.TILE_SIZE * 0.9,
		2.0,
		building_data.size.y * tile_grid.TILE_SIZE * 0.9
	)
	mesh_instance.mesh = box
	mesh_instance.position.y = 1.0
	
	var material = StandardMaterial3D.new()
	material.albedo_color = building_data.color
	material.metallic = 0.3
	material.roughness = 0.7
	
	# If it's an extractor, add emission matching the resource
	if building_data.get("extraction_rate", 0) > 0:
		var tile_info = tile_grid.get_tile_info(grid_pos)
		var resource_on_tile = tile_info.get("resource", null)
		if resource_on_tile != null and resource_on_tile != "":
			var resource = GameData.get_resource_by_id(resource_on_tile)
			if not resource.is_empty():
				material.emission_enabled = true
				material.emission = resource.color
				material.emission_energy = 0.5
	
	mesh_instance.material_override = material
	
	building.add_child(mesh_instance)
	
	# Store original material state for later restoration
	building_materials[grid_pos] = {
		"albedo": material.albedo_color,
		"emission": material.emission,
		"emission_enabled": material.emission_enabled
	}
	
	# Position in world
	var world_pos = tile_grid.grid_to_world(grid_pos)
	
	# For multi-tile buildings, offset to center
	if building_data.size.x > 1 or building_data.size.y > 1:
		var extra_offset_x = (building_data.size.x - 1) / 2.0
		var extra_offset_z = (building_data.size.y - 1) / 2.0
		
		world_pos.x += extra_offset_x * tile_grid.TILE_SIZE
		world_pos.z += extra_offset_z * tile_grid.TILE_SIZE
	
	world_pos.y = 1.0
	building.position = world_pos
	
	add_child(building)
	placed_buildings[grid_pos] = building
	
	# Register with upkeep manager
	var upkeep_mgr = get_tree().root.get_node_or_null("PlanetSurface/UpkeepManager")
	if upkeep_mgr:
		upkeep_mgr.register_building(grid_pos, building_id)
	
	# Register with resource tracker
	var tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	if tracker:
		if building_data.get("extraction_rate", 0) > 0:
			var tile_info = tile_grid.get_tile_info(grid_pos)
			var resource = tile_info.get("resource", null)
			if resource:
				tracker.register_extractor(grid_pos, building_id, resource, building_data.extraction_rate)
		
		if building_data.get("production", {}).size() > 0:
			tracker.register_producer(grid_pos, building_id)
	
	# Start production or extraction
	if building_data.get("production", {}).size() > 0:
		_start_production(grid_pos, building_id)
	
	if building_data.get("extraction_rate", 0) > 0:
		_start_extraction(grid_pos, building_id)

func _start_production(grid_pos: Vector2i, building_id: String):
	"""Start a production cycle for a building"""
	var building_data = GameData.get_building_by_id(building_id)
	var production = building_data.get("production", {})
	
	if production.is_empty():
		return
	
	var time = production.get("time", 10.0)
	
	var timer = Timer.new()
	timer.wait_time = time
	timer.timeout.connect(_on_production_cycle.bind(grid_pos, building_id))
	timer.autostart = true
	add_child(timer)

func _on_production_cycle(grid_pos: Vector2i, building_id: String):
	"""Handle one production cycle"""
	var building_data = GameData.get_building_by_id(building_id)
	var production = building_data.get("production", {})
	
	if production.is_empty():
		return
	
	# Check if building is paused
	var building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	if building_control and building_control.is_paused(grid_pos):
		return  # Don't produce if paused
	
	var inputs = production.get("input", {})
	var outputs = production.get("output", {})
	
	# Check if ALL inputs are available (including energy!)
	if GameState.has_resources(inputs):
		# Consume inputs (energy, biomatter, minerals, etc.)
		GameState.deduct_resources(inputs)
		
		# Produce outputs
		for resource_id in outputs:
			var amount = outputs[resource_id]
			GameState.add_resource(resource_id, amount)
		
		update_building_state(grid_pos, "active")
	else:
		# Missing resources - building stops
		var missing = []
		for res_id in inputs:
			var needed = inputs[res_id]
			var available = GameState.resources.get(res_id, 0)
			if available < needed:
				missing.append("%s (need %.1f, have %d)" % [res_id, needed, available])
		
		print("⚠️ Building at %s stopped - missing: %s" % [grid_pos, ", ".join(missing)])
		update_building_state(grid_pos, "warning")



func _start_extraction(grid_pos: Vector2i, building_id: String):
	"""Start extracting resources from a deposit"""
	var building_data = GameData.get_building_by_id(building_id)
	var extraction_rate = building_data.get("extraction_rate", 1.0)
	
	var tile_info = tile_grid.get_tile_info(grid_pos)
	var resource_on_tile = tile_info.get("resource", null)
	
	if resource_on_tile == null or resource_on_tile == "":
		print("⚠️ WARNING: Extractor at %s has NO resource deposit!" % grid_pos)
		return
	
	print("✅ Extractor at %s will extract %.1f %s per minute" % [grid_pos, extraction_rate, resource_on_tile])
	
	var timer = Timer.new()
	timer.wait_time = 10.0
	timer.timeout.connect(_on_extraction_tick.bind(grid_pos, building_id, resource_on_tile, extraction_rate / 6.0))
	timer.autostart = true
	add_child(timer)
	
	extraction_timers[grid_pos] = timer
	extraction_accumulators[grid_pos] = 0.0

func _on_extraction_tick(grid_pos: Vector2i, building_id: String, resource_id: String, rate: float):
	"""Handle one extraction tick"""
	var building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	if building_control and building_control.is_paused(grid_pos):
		return
	
	# Upkeep manager handles energy/biomatter consumption
	# If upkeep can't be paid, efficiency drops and this still runs (but at lower rate)
	# For now, just extract at full rate - upkeep manager will handle shortages
	
	var multiplier = GameState.extraction_rate_modifiers.get(building_id, 1.0)
	var buffer = extraction_accumulators.get(grid_pos, 0.0)
	buffer += rate * multiplier
	var amount = int(floor(buffer))
	buffer -= amount
	extraction_accumulators[grid_pos] = buffer
	
	if amount > 0:
		GameState.add_resource(resource_id, amount)
		print("⛏️ Extracted %d %s at %s" % [amount, resource_id, grid_pos])


func update_building_state(grid_pos: Vector2i, state: String):
	"""Update building visual state"""
	if grid_pos not in placed_buildings:
		return
	
	var building = placed_buildings[grid_pos]
	var mesh_instance = building.get_child(0) as MeshInstance3D
	if not mesh_instance:
		return
	
	var material = mesh_instance.material_override as StandardMaterial3D
	if not material:
		return
	
	match state:
		"active":
			if grid_pos in building_materials:
				var stored = building_materials[grid_pos]
				material.albedo_color = stored.albedo
				material.emission = stored.emission
				material.emission_enabled = stored.emission_enabled
			else:
				material.albedo_color.a = 1.0
				material.emission_enabled = false
		"paused":
			material.albedo_color = Color(0.5, 0.5, 0.5, 0.7)
			material.emission_enabled = false
		"warning":
			material.emission_enabled = true
			material.emission = Color.ORANGE
			material.emission_energy = 0.3
		"error":
			material.emission_enabled = true
			material.emission = Color.RED
			material.emission_energy = 0.5

func demolish_building(grid_pos: Vector2i) -> bool:
	"""Demolish a building"""
	if grid_pos not in placed_buildings:
		return false
	
	var tile_info = tile_grid.get_tile_info(grid_pos)
	var building_id = tile_info.get("building", "")
	if building_id == "":
		return false
	
	var building_data = GameData.get_building_by_id(building_id)
	if building_data.is_empty():
		return false
	
	# Unregister from resource tracker
	var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	if resource_tracker:
		resource_tracker.unregister_building(grid_pos)
		print("📊 Unregistered from resource tracker")
	
	# Unregister from upkeep manager
	var upkeep_manager = get_tree().root.get_node_or_null("PlanetSurface/UpkeepManager")
	if upkeep_manager:
		upkeep_manager.unregister_building(grid_pos)
		print("⚙️ Unregistered from upkeep manager")
	
	# Stop extraction timer
	if grid_pos in extraction_timers:
		var timer = extraction_timers[grid_pos]
		timer.stop()
		timer.queue_free()
		extraction_timers.erase(grid_pos)
	if grid_pos in extraction_accumulators:
		extraction_accumulators.erase(grid_pos)
	
	# Remove visual
	var building = placed_buildings[grid_pos]
	building.queue_free()
	placed_buildings.erase(grid_pos)
	
	# Clean up material storage
	if grid_pos in building_materials:
		building_materials.erase(grid_pos)
	
	# Clear tiles
	for dx in range(building_data.size.x):
		for dy in range(building_data.size.y):
			var tile_pos = grid_pos + Vector2i(dx, dy)
			if tile_grid.is_valid_pos(tile_pos):
				tile_grid.clear_tile(tile_pos)
	
	print("💥 Building demolished at %s" % grid_pos)
	return true

func pause_building(grid_pos: Vector2i):
	"""Pause a building"""
	var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	if resource_tracker:
		resource_tracker.unregister_building(grid_pos)
	
	update_building_state(grid_pos, "paused")
	print("⏸️ Building paused at %s" % grid_pos)

func resume_building(grid_pos: Vector2i):
	"""Resume a building"""
	var tile_info = tile_grid.get_tile_info(grid_pos)
	var building_id = tile_info.get("building", "")
	if building_id == "":
		return
	
	var building_data = GameData.get_building_by_id(building_id)
	if building_data.is_empty():
		return
	
	# Re-register with resource tracker
	var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	if resource_tracker:
		if building_data.get("extraction_rate", 0) > 0:
			var tile = tile_grid.get_tile_info(grid_pos)
			var resource_id = tile.get("resource", "")
			if resource_id != "":
				resource_tracker.register_extractor(grid_pos, building_id, resource_id, building_data.extraction_rate)
		elif not building_data.get("production", {}).is_empty():
			resource_tracker.register_producer(grid_pos, building_id)
	
	update_building_state(grid_pos, "active")
	print("▶️ Building resumed at %s" % grid_pos)

func _check_placement_requirement(grid_pos: Vector2i, building_size: Vector2i, requirement: String) -> bool:
	"""Check special placement requirements"""
	
	if requirement == "adjacent_shallow_water":
		var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
		
		for dx in range(building_size.x):
			for dy in range(building_size.y):
				var check_pos = grid_pos + Vector2i(dx, dy)
				
				for dir in directions:
					var adjacent = check_pos + dir
					if tile_grid.is_valid_pos(adjacent):
						var tile_info = tile_grid.get_tile_info(adjacent)
						if tile_info.get("type", "") == "shallow_water":
							return true
		
		return false
	
	return true


#extends Node3D
#class_name BuildingManager
## Manages building placement and visualization
#
#@export var tile_grid: TileGrid
#
#var placed_buildings: Dictionary = {}  # {grid_pos: Building instance}
#var preview_building: Node3D = null
#var current_building_id: String = ""
#var is_placing: bool = false
#
#var selected_building_pos: Vector2i = Vector2i(-1, -1)
#var selected_building_id: String = ""
#
## Track extraction timers so we can stop them
#var extraction_timers: Dictionary = {}  # {grid_pos: Timer}
#
## Store original building colors and emission for resume
#var building_materials: Dictionary = {}  # {grid_pos: {albedo: Color, emission: Color, emission_enabled: bool}}
#
#signal building_placed(building_id: String, grid_pos: Vector2i)
#signal building_placement_failed(reason: String)
#signal building_selected(grid_pos: Vector2i, building_id: String)
#signal building_right_clicked(grid_pos: Vector2i, building_id: String, world_pos: Vector3)
#
#func start_placement(building_id: String):
	#"""Start placing a building"""
	#current_building_id = building_id
	#is_placing = true
	#_create_preview()
#
#func cancel_placement():
	#"""Cancel current placement"""
	#is_placing = false
	#current_building_id = ""
	#if preview_building:
		#preview_building.queue_free()
		#preview_building = null
	#
	## Hide placement tooltip
	#var ui = get_tree().root.get_node_or_null("PlanetSurface/UI")
	#if ui:
		#ui.hide_placement_tooltip()
#
#func _create_preview():
	#"""Create visual preview of building being placed"""
	#if preview_building:
		#preview_building.queue_free()
	#
	#var building_data = GameData.get_building_by_id(current_building_id)
	#if building_data.is_empty():
		#return
	#
	#preview_building = Node3D.new()
	#
	## Create a mesh for the building footprint
	#var mesh_instance = MeshInstance3D.new()
	#var box = BoxMesh.new()
	#box.size = Vector3(
		#building_data.size.x * tile_grid.TILE_SIZE,
		#1.0,
		#building_data.size.y * tile_grid.TILE_SIZE
	#)
	#mesh_instance.mesh = box
	#mesh_instance.position.y = 0.5
	#
	#var material = StandardMaterial3D.new()
	#material.albedo_color = building_data.color
	#material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#material.albedo_color.a = 0.5
	#mesh_instance.material_override = material
	#
	#preview_building.add_child(mesh_instance)
	#add_child(preview_building)
#
#func _process(_delta):
	#if is_placing and preview_building:
		#_update_preview()
#
#func _update_preview():
	#"""Update preview building position and color"""
	#var camera = get_viewport().get_camera_3d() as IsometricCamera
	#if not camera:
		#return
	#
	#var mouse_pos = camera.get_mouse_world_position()
	#var grid_pos = tile_grid.world_to_grid(mouse_pos)
	#
	#if tile_grid.is_valid_pos(grid_pos):
		## Get building data
		#var building_data = GameData.get_building_by_id(current_building_id)
		#
		## Position EXACTLY like the actual building
		#var world_pos = tile_grid.grid_to_world(grid_pos)
		#
		## For multi-tile, offset to center of footprint
		#if building_data.size.x > 1 or building_data.size.y > 1:
			#var extra_offset_x = (building_data.size.x - 1) / 2.0
			#var extra_offset_z = (building_data.size.y - 1) / 2.0
			#
			#world_pos.x += extra_offset_x * tile_grid.TILE_SIZE
			#world_pos.z += extra_offset_z * tile_grid.TILE_SIZE
		#
		#world_pos.y = 0.5
		#preview_building.position = world_pos
		#
		## Check if can place
		#var can_place = tile_grid.can_place_building(grid_pos, building_data.size)
		#var can_afford = GameData.can_afford_building(current_building_id, GameState.resources)
		#
		## Check placement requirements
		#var requirement = building_data.get("placement_requirement", "")
		#var meets_requirement = true
		#if requirement != "":
			#meets_requirement = _check_placement_requirement(grid_pos, building_data.size, requirement)
		#
		## Update preview color
		#var mesh = preview_building.get_child(0) as MeshInstance3D
		#var material = mesh.material_override as StandardMaterial3D
		#
		#if can_place and can_afford and meets_requirement:
			#material.albedo_color = Color(0.3, 1.0, 0.3, 0.7)  # Green = OK
		#elif not can_afford:
			#material.albedo_color = Color(1.0, 0.5, 0.0, 0.7)  # Orange = Can't afford
		#elif not meets_requirement:
			#material.albedo_color = Color(1.0, 0.0, 1.0, 0.7)  # Purple = Wrong location
		#else:
			#material.albedo_color = Color(1.0, 0.3, 0.3, 0.7)  # Red = Can't place
		#
		## Update placement tooltip
		#var ui = get_tree().root.get_node_or_null("PlanetSurface/UI")
		#if ui:
			#var screen_mouse_pos = get_viewport().get_mouse_position()
			#ui.show_placement_tooltip(current_building_id, can_place and meets_requirement, can_afford)
			#ui.update_placement_tooltip_position(screen_mouse_pos)
#
#func _input(event):
	#if not is_placing:
		## Check for right-click on buildings when not placing
		#if event is InputEventMouseButton:
			#if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				#print("🖱️ Right-click event received!")
				## Don't show context menu if clicking on UI
				#if _is_mouse_over_ui():
					#print("⚠️ Mouse is over UI, ignoring")
					#return
				#print("✅ Processing right-click on game world")
				#_check_building_right_click(event.position)
		#return
	#
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			## Check if mouse is over UI
			#if _is_mouse_over_ui():
				#return  # Don't place if clicking on UI
			#_try_place_building()
		#elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			#cancel_placement()
#
#func _check_building_right_click(mouse_pos: Vector2):
	#"""Check if right-clicked on a building - using tile-based detection"""
	#var camera = get_viewport().get_camera_3d() as IsometricCamera
	#if not camera:
		#print("❌ No camera")
		#return
	#
	## Use the same method as hover detection - much simpler!
	#var mouse_world = camera.get_mouse_world_position()
	#print("📍 Mouse world position: %s" % mouse_world)
	#
	#var grid_pos = tile_grid.world_to_grid(mouse_world)
	#print("📐 Grid position: %s" % grid_pos)
	#
	#if not tile_grid.is_valid_pos(grid_pos):
		#print("❌ Grid position invalid")
		#return
	#
	#print("✅ Grid position is valid")
	#
	## Get tile info
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#print("📋 Tile info: %s" % tile_info)
	#
	#var building_id = tile_info.get("building", "")
	#print("🏢 Building ID: '%s'" % building_id)
	#
	#if building_id != "" and building_id != null:
		#print("✅✅✅ Emitting building_right_clicked signal!")
		#building_right_clicked.emit(grid_pos, building_id, mouse_world)
	#else:
		#print("❌ No building on this tile")
#
#func _is_mouse_over_ui() -> bool:
	#"""Check if mouse is over any UI element"""
	#var mouse_pos = get_viewport().get_mouse_position()
	#
	## Get all UI panels
	#var ui_root = get_tree().root.get_node_or_null("PlanetSurface/UI")
	#if ui_root:
		#var panel = ui_root.get_node_or_null("Panel")
		#if panel and panel is Control:
			#var rect = panel.get_global_rect()
			#if rect.has_point(mouse_pos):
				#return true
	#
	## Check debug overlay
	#var debug = get_tree().root.get_node_or_null("PlanetSurface/DebugOverlay")
	#if debug:
		#var debug_panel = debug.get_node_or_null("Panel")
		#if debug_panel and debug_panel is Control:
			#var rect = debug_panel.get_global_rect()
			#if rect.has_point(mouse_pos):
				#return true
	#
	#return false
#
#func _try_place_building():
	#"""Attempt to place the current building"""
	#var camera = get_viewport().get_camera_3d() as IsometricCamera
	#if not camera:
		#return
	#
	#var mouse_pos = camera.get_mouse_world_position()
	#var grid_pos = tile_grid.world_to_grid(mouse_pos)
	#
	#var building_data = GameData.get_building_by_id(current_building_id)
	#if building_data.is_empty():
		#return
	#
	## Check placement validity
	#if not tile_grid.can_place_building(grid_pos, building_data.size):
		#building_placement_failed.emit("Cannot place building here - tiles occupied")
		#return
	#
	## Check special placement requirements
	#var requirement = building_data.get("placement_requirement", "")
	#if requirement != "":
		#if not _check_placement_requirement(grid_pos, building_data.size, requirement):
			#building_placement_failed.emit("Invalid location - check placement requirement")
			#return
	#
	## Check affordability
	#if not GameState.has_resources(building_data.build_cost):
		#building_placement_failed.emit("Not enough resources to build")
		#return
	#
	## Deduct resources
	#GameState.deduct_resources(building_data.build_cost)
	#
	## Place on grid
	#tile_grid.place_building(grid_pos, current_building_id)
	#
	## Create actual building
	#_create_building(grid_pos, current_building_id)
	#
	## Emit signal
	#building_placed.emit(current_building_id, grid_pos)
	#
	## Check for special buildings
	#if building_data.get("special", "") == "enables_space_travel":
		#GameState.unlock_space_travel()
	#
	#print("Built %s at %s" % [building_data.name, grid_pos])
#
#func _create_building(grid_pos: Vector2i, building_id: String):
	#"""Create the actual building in the world"""
	#var building_data = GameData.get_building_by_id(building_id)
	#if building_data.is_empty():
		#return
	#
	#var building = Node3D.new()
	#building.name = "%s_%s" % [building_id, grid_pos]
	#
	## Create mesh
	#var mesh_instance = MeshInstance3D.new()
	#var box = BoxMesh.new()
	#box.size = Vector3(
		#building_data.size.x * tile_grid.TILE_SIZE * 0.9,
		#2.0,
		#building_data.size.y * tile_grid.TILE_SIZE * 0.9
	#)
	#mesh_instance.mesh = box
	#mesh_instance.position.y = 1.0
	#
	#var material = StandardMaterial3D.new()
	#material.albedo_color = building_data.color
	#material.metallic = 0.3
	#material.roughness = 0.7
	#
	## If it's an extractor, add emission matching the resource
	#if building_data.get("extraction_rate", 0) > 0:
		#var tile_info = tile_grid.get_tile_info(grid_pos)
		#var resource_on_tile = tile_info.get("resource", null)
		#if resource_on_tile != null and resource_on_tile != "":
			#var resource = GameData.get_resource_by_id(resource_on_tile)
			#if not resource.is_empty():
				#material.emission_enabled = true
				#material.emission = resource.color
				#material.emission_energy = 0.5
	#
	#mesh_instance.material_override = material
	#
	#building.add_child(mesh_instance)
	#
	## Store original material state for later restoration
	#building_materials[grid_pos] = {
		#"albedo": material.albedo_color,
		#"emission": material.emission,
		#"emission_enabled": material.emission_enabled
	#}
	#
	## Position in world
	#var world_pos = tile_grid.grid_to_world(grid_pos)
	#
	## For multi-tile buildings, offset to center
	#if building_data.size.x > 1 or building_data.size.y > 1:
		#var extra_offset_x = (building_data.size.x - 1) / 2.0
		#var extra_offset_z = (building_data.size.y - 1) / 2.0
		#
		#world_pos.x += extra_offset_x * tile_grid.TILE_SIZE
		#world_pos.z += extra_offset_z * tile_grid.TILE_SIZE
	#
	#world_pos.y = 1.0
	#building.position = world_pos
	#
	#add_child(building)
	#placed_buildings[grid_pos] = building
	#
	## Register with upkeep manager
	#var upkeep_mgr = get_tree().root.get_node_or_null("PlanetSurface/UpkeepManager")
	#if upkeep_mgr:
		#upkeep_mgr.register_building(grid_pos, building_id)
	#
	## Register with resource tracker
	#var tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	#if tracker:
		#if building_data.get("extraction_rate", 0) > 0:
			#var tile_info = tile_grid.get_tile_info(grid_pos)
			#var resource = tile_info.get("resource", null)
			#if resource:
				#tracker.register_extractor(grid_pos, resource, building_data.extraction_rate)
		#
		#if building_data.get("production", {}).size() > 0:
			#tracker.register_producer(grid_pos, building_id)
	#
	## Start production or extraction
	#if building_data.get("production", {}).size() > 0:
		#_start_production(grid_pos, building_id)
	#
	#if building_data.get("extraction_rate", 0) > 0:
		#_start_extraction(grid_pos, building_id)
#
#func _start_production(grid_pos: Vector2i, building_id: String):
	#"""Start a production cycle for a building"""
	#var building_data = GameData.get_building_by_id(building_id)
	#var production = building_data.get("production", {})
	#
	#if production.is_empty():
		#return
	#
	#var time = production.get("time", 10.0)
	#
	#var timer = Timer.new()
	#timer.wait_time = time
	#timer.timeout.connect(_on_production_cycle.bind(grid_pos, building_id))
	#timer.autostart = true
	#add_child(timer)
#
#func _on_production_cycle(grid_pos: Vector2i, building_id: String):
	#"""Handle one production cycle"""
	#var building_data = GameData.get_building_by_id(building_id)
	#var production = building_data.get("production", {})
	#
	#if production.is_empty():
		#return
	#
	## Check if building is paused
	#var building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	#if building_control and building_control.is_paused(grid_pos):
		#return  # Don't produce if paused
	#
	#var inputs = production.get("input", {})
	#var outputs = production.get("output", {})
	#
	## Check if ALL inputs are available (including energy!)
	#if GameState.has_resources(inputs):
		## Consume inputs (energy, biomatter, minerals, etc.)
		#GameState.deduct_resources(inputs)
		#
		## Produce outputs
		#for resource_id in outputs:
			#var amount = outputs[resource_id]
			#GameState.add_resource(resource_id, amount)
		#
		#update_building_state(grid_pos, "active")
	#else:
		## Missing resources - building stops
		#var missing = []
		#for res_id in inputs:
			#var needed = inputs[res_id]
			#var available = GameState.resources.get(res_id, 0)
			#if available < needed:
				#missing.append("%s (need %.1f, have %d)" % [res_id, needed, available])
		#
		#print("⚠️ Building at %s stopped - missing: %s" % [grid_pos, ", ".join(missing)])
		#update_building_state(grid_pos, "warning")
#
#
#
#func _start_extraction(grid_pos: Vector2i, building_id: String):
	#"""Start extracting resources from a deposit"""
	#var building_data = GameData.get_building_by_id(building_id)
	#var extraction_rate = building_data.get("extraction_rate", 1.0)
	#
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#var resource_on_tile = tile_info.get("resource", null)
	#
	#if resource_on_tile == null or resource_on_tile == "":
		#print("⚠️ WARNING: Extractor at %s has NO resource deposit!" % grid_pos)
		#return
	#
	#print("✅ Extractor at %s will extract %.1f %s per minute" % [grid_pos, extraction_rate, resource_on_tile])
	#
	#var timer = Timer.new()
	#timer.wait_time = 10.0
	#timer.timeout.connect(_on_extraction_tick.bind(grid_pos, resource_on_tile, extraction_rate / 6.0))
	#timer.autostart = true
	#add_child(timer)
	#
	#extraction_timers[grid_pos] = timer
#
#func _on_extraction_tick(grid_pos: Vector2i, resource_id: String, rate: float):
	#"""Handle one extraction tick"""
	#var building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	#if building_control and building_control.is_paused(grid_pos):
		#return
	#
	## Upkeep manager handles energy/biomatter consumption
	## If upkeep can't be paid, efficiency drops and this still runs (but at lower rate)
	## For now, just extract at full rate - upkeep manager will handle shortages
	#
	#var amount = ceil(rate)
	#
	#if amount > 0:
		#GameState.add_resource(resource_id, amount)
		#print("⛏️ Extracted %d %s at %s" % [amount, resource_id, grid_pos])
#
#
#func update_building_state(grid_pos: Vector2i, state: String):
	#"""Update building visual state"""
	#if grid_pos not in placed_buildings:
		#return
	#
	#var building = placed_buildings[grid_pos]
	#var mesh_instance = building.get_child(0) as MeshInstance3D
	#if not mesh_instance:
		#return
	#
	#var material = mesh_instance.material_override as StandardMaterial3D
	#if not material:
		#return
	#
	#match state:
		#"active":
			#if grid_pos in building_materials:
				#var stored = building_materials[grid_pos]
				#material.albedo_color = stored.albedo
				#material.emission = stored.emission
				#material.emission_enabled = stored.emission_enabled
			#else:
				#material.albedo_color.a = 1.0
				#material.emission_enabled = false
		#"paused":
			#material.albedo_color = Color(0.5, 0.5, 0.5, 0.7)
			#material.emission_enabled = false
		#"warning":
			#material.emission_enabled = true
			#material.emission = Color.ORANGE
			#material.emission_energy = 0.3
		#"error":
			#material.emission_enabled = true
			#material.emission = Color.RED
			#material.emission_energy = 0.5
#
#func demolish_building(grid_pos: Vector2i) -> bool:
	#"""Demolish a building"""
	#if grid_pos not in placed_buildings:
		#return false
	#
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#var building_id = tile_info.get("building", "")
	#if building_id == "":
		#return false
	#
	#var building_data = GameData.get_building_by_id(building_id)
	#if building_data.is_empty():
		#return false
	#
	## Unregister from resource tracker
	#var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	#if resource_tracker:
		#resource_tracker.unregister_building(grid_pos)
	#
	## Stop extraction timer
	#if grid_pos in extraction_timers:
		#var timer = extraction_timers[grid_pos]
		#timer.stop()
		#timer.queue_free()
		#extraction_timers.erase(grid_pos)
	#
	## Remove visual
	#var building = placed_buildings[grid_pos]
	#building.queue_free()
	#placed_buildings.erase(grid_pos)
	#
	## Clean up material storage
	#if grid_pos in building_materials:
		#building_materials.erase(grid_pos)
	#
	## Clear tiles
	#for dx in range(building_data.size.x):
		#for dy in range(building_data.size.y):
			#var tile_pos = grid_pos + Vector2i(dx, dy)
			#if tile_grid.is_valid_pos(tile_pos):
				#tile_grid.clear_tile(tile_pos)
	#
	#print("💥 Building demolished at %s" % grid_pos)
	#return true
#
#func pause_building(grid_pos: Vector2i):
	#"""Pause a building"""
	#var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	#if resource_tracker:
		#resource_tracker.unregister_building(grid_pos)
	#
	#update_building_state(grid_pos, "paused")
	#print("⏸️ Building paused at %s" % grid_pos)
#
#func resume_building(grid_pos: Vector2i):
	#"""Resume a building"""
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#var building_id = tile_info.get("building", "")
	#if building_id == "":
		#return
	#
	#var building_data = GameData.get_building_by_id(building_id)
	#if building_data.is_empty():
		#return
	#
	## Re-register with resource tracker
	#var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	#if resource_tracker:
		#if building_data.get("extraction_rate", 0) > 0:
			#var tile = tile_grid.get_tile_info(grid_pos)
			#var resource_id = tile.get("resource", "")
			#if resource_id != "":
				#resource_tracker.register_extractor(grid_pos, resource_id, building_data.extraction_rate)
		#elif not building_data.get("production", {}).is_empty():
			#resource_tracker.register_producer(grid_pos, building_id)
	#
	#update_building_state(grid_pos, "active")
	#print("▶️ Building resumed at %s" % grid_pos)
#
#func _check_placement_requirement(grid_pos: Vector2i, building_size: Vector2i, requirement: String) -> bool:
	#"""Check special placement requirements"""
	#
	#if requirement == "adjacent_shallow_water":
		#var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
		#
		#for dx in range(building_size.x):
			#for dy in range(building_size.y):
				#var check_pos = grid_pos + Vector2i(dx, dy)
				#
				#for dir in directions:
					#var adjacent = check_pos + dir
					#if tile_grid.is_valid_pos(adjacent):
						#var tile_info = tile_grid.get_tile_info(adjacent)
						#if tile_info.get("type", "") == "shallow_water":
							#return true
		#
		#return false
	#
	#return true

#extends Node3D
#class_name BuildingManager
## Manages building placement and visualization
#
#@export var tile_grid: TileGrid
#
#var placed_buildings: Dictionary = {}  # {grid_pos: Building instance}
#var preview_building: Node3D = null
#var current_building_id: String = ""
#var is_placing: bool = false
#
#var selected_building_pos: Vector2i = Vector2i(-1, -1)
#var selected_building_id: String = ""
#
## Track extraction timers so we can stop them
#var extraction_timers: Dictionary = {}  # {grid_pos: Timer}
#
## Store original building colors and emission for resume
#var building_materials: Dictionary = {}  # {grid_pos: {albedo: Color, emission: Color, emission_enabled: bool}}
#
#signal building_placed(building_id: String, grid_pos: Vector2i)
#signal building_placement_failed(reason: String)
#signal building_selected(grid_pos: Vector2i, building_id: String)
#signal building_right_clicked(grid_pos: Vector2i, building_id: String, world_pos: Vector3)
#
#func start_placement(building_id: String):
	#"""Start placing a building"""
	#current_building_id = building_id
	#is_placing = true
	#_create_preview()
#
#func cancel_placement():
	#"""Cancel current placement"""
	#is_placing = false
	#current_building_id = ""
	#if preview_building:
		#preview_building.queue_free()
		#preview_building = null
	#
	## Hide placement tooltip
	#var ui = get_tree().root.get_node_or_null("PlanetSurface/UI")
	#if ui:
		#ui.hide_placement_tooltip()
#
#func _create_preview():
	#"""Create visual preview of building being placed"""
	#if preview_building:
		#preview_building.queue_free()
	#
	#var building_data = GameData.get_building_by_id(current_building_id)
	#if building_data.is_empty():
		#return
	#
	#preview_building = Node3D.new()
	#
	## Create a mesh for the building footprint
	#var mesh_instance = MeshInstance3D.new()
	#var box = BoxMesh.new()
	#box.size = Vector3(
		#building_data.size.x * tile_grid.TILE_SIZE,
		#1.0,
		#building_data.size.y * tile_grid.TILE_SIZE
	#)
	#mesh_instance.mesh = box
	#mesh_instance.position.y = 0.5
	#
	#var material = StandardMaterial3D.new()
	#material.albedo_color = building_data.color
	#material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#material.albedo_color.a = 0.5
	#mesh_instance.material_override = material
	#
	#preview_building.add_child(mesh_instance)
	#add_child(preview_building)
#
#func _process(_delta):
	#if is_placing and preview_building:
		#_update_preview()
#
#func _update_preview():
	#"""Update preview building position and color"""
	#var camera = get_viewport().get_camera_3d() as IsometricCamera
	#if not camera:
		#return
	#
	#var mouse_pos = camera.get_mouse_world_position()
	#var grid_pos = tile_grid.world_to_grid(mouse_pos)
	#
	#if tile_grid.is_valid_pos(grid_pos):
		## Get building data
		#var building_data = GameData.get_building_by_id(current_building_id)
		#
		## Position EXACTLY like the actual building
		#var world_pos = tile_grid.grid_to_world(grid_pos)
		#
		## For multi-tile, offset to center of footprint
		#if building_data.size.x > 1 or building_data.size.y > 1:
			#var extra_offset_x = (building_data.size.x - 1) / 2.0
			#var extra_offset_z = (building_data.size.y - 1) / 2.0
			#
			#world_pos.x += extra_offset_x * tile_grid.TILE_SIZE
			#world_pos.z += extra_offset_z * tile_grid.TILE_SIZE
		#
		#world_pos.y = 0.5
		#preview_building.position = world_pos
		#
		## Check if can place
		#var can_place = tile_grid.can_place_building(grid_pos, building_data.size)
		#var can_afford = GameData.can_afford_building(current_building_id, GameState.resources)
		#
		## Check placement requirements
		#var requirement = building_data.get("placement_requirement", "")
		#var meets_requirement = true
		#if requirement != "":
			#meets_requirement = _check_placement_requirement(grid_pos, building_data.size, requirement)
		#
		## Update preview color
		#var mesh = preview_building.get_child(0) as MeshInstance3D
		#var material = mesh.material_override as StandardMaterial3D
		#
		#if can_place and can_afford and meets_requirement:
			#material.albedo_color = Color(0.3, 1.0, 0.3, 0.7)  # Green = OK
		#elif not can_afford:
			#material.albedo_color = Color(1.0, 0.5, 0.0, 0.7)  # Orange = Can't afford
		#elif not meets_requirement:
			#material.albedo_color = Color(1.0, 0.0, 1.0, 0.7)  # Purple = Wrong location
		#else:
			#material.albedo_color = Color(1.0, 0.3, 0.3, 0.7)  # Red = Can't place
		#
		## Update placement tooltip
		#var ui = get_tree().root.get_node_or_null("PlanetSurface/UI")
		#if ui:
			#var screen_mouse_pos = get_viewport().get_mouse_position()
			#ui.show_placement_tooltip(current_building_id, can_place and meets_requirement, can_afford)
			#ui.update_placement_tooltip_position(screen_mouse_pos)
#
#func _input(event):
	#if not is_placing:
		## Check for right-click on buildings when not placing
		#if event is InputEventMouseButton:
			#if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				#print("🖱️ Right-click event received!")
				## Don't show context menu if clicking on UI
				#if _is_mouse_over_ui():
					#print("⚠️ Mouse is over UI, ignoring")
					#return
				#print("✅ Processing right-click on game world")
				#_check_building_right_click(event.position)
		#return
	#
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			## Check if mouse is over UI
			#if _is_mouse_over_ui():
				#return  # Don't place if clicking on UI
			#_try_place_building()
		#elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			#cancel_placement()
#
#func _check_building_right_click(mouse_pos: Vector2):
	#"""Check if right-clicked on a building - using tile-based detection"""
	#var camera = get_viewport().get_camera_3d() as IsometricCamera
	#if not camera:
		#print("❌ No camera")
		#return
	#
	## Use the same method as hover detection - much simpler!
	#var mouse_world = camera.get_mouse_world_position()
	#print("📍 Mouse world position: %s" % mouse_world)
	#
	#var grid_pos = tile_grid.world_to_grid(mouse_world)
	#print("📐 Grid position: %s" % grid_pos)
	#
	#if not tile_grid.is_valid_pos(grid_pos):
		#print("❌ Grid position invalid")
		#return
	#
	#print("✅ Grid position is valid")
	#
	## Get tile info
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#print("📋 Tile info: %s" % tile_info)
	#
	#var building_id = tile_info.get("building", "")
	#print("🏢 Building ID: '%s'" % building_id)
	#
	#if building_id != "" and building_id != null:
		#print("✅✅✅ Emitting building_right_clicked signal!")
		#building_right_clicked.emit(grid_pos, building_id, mouse_world)
	#else:
		#print("❌ No building on this tile")
#
#func _is_mouse_over_ui() -> bool:
	#"""Check if mouse is over any UI element"""
	#var mouse_pos = get_viewport().get_mouse_position()
	#
	## Get all UI panels
	#var ui_root = get_tree().root.get_node_or_null("PlanetSurface/UI")
	#if ui_root:
		#var panel = ui_root.get_node_or_null("Panel")
		#if panel and panel is Control:
			#var rect = panel.get_global_rect()
			#if rect.has_point(mouse_pos):
				#return true
	#
	## Check debug overlay
	#var debug = get_tree().root.get_node_or_null("PlanetSurface/DebugOverlay")
	#if debug:
		#var debug_panel = debug.get_node_or_null("Panel")
		#if debug_panel and debug_panel is Control:
			#var rect = debug_panel.get_global_rect()
			#if rect.has_point(mouse_pos):
				#return true
	#
	#return false
#
#func _try_place_building():
	#"""Attempt to place the current building"""
	#var camera = get_viewport().get_camera_3d() as IsometricCamera
	#if not camera:
		#return
	#
	#var mouse_pos = camera.get_mouse_world_position()
	#var grid_pos = tile_grid.world_to_grid(mouse_pos)
	#
	#var building_data = GameData.get_building_by_id(current_building_id)
	#if building_data.is_empty():
		#return
	#
	## Check placement validity
	#if not tile_grid.can_place_building(grid_pos, building_data.size):
		#building_placement_failed.emit("Cannot place building here - tiles occupied")
		#return
	#
	## Check special placement requirements
	#var requirement = building_data.get("placement_requirement", "")
	#if requirement != "":
		#if not _check_placement_requirement(grid_pos, building_data.size, requirement):
			#building_placement_failed.emit("Invalid location - check placement requirement")
			#return
	#
	## Check affordability
	#if not GameState.has_resources(building_data.build_cost):
		#building_placement_failed.emit("Not enough resources to build")
		#return
	#
	## Deduct resources
	#GameState.deduct_resources(building_data.build_cost)
	#
	## Place on grid
	#tile_grid.place_building(grid_pos, current_building_id)
	#
	## Create actual building
	#_create_building(grid_pos, current_building_id)
	#
	## Emit signal
	#building_placed.emit(current_building_id, grid_pos)
	#
	## Check for special buildings
	#if building_data.get("special", "") == "enables_space_travel":
		#GameState.unlock_space_travel()
	#
	#print("Built %s at %s" % [building_data.name, grid_pos])
#
#func _create_building(grid_pos: Vector2i, building_id: String):
	#"""Create the actual building in the world"""
	#var building_data = GameData.get_building_by_id(building_id)
	#if building_data.is_empty():
		#return
	#
	#var building = Node3D.new()
	#building.name = "%s_%s" % [building_id, grid_pos]
	#
	## Create mesh
	#var mesh_instance = MeshInstance3D.new()
	#var box = BoxMesh.new()
	#box.size = Vector3(
		#building_data.size.x * tile_grid.TILE_SIZE * 0.9,
		#2.0,
		#building_data.size.y * tile_grid.TILE_SIZE * 0.9
	#)
	#mesh_instance.mesh = box
	#mesh_instance.position.y = 1.0
	#
	#var material = StandardMaterial3D.new()
	#material.albedo_color = building_data.color
	#material.metallic = 0.3
	#material.roughness = 0.7
	#
	## If it's an extractor, add emission matching the resource
	#if building_data.get("extraction_rate", 0) > 0:
		#var tile_info = tile_grid.get_tile_info(grid_pos)
		#var resource_on_tile = tile_info.get("resource", null)
		#if resource_on_tile != null and resource_on_tile != "":
			#var resource = GameData.get_resource_by_id(resource_on_tile)
			#if not resource.is_empty():
				#material.emission_enabled = true
				#material.emission = resource.color
				#material.emission_energy = 0.5
	#
	#mesh_instance.material_override = material
	#
	#building.add_child(mesh_instance)
	#
	## Store original material state for later restoration
	#building_materials[grid_pos] = {
		#"albedo": material.albedo_color,
		#"emission": material.emission,
		#"emission_enabled": material.emission_enabled
	#}
	#
	## Position in world
	#var world_pos = tile_grid.grid_to_world(grid_pos)
	#
	## For multi-tile buildings, offset to center
	#if building_data.size.x > 1 or building_data.size.y > 1:
		#var extra_offset_x = (building_data.size.x - 1) / 2.0
		#var extra_offset_z = (building_data.size.y - 1) / 2.0
		#
		#world_pos.x += extra_offset_x * tile_grid.TILE_SIZE
		#world_pos.z += extra_offset_z * tile_grid.TILE_SIZE
	#
	#world_pos.y = 1.0
	#building.position = world_pos
	#
	#add_child(building)
	#placed_buildings[grid_pos] = building
	#
	## Register with upkeep manager
	#var upkeep_mgr = get_tree().root.get_node_or_null("PlanetSurface/UpkeepManager")
	#if upkeep_mgr:
		#upkeep_mgr.register_building(grid_pos, building_id)
	#
	## Register with resource tracker
	#var tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	#if tracker:
		#if building_data.get("extraction_rate", 0) > 0:
			#var tile_info = tile_grid.get_tile_info(grid_pos)
			#var resource = tile_info.get("resource", null)
			#if resource:
				#tracker.register_extractor(grid_pos, resource, building_data.extraction_rate)
		#
		#if building_data.get("production", {}).size() > 0:
			#tracker.register_producer(grid_pos, building_id)
	#
	## Start production or extraction
	#if building_data.get("production", {}).size() > 0:
		#_start_production(grid_pos, building_id)
	#
	#if building_data.get("extraction_rate", 0) > 0:
		#_start_extraction(grid_pos, building_id)
#
#func _start_production(grid_pos: Vector2i, building_id: String):
	#"""Start a production cycle for a building"""
	#var building_data = GameData.get_building_by_id(building_id)
	#var production = building_data.get("production", {})
	#
	#if production.is_empty():
		#return
	#
	#var time = production.get("time", 10.0)
	#
	#var timer = Timer.new()
	#timer.wait_time = time
	#timer.timeout.connect(_on_production_cycle.bind(grid_pos, building_id))
	#timer.autostart = true
	#add_child(timer)
#
#func _on_production_cycle(grid_pos: Vector2i, building_id: String):
	#"""Handle one production cycle"""
	#var building_data = GameData.get_building_by_id(building_id)
	#var production = building_data.get("production", {})
	#
	#if production.is_empty():
		#return
	#
	#var inputs = production.get("input", {})
	#var outputs = production.get("output", {})
	#var efficiency = GameState.global_efficiency
	#
	#var scaled_inputs = {}
	#for res_id in inputs:
		#scaled_inputs[res_id] = ceil(inputs[res_id] * efficiency)
	#
	#if GameState.has_resources(scaled_inputs):
		#GameState.deduct_resources(scaled_inputs)
		#
		#for resource_id in outputs:
			#var amount = ceil(outputs[resource_id] * efficiency)
			#GameState.add_resource(resource_id, amount)
		#
		#if efficiency < 1.0:
			#print("⚠️ Production at %s running at %.0f%% efficiency" % [grid_pos, efficiency * 100])
#
#func _start_extraction(grid_pos: Vector2i, building_id: String):
	#"""Start extracting resources from a deposit"""
	#var building_data = GameData.get_building_by_id(building_id)
	#var extraction_rate = building_data.get("extraction_rate", 1.0)
	#
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#var resource_on_tile = tile_info.get("resource", null)
	#
	#if resource_on_tile == null or resource_on_tile == "":
		#print("⚠️ WARNING: Extractor at %s has NO resource deposit!" % grid_pos)
		#return
	#
	#print("✅ Extractor at %s will extract %.1f %s per minute" % [grid_pos, extraction_rate, resource_on_tile])
	#
	#var timer = Timer.new()
	#timer.wait_time = 10.0
	#timer.timeout.connect(_on_extraction_tick.bind(grid_pos, resource_on_tile, extraction_rate / 6.0))
	#timer.autostart = true
	#add_child(timer)
	#
	#extraction_timers[grid_pos] = timer
#
#func _on_extraction_tick(grid_pos: Vector2i, resource_id: String, rate: float):
	#"""Handle one extraction tick"""
	#var building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	#if building_control and building_control.is_paused(grid_pos):
		#return
	#
	#var efficiency = GameState.global_efficiency
	#var amount = ceil(rate * efficiency)
	#
	#if amount > 0:
		#GameState.add_resource(resource_id, amount)
		#
		#if efficiency < 1.0:
			#print("⛏️ Extracted %d %s at %s (%.0f%% efficiency)" % [amount, resource_id, grid_pos, efficiency * 100])
		#else:
			#print("⛏️ Extracted %d %s at %s" % [amount, resource_id, grid_pos])
#
#func update_building_state(grid_pos: Vector2i, state: String):
	#"""Update building visual state"""
	#if grid_pos not in placed_buildings:
		#return
	#
	#var building = placed_buildings[grid_pos]
	#var mesh_instance = building.get_child(0) as MeshInstance3D
	#if not mesh_instance:
		#return
	#
	#var material = mesh_instance.material_override as StandardMaterial3D
	#if not material:
		#return
	#
	#match state:
		#"active":
			#if grid_pos in building_materials:
				#var stored = building_materials[grid_pos]
				#material.albedo_color = stored.albedo
				#material.emission = stored.emission
				#material.emission_enabled = stored.emission_enabled
			#else:
				#material.albedo_color.a = 1.0
				#material.emission_enabled = false
		#"paused":
			#material.albedo_color = Color(0.5, 0.5, 0.5, 0.7)
			#material.emission_enabled = false
		#"warning":
			#material.emission_enabled = true
			#material.emission = Color.ORANGE
			#material.emission_energy = 0.3
		#"error":
			#material.emission_enabled = true
			#material.emission = Color.RED
			#material.emission_energy = 0.5
#
#func demolish_building(grid_pos: Vector2i) -> bool:
	#"""Demolish a building"""
	#if grid_pos not in placed_buildings:
		#return false
	#
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#var building_id = tile_info.get("building", "")
	#if building_id == "":
		#return false
	#
	#var building_data = GameData.get_building_by_id(building_id)
	#if building_data.is_empty():
		#return false
	#
	## Unregister from resource tracker
	#var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	#if resource_tracker:
		#resource_tracker.unregister_building(grid_pos)
	#
	## Stop extraction timer
	#if grid_pos in extraction_timers:
		#var timer = extraction_timers[grid_pos]
		#timer.stop()
		#timer.queue_free()
		#extraction_timers.erase(grid_pos)
	#
	## Remove visual
	#var building = placed_buildings[grid_pos]
	#building.queue_free()
	#placed_buildings.erase(grid_pos)
	#
	## Clean up material storage
	#if grid_pos in building_materials:
		#building_materials.erase(grid_pos)
	#
	## Clear tiles
	#for dx in range(building_data.size.x):
		#for dy in range(building_data.size.y):
			#var tile_pos = grid_pos + Vector2i(dx, dy)
			#if tile_grid.is_valid_pos(tile_pos):
				#tile_grid.clear_tile(tile_pos)
	#
	#print("💥 Building demolished at %s" % grid_pos)
	#return true
#
#func pause_building(grid_pos: Vector2i):
	#"""Pause a building"""
	#var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	#if resource_tracker:
		#resource_tracker.unregister_building(grid_pos)
	#
	#update_building_state(grid_pos, "paused")
	#print("⏸️ Building paused at %s" % grid_pos)
#
#func resume_building(grid_pos: Vector2i):
	#"""Resume a building"""
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#var building_id = tile_info.get("building", "")
	#if building_id == "":
		#return
	#
	#var building_data = GameData.get_building_by_id(building_id)
	#if building_data.is_empty():
		#return
	#
	## Re-register with resource tracker
	#var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
	#if resource_tracker:
		#if building_data.get("extraction_rate", 0) > 0:
			#var tile = tile_grid.get_tile_info(grid_pos)
			#var resource_id = tile.get("resource", "")
			#if resource_id != "":
				#resource_tracker.register_extractor(grid_pos, resource_id, building_data.extraction_rate)
		#elif not building_data.get("production", {}).is_empty():
			#resource_tracker.register_producer(grid_pos, building_id)
	#
	#update_building_state(grid_pos, "active")
	#print("▶️ Building resumed at %s" % grid_pos)
#
#func _check_placement_requirement(grid_pos: Vector2i, building_size: Vector2i, requirement: String) -> bool:
	#"""Check special placement requirements"""
	#
	#if requirement == "adjacent_shallow_water":
		#var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
		#
		#for dx in range(building_size.x):
			#for dy in range(building_size.y):
				#var check_pos = grid_pos + Vector2i(dx, dy)
				#
				#for dir in directions:
					#var adjacent = check_pos + dir
					#if tile_grid.is_valid_pos(adjacent):
						#var tile_info = tile_grid.get_tile_info(adjacent)
						#if tile_info.get("type", "") == "shallow_water":
							#return true
		#
		#return false
	#
	#return true
