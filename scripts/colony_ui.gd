extends CanvasLayer
# ColonyUI - Main UI for managing the colony

@onready var resource_container = $Panel/MarginContainer/VBoxContainer/Resources/ResourceList
@onready var building_container = $Panel/MarginContainer/VBoxContainer/Buildings/BuildingList
@onready var info_label = $Panel/MarginContainer/VBoxContainer/Info/InfoLabel

var building_manager: BuildingManager

func _ready():
	_setup_resources()
	_setup_buildings()
	
	# Connect to state changes
	GameState.resources_changed.connect(_on_resource_changed)
	GameState.space_travel_unlocked_signal.connect(_on_space_travel_unlocked)

func setup(manager: BuildingManager):
	"""Connect to the building manager"""
	building_manager = manager
	building_manager.building_placed.connect(_on_building_placed)
	building_manager.building_placement_failed.connect(_on_placement_failed)

func _setup_resources():
	"""Create resource display with storage and rates"""
	for child in resource_container.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "=== RESOURCES ==="
	title.add_theme_font_size_override("font_size", 14)
	resource_container.add_child(title)
	
	for resource in GameData.resources:
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size.y = 24
		
		# Make name clickable
		var name_button = Button.new()
		name_button.text = resource.name + ":"
		name_button.flat = true
		name_button.custom_minimum_size.x = 90
		name_button.pressed.connect(_on_resource_clicked.bind(resource.id))
		hbox.add_child(name_button)
		
		# Amount / Limit
		var amount_label = Label.new()
		amount_label.name = "Amount_" + resource.id
		var current = GameState.resources.get(resource.id, 0)
		var limit = GameState.get_storage_limit(resource.id)
		amount_label.text = "%d/%d" % [current, limit]
		amount_label.custom_minimum_size.x = 80
		hbox.add_child(amount_label)
		
		# Net rate
		var rate_label = Label.new()
		rate_label.name = "Rate_" + resource.id
		rate_label.text = "+0"
		rate_label.custom_minimum_size.x = 40
		hbox.add_child(rate_label)
		
		resource_container.add_child(hbox)
	
	# Connect to rate changes
	GameState.production_rate_changed.connect(_update_all_rates)

func _on_resource_clicked(resource_id: String):
	"""Handle resource name click"""
	# Show details panel
	var details_panel = get_tree().root.get_node_or_null("PlanetSurface/ResourceDetailsLayer/ResourceDetailsPanel")
	if details_panel:
		details_panel.show_resource_details(resource_id)

func _setup_buildings():
	"""Create building buttons"""
	for child in building_container.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "=== BUILDINGS ==="
	title.add_theme_font_size_override("font_size", 14)
	building_container.add_child(title)
	
	for building in GameData.buildings:
		var vbox = VBoxContainer.new()
		
		# Building name button
		var btn = Button.new()
		btn.text = building.name
		btn.pressed.connect(_on_building_selected.bind(building.id))
		vbox.add_child(btn)
		
		# Description
		var desc = Label.new()
		desc.text = building.description
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc)
		
		# Cost
		var cost_label = Label.new()
		var costs = []
		for resource_id in building.build_cost:
			var amount = building.build_cost[resource_id]
			var resource_data = GameData.get_resource_by_id(resource_id)
			costs.append("%s: %d" % [resource_data.name, amount])
		
		if costs.size() > 0:
			cost_label.text = "Cost: " + ", ".join(costs)
		else:
			cost_label.text = "Cost: Free"
		
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		vbox.add_child(cost_label)
		
		# Separator
		var sep = HSeparator.new()
		vbox.add_child(sep)
		
		building_container.add_child(vbox)

func _on_building_selected(building_id: String):
	"""Handle building selection"""
	if building_manager:
		building_manager.start_placement(building_id)
		var building = GameData.get_building_by_id(building_id)
		info_label.text = "Placing: %s (Left-click to place, Right-click to cancel)" % building.name

func _on_resource_changed(resource_id: String, new_amount: int):
	"""Update resource display"""
	var amount_label := resource_container.find_child(
		"Amount_" + resource_id,
		true,
		false
	)
	if amount_label:
		var limit = GameState.get_storage_limit(resource_id)
		amount_label.text = "%d/%d" % [new_amount, limit]
		
		# Color code if near limit
		if new_amount >= limit * 0.9:
			amount_label.add_theme_color_override("font_color", Color.ORANGE)
		elif new_amount >= limit:
			amount_label.add_theme_color_override("font_color", Color.RED)
		else:
			amount_label.add_theme_color_override("font_color", Color.WHITE)

func _update_all_rates():
	"""Update all rate displays"""
	for resource in GameData.resources:
		var rate_label := resource_container.find_child(
			"Rate_" + resource.id,
			true,
			false
		)
		if rate_label:
			var net_rate = GameState.get_net_rate(resource.id)
			
			if net_rate > 0:
				rate_label.text = "+%.0f" % net_rate
				rate_label.add_theme_color_override("font_color", Color.GREEN)
			elif net_rate < 0:
				rate_label.text = "%.0f" % net_rate
				rate_label.add_theme_color_override("font_color", Color.RED)
			else:
				rate_label.text = "+0"
				rate_label.add_theme_color_override("font_color", Color.GRAY)

func _on_building_placed(building_id: String, grid_pos: Vector2i):
	"""Handle successful building placement"""
	var building = GameData.get_building_by_id(building_id)
	info_label.text = "Built %s at %s" % [building.name, grid_pos]

func _on_placement_failed(reason: String):
	"""Handle failed building placement"""
	info_label.text = "❌ " + reason

func _on_space_travel_unlocked():
	"""Handle space travel unlock"""
	info_label.text = "🚀 SPACEPORT COMPLETE! You can now travel to space! (Press SPACE to launch)"
	
	# Add space travel button
	var space_btn = Button.new()
	space_btn.text = "🚀 LAUNCH TO SPACE"
	space_btn.pressed.connect(_launch_to_space)
	building_container.add_child(space_btn)

func _launch_to_space():
	"""Switch to space scene"""
	# TODO: Implement space scene transition
	info_label.text = "Space travel coming in next phase!"
