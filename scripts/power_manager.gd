extends Node
class_name PowerManager
# Manages power generation and consumption

var buildings_requiring_power: Dictionary = {}  # {grid_pos: power_needed}
var buildings_generating_power: Dictionary = {}  # {grid_pos: power_generated}

signal power_changed()

func register_power_generator(grid_pos: Vector2i, power_generated: float):
	"""Register a building that generates power"""
	buildings_generating_power[grid_pos] = power_generated
	print("⚡ Registered power generator at %s: +%.1f power" % [grid_pos, power_generated])
	power_changed.emit()

func register_power_consumer(grid_pos: Vector2i, power_required: float):
	"""Register a building that requires power"""
	buildings_requiring_power[grid_pos] = power_required
	print("⚡ Registered power consumer at %s: -%.1f power" % [grid_pos, power_required])
	power_changed.emit()

func unregister_building(grid_pos: Vector2i):
	"""Remove a building from power tracking"""
	if grid_pos in buildings_generating_power:
		buildings_generating_power.erase(grid_pos)
		power_changed.emit()
	
	if grid_pos in buildings_requiring_power:
		buildings_requiring_power.erase(grid_pos)
		power_changed.emit()

func get_total_power_available() -> float:
	"""Get total power generation"""
	var total = 0.0
	for power in buildings_generating_power.values():
		total += power
	return total

func get_total_power_required() -> float:
	"""Get total power consumption"""
	var total = 0.0
	for power in buildings_requiring_power.values():
		total += power
	return total

func get_power_remaining() -> float:
	"""Get available power after consumption"""
	return get_total_power_available() - get_total_power_required()

func has_power_for_building(power_needed: float) -> bool:
	"""Check if there's enough remaining power for a building to run"""
	return get_power_remaining() >= power_needed

func get_power_status() -> Dictionary:
	"""Get power grid status for UI"""
	return {
		"available": get_total_power_available(),
		"used": get_total_power_required(),
		"remaining": get_power_remaining()
	}
