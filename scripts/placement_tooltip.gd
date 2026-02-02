extends PanelContainer
class_name PlacementTooltip
# Shows detailed building info during placement

var current_building_id: String = ""

func _ready():
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_for_building(building_id: String, can_place: bool, can_afford: bool):
	"""Show tooltip for building being placed"""
	current_building_id = building_id
	
	# Clear existing content
	for child in get_children():
		child.queue_free()
	
	var building_data = GameData.get_building_by_id(building_id)
	if building_data.is_empty():
		hide()
		return
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = building_data.name.to_upper()
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", building_data.color)
	vbox.add_child(title)
	
	# Description
	var desc = Label.new()
	desc.text = building_data.description
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color.GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size.x = 250
	vbox.add_child(desc)
	
	vbox.add_child(HSeparator.new())
	
	# Size
	var size_label = Label.new()
	size_label.text = "Size: %dx%d" % [building_data.size.x, building_data.size.y]
	size_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(size_label)
	
	# Build cost
	if building_data.build_cost.size() > 0:
		var cost_label = Label.new()
		cost_label.text = "Build Cost:"
		cost_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(cost_label)
		
		for resource_id in building_data.build_cost:
			var amount = building_data.build_cost[resource_id]
			var available = GameState.resources.get(resource_id, 0)
			var has_enough = available >= amount
			
			var item = Label.new()
			item.text = "  • %d %s" % [amount, resource_id.capitalize()]
			item.add_theme_font_size_override("font_size", 9)
			if has_enough:
				item.add_theme_color_override("font_color", Color.GREEN)
			else:
				item.add_theme_color_override("font_color", Color.RED)
			vbox.add_child(item)
	
	# Upkeep
	if building_data.upkeep.size() > 0:
		vbox.add_child(HSeparator.new())
		
		var upkeep_label = Label.new()
		upkeep_label.text = "Upkeep:"
		upkeep_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(upkeep_label)
		
		for resource_id in building_data.upkeep:
			var amount = building_data.upkeep[resource_id]
			var item = Label.new()
			item.text = "  • %s: %.1f/min" % [resource_id.capitalize(), amount]
			item.add_theme_font_size_override("font_size", 9)
			item.add_theme_color_override("font_color", Color.ORANGE)
			vbox.add_child(item)
	
	# Production
	var production = building_data.get("production", {})
	if not production.is_empty():
		vbox.add_child(HSeparator.new())
		
		var prod_label = Label.new()
		prod_label.text = "Production:"
		prod_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(prod_label)
		
		var inputs = production.get("input", {})
		if inputs.size() > 0:
			var input_label = Label.new()
			input_label.text = "  Consumes:"
			input_label.add_theme_font_size_override("font_size", 9)
			input_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
			vbox.add_child(input_label)
			
			for res_id in inputs:
				var amount = inputs[res_id]
				var item = Label.new()
				item.text = "    - %s: %.1f/cycle" % [res_id.capitalize(), amount]
				item.add_theme_font_size_override("font_size", 9)
				vbox.add_child(item)
		
		var outputs = production.get("output", {})
		if outputs.size() > 0:
			var output_label = Label.new()
			output_label.text = "  Produces:"
			output_label.add_theme_font_size_override("font_size", 9)
			output_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
			vbox.add_child(output_label)
			
			for res_id in outputs:
				var amount = outputs[res_id]
				var item = Label.new()
				item.text = "    + %s: %.1f/cycle" % [res_id.capitalize(), amount]
				item.add_theme_font_size_override("font_size", 9)
				vbox.add_child(item)
	
	# Extraction
	var extraction_rate = building_data.get("extraction_rate", 0.0)
	if extraction_rate > 0:
		vbox.add_child(HSeparator.new())
		
		var extract_label = Label.new()
		extract_label.text = "Extracts: %.1f/min" % extraction_rate
		extract_label.add_theme_font_size_override("font_size", 10)
		extract_label.add_theme_color_override("font_color", Color.CYAN)
		vbox.add_child(extract_label)
	
	vbox.add_child(HSeparator.new())
	
	# Placement requirement
	var requirement = building_data.get("placement_requirement", "")
	if requirement != "":
		var req_label = Label.new()
		if requirement == "adjacent_shallow_water":
			req_label.text = "⚠️ Must be adjacent to shallow water"
		else:
			req_label.text = "⚠️ Special placement required: %s" % requirement
		req_label.add_theme_font_size_override("font_size", 10)
		req_label.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(req_label)
		vbox.add_child(HSeparator.new())
	
	# Status
	var status = Label.new()
	if not can_place:
		status.text = "❌ Cannot place here!"
		status.add_theme_color_override("font_color", Color.RED)
	elif not can_afford:
		status.text = "⚠️ Not enough resources!"
		status.add_theme_color_override("font_color", Color.ORANGE)
	else:
		status.text = "✅ Ready to place"
		status.add_theme_color_override("font_color", Color.GREEN)
	status.add_theme_font_size_override("font_size", 10)
	vbox.add_child(status)
	
	# Controls
	var controls = Label.new()
	controls.text = "[LMB] Place  [RMB] Cancel"
	controls.add_theme_font_size_override("font_size", 9)
	controls.add_theme_color_override("font_color", Color.GRAY)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls)
	
	show()

func update_position(mouse_pos: Vector2):
	"""Update tooltip position near mouse"""
	var viewport_size = get_viewport_rect().size
	
	# Offset from mouse
	var offset = Vector2(20, 20)
	var new_pos = mouse_pos + offset
	
	# Keep on screen
	new_pos.x = clamp(new_pos.x, 0, viewport_size.x - size.x)
	new_pos.y = clamp(new_pos.y, 0, viewport_size.y - size.y)
	
	position = new_pos
