#!/usr/bin/env python3
"""Procedural pixel-art logo generator for the "Pixel" game project.

Everything is drawn on a small integer grid (1 cell = 1 logical pixel) and then
upscaled with nearest-neighbour so the result stays crisp at any size.

Usage:
    python3 make_logo.py                # renders "PIXEL"
    python3 make_logo.py NEURELIX       # renders any word (A-Z 0-9 - space !)
"""

import sys
from PIL import Image

# ---------------------------------------------------------------- palette ---
P = {
    "bg":      (0x0f, 0x0f, 0x1b, 255),
    "frame":   (0x2a, 0x2a, 0x44, 255),
    "outline": (0x07, 0x07, 0x10, 255),
    "top":     (0x7c, 0xe8, 0xff, 255),
    "left":    (0x3a, 0xa7, 0xd8, 255),
    "right":   (0x1c, 0x5c, 0x8c, 255),
    "shine":   (0xff, 0xff, 0xff, 255),
    "text":    (0xf2, 0xf4, 0xff, 255),
    "shadow":  (0xa8, 0x25, 0x45, 255),
    "bar":     (0xff, 0x4d, 0x6d, 255),
    "none":    (0, 0, 0, 0),
}

# ------------------------------------------------------------------- font ---
# 5x7 bitmap font, rows top to bottom.
FONT = {
    "A": "01110/10001/10001/11111/10001/10001/10001",
    "B": "11110/10001/10001/11110/10001/10001/11110",
    "C": "01111/10000/10000/10000/10000/10000/01111",
    "D": "11110/10001/10001/10001/10001/10001/11110",
    "E": "11111/10000/10000/11110/10000/10000/11111",
    "F": "11111/10000/10000/11110/10000/10000/10000",
    "G": "01111/10000/10000/10111/10001/10001/01111",
    "H": "10001/10001/10001/11111/10001/10001/10001",
    "I": "11111/00100/00100/00100/00100/00100/11111",
    "J": "00111/00010/00010/00010/00010/10010/01100",
    "K": "10001/10010/10100/11000/10100/10010/10001",
    "L": "10000/10000/10000/10000/10000/10000/11111",
    "M": "10001/11011/10101/10101/10001/10001/10001",
    "N": "10001/11001/10101/10101/10011/10001/10001",
    "O": "01110/10001/10001/10001/10001/10001/01110",
    "P": "11110/10001/10001/11110/10000/10000/10000",
    "Q": "01110/10001/10001/10001/10101/10010/01101",
    "R": "11110/10001/10001/11110/10100/10010/10001",
    "S": "01111/10000/10000/01110/00001/00001/11110",
    "T": "11111/00100/00100/00100/00100/00100/00100",
    "U": "10001/10001/10001/10001/10001/10001/01110",
    "V": "10001/10001/10001/10001/10001/01010/00100",
    "W": "10001/10001/10001/10101/10101/11011/10001",
    "X": "10001/10001/01010/00100/01010/10001/10001",
    "Y": "10001/10001/01010/00100/00100/00100/00100",
    "Z": "11111/00001/00010/00100/01000/10000/11111",
    "0": "01110/10011/10011/10101/11001/11001/01110",
    "1": "00100/01100/00100/00100/00100/00100/01110",
    "2": "01110/10001/00001/00110/01000/10000/11111",
    "3": "11110/00001/00001/01110/00001/00001/11110",
    "4": "00010/00110/01010/10010/11111/00010/00010",
    "5": "11111/10000/11110/00001/00001/10001/01110",
    "6": "00110/01000/10000/11110/10001/10001/01110",
    "7": "11111/00001/00010/00100/01000/01000/01000",
    "8": "01110/10001/10001/01110/10001/10001/01110",
    "9": "01110/10001/10001/01111/00001/00010/01100",
    "-": "00000/00000/00000/11111/00000/00000/00000",
    "!": "00100/00100/00100/00100/00100/00000/00100",
    " ": "00000/00000/00000/00000/00000/00000/00000",
}
GW, GH = 5, 7          # glyph size
KERN = 1               # gap between glyphs


class Canvas:
    def __init__(self, w, h, fill="none"):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return "none"

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.set(x + i, y + j, c)

    def outline(self, colors, c="outline"):
        """Wrap every cell in `colors` with `c` on its empty 4-neighbours."""
        todo = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] in colors:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if self.get(x + dx, y + dy) not in colors:
                            todo.append((x + dx, y + dy))
        for x, y in todo:
            self.set(x, y, c)

    def blit(self, other, ox, oy, skip="none"):
        for y in range(other.h):
            for x in range(other.w):
                v = other.px[y][x]
                if v != skip:
                    self.set(ox + x, oy + y, v)

    def crop(self):
        """Return a copy trimmed to the bounding box of its non-empty cells."""
        xs = [x for y in range(self.h) for x in range(self.w)
              if self.px[y][x] != "none"]
        ys = [y for y in range(self.h) for x in range(self.w)
              if self.px[y][x] != "none"]
        if not xs:
            return self
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        out = Canvas(x1 - x0 + 1, y1 - y0 + 1)
        for y in range(out.h):
            for x in range(out.w):
                out.px[y][x] = self.px[y0 + y][x0 + x]
        return out

    def to_svg(self, scale=1, transparent=False):
        """One <rect> per horizontal run of identical pixels."""
        parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w*scale}" '
            f'height="{self.h*scale}" viewBox="0 0 {self.w} {self.h}" '
            f'shape-rendering="crispEdges">'
        ]
        for y in range(self.h):
            x = 0
            while x < self.w:
                k = self.px[y][x]
                run = 1
                while x + run < self.w and self.px[y][x + run] == k:
                    run += 1
                skip = k == "none" or (transparent and k == "bg")
                if not skip:
                    r, g, b, _ = P[k]
                    parts.append(
                        f'<rect x="{x}" y="{y}" width="{run}" height="1" '
                        f'fill="#{r:02x}{g:02x}{b:02x}"/>'
                    )
                x += run
        parts.append("</svg>")
        return "".join(parts)

    def to_image(self, scale=1, transparent=False):
        img = Image.new("RGBA", (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                k = self.px[y][x]
                if transparent and k == "bg":
                    k = "none"
                img.putpixel((x, y), P[k])
        if scale > 1:
            img = img.resize((self.w * scale, self.h * scale), Image.NEAREST)
        return img


# ------------------------------------------------------------------ pieces ---
def text_grid(word):
    """Render `word` into its own canvas using the 5x7 font."""
    word = word.upper()
    w = len(word) * GW + (len(word) - 1) * KERN
    c = Canvas(w, GH)
    for i, ch in enumerate(word):
        rows = FONT.get(ch, FONT[" "]).split("/")
        ox = i * (GW + KERN)
        for y, row in enumerate(rows):
            for x, bit in enumerate(row):
                if bit == "1":
                    c.set(ox + x, y, "text")
    return c


def cube_grid():
    """16x16 isometric cube: diamond top + two shaded side faces."""
    SIDE = 8                    # height of the vertical faces
    c = Canvas(18, 8 + SIDE + 8 + 2)
    ox, oy = 1, 1               # 1px margin so the outline has room

    # top face: diamond 16 wide, 8 tall
    for r in range(8):
        half = r if r < 4 else 7 - r
        x0 = 7 - (half * 2 + 1)
        x1 = 8 + (half * 2 + 1)
        for x in range(x0, x1 + 1):
            c.set(ox + x, oy + r, "top")

    # side faces hang off the lower edges of the diamond
    for x in range(0, 8):
        ytop = 4 + x // 2
        for y in range(ytop, ytop + SIDE):
            c.set(ox + x, oy + y, "left")
    for x in range(8, 16):
        ytop = 4 + (15 - x) // 2
        for y in range(ytop, ytop + SIDE):
            c.set(ox + x, oy + y, "right")

    # specular pixels on the top face
    for x, y in ((5, 2), (6, 2), (4, 3), (5, 3), (7, 1)):
        c.set(ox + x, oy + y, "shine")

    c.outline({"top", "left", "right", "shine"})
    return c.crop()


def _frame(c):
    """1px border with the four corners left open."""
    for x in range(1, c.w - 1):
        c.set(x, 0, "frame")
        c.set(x, c.h - 1, "frame")
    for y in range(1, c.h - 1):
        c.set(0, y, "frame")
        c.set(c.w - 1, y, "frame")


def _sparkle(c, x, y, col="shine"):
    """Tiny 4-point star."""
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        c.set(x + dx, y + dy, col)


def _wordmark(word):
    """Wordmark canvas with a 1px down-right extrude in the accent colour."""
    txt = text_grid(word)
    c = Canvas(txt.w + 1, txt.h + 1)
    for y in range(txt.h):
        for x in range(txt.w):
            if txt.px[y][x] == "text":
                c.set(x + 1, y + 1, "shadow")
    for y in range(txt.h):
        for x in range(txt.w):
            if txt.px[y][x] == "text":
                c.set(x, y, "text")
    return c


def build(word="PIXEL"):
    """Stacked lockup: cube above the wordmark."""
    mark = _wordmark(word)
    cube = cube_grid()

    pad = 7
    W = max(mark.w, cube.w) + pad * 2
    H = 3 + cube.h + 4 + mark.h + 2 + 1 + 3
    c = Canvas(W, H, "bg")
    _frame(c)

    c.blit(cube, (W - cube.w) // 2, 3)

    tx, ty = (W - mark.w) // 2, 3 + cube.h + 4
    c.blit(mark, tx, ty)

    # dashed rule under the wordmark
    for x in range(tx, tx + mark.w - 1):
        if (x - tx) % 2 == 0:
            c.set(x, ty + mark.h + 1, "bar")

    _sparkle(c, 4, 6)
    _sparkle(c, W - 5, 11, "top")
    c.set(W - 6, 4, "shine")
    c.set(5, 15, "top")
    return c


def build_wide(word="PIXEL"):
    """Horizontal lockup: cube on the left, wordmark on the right."""
    mark = _wordmark(word)
    cube = cube_grid()

    pad, gap = 5, 5
    W = pad * 2 + cube.w + gap + mark.w
    H = max(cube.h, mark.h) + pad * 2
    c = Canvas(W, H, "bg")
    _frame(c)
    c.blit(cube, pad, (H - cube.h) // 2)

    tx = pad + cube.w + gap
    ty = (H - mark.h) // 2
    c.blit(mark, tx, ty)
    for x in range(tx, tx + mark.w - 1):
        if (x - tx) % 2 == 0:
            c.set(x, ty + mark.h + 2, "bar")
    return c


def build_icon():
    """Square app/game icon: cube centred on a framed background."""
    cube = cube_grid()
    S = 32
    c = Canvas(S, S, "bg")
    _frame(c)
    c.blit(cube, (S - cube.w) // 2, (S - cube.h) // 2)
    _sparkle(c, 3, 3, "top")
    return c


def main():
    word = sys.argv[1] if len(sys.argv) > 1 else "PIXEL"
    stack, wide, icon = build(word), build_wide(word), build_icon()

    jobs = [
        ("logo.png", stack, 1, False),
        ("logo@8x.png", stack, 8, False),
        ("logo_transparent@8x.png", stack, 8, True),
        ("logo_wide.png", wide, 1, False),
        ("logo_wide@8x.png", wide, 8, False),
        ("logo_wide_transparent@8x.png", wide, 8, True),
        ("icon.png", icon, 1, False),
        ("icon_256.png", icon, 8, False),
    ]
    for name, grid, scale, transparent in jobs:
        img = grid.to_image(scale, transparent)
        img.save(name)
        print(f"{name:32} {img.width}x{img.height}")

    for name, grid, transparent in [
        ("logo.svg", stack, False),
        ("logo_transparent.svg", stack, True),
        ("logo_wide.svg", wide, False),
        ("icon.svg", icon, False),
    ]:
        open(name, "w").write(grid.to_svg(transparent=transparent))
        print(f"{name:32} {grid.w}x{grid.h} (vector)")


if __name__ == "__main__":
    main()
