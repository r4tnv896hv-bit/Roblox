"""3 本の新作ゲームのアイコン(512)とサムネイル(1920x1080)を作る。
使い方: python3 games/marketing/make_images.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "marketing"))
from make_images import gradient, rays, glow, sparkle, text  # noqa: E402

from PIL import Image, ImageDraw  # noqa: E402

OUT = os.path.dirname(os.path.abspath(__file__))


def draw_box(img, cx, cy, s):
    d = ImageDraw.Draw(img)
    d.polygon([(cx - s, cy - s * 0.3), (cx, cy - s * 0.75), (cx + s, cy - s * 0.3), (cx, cy + s * 0.15)], fill=(225, 175, 115))
    d.polygon([(cx - s, cy - s * 0.3), (cx, cy + s * 0.15), (cx, cy + s * 1.05), (cx - s, cy + s * 0.6)], fill=(190, 140, 85))
    d.polygon([(cx + s, cy - s * 0.3), (cx, cy + s * 0.15), (cx, cy + s * 1.05), (cx + s, cy + s * 0.6)], fill=(160, 115, 70))
    d.line([(cx - s * 0.5, cy - s * 0.52), (cx + s * 0.5, cy - s * 0.08)], fill=(250, 235, 200), width=max(4, int(s * 0.08)))


def draw_robot(img, cx, cy, s, body=(120, 200, 255)):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([cx - s * 0.6, cy - s * 0.2, cx + s * 0.6, cy + s * 0.8], int(s * 0.12), fill=body, outline=(40, 40, 60), width=6)
    d.rounded_rectangle([cx - s * 0.5, cy - s * 0.95, cx + s * 0.5, cy - s * 0.25], int(s * 0.12), fill=(230, 240, 255), outline=(40, 40, 60), width=6)
    for ex in (-0.22, 0.22):
        d.ellipse([cx + s * ex - s * 0.1, cy - s * 0.7, cx + s * ex + s * 0.1, cy - s * 0.5], fill=(60, 230, 255))
    d.line([(cx, cy - s * 0.95), (cx, cy - s * 1.25)], fill=(60, 60, 70), width=8)
    d.ellipse([cx - s * 0.1, cy - s * 1.38, cx + s * 0.1, cy - s * 1.18], fill=(255, 80, 120))


def draw_lucky(img, cx, cy, s):
    d = ImageDraw.Draw(img)
    d.polygon([(cx - s, cy - s * 0.4), (cx, cy - s * 0.9), (cx + s, cy - s * 0.4), (cx, cy + s * 0.1)], fill=(255, 225, 90))
    d.polygon([(cx - s, cy - s * 0.4), (cx, cy + s * 0.1), (cx, cy + s * 1.1), (cx - s, cy + s * 0.6)], fill=(240, 180, 30))
    d.polygon([(cx + s, cy - s * 0.4), (cx, cy + s * 0.1), (cx, cy + s * 1.1), (cx + s, cy + s * 0.6)], fill=(210, 150, 20))
    text(d, (int(cx - s * 0.5), int(cy + s * 0.35)), "?", int(s * 0.9), (255, 255, 255), stroke=(140, 80, 0))
    text(d, (int(cx + s * 0.5), int(cy + s * 0.35)), "?", int(s * 0.9), (255, 255, 255), stroke=(140, 80, 0))


def draw_shredder(img, cx, cy, s):
    d = ImageDraw.Draw(img)
    # 札束が上から落ちてくる
    for i, (dx, dy, ang) in enumerate([(-0.5, -1.25, -12), (0.15, -1.45, 8), (0.55, -1.1, 20)]):
        x, y = cx + s * dx, cy + s * dy
        w, h = s * 0.55, s * 0.26
        pts = []
        for px, py in [(-w, -h), (w, -h), (w, h), (-w, h)]:
            a = math.radians(ang)
            pts.append((x + px * math.cos(a) - py * math.sin(a), y + px * math.sin(a) + py * math.cos(a)))
        d.polygon(pts, fill=(110, 200, 110), outline=(40, 110, 40))
        text(d, (int(x), int(y)), "$", int(s * 0.28), (240, 255, 240), stroke=(40, 110, 40), stroke_width=4)
    # シュレッダー本体
    d.rounded_rectangle([cx - s * 0.9, cy - s * 0.55, cx + s * 0.9, cy + s * 0.9], int(s * 0.1), fill=(55, 60, 75), outline=(25, 25, 35), width=8)
    d.rectangle([cx - s * 0.95, cy - s * 0.7, cx + s * 0.95, cy - s * 0.5], fill=(255, 170, 30))
    for i in range(-3, 4):
        x = cx + i * s * 0.22
        d.polygon([(x - s * 0.08, cy - s * 0.5), (x + s * 0.08, cy - s * 0.5), (x, cy - s * 0.32)], fill=(255, 70, 70))
    # 細切れのお札
    for i in range(9):
        x = cx - s * 0.6 + i * s * 0.15
        d.rectangle([x, cy + s * 0.92, x + s * 0.06, cy + s * 1.25], fill=(110, 200, 110))


GAMES = {
    "shred": {
        "colors": ((40, 170, 90), (10, 50, 30)), "motif": draw_shredder,
        "title": "SHRED A", "subtitle": "BILLION", "tag": "+$140,000,000!",
        "lines": ["Throw cash, gold & vaults in!", "Upgrade your shredder", "Team up to wreck the money truck"],
    },
    "shop": {
        "colors": ((120, 60, 230), (30, 15, 80)), "motif": draw_box,
        "title": "ONLINE SHOP", "subtitle": "TYCOON", "tag": "+$22 NEW ORDER!",
        "lines": ["Buy stock, run ads, ship orders!", "Build a shopping empire", "Play with friends: +20% money"],
    },
    "steal": {
        "colors": ((255, 90, 120), (60, 20, 70)), "motif": draw_robot,
        "title": "STEAL A BOT", "subtitle": "", "tag": "SECRET BOT!",
        "lines": ["Buy robots that earn money", "Steal bots from other bases!", "Lock your base to defend"],
    },
    "kick": {
        "colors": ((60, 190, 255), (20, 60, 140)), "motif": draw_lucky,
        "title": "LUCKY BLOCK", "subtitle": "KICK", "tag": "5,000m!",
        "lines": ["Time your kick for PERFECT!", "Rainbow blocks = x50 coins", "Kick all the way to SPACE"],
    },
}


def make(name, g):
    # アイコン
    icon = gradient((512, 512), *g["colors"]).convert("RGBA")
    rays(icon, (256, 250), 18, (255, 240, 200), 35)
    glow(icon, (256, 250), 180, (255, 230, 150), 120)
    g["motif"](icon, 256, 240, 150)
    d = ImageDraw.Draw(icon)
    rng = random.Random(len(name))
    for _ in range(12):
        sparkle(d, rng.randint(30, 480), rng.randint(30, 480), rng.randint(8, 16))
    text(d, (256, 460), g["title"].split()[0], 70, (255, 255, 255), stroke_width=8)
    icon.convert("RGB").save(os.path.join(OUT, f"{name}_icon_512.png"))

    # サムネイル
    thumb = gradient((1920, 1080), *g["colors"]).convert("RGBA")
    rays(thumb, (520, 560), 24, (255, 240, 200), 40)
    glow(thumb, (520, 560), 380, (255, 230, 150), 140)
    g["motif"](thumb, 520, 560, 300)
    d = ImageDraw.Draw(thumb)
    for _ in range(36):
        sparkle(d, rng.randint(20, 1900), rng.randint(20, 1060), rng.randint(10, 24))
    text(d, (1350, 260), g["title"], 140, (255, 255, 255), stroke_width=14)
    if g["subtitle"]:
        text(d, (1350, 410), g["subtitle"], 120, (255, 215, 80), stroke_width=12)
    text(d, (420, 170), g["tag"], 90, (255, 240, 120), stroke_width=10)
    for i, line in enumerate(g["lines"]):
        y = 640 + i * 105
        box = Image.new("RGBA", thumb.size, (0, 0, 0, 0))
        ImageDraw.Draw(box).rounded_rectangle([960, y - 45, 1780, y + 45], 30, fill=(20, 10, 40, 190))
        thumb.alpha_composite(box)
        d = ImageDraw.Draw(thumb)
        text(d, (1370, y), line, 54, (255, 255, 255), stroke_width=5)
    thumb.convert("RGB").save(os.path.join(OUT, f"{name}_thumbnail_1920x1080.png"))


if __name__ == "__main__":
    for name, g in GAMES.items():
        make(name, g)
    print("done")
