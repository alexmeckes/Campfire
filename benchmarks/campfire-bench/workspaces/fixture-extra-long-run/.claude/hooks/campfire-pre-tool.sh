#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_FILE="$ROOT_DIR/.campfire/registry.json"
HOOK_HELPER="$SCRIPT_DIR/campfire-hook-helper.py"

RESULT_JSON="$(python3 "$HOOK_HELPER" guard-action "$REGISTRY_FILE")"

python3 - "$RESULT_JSON" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
action = payload.get("action", "allow")
reason = str(payload.get("reason", "")).strip()

if action == "block":
    if reason:
        print(reason, file=sys.stderr)
    raise SystemExit(2)
PY
