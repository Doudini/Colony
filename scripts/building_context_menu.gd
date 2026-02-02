extends PanelContainer
class_name BuildingContextMenu
# Right-click context menu for buildings

var current_grid_pos: Vector2i = Vector2i(-1, -1)
var current_building_id: String = ""
var is_paused: bool = false

signal pause_requested(grid_pos: Vector2i)
signal resume_requested(grid_pos: Vector2i)
signal info_requested(grid_pos: Vector2i)
signal demolish_requested(grid_pos: Vector2i)

func _ready():
	hide()
	
	# Create menu structure
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Title
	var title = Label.new()
	title.name = "Title"
	title.text = "BUILDING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title)
	
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Pause/Resume button
	var pause_btn = Button.new()
	pause_btn.name = "PauseButton"
	pause_btn.text = "⏸️ Pause Production"
	pause_btn.custom_minimum_size = Vector2(180, 30)
	pause_btn.pressed.connect(_on_pause_pressed)
	vbox.add_child(pause_btn)
	
	# Info button
	var info_btn = Button.new()
	info_btn.text = "🔍 View Info"
	info_btn.custom_minimum_size = Vector2(180, 30)
	info_btn.pressed.connect(_on_info_pressed)
	vbox.add_child(info_btn)
	
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Demolish button
	var demolish_btn = Button.new()
	demolish_btn.text = "💥 Demolish (50% refund)"
	demolish_btn.custom_minimum_size = Vector2(180, 30)
	demolish_btn.pressed.connect(_on_demolish_pressed)
	vbox.add_child(demolish_btn)

func show_for_building(grid_pos: Vector2i, building_id: String, world_pos: Vector3, paused: bool):
	"""Show menu for a building"""
	print("📋 Context menu showing for %s, paused=%s" % [grid_pos, paused])
	
	current_grid_pos = grid_pos
	current_building_id = building_id
	is_paused = paused
	
	print("   Menu internal state set: is_paused=%s" % is_paused)
	
	# Update title
	var building_data = GameData.get_building_by_id(building_id)
	var title = find_child("Title", true, false)
	if title:
		title.text = building_data.name.to_upper()
	
	# Update pause button
	var pause_btn = find_child("PauseButton", true, false)
	if pause_btn:
		if paused:
			pause_btn.text = "▶️ Resume Production"
			print("   Button set to: Resume Production")
		else:
			pause_btn.text = "⏸️ Pause Production"
			print("   Button set to: Pause Production")
	
	# Position near click (but on screen)
	var viewport_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	
	position.x = clamp(mouse_pos.x, 0, viewport_size.x - size.x)
	position.y = clamp(mouse_pos.y, 0, viewport_size.y - size.y)
	
	show()

func _on_pause_pressed():
	print("🖱️ Pause button clicked! Current state: paused=%s" % is_paused)
	if is_paused:
		print("▶️ Emitting resume_requested")
		resume_requested.emit(current_grid_pos)
	else:
		print("⏸️ Emitting pause_requested")
		pause_requested.emit(current_grid_pos)
	hide()

func _on_info_pressed():
	info_requested.emit(current_grid_pos)
	hide()

func _on_demolish_pressed():
	demolish_requested.emit(current_grid_pos)
	hide()

func _input(event):
	# Hide on any click outside
	if visible and event is InputEventMouseButton and event.pressed:
		if not get_global_rect().has_point(event.position):
			hide()
