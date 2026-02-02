extends PanelContainer
class_name ResourceDetailsPanel
# Shows detailed information about a specific resource

@onready var title_label = $MarginContainer/VBox/Title
@onready var storage_label = $MarginContainer/VBox/Storage
@onready var production_label = $MarginContainer/VBox/Production
@onready var consumption_label = $MarginContainer/VBox/Consumption
@onready var net_label = $MarginContainer/VBox/Net
@onready var used_by_label = $MarginContainer/VBox/UsedBy
@onready var produced_by_label = $MarginContainer/VBox/ProducedBy
@onready var export_label = $MarginContainer/VBox/ExportValue

var current_resource_id: String = ""

func _ready():
	hide()

func show_resource_details(resource_id: String):
	"""Display detailed info about a resource"""
	current_resource_id = resource_id
	
	var res_data = GameData.get_resource_by_id(resource_id)
	if res_data.is_empty():
		hide()
		return
	
	# Title
	title_label.text = res_data.name.to_upper()
	title_label.add_theme_color_override("font_color", res_data.color)
	
	# Storage
	var current = GameState.resources.get(resource_id, 0)
	var limit = GameState.get_storage_limit(resource_id)
	var percent = (float(current) / float(limit)) * 100.0
	storage_label.text = "Stored: %d / %d (%.0f%%)" % [current, limit, percent]
	
	# Production
	var prod_rate = GameState.production_rates.get(resource_id, 0.0)
	production_label.text = "Production: +%.1f/min" % prod_rate
	if prod_rate > 0:
		production_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		production_label.add_theme_color_override("font_color", Color.GRAY)
	
	# Consumption
	var cons_rate = GameState.consumption_rates.get(resource_id, 0.0)
	consumption_label.text = "Consumption: -%.1f/min" % cons_rate
	if cons_rate > 0:
		consumption_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		consumption_label.add_theme_color_override("font_color", Color.GRAY)
	
	# Net
	var net_rate = prod_rate - cons_rate
	net_label.text = "Net: %+.1f/min" % net_rate
	
	if net_rate > 0:
		net_label.add_theme_color_override("font_color", Color.GREEN)
		# Time to fill
		if current < limit:
			var time_to_fill = (limit - current) / net_rate
			net_label.text += " (full in %.0f min)" % time_to_fill
	elif net_rate < 0:
		net_label.add_theme_color_override("font_color", Color.RED)
		# Time to empty
		if current > 0:
			var time_to_empty = current / abs(net_rate)
			net_label.text += " (empty in %.0f min)" % time_to_empty
	else:
		net_label.add_theme_color_override("font_color", Color.GRAY)
	
	# Used by (what consumes this)
	var used_by = _find_consumers(resource_id)
	if used_by.size() > 0:
		used_by_label.text = "Used by:\n  - " + "\n  - ".join(used_by)
		used_by_label.show()
	else:
		used_by_label.hide()
	
	# Produced by (what produces this)
	var produced_by = _find_producers(resource_id)
	if produced_by.size() > 0:
		produced_by_label.text = "Produced by:\n  + " + "\n  + ".join(produced_by)
		produced_by_label.show()
	else:
		produced_by_label.hide()
	
	# Export value (future)
	export_label.text = "Export Value: ★★☆"
	
	show()

func _find_consumers(resource_id: String) -> Array:
	"""Find buildings that consume this resource"""
	var consumers = []
	
	for building in GameData.buildings:
		# Check production inputs
		var production = building.get("production", {})
		var inputs = production.get("input", {})
		if resource_id in inputs:
			consumers.append(building.name)
		
		# Check upkeep
		var upkeep = building.get("upkeep", {})
		if resource_id in upkeep:
			consumers.append("%s (upkeep)" % building.name)
		
		# Check build cost
		var build_cost = building.get("build_cost", {})
		if resource_id in build_cost:
			if building.name not in consumers:
				consumers.append("%s (construction)" % building.name)
	
	return consumers

func _find_producers(resource_id: String) -> Array:
	"""Find buildings that produce this resource"""
	var producers = []
	
	# Check if extractable
	var res_data = GameData.get_resource_by_id(resource_id)
	if res_data.get("extractable", false):
		producers.append("Miner (on deposits)")
	
	# Check building outputs
	for building in GameData.buildings:
		var production = building.get("production", {})
		var outputs = production.get("output", {})
		if resource_id in outputs:
			producers.append(building.name)
	
	return producers
