#!/usr/bin/env python3
"""Gera os ícones do Via Sacra (cruz latina dourada sobre pergaminho) para
Android, iOS, Web/PWA e fastlane. Requer Pillow. Uso: python tool/make_icons.py"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[1]
PERGAMINHO = (250, 248, 245)
OURO = (184, 134, 11)
OURO_CLARO = (217, 179, 90)
IGREJA = (18, 18, 18)


def icone(tam: int, *, maskable: bool = False, fundo=PERGAMINHO, cor=OURO, anel: bool = True) -> Image.Image:
    s = tam * 4  # supersampling para bordas suaves
    img = Image.new("RGBA", (s, s), fundo + (255,))
    d = ImageDraw.Draw(img)
    escala = 0.62 if maskable else 0.8  # zona segura de ícones maskable (80% do círculo)
    cx, cy = s / 2, s / 2
    if anel:
        r = s * escala / 2
        w = max(2, int(s * 0.018))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=cor + (255,), width=w)
    # Cruz latina: haste vertical longa, travessa no terço superior.
    h = s * escala * 0.74
    largura = s * escala * 0.085
    braco = s * escala * 0.46
    topo = cy - h * 0.52
    d.rectangle([cx - largura / 2, topo, cx + largura / 2, topo + h], fill=cor + (255,))
    ty = topo + h * 0.28
    d.rectangle([cx - braco / 2, ty - largura / 2, cx + braco / 2, ty + largura / 2], fill=cor + (255,))
    return img.resize((tam, tam), Image.LANCZOS)


def salvar(img: Image.Image, caminho: Path, rgb: bool = False) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    (img.convert("RGB") if rgb else img).save(caminho, optimize=True)
    print(" ", caminho.relative_to(RAIZ))


def main() -> None:
    app = RAIZ / "app"
    # Web / PWA
    salvar(icone(192), app / "web/icons/Icon-192.png")
    salvar(icone(512), app / "web/icons/Icon-512.png")
    salvar(icone(192, maskable=True), app / "web/icons/Icon-maskable-192.png")
    salvar(icone(512, maskable=True), app / "web/icons/Icon-maskable-512.png")
    salvar(icone(180, anel=False), app / "web/icons/apple-touch-icon.png", rgb=True)
    salvar(icone(48), app / "web/favicon.png")
    # Android (launcher)
    for pasta, t in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        salvar(icone(t), app / f"android/app/src/main/res/mipmap-{pasta}/ic_launcher.png")
    # iOS (AppIcon.appiconset) — iOS exige ícones sem transparência
    conjunto = app / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((conjunto / "Contents.json").read_text())
    for img in contents["images"]:
        nome = img.get("filename")
        if not nome:
            continue
        pts = float(img["size"].split("x")[0])
        fator = int(img["scale"].replace("x", ""))
        salvar(icone(int(round(pts * fator)), anel=False), conjunto / nome, rgb=True)
    # fastlane / F-Droid
    salvar(icone(512), RAIZ / "fastlane/metadata/android/pt-BR/images/icon.png")
    banner = Image.new("RGB", (1024, 500), PERGAMINHO)
    banner.paste(icone(320, fundo=PERGAMINHO).convert("RGB"), (90, 90))
    d = ImageDraw.Draw(banner)
    d.line([(470, 250), (930, 250)], fill=OURO, width=3)
    salvar(banner, RAIZ / "fastlane/metadata/android/pt-BR/images/featureGraphic.png")


if __name__ == "__main__":
    main()
