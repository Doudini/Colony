extends Node
class_name HoverDetector
# Detects buildings and tiles under mouse for tooltips

var camera: IsometricCamera
var tile_grid: TileGrid
var building_manager: BuildingManager
var tooltip: BuildingTooltip

var last_hovered_building: Vector2i = Vector2i(-1, -1)
var last_hovered_tile: Vector2i = Vector2i(-1, -1)
var hover_delay: float = 0.3  # Seconds before showing tooltip
var hover_timer: float = 0.0
var is_hovering: bool = false

func _ready():
	pass

func setup(cam: IsometricCamera, grid: TileGrid, manager: BuildingManager, tip: BuildingTooltip):
	camera = cam
	tile_grid = grid
	building_manager = manager
	tooltip = tip

func _process(delta):
	if not camera or not tile_grid or not tooltip:
		return
	
	# Get tile under mouse
	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = tile_grid.world_to_grid(mouse_world)
	
	if not tile_grid.is_valid_pos(grid_pos):
		_clear_hover()
		return
	
	# Check if we're in building placement mode
	if building_manager and building_manager.is_placing:
		_clear_hover()
		return
	
	# Get tile info
	var tile_info = tile_grid.get_tile_info(grid_pos)
	var building_id = tile_info.get("building", null)
	
	# Determine what we're hovering
	if building_id != null and building_id != "":
		# Hovering a building
		if grid_pos != last_hovered_building:
			last_hovered_building = grid_pos
			last_hovered_tile = Vector2i(-1, -1)
			hover_timer = 0.0
			is_hovering = false
			tooltip.hide()
		
		if not is_hovering:
			hover_timer += delta
			if hover_timer >= hover_delay:
				is_hovering = true
				tooltip.show_building_info(building_id, grid_pos)
				tooltip.update_position(get_viewport().get_mouse_position())
		else:
			# Update position while hovering
			tooltip.update_position(get_viewport().get_mouse_position())
	else:
		# Hovering empty tile or resource
		if grid_pos != last_hovered_tile:
			last_hovered_tile = grid_pos
			last_hovered_building = Vector2i(-1, -1)
			hover_timer = 0.0
			is_hovering = false
			tooltip.hide()
		
		# Only show tile tooltip if there's a resource
		var resource = tile_info.get("resource", null)
		if resource != null and resource != "":
			if not is_hovering:
				hover_timer += delta
				if hover_timer >= hover_delay:
					is_hovering = true
					tooltip.show_tile_info(grid_pos)
					tooltip.update_position(get_viewport().get_mouse_position())
			else:
				tooltip.update_position(get_viewport().get_mouse_position())
		else:
			# No interesting info to show
			_clear_hover()

func _clear_hover():
	if is_hovering:
		tooltip.hide()
		is_hovering = false
	hover_timer = 0.0
	last_hovered_building = Vector2i(-1, -1)
	last_hovered_tile = Vector2i(-1, -1)
