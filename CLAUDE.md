# CLAUDE.md - AI Assistant Guide for Colony Project

## Project Overview

**Space Colony Trader** is a tile-based colony builder game built with **Godot 4.5** using GDScript. Inspired by Anno, Factorio, and Oxygen Not Included, the game features:
- 256x256 procedurally generated terrain with chunked rendering
- Multi-tile building placement with production chains
- Resource extraction, processing, and life support systems
- Marching squares autotiling for terrain transitions

## Quick Reference

```bash
# Run the game (from Godot editor or command line)
godot --path /home/user/Colony scenes/planet_surface.tscn

# Project entry point
scenes/planet_surface.tscn
```

## Directory Structure

```
Colony/
├── project.godot              # Godot project config (4.5, Forward Plus)
├── scenes/
│   ├── planet_surface.tscn    # Main game scene (entry point)
│   └── planet_surface_new.tscn # Alternative scene variant
├── scripts/
│   ├── game_data.gd           # AUTOLOAD: Resource/building/research definitions
│   ├── game_state.gd          # AUTOLOAD: Global state, resources, rates
│   ├── planet_surface.gd      # Main scene controller
│   ├── tile_grid.gd           # 256x256 grid with chunked rendering
│   ├── building_manager.gd    # Building placement, production, visuals
│   ├── clean_modern_ui.gd     # Main UI system, windows, menus
│   ├── resource_tracker.gd    # Production/consumption rate calculation
│   ├── upkeep_manager.gd      # Building upkeep (energy, biomatter)
│   ├── building_control.gd    # Pause/resume state management
│   ├── isometric_camera.gd    # Camera controls (WASD, zoom, rotation)
│   ├── hover_detector.gd      # Mouse hover detection
│   ├── building_tooltip.gd    # Hover tooltips for buildings
│   ├── placement_tooltip.gd   # Building placement preview
│   ├── building_context_menu.gd # Right-click menu
│   └── *.gd.uid               # Godot UID files (auto-generated)
├── shaders/
│   └── grid_overlay.gdshader  # Grid line overlay shader
├── tex/
│   └── terrain_tileset_v2.png # Terrain texture atlas
└── docs/                      # Reference documentation
    ├── PROJECT_STATUS_SUMMARY.md
    ├── TERRAIN_TEXTURING_GUIDE.md
    ├── MARCHING_SQUARES_REFERENCE.md
    └── TEXTURE_ATLAS_TEMPLATE.md
```

## Architecture

### Autoload Singletons (Global Scripts)

Defined in `project.godot`:
- **GameData** (`scripts/game_data.gd`): Static definitions for resources, buildings, research
- **GameState** (`scripts/game_state.gd`): Runtime state, resource amounts, production rates

Access from any script:
```gdscript
var building = GameData.get_building_by_id("solar_panel")
var minerals = GameState.resources.get("minerals", 0)
```

### Main Scene Hierarchy

```
PlanetSurface (Node3D)
├── IsometricCamera (Camera3D)
├── TileGrid (Node3D)          # Generates terrain chunks
├── BuildingManager (Node3D)    # Manages placed buildings
├── DirectionalLight3D
├── WorldEnvironment
├── HoverDetector (Node)
├── UpkeepManager (Node)
├── ResourceTracker (Node)
├── BuildingControl (Node)
├── UI (Control)               # Full-screen UI layer
└── DebugOverlay (CanvasLayer)
```

### Key Systems

#### TileGrid (`tile_grid.gd`)
- **Grid size**: 256x256 tiles, `TILE_SIZE = 2.0` world units
- **Chunks**: 16x16 tiles per chunk for efficient rendering
- **Terrain types**: deep_water, shallow_water, beach, marsh, lowland, forest, grassland, ground, highland, mountain
- **Resources**: minerals, biomatter, hydrogen, crystals, wood, ore, rare_minerals
- **Autotiling**: Marching squares algorithm with terrain priority system

#### BuildingManager (`building_manager.gd`)
- Handles building placement preview and validation
- Creates 3D meshes for buildings
- Tracks placed buildings in `placed_buildings: Dictionary`
- Manages extraction/production timers
- Emits signals: `building_placed`, `building_right_clicked`

#### Resource System
- **13+ resource types** across tiers (0-3)
- **10-second production cycles** (consistent timing, vary amounts)
- **Rate tracking**: Per-minute internally, displayed per-second in UI
- **Storage limits**: Upgradeable with warehouse buildings

## Code Conventions

### GDScript Style
```gdscript
# Class structure
extends Node3D
class_name BuildingManager

# Constants in SCREAMING_SNAKE_CASE
const TILE_SIZE := 2.0
const CHUNK_SIZE := 16

# Exported variables for editor configuration
@export var tile_grid: TileGrid

# Private variables with descriptive names
var placed_buildings: Dictionary = {}

# Signals for loose coupling
signal building_placed(building_id: String, grid_pos: Vector2i)

# Docstrings for public functions
func start_placement(building_id: String):
    """Start placing a building"""
    pass

# Private functions prefixed with underscore
func _create_preview():
    pass
```

### Signal Patterns
```gdscript
# Emit signals for state changes
building_placed.emit(building_id, grid_pos)

# Connect in _ready()
building_manager.building_placed.connect(_on_building_placed)
GameState.resources_changed.connect(_update_resource_display)
```

### Coordinate Systems
```gdscript
# Grid coordinates (tile indices)
var grid_pos: Vector2i = Vector2i(50, 60)

# World coordinates (3D space)
var world_pos: Vector3 = tile_grid.grid_to_world(grid_pos)

# Conversion
var grid_pos = tile_grid.world_to_grid(world_pos)
```

### Multi-Tile Buildings
Buildings larger than 1x1 store their origin position:
```gdscript
# All tiles of a 2x2 building point to origin
tile_info["building_origin"] = Vector2i(50, 60)  # Top-left corner

# Always use origin for operations
var origin = tile_info.get("building_origin", grid_pos)
```

## Common Development Tasks

### Adding a New Building

Edit `scripts/game_data.gd` in the `_initialize_buildings()` function:

```gdscript
{
    "id": "new_building",
    "name": "New Building",
    "description": "What it does",
    "size": Vector2i(2, 2),  # Footprint in tiles
    "build_cost": {"minerals": 50, "metal": 20},
    "upkeep": {"energy": 1},  # Per production cycle
    "production": {
        "inputs": {"minerals": 2},
        "outputs": {"metal": 1},
        "cycle_time": 10.0  # Seconds
    },
    "color": Color(0.5, 0.5, 0.5),
    "category": "production",  # extraction, production, infrastructure, life_support, social
    "tier": 1
}
```

### Adding a New Resource

Edit `scripts/game_data.gd` in the `_initialize_resources()` function:

```gdscript
{
    "id": "new_resource",
    "name": "New Resource",
    "description": "Description here",
    "color": Color(0.5, 0.5, 0.5),
    "tier": 1,  # 0=raw, 1=processed, 2=advanced, 3=high-tech
    "extractable": false  # true if can be mined from deposits
}
```

### Adding Placement Requirements

Edit `building_manager.gd`, `_check_placement_requirement()` function:

```gdscript
"requires_water":
    # Must be adjacent to water
    return _has_adjacent_terrain(grid_pos, building_data.size, ["shallow_water", "deep_water"])
```

### Modifying UI

Main UI is in `scripts/clean_modern_ui.gd`:
- `_build_ui()`: Creates UI structure
- `_update_resource_display()`: Updates resource bar
- `_create_building_button()`: Creates building menu buttons

## Key Technical Details

### Terrain Generation
Uses `FastNoiseLite` with multiple layers:
- `height_noise`: Base elevation
- `moisture_noise`: Water/vegetation distribution
- `temperature_noise`: Biome variation
- `ridge_noise`: Mountain ridges

### Marching Squares Autotiling
Defined in `tile_grid.gd`:
- `TERRAIN_PRIORITY`: Higher values dominate (water=100, beach=80, grass=60)
- `TERRAIN_TRANSITIONS`: Maps each terrain to its transition target
- `_get_autotile_index()`: Returns 0-15 bitmask based on neighbors

### Performance Optimizations
- Chunked mesh rendering (16x16 tiles per draw call)
- Single texture atlas for all terrain
- UV calculations at mesh generation time
- 60 FPS with 50+ buildings

### Input Mappings (project.godot)
- WASD: Camera movement
- Q/E: Camera rotation
- Mouse wheel: Zoom
- Middle mouse: Pan
- Right-click: Building context menu

## Known Issues / TODOs

1. Technology tree is structured but not fully functional
2. Population system exists but has no mechanics
3. Happiness system provides bonuses but no actual effect
4. Save/Load system not implemented
5. No audio (music/sound effects)

## Testing

No automated test suite. Manual testing:
1. Run from Godot editor (F5)
2. Check building placement works
3. Verify resource production rates
4. Test pause/resume/demolish via right-click menu
5. Check UI updates correctly

## File Naming Conventions

- Scripts: `snake_case.gd`
- Scenes: `snake_case.tscn`
- Shaders: `snake_case.gdshader`
- Textures: `snake_case.png`
- UID files: Auto-generated by Godot, don't edit

## Important Patterns to Preserve

1. **Production cycles**: Always 10 seconds, vary output amounts
2. **Energy as resource**: Stored and consumed like materials
3. **Per-second display**: UI shows rates per-second (internal is per-minute)
4. **Building origins**: Multi-tile buildings tracked by top-left corner
5. **50% demolish refund**: Get back half of building costs
6. **Signal-based communication**: Loose coupling between systems

## 3D Terrain Plan (tile_grid_var2.gd)

### Overview
`tile_grid_var2.gd` is an alternative terrain renderer that adds 3D heightmapped terrain with cliffs and elevation, inspired by SimCity 4 / Anno. It replaces flat Y=0 terrain with discrete height levels while keeping the same terrain generation, autotiling, and resource systems from `tile_grid.gd`.

### Architecture
- **Inherits from**: Standalone script (copy of tile_grid.gd with modified mesh generation)
- **class_name**: `TileGridVar2` (can swap with `TileGrid` in scenes)
- **Shader**: `terrain_blend_3d.gdshader` (extends terrain_blend with slope-based cliff texturing)

### Height Level System
Maps terrain types to discrete world-Y elevations:
```
deep_water    → Y = -3.0
shallow_water → Y = -1.5
beach         → Y =  0.0  (sea level)
lowland/grass → Y =  1.5
forest        → Y =  2.0
ground        → Y =  3.0
highland      → Y =  5.0
mountain      → Y =  7.0
```

### Corner Height Interpolation
Each tile has 4 corners. A corner's height = average of the up-to-4 tiles sharing that corner. This creates smooth slopes between elevation levels. Steep deltas produce natural cliff faces.

### Tile Subdivision
Each tile is subdivided into a 3x3 grid (18 triangles vs 2 in flat version). Sub-vertex heights are bilinearly interpolated from corner heights. Total geometry: ~1.2M triangles (65k tiles × 18 tri), chunked as before.

### Cliff Texturing (terrain_blend_3d.gdshader)
Extends the existing terrain_blend shader with slope detection:
- `NORMAL.y > 0.7` → use terrain atlas texture (flat/gentle slope)
- `NORMAL.y < 0.3` → use cliff rock texture (steep/vertical)
- Between → smooth blend

### Implementation Phases
1. **Phase 1 (current)**: Heightmapped terrain mesh + cliff shader
2. **Phase 2**: Water plane system with water shader (transparency, foam, waves)
3. **Phase 3**: Integration fixes (camera height-awareness, building Y placement, hover detection)
4. **Phase 4**: Visual polish (AO, shore detail, LOD)

### Key Files
| File | Purpose |
|------|---------|
| `scripts/tile_grid_var2.gd` | 3D terrain renderer (alternative to tile_grid.gd) |
| `shaders/terrain_blend_3d.gdshader` | Slope-aware terrain + cliff shader |
| `shaders/water.gdshader` | Water surface (Phase 2) |

### Switching Between Variants
In the scene editor, swap the TileGrid node's script between `tile_grid.gd` (flat) and `tile_grid_var2.gd` (3D). Both use the same grid data format, signals, and public API (`grid_to_world`, `world_to_grid`, `can_place_building`, etc).

## Documentation Files

- `PROJECT_STATUS_SUMMARY.md`: Current implementation status
- `TERRAIN_TEXTURING_GUIDE.md`: How to create texture atlases
- `MARCHING_SQUARES_REFERENCE.md`: Visual guide for 16-tile autotiling
- `TEXTURE_ATLAS_TEMPLATE.md`: Atlas layout specifications
