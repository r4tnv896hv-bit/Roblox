"""games/places.json に書いた全部のゲームを、文法チェック → ビルド → Roblox に公開する。
使い方: python3 games/publish_all.py [ゲーム名 ...]   （省略すると全部）
API キーは x-api-key ヘッダーで送る（Claude Code の環境ではプロキシが本物の鍵に差し替える）。
"""
import glob
import json
import os
import subprocess
import sys

from luaparser import ast

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROJO = os.environ.get("ROJO", "/tmp/rojo/rojo")
API_KEY = os.environ.get("ROBLOX_API_KEY", "proxy-injected")


def syntax_ok(project_dir):
    ok = True
    for path in glob.glob(os.path.join(project_dir, "**", "*.lua"), recursive=True):
        try:
            ast.parse(open(path, encoding="utf-8").read())
        except Exception as error:  # noqa: BLE001
            ok = False
            print("  SYNTAX FAIL", path, str(error).splitlines()[0][:150])
    return ok


def main():
    places = json.load(open(os.path.join(ROOT, "games", "places.json")))
    names = sys.argv[1:] or list(places)
    for name in names:
        info = places[name]
        project = os.path.join(ROOT, info["project"])
        project_dir = os.path.dirname(project)
        print(f"== {name}")
        src_dir = os.path.join(project_dir, "game", "src") if name == "coin-clicker" else os.path.join(project_dir, "src")
        if not syntax_ok(src_dir) or not syntax_ok(os.path.join(ROOT, "games", "shared")):
            print("  skipped (syntax errors)")
            continue
        out = os.path.join(project_dir, f"{name}.rbxlx")
        subprocess.run([ROJO, "build", project, "-o", out], check=True, capture_output=True)
        result = subprocess.run(
            [
                "curl", "-sS", "-w", " HTTP %{http_code}", "-X", "POST",
                f"https://apis.roblox.com/universes/v1/{info['universeId']}/places/{info['placeId']}/versions?versionType=Published",
                "-H", f"x-api-key: {API_KEY}", "-H", "Content-Type: application/xml", "--data-binary", f"@{out}",
            ],
            capture_output=True, text=True,
        )
        print("  ", result.stdout.strip())
        os.remove(out)


if __name__ == "__main__":
    main()
