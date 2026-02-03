extends Node
class_name UpkeepManager
# Manages building upkeep costs (energy and biomatter consumption)

var building_manager: BuildingManager
var upkeep_timer: Timer
var tick_interval: float = 10.0  # Check every 10 seconds

# Track all buildings with upkeep
var buildings_with_upkeep: Dictionary = {}  # {grid_pos: building_id}

func _ready():
	# Create upkeep timer
	upkeep_timer = Timer.new()
	upkeep_timer.wait_time = tick_interval
	upkeep_timer.timeout.connect(_process_upkeep)
	upkeep_timer.autostart = true
	add_child(upkeep_timer)

func register_building(grid_pos: Vector2i, building_id: String):
	"""Register a building that has upkeep costs"""
	var building_data = GameData.get_building_by_id(building_id)
	var upkeep = building_data.get("upkeep", {})
	
	if upkeep.size() > 0:
		buildings_with_upkeep[grid_pos] = building_id
		print("⚙️ Registered building at %s for upkeep: %s" % [grid_pos, upkeep])
		
		# Notify ResourceTracker to recalculate rates
		var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
		if resource_tracker:
			resource_tracker._recalculate_rates()


func unregister_building(grid_pos: Vector2i):
	"""Remove a building from upkeep tracking"""
	if grid_pos in buildings_with_upkeep:
		buildings_with_upkeep.erase(grid_pos)
		print("⚙️ UpkeepManager: Unregistered building at %s" % grid_pos)
		
		# Notify ResourceTracker to recalculate rates (upkeep affects consumption)
		var resource_tracker = get_tree().root.get_node_or_null("PlanetSurface/ResourceTracker")
		if resource_tracker:
			resource_tracker._recalculate_rates()
			print("📊 Triggered rate recalculation after upkeep change")


func _process_upkeep():
	"""Process upkeep for all buildings every tick"""
	var total_upkeep = {}
	var total_buildings = buildings_with_upkeep.size()
	
	if total_buildings == 0:
		return
	
	# Get BuildingControl to check pause state
	var building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	
	# Calculate total upkeep needed
	for grid_pos in buildings_with_upkeep:
		# Skip paused buildings - they consume NO upkeep
		if building_control and building_control.is_paused(grid_pos):
			continue  # Paused buildings use 0% upkeep
		
		var building_id = buildings_with_upkeep[grid_pos]
		var building_data = GameData.get_building_by_id(building_id)
		var upkeep = building_data.get("upkeep", {})
		
		for resource_id in upkeep:
			var amount_per_min = upkeep[resource_id]
			var modifier = 1.0
			if building_id in GameState.upkeep_modifiers:
				modifier = GameState.upkeep_modifiers[building_id].get(resource_id, 1.0)
			amount_per_min *= modifier
			var amount_per_tick = (amount_per_min / 60.0) * tick_interval  # Per 10 seconds
			
			if resource_id not in total_upkeep:
				total_upkeep[resource_id] = 0.0
			total_upkeep[resource_id] += amount_per_tick
	
	# Try to deduct upkeep
	var can_afford = true
	for resource_id in total_upkeep:
		var needed = ceil(total_upkeep[resource_id])
		var available = GameState.resources.get(resource_id, 0)
		if available < needed:
			can_afford = false
			print("⚠️ Insufficient %s for upkeep! Need %d, have %d" % [resource_id, needed, available])
	
	# Deduct resources
	if can_afford:
		for resource_id in total_upkeep:
			var amount = ceil(total_upkeep[resource_id])
			GameState.remove_resource(resource_id, amount)
		
		# Full efficiency
		GameState.calculate_efficiency()
	else:
		# Low resources - calculate degraded efficiency
		GameState.energy_consumption_rate = total_upkeep.get("energy", 0) * 6.0  # Convert to per-minute
		GameState.biomatter_consumption_rate = total_upkeep.get("biomatter", 0) * 6.0
		GameState.calculate_efficiency()
		
		# Still deduct what we can
		for resource_id in total_upkeep:
			var needed = ceil(total_upkeep[resource_id])
			var available = GameState.resources.get(resource_id, 0)
			var to_remove = min(needed, available)
			if to_remove > 0:
				GameState.remove_resource(resource_id, to_remove)

func get_total_upkeep() -> Dictionary:
	"""Get total upkeep costs per minute (excludes paused buildings)"""
	var total = {}
	
	# Get BuildingControl to check pause state
	var building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	
	for grid_pos in buildings_with_upkeep:
		# Skip paused buildings
		if building_control and building_control.is_paused(grid_pos):
			continue
		
		var building_id = buildings_with_upkeep[grid_pos]
		var building_data = GameData.get_building_by_id(building_id)
		var upkeep = building_data.get("upkeep", {})
		
		for resource_id in upkeep:
			if resource_id not in total:
				total[resource_id] = 0.0
			var amount_per_min = upkeep[resource_id]
			var modifier = 1.0
			if building_id in GameState.upkeep_modifiers:
				modifier = GameState.upkeep_modifiers[building_id].get(resource_id, 1.0)
			total[resource_id] += amount_per_min * modifier
	
	return total
