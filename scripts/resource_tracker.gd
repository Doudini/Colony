extends Node
class_name ResourceTracker
# Tracks production and consumption rates for all resources

var building_manager: BuildingManager
var upkeep_manager: UpkeepManager

# Tracking dictionaries
var extractors: Dictionary = {}  # {grid_pos: {resource_id, rate}}
var producers: Dictionary = {}   # {grid_pos: {inputs, outputs, time}}

# Calculated rates (per minute)
var production_rates: Dictionary = {}
var consumption_rates: Dictionary = {}

func _ready():
	# Initialize all resources to 0
	for resource in GameData.resources:
		production_rates[resource.id] = 0.0
		consumption_rates[resource.id] = 0.0

func register_extractor(grid_pos: Vector2i, resource_id: String, rate: float):
	"""Register an extractor building"""
	extractors[grid_pos] = {
		"resource": resource_id,
		"rate": rate
	}
	_recalculate_rates()

func register_producer(grid_pos: Vector2i, building_id: String):
	"""Register a production building"""
	var building_data = GameData.get_building_by_id(building_id)
	var production = building_data.get("production", {})
	
	if not production.is_empty():
		producers[grid_pos] = {
			"inputs": production.get("input", {}),
			"outputs": production.get("output", {}),
			"time": production.get("time", 10.0)
		}
		_recalculate_rates()

func unregister_building(grid_pos: Vector2i):
	"""Remove a building from tracking"""
	if grid_pos in extractors:
		extractors.erase(grid_pos)
		_recalculate_rates()
	
	if grid_pos in producers:
		producers.erase(grid_pos)
		_recalculate_rates()

func _recalculate_rates():
	"""Recalculate all production and consumption rates"""
	# Reset all rates
	for resource in GameData.resources:
		production_rates[resource.id] = 0.0
		consumption_rates[resource.id] = 0.0
	
	# Add extractor production
	for extractor in extractors.values():
		var res_id = extractor.resource
		var rate = extractor.rate
		if res_id in production_rates:
			production_rates[res_id] += rate
		else:
			print("⚠️ Unknown resource in extractor: %s" % res_id)
	
	# Add producer production/consumption
	for producer in producers.values():
		var time = producer.time
		
		# Outputs (production)
		for res_id in producer.outputs:
			if res_id in production_rates:
				var amount = producer.outputs[res_id]
				var rate_per_min = (amount / time) * 60.0
				production_rates[res_id] += rate_per_min
			else:
				print("⚠️ Unknown resource in producer output: %s" % res_id)
		
		# Inputs (consumption)
		for res_id in producer.inputs:
			if res_id in consumption_rates:
				var amount = producer.inputs[res_id]
				var rate_per_min = (amount / time) * 60.0
				consumption_rates[res_id] += rate_per_min
			else:
				print("⚠️ Unknown resource in producer input: %s (probably old 'ore' reference)" % res_id)
	
	# Add upkeep consumption
	if upkeep_manager:
		var upkeep_totals = upkeep_manager.get_total_upkeep()
		for res_id in upkeep_totals:
			if res_id in consumption_rates:
				consumption_rates[res_id] += upkeep_totals[res_id]
			else:
				print("⚠️ Unknown resource in upkeep: %s" % res_id)
	
	# Notify GameState
	for res_id in production_rates:
		GameState.update_production_rate(res_id, production_rates[res_id])
	for res_id in consumption_rates:
		GameState.update_consumption_rate(res_id, consumption_rates[res_id])
	
	print("📊 Rates recalculated - Production: %s" % production_rates)
	print("📊 Rates recalculated - Consumption: %s" % consumption_rates)

func get_net_rate(resource_id: String) -> float:
	"""Get net rate for a resource"""
	return production_rates.get(resource_id, 0.0) - consumption_rates.get(resource_id, 0.0)
