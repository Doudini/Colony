extends Control
class_name ModernColonyUI
# Modern RTS-style UI inspired by Anno/SimCity

# References
var building_manager: BuildingManager

# UI Nodes
var top_bar: HBoxContainer
var left_panel: PanelContainer
var bottom_panel: PanelContainer
var right_panel: PanelContainer

# Resource display
var resource_bars: Dictionary = {}

# Building categories
var building_categories: Dictionary = {
	"extraction": [],
	"production": [],
	"storage": [],
	"infrastructure": [], 
	"life_support": [],
	#"energy": [], 
	"industrial": [], 
	"social": [], 
}

# State
var left_panel_collapsed: bool = false
var right_panel_collapsed: bool = false
var selected_category: String = "extraction"

func _ready():
	_build_ui()
	_populate_buildings()
	
	# Connect to GameState
	GameState.resources_changed.connect(_on_resource_changed)
	GameState.production_rate_changed.connect(_update_resource_bars)

func setup(manager: BuildingManager):
	building_manager = manager

func _build_ui():
	"""Build the complete UI structure"""
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Top bar (resources at a glance)
	_create_top_bar()
	
	# Left panel (detailed resources - collapsible)
	_create_left_panel()
	
	# Bottom panel (building menu)
	_create_bottom_panel()
	
	# Right panel (info/tutorial - collapsible)
	_create_right_panel()

func _create_top_bar():
	"""Create compact resource bar at top"""
	top_bar = HBoxContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.custom_minimum_size.y = 40
	add_child(top_bar)
	
	# Background
	var panel = PanelContainer.new()
	panel.anchor_right = 1.0
	panel.custom_minimum_size.y = 40
	top_bar.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	
	# Show key resources only
	var key_resources = ["minerals", "food", "oxygen", "hydrogen", "biomatter", "energy", "metal", "alloy"]
	for res_id in key_resources:
		var res_data = GameData.get_resource_by_id(res_id)
		if res_data.is_empty():
			continue
		
		var res_hbox = HBoxContainer.new()
		
		# Icon (colored square)
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.color = res_data.color
		res_hbox.add_child(icon)
		
		# Amount
		var amount_label = Label.new()
		amount_label.name = "TopAmount_" + res_id
		var current = GameState.resources.get(res_id, 0)
		amount_label.text = str(current)
		amount_label.custom_minimum_size.x = 40
		res_hbox.add_child(amount_label)
		
		# Rate
		var rate_label = Label.new()
		rate_label.name = "TopRate_" + res_id
		rate_label.text = "+0"
		rate_label.custom_minimum_size.x = 30
		res_hbox.add_child(rate_label)
		
		hbox.add_child(res_hbox)
		resource_bars[res_id] = {"amount": amount_label, "rate": rate_label}

func _create_left_panel():
	"""Create detailed resources panel (collapsible)"""
	left_panel = PanelContainer.new()
	left_panel.anchor_top = 0.08  # Below top bar
	left_panel.anchor_bottom = 1.0
	left_panel.custom_minimum_size.x = 280
	add_child(left_panel)
	
	var vbox = VBoxContainer.new()
	left_panel.add_child(vbox)
	
	# Header with collapse button
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = "RESOURCES"
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	
	header.add_child(Control.new())  # Spacer
	header.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var collapse_btn = Button.new()
	collapse_btn.text = "◀"
	collapse_btn.custom_minimum_size = Vector2(30, 30)
	collapse_btn.pressed.connect(_toggle_left_panel)
	header.add_child(collapse_btn)
	
	# Resource list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var resource_list = VBoxContainer.new()
	resource_list.name = "ResourceList"
	scroll.add_child(resource_list)
	
	_populate_resource_list(resource_list)

func _populate_resource_list(container: VBoxContainer):
	"""Populate detailed resource list"""
	for resource in GameData.resources:
		var res_panel = PanelContainer.new()
		res_panel.custom_minimum_size.y = 60
		container.add_child(res_panel)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		res_panel.add_child(margin)
		
		var vbox = VBoxContainer.new()
		margin.add_child(vbox)
		
		# Name (clickable)
		var name_btn = Button.new()
		name_btn.text = resource.name
		name_btn.flat = true
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.pressed.connect(_on_resource_clicked.bind(resource.id))
		vbox.add_child(name_btn)
		
		# Storage bar
		var progress = ProgressBar.new()
		progress.name = "Progress_" + resource.id
		progress.show_percentage = false
		progress.max_value = GameState.get_storage_limit(resource.id)
		progress.value = GameState.resources.get(resource.id, 0)
		vbox.add_child(progress)
		
		# Amount and rate
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)
		
		var amount_label = Label.new()
		amount_label.name = "DetailAmount_" + resource.id
		var current = GameState.resources.get(resource.id, 0)
		var limit = GameState.get_storage_limit(resource.id)
		amount_label.text = "%d/%d" % [current, limit]
		amount_label.add_theme_font_size_override("font_size", 11)
		hbox.add_child(amount_label)
		
		hbox.add_child(Control.new())  # Spacer
		hbox.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var rate_label = Label.new()
		rate_label.name = "DetailRate_" + resource.id
		rate_label.text = "+0"
		rate_label.add_theme_font_size_override("font_size", 11)
		hbox.add_child(rate_label)

func _create_bottom_panel():
	"""Create building menu (Anno-style category tabs)"""
	bottom_panel = PanelContainer.new()
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.offset_top = -180
	add_child(bottom_panel)
	
	var vbox = VBoxContainer.new()
	bottom_panel.add_child(vbox)
	
	# Category tabs
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	vbox.add_child(tabs)
	
	var categories = [
		{"id": "extraction", "icon": "⛏️", "name": "Extract"},
		{"id": "production", "icon": "🏭", "name": "Produce"},
		{"id": "storage", "icon": "📦", "name": "Store"},
		{"id": "infrastructure", "icon": "🏗️", "name": "Infrastructure"},
		#{"id": "energy", "icon": "🏗️", "name": "energy"},
		{"id": "life_support", "icon": "🏗️", "name": "Synthetics"},
		{"id": "industrial", "icon": "🏗️", "name": "industrial"},
		{"id": "social", "icon": "🏗️", "name": "Social"}
	]
	
	for cat in categories:
		var btn = Button.new()
		btn.text = "%s %s" % [cat.icon, cat.name]
		btn.custom_minimum_size = Vector2(100, 40)
		btn.toggle_mode = true
		btn.button_pressed = (cat.id == selected_category)
		btn.pressed.connect(_on_category_selected.bind(cat.id))
		tabs.add_child(btn)
	
	# Building grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 130
	vbox.add_child(scroll)
	
	var building_grid = GridContainer.new()
	building_grid.name = "BuildingGrid"
	building_grid.columns = 8
	building_grid.add_theme_constant_override("h_separation", 10)
	building_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(building_grid)

func _create_right_panel():
	"""Create info/tutorial panel (collapsible)"""
	right_panel = PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_top = 0.08
	right_panel.anchor_bottom = 0.7
	right_panel.offset_left = -300
	add_child(right_panel)
	
	var vbox = VBoxContainer.new()
	right_panel.add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var collapse_btn = Button.new()
	collapse_btn.text = "▶"
	collapse_btn.custom_minimum_size = Vector2(30, 30)
	collapse_btn.pressed.connect(_toggle_right_panel)
	header.add_child(collapse_btn)
	
	var title = Label.new()
	title.text = "TUTORIAL"
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	
	# Tutorial text
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var tutorial = Label.new()
	tutorial.text = "🎯 QUICK START:\n\n(1) Build Miners on glowing tiles\n(2) Build Power Plant (needs Hydrogen)\n(3) Extract Minerals & Energy\n(4) Build Smelter for Metal\n\n💡 TIP: Click resource names for details!"
	tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD
	scroll.add_child(tutorial)

func _populate_buildings():
	"""Organize buildings into categories"""
	for building in GameData.buildings:
		var category = building.get("category", "infrastructure")
		if category not in building_categories:
			building_categories[category] = []
		building_categories[category].append(building)
	
	_update_building_grid()

func _update_building_grid():
	"""Update building grid for selected category"""
	var grid = get_node_or_null("BuildingGrid")
	if not grid:
		grid = bottom_panel.find_child("BuildingGrid", true, false)
	if not grid:
		return
	
	# Clear grid
	for child in grid.get_children():
		child.queue_free()
	
	# Add buildings for selected category
	var buildings = building_categories.get(selected_category, [])
	for building in buildings:
		var btn_container = PanelContainer.new()
		btn_container.custom_minimum_size = Vector2(80, 80)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.pressed.connect(_on_building_selected.bind(building.id))
		btn_container.add_child(btn)
		
		# Building info
		var vbox = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)
		
		var name_label = Label.new()
		name_label.text = building.name
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(name_label)
		
		var cost_label = Label.new()
		var costs = []
		for res_id in building.build_cost:
			costs.append("%d %s" % [building.build_cost[res_id], res_id])
		cost_label.text = "\n".join(costs)
		cost_label.add_theme_font_size_override("font_size", 9)
		cost_label.add_theme_color_override("font_color", Color.GRAY)
		vbox.add_child(cost_label)
		
		grid.add_child(btn_container)

func _on_category_selected(category: String):
	"""Switch building category"""
	selected_category = category
	_update_building_grid()
	
	# Update tab visual state
	var tabs = bottom_panel.find_child("HBoxContainer", true, false)
	if tabs:
		for child in tabs.get_children():
			if child is Button:
				child.button_pressed = false
	
	print("Selected category: %s" % category)

func _on_building_selected(building_id: String):
	"""Start building placement"""
	if building_manager:
		building_manager.start_placement(building_id)
		print("Started placing: %s" % building_id)

func _on_resource_clicked(resource_id: String):
	"""Show resource details"""
	var details_panel = get_tree().root.get_node_or_null("PlanetSurface/ResourceDetailsLayer/ResourceDetailsPanel")
	if details_panel:
		details_panel.show_resource_details(resource_id)

func _toggle_left_panel():
	"""Toggle left panel visibility"""
	left_panel_collapsed = !left_panel_collapsed
	if left_panel_collapsed:
		left_panel.visible = false
	else:
		left_panel.visible = true

func _toggle_right_panel():
	"""Toggle right panel visibility"""
	right_panel_collapsed = !right_panel_collapsed
	if right_panel_collapsed:
		right_panel.visible = false
	else:
		right_panel.visible = true

func _on_resource_changed(resource_id: String, new_amount: int):
	"""Update all resource displays"""
	# Update top bar
	if resource_id in resource_bars:
		resource_bars[resource_id].amount.text = str(new_amount)
	
	# Update left panel
	var amount_label = left_panel.find_child("DetailAmount_" + resource_id, true, false)
	if amount_label:
		var limit = GameState.get_storage_limit(resource_id)
		amount_label.text = "%d/%d" % [new_amount, limit]
	
	var progress = left_panel.find_child("Progress_" + resource_id, true, false)
	if progress:
		progress.value = new_amount

func _update_resource_bars():
	"""Update rate displays"""
	for res_id in resource_bars:
		var net_rate = GameState.get_net_rate(res_id)
		var rate_label = resource_bars[res_id].rate
		
		if net_rate > 0:
			rate_label.text = "+%.0f" % net_rate
			rate_label.add_theme_color_override("font_color", Color.GREEN)
		elif net_rate < 0:
			rate_label.text = "%.0f" % net_rate
			rate_label.add_theme_color_override("font_color", Color.RED)
		else:
			rate_label.text = "+0"
			rate_label.add_theme_color_override("font_color", Color.GRAY)
	
	# Update left panel rates
	for resource in GameData.resources:
		var rate_label = left_panel.find_child("DetailRate_" + resource.id, true, false)
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
