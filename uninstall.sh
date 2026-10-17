#!/usr/bin/env bash
# Cleans up extension policies created by install.sh on macOS and Linux
# Removes the managed ExtensionInstallForcelist so the browser uninstalls them.

OS="$(uname -s)"
TARGET_BROWSER="$1"
SUPPORTED=("Brave" "Chrome" "Edge" "Chromium" "Vivaldi" "All")

if [[ -z "$TARGET_BROWSER" ]]; then
    echo -e "\033[0;36mSelect which browser's extension policy you want to remove:\033[0m"
    for i in "${!SUPPORTED[@]}"; do
        echo "  [$((i + 1))] ${SUPPORTED[$i]}"
    done
    read -rp "Enter selection [1-${#SUPPORTED[@]}]: " CHOICE
    CHOICE=${CHOICE:-1}
    IDX=$((CHOICE - 1))
    TARGET_BROWSER="${SUPPORTED[$IDX]}"
fi

if [[ "$OS" == "Darwin" ]]; then
    declare -A MAC_BUNDLES=(
        ["Brave"]="com.brave.Browser"
        ["Chrome"]="com.google.Chrome"
        ["Edge"]="com.microsoft.Edge"
        ["Chromium"]="org.chromium.Chromium"
        ["Vivaldi"]="com.vivaldi.Vivaldi"
    )
    for b in "${!MAC_BUNDLES[@]}"; do
        if [[ "${TARGET_BROWSER,,}" != "all" && "${TARGET_BROWSER,,}" != "${b,,}" ]]; then
            continue
        fi
        bundle="${MAC_BUNDLES[$b]}"
        defaults delete "$bundle" ExtensionInstallForcelist 2>/dev/null && echo "Deleted policy for $b ($bundle)" || true
    done

elif [[ "$OS" == "Linux" ]]; then
    declare -A LINUX_FILES=(
        ["Brave"]="/etc/brave/policies/managed/extensions.json"
        ["Chrome"]="/etc/opt/chrome/policies/managed/extensions.json"
        ["Edge"]="/etc/opt/edge/policies/managed/extensions.json"
        ["Chromium"]="/etc/chromium/policies/managed/extensions.json"
        ["Vivaldi"]="/etc/vivaldi/policies/managed/extensions.json"
    )
    for b in "${!LINUX_FILES[@]}"; do
        if [[ "${TARGET_BROWSER,,}" != "all" && "${TARGET_BROWSER,,}" != "${b,,}" ]]; then
            continue
        fi
        path="${LINUX_FILES[$b]}"
        if [[ -f "$path" ]]; then
            if [[ "$EUID" -eq 0 ]]; then
                rm -f "$path"
            else
                sudo rm -f "$path"
            fi
            echo "Removed policy file: $path"
        fi
    done
fi

echo -e "\n\033[0;32mPolicy cleanup finished for $TARGET_BROWSER.\033[0m"
echo -e "\033[0;33mWhen you next start the browser, the forced extensions will be automatically uninstalled.\033[0m"
