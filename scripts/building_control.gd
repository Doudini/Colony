extends Node
class_name BuildingControl
# Manages building states: paused, active, demolished

var paused_buildings: Dictionary = {}  # {grid_pos: true}

signal building_paused(grid_pos: Vector2i)
signal building_resumed(grid_pos: Vector2i)
signal building_demolished(grid_pos: Vector2i)

func pause_building(grid_pos: Vector2i):
	"""Pause a building - stops production and upkeep"""
	paused_buildings[grid_pos] = true
	print("⏸️ Building at %s paused (upkeep stopped)" % grid_pos)
	building_paused.emit(grid_pos)

func resume_building(grid_pos: Vector2i):
	"""Resume a building"""
	if grid_pos in paused_buildings:
		paused_buildings.erase(grid_pos)
	print("▶️ Building at %s resumed (upkeep active)" % grid_pos)
	building_resumed.emit(grid_pos)

func is_paused(grid_pos: Vector2i) -> bool:
	"""Check if building is paused"""
	return paused_buildings.get(grid_pos, false)

func demolish_building(grid_pos: Vector2i, building_id: String) -> Dictionary:
	"""Demolish building and return 50% of materials"""
	var building_data = GameData.get_building_by_id(building_id)
	if building_data.is_empty():
		return {}
	
	var refund = {}
	for resource_id in building_data.build_cost:
		var cost = building_data.build_cost[resource_id]
		refund[resource_id] = int(cost * 0.5)  # 50% refund
	
	# Clean up pause state
	if grid_pos in paused_buildings:
		paused_buildings.erase(grid_pos)
	
	building_demolished.emit(grid_pos)
	return refund
