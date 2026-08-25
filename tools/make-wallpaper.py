#!/usr/bin/env python3
"""Compose the Yaya OS desktop wallpapers from the alien mark.

Reads branding/yaya-logo.svg (pure vector, VTracer output) and writes
branding/yaya-wallpaper.svg (dark, the default) and
branding/yaya-wallpaper-light.svg (GNOME light mode).

    python3 tools/make-wallpaper.py

Re-run this whenever the alien mark changes. The output is committed, so
building an ISO never needs this script — only rsvg-convert to rasterise.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOGO = ROOT / "branding" / "yaya-logo.svg"

W, H = 3840, 2160          # 4K master; GNOME scales it down cleanly
LOGO_CANVAS = 670          # viewBox of yaya-logo.svg (the mark is centred in it)
LOGO_FRACTION = 0.36       # alien height as a fraction of screen height
BRAND_TEAL = "#39c5a0"     # halo tint, same family as the fastfetch green-teal


def alien_group() -> str:
    """The bare <g> holding the alien paths, lifted out of yaya-logo.svg."""
    src = LOGO.read_text()
    m = re.search(r'(<g fill="#cfd4da"[^>]*>.*</g>)', src, re.S)
    if not m:
        raise SystemExit(f"{LOGO}: alien group not found — did the mark change shape?")
    return m.group(1)


def compose(path, bg_inner, bg_outer, fill, opacity):
    size = H * LOGO_FRACTION
    scale = size / LOGO_CANVAS
    x = (W - size) / 2
    y = (H - size) / 2 - H * 0.015     # nudge up: optical centre sits above true centre
    mark = alien_group().replace('fill="#cfd4da"', f'fill="{fill}"')
    path.write_text(f"""<?xml version="1.0" encoding="UTF-8"?>
<!-- Yaya OS desktop wallpaper. Composed from branding/yaya-logo.svg; the alien
     is pure vector (VTracer), so it stays crisp at any resolution. Regenerate
     with tools/make-wallpaper.py if the mark changes. -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>
    <radialGradient id="bg" cx="50%" cy="40%" r="80%">
      <stop offset="0%" stop-color="{bg_inner}"/>
      <stop offset="100%" stop-color="{bg_outer}"/>
    </radialGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="{BRAND_TEAL}" stop-opacity="0.16"/>
      <stop offset="100%" stop-color="{BRAND_TEAL}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <ellipse cx="{W // 2}" cy="{int(H * 0.44)}" rx="{int(W * 0.30)}" ry="{int(H * 0.40)}" fill="url(#glow)"/>
  <g transform="translate({x:.2f},{y:.2f}) scale({scale:.6f})" opacity="{opacity}">
    {mark}
  </g>
</svg>
""")
    print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    out = ROOT / "branding"
    compose(out / "yaya-wallpaper.svg",       "#12161a", "#000000", "#cfd4da", "0.95")
    compose(out / "yaya-wallpaper-light.svg", "#f3f5f7", "#d5dade", "#828d99", "0.90")
