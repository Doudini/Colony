# Marching Squares Tile Reference

## Visual Guide for Creating Your 16-Tile Autotile Set

Each tile shows where **solid terrain** (your base texture) should be, and where **transitions** (to other terrain) should occur.

```
Legend:
█ = Solid terrain (e.g., grass)
░ = Transition edge (e.g., grass fading to beach)
· = Other terrain (e.g., beach/water)
```

## The 16 Tiles (0-15)

```
Index 0 (0000)          Index 1 (0001)          Index 2 (0010)          Index 3 (0011)
North: Other            North: Other            North: Other            North: Other
East:  Other            East:  Other            East:  Other            East:  Other
South: Other            South: Other            South: Same             South: Same
West:  Other            West:  Same             West:  Other            West:  Same

· · · · · · · ·         · · · · · · · ·         · · · · · · · ·         · · · · · · · ·
· · · · · · · ·         · · · · · · · ·         · · · · · · · ·         · · · · · · · ·
· · ░ ░ ░ ░ · ·         · · ░ ░ ░ ░ · ·         · ░ ░ ░ ░ ░ ░ ·         · ░ ░ ░ ░ ░ ░ ·
· ░ ░ █ █ ░ ░ ·         · ░ █ █ █ █ ░ ·         ░ ░ █ █ █ █ ░ ░         ░ █ █ █ █ █ █ ·
· ░ █ █ █ █ ░ ·         · ░ █ █ █ █ ░ ·         ░ █ █ █ █ █ █ ░         ░ █ █ █ █ █ █ ·
· ░ ░ █ █ ░ ░ ·         · ░ █ █ █ █ ░ ·         ░ █ █ █ █ █ █ ░         ░ █ █ █ █ █ █ ·
· · ░ ░ ░ ░ · ·         · ░ █ █ █ █ █ █         ░ █ █ █ █ █ █ ░         ░ █ █ █ █ █ █ █
· · · · · · · ·         · ░ █ █ █ █ █ █         ░ ░ █ █ █ █ ░ ░         ░ █ █ █ █ █ █ █

(Island)                (West edge)             (South edge)            (SW corner)


Index 4 (0100)          Index 5 (0101)          Index 6 (0110)          Index 7 (0111)
North: Other            North: Other            North: Other            North: Other
East:  Same             East:  Same             East:  Same             East:  Same
South: Other            South: Other            South: Same             South: Same
West:  Other            West:  Same             West:  Other            West:  Same

· · · · · · · ·         · · · · · · · ·         · · · · · · · ·         · · · · · · · ·
· · · · · · · ·         · · · · · · · ·         · · · · · · · ·         · · · · · · · ·
· · ░ ░ ░ ░ · ·         · · ░ ░ ░ ░ · ·         · ░ ░ ░ ░ ░ · ·         · ░ ░ ░ ░ ░ · ·
· ░ ░ █ █ ░ ░ ·         · ░ █ █ █ █ · ·         ░ ░ █ █ █ █ · ·         ░ █ █ █ █ █ · ·
· ░ █ █ █ █ ░ ·         · ░ █ █ █ █ · ·         ░ █ █ █ █ █ · ·         ░ █ █ █ █ █ · ·
· ░ ░ █ █ ░ ░ ·         · ░ █ █ █ █ · ·         ░ █ █ █ █ █ · ·         ░ █ █ █ █ █ · ·
· · ░ ░ ░ ░ · ·         · ░ █ █ █ █ · ·         ░ █ █ █ █ █ █ █         ░ █ █ █ █ █ █ █
· · · · · · · ·         · ░ █ █ █ █ · ·         ░ ░ █ █ █ █ █ █         ░ █ █ █ █ █ █ █

(East edge)             (E-W edges)             (SE corner)             (S-E-W edges)


Index 8 (1000)          Index 9 (1001)          Index 10 (1010)         Index 11 (1011)
North: Same             North: Same             North: Same             North: Same
East:  Other            East:  Other            East:  Other            East:  Other
South: Other            South: Other            South: Same             South: Same
West:  Other            West:  Same             West:  Other            West:  Same

█ █ █ █ ░ · ·           █ █ █ █ ░ · ·           █ █ █ █ ░ ░ ·           █ █ █ █ ░ · ·
█ █ █ █ ░ · ·           █ █ █ █ ░ · ·           █ █ █ █ █ ░ ░           █ █ █ █ ░ · ·
░ ░ █ █ ░ ░ · ·         ░ █ █ █ ░ · ·           ░ █ █ █ █ █ ░           ░ █ █ █ ░ · ·
· ░ ░ █ █ ░ ░ ·         · ░ █ █ ░ · ·           ░ █ █ █ █ █ ░           ░ █ █ █ █ · ·
· ░ █ █ █ █ ░ ·         · ░ █ █ ░ · ·           ░ █ █ █ █ █ ░           ░ █ █ █ █ · ·
· ░ ░ █ █ ░ ░ ·         · ░ █ █ █ ░ ·           ░ █ █ █ █ █ ░           ░ █ █ █ █ · ·
· · ░ ░ ░ ░ · ·         · ░ █ █ █ █ ░ ·         ░ ░ █ █ █ ░ ░           ░ █ █ █ █ █ █
· · · · · · · ·         · ░ █ █ █ █ █ █         · ░ ░ █ █ ░ ░           ░ █ █ █ █ █ █

(North edge)            (NW corner)             (N-S edges)             (N-S-W edges)


Index 12 (1100)         Index 13 (1101)         Index 14 (1110)         Index 15 (1111)
North: Same             North: Same             North: Same             North: Same
East:  Same             East:  Same             East:  Same             East:  Same
South: Other            South: Other            South: Same             South: Same
West:  Other            West:  Same             West:  Other            West:  Same

█ █ ░ · · · · ·         █ █ ░ · · · · ·         █ █ █ █ █ ░ ░           █ █ █ █ █ █ █
█ █ ░ · · · · ·         █ █ ░ · · · · ·         █ █ █ █ █ █ ░           █ █ █ █ █ █ █
░ ░ ░ · · · · ·         ░ █ █ · · · · ·         ░ █ █ █ █ █ ░           █ █ █ █ █ █ █
· ░ ░ █ █ · ·           · ░ █ █ █ · ·           ░ █ █ █ █ █ ░           █ █ █ █ █ █ █
· ░ █ █ █ █ · ·         · ░ █ █ █ █ · ·         ░ █ █ █ █ █ █ █         █ █ █ █ █ █ █
· ░ ░ █ █ · ·           · ░ █ █ █ █ · ·         ░ ░ █ █ █ █ █ █         █ █ █ █ █ █ █
· · ░ ░ ░ ░ · ·         · ░ █ █ █ █ · ·         · ░ ░ █ █ █ █ █         █ █ █ █ █ █ █
· · · · · · · ·         · ░ █ █ █ █ · ·         · · ░ ░ ░ ░ █ █         █ █ █ █ █ █ █

(NE corner)             (N-E-W edges)           (N-E-S edges)           (Solid/Center)
```

## Understanding the Pattern

### Bit Encoding
Each tile index is a 4-bit number:
- **Bit 3 (8)**: North neighbor same? (1=yes, 0=no)
- **Bit 2 (4)**: East neighbor same? (1=yes, 0=no)
- **Bit 1 (2)**: South neighbor same? (1=yes, 0=no)
- **Bit 0 (1)**: West neighbor same? (1=yes, 0=no)

### Examples
- **Index 0 (0000)**: No matching neighbors → Island
- **Index 3 (0011)**: South and West match → SW corner
- **Index 15 (1111)**: All neighbors match → Solid center
- **Index 5 (0101)**: East and West match → Horizontal strip

## Practical Tileset Creation Workflow

### Phase 1: Create Corner Pieces (Most Important!)
Start with indices: **3, 6, 9, 12**
- These define your transition curves
- Get these right and everything else flows

### Phase 2: Create Edge Pieces
Create indices: **1, 2, 4, 8**
- Should connect seamlessly to corners
- Test by placing them adjacent to corners

### Phase 3: Create Multi-Edge Pieces
Create indices: **5, 7, 10, 11, 13, 14**
- Combine edge patterns from Phase 2
- Index 5 = combine indices 1 and 4
- Index 7 = combine indices 1, 2, and 4
- etc.

### Phase 4: Create Special Pieces
- **Index 0**: Island (standalone blob)
- **Index 15**: Solid center (this is where variations go!)

### Phase 5: Create Variations
- Create 3-5 alternative versions of index 15
- Add visual interest: patches, details, etc.
- These go in tiles 16, 17, 18... in your atlas

## Tileset Examples by Terrain

### Beach Tileset
```
Center (15): Sandy texture
Edges: Sand fading to water (blue)
Corners: Curved beach shorelines
Variations: Shells, rocks, seaweed patches
```

### Grassland Tileset
```
Center (15): Green grass
Edges: Grass fading to beach (tan/yellow)
Corners: Curved grass-to-beach transitions
Variations: Flowers, rocks, dirt patches, darker/lighter grass
```

### Forest Tileset
```
Center (15): Dense trees
Edges: Trees fading to grass (lighter green)
Corners: Tree line curves
Variations: Different tree densities, clearings
```

### Mountain Tileset
```
Center (15): Rocky peaks
Edges: Rocks fading to highlands (brown)
Corners: Mountain ridges
Variations: Snow caps, different rock patterns
```

## Common Mistakes to Avoid

❌ **Don't** make transitions too sharp (use gradients)
❌ **Don't** forget to make corners smooth curves
❌ **Don't** make tile 0 (island) too large (should be smaller blob)
❌ **Don't** make all variations too different (maintain cohesion)

✅ **Do** test corners by placing 4 tiles in a 2x2 grid
✅ **Do** use consistent transition width across all tiles
✅ **Do** add 1-2 pixel padding to avoid seams
✅ **Do** keep style consistent within a tileset

## Testing Your Tileset

1. **Corner test**: Place tiles 3, 6, 9, 12 in a grid
2. **Edge test**: Place tiles 1, 2, 4, 8 around tile 15
3. **Strip test**: Place tile 5 (or 10) repeatedly in a line
4. **Random test**: Place tiles randomly to check all combinations

## Atlas Layout Example

For your 2048×2048 atlas (16 tiles × 128px per row):

```
Row 0 (Beach):
[0][1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16][17][18]...
 ↑                                                  ↑   ↑   ↑   ↑
 Island                                          Center Variations

Row 1 (Grassland):
[0][1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16][17][18][19][20]...
 ↑                                                  ↑   ↑   ↑   ↑   ↑   ↑
 Island                                          Center    Variations

... (continue for each terrain)
```

## Quick Reference: Tile Index Calculator

To find which tile to use manually:
1. Check North neighbor: Same terrain? Add 8
2. Check East neighbor: Same terrain? Add 4
3. Check South neighbor: Same terrain? Add 2
4. Check West neighbor: Same terrain? Add 1
5. Sum = tile index (0-15)

Example: Tile with matching neighbors to North and West only:
- North same: +8
- East different: +0
- South different: +0
- West same: +1
- **Index = 9** (NW corner)

---

## Resources

- Search online for "marching squares template 16 tiles"
- Look at Age of Empires or Anno 1602 tilesets for inspiration
- Use Tiled Map Editor's terrain brush to test
- Aseprite has autotile preview features

Good luck with your tileset creation! Start with beach-to-water since you already have that prepared. 🏖️🌊
