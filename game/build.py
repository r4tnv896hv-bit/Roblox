#!/usr/bin/env python3
"""Rojo なしで CoinClicker.rbxlx（Roblox Studio で開けるプレースファイル）を作る。

使い方: python3 game/build.py
"""
import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "CoinClicker.rbxlx")

_ref = 0


def item(class_name, name, source=None, children=""):
    global _ref
    _ref += 1
    props = '<string name="Name">%s</string>' % escape(name)
    if source is not None:
        props += '<ProtectedString name="Source">%s</ProtectedString>' % escape(source)
    return '<Item class="%s" referent="RBX%d"><Properties>%s</Properties>%s</Item>\n' % (
        class_name, _ref, props, children)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def module_tree(path, name):
    """Rojo と同じ規則でディレクトリ/ファイルを ModuleScript にする。"""
    if os.path.isdir(path):
        children = ""
        for entry in sorted(os.listdir(path)):
            if entry == "init.lua":
                continue
            child = os.path.join(path, entry)
            if os.path.isdir(child) or entry.endswith(".lua"):
                children += module_tree(child, entry[:-4] if entry.endswith(".lua") else entry)
        return item("ModuleScript", name, read(os.path.join(path, "init.lua")), children)
    return item("ModuleScript", name, read(path))


def main():
    server = item(
        "ServerScriptService", "ServerScriptService",
        children=module_tree(os.path.join(ROOT, "DataStore2"), "DataStore2")
        + item("Script", "Main", read(os.path.join(ROOT, "game/src/server/Main.server.lua")))
        + item("Script", "Decor", read(os.path.join(ROOT, "game/src/server/Decor.server.lua"))),
    )
    starter = item(
        "StarterPlayer", "StarterPlayer",
        children=item(
            "StarterPlayerScripts", "StarterPlayerScripts",
            children=item("LocalScript", "CoinGui",
                          read(os.path.join(ROOT, "game/src/client/CoinGui.client.lua"))),
        ),
    )
    replicated = item(
        "ReplicatedStorage", "ReplicatedStorage",
        children=item("ModuleScript", "UpgradeConfig",
                      read(os.path.join(ROOT, "game/src/shared/UpgradeConfig.lua")))
        + item("ModuleScript", "Locale", read(os.path.join(ROOT, "game/src/shared/Locale.lua"))),
    )
    with open(OUT, "w", encoding="utf-8") as f:
        f.write('<roblox version="4">\n' + server + replicated + starter + "</roblox>\n")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
