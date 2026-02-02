extends Control
class_name CleanModernUI
# Clean modern UI with window system

var building_manager: BuildingManager

# UI state
var windows: Dictionary = {}  # Draggable windows
var selected_category: String = "extraction"

# UI Components
var context_menu: BuildingContextMenu
var placement_tooltip: PlacementTooltip
var miner_warning: MisplacedMinerWarning
var building_control: BuildingControl
var research_ui_nodes: Dictionary = {}  # {research_id: {button, status, progress}}

func _ready():
	_build_ui()
	_create_ui_components()
	GameState.resources_changed.connect(_update_resource_display)
	GameState.production_rate_changed.connect(_update_resource_display)
	GameState.research_queue_changed.connect(_refresh_research_ui)
	GameState.research_progress_changed.connect(_on_research_progress_changed)
	_update_tech_button_state()

func _create_ui_components():
	"""Create all UI overlay components"""
	# Get reference to BuildingControl
	building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	print("🔍 Looking for BuildingControl...")
	print("   Found: %s" % building_control)
	
	if not building_control:
		print("❌ WARNING: BuildingControl not found!")
	else:
		print("✅ BuildingControl found successfully")
	
	# Context Menu (for right-click on buildings)
	context_menu = BuildingContextMenu.new()
	context_menu.name = "ContextMenu"
	context_menu.z_index = 100
	add_child(context_menu)
	
	# Connect context menu signals
	context_menu.pause_requested.connect(_on_pause_requested)
	context_menu.resume_requested.connect(_on_resume_requested)
	context_menu.demolish_requested.connect(_on_demolish_requested)
	context_menu.info_requested.connect(_on_info_requested)
	
	# Placement Tooltip (shows info while placing)
	placement_tooltip = PlacementTooltip.new()
	placement_tooltip.name = "PlacementTooltip"
	placement_tooltip.z_index = 90
	add_child(placement_tooltip)
	
	# Misplaced Miner Warning
	miner_warning = MisplacedMinerWarning.new()
	miner_warning.name = "MinerWarning"
	miner_warning.z_index = 110
	add_child(miner_warning)
	
	# Connect warning signals
	miner_warning.demolish_requested.connect(_on_demolish_requested)
	
	print("✅ UI components created and connected")

func _process(_delta):
	"""Check if mouse is over UI and update camera flag"""
	var camera = get_viewport().get_camera_3d()
	if not camera or not (camera is IsometricCamera):
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var over_ui = false
	
	# Check if mouse is over top bar
	var top_bar = find_child("TopBar", true, false)
	if top_bar and top_bar.visible:
		var rect = Rect2(top_bar.global_position, top_bar.size)
		if rect.has_point(mouse_pos):
			over_ui = true
	
	# Check if mouse is over bottom panel
	var bottom_panel = find_child("BottomPanel", true, false)
	if bottom_panel and bottom_panel.visible:
		var rect = Rect2(bottom_panel.global_position, bottom_panel.size)
		if rect.has_point(mouse_pos):
			over_ui = true
	
	# Check if mouse is over any open windows
	for window in windows.values():
		if is_instance_valid(window) and window.visible:
			var rect = Rect2(window.global_position, window.size)
			if rect.has_point(mouse_pos):
				over_ui = true
				break
	
	camera.is_mouse_over_ui = over_ui

func setup(manager: BuildingManager):
	building_manager = manager
	
	# Connect building manager signals
	if building_manager:
		building_manager.building_placed.connect(_on_building_placed)

#func _create_ui_components():
	#"""Create all UI components"""
	## Context Menu (for right-click on buildings)
	#context_menu = BuildingContextMenu.new()
	#context_menu.name = "ContextMenu"
	#context_menu.z_index = 100
	#add_child(context_menu)
	#
	## Connect context menu signals
	#context_menu.pause_requested.connect(_on_pause_requested)
	#context_menu.resume_requested.connect(_on_resume_requested)
	#context_menu.demolish_requested.connect(_on_demolish_requested)
	#context_menu.info_requested.connect(_on_info_requested)
	#
	## Placement Tooltip (shows info while placing)
	#placement_tooltip = PlacementTooltip.new()
	#placement_tooltip.name = "PlacementTooltip"
	#placement_tooltip.z_index = 90
	#add_child(placement_tooltip)
	#
	## Misplaced Miner Warning
	#miner_warning = MisplacedMinerWarning.new()
	#miner_warning.name = "MinerWarning"
	#miner_warning.z_index = 110
	#add_child(miner_warning)
	#
	## Connect warning signals
	#miner_warning.demolish_requested.connect(_on_demolish_requested)

func _build_ui():
	"""Build clean UI structure"""
	# Clear existing
	for child in get_children():
		child.queue_free()
	
	# Top bar - Key resources only
	_create_top_bar()
	
	# Bottom panel - Building menu + action buttons
	_create_bottom_panel()

func _create_top_bar():
	"""Compact top bar with essential resources"""
	var bar = PanelContainer.new()
	bar.name = "TopBar"
	bar.anchor_right = 1.0
	bar.custom_minimum_size.y = 50
	add_child(bar)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	margin.add_child(hbox)
	
	# Essential resources only
	var essential = ["food", "water", "wood", "minerals", "hydrogen", "biomatter", "energy"]
	for res_id in essential:
		var res_data = GameData.get_resource_by_id(res_id)
		if res_data.is_empty():
			continue
		
		_create_resource_display(hbox, res_id, res_data)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Action buttons
	var resources_btn = Button.new()
	resources_btn.text = "📊 Resources"
	resources_btn.custom_minimum_size = Vector2(120, 30)
	resources_btn.pressed.connect(_toggle_window.bind("resources"))
	hbox.add_child(resources_btn)
	
	var tech_btn = Button.new()
	tech_btn.text = "🔬 Tech Tree"
	tech_btn.custom_minimum_size = Vector2(120, 30)
	tech_btn.pressed.connect(_toggle_window.bind("tech"))
	tech_btn.disabled = true  # Updated later based on research buildings
	tech_btn.name = "TechButton"
	hbox.add_child(tech_btn)

func _create_resource_display(parent: Control, res_id: String, res_data: Dictionary):
	"""Create single resource display"""
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size.x = 100
	parent.add_child(vbox)
	
	# Name
	var name_label = Label.new()
	name_label.text = res_data.name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(name_label)
	
	# Amount bar
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.color = res_data.color
	hbox.add_child(icon)
	
	var amount = Label.new()
	amount.name = "Amount_" + res_id
	amount.text = str(GameState.resources.get(res_id, 0))
	amount.add_theme_font_size_override("font_size", 18)
	hbox.add_child(amount)
	
	# Rate
	var rate = Label.new()
	rate.name = "Rate_" + res_id
	rate.text = "+0"
	rate.add_theme_font_size_override("font_size", 14)
	vbox.add_child(rate)

func _create_bottom_panel():
	"""Building menu with categories"""
	var panel = PanelContainer.new()
	panel.name = "BottomPanel"
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.offset_top = -150
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Category tabs
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	vbox.add_child(tabs)
	
	var categories = [
		{"id": "extraction", "name": "⛏️ Extract"},
		{"id": "production", "name": "🏭 Produce"},
		{"id": "storage", "name": "📦 Store"},
		{"id": "infrastructure", "name": "🏗️ Build"},
		{"id": "research", "name": "🔬 Research"},
		{"id": "social", "name": "🎭 Social"}
	]
	
	for cat in categories:
		var btn = Button.new()
		btn.text = cat.name
		btn.custom_minimum_size = Vector2(120, 35)
		btn.toggle_mode = true
		btn.button_pressed = (cat.id == selected_category)
		btn.pressed.connect(_on_category_selected.bind(cat.id, btn, tabs))
		tabs.add_child(btn)
	
	# Building grid
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 105
	vbox.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.name = "BuildingGrid"
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	
	_populate_building_grid()

func _populate_building_grid():
	"""Fill grid with buildings for selected category"""
	var grid = find_child("BuildingGrid", true, false)
	if not grid:
		return
	
	# Clear
	for child in grid.get_children():
		child.queue_free()
	
	# Add buildings
	for building in GameData.buildings:
		if building.get("category", "") != selected_category:
			continue
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(90, 90)
		btn.pressed.connect(_on_building_clicked.bind(building.id))
		grid.add_child(btn)
		
		# Building info overlay
		var vbox = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)
		
		var name_label = Label.new()
		name_label.text = building.name
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(name_label)
		
		# Cost
		var costs = []
		for res_id in building.build_cost:
			var amount = building.build_cost[res_id]
			costs.append("%d %s" % [amount, res_id])
		
		if costs.size() > 0:
			var cost_label = Label.new()
			cost_label.text = "\n".join(costs)
			cost_label.add_theme_font_size_override("font_size", 9)
			cost_label.add_theme_color_override("font_color", Color.GRAY)
			cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(cost_label)

func _on_category_selected(category: String, clicked_btn: Button, tabs_container: Control):
	"""Switch category"""
	selected_category = category
	
	# Update button states
	for btn in tabs_container.get_children():
		if btn is Button:
			btn.button_pressed = (btn == clicked_btn)
	
	_populate_building_grid()

func _on_building_clicked(building_id: String):
	"""Start building placement"""
	if building_manager:
		building_manager.start_placement(building_id)

func _toggle_window(window_name: String):
	"""Toggle draggable window"""
	if window_name in windows and is_instance_valid(windows[window_name]):
		if window_name == "tech":
			research_ui_nodes.clear()
		windows[window_name].queue_free()
		windows.erase(window_name)
	else:
		match window_name:
			"resources":
				_create_resources_window()
			"tech":
				_create_tech_window()

func _create_resources_window():
	"""Create detailed resources window"""
	var window_data = _create_draggable_window("Resources", Vector2(350, 500), Vector2(100, 100), "resources")
	windows["resources"] = window_data["window"]
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP  # Block mouse events
	window_data["content"].add_child(scroll)
	
	# Consume scroll events to prevent camera zoom
	scroll.gui_input.connect(func(event):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll.accept_event()  # Consume the event
	)
	
	var list = VBoxContainer.new()
	scroll.add_child(list)
	
	for resource in GameData.resources:
		var panel = PanelContainer.new()
		panel.custom_minimum_size.y = 70
		list.add_child(panel)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)
		
		var vbox = VBoxContainer.new()
		margin.add_child(vbox)
		
		# Header
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)
		
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.color = resource.color
		hbox.add_child(icon)
		
		var name_label = Label.new()
		name_label.text = resource.name
		name_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(name_label)
		
		# Progress bar
		var progress = ProgressBar.new()
		progress.name = "WindowProgress_" + resource.id
		progress.max_value = GameState.get_storage_limit(resource.id)
		progress.value = GameState.resources.get(resource.id, 0)
		progress.show_percentage = false
		vbox.add_child(progress)
		
		# Stats
		var stats = HBoxContainer.new()
		vbox.add_child(stats)
		
		var amount_label = Label.new()
		amount_label.name = "WindowAmount_" + resource.id
		var current = GameState.resources.get(resource.id, 0)
		var limit = GameState.get_storage_limit(resource.id)
		amount_label.text = "%d/%d" % [current, limit]
		amount_label.add_theme_font_size_override("font_size", 11)
		stats.add_child(amount_label)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(spacer)
		
		var rate_label = Label.new()
		rate_label.name = "WindowRate_" + resource.id
		rate_label.text = "+0"
		rate_label.add_theme_font_size_override("font_size", 11)
		stats.add_child(rate_label)

func _create_tech_window():
	"""Create tech tree window"""
	var window_data = _create_draggable_window("Technology", Vector2(900, 520), Vector2(200, 120), "tech")
	windows["tech"] = window_data["window"]
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	window_data["content"].add_child(scroll)
	
	scroll.gui_input.connect(func(event):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll.accept_event()
	)
	
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	scroll.add_child(columns)
	
	research_ui_nodes.clear()
	
	var tiers: Dictionary = {}
	for item in GameData.research:
		var tier = item.get("tier", 0)
		if tier not in tiers:
			tiers[tier] = []
		tiers[tier].append(item)
	
	var tier_keys = tiers.keys()
	tier_keys.sort()
	
	for tier in tier_keys:
		var tier_vbox = VBoxContainer.new()
		tier_vbox.custom_minimum_size = Vector2(260, 0)
		columns.add_child(tier_vbox)
		
		var tier_label = Label.new()
		tier_label.text = "Tier %d" % tier
		tier_label.add_theme_font_size_override("font_size", 14)
		tier_vbox.add_child(tier_label)
		
		var tier_items: Array = tiers[tier]
		for item in tier_items:
			var panel = PanelContainer.new()
			panel.custom_minimum_size.y = 70
			tier_vbox.add_child(panel)
			
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 10)
			margin.add_theme_constant_override("margin_top", 10)
			margin.add_theme_constant_override("margin_right", 10)
			margin.add_theme_constant_override("margin_bottom", 10)
			panel.add_child(margin)
			
			var vbox = VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 4)
			margin.add_child(vbox)
			
			var action_btn = Button.new()
			action_btn.name = "ResearchBtn_" + item.id
			action_btn.text = item.name
			action_btn.autowrap_mode = TextServer.AUTOWRAP_WORD
			action_btn.custom_minimum_size = Vector2(220, 40)
			action_btn.pressed.connect(_on_research_button_pressed.bind(item.id))
			vbox.add_child(action_btn)
			
			research_ui_nodes[item.id] = {
				"button": action_btn
			}
	
	_refresh_research_ui()

func _format_research_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts = []
	for res_id in cost:
		parts.append("%d %s" % [cost[res_id], res_id])
	return ", ".join(parts)

func _on_research_button_pressed(research_id: String):
	if GameState.queue_research(research_id):
		_refresh_research_ui()

func _on_research_progress_changed(_active_id: String, _time_left: float):
	_refresh_research_ui()

func _refresh_research_ui():
	if research_ui_nodes.is_empty():
		return
	for item in GameData.research:
		if item.id not in research_ui_nodes:
			continue
		var nodes: Dictionary = research_ui_nodes[item.id]
		var button: Button = nodes.get("button", null)
		if not is_instance_valid(button):
			continue
		
		var status = _get_research_status(item)
		button.disabled = status.disabled
		button.text = status.button_text
		button.tooltip_text = _build_research_tooltip(item, status)
		button.disabled = status.disabled

func _get_research_status(item: Dictionary) -> Dictionary:
	var research_id = item.id
	var tier_unlocked = GameState.get_research_tier_unlocked()
	var status_text = ""
	var progress_text = ""
	var level = GameState.get_research_level(research_id)
	var max_level = int(item.get("max_level", 1))
	var button_text = "%s (%d/%d)" % [item.name, level, max_level]
	var disabled = false
	
	if tier_unlocked == 0:
		status_text = "🔒 Build research labs to unlock"
		button_text = "%s (Locked)" % item.name
		disabled = true
	elif level >= max_level:
		status_text = "✅ Completed"
		button_text = "%s (Complete)" % item.name
		disabled = true
	elif GameState.active_research_id == research_id:
		status_text = "🔬 Researching"
		progress_text = "Time left: %.0fs" % GameState.active_research_time_left
		button_text = "%s (Active)" % item.name
		disabled = true
	elif research_id in GameState.research_queue:
		var position = GameState.research_queue.find(research_id) + 1
		status_text = "⏳ Queued (#%d)" % position
		button_text = "%s (Queued)" % item.name
		disabled = true
	else:
		var tier = item.get("tier", 0)
		if tier > tier_unlocked:
			status_text = "🔒 Locked (Tier %d required)" % tier
			button_text = "%s (Locked)" % item.name
			disabled = true
		else:
			var prereqs = item.get("prerequisites", [])
			var missing = []
			for prereq in prereqs:
				if prereq is Dictionary:
					var prereq_id = prereq.get("id", "")
					var prereq_level = int(prereq.get("level", 1))
					if GameState.get_research_level(prereq_id) < prereq_level:
						missing.append("%s L%d" % [prereq_id, prereq_level])
				else:
					if GameState.get_research_level(prereq) < 1:
						missing.append(prereq)
			if missing.size() > 0:
				status_text = "🔒 Locked (Missing prereqs)"
				button_text = "%s (Locked)" % item.name
				disabled = true
			else:
				status_text = "Available"
				button_text = "%s (%d/%d)" % [item.name, level, max_level]
	
	return {
		"text": status_text,
		"progress": progress_text,
		"button_text": button_text,
		"disabled": disabled
	}

func _build_research_tooltip(item: Dictionary, status: Dictionary) -> String:
	var research_id = item.id
	var level = GameState.get_research_level(research_id)
	var max_level = int(item.get("max_level", 1))
	var next_level = min(level + 1, max_level)
	var cost = GameState.get_research_cost(item, next_level)
	var time = GameState.get_research_time(item, next_level)
	var cost_text = _format_research_cost(cost)
	var lines = []
	lines.append(item.name)
	lines.append("Level: %d/%d" % [level, max_level])
	lines.append(item.description)
	lines.append(status.text)
	if level < max_level:
		if cost_text != "":
			lines.append("Cost: %s" % cost_text)
		if time > 0.0:
			lines.append("Time: %.0fs" % time)
	return "\n".join(lines)

func _update_tech_button_state():
	var tech_btn = find_child("TechButton", true, false)
	if tech_btn:
		tech_btn.disabled = GameState.get_research_tier_unlocked() <= 0

func _create_draggable_window(title: String, size: Vector2, pos: Vector2, window_key: String = "") -> Dictionary:
	"""Create draggable window - returns dict with window and content"""
	var window = PanelContainer.new()
	window.custom_minimum_size = size
	window.position = pos
	window.mouse_filter = Control.MOUSE_FILTER_STOP  # Block mouse to 3D scene
	add_child(window)
	
	var vbox = VBoxContainer.new()
	window.add_child(vbox)
	
	# Title bar (draggable)
	var title_bar = PanelContainer.new()
	title_bar.custom_minimum_size.y = 30
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(title_bar)
	
	var title_hbox = HBoxContainer.new()
	title_bar.add_child(title_hbox)
	
	var title_label = Label.new()
	title_label.text = " " + title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_label)
	
	var close_btn = Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(func():
		var key = window_key
		if key == "":
			key = title.to_lower().replace(" ", "_")
		if key == "tech":
			research_ui_nodes.clear()
		windows.erase(key)
		window.queue_free()
	)
	title_hbox.add_child(close_btn)
	
	# Content area
	var content = MarginContainer.new()
	content.add_theme_constant_override("margin_left", 10)
	content.add_theme_constant_override("margin_right", 10)
	content.add_theme_constant_override("margin_bottom", 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_STOP  # Block scrolling through
	vbox.add_child(content)
	
	var content_container = VBoxContainer.new()
	content.add_child(content_container)
	
	# Make draggable
	var dragging = {"active": false, "offset": Vector2.ZERO}
	
	title_bar.gui_input.connect(func(event):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					dragging.active = true
					dragging.offset = event.position
					# Bring window to front
					window.move_to_front()
				else:
					dragging.active = false
		elif event is InputEventMouseMotion and dragging.active:
			window.position += event.relative
	)
	
	return {"window": window, "content": content_container}

func _update_resource_display(res_id: String = "", amount: int = 0):
	"""Update all resource displays"""
	# Update top bar
	for res_id2 in ["minerals", "hydrogen", "biomatter", "energy"]:
		var amount_label = find_child("Amount_" + res_id2, true, false)
		if amount_label:
			amount_label.text = str(GameState.resources.get(res_id2, 0))
		
		var rate_label = find_child("Rate_" + res_id2, true, false)
		if rate_label:
			var net = GameState.get_net_rate(res_id2)
			var net_per_sec = net / 60.0  # Convert from per-minute to per-second
			if net_per_sec > 0.01:
				rate_label.text = "+%.2f/s" % net_per_sec
				rate_label.add_theme_color_override("font_color", Color.GREEN)
			elif net_per_sec < -0.01:
				rate_label.text = "%.2f/s" % net_per_sec
				rate_label.add_theme_color_override("font_color", Color.RED)
			else:
				rate_label.text = "0.00/s"
				rate_label.add_theme_color_override("font_color", Color.GRAY)
	
	# Update resources window if open
	if "resources" in windows and is_instance_valid(windows["resources"]):
		for resource in GameData.resources:
			var amount_label = windows["resources"].find_child("WindowAmount_" + resource.id, true, false)
			if amount_label:
				var current = GameState.resources.get(resource.id, 0)
				var limit = GameState.get_storage_limit(resource.id)
				amount_label.text = "%d/%d" % [current, limit]
			
			var rate_label = windows["resources"].find_child("WindowRate_" + resource.id, true, false)
			if rate_label:
				var net = GameState.get_net_rate(resource.id)
				var net_per_sec = net / 60.0  # Convert from per-minute to per-second
				if net_per_sec > 0.01:
					rate_label.text = "+%.2f/s" % net_per_sec
					rate_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Bright green
				elif net_per_sec < -0.01:
					rate_label.text = "%.2f/s" % net_per_sec
					rate_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Bright red
				else:
					rate_label.text = "0.00/s"
					rate_label.add_theme_color_override("font_color", Color.GRAY)
			
			var progress = windows["resources"].find_child("WindowProgress_" + resource.id, true, false)
			if progress:
				progress.value = GameState.resources.get(resource.id, 0)

# ============================================
# UI Component Interface Functions
# ============================================

func show_building_context_menu(grid_pos: Vector2i, building_id: String, world_pos: Vector3, is_paused: bool):
	"""Show context menu for a building"""
	if context_menu:
		context_menu.show_for_building(grid_pos, building_id, world_pos, is_paused)

func show_placement_tooltip(building_id: String, can_place: bool, can_afford: bool):
	"""Show tooltip during building placement"""
	if placement_tooltip:
		placement_tooltip.show_for_building(building_id, can_place, can_afford)
		
func hide_placement_tooltip():
	"""Hide placement tooltip"""
	if placement_tooltip:
		placement_tooltip.hide()

func update_placement_tooltip_position(mouse_pos: Vector2):
	"""Update tooltip position"""
	if placement_tooltip and placement_tooltip.visible:
		placement_tooltip.update_position(mouse_pos)

func show_misplaced_miner_warning(grid_pos: Vector2i):
	"""Show warning for misplaced miner"""
	if miner_warning:
		miner_warning.show_warning(grid_pos)

# ============================================
# Signal Handlers for UI Components
# ============================================

func _on_pause_requested(grid_pos: Vector2i):
	"""Handle pause request from context menu"""
	print("📥 UI received pause_requested for %s" % grid_pos)
	print("   building_control = %s" % building_control)
	print("   building_manager = %s" % building_manager)
	
	if building_control:
		print("   Calling BuildingControl.pause_building()...")
		building_control.pause_building(grid_pos)
		print("✅ BuildingControl.pause_building() called")
	else:
		print("❌ building_control is NULL!")
	
	# Use building_manager to handle pause (it updates resource tracker)
	if building_manager:
		building_manager.pause_building(grid_pos)
		print("✅ BuildingManager.pause_building() called")
	else:
		print("❌ building_manager is NULL!")

func _on_resume_requested(grid_pos: Vector2i):
	"""Handle resume request from context menu"""
	print("📥 UI received resume_requested for %s" % grid_pos)
	
	if building_control:
		building_control.resume_building(grid_pos)
		print("✅ BuildingControl.resume_building() called")
	
	# Use building_manager to handle resume (it updates resource tracker)
	if building_manager:
		building_manager.resume_building(grid_pos)
		print("✅ BuildingManager.resume_building() called")

func _on_demolish_requested(grid_pos: Vector2i):
	"""Handle demolish request"""
	var tile_grid = get_tree().root.get_node_or_null("PlanetSurface/TileGrid")
	
	if not tile_grid:
		return
	
	# Get building info
	var tile_info = tile_grid.get_tile_info(grid_pos)
	var building_id = tile_info.get("building", "")
	
	if building_id == "":
		return
	
	# Get refund
	var refund = {}
	if building_control:
		refund = building_control.demolish_building(grid_pos, building_id)
		print("💰 Refund calculated: %s" % refund)
	else:
		print("❌ No building_control found!")
	
	# Add refunded resources
	if refund.is_empty():
		print("⚠️ Refund is empty!")
	else:
		for resource_id in refund:
			var amount = refund[resource_id]
			GameState.add_resource(resource_id, amount)
			print("💰 Refunded: %d %s" % [amount, resource_id])
	
	# Remove building visually
	if building_manager:
		building_manager.demolish_building(grid_pos)
		if building_id in ["building_research", "ship_research", "tech_research"]:
			_update_tech_button_state()
			_refresh_research_ui()
	
	print("💥 Building demolished at %s" % grid_pos)

func _on_info_requested(grid_pos: Vector2i):
	"""Handle info request - show building details"""
	var tile_grid = get_tree().root.get_node_or_null("PlanetSurface/TileGrid")
	if not tile_grid:
		return
	
	var tile_info = tile_grid.get_tile_info(grid_pos)
	var building_id = tile_info.get("building", "")
	
	if building_id != "":
		var building_data = GameData.get_building_by_id(building_id)
		print("ℹ️ %s at %s" % [building_data.name, grid_pos])
		print("   Description: %s" % building_data.description)
		
		if building_data.upkeep.size() > 0:
			print("   Upkeep: %s" % building_data.upkeep)
		
		if not building_data.get("production", {}).is_empty():
			var prod = building_data.production
			print("   Input: %s → Output: %s" % [prod.get("input", {}), prod.get("output", {})])

func _on_building_placed(building_id: String, grid_pos: Vector2i):
	"""Handle building placement - hide tooltip"""
	hide_placement_tooltip()
	if building_id in ["building_research", "ship_research", "tech_research"]:
		_update_tech_button_state()
		_refresh_research_ui()

#extends Control
#class_name CleanModernUI
## Clean modern UI with window system
#
#var building_manager: BuildingManager
#
## UI state
#var windows: Dictionary = {}  # Draggable windows
#var selected_category: String = "extraction"
#var _essential = ["water", "food", "oxygen", "minerals", "hydrogen", "biomatter", "energy"]
#
## UI Components
#var context_menu: BuildingContextMenu
#var placement_tooltip: PlacementTooltip
#var miner_warning: MisplacedMinerWarning
#var building_control: BuildingControl
#
#func _ready():
	#_build_ui()
	#_create_ui_components()
	#GameState.resources_changed.connect(_update_resource_display)
	#GameState.production_rate_changed.connect(_update_resource_display)
#
##func _create_ui_components():
	##"""Create all UI overlay components"""
	### Get reference to BuildingControl
	##building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	##print("🔍 Looking for BuildingControl...")
	##print("   Found: %s" % building_control)
	##
	##if not building_control:
		##print("❌ WARNING: BuildingControl not found!")
	##else:
		##print("✅ BuildingControl found successfully")
	##
	### Context Menu (for right-click on buildings)
	##context_menu = BuildingContextMenu.new()
	##context_menu.name = "ContextMenu"
	##context_menu.z_index = 100
	##add_child(context_menu)
	##
	### Connect context menu signals
	##context_menu.pause_requested.connect(_on_pause_requested)
	##context_menu.resume_requested.connect(_on_resume_requested)
	##context_menu.demolish_requested.connect(_on_demolish_requested)
	##context_menu.info_requested.connect(_on_info_requested)
	##
	### Placement Tooltip (shows info while placing)
	##placement_tooltip = PlacementTooltip.new()
	##placement_tooltip.name = "PlacementTooltip"
	##placement_tooltip.z_index = 90
	##add_child(placement_tooltip)
	##
	### Misplaced Miner Warning
	##miner_warning = MisplacedMinerWarning.new()
	##miner_warning.name = "MinerWarning"
	##miner_warning.z_index = 110
	##add_child(miner_warning)
	##
	### Connect warning signals
	##miner_warning.demolish_requested.connect(_on_demolish_requested)
	##
	##print("✅ UI components created and connected")
#
#func _process(_delta):
	#"""Check if mouse is over UI and update camera flag"""
	#var camera = get_viewport().get_camera_3d()
	#if not camera or not (camera is IsometricCamera):
		#return
	#
	#var mouse_pos = get_viewport().get_mouse_position()
	#var over_ui = false
	#
	## Check if mouse is over top bar
	#var top_bar = find_child("TopBar", true, false)
	#if top_bar and top_bar.visible:
		#var rect = Rect2(top_bar.global_position, top_bar.size)
		#if rect.has_point(mouse_pos):
			#over_ui = true
	#
	## Check if mouse is over bottom panel
	#var bottom_panel = find_child("BottomPanel", true, false)
	#if bottom_panel and bottom_panel.visible:
		#var rect = Rect2(bottom_panel.global_position, bottom_panel.size)
		#if rect.has_point(mouse_pos):
			#over_ui = true
	#
	## Check if mouse is over any open windows
	#for window in windows.values():
		#if is_instance_valid(window) and window.visible:
			#var rect = Rect2(window.global_position, window.size)
			#if rect.has_point(mouse_pos):
				#over_ui = true
				#break
	#
	#camera.is_mouse_over_ui = over_ui
#
#func setup(manager: BuildingManager):
	#building_manager = manager
	#
	## Connect building manager signals
	#if building_manager:
		#building_manager.building_placed.connect(_on_building_placed)
#
#func _create_ui_components():
	#"""Create all UI components"""
		## Get reference to BuildingControl
	#building_control = get_tree().root.get_node_or_null("PlanetSurface/BuildingControl")
	#print("🔍 Looking for BuildingControl...")
	#print("   Found: %s" % building_control)
	#
	#if not building_control:
		#print("❌ WARNING: BuildingControl not found!")
	#else:
		#print("✅ BuildingControl found successfully")
	#
	## Context Menu (for right-click on buildings)
	#context_menu = BuildingContextMenu.new()
	#context_menu.name = "ContextMenu"
	#context_menu.z_index = 100
	#add_child(context_menu)
	#
	## Connect context menu signals
	#context_menu.pause_requested.connect(_on_pause_requested)
	#context_menu.resume_requested.connect(_on_resume_requested)
	#context_menu.demolish_requested.connect(_on_demolish_requested)
	#context_menu.info_requested.connect(_on_info_requested)
	#
	## Placement Tooltip (shows info while placing)
	#placement_tooltip = PlacementTooltip.new()
	#placement_tooltip.name = "PlacementTooltip"
	#placement_tooltip.z_index = 90
	#add_child(placement_tooltip)
	#
	## Misplaced Miner Warning
	#miner_warning = MisplacedMinerWarning.new()
	#miner_warning.name = "MinerWarning"
	#miner_warning.z_index = 110
	#add_child(miner_warning)
	#
	## Connect warning signals
	#miner_warning.demolish_requested.connect(_on_demolish_requested)
#
#func _build_ui():
	#"""Build clean UI structure"""
	## Clear existing
	#for child in get_children():
		#child.queue_free()
	#
	## Top bar - Key resources only
	#_create_top_bar()
	#
	## Bottom panel - Building menu + action buttons
	#_create_bottom_panel()
#
#func _create_top_bar():
	#"""Compact top bar with essential resources"""
	#var bar = PanelContainer.new()
	#bar.name = "TopBar"
	#bar.anchor_right = 1.0
	#bar.custom_minimum_size.y = 50
	#add_child(bar)
	#
	#var margin = MarginContainer.new()
	#margin.add_theme_constant_override("margin_left", 20)
	#margin.add_theme_constant_override("margin_right", 20)
	#margin.add_theme_constant_override("margin_top", 10)
	#margin.add_theme_constant_override("margin_bottom", 10)
	#bar.add_child(margin)
	#
	#var hbox = HBoxContainer.new()
	#hbox.add_theme_constant_override("separation", 30)
	#margin.add_child(hbox)
	#
	## Essential resources only
	##var essential = ["water", "food", "oxygen", "minerals", "hydrogen", "biomatter", "energy"]
	#var essential = _essential
	#for res_id in essential:
		#var res_data = GameData.get_resource_by_id(res_id)
		#if res_data.is_empty():
			#continue
		#
		#_create_resource_display(hbox, res_id, res_data)
	#
	## Spacer
	#var spacer = Control.new()
	#spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#hbox.add_child(spacer)
	#
	## Action buttons
	#var resources_btn = Button.new()
	#resources_btn.text = "📊 Resources"
	#resources_btn.custom_minimum_size = Vector2(120, 30)
	#resources_btn.pressed.connect(_toggle_window.bind("resources"))
	#hbox.add_child(resources_btn)
	#
	#var tech_btn = Button.new()
	#tech_btn.text = "🔬 Tech Tree"
	#tech_btn.custom_minimum_size = Vector2(120, 30)
	#tech_btn.pressed.connect(_toggle_window.bind("tech"))
	#tech_btn.disabled = true  # Enable when R&D built
	#tech_btn.name = "TechButton"
	#hbox.add_child(tech_btn)
#
#func _create_resource_display(parent: Control, res_id: String, res_data: Dictionary):
	#"""Create single resource display"""
	#var vbox = VBoxContainer.new()
	#vbox.custom_minimum_size.x = 100
	#parent.add_child(vbox)
	#
	## Name
	#var name_label = Label.new()
	#name_label.text = res_data.name
	#name_label.add_theme_font_size_override("font_size", 11)
	#name_label.add_theme_color_override("font_color", Color.GRAY)
	#vbox.add_child(name_label)
	#
	## Amount bar
	#var hbox = HBoxContainer.new()
	#vbox.add_child(hbox)
	#
	#var icon = ColorRect.new()
	#icon.custom_minimum_size = Vector2(20, 20)
	#icon.color = res_data.color
	#hbox.add_child(icon)
	#
	#var amount = Label.new()
	#amount.name = "Amount_" + res_id
	#amount.text = str(GameState.resources.get(res_id, 0))
	#amount.add_theme_font_size_override("font_size", 18)
	#hbox.add_child(amount)
	#
	## Rate
	#var rate = Label.new()
	#rate.name = "Rate_" + res_id
	#rate.text = "+0"
	#rate.add_theme_font_size_override("font_size", 14)
	#vbox.add_child(rate)
#
#func _create_bottom_panel():
	#"""Building menu with categories"""
	#var panel = PanelContainer.new()
	#panel.name = "BottomPanel"
	#panel.anchor_top = 1.0
	#panel.anchor_right = 1.0
	#panel.offset_top = -150
	#add_child(panel)
	#
	#var vbox = VBoxContainer.new()
	#panel.add_child(vbox)
	#
	## Category tabs
	#var tabs = HBoxContainer.new()
	#tabs.add_theme_constant_override("separation", 5)
	#vbox.add_child(tabs)
	#
	#var categories = [
		#{"id": "extraction", "name": "⛏️ Extract"},
		#{"id": "production", "name": "🏭 Produce"},
		#{"id": "storage", "name": "📦 Store"},
		#{"id": "infrastructure", "name": "🏗️ Infrastructure"},
		##{"id": "energy", "name": "🏗️ Eneergy"},
		#{"id": "life_support", "name": "🏗️ Life Support"},
		#{"id": "social", "name": "🏗️ Social Support"},
		#{"id": "industrial", "name": "🏗️ Industrial"}
	#]
	#
	#for cat in categories:
		#var btn = Button.new()
		#btn.text = cat.name
		#btn.custom_minimum_size = Vector2(120, 35)
		#btn.toggle_mode = true
		#btn.button_pressed = (cat.id == selected_category)
		#btn.pressed.connect(_on_category_selected.bind(cat.id, btn, tabs))
		#tabs.add_child(btn)
	#
	## Building grid
	#var scroll = ScrollContainer.new()
	#scroll.custom_minimum_size.y = 105
	#vbox.add_child(scroll)
	#
	#var grid = GridContainer.new()
	#grid.name = "BuildingGrid"
	#grid.columns = 10
	#grid.add_theme_constant_override("h_separation", 8)
	#grid.add_theme_constant_override("v_separation", 8)
	#scroll.add_child(grid)
	#
	#_populate_building_grid()
#
#func _populate_building_grid():
	#"""Fill grid with buildings for selected category"""
	#var grid = find_child("BuildingGrid", true, false)
	#if not grid:
		#return
	#
	## Clear
	#for child in grid.get_children():
		#child.queue_free()
	#
	## Add buildings
	#for building in GameData.buildings:
		#if building.get("category", "") != selected_category:
			#continue
		#
		#var btn = Button.new()
		#btn.custom_minimum_size = Vector2(90, 90)
		#btn.pressed.connect(_on_building_clicked.bind(building.id))
		#grid.add_child(btn)
		#
		## Building info overlay
		#var vbox = VBoxContainer.new()
		#vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		#btn.add_child(vbox)
		#
		#var name_label = Label.new()
		#name_label.text = building.name
		#name_label.add_theme_font_size_override("font_size", 10)
		#name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		#name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		#vbox.add_child(name_label)
		#
		## Cost
		#var costs = []
		#for res_id in building.build_cost:
			#var amount = building.build_cost[res_id]
			#costs.append("%d %s" % [amount, res_id])
		#
		#if costs.size() > 0:
			#var cost_label = Label.new()
			#cost_label.text = "\n".join(costs)
			#cost_label.add_theme_font_size_override("font_size", 9)
			#cost_label.add_theme_color_override("font_color", Color.GRAY)
			#cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			#vbox.add_child(cost_label)
#
#func _on_category_selected(category: String, clicked_btn: Button, tabs_container: Control):
	#"""Switch category"""
	#selected_category = category
	#
	## Update button states
	#for btn in tabs_container.get_children():
		#if btn is Button:
			#btn.button_pressed = (btn == clicked_btn)
	#
	#_populate_building_grid()
#
#func _on_building_clicked(building_id: String):
	#"""Start building placement"""
	#if building_manager:
		#building_manager.start_placement(building_id)
#
#func _toggle_window(window_name: String):
	#"""Toggle draggable window"""
	#if window_name in windows and is_instance_valid(windows[window_name]):
		#windows[window_name].queue_free()
		#windows.erase(window_name)
	#else:
		#match window_name:
			#"resources":
				#_create_resources_window()
			#"tech":
				#_create_tech_window()
#
#func _create_resources_window():
	#"""Create detailed resources window"""
	#var window_data = _create_draggable_window("Resources", Vector2(350, 500), Vector2(100, 100))
	#windows["resources"] = window_data["window"]
	#
	#var scroll = ScrollContainer.new()
	#scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	#scroll.mouse_filter = Control.MOUSE_FILTER_STOP  # Block mouse events
	#window_data["content"].add_child(scroll)
	#
	## Consume scroll events to prevent camera zoom
	#scroll.gui_input.connect(func(event):
		#if event is InputEventMouseButton:
			#if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				#scroll.accept_event()  # Consume the event
	#)
	#
	#var list = VBoxContainer.new()
	#scroll.add_child(list)
	#
	#for resource in GameData.resources:
		#var panel = PanelContainer.new()
		#panel.custom_minimum_size.y = 70
		#list.add_child(panel)
		#
		#var margin = MarginContainer.new()
		#margin.add_theme_constant_override("margin_left", 10)
		#margin.add_theme_constant_override("margin_top", 10)
		#margin.add_theme_constant_override("margin_right", 10)
		#margin.add_theme_constant_override("margin_bottom", 10)
		#panel.add_child(margin)
		#
		#var vbox = VBoxContainer.new()
		#margin.add_child(vbox)
		#
		## Header
		#var hbox = HBoxContainer.new()
		#vbox.add_child(hbox)
		#
		#var icon = ColorRect.new()
		#icon.custom_minimum_size = Vector2(16, 16)
		#icon.color = resource.color
		#hbox.add_child(icon)
		#
		#var name_label = Label.new()
		#name_label.text = resource.name
		#name_label.add_theme_font_size_override("font_size", 14)
		#hbox.add_child(name_label)
		#
		## Progress bar
		#var progress = ProgressBar.new()
		#progress.name = "WindowProgress_" + resource.id
		#progress.max_value = GameState.get_storage_limit(resource.id)
		#progress.value = GameState.resources.get(resource.id, 0)
		#progress.show_percentage = false
		#vbox.add_child(progress)
		#
		## Stats
		#var stats = HBoxContainer.new()
		#vbox.add_child(stats)
		#
		#var amount_label = Label.new()
		#amount_label.name = "WindowAmount_" + resource.id
		#var current = GameState.resources.get(resource.id, 0)
		#var limit = GameState.get_storage_limit(resource.id)
		#amount_label.text = "%d/%d" % [current, limit]
		#amount_label.add_theme_font_size_override("font_size", 11)
		#stats.add_child(amount_label)
		#
		#var spacer = Control.new()
		#spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		#stats.add_child(spacer)
		#
		#var rate_label = Label.new()
		#rate_label.name = "WindowRate_" + resource.id
		#rate_label.text = "+0"
		#rate_label.add_theme_font_size_override("font_size", 11)
		#stats.add_child(rate_label)
#
#func _create_tech_window():
	#"""Create tech tree window (placeholder)"""
	#var window_data = _create_draggable_window("Technology", Vector2(600, 400), Vector2(200, 150))
	#windows["tech"] = window_data["window"]
	#
	#var label = Label.new()
	#label.text = "🔬 TECHNOLOGY TREE\n\n(Placeholder)\n\nBuild R&D building to unlock research"
	#label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	#label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	#window_data["content"].add_child(label)
#
#func _create_draggable_window(title: String, size: Vector2, pos: Vector2) -> Dictionary:
	#"""Create draggable window - returns dict with window and content"""
	#var window = PanelContainer.new()
	#window.custom_minimum_size = size
	#window.position = pos
	#window.mouse_filter = Control.MOUSE_FILTER_STOP  # Block mouse to 3D scene
	#add_child(window)
	#
	#var vbox = VBoxContainer.new()
	#window.add_child(vbox)
	#
	## Title bar (draggable)
	#var title_bar = PanelContainer.new()
	#title_bar.custom_minimum_size.y = 30
	#title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	#vbox.add_child(title_bar)
	#
	#var title_hbox = HBoxContainer.new()
	#title_bar.add_child(title_hbox)
	#
	#var title_label = Label.new()
	#title_label.text = " " + title
	#title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#title_hbox.add_child(title_label)
	#
	#var close_btn = Button.new()
	#close_btn.text = "×"
	#close_btn.custom_minimum_size = Vector2(30, 30)
	#close_btn.pressed.connect(func():
		#windows.erase(title.to_lower().replace(" ", "_"))
		#window.queue_free()
	#)
	#title_hbox.add_child(close_btn)
	#
	## Content area
	#var content = MarginContainer.new()
	#content.add_theme_constant_override("margin_left", 10)
	#content.add_theme_constant_override("margin_right", 10)
	#content.add_theme_constant_override("margin_bottom", 10)
	#content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	#content.mouse_filter = Control.MOUSE_FILTER_STOP  # Block scrolling through
	#vbox.add_child(content)
	#
	#var content_container = VBoxContainer.new()
	#content.add_child(content_container)
	#
	## Make draggable
	#var dragging = {"active": false, "offset": Vector2.ZERO}
	#
	#title_bar.gui_input.connect(func(event):
		#if event is InputEventMouseButton:
			#if event.button_index == MOUSE_BUTTON_LEFT:
				#if event.pressed:
					#dragging.active = true
					#dragging.offset = event.position
					## Bring window to front
					#window.move_to_front()
				#else:
					#dragging.active = false
		#elif event is InputEventMouseMotion and dragging.active:
			#window.position += event.relative
	#)
	#
	#return {"window": window, "content": content_container}
#
#func _update_resource_display(res_id: String = "", amount: int = 0):
	#"""Update all resource displays"""
	## Update top bar
	##for res_id2 in ["minerals", "hydrogen", "biomatter", "energy"]:
	#for res_id2 in _essential:
		#var amount_label = find_child("Amount_" + res_id2, true, false)
		#if amount_label:
			#amount_label.text = str(GameState.resources.get(res_id2, 0))
		#
		#var rate_label = find_child("Rate_" + res_id2, true, false)
		#if rate_label:
			#var net = GameState.get_net_rate(res_id2)
			#if net > 0:
				#rate_label.text = "+%.0f/min" % net
				#rate_label.add_theme_color_override("font_color", Color.GREEN)
			#elif net < 0:
				#rate_label.text = "%.0f/min" % net
				#rate_label.add_theme_color_override("font_color", Color.RED)
			#else:
				#rate_label.text = "+0"
				#rate_label.add_theme_color_override("font_color", Color.GRAY)
	#
	## Update resources window if open
	#if "resources" in windows and is_instance_valid(windows["resources"]):
		#for resource in GameData.resources:
			#var amount_label = windows["resources"].find_child("WindowAmount_" + resource.id, true, false)
			#if amount_label:
				#var current = GameState.resources.get(resource.id, 0)
				#var limit = GameState.get_storage_limit(resource.id)
				#amount_label.text = "%d/%d" % [current, limit]
			#
			#var rate_label = windows["resources"].find_child("WindowRate_" + resource.id, true, false)
			#if rate_label:
				#var net = GameState.get_net_rate(resource.id)
				#if net > 0:
					#rate_label.text = "+%.0f" % net
					#rate_label.add_theme_color_override("font_color", Color.GREEN)
				#elif net < 0:
					#rate_label.text = "%.0f" % net
					#rate_label.add_theme_color_override("font_color", Color.RED)
				#else:
					#rate_label.text = "+0"
					#rate_label.add_theme_color_override("font_color", Color.GRAY)
			#
			#var progress = windows["resources"].find_child("WindowProgress_" + resource.id, true, false)
			#if progress:
				#progress.value = GameState.resources.get(resource.id, 0)
#
## ============================================
## UI Component Interface Functions
## ============================================
#
#func show_building_context_menu(grid_pos: Vector2i, building_id: String, world_pos: Vector3, is_paused: bool):
	#"""Show context menu for a building"""
	#if context_menu:
		#context_menu.show_for_building(grid_pos, building_id, world_pos, is_paused)
#
#func show_placement_tooltip(building_id: String, can_place: bool, can_afford: bool):
	#"""Show tooltip during building placement"""
	#if placement_tooltip:
		#placement_tooltip.show_for_building(building_id, can_place, can_afford)
		#
#func hide_placement_tooltip():
	#"""Hide placement tooltip"""
	#if placement_tooltip:
		#placement_tooltip.hide()
#
#func update_placement_tooltip_position(mouse_pos: Vector2):
	#"""Update tooltip position"""
	#if placement_tooltip and placement_tooltip.visible:
		#placement_tooltip.update_position(mouse_pos)
#
#func show_misplaced_miner_warning(grid_pos: Vector2i):
	#"""Show warning for misplaced miner"""
	#if miner_warning:
		#miner_warning.show_warning(grid_pos)
#
## ============================================
## Signal Handlers for UI Components
## ============================================
#
#func _on_pause_requested(grid_pos: Vector2i):
	#"""Handle pause request from context menu"""
	#print("📥 UI received pause_requested for %s" % grid_pos)
	#print("   building_control = %s" % building_control)
	#print("   building_manager = %s" % building_manager)
	#
	#if building_control:
		#print("   Calling BuildingControl.pause_building()...")
		#building_control.pause_building(grid_pos)
		#print("✅ BuildingControl.pause_building() called")
	#else:
		#print("❌ building_control is NULL!")
	#
	## Use building_manager to handle pause (it updates resource tracker)
	#if building_manager:
		#building_manager.pause_building(grid_pos)
		#print("✅ BuildingManager.pause_building() called")
	#else:
		#print("❌ building_manager is NULL!")
#
#func _on_resume_requested(grid_pos: Vector2i):
	#"""Handle resume request from context menu"""
	#print("📥 UI received resume_requested for %s" % grid_pos)
	#
	#if building_control:
		#building_control.resume_building(grid_pos)
		#print("✅ BuildingControl.resume_building() called")
	#
	## Use building_manager to handle resume (it updates resource tracker)
	#if building_manager:
		#building_manager.resume_building(grid_pos)
		#print("✅ BuildingManager.resume_building() called")
#
#func _on_demolish_requested(grid_pos: Vector2i):
	#"""Handle demolish request"""
	#var tile_grid = get_tree().root.get_node_or_null("PlanetSurface/TileGrid")
	#
	#if not tile_grid:
		#return
	#
	## Get building info
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#var building_id = tile_info.get("building", "")
	#
	#if building_id == "":
		#return
	#
	## Get refund
	#var refund = {}
	#if building_control:
		#refund = building_control.demolish_building(grid_pos, building_id)
		#print("💰 Refund calculated: %s" % refund)
	#else:
		#print("❌ No building_control found!")
	#
	## Add refunded resources
	#if refund.is_empty():
		#print("⚠️ Refund is empty!")
	#else:
		#for resource_id in refund:
			#var amount = refund[resource_id]
			#GameState.add_resource(resource_id, amount)
			#print("💰 Refunded: %d %s" % [amount, resource_id])
	#
	## Remove building visually
	#if building_manager:
		#building_manager.demolish_building(grid_pos)
	#
	#print("💥 Building demolished at %s" % grid_pos)
#
#func _on_info_requested(grid_pos: Vector2i):
	#"""Handle info request - show building details"""
	#var tile_grid = get_tree().root.get_node_or_null("PlanetSurface/TileGrid")
	#if not tile_grid:
		#return
	#
	#var tile_info = tile_grid.get_tile_info(grid_pos)
	#var building_id = tile_info.get("building", "")
	#
	#if building_id != "":
		#var building_data = GameData.get_building_by_id(building_id)
		#print("ℹ️ %s at %s" % [building_data.name, grid_pos])
		#print("   Description: %s" % building_data.description)
		#
		#if building_data.upkeep.size() > 0:
			#print("   Upkeep: %s" % building_data.upkeep)
		#
		#if not building_data.get("production", {}).is_empty():
			#var prod = building_data.production
			#print("   Input: %s → Output: %s" % [prod.get("input", {}), prod.get("output", {})])
#
#func _on_building_placed(building_id: String, grid_pos: Vector2i):
	#"""Handle building placement - hide tooltip"""
	#hide_placement_tooltip()
