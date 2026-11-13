"""コインクリッカーのアイコン(512x512)とサムネイル(1920x1080)を作る。
使い方: python3 game/marketing/make_images.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
FONT = "/usr/share/fonts/opentype/ipafont-gothic/ipagp.ttf"
GOLD = (255, 205, 40)
GOLD_LIGHT = (255, 240, 150)
GOLD_DARK = (190, 120, 0)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def rays(img, center, count, color, alpha):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = max(img.size) * 1.5
    cx, cy = center
    for i in range(count):
        a0 = 2 * math.pi * i / count
        a1 = a0 + math.pi / count
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)),
                   (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=color + (alpha,))
    img.alpha_composite(layer)


def glow(img, center, radius, color, strength=200):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color + (strength,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * 0.45)))


def coin(img, center, radius):
    cx, cy = center
    d = ImageDraw.Draw(img)
    d.ellipse([cx - radius, cy - radius + radius * 0.08, cx + radius, cy + radius + radius * 0.08], fill=GOLD_DARK)
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=GOLD)
    inner = radius * 0.78
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], outline=GOLD_DARK, width=max(4, int(radius * 0.05)))
    # 星マーク
    pts = []
    for i in range(10):
        r = inner * (0.62 if i % 2 == 0 else 0.26)
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=GOLD_LIGHT, outline=GOLD_DARK)
    # ハイライト
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([cx - radius * 0.7, cy - radius * 0.85, cx - radius * 0.1, cy - radius * 0.45],
                               fill=(255, 255, 255, 140))
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(radius * 0.06)))


def sparkle(d, x, y, s, color=(255, 255, 220)):
    d.polygon([(x, y - s), (x + s * 0.22, y - s * 0.22), (x + s, y), (x + s * 0.22, y + s * 0.22),
               (x, y + s), (x - s * 0.22, y + s * 0.22), (x - s, y), (x - s * 0.22, y - s * 0.22)], fill=color)


def text(d, xy, s, size, fill, stroke=(60, 20, 80), stroke_width=None, anchor="mm"):
    font = ImageFont.truetype(FONT, size)
    d.text(xy, s, font=font, fill=fill, stroke_width=stroke_width or max(4, size // 9),
           stroke_fill=stroke, anchor=anchor)


def make_icon():
    size = (512, 512)
    img = gradient(size, (120, 40, 180), (30, 20, 90)).convert("RGBA")
    rays(img, (256, 250), 18, (255, 220, 120), 40)
    glow(img, (256, 250), 200, (255, 200, 60), 170)
    coin(img, (256, 250), 150)
    d = ImageDraw.Draw(img)
    rng = random.Random(7)
    for _ in range(14):
        sparkle(d, rng.randint(30, 480), rng.randint(30, 480), rng.randint(8, 18))
    text(d, (390, 95), "+100", 62, GOLD_LIGHT, stroke_width=7)
    text(d, (256, 445), "CLICK!", 74, (255, 255, 255), stroke_width=9)
    img.convert("RGB").save(os.path.join(OUT, "icon_512.png"))


def make_thumbnail():
    size = (1920, 1080)
    img = gradient(size, (255, 150, 90), (110, 50, 160)).convert("RGBA")
    center = (560, 600)
    rays(img, center, 24, (255, 235, 160), 45)
    glow(img, center, 420, (255, 210, 80), 180)
    coin(img, center, 300)
    d = ImageDraw.Draw(img)
    rng = random.Random(3)
    for _ in range(40):
        sparkle(d, rng.randint(20, 1900), rng.randint(20, 1060), rng.randint(10, 26))

    text(d, (1350, 230), "【転生】", 110, GOLD_LIGHT)
    text(d, (1340, 390), "コインクリッカー", 150, (255, 255, 255), stroke_width=14)
    text(d, (1350, 540), "シミュレーター", 120, GOLD, stroke_width=12)

    lines = ["転生で倍率アップ！", "友だちと遊ぶとコイン+20%", "毎日ログインボーナス！"]
    for i, line in enumerate(lines):
        y = 700 + i * 105
        box = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(box).rounded_rectangle([960, y - 45, 1760, y + 45], 30, fill=(40, 20, 70, 190))
        img.alpha_composite(box)
        d = ImageDraw.Draw(img)
        text(d, (1360, y), line, 64, (255, 255, 255), stroke_width=5)

    text(d, (300, 220), "+1,000", 110, GOLD_LIGHT, stroke_width=11)
    text(d, (860, 170), "大当たり!", 100, (255, 90, 60), stroke=(255, 255, 255), stroke_width=10)
    img.convert("RGB").save(os.path.join(OUT, "thumbnail_1920x1080.png"))


if __name__ == "__main__":
    make_icon()
    make_thumbnail()
    print("done")
