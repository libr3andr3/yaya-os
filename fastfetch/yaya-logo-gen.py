#!/usr/bin/env python3
"""Render the Yaya alien mark as fastfetch ASCII art at an arbitrary cell size.

    yaya-logo-gen.py <cols> <rows> [out.txt]

Emits <rows> lines of at most <cols> columns, each prefixed with fastfetch's
"$1" colour placeholder (so the caller's logo colour still applies). Used by
yaya-webcam to size the banner to the terminal instead of shipping a
couple of fixed-size .txt logos.

The shape is re-derived from the vector-quality PNG on every call: coverage per
character cell is area-averaged (BOX resample of the alpha/ink mask) and then
quantised onto a density ramp, so it stays smooth at any size rather than
turning blocky the way scaling the old .txt art would.
"""
import sys
from pathlib import Path

from PIL import Image

# Nominal terminal cell aspect (height / width). A character is about twice as
# tall as it is wide, so the pixel grid has to be stretched horizontally by
# this much for the alien to come out round instead of squashed.
CELL_ASPECT = 1.85

# Density ramp, lightest to darkest — same character vocabulary as the original
# hand-made logo, so the rendered mark still looks like the one it replaces.
RAMP = " .:-=+*#%@"

SOURCES = [
    Path("/usr/share/yaya/fastfetch/yaya-logo.png"),
    Path(__file__).with_name("yaya-logo.png"),
]


def load_mask():
    """Return the logo as an 'L' image where 255 = ink, 0 = background."""
    for src in SOURCES:
        if src.is_file():
            img = Image.open(src)
            break
    else:
        raise SystemExit("yaya-logo-gen: no logo source image found")

    img = img.convert("RGBA")
    alpha = img.getchannel("A")
    if alpha.getextrema()[0] < 250:
        mask = alpha  # transparent background: opacity is the ink
    else:
        # Opaque file: the mark is drawn darker than its (white) background.
        mask = Image.eval(img.convert("L"), lambda v: 255 - v)

    box = mask.getbbox()
    return mask.crop(box) if box else mask


def render(cols, rows):
    mask = load_mask()
    # Reserve one ramp step for "empty" so faint antialiasing doesn't speckle
    # the background, and fit the mark inside the cols x rows box.
    scale = min(cols / (mask.width * CELL_ASPECT), rows / mask.height)
    w = max(1, min(cols, round(mask.width * CELL_ASPECT * scale)))
    h = max(1, min(rows, round(mask.height * scale)))

    cells = mask.resize((w, h), Image.BOX).load()
    lines = []
    for y in range(h):
        row = "".join(RAMP[cells[x, y] * (len(RAMP) - 1) // 255] for x in range(w))
        lines.append(row.rstrip())
    return lines


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    cols, rows = int(sys.argv[1]), int(sys.argv[2])
    if cols < 1 or rows < 1:
        raise SystemExit("yaya-logo-gen: cols and rows must be positive")

    text = "".join(f"$1{line}\n" for line in render(cols, rows))
    if len(sys.argv) > 3:
        Path(sys.argv[3]).write_text(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
