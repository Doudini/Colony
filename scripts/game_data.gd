extends Node
# GameData - Resource and Building definitions (Phase 1 Economy)

# Resource types
var resources: Array[Dictionary] = []

# Building types
var buildings: Array[Dictionary] = []

func _ready():
	_initialize_resources()
	_initialize_buildings()

func _initialize_resources():
	"""Define tiered resource system"""
	resources = [
		# === TIER 0: EXTRACTABLE RESOURCES ===
		{
			"id": "minerals",
			"name": "Minerals",
			"description": "Common raw material. Foundation of economy.",
			"color": Color(0.6, 0.6, 0.6),
			"tier": 0,
			"extractable": true,
			"rarity": "common"
		},
		{
			"id": "crystals",
			"name": "Crystals",
			"description": "High-tech material. Rare and valuable.",
			"color": Color(0.8, 0.3, 1.0),
			"tier": 0,
			"extractable": true,
			"rarity": "rare"
		},
		{
			"id": "hydrogen",
			"name": "Hydrogen",
			"description": "Gas fuel. Powers everything.",
			"color": Color(0.5, 0.7, 1.0),
			"tier": 0,
			"extractable": true,
			"rarity": "uncommon"
		},
		{
			"id": "water",
			"name": "Water",
			"description": "Essential for life and chemistry.",
			"color": Color(0.3, 0.5, 0.9),
			"tier": 0,
			"extractable": true,
			"rarity": "uncommon"
		},
		{
			"id": "biomatter",
			"name": "Biomatter",
			"description": "Organic material. Limits colony growth.",
			"color": Color(0.3, 0.8, 0.3),
			"tier": 0,
			"extractable": true,
			"rarity": "uncommon"
		},
		{
			"id": "ore",
			"name": "Ore",
			"description": "Metallic ore for steel production.",
			"color": Color(0.7, 0.6, 0.5),
			"tier": 0,
			"extractable": true,
			"rarity": "common"
		},
		{
			"id": "rare_minerals",
			"name": "Rare Minerals",
			"description": "Exotic minerals for advanced technology.",
			"color": Color(0.8, 0.3, 1.0),
			"tier": 0,
			"extractable": true,
			"rarity": "rare"
		},
		
		# === TIER 0: LIFE SUPPORT RESOURCES ===
		{
			"id": "food",
			"name": "Food",
			"description": "Essential for colonist survival. Fish, crops, or synthesized.",
			"color": Color(0.9, 0.7, 0.3),
			"tier": 0,
			"extractable": false
		},
		{
			"id": "oxygen",
			"name": "Oxygen",
			"description": "Breathable air. Generated from water electrolysis.",
			"color": Color(0.6, 0.9, 1.0),
			"tier": 0,
			"extractable": false
		},
		
		# === TIER 1: PROCESSED RESOURCES ===
		{
			"id": "metal",
			"name": "Metal",
			"description": "Refined from Minerals. Used in construction.",
			"color": Color(0.75, 0.75, 0.8),
			"tier": 1,
			"extractable": false
		},
		{
			"id": "energy",
			"name": "Energy",
			"description": "Power for buildings. Generated from Hydrogen.",
			"color": Color(1.0, 0.9, 0.3),
			"tier": 1,
			"extractable": false
		},
		{
			"id": "alloy",
			"name": "Alloy",
			"description": "Advanced metal. Minerals + Crystals.",
			"color": Color(0.8, 0.5, 0.2),
			"tier": 1,
			"extractable": false
		},
		{
			"id": "wood",
			"name": "Wood",
			"description": "Raw timber extracted from forests.",
			"color": Color(0.6, 0.4, 0.2),
			"tier": 1,
			"extractable": false  # Comes from forest miner
		},
		
		# === TIER 2: ADVANCED GOODS ===
		{
			"id": "lumber",
			"name": "Lumber",
			"description": "Processed wood planks for construction.",
			"color": Color(0.7, 0.5, 0.3),
			"tier": 2,
			"extractable": false
		},
		{
			"id": "components",
			"name": "Components",
			"description": "Basic machine parts. Metal + Alloy.",
			"color": Color(0.6, 0.6, 0.7),
			"tier": 2,
			"extractable": false
		},
		{
			"id": "machine_parts",
			"name": "Machine Parts",
			"description": "Complex components. Metal + Alloy.",
			"color": Color(0.5, 0.5, 0.6),
			"tier": 2,
			"extractable": false
		},
		{
			"id": "electronics",
			"name": "Electronics",
			"description": "High-tech components. Crystals required.",
			"color": Color(0.2, 0.6, 0.9),
			"tier": 2,
			"extractable": false
		},
		
		# === TIER 3: HIGH-TECH RESOURCES ===
		{
			"id": "fuel",
			"name": "Rocket Fuel",
			"description": "High-energy fuel for spacecraft.",
			"color": Color(1.0, 0.4, 0.2),
			"tier": 3,
			"extractable": false
		}
	]

func _initialize_buildings():
	"""Define all building types with clear progression"""
	buildings = [
		# === STARTING BUILDING ===
		{
			"id": "landing_pad",
			"name": "Landing Pad",
			"description": "Your starting point. Free.",
			"size": Vector2i(2, 2),
			"build_cost": {},
			"upkeep": {},
			"production": {},
			"color": Color(0.4, 0.4, 0.5),
			"category": "infrastructure",
			"tier": 0
		},
		
		# === TIER 0: LIFE SUPPORT & HABITATION ===
		{
			"id": "fishery",
			"name": "Fishery",
			"description": "Harvests fish from shallow water. Your colony's first food source!",
			"size": Vector2i(2, 2),
			"build_cost": {
				"minerals": 15,
				"wood": 10
			},
			"upkeep": {},
			"placement_requirement": "adjacent_shallow_water",
			"production": {
				"input": {},
				"output": {"food": 3},
				"time": 10.0
			},
			"color": Color(0.3, 0.5, 0.7),
			"category": "life_support",
			"tier": 0
		},
		{
			"id": "farm",
			"name": "Farm",
			"description": "Produces biomatter for food processing.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 15,
				"wood": 10
			},
			"upkeep": {
				"oxygen": 1
			},
			"production": {
				"input": {"energy": 1.0},
				"output": {"biomatter": 5},
				"time": 10.0
			},
			"color": Color(0.302, 0.149, 0.224, 1.0),
			"category": "life_support",
			"tier": 0
		},
		{
			"id": "foodfactory",
			"name": "Food Factory",
			"description": "Converts biomatter into food rations.",
			"size": Vector2i(2, 2),
			"build_cost": {
				"minerals": 15,
				"wood": 10
			},
			"upkeep": {
				"oxygen": 1
			},
			"production": {
				"input": {"energy": 1, "biomatter": 1},
				"output": {"food": 5},
				"time": 10.0
			},
			"color": Color(0.9, 0.7, 0.3),
			"category": "life_support",
			"tier": 0
		},
		{
			"id": "oxygen_generator",
			"name": "Oxygen Generator",
			"description": "Electrolyzes water into oxygen. Essential for breathing!",
			"size": Vector2i(2, 2),
			"build_cost": {
				"minerals": 25,
				"metal": 10
			},
			"upkeep": {
			},
			"production": {
				"input": {"energy": 2, "water": 2},
				"output": {"oxygen": 5},
				"time": 10.0
			},
			"color": Color(0.6, 0.8, 1.0),
			"category": "life_support",
			"tier": 0
		},
		{
			"id": "solar_panel",
			"name": "Solar Panel",
			"description": "Generates energy from sunlight. Free and reliable!",
			"size": Vector2i(2, 2),
			"build_cost": {
				"minerals": 20,
				"metal": 5
			},
			"upkeep": {},
			"production": {
				"input": {},
				"output": {"energy": 2},
				"time": 10.0
			},
			"color": Color(0.2, 0.3, 0.5),
			"category": "energy",
			"tier": 0
		},
		{
			"id": "habitat",
			"name": "Habitat",
			"description": "Basic housing for colonists.",
			"size": Vector2i(2, 2),
			"build_cost": {
				"minerals": 20,
				"lumber": 10
			},
			"upkeep": {
				"food": 1,
				"oxygen": 1
			},
			"population_capacity": 5,
			"color": Color(0.6, 0.6, 0.6),
			"category": "habitation",
			"tier": 0
		},
		{
			"id": "park",
			"name": "Park",
			"description": "Improves colonist happiness.",
			"size": Vector2i(2, 2),
			"build_cost": {
				"lumber": 10
			},
			"upkeep": {},
			"happiness_bonus": 0.1,
			"color": Color(0.3, 0.7, 0.3),
			"category": "social",
			"tier": 0
		},
		{
			"id": "hospital",
			"name": "Hospital",
			"description": "Provides medical care. Improves colonist happiness.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 40,
				"lumber": 20,
				"components": 10
			},
			"upkeep": {
			},
			"power_required": 2,
			"happiness_bonus": 0.15,
			"color": Color(1.0, 0.3, 0.3),
			"category": "social",
			"tier": 1
		},
		{
			"id": "police",
			"name": "Police Station",
			"description": "Maintains order. Improves colonist happiness.",
			"size": Vector2i(2, 2),
			"build_cost": {
				"minerals": 30,
				"lumber": 15
			},
			"upkeep": {
			},
			"power_required": 1,
			"happiness_bonus": 0.1,
			"color": Color(0.2, 0.2, 0.8),
			"category": "social",
			"tier": 1
		},
		{
			"id": "firebrigade",
			"name": "Fire Brigade",
			"description": "Emergency services. Improves colonist happiness.",
			"size": Vector2i(2, 2),
			"build_cost": {
				"minerals": 30,
				"lumber": 15
			},
			"upkeep": {
			},
			"power_required": 1,
			"happiness_bonus": 0.1,
			"color": Color(0.9, 0.3, 0.1),
			"category": "social",
			"tier": 1
		},
		{
			"id": "recreationcenter",
			"name": "Recreation Center",
			"description": "Entertainment facility. Improves colonist happiness.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 35,
				"lumber": 20
			},
			"upkeep": {
			},
			"power_required": 2,
			"happiness_bonus": 0.12,
			"color": Color(0.9, 0.7, 0.2),
			"category": "social",
			"tier": 1
		},
		{
			"id": "stadium",
			"name": "Stadium",
			"description": "Large sports venue. Greatly improves colonist happiness.",
			"size": Vector2i(4, 4),
			"build_cost": {
				"minerals": 80,
				"lumber": 40,
				"components": 20
			},
			"upkeep": {
			},
			"power_required": 3,
			"happiness_bonus": 0.2,
			"color": Color(0.5, 0.8, 0.3),
			"category": "social",
			"tier": 2
		},
		{
			"id": "bar",
			"name": "Bar",
			"description": "Social gathering place. Improves colonist happiness.",
			"size": Vector2i(2, 2),
			"build_cost": {
				"lumber": 10
			},
			"upkeep": {},
			"happiness_bonus": 0.08,
			"color": Color(0.7, 0.5, 0.3),
			"category": "social",
			"tier": 0
		},
		
		# === TIER 1: EXTRACTION ===
		{
			"id": "miner",
			"name": "Miner",
			"description": "Extracts ANY resource from deposits. Consumes energy per cycle.",
			"size": Vector2i(1, 1),
			"build_cost": {
				"minerals": 10
			},
			"upkeep": {
				"biomatter": 1,
				"energy": 1
			},
			"production": {},
			"extraction_rate": 3.0,  # Per minute
			"color": Color(0.7, 0.5, 0.3),
			"category": "extraction",
			"tier": 1
		},
		{
			"id": "forester",
			"name": "Forester",
			"description": "Harvests wood from forest tiles. Place on lowland/forest.",
			"size": Vector2i(1, 1),
			"build_cost": {
				"minerals": 8
			},
			"upkeep": {
				"energy": 0.5
			},
			"production": {},
			"extraction_rate": 2.0,  # Per minute - extracts wood
			"color": Color(0.4, 0.6, 0.2),
			"category": "extraction",
			"tier": 1
		},
		
		# === TIER 2: BASIC PROCESSING ===
		{
			"id": "power_plant",
			"name": "Power Plant",
			"description": "Burns hydrogen to generate energy.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 25,
				"metal": 10
			},
			"upkeep": {
				"biomatter": 2
			},
			"production": {
				"input": {"biomatter": 1, "hydrogen": 2},
				"output": {"energy": 10},
				"time": 10.0
			},
			"color": Color(0.9, 0.8, 0.2),
			"category": "production",
			"tier": 2
		},
		{
			"id": "smelter",
			"name": "Smelter",
			"description": "Minerals + Biomatter → Metal. Foundation of industry.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 40  # Only minerals - no chicken-egg problem!
			},
			"upkeep": {
			},
			"production": {
				"input": {"energy": 3, "minerals": 4, "biomatter": 1},  # Biomatter as fuel
				"output": {"metal": 1},
				"time": 10.0
			},
			"color": Color(0.8, 0.4, 0.2),
			"category": "production",
			"tier": 2
		},
		{
			"id": "alloy_foundry",
			"name": "Alloy Foundry",
			"description": "Minerals + Crystals → Alloy.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 30,
				"metal": 15
			},
			"upkeep": {
				"biomatter": 2
			},
			"production": {
				"input": {"energy": 3, "minerals": 2, "crystals": 1},
				"output": {"alloy": 1},
				"time": 8.0
			},
			"color": Color(0.8, 0.5, 0.2),
			"category": "production",
			"tier": 2
		},
		{
			"id": "component_factory",
			"name": "Component Factory",
			"description": "Metal + Alloy → Components. Basic parts production.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 25,
				"metal": 10
			},
			"upkeep": {
				"biomatter": 1
			},
			"production": {
				"input": {"energy": 3, "metal": 2, "alloy": 1},
				"output": {"components": 1},
				"time": 10.0
			},
			"color": Color(0.6, 0.6, 0.7),
			"category": "production",
			"tier": 2
		},
		{
			"id": "lumber_mill",
			"name": "Lumber Mill",
			"description": "Wood → Lumber. Processes raw timber into planks.",
			"size": Vector2i(2, 2),
			"build_cost": {
				"minerals": 15,
				"metal": 5
			},
			"upkeep": {
			},
			"production": {
				"input": {"energy": 1, "wood": 2},
				"output": {"lumber": 1},
				"time": 1.0
			},
			"color": Color(0.7, 0.5, 0.3),
			"category": "production",
			"tier": 2
		},
		
		# === TIER 3: ADVANCED PRODUCTION ===
		{
			"id": "workshop",
			"name": "Workshop",
			"description": "Metal + Alloy → Machine Parts.",
			"size": Vector2i(4, 4),
			"build_cost": {
				"metal": 30,
				"alloy": 10
			},
			"upkeep": {
				"biomatter": 2
			},
			"production": {
				"input": {"energy": 4, "metal": 2, "alloy": 1},
				"output": {"machine_parts": 1},
				"time": 10.0
			},
			"color": Color(0.5, 0.5, 0.6),
			"category": "production",
			"tier": 3
		},
		{
			"id": "electronics_factory",
			"name": "Electronics Factory",
			"description": "Crystals + Metal → Electronics.",
			"size": Vector2i(4, 4),
			"build_cost": {
				"metal": 40,
				"alloy": 15,
				"crystals": 10
			},
			"upkeep": {
				"biomatter": 2
			},
			"production": {
				"input": {"energy": 5, "crystals": 2, "metal": 1},
				"output": {"electronics": 1},
				"time": 12.0
			},
			"color": Color(0.2, 0.6, 0.9),
			"category": "production",
			"tier": 3
		},
		
		# === UTILITY BUILDINGS ===
		{
			"id": "warehouse",
			"name": "Warehouse",
			"description": "Stores resources. No upkeep.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 15
			},
			"upkeep": {},
			"production": {},
			"storage_capacity": 500,
			"color": Color(0.5, 0.5, 0.6),
			"category": "storage",
			"tier": 1
		},
		
		# === RESEARCH BUILDINGS ===
		{
			"id": "building_research",
			"name": "Building Research Lab",
			"description": "Unlocks building upgrades and advanced construction.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 50,
				"metal": 30,
				"components": 10
			},
			"upkeep": {
			},
			"production": {},
			"color": Color(0.07, 0.255, 0.242, 1.0),
			"category": "research",
			"tier": 2
		},
		{
			"id": "ship_research",
			"name": "Ship Research Lab",
			"description": "Unlocks ship upgrades and faster trade routes.",
			"size": Vector2i(3, 3),
			"build_cost": {
				"minerals": 50,
				"metal": 30,
				"components": 10
			},
			"upkeep": {
			},
			"power_required": 2,
			"production": {},
			"color": Color(0.07, 0.212, 0.161, 1.0),
			"category": "research",
			"tier": 2
		},
		
		# === ENDGAME ===
		{
			"id": "spaceport",
			"name": "Spaceport",
			"description": "Victory! Launch to space.",
			"size": Vector2i(5, 5),
			"build_cost": {
				"alloy": 100,
				"machine_parts": 50,
				"electronics": 30,
				"energy": 100
			},
			"upkeep": {},
			"production": {},
			"color": Color(0.2, 0.4, 0.8),
			"category": "infrastructure",
			"special": "enables_space_travel",
			"tier": 4
		}
	]

## Helper functions
#func get_resource_by_id(resource_id: String) -> Dictionary:
	#for resource in resources:
		#if resource.id == resource_id:
			#return resource
	#return {}
#
#func get_building_by_id(building_id: String) -> Dictionary:
	#for building in buildings:
		#if building.id == building_id:
			#return building
	#return {}
#
#func can_afford_building(building_id: String, inventory: Dictionary) -> bool:
	#var building = get_building_by_id(building_id)
	#if building.is_empty():
		#return false
	#
	#var costs = building.get("build_cost", {})
	#for resource_id in costs:
		#var required = costs[resource_id]
		#var available = inventory.get(resource_id, 0)
		#if available < required:
			#return false
	#
	#return true
#
#func get_extractable_resources() -> Array:
	#"""Get list of resources that can be extracted"""
	#var extractable = []
	#for resource in resources:
		#if resource.get("extractable", false):
			#extractable.append(resource)
	#return extractable

# Helper functions
func get_resource_by_id(resource_id: String) -> Dictionary:
	for resource in resources:
		if resource.id == resource_id:
			return resource
	return {}

func get_building_by_id(building_id: String) -> Dictionary:
	for building in buildings:
		if building.id == building_id:
			return building
	return {}

func can_afford_building(building_id: String, inventory: Dictionary) -> bool:
	var building = get_building_by_id(building_id)
	if building.is_empty():
		return false
	
	var costs = building.get("build_cost", {})
	for resource_id in costs:
		var required = costs[resource_id]
		var available = inventory.get(resource_id, 0)
		if available < required:
			return false
	
	return true

func get_extractable_resources() -> Array:
	"""Get list of resources that can be extracted"""
	var extractable = []
	for resource in resources:
		if resource.get("extractable", false):
			extractable.append(resource)
	return extractable

#extends Node
## GameData - Resource and Building definitions (Phase 1 Economy)
#
## Resource types
#var resources: Array[Dictionary] = []
#
## Building types
#var buildings: Array[Dictionary] = []
#
#func _ready():
	#_initialize_resources()
	#_initialize_buildings()
#
#func _initialize_resources():
	#"""Define tiered resource system"""
	#resources = [
		## === TIER 0: EXTRACTABLE RESOURCES ===
		#{
			#"id": "minerals",
			#"name": "Minerals",
			#"description": "Common raw material. Foundation of economy.",
			#"color": Color(0.6, 0.6, 0.6),
			#"tier": 0,
			#"extractable": true,
			#"rarity": "common"
		#},
		#{
			#"id": "crystals",
			#"name": "Crystals",
			#"description": "High-tech material. Rare and valuable.",
			#"color": Color(0.8, 0.3, 1.0),
			#"tier": 0,
			#"extractable": true,
			#"rarity": "rare"
		#},
		#{
			#"id": "hydrogen",
			#"name": "Hydrogen",
			#"description": "Gas fuel. Powers everything.",
			#"color": Color(0.5, 0.7, 1.0),
			#"tier": 0,
			#"extractable": true,
			#"rarity": "uncommon"
		#},
		#{
			#"id": "water",
			#"name": "Water",
			#"description": "Essential for life and chemistry.",
			#"color": Color(0.3, 0.5, 0.9),
			#"tier": 0,
			#"extractable": true,
			#"rarity": "uncommon"
		#},
		#{
			#"id": "biomatter",
			#"name": "Biomatter",
			#"description": "Organic material. Limits colony growth.",
			#"color": Color(0.3, 0.8, 0.3),
			#"tier": 0,
			#"extractable": true,
			#"rarity": "uncommon"
		#},
		#{
			#"id": "ore",
			#"name": "Ore",
			#"description": "Metallic ore for steel production.",
			#"color": Color(0.7, 0.6, 0.5),
			#"tier": 0,
			#"extractable": true,
			#"rarity": "common"
		#},
		#{
			#"id": "rare_minerals",
			#"name": "Rare Minerals",
			#"description": "Exotic minerals for advanced technology.",
			#"color": Color(0.8, 0.3, 1.0),
			#"tier": 0,
			#"extractable": true,
			#"rarity": "rare"
		#},
		#
		## === TIER 0: LIFE SUPPORT RESOURCES ===
		#{
			#"id": "food",
			#"name": "Food",
			#"description": "Essential for colonist survival. Fish, crops, or synthesized.",
			#"color": Color(0.9, 0.7, 0.3),
			#"tier": 0,
			#"extractable": false
		#},
		#{
			#"id": "oxygen",
			#"name": "Oxygen",
			#"description": "Breathable air. Generated from water electrolysis.",
			#"color": Color(0.6, 0.9, 1.0),
			#"tier": 0,
			#"extractable": false
		#},
		#
		## === TIER 1: PROCESSED RESOURCES ===
		#{
			#"id": "metal",
			#"name": "Metal",
			#"description": "Refined from Minerals. Used in construction.",
			#"color": Color(0.75, 0.75, 0.8),
			#"tier": 1,
			#"extractable": false
		#},
		#{
			#"id": "energy",
			#"name": "Energy",
			#"description": "Power for buildings. Generated from Hydrogen.",
			#"color": Color(1.0, 0.9, 0.3),
			#"tier": 1,
			#"extractable": false
		#},
		#{
			#"id": "alloy",
			#"name": "Alloy",
			#"description": "Advanced metal. Minerals + Crystals.",
			#"color": Color(0.8, 0.5, 0.2),
			#"tier": 1,
			#"extractable": false
		#},
		#{
			#"id": "wood",
			#"name": "Wood",
			#"description": "Raw timber extracted from forests.",
			#"color": Color(0.6, 0.4, 0.2),
			#"tier": 1,
			#"extractable": false  # Comes from forest miner
		#},
		#
		## === TIER 2: ADVANCED GOODS ===
		#{
			#"id": "lumber",
			#"name": "Lumber",
			#"description": "Processed wood planks for construction.",
			#"color": Color(0.7, 0.5, 0.3),
			#"tier": 2,
			#"extractable": false
		#},
		#{
			#"id": "components",
			#"name": "Components",
			#"description": "Basic machine parts. Metal + Alloy.",
			#"color": Color(0.6, 0.6, 0.7),
			#"tier": 2,
			#"extractable": false
		#},
		#{
			#"id": "machine_parts",
			#"name": "Machine Parts",
			#"description": "Complex components. Metal + Alloy.",
			#"color": Color(0.5, 0.5, 0.6),
			#"tier": 2,
			#"extractable": false
		#},
		#{
			#"id": "electronics",
			#"name": "Electronics",
			#"description": "High-tech components. Crystals required.",
			#"color": Color(0.2, 0.6, 0.9),
			#"tier": 2,
			#"extractable": false
		#},
		#
		## === TIER 3: HIGH-TECH RESOURCES ===
		#{
			#"id": "fuel",
			#"name": "Rocket Fuel",
			#"description": "High-energy fuel for spacecraft.",
			#"color": Color(1.0, 0.4, 0.2),
			#"tier": 3,
			#"extractable": false
		#}
	#]
#
#func _initialize_buildings():
	#"""Define all building types with clear progression"""
	#buildings = [
		## === STARTING BUILDING ===
		#{
			#"id": "landing_pad",
			#"name": "Landing Pad",
			#"description": "Your starting point. Free.",
			#"size": Vector2i(2, 2),
			#"build_cost": {},
			#"upkeep": {},
			#"production": {},
			#"color": Color(0.4, 0.4, 0.5),
			#"category": "infrastructure",
			#"tier": 0
		#},
		#
		## === TIER 0: LIFE SUPPORT & HABITATION ===
		#{
			#"id": "fishery",
			#"name": "Fishery",
			#"description": "Harvests fish from shallow water. Your colony's first food source!",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"minerals": 15,
				#"wood": 10
			#},
			#"upkeep": {},
			#"placement_requirement": "adjacent_shallow_water",
			#"production": {
				#"input": {},
				#"output": {"food": 3},
				#"time": 10.0
			#},
			#"color": Color(0.3, 0.5, 0.7),
			#"category": "life_support",
			#"tier": 0
		#},
		#{
			#"id": "farm",
			#"name": "Farm",
			#"description": "Produces biomatter for food processing.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 15,
				#"wood": 10
			#},
			#"upkeep": {
				#"energy": 1,
				#"oxygen": 1
			#},
			#"production": {
				#"input": {},
				#"output": {"biomatter": 5},
				#"time": 10.0
			#},
			#"color": Color(0.302, 0.149, 0.224, 1.0),
			#"category": "life_support",
			#"tier": 0
		#},
		#{
			#"id": "foodfactory",
			#"name": "Food Factory",
			#"description": "Converts biomatter into food rations.",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"minerals": 15,
				#"wood": 10
			#},
			#"upkeep": {
				#"energy": 1,
				#"oxygen": 1
			#},
			#"production": {
				#"input": {"biomatter": 1},
				#"output": {"food": 5},
				#"time": 10.0
			#},
			#"color": Color(0.9, 0.7, 0.3),
			#"category": "life_support",
			#"tier": 0
		#},
		#{
			#"id": "oxygen_generator",
			#"name": "Oxygen Generator",
			#"description": "Electrolyzes water into oxygen. Essential for breathing!",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"minerals": 25,
				#"metal": 10
			#},
			#"upkeep": {
				#"energy": 2
			#},
			#"production": {
				#"input": {"water": 2},
				#"output": {"oxygen": 5},
				#"time": 10.0
			#},
			#"color": Color(0.6, 0.8, 1.0),
			#"category": "life_support",
			#"tier": 0
		#},
		#{
			#"id": "solar_panel",
			#"name": "Solar Panel",
			#"description": "Generates free energy from sunlight. Slow but reliable!",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"minerals": 20,
				#"metal": 5
			#},
			#"upkeep": {},
			#"production": {
				#"input": {},
				#"output": {"energy": 2},
				#"time": 10.0
			#},
			#"color": Color(0.2, 0.3, 0.5),
			#"category": "production",
			#"tier": 0
		#},
		#{
			#"id": "habitat",
			#"name": "Habitat",
			#"description": "Basic housing for colonists.",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"minerals": 20,
				#"lumber": 10
			#},
			#"upkeep": {
				#"energy": 1,
				#"food": 1,
				#"oxygen": 1
			#},
			#"population_capacity": 5,
			#"color": Color(0.6, 0.6, 0.6),
			#"category": "social",
			#"tier": 0
		#},
		#{
			#"id": "park",
			#"name": "Park",
			#"description": "Improves colonist happiness.",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"lumber": 10
			#},
			#"upkeep": {},
			#"happiness_bonus": 0.1,
			#"color": Color(0.3, 0.7, 0.3),
			#"category": "social",
			#"tier": 0
		#},
		#{
			#"id": "hospital",
			#"name": "Hospital",
			#"description": "Provides medical care. Improves colonist happiness.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 40,
				#"lumber": 20,
				#"components": 10
			#},
			#"upkeep": {
				#"energy": 2
			#},
			#"happiness_bonus": 0.15,
			#"color": Color(1.0, 0.3, 0.3),
			#"category": "social",
			#"tier": 1
		#},
		#{
			#"id": "police",
			#"name": "Police Station",
			#"description": "Maintains order. Improves colonist happiness.",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"minerals": 30,
				#"lumber": 15
			#},
			#"upkeep": {
				#"energy": 1
			#},
			#"happiness_bonus": 0.1,
			#"color": Color(0.2, 0.2, 0.8),
			#"category": "social",
			#"tier": 1
		#},
		#{
			#"id": "firebrigade",
			#"name": "Fire Brigade",
			#"description": "Emergency services. Improves colonist happiness.",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"minerals": 30,
				#"lumber": 15
			#},
			#"upkeep": {
				#"energy": 1
			#},
			#"happiness_bonus": 0.1,
			#"color": Color(0.9, 0.3, 0.1),
			#"category": "social",
			#"tier": 1
		#},
		#{
			#"id": "recreationcenter",
			#"name": "Recreation Center",
			#"description": "Entertainment facility. Improves colonist happiness.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 35,
				#"lumber": 20
			#},
			#"upkeep": {
				#"energy": 2
			#},
			#"happiness_bonus": 0.12,
			#"color": Color(0.9, 0.7, 0.2),
			#"category": "social",
			#"tier": 1
		#},
		#{
			#"id": "stadium",
			#"name": "Stadium",
			#"description": "Large sports venue. Greatly improves colonist happiness.",
			#"size": Vector2i(4, 4),
			#"build_cost": {
				#"minerals": 80,
				#"lumber": 40,
				#"components": 20
			#},
			#"upkeep": {
				#"energy": 3
			#},
			#"happiness_bonus": 0.2,
			#"color": Color(0.5, 0.8, 0.3),
			#"category": "social",
			#"tier": 2
		#},
		#{
			#"id": "bar",
			#"name": "Bar",
			#"description": "Social gathering place. Improves colonist happiness.",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"lumber": 10
			#},
			#"upkeep": {},
			#"happiness_bonus": 0.08,
			#"color": Color(0.7, 0.5, 0.3),
			#"category": "social",
			#"tier": 0
		#},
		#
		## === TIER 1: EXTRACTION ===
		#{
			#"id": "miner",
			#"name": "Miner",
			#"description": "Extracts ANY resource from deposits. Universal!",
			#"size": Vector2i(1, 1),
			#"build_cost": {
				#"minerals": 10
			#},
			#"upkeep": {
				#"energy": 1,
				#"biomatter": 1
			#},
			#"production": {},
			#"extraction_rate": 3.0,  # Per minute
			#"color": Color(0.7, 0.5, 0.3),
			#"category": "extraction",
			#"tier": 1
		#},
		#{
			#"id": "forester",
			#"name": "Forester",
			#"description": "Harvests wood from forest tiles. Place on lowland/forest.",
			#"size": Vector2i(1, 1),
			#"build_cost": {
				#"minerals": 8
			#},
			#"upkeep": {
				#"energy": 0.5
			#},
			#"production": {},
			#"extraction_rate": 2.0,  # Per minute - extracts wood
			#"color": Color(0.4, 0.6, 0.2),
			#"category": "extraction",
			#"tier": 1
		#},
		#
		## === TIER 2: BASIC PROCESSING ===
		#{
			#"id": "power_plant",
			#"name": "Power Plant",
			#"description": "Hydrogen → Energy. Core infrastructure.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 25,
				#"metal": 10
			#},
			#"upkeep": {
				#"biomatter": 2
			#},
			#"production": {
				#"input": {"hydrogen": 2},
				#"output": {"energy": 10},
				#"time": 6.0  # Per minute
			#},
			#"color": Color(0.9, 0.8, 0.2),
			#"category": "production",
			#"tier": 2
		#},
		#{
			#"id": "smelter",
			#"name": "Smelter",
			#"description": "Minerals + Biomatter → Metal. Foundation of industry.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 40  # Only minerals - no chicken-egg problem!
			#},
			#"upkeep": {
				#"energy": 3
			#},
			#"production": {
				#"input": {"minerals": 4, "biomatter": 1},  # Biomatter as fuel
				#"output": {"metal": 1},
				#"time": 10.0
			#},
			#"color": Color(0.8, 0.4, 0.2),
			#"category": "production",
			#"tier": 2
		#},
		#{
			#"id": "alloy_foundry",
			#"name": "Alloy Foundry",
			#"description": "Minerals + Crystals → Alloy.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 30,
				#"metal": 15
			#},
			#"upkeep": {
				#"energy": 3,
				#"biomatter": 2
			#},
			#"production": {
				#"input": {"minerals": 2, "crystals": 1},
				#"output": {"alloy": 1},
				#"time": 8.0
			#},
			#"color": Color(0.8, 0.5, 0.2),
			#"category": "production",
			#"tier": 2
		#},
		#{
			#"id": "component_factory",
			#"name": "Component Factory",
			#"description": "Metal + Alloy → Components. Basic parts production.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 25,
				#"metal": 10
			#},
			#"upkeep": {
				#"energy": 3,
				#"biomatter": 1
			#},
			#"production": {
				#"input": {"metal": 2, "alloy": 1},
				#"output": {"components": 1},
				#"time": 10.0
			#},
			#"color": Color(0.6, 0.6, 0.7),
			#"category": "production",
			#"tier": 2
		#},
		#{
			#"id": "lumber_mill",
			#"name": "Lumber Mill",
			#"description": "Wood → Lumber. Processes raw timber into planks.",
			#"size": Vector2i(2, 2),
			#"build_cost": {
				#"minerals": 15,
				#"metal": 5
			#},
			#"upkeep": {
				#"energy": 1
			#},
			#"production": {
				#"input": {"wood": 2},
				#"output": {"lumber": 1},
				#"time": 10.0
			#},
			#"color": Color(0.7, 0.5, 0.3),
			#"category": "production",
			#"tier": 2
		#},
		#
		## === TIER 3: ADVANCED PRODUCTION ===
		#{
			#"id": "workshop",
			#"name": "Workshop",
			#"description": "Metal + Alloy → Machine Parts.",
			#"size": Vector2i(4, 4),
			#"build_cost": {
				#"metal": 30,
				#"alloy": 10
			#},
			#"upkeep": {
				#"energy": 4,
				#"biomatter": 2
			#},
			#"production": {
				#"input": {"metal": 2, "alloy": 1},
				#"output": {"machine_parts": 1},
				#"time": 10.0
			#},
			#"color": Color(0.5, 0.5, 0.6),
			#"category": "production",
			#"tier": 3
		#},
		#{
			#"id": "electronics_factory",
			#"name": "Electronics Factory",
			#"description": "Crystals + Metal → Electronics.",
			#"size": Vector2i(4, 4),
			#"build_cost": {
				#"metal": 40,
				#"alloy": 15,
				#"crystals": 10
			#},
			#"upkeep": {
				#"energy": 5,
				#"biomatter": 2
			#},
			#"production": {
				#"input": {"crystals": 2, "metal": 1},
				#"output": {"electronics": 1},
				#"time": 12.0
			#},
			#"color": Color(0.2, 0.6, 0.9),
			#"category": "production",
			#"tier": 3
		#},
		#
		## === UTILITY BUILDINGS ===
		#{
			#"id": "warehouse",
			#"name": "Warehouse",
			#"description": "Stores resources. No upkeep.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 15
			#},
			#"upkeep": {},
			#"production": {},
			#"storage_capacity": 500,
			#"color": Color(0.5, 0.5, 0.6),
			#"category": "infrastructure",
			#"tier": 1
		#},
		#
		## === RESEARCH BUILDINGS ===
		#{
			#"id": "building_research",
			#"name": "Building Research Lab",
			#"description": "Unlocks building upgrades and advanced construction.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 50,
				#"metal": 30,
				#"components": 10
			#},
			#"upkeep": {
				#"energy": 2
			#},
			#"production": {},
			#"color": Color(0.07, 0.255, 0.242, 1.0),
			#"category": "infrastructure",
			#"tier": 2
		#},
		#{
			#"id": "ship_research",
			#"name": "Ship Research Lab",
			#"description": "Unlocks ship upgrades and faster trade routes.",
			#"size": Vector2i(3, 3),
			#"build_cost": {
				#"minerals": 50,
				#"metal": 30,
				#"components": 10
			#},
			#"upkeep": {
				#"energy": 2
			#},
			#"production": {},
			#"color": Color(0.07, 0.212, 0.161, 1.0),
			#"category": "infrastructure",
			#"tier": 2
		#},
		#
		## === ENDGAME ===
		#{
			#"id": "spaceport",
			#"name": "Spaceport",
			#"description": "Victory! Launch to space.",
			#"size": Vector2i(5, 5),
			#"build_cost": {
				#"alloy": 100,
				#"machine_parts": 50,
				#"electronics": 30,
				#"energy": 100
			#},
			#"upkeep": {},
			#"production": {},
			#"color": Color(0.2, 0.4, 0.8),
			#"category": "infrastructure",
			#"special": "enables_space_travel",
			#"tier": 4
		#}
	#]
#
## Helper functions
#func get_resource_by_id(resource_id: String) -> Dictionary:
	#for resource in resources:
		#if resource.id == resource_id:
			#return resource
	#return {}
#
#func get_building_by_id(building_id: String) -> Dictionary:
	#for building in buildings:
		#if building.id == building_id:
			#return building
	#return {}
#
#func can_afford_building(building_id: String, inventory: Dictionary) -> bool:
	#var building = get_building_by_id(building_id)
	#if building.is_empty():
		#return false
	#
	#var costs = building.get("build_cost", {})
	#for resource_id in costs:
		#var required = costs[resource_id]
		#var available = inventory.get(resource_id, 0)
		#if available < required:
			#return false
	#
	#return true
#
#func get_extractable_resources() -> Array:
	#"""Get list of resources that can be extracted"""
	#var extractable = []
	#for resource in resources:
		#if resource.get("extractable", false):
			#extractable.append(resource)
	#return extractable
