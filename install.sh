#!/usr/bin/env bash
# Universal Browser Extension Installer for macOS and Linux
# Installs extensions into a single chosen browser (Brave, Chrome, Edge, Chromium, Vivaldi)

set -e

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null || pwd)" && pwd)"
JSON_FILE="${SCRIPT_DIR}/extensions.json"
OPEN_TABS=false
TARGET_BROWSER=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --open-tabs) OPEN_TABS=true; shift ;;
        --browser) TARGET_BROWSER="$2"; shift 2 ;;
        --source) JSON_FILE="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

# --- 1. Select Browser ---
SUPPORTED=("Brave" "Chrome" "Edge" "Chromium" "Vivaldi")

if [[ -z "$TARGET_BROWSER" ]]; then
    echo -e "\033[0;36mChoose which browser to install extensions into:\033[0m"
    for i in "${!SUPPORTED[@]}"; do
        echo "  [$((i + 1))] ${SUPPORTED[$i]}"
    done
    read -rp "Enter selection [1-${#SUPPORTED[@]}] (default: 1): " CHOICE
    CHOICE=${CHOICE:-1}
    IDX=$((CHOICE - 1))
    TARGET_BROWSER="${SUPPORTED[$IDX]}"
fi

# Normalize case
MATCHED=""
for b in "${SUPPORTED[@]}"; do
    if [[ "${b,,}" == "${TARGET_BROWSER,,}" ]]; then
        MATCHED="$b"
        break
    fi
done

if [[ -z "$MATCHED" ]]; then
    echo "Error: Unsupported browser '$TARGET_BROWSER'. Supported: ${SUPPORTED[*]}"
    exit 1
fi
TARGET_BROWSER="$MATCHED"
echo -e "\033[0;32mTarget Browser: $TARGET_BROWSER\033[0m\n"

# --- 2. Resolve Extension Data ---
if [[ -f "$JSON_FILE" ]]; then
    EXT_DATA=$(cat "$JSON_FILE")
elif [[ "$JSON_FILE" =~ ^https?:// ]]; then
    echo -e "\033[0;36mFetching extensions from $JSON_FILE...\033[0m"
    EXT_DATA=$(curl -fsSL "$JSON_FILE")
else
    echo -e "\033[0;33mLocal extensions.json not found.\033[0m"
    read -rp "Enter your GitHub username (or raw URL to extensions.json): " USER_INPUT
    if [[ "$USER_INPUT" =~ ^https?:// ]]; then
        EXT_DATA=$(curl -fsSL "$USER_INPUT")
    else
        read -rp "Enter repository name [default: browser-extensions-sync]: " REPO_INPUT
        REPO_INPUT=${REPO_INPUT:-browser-extensions-sync}
        RAW_URL="https://raw.githubusercontent.com/${USER_INPUT}/${REPO_INPUT}/main/extensions.json"
        echo -e "\033[0;36mFetching: $RAW_URL\033[0m"
        EXT_DATA=$(curl -fsSL "$RAW_URL")
    fi
fi

EXT_IDS=()
EXT_NAMES=()
EXT_URLS=()

if command -v python3 >/dev/null 2>&1; then
    while IFS="|" read -r id name url; do
        EXT_IDS+=("$id")
        EXT_NAMES+=("$name")
        EXT_URLS+=("$url")
    done < <(python3 -c "
import json, sys
data = json.loads('''$EXT_DATA''')
for item in data:
    print(f\"{item.get('id', '')}|{item.get('name', '')}|{item.get('url', '')}\")
")
else
    while IFS= read -r line; do
        id=$(echo "$line" | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p')
        [[ -n "$id" ]] && EXT_IDS+=("$id")
    done <<< "$EXT_DATA"
fi

echo -e "\033[0;32mLoaded ${#EXT_IDS[@]} extensions to install.\033[0m"

UPDATE_URL="https://clients2.google.com/service/update2/crx"

# --- 3. Execute Installation for Selected Browser ---
if [[ "$OS" == "Darwin" ]]; then
    declare -A MAC_BUNDLES=(
        ["Brave"]="com.brave.Browser"
        ["Chrome"]="com.google.Chrome"
        ["Edge"]="com.microsoft.Edge"
        ["Chromium"]="org.chromium.Chromium"
        ["Vivaldi"]="com.vivaldi.Vivaldi"
    )
    bundle_id="${MAC_BUNDLES[$TARGET_BROWSER]}"

    if [[ "$OPEN_TABS" == true ]]; then
        echo "Opening tabs in $TARGET_BROWSER..."
        open -a "$TARGET_BROWSER" "${EXT_URLS[@]}" || true
    else
        echo "Configuring managed preferences for $TARGET_BROWSER ($bundle_id)..."
        POLICY_ITEMS=()
        for id in "${EXT_IDS[@]}"; do
            POLICY_ITEMS+=("${id};${UPDATE_URL}")
        done
        defaults write "$bundle_id" ExtensionInstallForcelist -array "${POLICY_ITEMS[@]}"
        echo -e "\033[0;32m [x] Configured $TARGET_BROWSER policy successfully.\033[0m"
    fi

elif [[ "$OS" == "Linux" ]]; then
    declare -A LINUX_DIRS=(
        ["Brave"]="/etc/brave/policies/managed"
        ["Chrome"]="/etc/opt/chrome/policies/managed"
        ["Edge"]="/etc/opt/edge/policies/managed"
        ["Chromium"]="/etc/chromium/policies/managed"
        ["Vivaldi"]="/etc/vivaldi/policies/managed"
    )
    dir="${LINUX_DIRS[$TARGET_BROWSER]}"

    if [[ "$OPEN_TABS" == true ]]; then
        for url in "${EXT_URLS[@]}"; do
            xdg-open "$url" >/dev/null 2>&1 || true
        done
        echo -e "\033[0;32mTabs opened via xdg-open!\033[0m"
        exit 0
    fi

    echo "Configuring managed policy for $TARGET_BROWSER in $dir..."
    JSON_ENTRIES=()
    for id in "${EXT_IDS[@]}"; do
        JSON_ENTRIES+=("\"${id};${UPDATE_URL}\"")
    done
    JOINED_ENTRIES=$(IFS=,; echo "${JSON_ENTRIES[*]}")
    POLICY_JSON="{\"ExtensionInstallForcelist\": [${JOINED_ENTRIES}]}"

    if [[ "$EUID" -eq 0 ]]; then
        mkdir -p "$dir"
        echo "$POLICY_JSON" > "${dir}/extensions.json"
    elif command -v sudo >/dev/null 2>&1; then
        sudo mkdir -p "$dir"
        echo "$POLICY_JSON" | sudo tee "${dir}/extensions.json" >/dev/null
    else
        echo "Error: root/sudo permissions needed to write to $dir"
        exit 1
    fi
    echo -e "\033[0;32m [x] Configured $TARGET_BROWSER policy in ${dir}/extensions.json\033[0m"
fi

echo -e "\n\033[0;32m[SUCCESS] Done! Next time you launch $TARGET_BROWSER, all extensions will auto-install.\033[0m"
