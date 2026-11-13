#!/usr/bin/env bash
# CoinClicker.rbxlx をビルドして Roblox に公開する（Open Cloud Place Publishing API）
# 使い方: game/publish.sh <PLACE_ID>
# API キーは x-api-key ヘッダーで送る。Claude Code の環境ではプロキシが本物の鍵に差し替える。
set -euo pipefail
cd "$(dirname "$0")/.."

PLACE_ID="${1:?PLACE_ID を指定してください}"
ROJO="${ROJO:-/tmp/rojo/rojo}"
API_KEY="${ROBLOX_API_KEY:-proxy-injected}"

"$ROJO" build game.project.json -o game/CoinClicker.rbxlx

UNIVERSE_ID=$(curl -sS "https://apis.roblox.com/universes/v1/places/${PLACE_ID}/universe" \
	| python3 -c 'import sys, json; print(json.load(sys.stdin)["universeId"])')
echo "universe: ${UNIVERSE_ID} / place: ${PLACE_ID}"

curl -sS --fail-with-body -X POST \
	"https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=Published" \
	-H "x-api-key: ${API_KEY}" \
	-H "Content-Type: application/xml" \
	--data-binary @game/CoinClicker.rbxlx
echo
