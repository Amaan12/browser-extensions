#!/usr/bin/env bash
# Smart Additive Browser Extension Installer for macOS and Linux
# - Compares against existing extensions in the browser profile
# - Automatically SKIPS extensions that are already present
# - ONLY installs missing extensions

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

# --- 2. Load Extension List from JSON ---
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

# --- 3. Find Profile & Filter Already-Installed Extensions ---
PROFILE_PATH=""
if [[ "$OS" == "Darwin" ]]; then
    declare -A MAC_PROFILES=(
        ["Brave"]="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default"
        ["Chrome"]="$HOME/Library/Application Support/Google/Chrome/Default"
        ["Edge"]="$HOME/Library/Application Support/Microsoft Edge/Default"
        ["Chromium"]="$HOME/Library/Application Support/Chromium/Default"
        ["Vivaldi"]="$HOME/Library/Application Support/Vivaldi/Default"
    )
    PROFILE_PATH="${MAC_PROFILES[$TARGET_BROWSER]}"
elif [[ "$OS" == "Linux" ]]; then
    declare -A LINUX_PROFILES=(
        ["Brave"]="$HOME/.config/BraveSoftware/Brave-Browser/Default"
        ["Chrome"]="$HOME/.config/google-chrome/Default"
        ["Edge"]="$HOME/.config/microsoft-edge/Default"
        ["Chromium"]="$HOME/.config/chromium/Default"
        ["Vivaldi"]="$HOME/.config/vivaldi/Default"
    )
    PROFILE_PATH="${LINUX_PROFILES[$TARGET_BROWSER]}"
fi

# Differential check via Python
DIFF_OUTPUT=$(python3 -c "
import json, os, sys

ext_data = json.loads('''$EXT_DATA''')
installed_ids = set()

profile_dir = '$PROFILE_PATH'
pref_files = [os.path.join(profile_dir, 'Secure Preferences'), os.path.join(profile_dir, 'Preferences')]

for pf in pref_files:
    if os.path.exists(pf):
        try:
            with open(pf, 'r', encoding='utf-8') as f:
                d = json.load(f)
                installed_ids.update(d.get('extensions', {}).get('settings', {}).keys())
        except Exception:
            pass

ext_dir = os.path.join(profile_dir, 'Extensions')
if os.path.exists(ext_dir):
    for name in os.listdir(ext_dir):
        if os.path.isdir(os.path.join(ext_dir, name)):
            installed_ids.add(name)

missing = []
present = []

for item in ext_data:
    eid = item.get('id', '')
    if eid in installed_ids:
        present.append(item.get('name', eid))
    else:
        missing.append(item)

print(json.dumps({'missing': missing, 'present': present}))
" 2>/dev/null || echo '{"missing": [], "present": []}')

# Parse diff output
MISSING_COUNT=$(python3 -c "import json; d=json.loads('''$DIFF_OUTPUT'''); print(len(d['missing']))" 2>/dev/null || echo "0")
PRESENT_COUNT=$(python3 -c "import json; d=json.loads('''$DIFF_OUTPUT'''); print(len(d['present']))" 2>/dev/null || echo "0")

if [[ "$PRESENT_COUNT" -gt 0 ]]; then
    echo -e "\033[0;90m[SKIPPED] Already installed in $TARGET_BROWSER ($PRESENT_COUNT extensions)\033[0m"
fi

if [[ "$MISSING_COUNT" -eq 0 && "$PRESENT_COUNT" -gt 0 ]]; then
    echo -e "\033[0;32m[ALL SET] All extensions are already installed in $TARGET_BROWSER! Nothing to do.\033[0m"
    exit 0
fi

echo -e "\033[0;36m[TO INSTALL] Missing extensions ($MISSING_COUNT):\033[0m"

MISSING_IDS=()
MISSING_URLS=()
while IFS="|" read -r id url name; do
    if [[ -n "$id" ]]; then
        MISSING_IDS+=("$id")
        MISSING_URLS+=("$url")
        echo -e " \033[0;32m+ $name ($id)\033[0m"
    fi
done < <(python3 -c "
import json
d = json.loads('''$DIFF_OUTPUT''')
for item in d['missing']:
    print(f\"{item.get('id')}|{item.get('url')}|{item.get('name')}\")
")

UPDATE_URL="https://clients2.google.com/service/update2/crx"

# --- 4. Install Missing Extensions ---
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
        open -a "$TARGET_BROWSER" "${MISSING_URLS[@]}" || true
    else
        echo "Adding missing extensions to managed policy for $TARGET_BROWSER ($bundle_id)..."
        POLICY_ITEMS=()
        for id in "${MISSING_IDS[@]}"; do
            POLICY_ITEMS+=("${id};${UPDATE_URL}")
        done
        defaults write "$bundle_id" ExtensionInstallForcelist -array-add "${POLICY_ITEMS[@]}"
        echo -e "\033[0;32m [x] Configured $TARGET_BROWSER successfully.\033[0m"
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
        for url in "${MISSING_URLS[@]}"; do
            xdg-open "$url" >/dev/null 2>&1 || true
        done
        echo -e "\033[0;32mTabs opened via xdg-open!\033[0m"
        exit 0
    fi

    echo "Configuring managed policy for $TARGET_BROWSER in $dir..."
    JSON_ENTRIES=()
    for id in "${MISSING_IDS[@]}"; do
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

echo -e "\n\033[0;32m[SUCCESS] Done! Restart $TARGET_BROWSER to auto-download the missing extensions.\033[0m"
