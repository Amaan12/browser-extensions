#!/usr/bin/env bash
# Universal Browser Extension Exporter for macOS and Linux
# Scans local browser profiles and exports Chrome Web Store extensions to extensions.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null || pwd)" && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/extensions.json"
OS="$(uname -s)"

# Define search candidates per OS
CANDIDATES=()
if [[ "$OS" == "Darwin" ]]; then
    CANDIDATES=(
        "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default/Secure Preferences"
        "$HOME/Library/Application Support/Google/Chrome/Default/Secure Preferences"
        "$HOME/Library/Application Support/Microsoft Edge/Default/Secure Preferences"
        "$HOME/Library/Application Support/Vivaldi/Default/Secure Preferences"
    )
elif [[ "$OS" == "Linux" ]]; then
    CANDIDATES=(
        "$HOME/.config/BraveSoftware/Brave-Browser/Default/Secure Preferences"
        "$HOME/.config/google-chrome/Default/Secure Preferences"
        "$HOME/.config/microsoft-edge/Default/Secure Preferences"
        "$HOME/.config/chromium/Default/Secure Preferences"
        "$HOME/.config/vivaldi/Default/Secure Preferences"
    )
fi

TARGET_FILE=""
for c in "${CANDIDATES[@]}"; do
    if [[ -f "$c" ]]; then
        TARGET_FILE="$c"
        echo "Found browser profile: $c"
        break
    fi
done

if [[ -z "$TARGET_FILE" ]]; then
    echo "Error: Could not locate browser preferences file."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required to parse JSON."
    exit 1
fi

python3 -c "
import json, sys

with open('$TARGET_FILE', 'r', encoding='utf-8') as f:
    data = json.load(f)

ext_settings = data.get('extensions', {}).get('settings', {})
results = []

for ext_id, ext_data in ext_settings.items():
    if ext_data.get('from_webstore') is True:
        name = ext_data.get('manifest', {}).get('name')
        if name and not name.startswith('__MSG_'):
            results.append({
                'id': ext_id,
                'name': name,
                'url': f'https://chromewebstore.google.com/detail/{ext_id}'
            })

results.sort(key=lambda x: x['name'].lower())

with open('$OUTPUT_FILE', 'w', encoding='utf-8') as out:
    json.dump(results, out, indent=2)

print(f'Successfully exported {len(results)} extensions to $OUTPUT_FILE')
"
