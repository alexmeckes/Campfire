#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/plugins/campfire-codex"
PLUGIN_JSON="$PLUGIN_DIR/.codex-plugin/plugin.json"
MARKETPLACE_JSON="$ROOT_DIR/.agents/plugins/marketplace.json"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_file() {
  local path="$1"
  [ -e "$path" ] || fail "Missing required path: $path"
}

echo "== Syntax checks =="
zsh -n "$0"

echo "== Plugin packaging =="
expect_file "$PLUGIN_JSON"
expect_file "$MARKETPLACE_JSON"
expect_file "$PLUGIN_DIR/skills/campfire/SKILL.md"

python3 - "$PLUGIN_JSON" "$MARKETPLACE_JSON" <<'PY'
import json
import sys
from pathlib import Path

plugin_json = Path(sys.argv[1])
marketplace_json = Path(sys.argv[2])
plugin = json.loads(plugin_json.read_text())
marketplace = json.loads(marketplace_json.read_text())

if plugin.get("name") != "campfire-codex":
    raise SystemExit("plugin name mismatch")
if plugin.get("skills") != "./skills/":
    raise SystemExit("plugin skills path mismatch")
interface = plugin.get("interface", {})
if interface.get("displayName") != "Campfire":
    raise SystemExit("plugin display name mismatch")

plugins = marketplace.get("plugins", [])
entry = next((item for item in plugins if item.get("name") == "campfire-codex"), None)
if not entry:
    raise SystemExit("marketplace missing campfire-codex entry")
if entry.get("source", {}).get("path") != "./plugins/campfire-codex":
    raise SystemExit("marketplace path mismatch")
if entry.get("policy", {}).get("installation") != "AVAILABLE":
    raise SystemExit("marketplace installation policy mismatch")
if entry.get("policy", {}).get("authentication") != "ON_INSTALL":
    raise SystemExit("marketplace authentication policy mismatch")
PY

echo "PASS: Codex plugin verification completed."
