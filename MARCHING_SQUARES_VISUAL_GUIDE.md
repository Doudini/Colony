# Marching Squares Visual Guide - Beach to Water Example

## Understanding the Bits

Think of it this way:
- **1 = SAME TERRAIN** (keep the solid texture - BEACH in our example)
- **0 = DIFFERENT TERRAIN** (transition to other terrain - WATER in our example)

## Visual Reference - Beach to Water Tileset

In this example:
- 🟨 = Beach (sand) - your base terrain
- 🟦 = Water (ocean) - what you're transitioning to
- 🌊 = Transition zone (sand fading to water)

---

## The 16 Tiles Explained

### Index 0: `0000` - Island
**N=0, E=0, S=0, W=0** - All neighbors are WATER

```
       WATER
         ↓
   🟦🟦🟦🟦🟦🟦🟦
   🟦🌊🌊🌊🌊🌊🟦
WATER→🟦🌊🟨🟨🌊🟦←WATER
   🟦🌊🟨🟨🌊🟦
   🟦🌊🌊🌊🌊🌊🟦
   🟦🟦🟦🟦🟦🟦🟦
       ↑
      WATER
```
A small beach island completely surrounded by water.
All edges fade from beach to water in all directions.

---

### Index 1: `0001` - West Edge Solid
**N=0, E=0, S=0, W=1** - West neighbor is BEACH, others are WATER

```
       WATER
         ↓
   🟦🟦🟦🟦🟦🟦🟦
   🟦🌊🌊🌊🌊🌊🟦
BEACH→🟨🟨🟨🟨🌊🟦←WATER
   🟨🟨🟨🟨🌊🟦
   🟦🌊🌊🌊🌊🌊🟦
   🟦🟦🟦🟦🟦🟦🟦
       ↑
      WATER
```
West edge is solid beach (connecting to more beach).
North, East, South edges fade to water.

---

### Index 2: `0010` - South Edge Solid
**N=0, E=0, S=1, W=0** - South neighbor is BEACH, others are WATER

```
       WATER
         ↓
   🟦🟦🟦🟦🟦🟦🟦
   🟦🌊🌊🌊🌊🌊🟦
WATER→🟦🌊🟨🟨🌊🟦←WATER
   🟦🌊🟨🟨🌊🟦
   🟦🌊🟨🟨🌊🟦
   🟦🌊🟨🟨🌊🟦
       ↑
      BEACH
```
South edge is solid beach (connecting to more beach).
North, East, West edges fade to water.

---

### Index 3: `0011` - Southwest Corner (L-Shape)
**N=0, E=0, S=1, W=1** - South and West neighbors are BEACH

```
       WATER
         ↓
   🟦🟦🟦🟦🟦🟦🟦
   🟦🌊🌊🌊🌊🌊🟦
BEACH→🟨🟨🟨🟨🌊🟦←WATER
   🟨🟨🟨🟨🌊🟦
   🟨🟨🟨🟨🌊🟦
   🟨🟨🟨🟨🌊🟦
       ↑
      BEACH
```
Southwest corner piece. Solid beach on West and South edges.
Only North and East edges fade to water.
Makes an "L" shape of beach in the SW corner.

---

### Index 4: `0100` - East Edge Solid
**N=0, E=1, S=0, W=0** - East neighbor is BEACH

```
       WATER
         ↓
   🟦🟦🟦🟦🟦🟦🟦
   🟦🌊🌊🌊🌊🌊🟦
WATER→🟦🌊🟨🟨🟨🟨←BEACH
   🟦🌊🟨🟨🟨🟨
   🟦🌊🌊🌊🌊🌊🟦
   🟦🟦🟦🟦🟦🟦🟦
       ↑
      WATER
```
East edge is solid beach.
North, South, West edges fade to water.

---

### Index 5: `0101` - East and West Edges Solid (Horizontal Strip)
**N=0, E=1, S=0, W=1** - East and West neighbors are BEACH

```
       WATER
         ↓
   🟦🟦🟦🟦🟦🟦🟦
   🟦🌊🌊🌊🌊🌊🟦
BEACH→🟨🟨🟨🟨🟨🟨←BEACH
   🟨🟨🟨🟨🟨🟨
   🟦🌊🌊🌊🌊🌊🟦
   🟦🟦🟦🟦🟦🟦🟦
       ↑
      WATER
```
Horizontal strip of beach.
Solid beach on East and West edges.
Only North and South edges fade to water.

---

### Index 6: `0110` - Southeast Corner (L-Shape)
**N=0, E=1, S=1, W=0** - South and East neighbors are BEACH

```
       WATER
         ↓
   🟦🟦🟦🟦🟦🟦🟦
   🟦🌊🌊🌊🌊🌊🟦
WATER→🟦🌊🟨🟨🟨🟨←BEACH
   🟦🌊🟨🟨🟨🟨
   🟦🌊🟨🟨🟨🟨
   🟦🌊🟨🟨🟨🟨
       ↑
      BEACH
```
Southeast corner piece.
Solid beach on South and East edges.
Only North and West edges fade to water.

---

### Index 7: `0111` - South, East, West Edges Solid (U-Shape Open North)
**N=0, E=1, S=1, W=1** - All neighbors are BEACH except North

```
       WATER
         ↓
   🟦🟦🟦🟦🟦🟦🟦
   🟦🌊🌊🌊🌊🌊🟦
BEACH→🟨🟨🟨🟨🟨🟨←BEACH
   🟨🟨🟨🟨🟨🟨
   🟨🟨🟨🟨🟨🟨
   🟨🟨🟨🟨🟨🟨
       ↑
      BEACH
```
U-shape with opening to the North.
Solid beach on South, East, West edges.
Only North edge fades to water.

---

### Index 8: `1000` - North Edge Solid
**N=1, E=0, S=0, W=0** - North neighbor is BEACH

```
       BEACH
         ↓
   🟨🟨🟨🟨🟨🟨🟨
   🟦🌊🟨🟨🌊🟦
WATER→🟦🌊🟨🟨🌊🟦←WATER
   🟦🌊🟨🟨🌊🟦
   🟦🌊🌊🌊🌊🌊🟦
   🟦🟦🟦🟦🟦🟦🟦
       ↑
      WATER
```
North edge is solid beach.
East, South, West edges fade to water.

---

### Index 9: `1001` - Northwest Corner (L-Shape)
**N=1, E=0, S=0, W=1** - North and West neighbors are BEACH

```
       BEACH
         ↓
   🟨🟨🟨🟨🟨🟨🟨
   🟨🟨🟨🟨🌊🟦
BEACH→🟨🟨🟨🟨🌊🟦←WATER
   🟨🟨🟨🟨🌊🟦
   🟦🌊🌊🌊🌊🌊🟦
   🟦🟦🟦🟦🟦🟦🟦
       ↑
      WATER
```
Northwest corner piece.
Solid beach on North and West edges.
Only East and South edges fade to water.

---

### Index 10: `1010` - North and South Edges Solid (Vertical Strip)
**N=1, E=0, S=1, W=0** - North and South neighbors are BEACH

```
       BEACH
         ↓
   🟨🟨🟨🟨🟨🟨🟨
   🟦🌊🟨🟨🌊🟦
WATER→🟦🌊🟨🟨🌊🟦←WATER
   🟦🌊🟨🟨🌊🟦
   🟦🌊🟨🟨🌊🟦
   🟦🌊🟨🟨🌊🟦
       ↑
      BEACH
```
Vertical strip of beach.
Solid beach on North and South edges.
Only East and West edges fade to water.

---

### Index 11: `1011` - North, South, West Edges Solid (U-Shape Open East)
**N=1, E=0, S=1, W=1** - All neighbors are BEACH except East

```
       BEACH
         ↓
   🟨🟨🟨🟨🟨🟨🟨
   🟨🟨🟨🟨🌊🟦
BEACH→🟨🟨🟨🟨🌊🟦←WATER
   🟨🟨🟨🟨🌊🟦
   🟨🟨🟨🟨🌊🟦
   🟨🟨🟨🟨🌊🟦
       ↑
      BEACH
```
U-shape with opening to the East.
Solid beach on North, South, West edges.
Only East edge fades to water.

---

### Index 12: `1100` - Northeast Corner (L-Shape)
**N=1, E=1, S=0, W=0** - North and East neighbors are BEACH

```
       BEACH
         ↓
   🟨🟨🟨🟨🟨🟨🟨
   🟦🌊🟨🟨🟨🟨
WATER→🟦🌊🟨🟨🟨🟨←BEACH
   🟦🌊🟨🟨🟨🟨
   🟦🌊🌊🌊🌊🌊🟦
   🟦🟦🟦🟦🟦🟦🟦
       ↑
      WATER
```
Northeast corner piece.
Solid beach on North and East edges.
Only South and West edges fade to water.

---

### Index 13: `1101` - North, East, West Edges Solid (U-Shape Open South)
**N=1, E=1, S=0, W=1** - All neighbors are BEACH except South

```
       BEACH
         ↓
   🟨🟨🟨🟨🟨🟨🟨
   🟨🟨🟨🟨🟨🟨
BEACH→🟨🟨🟨🟨🟨🟨←BEACH
   🟨🟨🟨🟨🟨🟨
   🟦🌊🌊🌊🌊🌊🟦
   🟦🟦🟦🟦🟦🟦🟦
       ↑
      WATER
```
U-shape with opening to the South.
Solid beach on North, East, West edges.
Only South edge fades to water.

---

### Index 14: `1110` - North, East, South Edges Solid (U-Shape Open West)
**N=1, E=1, S=1, W=0** - All neighbors are BEACH except West

```
       BEACH
         ↓
   🟨🟨🟨🟨🟨🟨🟨
   🟦🌊🟨🟨🟨🟨
WATER→🟦🌊🟨🟨🟨🟨←BEACH
   🟦🌊🟨🟨🟨🟨
   🟦🌊🟨🟨🟨🟨
   🟦🌊🟨🟨🟨🟨
       ↑
      BEACH
```
U-shape with opening to the West.
Solid beach on North, East, South edges.
Only West edge fades to water.

---

### Index 15: `1111` - Fully Surrounded (Solid Center)
**N=1, E=1, S=1, W=1** - All neighbors are BEACH

```
       BEACH
         ↓
   🟨🟨🟨🟨🟨🟨🟨
   🟨🟨🟨🟨🟨🟨
BEACH→🟨🟨🟨🟨🟨🟨←BEACH
   🟨🟨🟨🟨🟨🟨
   🟨🟨🟨🟨🟨🟨
   🟨🟨🟨🟨🟨🟨
       ↑
      BEACH
```
Completely solid beach tile.
All neighbors are beach, so no transitions needed.
This is where you add variations (shells, rocks, etc.)

---

## How to Remember the Pattern

### Quick Mental Model:

1. **Look at the 4-bit code**: `N E S W`
2. **For each bit:**
   - **1 = Solid edge** (connects to same terrain)
   - **0 = Transition edge** (fades to other terrain)

### Examples:
- `0000` = All edges transition → Island
- `1111` = All edges solid → Center tile
- `0011` = South and West solid → SW corner
- `1100` = North and East solid → NE corner
- `1010` = North and South solid → Vertical strip

---

## Practical Example: Building a Beach Peninsula

Let's say you have this layout:

```
     W W W W W      W = Water
     W B B B W      B = Beach
     W B B W W
     W B W W W
     W W W W W
```

The middle beach tiles would use:
```
     W W W W W
     W[7][5][7]W    [7] = 0111 (beach surrounded by beach on S,E,W)
     W[11][6]W W    [5] = 0101 (beach surrounded by beach on E,W)
     W[1]W W W      [11]= 1011 (beach surrounded by beach on N,S,W)
     W W W W W      [6] = 0110 (beach surrounded by beach on S,E)
                    [1] = 0001 (beach surrounded by beach on W)
```

---

## Creating Your Tileset - Step by Step

1. **Start with the 4 corners** (easiest to understand):
   - Index 3 (0011): SW corner
   - Index 6 (0110): SE corner
   - Index 9 (1001): NW corner
   - Index 12 (1100): NE corner

2. **Then do the 4 edges**:
   - Index 1 (0001): West edge
   - Index 2 (0010): South edge
   - Index 4 (0100): East edge
   - Index 8 (1000): North edge

3. **Then the 2 strips**:
   - Index 5 (0101): Horizontal strip (E-W)
   - Index 10 (1010): Vertical strip (N-S)

4. **Then the 4 U-shapes**:
   - Index 7 (0111): U open to North
   - Index 11 (1011): U open to East
   - Index 13 (1101): U open to South
   - Index 14 (1110): U open to West

5. **Finally the special tiles**:
   - Index 0 (0000): Island
   - Index 15 (1111): Solid center

---

## Testing Your Tiles

Place them in this grid to see all transitions:

```
[0] [1] [2] [3]
[4] [5] [6] [7]
[8] [9][10][11]
[12][13][14][15]
```

If they connect seamlessly, your tileset is correct!

---

## Common Mistakes

❌ **Backwards transitions**: Make sure beach is "inside" (1) and water is "outside" (0)
❌ **Inconsistent transition width**: Keep the fade zone the same width in all tiles
❌ **Sharp corners**: Corners should be smooth curves, not right angles
❌ **Misaligned edges**: Edges must line up perfectly when tiles are placed side-by-side

✅ **Correct approach**:
- Solid terrain in center
- Smooth gradual fade to other terrain
- Consistent transition zone width
- Curved corners that flow naturally

---

Good luck! Start with the 4 corner tiles and work from there. 🏖️
