#!/usr/bin/env python3
"""Writes the shape textures in Media/ that the launcher is drawn with.

    python3 tools/generate_textures.py

All are white (tinted in game with SetVertexColor):
  Arrow.tga            the compass-style arrow, pointing left: two nested chevrons, like the
                       minimap's compass arrows (64x64)
  ArrowShadow.tga      the same, two pixels wider all round, for its dark outline
  PanelFill.tga        a rounded rectangle, the menu's background and the square launcher (drawn
                       as slices, so the corners keep their size; PANEL_RADIUS in the Lua code)
  PanelBorder.tga      just its outline, for the silver border
  BarFill.tga          a smaller rounded rectangle, for the square launcher and Edit Mode's box
                       (32x32)
  BarBorder.tga        just its outline
  TabFill.tga          the side bar's tab, like Blizzard's side panels: a rectangle with its
                       corners cut off by 4 pixels (16x16)
  TabBorder.tga        its outline, 1 pixel
  RailFill.tga         the side bar itself: corners cut off by 6 pixels (32x32)
  RailBorder.tga       its outline, 1.5 pixels
  Disc.tga             a filled circle, the round launcher (64x64)
  Triangle.tga         a triangle pointing left, the launchers' chevron (64x64)
"""
import math
import struct
from pathlib import Path

SAMPLES = 4  # per axis, for smooth edges
MEDIA = Path(__file__).resolve().parent.parent / "Media"


def inside_polygon(x, y, points):
    """Even-odd rule."""
    inside = False
    for (x1, y1), (x2, y2) in zip(points, points[1:] + points[:1]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def coverage(size, inside):
    """Rows of how much of each pixel is inside the shape, 0 to 1."""
    rows = []
    for py in range(size):
        row = []
        for px in range(size):
            hits = 0
            for sx in range(SAMPLES):
                for sy in range(SAMPLES):
                    hits += inside(px + (sx + 0.5) / SAMPLES, py + (sy + 0.5) / SAMPLES)
            row.append(hits / (SAMPLES * SAMPLES))
        rows.append(row)
    return rows


def dilate(rows, radius):
    """Grows the shape by radius pixels (each pixel takes the most of its neighbours)."""
    size = len(rows)
    grown = []
    for py in range(size):
        row = []
        for px in range(size):
            best = 0
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    x, y = px + dx, py + dy
                    if 0 <= x < size and 0 <= y < size and dx * dx + dy * dy <= radius * radius:
                        best = max(best, rows[y][x])
            row.append(best)
        grown.append(row)
    return grown


def write_tga(name, rows):
    # Uncompressed 32-bit TGA, rows from the top (descriptor: 8 alpha bits, top-left origin).
    size = len(rows)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    pixels = bytearray()
    for row in rows:
        for value in row:
            pixels += bytes((255, 255, 255, round(255 * value)))  # BGRA
    path = MEDIA / name
    path.write_bytes(header + bytes(pixels))
    print(f"Wrote {path.relative_to(MEDIA.parent)}")


# The compass-style arrow: twice as tall as wide, the inner chevron inside the outer one.
def chevron(tip_x, arm_x, half_height, stroke, center=32):
    """A chevron pointing left: tip at (tip_x, center), arms ending at arm_x."""
    return [(tip_x, center), (arm_x, center - half_height), (arm_x + stroke, center - half_height),
            (tip_x + stroke, center), (arm_x + stroke, center + half_height),
            (arm_x, center + half_height)]


OUTER = chevron(10, 34, 28, 8)
INNER = chevron(25, 40, 17, 7)
arrow_rows = coverage(64, lambda x, y: inside_polygon(x, y, OUTER) or inside_polygon(x, y, INNER))
write_tga("Arrow.tga", arrow_rows)
write_tga("ArrowShadow.tga", dilate(arrow_rows, 2))


def rounded_distance(x, y, size, radius):
    """Signed distance from the edge of a rounded rectangle filling the texture (negative inside)."""
    cx = min(max(x, radius), size - radius)
    cy = min(max(y, radius), size - radius)
    return math.hypot(x - cx, y - cy) - radius


# The menu panel and square launcher: 64 pixels, corner radius 16, border 3.
write_tga("PanelFill.tga", coverage(64, lambda x, y: rounded_distance(x, y, 64, 16) <= 0))
write_tga("PanelBorder.tga", coverage(64, lambda x, y: -3 <= rounded_distance(x, y, 64, 16) <= 0))
# The side bar and its tab: 32 pixels, corner radius 6, border 2.
write_tga("BarFill.tga", coverage(32, lambda x, y: rounded_distance(x, y, 32, 6) <= 0))
write_tga("BarBorder.tga", coverage(32, lambda x, y: -2 <= rounded_distance(x, y, 32, 6) <= 0))

# The side bar's tab and the bar itself, like Blizzard's side panels.
def cut_distance(x, y, size, cut):
    """Distance inward from the edge of a rectangle with its corners cut off (negative outside)."""
    straight = min(x, size - x, y, size - y)
    corners = min(x + y, size - x + y, x + size - y, size - x + size - y)
    return min(straight, (corners - cut) / math.sqrt(2))


# The slices are drawn one texture pixel per interface unit, so these are their sizes in game.
write_tga("TabFill.tga", coverage(16, lambda x, y: cut_distance(x, y, 16, 4) >= 0))
write_tga("TabBorder.tga", coverage(16, lambda x, y: 0 <= cut_distance(x, y, 16, 4) <= 1))
write_tga("RailFill.tga", coverage(32, lambda x, y: cut_distance(x, y, 32, 6) >= 0))
write_tga("RailBorder.tga", coverage(32, lambda x, y: 0 <= cut_distance(x, y, 32, 6) <= 1.5))

# The round launcher: one pixel of margin keeps the edges from bleeding when scaled.
write_tga("Disc.tga", coverage(64, lambda x, y: math.hypot(x - 32, y - 32) <= 31))

# The launchers' chevron, pointing left.
TRIANGLE = [(4, 32), (58, 5), (58, 59)]
write_tga("Triangle.tga", coverage(64, lambda x, y: inside_polygon(x, y, TRIANGLE)))
