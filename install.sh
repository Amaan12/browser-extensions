#!/usr/bin/env bash
# Universal Browser Extension Installer for macOS and Linux
# Supports: Brave, Google Chrome, Microsoft Edge, Chromium, Vivaldi

set -e

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null || pwd)" && pwd)"
JSON_FILE="${SCRIPT_DIR}/extensions.json"
OPEN_TABS=false
TARGET_BROWSER="all"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --open-tabs) OPEN_TABS=true; shift ;;
        --browser) TARGET_BROWSER="$2"; shift 2 ;;
        --source) JSON_FILE="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

# 1. Resolve Extension Data
if [[ -f "$JSON_FILE" ]]; then
    EXT_DATA=$(cat "$JSON_FILE")
elif [[ "$JSON_FILE" =~ ^https?:// ]]; then
    echo -e "\033[0;36mFetching extensions from $JSON_FILE...\033[0m"
    EXT_DATA=$(curl -fsSL "$JSON_FILE")
else
    echo -e "\033[0;33mLocal extensions.json not found (remote stream mode).\033[0m"
    read -rp "Enter your GitHub username (or full raw URL to extensions.json): " USER_INPUT
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

# Extract IDs and URLs using python3, jq, or grep/sed
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
    # Fallback extractor if python3 is not present
    while IFS= read -r line; do
        id=$(echo "$line" | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p')
        [[ -n "$id" ]] && EXT_IDS+=("$id")
    done <<< "$EXT_DATA"
fi

echo -e "\033[0;32mLoaded ${#EXT_IDS[@]} extensions:\033[0m"
for i in "${!EXT_IDS[@]}"; do
    echo " - ${EXT_NAMES[$i]:-Extension} (${EXT_IDS[$i]})"
done
echo ""

UPDATE_URL="https://clients2.google.com/service/update2/crx"

# --- macOS Handler ---
if [[ "$OS" == "Darwin" ]]; then
    echo -e "\033[0;36mRunning on macOS...\033[0m"

    declare -A MAC_BUNDLES=(
        ["Brave"]="com.brave.Browser"
        ["Chrome"]="com.google.Chrome"
        ["Edge"]="com.microsoft.Edge"
        ["Chromium"]="org.chromium.Chromium"
        ["Vivaldi"]="com.vivaldi.Vivaldi"
    )

    for b in "${!MAC_BUNDLES[@]}"; do
        if [[ "$TARGET_BROWSER" != "all" && "${TARGET_BROWSER,,}" != "${b,,}" ]]; then
            continue
        fi

        bundle_id="${MAC_BUNDLES[$b]}"
        if [[ "$OPEN_TABS" == true ]]; then
            echo "Opening tabs in $b..."
            open -a "$b" "${EXT_URLS[@]}" || true
        else
            echo "Configuring managed preferences for $b ($bundle_id)..."
            # Build array of id;update_url
            POLICY_ITEMS=()
            for id in "${EXT_IDS[@]}"; do
                POLICY_ITEMS+=("${id};${UPDATE_URL}")
            done
            defaults write "$bundle_id" ExtensionInstallForcelist -array "${POLICY_ITEMS[@]}"
            echo -e "\033[0;32m [x] Configured $b policy successfully.\033[0m"
        fi
    done

# --- Linux Handler ---
elif [[ "$OS" == "Linux" ]]; then
    echo -e "\033[0;36mRunning on Linux...\033[0m"

    declare -A LINUX_DIRS=(
        ["Brave"]="/etc/brave/policies/managed"
        ["Chrome"]="/etc/opt/chrome/policies/managed"
        ["Edge"]="/etc/opt/edge/policies/managed"
        ["Chromium"]="/etc/chromium/policies/managed"
        ["Vivaldi"]="/etc/vivaldi/policies/managed"
    )

    if [[ "$OPEN_TABS" == true ]]; then
        for url in "${EXT_URLS[@]}"; do
            xdg-open "$url" >/dev/null 2>&1 || true
        done
        echo -e "\033[0;32mTabs opened via xdg-open!\033[0m"
        exit 0
    fi

    for b in "${!LINUX_DIRS[@]}"; do
        if [[ "$TARGET_BROWSER" != "all" && "${TARGET_BROWSER,,}" != "${b,,}" ]]; then
            continue
        fi

        dir="${LINUX_DIRS[$b]}"
        echo "Creating managed policy for $b in $dir..."

        # Format JSON policy
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
            echo "Skipping $b: root/sudo permissions needed to write to $dir"
            continue
        fi

        echo -e "\033[0;32m [x] Configured $b policy successfully in ${dir}/extensions.json\033[0m"
    done
fi

echo -e "\n\033[0;32m[SUCCESS] Done! Restart your browser to auto-install all extensions.\033[0m"
