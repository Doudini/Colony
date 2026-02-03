#!/usr/bin/env python3
"""
Generate a visual reference image for marching squares autotiling.
This creates a 4x4 grid showing all 16 tile patterns.
"""

def print_tile_grid():
    """Print ASCII art showing all 16 tiles in a 4x4 grid"""

    # Define tiles as 7x7 ASCII art
    # █ = solid terrain, ░ = transition, · = other terrain
    tiles = {
        0: [  # 0000 - Island
            "·······",
            "··░░░··",
            "·░███░·",
            "·░███░·",
            "·░███░·",
            "··░░░··",
            "·······"
        ],
        1: [  # 0001 - West edge
            "··░░░··",
            "··███░·",
            "█████░·",
            "█████░·",
            "█████░·",
            "··███░·",
            "··░░░··"
        ],
        2: [  # 0010 - South edge
            "·······",
            "··░░░··",
            "·░███░·",
            "·░███░·",
            "·░███░·",
            "··███··",
            "··███··"
        ],
        3: [  # 0011 - SW corner
            "··░░░··",
            "··███░·",
            "█████░·",
            "█████░·",
            "█████░·",
            "███████",
            "███████"
        ],
        4: [  # 0100 - East edge
            "··░░░··",
            "·░███··",
            "·░█████",
            "·░█████",
            "·░█████",
            "·░███··",
            "··░░░··"
        ],
        5: [  # 0101 - E-W edges
            "··░░░··",
            "·░███··",
            "███████",
            "███████",
            "███████",
            "··███░·",
            "··░░░··"
        ],
        6: [  # 0110 - SE corner
            "··░░░··",
            "·░███··",
            "·░█████",
            "·░█████",
            "·░█████",
            "·██████",
            "·██████"
        ],
        7: [  # 0111 - S,E,W edges
            "··░░░··",
            "·░███··",
            "███████",
            "███████",
            "███████",
            "███████",
            "███████"
        ],
        8: [  # 1000 - North edge
            "███████",
            "███████",
            "·░███░·",
            "·░███░·",
            "·░███░·",
            "··░░░··",
            "·······"
        ],
        9: [  # 1001 - NW corner
            "███████",
            "███████",
            "█████░·",
            "█████░·",
            "█████░·",
            "··███░·",
            "··░░░··"
        ],
        10: [  # 1010 - N-S edges
            "███████",
            "███████",
            "·░███░·",
            "·░███░·",
            "·░███░·",
            "··███··",
            "··███··"
        ],
        11: [  # 1011 - N,S,W edges
            "███████",
            "███████",
            "█████░·",
            "█████░·",
            "█████░·",
            "███████",
            "███████"
        ],
        12: [  # 1100 - NE corner
            "███████",
            "███████",
            "·░█████",
            "·░█████",
            "·░█████",
            "·░███··",
            "··░░░··"
        ],
        13: [  # 1101 - N,E,W edges
            "███████",
            "███████",
            "███████",
            "███████",
            "███████",
            "··███░·",
            "··░░░··"
        ],
        14: [  # 1110 - N,E,S edges
            "███████",
            "███████",
            "·░█████",
            "·░█████",
            "·░█████",
            "·██████",
            "·██████"
        ],
        15: [  # 1111 - Solid
            "███████",
            "███████",
            "███████",
            "███████",
            "███████",
            "███████",
            "███████"
        ]
    }

    # Bit patterns
    patterns = {
        0: "0000", 1: "0001", 2: "0010", 3: "0011",
        4: "0100", 5: "0101", 6: "0110", 7: "0111",
        8: "1000", 9: "1001", 10: "1010", 11: "1011",
        12: "1100", 13: "1101", 14: "1110", 15: "1111"
    }

    # Names
    names = {
        0: "Island", 1: "W-edge", 2: "S-edge", 3: "SW-corner",
        4: "E-edge", 5: "H-strip", 6: "SE-corner", 7: "U-North",
        8: "N-edge", 9: "NW-corner", 10: "V-strip", 11: "U-East",
        12: "NE-corner", 13: "U-South", 14: "U-West", 15: "Solid"
    }

    print("\n" + "="*80)
    print("MARCHING SQUARES - 16 TILE REFERENCE")
    print("="*80)
    print("\nLegend: █ = Solid terrain  ░ = Transition  · = Other terrain")
    print("\nBit pattern: N E S W (1=same, 0=different)\n")

    # Print 4x4 grid
    for row in range(4):
        # Print tile numbers and patterns
        for col in range(4):
            idx = row * 4 + col
            print(f" [{idx:2d}] {patterns[idx]} {names[idx]:11s}", end="  ")
        print("\n")

        # Print tile graphics (7 lines per tile)
        for line in range(7):
            for col in range(4):
                idx = row * 4 + col
                print(f" {tiles[idx][line]} ", end="  ")
            print()
        print()  # Extra space between rows

    print("="*80)
    print("\nQuick Reference:")
    print("  Corners: 3(SW), 6(SE), 9(NW), 12(NE)")
    print("  Edges: 1(W), 2(S), 4(E), 8(N)")
    print("  Strips: 5(Horizontal), 10(Vertical)")
    print("  U-shapes: 7(↑), 11(→), 13(↓), 14(←)")
    print("  Special: 0(Island), 15(Solid)")
    print("="*80 + "\n")


def print_example_usage():
    """Print an example of how tiles connect"""
    print("\n" + "="*80)
    print("EXAMPLE: Beach Peninsula")
    print("="*80)
    print("\nLayout (B=Beach, W=Water):")
    print("""
    W W W W W
    W B B B W
    W B B W W
    W B W W W
    W W W W W
    """)

    print("Tile indices used:")
    print("""
    · · · · ·
    · 7 5 7 ·
    ·11 6 · ·
    · 1 · · ·
    · · · · ·
    """)

    print("\nWhat each tile shows:")
    print("  [7]  = 0111 = Beach solid on S,E,W; fades to water on N")
    print("  [5]  = 0101 = Beach solid on E,W; fades to water on N,S (horizontal strip)")
    print("  [11] = 1011 = Beach solid on N,S,W; fades to water on E (U-shape)")
    print("  [6]  = 0110 = Beach solid on S,E; fades to water on N,W (SE corner)")
    print("  [1]  = 0001 = Beach solid on W; fades to water on N,E,S")
    print("="*80 + "\n")


def print_bit_calculation():
    """Show how to calculate tile index from neighbors"""
    print("\n" + "="*80)
    print("HOW TO CALCULATE TILE INDEX")
    print("="*80)
    print("""
Given a tile and its 4 neighbors:

         [N]
          ↑
    [W] ←[T]→ [E]
          ↓
         [S]

For each neighbor:
  - If neighbor is SAME terrain as [T]: bit = 1
  - If neighbor is DIFFERENT terrain: bit = 0

Combine bits: N E S W (4-bit binary number)

Example: Tile with beach to North and West, water to East and South
  North = Beach = SAME  → 1
  East  = Water = DIFF  → 0
  South = Water = DIFF  → 0
  West  = Beach = SAME  → 1

  Binary: 1001
  Decimal: 8 + 0 + 0 + 1 = 9

  Tile index = 9 (NW corner)
""")
    print("="*80 + "\n")


if __name__ == "__main__":
    print_tile_grid()
    print_example_usage()
    print_bit_calculation()

    print("\nSave this output to a text file for reference:")
    print("  python3 create_marching_squares_reference.py > marching_squares_tiles.txt")
    print()
