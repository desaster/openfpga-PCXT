#!/usr/bin/env python3
"""Generate font_8x8.vh (the RTL OSD font ROM image) from font_8x8.png.

The PNG is a 16x16 grid of 8x8 glyphs in CP437 order at 1:1 (one image pixel per
glyph pixel), black pixels on. To add a custom glyph, redraw one of the unused
slots. font_8x8.vh is the $readmemh image for the OSD GPU font ROM: one byte per
line, glyph-major then row, so the ROM address is glyph*8 + row.
"""

from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PNG = HERE / "font_8x8.png"
VH = HERE / "font_8x8.vh"

COLS = ROWS = 16  # 16x16 CP437 grid (256 glyphs)
SIZE = 8          # glyph width and height, in pixels


def load_glyphs(img):
    """Decode the 16x16 grid into 8-byte glyphs, bit 7 = leftmost pixel."""
    if img.size != (COLS * SIZE, ROWS * SIZE):
        raise SystemExit(f"{img.width}x{img.height} is not a {COLS * SIZE}x{ROWS * SIZE} grid")
    px = img.convert("L").load()
    glyphs = []
    for i in range(COLS * ROWS):
        ox, oy = (i % COLS) * SIZE, (i // COLS) * SIZE
        glyph = []
        for r in range(SIZE):
            bits = 0
            for c in range(SIZE):
                if px[ox + c, oy + r] < 128:
                    bits |= 0x80 >> c
            glyph.append(bits)
        glyphs.append(glyph)
    return glyphs


def render_vh(glyphs):
    """One byte per line, hex, glyph-major then row (ROM address = glyph*8 + row)."""
    return "\n".join(f"{b:02x}" for glyph in glyphs for b in glyph) + "\n"


def main():
    glyphs = load_glyphs(Image.open(PNG))
    VH.write_text(render_vh(glyphs))
    print(f"wrote {VH.relative_to(HERE.parent)} ({len(glyphs)} glyphs)")


if __name__ == "__main__":
    main()
