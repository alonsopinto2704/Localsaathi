#!/usr/bin/env python3
"""Draws the LocalSaathi mark (same geometry as lib/core/widgets/app_logo.dart)
and writes the app icons and the store graphics.

    python tool/make_icons.py          # everything below
    python tool/make_icons.py app      # web icons + Android launcher icons
    python tool/make_icons.py store    # store/assets: Play icon, feature graphic, og-image

Needs Pillow. Re-run after changing the logo.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEAL = (15, 118, 110, 255)       # AppColors.teal700
TEAL_GROUND = (13, 148, 136, 255)  # AppColors.teal600
WHITE = (255, 255, 255, 255)
AMBER = (244, 183, 64, 255)      # AppColors.accent500
INK = (23, 43, 53)               # AppColors.textPrimary
INK_SOFT = (82, 97, 107)         # AppColors.textSecondary
BACKGROUND = (247, 249, 250)     # AppColors.background
TINT = (230, 244, 242)           # AppColors.teal50
SS = 4  # supersampling for smooth edges


def mark(size, tile=True, scale=1.0, bleed=False):
    """The logo at `size` px. `scale` shrinks the pin inside the canvas (for
    adaptive-icon safe zones); `bleed` fills the canvas with a square tile."""
    s = size * SS
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if tile:
        if bleed:
            d.rectangle([0, 0, s, s], fill=TEAL)
        else:
            d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.28), fill=TEAL)

    w = s * scale
    ox = (s - w) / 2  # centre the scaled drawing

    def P(x, y):
        return (ox + x * w, ox + y * w)

    # Ground ellipse.
    gx, gy = P(0.5, 0.80)
    d.ellipse([gx - 0.23 * w, gy - 0.06 * w, gx + 0.23 * w, gy + 0.06 * w], fill=TEAL_GROUND)

    # Teardrop pin.
    cx, cy = P(0.5, 0.40)
    r = 0.22 * w
    tip = P(0.5, 0.80)
    phi = math.acos(r / (tip[1] - cy))
    left = (cx - r * math.sin(phi), cy + r * math.cos(phi))
    right = (cx + r * math.sin(phi), cy + r * math.cos(phi))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)
    d.polygon([left, right, tip], fill=WHITE)

    # Check.
    stroke = 0.075 * w
    pts = [P(0.5 - 0.095, 0.40 + 0.005), P(0.5 - 0.025, 0.40 + 0.07), P(0.5 + 0.10, 0.40 - 0.065)]
    d.line(pts, fill=AMBER, width=int(stroke), joint="curve")
    for x, y in (pts[0], pts[-1]):  # round caps
        d.ellipse([x - stroke / 2, y - stroke / 2, x + stroke / 2, y + stroke / 2], fill=AMBER)

    return im.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


# ------------------------------------------------------------ store graphics
def font(weight, size):
    """Plus Jakarta Sans, the app font (assets/fonts). weight: Regular|Medium|SemiBold|Bold."""
    return ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", f"PlusJakartaSans-{weight}.ttf"), size)


def lockup(img, centre, mark_size):
    """Mark + two-tone wordmark ("Local" ink, "Saathi" teal), proportioned like
    AppWordmark: 34 px logo, 10 px gap, 18 px bold text tracked -0.3 px."""
    f = font("Bold", round(mark_size * 18 / 34))
    track = -0.3 / 18 * f.size
    gap = mark_size * 10 / 34
    text_w = sum(f.getlength(c) for c in "LocalSaathi") + track * 10
    x = round(centre[0] - (mark_size + gap + text_w) / 2)
    top = round(centre[1] - mark_size / 2)
    m = mark(mark_size)
    img.paste(m, (x, top), m)
    d = ImageDraw.Draw(img)
    x += mark_size + gap
    baseline = centre[1] + 0.38 * f.size  # caps (~0.76 em tall) centred on the mark
    for part, colour in (("Local", INK), ("Saathi", TEAL[:3])):
        for c in part:  # per glyph, for the tracking
            d.text((x, baseline), c, font=f, fill=colour, anchor="ls")
            x += f.getlength(c) + track


def card(size, background, mark_size, centre_y, lines):
    """A plain, centred brand card: lockup, then `lines` of (text, weight, px, colour, baseline)."""
    img = Image.new("RGB", size, background)
    lockup(img, (size[0] / 2, centre_y), mark_size)
    d = ImageDraw.Draw(img)
    for text, weight, px, colour, baseline in lines:
        d.text((size[0] / 2, baseline), text, font=font(weight, px), fill=colour, anchor="ms")
    return img


def store_assets():
    # Social preview for the website (og:image / twitter:image).
    save(card((1200, 630), BACKGROUND, 116, 214, [
        ("Find trusted help near you", "Bold", 66, INK, 372),
        ("Plumbers, electricians, clinics and more across Mumbai", "Medium", 32, INK_SOFT, 440),
    ]), "store", "assets", "og-image.png")

    # Play feature graphic: 1024x500, no alpha, everything well inside the edges.
    save(card((1024, 500), TINT, 112, 196, [
        ("Find trusted help near you", "Bold", 52, INK, 330),
    ]), "store", "assets", "feature-graphic.png")

    # Play store icon: 512x512 32-bit PNG, full-bleed square (Play applies its
    # own corner mask and shadow), same mark and proportions as the launcher icon.
    save(mark(512, bleed=True), "store", "assets", "icon-512.png")


def app_icons():
    # Web.
    save(mark(32), "web", "favicon.png")
    save(mark(192), "web", "icons", "Icon-192.png")
    save(mark(512), "web", "icons", "Icon-512.png")
    save(mark(192, bleed=True, scale=0.78), "web", "icons", "Icon-maskable-192.png")
    save(mark(512, bleed=True, scale=0.78), "web", "icons", "Icon-maskable-512.png")

    # Android: legacy launcher icons, plus adaptive-icon foregrounds (108dp canvas,
    # drawing kept inside the 66dp safe zone; the background is a colour resource).
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, k in densities.items():
        save(mark(int(48 * k)), "android", "app", "src", "main", "res", f"mipmap-{name}", "ic_launcher.png")
        save(mark(int(108 * k), tile=False, scale=66 / 108 * 1.05), "android", "app", "src", "main", "res",
             f"mipmap-{name}", "ic_launcher_foreground.png")


if __name__ == "__main__":
    targets = sys.argv[1:] or ["app", "store"]
    for target in targets:
        {"app": app_icons, "store": store_assets}[target]()
