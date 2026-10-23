# kepler_app: app for pupils, teachers and parents of pupils of the JKG
# Copyright (c) 2026 Jakob Krause
#
# This file is part of kepler_app. It is licensed under the GNU GPLv3.

"""Erzeugt alle iOS-App-Icon-Varianten aus einer einzigen Geometriequelle.

    python3 other/generate_ios_icons.py

Ausgaben:
  ios/Runner/Assets.xcassets/AppIcon.appiconset/  Light (iOS 14-25),
                                                  Dark und Tinted (iOS 18-25)
  ios/Runner/AppIcon.icon/                        Liquid Glass (iOS 26+)

Die drei Kreise stammen aus other/app-icon.svg. Keine Ebene ueberlappt eine
andere: jede wird um die davorliegenden ausgespart. Das haelt die Formen
auseinander, wenn iOS im Clear-Modus saemtliche Farbe entfernt und nur die
Umrisse bleiben -- und es verhindert, dass sich mehrere Glasebenen stapeln
und die Ueberlappung truebe wird.

Benoetigt Pillow. Nach Aenderungen an CIRCLES neu ausfuehren; die erzeugten
Dateien werden mitversioniert, damit ein Build ohne Python auskommt.
"""

import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

# --------------------------------------------------------------------- Geometrie
# Kreise aus other/app-icon.svg im 512er Koordinatensystem, von hinten nach vorn.
CIRCLES = [
    ("sun",           252.8465, 230.99948, 100.0, (0xfe, 0xd4, 0x4c)),
    ("planet-blue",   321.0405, 289.03351,  57.5, (0x4a, 0x8a, 0xba)),
    ("planet-orange", 203.4595, 311.00052,  70.0, (0xff, 0x7c, 0x00)),
]

SRC = 512.0          # Koordinatensystem der Quelle
OUT = 1024           # Kantenlaenge der erzeugten Bilder
GAP = 5.0            # Luft zwischen den Ebenen, entspricht der alten Konturbreite
# Im Glass-Bundle stossen die Formen aneinander: dort trennt sie der Schatten,
# den jede Gruppe wirft, und eine zusaetzliche Luecke wuerde als weisse Linie
# zwischen den Kreisen sichtbar.
GLASS_GAP = 0.0

# Das ausgelieferte Icon zeigt das Motiv groesser als das Quell-SVG: es fuellt
# 67 statt 49 Prozent der Kantenlaenge. Der Faktor wurde durch Minimierung der
# Pixeldifferenz gegen das fruehere Icon-App-1024x1024@1x.png bestimmt
# (Restfehler 0.21 pro Kanal; die Datei ist inzwischen durch AppIcon-1024.png
# ersetzt und nur noch in der Git-Historie). Er gilt fuer alle Varianten, damit
# klassisch und Glass deckungsgleich bleiben.
BASE_SCALE = 1.3677

STROKE = (0x00, 0x00, 0x00)
BG_LIGHT = (0xff, 0xff, 0xff)
BG_DARK = (0x0a, 0x0d, 0x14)   # near-black; reines Schwarz wirkt auf OLED wie ein Loch

# Tinted braucht eigene Helligkeiten statt echter Luminanz: Blau (124) und
# Orange (149) liegen zu dicht beieinander und verschmelzen sonst zu einer Flaeche.
TINT_GRAY = {"sun": 235, "planet-orange": 170, "planet-blue": 105}

# --------------------------------------------------------------- Liquid Glass
# Im Hellmodus faellt die schwarze Kontur weg, die das Motiv bisher vom Grund
# abhob -- eine helle Glaskante auf weissem Grund ist praktisch unsichtbar.
# Den Kontrast liefert stattdessen der Schatten, und der wirkt nur, wenn jede
# Form ihn selbst wirft. Deshalb liegt jeder Kreis in einer eigenen Gruppe:
# so beschatten die vorderen Formen die dahinterliegenden. In einer gemeinsamen
# Gruppe teilen sich alle drei einen einzigen flachen Schatten nach hinten.
#
# Das Format erlaubt hoechstens vier Gruppen; bei drei Kreisen bleibt also eine
# uebrig. Sie zum Verdoppeln eines Schattens zu nutzen bringt sichtbar nichts,
# und opacity ist mit 1.0 ausgereizt -- mehr Tiefe gibt Icon Composer nicht her.
GLASS_SHADOW_OPACITY = 1.0
GLASS_SHADOW_KIND = "neutral"   # "neutral", "layer-color" oder "none"
GLASS_TRANSLUCENCY = 0.2
GLASS_SPECULAR = True           # Glanzkante, die iOS auf jede Ebene legt
GLASS_BLUR_MATERIAL = None      # Weichzeichnung im Material, None oder 0..1
GLASS_GROUP_PER_LAYER = True
# Hintergrund im Hellmodus: (oben, unten). Beide gleich ergibt eine Flaeche.
# Im Dunkelmodus setzt das Bundle "system-dark" und ueberlaesst iOS die Wahl.
GLASS_BG_LIGHT = ((0xff, 0xff, 0xff), (0xff, 0xff, 0xff))

ROOT = Path(__file__).resolve().parent.parent
APPICONSET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ICONBUNDLE = ROOT / "ios/Runner/AppIcon.icon"


def placed(scale=BASE_SCALE):
    """Kreise auf OUT umrechnen, optional um die Bildmitte skaliert."""
    k = OUT / SRC
    mid = OUT / 2.0
    return [(name, mid + (cx * k - mid) * scale, mid + (cy * k - mid) * scale,
             r * k * scale, col)
            for name, cx, cy, r, col in CIRCLES]


def half_gap(scale, gap=GAP):
    """Halbe Zwischenraumbreite.

    Jede Form schrumpft darum, jede Aussparung waechst darum -- zwischen zwei
    Ebenen entsteht so genau gap. Das entspricht zugleich der zentriert auf dem
    Kreisrand liegenden Kontur des Quell-SVG.
    """
    return gap * (OUT / SRC) * scale / 2.0


# ------------------------------------------------------------------ Rasterbilder
def render_flat(bg, gap_fill, colors=None, scale=BASE_SCALE, ss=4):
    """Flaches Icon mit freigestellten Ebenen.

    Vor jeder Ebene wird eine aufgeweitete Scheibe in gap_fill gesetzt, die Form
    selbst dann um dasselbe Mass verkleinert. Weil die vorderen Ebenen dasselbe
    tun, entsteht ueberall exakt GAP Abstand -- mit gap_fill=STROKE ergibt das
    die bekannte schwarze Kontur, mit gap_fill=bg konturlose Formen.
    """
    size = OUT * ss
    im = Image.new("RGB", (size, size), bg)
    draw = ImageDraw.Draw(im)
    h = half_gap(scale)

    for name, cx, cy, r, col in placed(scale):
        for radius, fill in ((r + h, gap_fill), (r - h, colors[name] if colors else col)):
            draw.ellipse([(cx - radius) * ss, (cy - radius) * ss,
                          (cx + radius) * ss, (cy + radius) * ss], fill=fill)

    return im.resize((OUT, OUT), Image.LANCZOS)


# -------------------------------------------------------------------------- SVG
def svg_layer(index, scale=BASE_SCALE):
    """Eine freigestellte Ebene als SVG. Monochrom -- die Farbe setzt icon.json."""
    circles = placed(scale)
    name, cx, cy, r, _ = circles[index]
    front = circles[index + 1:]
    h = half_gap(scale, GLASS_GAP)
    radius = r - h

    disc = f'<circle cx="{cx:.3f}" cy="{cy:.3f}" r="{radius:.3f}" fill="#000"'
    if not front:
        body = f"  {disc}/>\n"
    else:
        cuts = "".join(
            f'    <circle cx="{fx:.3f}" cy="{fy:.3f}" r="{fr + h:.3f}" fill="#000"/>\n'
            for _, fx, fy, fr, _ in front)
        body = (f'  <mask id="cut-{name}" maskUnits="userSpaceOnUse"'
                f' x="0" y="0" width="{OUT}" height="{OUT}">\n'
                f'    <rect width="{OUT}" height="{OUT}" fill="#fff"/>\n'
                f"{cuts}"
                f"  </mask>\n"
                f'  {disc} mask="url(#cut-{name})"/>\n')

    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{OUT}" height="{OUT}"'
            f' viewBox="0 0 {OUT} {OUT}">\n{body}</svg>\n')


# ------------------------------------------------------------------ Asset-Katalog
def build_appiconset():
    if APPICONSET.exists():
        shutil.rmtree(APPICONSET)
    APPICONSET.mkdir(parents=True)

    # Light: Zwischenraum schwarz, also optisch das bisherige Icon.
    render_flat(BG_LIGHT, STROKE).save(APPICONSET / "AppIcon-1024.png")
    # Dark: konturlos, Zwischenraum in Hintergrundfarbe.
    render_flat(BG_DARK, BG_DARK).save(APPICONSET / "AppIcon-1024-Dark.png")
    # Tinted: gespreizte Graustufen auf Schwarz, die Toenung legt iOS darueber.
    render_flat((0, 0, 0), (0, 0, 0),
                colors={n: (v, v, v) for n, v in TINT_GRAY.items()}
                ).save(APPICONSET / "AppIcon-1024-Tinted.png")

    def entry(filename, appearance=None):
        item = {"filename": filename, "idiom": "universal",
                "platform": "ios", "size": "1024x1024"}
        if appearance:
            item["appearances"] = [{"appearance": "luminosity", "value": appearance}]
        return item

    contents = {
        "images": [
            entry("AppIcon-1024.png"),
            entry("AppIcon-1024-Dark.png", "dark"),
            entry("AppIcon-1024-Tinted.png", "tinted"),
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (APPICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


# ------------------------------------------------------------------- Liquid Glass
def srgb(rgb, alpha=1.0):
    r, g, b = (c / 255.0 for c in rgb)
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},{alpha:.5f}"


def gray(value, alpha=1.0):
    return f"gray:{value / 255.0:.5f},{alpha:.5f}"





def build_icon_bundle():
    if ICONBUNDLE.exists():
        shutil.rmtree(ICONBUNDLE)
    assets = ICONBUNDLE / "Assets"
    assets.mkdir(parents=True)

    layers = []
    for index, (name, _, _, _, col) in enumerate(placed()):
        (assets / f"{name}.svg").write_text(svg_layer(index))


        layers.append({
            "fill-specializations": [
                {"value": {"solid": srgb(col)}},
                {"appearance": "tinted",
                 "value": {"solid": gray(TINT_GRAY[name])}},
            ],
            "glass": True,
            "hidden": False,
            "image-name": f"{name}.svg",
            "name": name,
        })

    layers.reverse()   # Icon Composer stapelt die Liste von vorn nach hinten.

    top, bottom = GLASS_BG_LIGHT
    if top == bottom:
        light_bg = {"solid": srgb(top)}
    else:
        light_bg = {
            "linear-gradient": [srgb(top), srgb(bottom)],
            "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}},
        }

    def group(members):
        return {
            "blur-material": GLASS_BLUR_MATERIAL,
            "hidden": False,
            "layers": members,
            "lighting": "individual",
            "shadow": {"kind": GLASS_SHADOW_KIND, "opacity": GLASS_SHADOW_OPACITY},
            "specular": GLASS_SPECULAR,
            "translucency": {"enabled": GLASS_TRANSLUCENCY > 0,
                             "value": GLASS_TRANSLUCENCY},
        }

    if GLASS_GROUP_PER_LAYER:
        groups = [group([lay]) for lay in layers]
    else:
        groups = [group(layers)]
    if len(groups) > 4:
        raise ValueError(f"{len(groups)} Gruppen -- das Format erlaubt hoechstens vier")

    icon = {
        "color-space-for-untagged-svg-colors": "display-p3",
        "fill-specializations": [
            {"value": light_bg},
            {"appearance": "dark", "value": "system-dark"},
        ],
        "groups": groups,
        "supported-platforms": {"squares": "shared"},
    }
    (ICONBUNDLE / "icon.json").write_text(json.dumps(icon, indent=2) + "\n")


if __name__ == "__main__":
    build_appiconset()
    build_icon_bundle()
    print(f"appiconset  -> {APPICONSET.relative_to(ROOT)}")
    print(f"icon bundle -> {ICONBUNDLE.relative_to(ROOT)}")
