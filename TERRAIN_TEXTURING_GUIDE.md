# Terrain Texturing Implementation Guide

## Overview

The marching squares autotiling system in `scripts/tile_grid.gd` now uses alpha mask blending to create terrain transitions. Each tile renders two terrain layers (base + transition) and blends them using a mask row in the atlas.

## What Was Implemented

### 1. Configuration Constants (lines ~99-182)

**TERRAIN_PRIORITY**: Defines the dominance hierarchy
- Water types are most dominant (100, 90)
- Beach/Marsh in the middle (80, 70)
- Land types decrease in priority (60 → 20)

**ATLAS_CONFIG**: Defines texture atlas layout
- Each terrain assigned a row in the atlas
- Each row contains 16 solid variations (no baked transitions)
- Alpha masks live in a dedicated mask row

### 2. Autotiling Functions

**`_get_autotile_index(pos: Vector2i) -> int`**
- Core marching squares algorithm
- Checks the 4 tile corners via the corner grid
- Returns bitmask 0-15 indicating which neighbors to transition to

**`_get_terrain_variation(pos: Vector2i, tile_type: String) -> int`**
- Position-based pseudo-random variation selection
- Ensures consistency (same tile always gets same variation)
- Returns 0-15 for the terrain row

**`_get_transition_terrain(pos: Vector2i, base_type: String) -> String`**
- Finds the highest-priority neighbor in the corner grid
- Used as the transition layer for alpha blending

**`_get_tile_layer_data(pos: Vector2i) -> Dictionary`**
- Returns base UVs, transition UVs, and mask index
- Coordinates are [top_left, top_right, bottom_right, bottom_left]

**`_calculate_uv_for_tile(tile_index: int, atlas_row: int) -> Array`**
- Converts tile index and atlas row to UV coordinates
- Handles atlas layout calculation

### 3. Rendering Updates

**`_create_chunk_mesh(chunk: Vector2i)`** - Modified
- Uses a ShaderMaterial for alpha blending when `terrain_atlas` is assigned
- Falls back to vertex colors if atlas is missing

**`_add_quad_with_layers(st: SurfaceTool, pos: Vector3, base_uv: Array, transition_uv: Array, mask_index: int)`**
- Adds quad geometry with UV, UV2, and per-vertex mask index
- Encodes mask index in vertex color for the shader

**`_add_quad_with_color(st: SurfaceTool, pos: Vector3, color: Color)`** - Renamed
- Original color-based quad creation (for fallback)

## How to Use

### Step 1: Create Your Texture Atlas

Create a texture atlas with the following specifications:

**Atlas Dimensions**: 256 x 256 pixels (16 x 16 tiles at 16px each)

**Layout** (each row is 16px tall):
```
Row 0:  Deep water variations (16 tiles)
Row 1:  Shallow water variations (16 tiles)
Row 2:  Beach variations (16 tiles)
Row 3:  Marsh variations (16 tiles)
Row 4:  Grassland/Lowland variations (16 tiles)
Row 5:  Forest variations (16 tiles)
Row 6:  Ground variations (16 tiles)
Row 7:  Highland variations (16 tiles)
Row 8:  Mountain variations (16 tiles)
Row 9:  Alpha mask tiles for marching squares (16 tiles)
```

**Marching Squares Mask Tile Order** (indices 0-15):
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
        "row": 2,              # Which row in atlas
        "variations": 16       # How many solid variations
    },
    # ... etc
}
```

**Modify atlas size** (around line 173):
```gdscript
const ATLAS_TILE_SIZE := 16  # Pixels per tile
const ATLAS_TILES_PER_ROW := 16  # Tiles per row
const MASK_ROW := 9
```

## How the Priority System Works

**Example: Grass → Beach → Water**

1. **Deep water tile:**
   - Priority: 100 (highest)
   - No higher-priority neighbors, so mask index is 15
   - Uses deep water variation tiles

2. **Beach tile next to water:**
   - Priority: 80
   - Detects higher-priority shallow/deep water at corners
   - Uses beach variations as the base layer
   - Uses water variations as the transition layer
   - Mask index selects which alpha mask tile to blend

3. **Grass tile next to beach:**
   - Priority: 60
   - Detects beach as the highest-priority neighbor
   - Blends grass variations over beach variations using the mask row

## Tileset Creation Tips

### Creating Alpha Masks

1. **Create 16 mask tiles** (indices 0-15)
   - White = base terrain visible
   - Black = transition terrain visible
2. **Keep masks crisp**
   - With pixel art, sharp edges are acceptable
3. **Re-use the same masks for every terrain**
   - Only the solid variation rows are terrain-specific

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
