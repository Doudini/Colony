# Terrain Texturing Implementation Guide

## Overview

The marching squares autotiling system has been successfully implemented in `scripts/tile_grid.gd`. This system uses a priority-based transition approach to create smooth terrain transitions with minimal texture requirements.

## What Was Implemented

### 1. Configuration Constants (lines ~99-182)

**TERRAIN_PRIORITY**: Defines the dominance hierarchy
- Water types are most dominant (100, 90)
- Beach/Marsh in the middle (80, 70)
- Land types decrease in priority (60 → 20)

**TERRAIN_TRANSITIONS**: Maps each terrain to its transition target
- Grassland → Beach
- Beach → Shallow Water
- Forest → Grassland
- etc.

**ATLAS_CONFIG**: Defines texture atlas layout
- Each terrain assigned a row in the atlas
- Specifies tile count and variation count
- Currently configured for 128px tiles, 16 tiles per row

### 2. Autotiling Functions

**`_get_autotile_index(pos: Vector2i) -> int`**
- Core marching squares algorithm
- Checks 4 cardinal neighbors (N, E, S, W)
- Returns bitmask 0-15 indicating which neighbors to transition to
- Handles tile variations for solid center tiles

**`_get_tile_variation(pos: Vector2i, tile_type: String) -> int`**
- Position-based pseudo-random variation selection
- Ensures consistency (same tile always gets same variation)
- Returns indices 15+ for variation tiles

**`_get_water_variation(pos: Vector2i) -> int`**
- Simple variation for water (no transitions needed)
- Returns 0-3 for water tile variations

**`_get_tile_uv_coords(pos: Vector2i) -> Array`**
- Returns UV coordinates for a tile based on its type and neighbors
- Coordinates are [top_left, top_right, bottom_right, bottom_left]

**`_calculate_uv_for_tile(tile_index: int, atlas_row: int) -> Array`**
- Converts tile index and atlas row to UV coordinates
- Handles atlas layout calculation

### 3. Rendering Updates

**`_create_chunk_mesh(chunk: Vector2i)`** - Modified
- Now supports both texture atlas and vertex color fallback
- Automatically uses texture if `terrain_atlas` is assigned
- Falls back to colors if atlas is missing

**`_add_quad_with_uv(st: SurfaceTool, pos: Vector3, uv_coords: Array)`** - New
- Adds quad geometry with UV texture coordinates
- Properly maps UVs to vertices

**`_add_quad_with_color(st: SurfaceTool, pos: Vector3, color: Color)`** - Renamed
- Original color-based quad creation (for fallback)

## How to Use

### Step 1: Create Your Texture Atlas

Create a texture atlas with the following specifications:

**Atlas Dimensions**: 2048 x 2048 pixels (or 16 x 16 tiles at 128px each)

**Layout** (each row is 128px tall):
```
Row 0:  Beach tiles         (16 tiles: indices 0-15, then variations)
Row 1:  Grassland tiles     (16 tiles: indices 0-15, then variations)
Row 2:  Forest tiles        (16 tiles: indices 0-15, then variations)
Row 3:  Ground tiles        (16 tiles: indices 0-15, then variations)
Row 4:  Highland tiles      (16 tiles: indices 0-15, then variations)
Row 5:  Mountain tiles      (16 tiles: indices 0-15, then variations)
Row 6:  Marsh tiles         (16 tiles: indices 0-15, then variations)
Row 7:  Water tiles         (4-8 simple tiles)
```

**Marching Squares Tile Order** (indices 0-15):
```
Index  | N E S W | Description
-------|---------|-------------
  0    | 0 0 0 0 | Island (surrounded by transition)
  1    | 0 0 0 1 | West edge only
  2    | 0 0 1 0 | South edge only
  3    | 0 0 1 1 | South-West corner
  4    | 0 1 0 0 | East edge only
  5    | 0 1 0 1 | East-West edges
  6    | 0 1 1 0 | South-East corner
  7    | 0 1 1 1 | South, East, West edges
  8    | 1 0 0 0 | North edge only
  9    | 1 0 0 1 | North-West corner
 10    | 1 0 1 0 | North-South edges
 11    | 1 0 1 1 | North, South, West edges
 12    | 1 1 0 0 | North-East corner
 13    | 1 1 0 1 | North, East, West edges
 14    | 1 1 1 0 | North, East, South edges
 15    | 1 1 1 1 | Fully surrounded (solid tile)
```

**Bit positions**: N=bit3, E=bit2, S=bit1, W=bit0
- Bit = 1 means "same terrain" (no transition)
- Bit = 0 means "different terrain" (show transition)

### Step 2: Configure Atlas in Godot

1. Import your texture atlas PNG into your Godot project
2. Select the TileGrid node in your scene
3. In the Inspector, find the "Terrain Atlas" property
4. Drag your texture atlas texture into this property

### Step 3: Test

Run your game! The terrain should now display with:
- ✅ Smooth transitions between biomes
- ✅ Marching squares autotiling
- ✅ Pseudo-random variations for center tiles
- ✅ Proper fallback to colors if no atlas is assigned

### Step 4: Adjust Configuration (Optional)

If you need to adjust the atlas layout:

**Edit `ATLAS_CONFIG` constant** (around line 127):
```gdscript
const ATLAS_CONFIG := {
    "beach": {
        "row": 0,              # Which row in atlas
        "has_transitions": true,
        "tile_count": 16,
        "variations": 3        # How many variation tiles
    },
    # ... etc
}
```

**Modify atlas size** (around line 173):
```gdscript
const ATLAS_TILE_SIZE := 128  # Pixels per tile
const ATLAS_TILES_PER_ROW := 16  # Tiles per row
```

## How the Priority System Works

**Example: Grass → Beach → Ocean**

1. **Ocean (deep_water) tile:**
   - Priority: 100 (highest)
   - No transitions defined (solid tiles)
   - Uses simple variations (0-3)

2. **Beach tile next to ocean:**
   - Priority: 80
   - Transitions to: shallow_water (priority 90)
   - Checks neighbors: finds water to the east
   - Result: Shows beach-to-water transition on east edge
   - **Uses: beach tileset, index based on water neighbor positions**

3. **Grass tile next to beach:**
   - Priority: 60
   - Transitions to: beach (priority 80)
   - Checks neighbors: finds beach to the north
   - Result: Shows grass-to-beach transition on north edge
   - **Uses: grassland tileset, index based on beach neighbor positions**

4. **Grass tile directly next to ocean** (rare case):
   - Priority: 60
   - Transitions to: beach (priority 80)
   - Checks neighbors: finds water (priority 90) instead
   - Water priority > grass priority, so treats as transition
   - Result: Shows grass transitioning (uses beach transition as fallback)

## Tileset Creation Tips

### Creating Marching Squares Tilesets

1. **Start with the corners** (indices 3, 6, 9, 12)
   - These are your foundation pieces
   - Make sure curves are smooth

2. **Create the edges** (indices 1, 2, 4, 8)
   - Should connect seamlessly to corners

3. **Handle multi-edge tiles** (indices 5, 7, 10, 11, 13, 14)
   - Check that transitions flow naturally

4. **Add the special tiles**
   - Index 0: Island (fully surrounded by other terrain)
   - Index 15: Solid center tile (fully surrounded by same terrain)

5. **Create variations** (indices 16+)
   - Only needed for center tiles (index 15)
   - Add visual interest: grass patches, rocks, flowers, etc.

### Tools for Creating Tilesets

- **Aseprite**: Excellent for pixel art tilesets
- **Tiled Map Editor**: Use terrain brush to test layouts
- **Template generators**: Search for "marching squares template" online
- Many free marching squares templates available (4-bit pattern)

### Color Palette Tips

For your satellite/RTS view:
- Keep palette limited (Anno 1602 style)
- Use 8-16 pixel effective detail
- High contrast at edges for transitions
- Subtle variations in center tiles

## Testing Without Atlas

The system has a fallback mode! If no texture atlas is assigned:
- ✅ System continues to use vertex colors
- ✅ Original `_get_tile_color()` function still works
- ✅ No errors or crashes

This lets you test other features while creating the atlas.

## Required Tilesets

Based on the current configuration, you need:

**Core Tilesets** (16 tiles each):
1. Beach-to-water transition
2. Grassland-to-beach transition
3. Forest-to-grassland transition
4. Ground-to-grassland transition
5. Highland-to-ground transition
6. Mountain-to-highland transition
7. Marsh-to-water transition

**Simple Tiles** (4 variations each):
8. Deep water
9. Shallow water

**Total**: ~120 transition tiles + ~8 water tiles + ~30 variation tiles = **~158 tiles**

## Performance Notes

✅ **Already optimized:**
- Chunk-based rendering (16x16 tiles per chunk)
- Single draw call per chunk (texture atlas enables batching)
- UV calculations only at mesh generation (not per-frame)
- Pseudo-random variations computed deterministically

✅ **Memory efficient:**
- Single texture atlas shared across all chunks
- No duplicate texture memory
- Variations use same atlas space

## Troubleshooting

**Problem: Tiles appear stretched or incorrect**
- Check that atlas dimensions match ATLAS_TILE_SIZE constant
- Verify texture import settings: Repeat = Disabled, Filter = Nearest

**Problem: Transitions look wrong**
- Verify TERRAIN_PRIORITY values (higher = more dominant)
- Check TERRAIN_TRANSITIONS mappings
- Ensure ATLAS_CONFIG row values match your atlas layout

**Problem: Getting black/missing textures**
- Ensure terrain_atlas property is assigned in Inspector
- Check that atlas texture imported correctly
- Verify atlas dimensions are power-of-2 (2048x2048)

**Problem: Seams between tiles**
- Add 1-2 pixel bleed/padding around each tile in atlas
- Ensure texture filter is set to NEAREST (not LINEAR)

## Next Steps

1. **Create your first tileset**: Start with beach-to-water (you mentioned having this!)
2. **Test with single terrain**: Modify code to show only beach tiles
3. **Add more terrains gradually**: One tileset at a time
4. **Fine-tune transitions**: Adjust TERRAIN_PRIORITY if needed
5. **Add variations**: Create variation tiles for visual interest

## File Modified

- **scripts/tile_grid.gd**:
  - Added terrain configuration (lines ~99-182)
  - Added autotiling functions (lines ~920-1025)
  - Modified chunk mesh generation (lines ~1030-1090)
  - Added UV quad creation (lines ~1095-1140)

## Code is Backwards Compatible

✅ If no atlas assigned → uses vertex colors (original behavior)
✅ All existing functionality preserved
✅ No breaking changes to public API
