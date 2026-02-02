extends PanelContainer
class_name BuildingTooltip
# Displays detailed information about buildings on hover

@onready var title_label = $MarginContainer/VBox/Title
@onready var status_label = $MarginContainer/VBox/Status
@onready var consumes_label = $MarginContainer/VBox/Consumes
@onready var produces_label = $MarginContainer/VBox/Produces
@onready var upkeep_label = $MarginContainer/VBox/Upkeep

func _ready():
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse

func show_building_info(building_id: String, grid_pos: Vector2i):
	"""Display tooltip for a building"""
	var building_data = GameData.get_building_by_id(building_id)
	if building_data.is_empty():
		hide()
		return
	
	# Title
	title_label.text = building_data.name.to_upper()
	
	# Status (check if paused first)
	var building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	var is_paused = false
	if building_control:
		is_paused = building_control.is_paused(grid_pos)
	
	if is_paused:
		status_label.text = "Status: ⏸️ Paused"
		status_label.add_theme_color_override("font_color", Color.GRAY)
	else:
		var efficiency = GameState.global_efficiency
		if efficiency >= 1.0:
			status_label.text = "Status: ⚡ Active"
			status_label.add_theme_color_override("font_color", Color.GREEN)
		elif efficiency >= 0.75:
			status_label.text = "Status: ⚠ Reduced Efficiency (%.0f%%)" % (efficiency * 100)
			status_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			status_label.text = "Status: ❌ Low Efficiency (%.0f%%)" % (efficiency * 100)
			status_label.add_theme_color_override("font_color", Color.RED)
	
	# Production info
	var production = building_data.get("production", {})
	if not production.is_empty():
		var inputs = production.get("input", {})
		var outputs = production.get("output", {})
		var time = production.get("time", 10.0)
		
		# Consumes
		if inputs.size() > 0:
			var consume_text = "Consumes:\n"
			for res_id in inputs:
				var amount = inputs[res_id]
				var res_data = GameData.get_resource_by_id(res_id)
				var rate = (amount / time) * 60.0  # Per minute
				consume_text += "  - %s: %.1f/min\n" % [res_data.name, rate]
			consumes_label.text = consume_text.strip_edges()
			consumes_label.show()
		else:
			consumes_label.hide()
		
		# Produces
		if outputs.size() > 0:
			var produce_text = "Produces:\n"
			for res_id in outputs:
				var amount = outputs[res_id]
				var res_data = GameData.get_resource_by_id(res_id)
				var rate = (amount / time) * 60.0  # Per minute
				produce_text += "  + %s: %.1f/min\n" % [res_data.name, rate]
			produces_label.text = produce_text.strip_edges()
			produces_label.add_theme_color_override("font_color", Color.GREEN)
			produces_label.show()
		else:
			produces_label.hide()
	else:
		consumes_label.hide()
		produces_label.hide()
	
	# Extraction info
	var extraction_rate = building_data.get("extraction_rate", 0.0)
	if extraction_rate > 0:
		# This is an extractor - show what it's extracting
		var tile_grid = get_tree().root.get_node("PlanetSurface/TileGrid")
		if tile_grid:
			var tile_info = tile_grid.get_tile_info(grid_pos)
			var resource = tile_info.get("resource", null)
			if resource != null and resource != "":
				var res_data = GameData.get_resource_by_id(resource)
				if not res_data.is_empty():
					produces_label.text = "Extracts:\n  + %s: %.1f/min" % [res_data.name, extraction_rate]
					produces_label.add_theme_color_override("font_color", Color.GREEN)
					produces_label.show()
				else:
					produces_label.text = "⚠ Invalid resource!"
					produces_label.add_theme_color_override("font_color", Color.RED)
					produces_label.show()
			else:
				produces_label.text = "⚠ No resource deposit!"
				produces_label.add_theme_color_override("font_color", Color.RED)
				produces_label.show()
		
		consumes_label.hide()
	
	# Upkeep
	var upkeep = building_data.get("upkeep", {})
	if upkeep.size() > 0:
		var upkeep_text = "Upkeep:\n"
		for res_id in upkeep:
			var amount = upkeep[res_id]
			var res_data = GameData.get_resource_by_id(res_id)
			upkeep_text += "  - %s: %.1f/min\n" % [res_data.name, amount]
		upkeep_label.text = upkeep_text.strip_edges()
		upkeep_label.show()
	else:
		upkeep_label.hide()
	
	show()

func show_tile_info(grid_pos: Vector2i):
	"""Display tooltip for a tile"""
	var tile_grid = get_tree().root.get_node("PlanetSurface/TileGrid")
	if not tile_grid:
		hide()
		return
	
	var tile_info = tile_grid.get_tile_info(grid_pos)
	
	# Title
	title_label.text = "TILE [%d, %d]" % [grid_pos.x, grid_pos.y]
	
	# Terrain type
	var terrain = tile_info.get("type", "unknown")
	status_label.text = "Terrain: %s" % terrain.capitalize()
	status_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Resource
	var resource = tile_info.get("resource", null)
	if resource:
		var res_data = GameData.get_resource_by_id(resource)
		if not res_data.is_empty():
			produces_label.text = "Resource: %s" % res_data.name
			produces_label.add_theme_color_override("font_color", res_data.color)
			produces_label.show()
		else:
			produces_label.hide()
	else:
		produces_label.hide()
	
	# Occupied
	var occupied = tile_info.get("occupied", false)
	var building = tile_info.get("building", null)
	if occupied and building:
		upkeep_label.text = "Building: %s" % building
		upkeep_label.show()
	elif occupied:
		upkeep_label.text = "Occupied"
		upkeep_label.show()
	else:
		upkeep_label.hide()
	
	consumes_label.hide()
	
	show()

func update_position(mouse_pos: Vector2):
	"""Position tooltip near mouse"""
	var offset = Vector2(20, 20)
	var new_pos = mouse_pos + offset
	
	# Keep on screen
	var screen_size = get_viewport().get_visible_rect().size
	if new_pos.x + size.x > screen_size.x:
		new_pos.x = mouse_pos.x - size.x - 10
	if new_pos.y + size.y > screen_size.y:
		new_pos.y = mouse_pos.y - size.y - 10
	
	position = new_pos
