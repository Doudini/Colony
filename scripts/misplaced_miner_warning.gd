extends PanelContainer
class_name MisplacedMinerWarning
# Warning popup when miner is placed on empty tile

var warned_positions: Array[Vector2i] = []

signal demolish_requested(grid_pos: Vector2i)

func _ready():
	hide()

func show_warning(grid_pos: Vector2i):
	"""Show warning for misplaced miner"""
	# Don't warn twice for same position
	if grid_pos in warned_positions:
		return
	
	warned_positions.append(grid_pos)
	
	# Clear existing content
	for child in get_children():
		child.queue_free()
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Warning icon and title
	var title = Label.new()
	title.text = "⚠️ WARNING: Misplaced Miner!"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.ORANGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Message
	var message = Label.new()
	message.text = "This miner is not on a resource deposit.\n\nIt will consume upkeep but produce NOTHING.\n\nPlace miners on GLOWING tiles for resources!"
	message.add_theme_font_size_override("font_size", 12)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	message.custom_minimum_size.x = 300
	vbox.add_child(message)
	
	vbox.add_child(HSeparator.new())
	
	# Buttons
	var button_box = HBoxContainer.new()
	button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	button_box.add_theme_constant_override("separation", 10)
	vbox.add_child(button_box)
	
	var demolish_btn = Button.new()
	demolish_btn.text = "💥 Demolish (refund 50%)"
	demolish_btn.custom_minimum_size = Vector2(150, 40)
	demolish_btn.pressed.connect(func():
		demolish_requested.emit(grid_pos)
		hide()
	)
	button_box.add_child(demolish_btn)
	
	var keep_btn = Button.new()
	keep_btn.text = "Keep Anyway"
	keep_btn.custom_minimum_size = Vector2(120, 40)
	keep_btn.pressed.connect(hide)
	button_box.add_child(keep_btn)
	
	# Center on screen
	var viewport_size = get_viewport_rect().size
	position = (viewport_size - size) / 2
	
	show()
	
	# Auto-hide after 10 seconds
	await get_tree().create_timer(10.0).timeout
	if visible:
		hide()
