# Texture Atlas Template

## Specifications

- **Atlas Size**: 256 × 256 pixels
- **Tile Size**: 16 × 16 pixels
- **Tiles Per Row**: 16
- **Total Rows**: 16 (using 10 for terrain + masks)
- **Format**: PNG with transparency where needed
- **Filter**: Nearest (for pixel art)

## Atlas Layout (Row by Row)

```
┌────────────────────────────────────────────────────────────────────────┐
│ 256 pixels wide                                                        │
├────────────────────────────────────────────────────────────────────────┤
│ Row 0 (Y: 0-15)     │ DEEP WATER VARIATIONS (16 tiles)                │
├────────────────────────────────────────────────────────────────────────┤
│ Row 1 (Y: 16-31)    │ SHALLOW WATER VARIATIONS (16 tiles)             │
├────────────────────────────────────────────────────────────────────────┤
│ Row 2 (Y: 32-47)    │ BEACH VARIATIONS (16 tiles)                     │
├────────────────────────────────────────────────────────────────────────┤
│ Row 3 (Y: 48-63)    │ MARSH VARIATIONS (16 tiles)                     │
├────────────────────────────────────────────────────────────────────────┤
│ Row 4 (Y: 64-79)    │ GRASSLAND/LOWLAND VARIATIONS (16 tiles)          │
├────────────────────────────────────────────────────────────────────────┤
│ Row 5 (Y: 80-95)    │ FOREST VARIATIONS (16 tiles)                    │
├────────────────────────────────────────────────────────────────────────┤
│ Row 6 (Y: 96-111)   │ GROUND VARIATIONS (16 tiles)                    │
├────────────────────────────────────────────────────────────────────────┤
│ Row 7 (Y: 112-127)  │ HIGHLAND VARIATIONS (16 tiles)                  │
├────────────────────────────────────────────────────────────────────────┤
│ Row 8 (Y: 128-143)  │ MOUNTAIN VARIATIONS (16 tiles)                  │
├────────────────────────────────────────────────────────────────────────┤
│ Row 9 (Y: 144-159)  │ ALPHA MASKS (16 marching squares masks)          │
├────────────────────────────────────────────────────────────────────────┤
│ Rows 10-15          │ RESERVED (Future expansion)                      │
└────────────────────────────────────────────────────────────────────────┘
```

## Detailed Breakdown

### Terrain Variation Rows

Each terrain row contains 16 solid variations (indices 0-15). These are sampled for:

- Base terrain (UV)
- Transition terrain (UV2)

Because transitions now use alpha masks, you do **not** need to pre-bake
edge tiles for each terrain.

### Alpha Mask Row

Row 9 contains 16 alpha masks (indices 0-15) that match the marching squares
bitmask order. The shader uses these masks to blend between UV (base) and UV2
(transition).

### Mask Tile Order

See `MARCHING_SQUARES_REFERENCE.md` for the exact mask order.

---

## Creating the Atlas

### Option 1: Manual Assembly (Recommended for learning)

1. Create each tileset separately (16 tiles per set)
2. Export each as separate PNG
3. Use image editing software to assemble:
   - Create 256×256 canvas
   - Paste each tileset at correct Y position
   - Export as single PNG

### Option 2: Use Tileset Tools

Tools like **Tilesetter** or **Aseprite** can help:
- Create tiles in grid layout
- Auto-export to atlas format
- Preview how tiles connect

### Option 3: Start with Placeholders

1. Fill atlas with solid colors:
   - Row 0: Deep water blue (#1B2B52)
   - Row 1: Shallow water blue (#2E5E8B)
   - Row 2: Beach sand (#D4C4A8)
   - Row 3: Marsh green (#4E5C3A)
   - Row 4: Grass green (#8BC34A)
   - Row 5: Forest dark green (#2E7D32)
   - Row 6: Ground brown (#8A6D4A)
   - Row 7: Highland gray (#8E8E8E)
   - Row 8: Mountain light gray (#B0B0B0)
   - Row 9: Alpha masks (grayscale)

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
    (16×16)                  (18×18)

Edge pixels duplicated outward
```

**If using padding**, adjust constants:
```gdscript
const ATLAS_TILE_SIZE := 18  # Instead of 16
```

### Pixel Art Style

For satellite RTS view:
- **Effective detail**: 8-16 pixels (since viewing from far)
- **Color palette**: 8-16 colors per terrain type
- **Contrast**: High contrast between variations
- **Dithering**: Optional, can add texture

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

## Checklist

- [ ] Created 256×256 PNG canvas
- [ ] Added Deep water variations (row 0)
- [ ] Added Shallow water variations (row 1)
- [ ] Added Beach variations (row 2)
- [ ] Added Marsh variations (row 3)
- [ ] Added Grassland/Lowland variations (row 4)
- [ ] Added Forest variations (row 5)
- [ ] Added Ground variations (row 6)
- [ ] Added Highland variations (row 7)
- [ ] Added Mountain variations (row 8)
- [ ] Added Alpha masks (row 9)
- [ ] Imported with correct settings (Nearest filter)
- [ ] Assigned to TileGrid terrain_atlas property
- [ ] Tested in-game

---

## Quick Start: Minimal Working Atlas

If you want to test quickly, create a minimal 256×256 atlas with just a few
variation rows and a mask row. Fill the unused rows with a solid color so the
shader still samples valid pixels.

**Fastest test**:
1. Create deep water (row 0) and shallow water (row 1) variations
2. Create the 16 alpha masks in row 9
3. Fill the remaining rows with placeholder colors
4. Import, assign, and verify water blending in-game

Good luck! 🎨
