"""ゲームのスクリプトに文法の間違いがないか調べる（Lua 5.x の文法で解析）。
使い方: python3 game/check_syntax.py
"""
import glob
import sys

from luaparser import ast

ok = True
files = sorted(glob.glob("game/src/**/*.lua", recursive=True)) + sorted(glob.glob("DataStore2/**/*.lua", recursive=True))
for path in files:
    try:
        ast.parse(open(path, encoding="utf-8").read())
        print("OK  ", path)
    except Exception as error:  # noqa: BLE001
        ok = False
        print("FAIL", path, "->", str(error).splitlines()[0][:200])
sys.exit(0 if ok else 1)
