extends CanvasLayer
# DebugOverlay - Shows tile information and game stats
@onready var vbox := $Panel/MarginContainer/VBoxContainer

@onready var fps_label  : Label = vbox.get_node("FPSLabel")
@onready var time_label : Label = vbox.get_node("TimeLabel")
@onready var pos_label  : Label = vbox.get_node("CameraLabel")
@onready var tile_info_label : Label = vbox.get_node("TileLabel")

var tile_grid: TileGrid
var camera: IsometricCamera
var game_time: float = 0.0

func _ready():
	pass

func setup(grid: TileGrid, cam: IsometricCamera):
	tile_grid = grid
	camera = cam

func _process(delta):
	game_time += delta
	_update_debug_info(delta)

func _update_debug_info(delta):
	# FPS
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	# Game time
	var minutes = int(game_time / 60)
	var seconds = int(game_time) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	
	# Camera position
	if camera:
		pos_label.text = "Cam: (%.1f, %.1f, %.1f)" % [camera.position.x, camera.position.y, camera.position.z]
	
	# Tile under mouse
	if camera and tile_grid:
		var mouse_world = camera.get_mouse_world_position()
		var grid_pos = tile_grid.world_to_grid(mouse_world)
		
		if tile_grid.is_valid_pos(grid_pos):
			var tile_info = tile_grid.get_tile_info(grid_pos)
			
			var info_text = "Tile [%d, %d]\n" % [grid_pos.x, grid_pos.y]
			info_text += "Type: %s\n" % tile_info.get("type", "unknown")
			
			var resource = tile_info.get("resource", null)
			if resource != null and resource != "":
				var resource_data = GameData.get_resource_by_id(resource)
				if not resource_data.is_empty():
					info_text += "Resource: %s\n" % resource_data.name
				else:
					info_text += "Resource: %s (invalid)\n" % resource
			else:
				info_text += "Resource: None\n"
			
			var building = tile_info.get("building", null)
			if building != null and building != "":
				info_text += "Building: %s\n" % building
			else:
				info_text += "Building: None\n"
			
			var occupied = tile_info.get("occupied", false)
			info_text += "Occupied: %s" % ("Yes" if occupied else "No")
			
			tile_info_label.text = info_text
		else:
			tile_info_label.text = "Tile: Out of bounds"
