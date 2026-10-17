#!/usr/bin/env bash
# Cleans up extension policies created by install.sh on macOS and Linux

OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
    for bundle in com.brave.Browser com.google.Chrome com.microsoft.Edge org.chromium.Chromium com.vivaldi.Vivaldi; do
        defaults delete "$bundle" ExtensionInstallForcelist 2>/dev/null && echo "Deleted policy for $bundle" || true
    done
elif [[ "$OS" == "Linux" ]]; then
    for path in \
        /etc/brave/policies/managed/extensions.json \
        /etc/opt/chrome/policies/managed/extensions.json \
        /etc/opt/edge/policies/managed/extensions.json \
        /etc/chromium/policies/managed/extensions.json \
        /etc/vivaldi/policies/managed/extensions.json; do
        if [[ -f "$path" ]]; then
            if [[ "$EUID" -eq 0 ]]; then
                rm -f "$path"
            else
                sudo rm -f "$path"
            fi
            echo "Removed $path"
        fi
    done
fi

echo "Policy cleanup finished."
