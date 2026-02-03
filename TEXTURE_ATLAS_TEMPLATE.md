# Texture Atlas Template

## Specifications

- **Atlas Size**: 2048 × 2048 pixels
- **Tile Size**: 128 × 128 pixels
- **Tiles Per Row**: 16
- **Total Rows**: 16 (but only using 8 for now)
- **Format**: PNG with transparency where needed
- **Filter**: Nearest (for pixel art)

## Atlas Layout (Row by Row)

```
┌────────────────────────────────────────────────────────────────────────┐
│ 2048 pixels wide                                                       │
├────────────────────────────────────────────────────────────────────────┤
│ Row 0 (Y: 0-127)    │ BEACH TILESET                                   │
│                     │ [0][1][2][3][4][5][6][7][8][9][10]...[15][V1][V2][V3]│
├────────────────────────────────────────────────────────────────────────┤
│ Row 1 (Y: 128-255)  │ GRASSLAND TILESET                               │
│                     │ [0][1][2][3][4][5][6][7][8][9][10]...[15][V1][V2][V3][V4][V5]│
├────────────────────────────────────────────────────────────────────────┤
│ Row 2 (Y: 256-383)  │ FOREST TILESET                                  │
│                     │ [0][1][2][3][4][5][6][7][8][9][10]...[15][V1][V2][V3][V4][V5]│
├────────────────────────────────────────────────────────────────────────┤
│ Row 3 (Y: 384-511)  │ GROUND TILESET                                  │
│                     │ [0][1][2][3][4][5][6][7][8][9][10]...[15][V1][V2][V3]│
├────────────────────────────────────────────────────────────────────────┤
│ Row 4 (Y: 512-639)  │ HIGHLAND TILESET                                │
│                     │ [0][1][2][3][4][5][6][7][8][9][10]...[15][V1][V2][V3]│
├────────────────────────────────────────────────────────────────────────┤
│ Row 5 (Y: 640-767)  │ MOUNTAIN TILESET                                │
│                     │ [0][1][2][3][4][5][6][7][8][9][10]...[15][V1][V2][V3]│
├────────────────────────────────────────────────────────────────────────┤
│ Row 6 (Y: 768-895)  │ MARSH TILESET                                   │
│                     │ [0][1][2][3][4][5][6][7][8][9][10]...[15][V1][V2][V3]│
├────────────────────────────────────────────────────────────────────────┤
│ Row 7 (Y: 896-1023) │ WATER TILES (Simple variations)                 │
│                     │ [Shallow1][Shallow2][Deep1][Deep2][...]          │
├────────────────────────────────────────────────────────────────────────┤
│ Rows 8-15           │ RESERVED (Future expansion)                      │
└────────────────────────────────────────────────────────────────────────┘
```

## Detailed Breakdown

### Row 0: Beach (Beach → Water transition)

The beach tileset shows sand transitioning to water (blue).

```
Tiles 0-15: Marching squares autotiles
  [0] = Beach island surrounded by water
  [1] = Beach with water on N, E, S
  [2] = Beach with water on N, E, W
  [3] = Beach SW corner (water on N, E)
  ... (see MARCHING_SQUARES_REFERENCE.md)
  [15] = Solid beach (fully surrounded by beach)

Tiles 16-18: Center variations
  [16] = Beach with shells
  [17] = Beach with small rocks
  [18] = Beach with seaweed/kelp
```

**Visual Style**: Sandy yellow/tan fading to blue water
**Transition target**: Shallow water (blue)

---

### Row 1: Grassland (Grass → Beach transition)

The grassland tileset shows green grass transitioning to beach/sand.

```
Tiles 0-15: Marching squares autotiles
  [0] = Grass island surrounded by beach
  [15] = Solid grass (fully surrounded by grass)

Tiles 16-20: Center variations
  [16] = Grass with flowers
  [17] = Grass with small rocks
  [18] = Darker grass patch
  [19] = Lighter grass patch
  [20] = Grass with dirt patch
```

**Visual Style**: Green grass fading to tan/yellow beach
**Transition target**: Beach (tan/yellow)

---

### Row 2: Forest (Forest → Grass transition)

The forest tileset shows dense trees transitioning to grass.

```
Tiles 0-15: Marching squares autotiles
  [0] = Forest island surrounded by grass
  [15] = Dense forest (fully surrounded by forest)

Tiles 16-20: Center variations
  [16] = Dense trees
  [17] = Trees with clearing
  [18] = Different tree types
  [19] = Trees with undergrowth
  [20] = Sparse trees
```

**Visual Style**: Dark green trees fading to light green grass
**Transition target**: Grassland (light green)

---

### Row 3: Ground (Ground → Grass transition)

The ground tileset shows neutral terrain transitioning to grass.

```
Tiles 0-15: Marching squares autotiles
  [0] = Ground island surrounded by grass
  [15] = Solid ground

Tiles 16-18: Center variations
  [16] = Ground with small rocks
  [17] = Slightly different color
  [18] = Ground with grass tufts
```

**Visual Style**: Brown/gray ground fading to green grass
**Transition target**: Grassland (green)

---

### Row 4: Highland (Highland → Ground transition)

The highland tileset shows elevated rocky terrain transitioning to ground.

```
Tiles 0-15: Marching squares autotiles
  [0] = Highland island
  [15] = Solid highland

Tiles 16-18: Center variations
  [16] = Highland with large rocks
  [17] = Highland different texture
  [18] = Highland with vegetation
```

**Visual Style**: Gray/brown rocky terrain fading to brown ground
**Transition target**: Ground (brown)

---

### Row 5: Mountain (Mountain → Highland transition)

The mountain tileset shows peaks transitioning to highlands.

```
Tiles 0-15: Marching squares autotiles
  [0] = Mountain peak island
  [15] = Solid mountain

Tiles 16-18: Center variations
  [16] = Mountain with snow
  [17] = Different rock pattern
  [18] = Mountain with shadows
```

**Visual Style**: Light gray/white peaks fading to gray highlands
**Transition target**: Highland (gray)

---

### Row 6: Marsh (Marsh → Water transition)

The marsh tileset shows wetlands transitioning to water.

```
Tiles 0-15: Marching squares autotiles
  [0] = Marsh island in water
  [15] = Solid marsh

Tiles 16-18: Center variations
  [16] = Marsh with reeds
  [17] = Darker marsh
  [18] = Marsh with lily pads
```

**Visual Style**: Dark green/brown marsh fading to blue water
**Transition target**: Shallow water (blue)

---

### Row 7: Water (Simple variations, no transitions)

Water doesn't use marching squares. Just simple tile variations.

```
Tiles 0-7: Water variations
  [0] = Shallow water variation 1
  [1] = Shallow water variation 2
  [2] = Deep water variation 1
  [3] = Deep water variation 2
  [4-7] = Additional water variations (optional)
```

**Visual Style**:
- Shallow: Medium blue
- Deep: Dark blue/navy
**Transition**: None (water is always solid)

---

## Creating the Atlas

### Option 1: Manual Assembly (Recommended for learning)

1. Create each tileset separately (16 tiles per set)
2. Export each as separate PNG
3. Use image editing software to assemble:
   - Create 2048×2048 canvas
   - Paste each tileset at correct Y position
   - Export as single PNG

### Option 2: Use Tileset Tools

Tools like **Tilesetter** or **Aseprite** can help:
- Create tiles in grid layout
- Auto-export to atlas format
- Preview how tiles connect

### Option 3: Start with Placeholders

1. Fill atlas with solid colors:
   - Row 0: Sandy yellow (#D4C4A8)
   - Row 1: Grass green (#8BC34A)
   - Row 2: Forest dark green (#2E7D32)
   - etc.

2. Test that system works with colors

3. Replace with actual pixel art gradually

---

## Pro Tips for Atlas Creation

### Padding/Bleeding
Add 1-2 pixel borders around each tile that repeat the edge pixels. This prevents seams when GPU samples between tiles.

```
Without padding:          With 1px padding:
┌────┬────┬────┐         ┌─────┬─────┬─────┐
│ T0 │ T1 │ T2 │         │ T0  │ T1  │ T2  │
├────┼────┼────┤   →     ├─────┼─────┼─────┤
│ T3 │ T4 │ T5 │         │ T3  │ T4  │ T5  │
└────┴────┴────┘         └─────┴─────┴─────┘
    (128×128)                (130×130)

Edge pixels duplicated outward
```

**If using padding**, adjust constants:
```gdscript
const ATLAS_TILE_SIZE := 130  # Instead of 128
```

### Pixel Art Style

For satellite RTS view:
- **Effective detail**: 8-16 pixels (since viewing from far)
- **Color palette**: 8-16 colors per terrain type
- **Contrast**: High contrast at transition edges
- **Dithering**: Optional, can add texture

### Testing Individual Tilesets

Temporarily modify code to test one tileset:
```gdscript
# In _get_tile_color(), override all terrain to beach for testing:
func _get_tile_color(tile: Dictionary) -> Color:
    return Color(0.8, 0.75, 0.6)  # Beach color for all tiles
```

Then all tiles will use beach tileset, letting you verify it works.

---

## Godot Import Settings

After importing your atlas PNG:

1. Select the texture in Godot FileSystem
2. In Import tab, configure:
   - **Compress**: VRAM Uncompressed (or Lossless for smaller files)
   - **Mipmaps**: Disabled (optional: enabled for better distance quality)
   - **Filter**: Nearest (CRITICAL for pixel art!)
   - **Repeat**: Disabled
3. Click "Reimport"

---

## Example: Starting with Beach Tileset

You mentioned having a grass-to-ocean tileset prepared. If it's beach-to-water:

1. Place your 16 tiles in Row 0 (Y: 0-127)
2. Fill rest of atlas with placeholder colors
3. Assign atlas to TileGrid in Inspector
4. Test! Beach tiles should now use your textures

If transitions look backward:
- Check that beach texture is "inside" and water is "outside"
- Remember: 1 = same terrain (solid), 0 = other terrain (transition)

---

## Checklist

- [ ] Created 2048×2048 PNG canvas
- [ ] Added Beach tileset (row 0)
- [ ] Added Grassland tileset (row 1)
- [ ] Added Forest tileset (row 2)
- [ ] Added Ground tileset (row 3)
- [ ] Added Highland tileset (row 4)
- [ ] Added Mountain tileset (row 5)
- [ ] Added Marsh tileset (row 6)
- [ ] Added Water variations (row 7)
- [ ] Imported with correct settings (Nearest filter)
- [ ] Assigned to TileGrid terrain_atlas property
- [ ] Tested in-game

---

## Quick Start: Minimal Working Atlas

If you want to test quickly, create a minimal 2048×256 atlas (just row 0) with beach tiles, then fill rest with a solid color. System will use beach tiles for beach, and fallback color for other terrains.

**Fastest test**:
1. Create your beach tileset only (16 tiles × 128px = 2048px wide, 128px tall)
2. Extend canvas to 2048×2048 with solid colors below
3. Import and assign
4. See beach transitions working while other terrains use placeholders

Good luck! 🎨
