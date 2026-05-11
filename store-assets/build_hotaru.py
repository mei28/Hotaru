"""Generate promo images for Hotaru (macOS firefly border app).

Output: 2 PNGs at 1280x800, 24-bit RGB.
"""

from __future__ import annotations

import base64
import io
from pathlib import Path

import cairosvg
from PIL import Image

W, H = 1280, 800
HERE = Path("/sessions/youthful-beautiful-euler/mnt/outputs")
ICON_PATH = HERE / "hotaru-icon.png"
ICON_HREF = "data:image/png;base64," + base64.b64encode(ICON_PATH.read_bytes()).decode()


# -- common building blocks -------------------------------------------------

DEFS = '''
  <defs>
    <!-- night-sky wallpaper -->
    <linearGradient id="sky" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0e0a2a"/>
      <stop offset="0.55" stop-color="#26154d"/>
      <stop offset="1" stop-color="#4a1d54"/>
    </linearGradient>
    <linearGradient id="lightbg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff8e7"/>
      <stop offset="1" stop-color="#fef4d9"/>
    </linearGradient>
    <!-- firefly-yellow glow -->
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#fff5a8" stop-opacity="0.9"/>
      <stop offset="0.4" stop-color="#ffd84d" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#ffb700" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="windowfill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fdfcfb"/>
      <stop offset="1" stop-color="#f3eee6"/>
    </linearGradient>
    <linearGradient id="windowfill-dim" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#e9e4dc"/>
      <stop offset="1" stop-color="#d8d0c2"/>
    </linearGradient>
    <linearGradient id="titlebar" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#f3eee6"/>
      <stop offset="1" stop-color="#e7e0d3"/>
    </linearGradient>
    <linearGradient id="titlebar-dim" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#d2cabb"/>
      <stop offset="1" stop-color="#c4bcad"/>
    </linearGradient>

    <filter id="bigglow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="24"/>
    </filter>
    <filter id="softer" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="8"/>
    </filter>
    <filter id="cardshadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="14" stdDeviation="22" flood-color="#000" flood-opacity="0.45"/>
    </filter>
    <filter id="softshadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="6" stdDeviation="14" flood-color="#000" flood-opacity="0.18"/>
    </filter>
  </defs>
'''


def brand(x: int, y: int, size: int = 64, sub: str | None = None,
          name_color: str = "#fff8e7", sub_color: str = "#cdb9d6") -> str:
    icon_size = size
    text_x = x + icon_size + 18
    text_y = y + icon_size * 0.78
    parts = [
        f'<image href="{ICON_HREF}" x="{x}" y="{y}" width="{icon_size}" height="{icon_size}" />',
        (
            f'<text x="{text_x}" y="{text_y}" '
            f'font-family="Inter, DejaVu Sans, sans-serif" font-size="{int(size*0.78)}" '
            f'font-weight="700" fill="{name_color}" letter-spacing="-1">Hotaru</text>'
        ),
    ]
    if sub:
        parts.append(
            f'<text x="{text_x}" y="{text_y + 28}" '
            f'font-family="Inter, DejaVu Sans, sans-serif" font-size="16" '
            f'fill="{sub_color}">{sub}</text>'
        )
    return "\n".join(parts)


def window(x: int, y: int, w: int, h: int, title: str, *,
           active: bool, border_color: str = "#ffd84d",
           border_width: int = 6, glow: bool = True) -> str:
    """A macOS-style window card. Active windows get a firefly glow border."""
    rx = 14
    parts: list[str] = []

    fill = "windowfill" if active else "windowfill-dim"
    tbar = "titlebar" if active else "titlebar-dim"

    if active and glow:
        # outer big glow (yellow)
        pad = 60
        parts.append(
            f'<rect x="{x-pad}" y="{y-pad}" width="{w+pad*2}" height="{h+pad*2}" rx="{rx+pad}" '
            f'fill="{border_color}" opacity="0.55" filter="url(#bigglow)"/>'
        )
        # inner tighter glow
        pad2 = 20
        parts.append(
            f'<rect x="{x-pad2}" y="{y-pad2}" width="{w+pad2*2}" height="{h+pad2*2}" rx="{rx+pad2}" '
            f'fill="{border_color}" opacity="0.8" filter="url(#softer)"/>'
        )

    # the window body
    if not active:
        parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="url(#{fill})" '
            f'filter="url(#softshadow)" opacity="0.78"/>'
        )
    else:
        parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="url(#{fill})"/>'
        )

    # crisp Hotaru border on the active window
    if active:
        bw = border_width
        parts.append(
            f'<rect x="{x - bw/2}" y="{y - bw/2}" width="{w + bw}" height="{h + bw}" rx="{rx + bw/2}" '
            f'fill="none" stroke="{border_color}" stroke-width="{bw}" stroke-linejoin="round"/>'
        )

    # titlebar
    tb_h = 36
    parts.append(
        f'<path d="M{x} {y+rx} Q{x} {y} {x+rx} {y} L{x+w-rx} {y} Q{x+w} {y} {x+w} {y+rx} L{x+w} {y+tb_h} L{x} {y+tb_h} Z" '
        f'fill="url(#{tbar})"/>'
    )
    # traffic lights
    tl_y = y + tb_h / 2
    if active:
        colors = ("#ff5f56", "#ffbd2e", "#27c93f")
    else:
        colors = ("#bbb1a3", "#bbb1a3", "#bbb1a3")
    for i, c in enumerate(colors):
        parts.append(f'<circle cx="{x + 18 + i*18}" cy="{tl_y}" r="6" fill="{c}"/>')
    # title
    title_fill = "#3a3528" if active else "#7a7264"
    parts.append(
        f'<text x="{x + w/2}" y="{tl_y + 5}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="13" font-weight="600" fill="{title_fill}" text-anchor="middle">{title}</text>'
    )

    return "".join(parts)


# -- image 1: hero ----------------------------------------------------------

def img_hero() -> str:
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">']
    s.append(DEFS)
    s.append('<rect width="100%" height="100%" fill="url(#sky)"/>')

    # distant stars / fireflies in the sky
    import random
    rng = random.Random(2026)
    stars = []
    for _ in range(80):
        sx, sy = rng.randint(0, W), rng.randint(0, 480)
        r = rng.choice([0.6, 0.8, 1.0, 1.2, 1.6])
        op = rng.uniform(0.35, 0.85)
        stars.append(f'<circle cx="{sx}" cy="{sy}" r="{r}" fill="#fff5d6" opacity="{op}"/>')
    s.append("".join(stars))

    # ambient firefly bokeh
    bokeh = [
        (120, 640, 28, 0.7),
        (1080, 580, 36, 0.6),
        (220, 200, 14, 0.5),
        (1180, 140, 22, 0.55),
        (980, 720, 18, 0.4),
        (60,  420, 10, 0.4),
    ]
    for bx, by, br, bo in bokeh:
        s.append(
            f'<circle cx="{bx}" cy="{by}" r="{br}" fill="url(#glow)" opacity="{bo}" filter="url(#softer)"/>'
        )

    # brand
    s.append(brand(60, 50, 60, "macOS menu bar app"))

    # tagline (top-right)
    s.append(
        f'<text x="{W-60}" y="78" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="15" font-weight="600" fill="#cdb9d6" text-anchor="end" letter-spacing="3">'
        f'FOR macOS TAHOE +</text>'
    )

    # three windows: 2 inactive in back, 1 active glowing in front
    # inactive back-left
    s.append(window(150, 320, 520, 340, "Notes", active=False))
    # inactive back-right
    s.append(window(700, 270, 520, 340, "Mail", active=False))
    # active front-center
    aw_x, aw_y, aw_w, aw_h = 340, 340, 600, 340
    s.append(window(aw_x, aw_y, aw_w, aw_h, "Hotaru.swift",
                    active=True, border_color="#ffd84d", border_width=6, glow=True))

    # inside the active window — code mock (preserve whitespace)
    code_x = aw_x + 30
    line_y = aw_y + 80
    fs = 17
    code_lines = [
        ('<tspan fill="#a877d8">func </tspan>'
         '<tspan fill="#c47a1a" font-weight="600">highlight</tspan>'
         '<tspan fill="#3a3528">(window: AXUIElement) {</tspan>'),
        ('<tspan fill="#3a3528">    </tspan>'
         '<tspan fill="#a877d8">let </tspan>'
         '<tspan fill="#3a3528">rect = window.frame</tspan>'),
        ('<tspan fill="#3a3528">    overlay.</tspan>'
         '<tspan fill="#c47a1a" font-weight="600">show</tspan>'
         '<tspan fill="#3a3528">(around: rect, color: .firefly)</tspan>'),
        ('<tspan fill="#3a3528">}</tspan>'),
        ('<tspan fill="#3a3528">  </tspan>'),
        ('<tspan fill="#9b8f78">// Glow follows the focused window</tspan>'),
    ]
    for line in code_lines:
        s.append(
            f'<text x="{code_x}" y="{line_y}" xml:space="preserve" '
            f'font-family="DejaVu Sans Mono, Menlo, monospace" font-size="{fs}">{line}</text>'
        )
        line_y += 28

    # subtle "active" hint label near the active window
    label_x = aw_x + aw_w/2
    label_y = aw_y + aw_h + 50
    s.append(
        f'<rect x="{label_x - 88}" y="{label_y - 18}" width="176" height="26" rx="13" '
        f'fill="#ffd84d" opacity="0.18"/>'
    )
    s.append(
        f'<text x="{label_x}" y="{label_y}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="12" font-weight="800" fill="#ffd84d" text-anchor="middle" letter-spacing="3">'
        f'ACTIVE WINDOW</text>'
    )

    # main headline
    s.append(
        '<text x="60" y="180" font-family="Inter, DejaVu Sans, sans-serif" '
        'font-size="56" font-weight="800" fill="#fff8e7" letter-spacing="-1.5">'
        'Find your active window'
        '</text>'
    )
    s.append(
        '<text x="60" y="240" font-family="Inter, DejaVu Sans, sans-serif" '
        'font-size="56" font-weight="800" fill="#ffd84d" letter-spacing="-1.5">'
        'at a glance.'
        '</text>'
    )

    s.append("</svg>")
    return "".join(s)


# -- image 2: tune the glow / features --------------------------------------

def img_features() -> str:
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">']
    s.append(DEFS)
    # twilight gradient — lighter for the features image
    s.append('''
    <defs>
      <linearGradient id="twilight" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#241540"/>
        <stop offset="1" stop-color="#5b2a5a"/>
      </linearGradient>
    </defs>
    ''')
    s.append('<rect width="100%" height="100%" fill="url(#twilight)"/>')

    # a few fireflies
    for bx, by, br, bo in [(80, 120, 20, 0.5), (1180, 700, 28, 0.55),
                            (1130, 90, 14, 0.5), (90, 720, 16, 0.45)]:
        s.append(f'<circle cx="{bx}" cy="{by}" r="{br}" fill="url(#glow)" opacity="{bo}" filter="url(#softer)"/>')

    s.append(brand(60, 50, 60, "Customize the firefly glow"))

    # headline
    s.append(
        '<text x="60" y="190" font-family="Inter, DejaVu Sans, sans-serif" '
        'font-size="52" font-weight="800" fill="#fff8e7" letter-spacing="-1.2">'
        'Tune the glow.</text>'
    )
    s.append(
        '<text x="60" y="232" font-family="Inter, DejaVu Sans, sans-serif" '
        'font-size="20" fill="#cdb9d6">'
        'Pick a color per appearance, set the width, and forget it&apos;s there.</text>'
    )

    # settings panel mock (light, macOS System Settings vibe)
    px, py, pw, ph = 60, 290, 600, 470
    # outer rounded panel
    s.append(
        f'<rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="16" '
        f'fill="#f4f1ea" filter="url(#cardshadow)"/>'
    )
    # title bar of the settings window
    s.append(
        f'<path d="M{px} {py+16} Q{px} {py} {px+16} {py} L{px+pw-16} {py} '
        f'Q{px+pw} {py} {px+pw} {py+16} L{px+pw} {py+44} L{px} {py+44} Z" fill="#ece6da"/>'
    )
    for i, c in enumerate(("#ff5f56", "#ffbd2e", "#27c93f")):
        s.append(f'<circle cx="{px + 20 + i*18}" cy="{py + 22}" r="6" fill="{c}"/>')
    s.append(
        f'<text x="{px + pw/2}" y="{py + 27}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="13" font-weight="600" fill="#3a3528" text-anchor="middle">Hotaru — Settings</text>'
    )

    # Border section card
    sec_x = px + 24
    sec_y = py + 72
    sec_w = pw - 48
    s.append(f'<rect x="{sec_x}" y="{sec_y}" width="{sec_w}" height="180" rx="10" fill="#ffffff"/>')
    s.append(
        f'<text x="{sec_x + 18}" y="{sec_y + 32}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="12" font-weight="700" fill="#7a7264" letter-spacing="1">BORDER</text>'
    )

    # color row 1 (light)
    row_y = sec_y + 56
    s.append(
        f'<text x="{sec_x + 18}" y="{row_y + 20}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="15" fill="#3a3528">Color (Light mode)</text>'
    )
    s.append(f'<rect x="{sec_x + sec_w - 56}" y="{row_y + 6}" width="36" height="22" rx="4" fill="#ffd84d" stroke="#cfc6b3"/>')
    # color row 2 (dark)
    row_y += 40
    s.append(
        f'<text x="{sec_x + 18}" y="{row_y + 20}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="15" fill="#3a3528">Color (Dark mode)</text>'
    )
    s.append(f'<rect x="{sec_x + sec_w - 56}" y="{row_y + 6}" width="36" height="22" rx="4" fill="#5fb4ff" stroke="#cfc6b3"/>')
    # width slider
    row_y += 40
    s.append(
        f'<text x="{sec_x + 18}" y="{row_y + 20}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="15" fill="#3a3528">Width</text>'
    )
    track_x = sec_x + 110
    track_w = sec_w - 170
    s.append(f'<rect x="{track_x}" y="{row_y + 14}" width="{track_w}" height="4" rx="2" fill="#dcd5c5"/>')
    s.append(f'<rect x="{track_x}" y="{row_y + 14}" width="{int(track_w*0.55)}" height="4" rx="2" fill="#7a5cb0"/>')
    knob_x = track_x + int(track_w*0.55)
    s.append(f'<circle cx="{knob_x}" cy="{row_y + 16}" r="9" fill="#ffffff" stroke="#bdb4a3" stroke-width="1"/>')
    s.append(
        f'<text x="{sec_x + sec_w - 22}" y="{row_y + 20}" font-family="DejaVu Sans Mono, Menlo, monospace" '
        f'font-size="14" fill="#3a3528" text-anchor="end">6px</text>'
    )

    # Preview card
    prev_y = sec_y + 200
    s.append(f'<rect x="{sec_x}" y="{prev_y}" width="{sec_w}" height="150" rx="10" fill="#ffffff"/>')
    s.append(
        f'<text x="{sec_x + 18}" y="{prev_y + 30}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="12" font-weight="700" fill="#7a7264" letter-spacing="1">PREVIEW</text>'
    )
    # preview rect with glow
    rx2, ry2 = sec_x + 30, prev_y + 56
    rw2, rh2 = sec_w - 60, 76
    # outer glow
    s.append(
        f'<rect x="{rx2-30}" y="{ry2-30}" width="{rw2+60}" height="{rh2+60}" rx="42" '
        f'fill="#ffd84d" opacity="0.45" filter="url(#bigglow)"/>'
    )
    s.append(
        f'<rect x="{rx2}" y="{ry2}" width="{rw2}" height="{rh2}" rx="12" '
        f'fill="none" stroke="#ffd84d" stroke-width="6"/>'
    )

    # right column: feature bullets + menu bar callout
    fx = 720
    fy_top = 320

    # menu bar callout
    mb_w = 500
    mb_h = 44
    s.append(f'<rect x="{fx}" y="{fy_top}" width="{mb_w}" height="{mb_h}" rx="10" fill="#ffffff" opacity="0.97"/>')
    # menu bar items mock
    s.append(
        f'<text x="{fx + 18}" y="{fy_top + 28}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="14" font-weight="700" fill="#3a3528"></text>'
    )
    s.append(
        f'<text x="{fx + 60}" y="{fy_top + 28}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="14" font-weight="600" fill="#3a3528">Xcode</text>'
    )
    s.append(
        f'<text x="{fx + 130}" y="{fy_top + 28}" font-family="Inter, DejaVu Sans, sans-serif" '
        f'font-size="14" fill="#3a3528">File   Edit   View</text>'
    )
    # sparkles icon stand-in (Hotaru menu bar item)
    icon_cx = fx + mb_w - 60
    s.append(f'<circle cx="{icon_cx}" cy="{fy_top + mb_h/2}" r="14" fill="#fff5a8" opacity="0.65" filter="url(#softer)"/>')
    s.append(f'<text x="{icon_cx}" y="{fy_top + mb_h/2 + 6}" font-family="DejaVu Sans, sans-serif" '
             f'font-size="18" fill="#c4881a" text-anchor="middle">✦</text>')
    s.append(
        f'<text x="{fx + mb_w - 24}" y="{fy_top + 28}" font-family="DejaVu Sans Mono, Menlo, monospace" '
        f'font-size="13" fill="#3a3528" text-anchor="end">9:41</text>'
    )

    # feature bullets
    feats = [
        ("Light + Dark colors",      "Different glow per appearance — follows the system."),
        ("Border width 1–10 px",     "Hairline accent or unmistakable halo. Your call."),
        ("Live-tracks every move",   "Follows the focused window as it slides and resizes."),
        ("Quiet by default",         "Hides in Mission Control, fullscreen, and Exposé."),
    ]
    fy = fy_top + 88
    for title, body in feats:
        s.append(f'<circle cx="{fx + 10}" cy="{fy + 10}" r="6" fill="#ffd84d"/>')
        s.append(
            f'<text x="{fx + 32}" y="{fy + 16}" font-family="Inter, DejaVu Sans, sans-serif" '
            f'font-size="22" font-weight="700" fill="#fff8e7">{title}</text>'
        )
        s.append(
            f'<text x="{fx + 32}" y="{fy + 44}" font-family="Inter, DejaVu Sans, sans-serif" '
            f'font-size="15" fill="#cdb9d6">{body}</text>'
        )
        fy += 76

    s.append("</svg>")
    return "".join(s)


# -- render pipeline --------------------------------------------------------

def render(svg_str: str, out_path: Path) -> None:
    png_bytes = cairosvg.svg2png(bytestring=svg_str.encode("utf-8"),
                                 output_width=W, output_height=H)
    im = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    bg = Image.new("RGB", im.size, (0, 0, 0))  # dark behind transparent for night-look
    bg.paste(im, mask=im.split()[3])
    bg.save(out_path, "PNG", optimize=True)


def main() -> None:
    for name, fn in [
        ("hotaru-1-hero.png",     img_hero),
        ("hotaru-2-features.png", img_features),
    ]:
        out = HERE / name
        render(fn(), out)
        with Image.open(out) as im:
            print(f"{name}  size={im.size}  mode={im.mode}")


if __name__ == "__main__":
    main()
