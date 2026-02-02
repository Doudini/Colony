extends Node
# GameState - Manages player state and colony progress

# Player resources (global inventory)
var resources: Dictionary = {}

# Storage limits per resource
var storage_limits: Dictionary = {}

# Production/consumption tracking (per minute)
var production_rates: Dictionary = {}  # How much we're producing
var consumption_rates: Dictionary = {}  # How much we're consuming

# Energy system
var energy_capacity: int = 100
var energy_generation_rate: float = 0.0  # Per minute
var energy_consumption_rate: float = 0.0  # Per minute

# Biomatter system (growth limiter)
var biomatter_consumption_rate: float = 0.0  # Per minute
var max_buildings_by_biomatter: int = 999  # Calculated

# Current planet
var current_planet_id: String = "home_planet"

# Space travel (Phase 2)
var space_travel_unlocked: bool = false
var ship_fuel: int = 0
var ship_fuel_capacity: int = 100

# Building efficiency (based on energy/biomatter)
var global_efficiency: float = 1.0  # 0.0 to 1.0

signal resources_changed(resource_id: String, amount: int)
signal space_travel_unlocked_signal()
signal efficiency_changed(new_efficiency: float)
signal production_rate_changed()

func _ready():
	_initialize_resources()
	_initialize_storage_limits()
	_initialize_tracking()

func _initialize_storage_limits():
	"""Set default storage limits"""
	# Base storage (no warehouse)
	# Tier 0 - Raw
	storage_limits["minerals"] = 500
	storage_limits["water"] = 500
	storage_limits["hydrogen"] = 500
	storage_limits["biomatter"] = 200
	storage_limits["ore"] = 500
	storage_limits["rare_minerals"] = 100
	
	# Tier 1 - Refined
	storage_limits["energy"] = 100
	storage_limits["metal"] = 300
	storage_limits["steel"] = 200
	storage_limits["processed_water"] = 300
	storage_limits["bio_paste"] = 200
	storage_limits["hydrogen_cells"] = 200
	
	# Tier 2 - Industrial
	storage_limits["construction_materials"] = 150
	storage_limits["electronics"] = 100
	storage_limits["polymers"] = 150
	
	# Tier 3 - Strategic
	storage_limits["fuel"] = 100
	storage_limits["ship_components"] = 50

func _initialize_tracking():
	"""Initialize production/consumption tracking"""
	for resource in GameData.resources:
		production_rates[resource.id] = 0.0
		consumption_rates[resource.id] = 0.0

func increase_storage(amount: int):
	"""Called when warehouses are built"""
	for resource_id in storage_limits:
		if resource_id != "energy":  # Energy doesn't benefit from warehouses
			storage_limits[resource_id] += amount

func update_production_rate(resource_id: String, rate: float):
	"""Update production rate for a resource"""
	production_rates[resource_id] = rate
	production_rate_changed.emit()

func update_consumption_rate(resource_id: String, rate: float):
	"""Update consumption rate for a resource"""
	consumption_rates[resource_id] = rate
	production_rate_changed.emit()

func get_net_rate(resource_id: String) -> float:
	"""Get net production (production - consumption)"""
	var prod = production_rates.get(resource_id, 0.0)
	var cons = consumption_rates.get(resource_id, 0.0)
	return prod - cons

func get_storage_limit(resource_id: String) -> int:
	"""Get storage limit for a resource"""
	return storage_limits.get(resource_id, 1000)

func _initialize_resources():
	"""Start with basic resources"""
	for resource in GameData.resources:
		resources[resource.id] = 0
	
	# Starting resources - Anno-style bootstrap
	resources["minerals"] = 100  # Build first miners
	resources["water"] = 50
	resources["hydrogen"] = 0
	resources["biomatter"] = 20  # Enough for first buildings
	resources["ore"] = 0
	resources["rare_minerals"] = 0
	
	resources["energy"] = 50  # Starting power
	resources["metal"] = 100  # Kickstart
	resources["steel"] = 50
	resources["processed_water"] = 100
	resources["bio_paste"] = 10
	resources["hydrogen_cells"] = 10
	resources["oxygen"] = 100
	
	resources["wood"] = 100
	resources["food"] = 100
	
	resources["construction_materials"] = 0
	resources["electronics"] = 0
	resources["polymers"] = 10
	
	resources["fuel"] = 10
	resources["ship_components"] = 50

func add_resource(resource_id: String, amount: int):
	"""Add resources to inventory (respects storage limits)"""
	if resource_id in resources:
		var limit = get_storage_limit(resource_id)
		var new_amount = min(resources[resource_id] + amount, limit)
		
		# Check if we hit the limit
		if resources[resource_id] + amount > limit:
			print("⚠️ Storage full for %s! (%d/%d)" % [resource_id, limit, limit])
		
		resources[resource_id] = new_amount
		resources_changed.emit(resource_id, resources[resource_id])
		return true
	return false

func remove_resource(resource_id: String, amount: int) -> bool:
	"""Remove resources from inventory (returns false if not enough)"""
	if resource_id in resources and resources[resource_id] >= amount:
		resources[resource_id] -= amount
		resources_changed.emit(resource_id, resources[resource_id])
		return true
	return false

func has_resources(required: Dictionary) -> bool:
	"""Check if player has required resources"""
	for resource_id in required:
		if resources.get(resource_id, 0) < required[resource_id]:
			return false
	return true

func deduct_resources(costs: Dictionary) -> bool:
	"""Deduct multiple resources at once"""
	if not has_resources(costs):
		return false
	
	for resource_id in costs:
		remove_resource(resource_id, costs[resource_id])
	
	return true

func calculate_efficiency() -> float:
	"""Calculate global efficiency based on energy and biomatter"""
	var energy_ratio = 1.0
	if energy_consumption_rate > 0:
		var available_energy = resources.get("energy", 0)
		energy_ratio = clamp(available_energy / max(energy_consumption_rate, 1.0), 0.0, 1.0)
	
	var biomatter_ratio = 1.0
	if biomatter_consumption_rate > 0:
		var available_biomatter = resources.get("biomatter", 0)
		biomatter_ratio = clamp(available_biomatter / max(biomatter_consumption_rate, 1.0), 0.0, 1.0)
	
	# Use the lower of the two
	var new_efficiency = min(energy_ratio, biomatter_ratio)
	
	# Apply efficiency curve (soft degradation)
	if new_efficiency < 1.0:
		if new_efficiency > 0.75:
			new_efficiency = 0.9  # 90% at 75%+
		elif new_efficiency > 0.5:
			new_efficiency = 0.7  # 70% at 50-75%
		elif new_efficiency > 0.25:
			new_efficiency = 0.4  # 40% at 25-50%
		else:
			new_efficiency = 0.1  # 10% below 25%
	
	if new_efficiency != global_efficiency:
		global_efficiency = new_efficiency
		efficiency_changed.emit(global_efficiency)
	
	return global_efficiency

func unlock_space_travel():
	"""Called when spaceport is built"""
	space_travel_unlocked = true
	space_travel_unlocked_signal.emit()
	print("🚀 Space travel unlocked! You can now launch into orbit!")

func add_fuel(amount: int):
	"""Add fuel to ship"""
	ship_fuel = min(ship_fuel + amount, ship_fuel_capacity)

func use_fuel(amount: int) -> bool:
	"""Use fuel for travel (returns false if not enough)"""
	if ship_fuel >= amount:
		ship_fuel -= amount
		return true
	return false

# Save/Load support
func get_save_data() -> Dictionary:
	return {
		"resources": resources,
		"current_planet_id": current_planet_id,
		"space_travel_unlocked": space_travel_unlocked,
		"ship_fuel": ship_fuel,
		"ship_fuel_capacity": ship_fuel_capacity
	}

func load_save_data(data: Dictionary):
	resources = data.get("resources", {})
	current_planet_id = data.get("current_planet_id", "home_planet")
	space_travel_unlocked = data.get("space_travel_unlocked", false)
	ship_fuel = data.get("ship_fuel", 0)
	ship_fuel_capacity = data.get("ship_fuel_capacity", 100)
