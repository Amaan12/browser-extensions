# 🌐 Universal Browser Extension Sync & Auto-Installer

Automate exporting and installing your browser extensions on **any PC** (Windows, macOS, Linux) into **a specific browser of your choice** (Brave, Google Chrome, Microsoft Edge, Vivaldi, or Opera).

Your 16 current extensions are saved in [`extensions.json`](extensions.json).

---

## ⚡ 1-Command Installation on a New PC

You can specify the target browser directly in your terminal command:

### 🪟 Windows (PowerShell)

**Specify the browser directly:**
```powershell
# For Brave:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1))) -Browser Brave

# For Chrome:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1))) -Browser Chrome

# For Edge:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1))) -Browser Edge
```

**Or run interactively (it will ask you to choose 1 browser):**
```powershell
irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1 | iex
```

---

### 🍎 macOS / 🐧 Linux (Terminal)

**Specify the browser directly:**
```bash
# For Brave:
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash -s -- --browser brave

# For Chrome:
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash -s -- --browser chrome

# For Edge:
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash -s -- --browser edge
```

**Or run interactively (it will ask you to choose 1 browser):**
```bash
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash
```

---

## ❓ What Does "Uninstall" Mean? (How It Works)

### How "Install" works:
When you run `install.ps1`, it writes the extensions to the browser's **`ExtensionInstallForcelist`** policy (in Windows Registry or Mac/Linux managed policy directories).
- The browser downloads and installs them silently from the Chrome Web Store.
- Because it is configured as a policy, the extensions are marked as "managed by your organization" so they cannot be accidentally removed or disabled.

### What "Uninstall" does:
When you run `uninstall.ps1` (or `uninstall.sh`):
1. **It removes only that policy key from your system.**
2. The next time you open that browser, Chromium checks the policy list, sees that those extensions are no longer mandated, and **automatically deletes / uninstalls those extensions from the browser**.
3. **What is NOT touched:** It will **never** touch your bookmarks, browsing history, saved passwords, cookies, or any other personal browser data.

---

## 📁 Repository Structure

| File | Target OS | Description |
| :--- | :--- | :--- |
| [`extensions.json`](extensions.json) | Any | Unified list of extension IDs, names, and Web Store URLs. |
| [`install.ps1`](install.ps1) | Windows | Installs extensions into a specified browser (or interactive choice). |
| [`install.sh`](install.sh) | macOS / Linux | Installs extensions into a specified browser on Mac/Linux. |
| [`export.ps1`](export.ps1) | Windows | Scans your browser profile and updates `extensions.json` when you add new extensions. |
| [`export.sh`](export.sh) | macOS / Linux | Linux/Mac equivalent to export your extensions. |
| [`uninstall.ps1`](uninstall.ps1) | Windows | Removes the auto-install policy for a chosen browser, causing the browser to uninstall them. |
| [`uninstall.sh`](uninstall.sh) | macOS / Linux | Removes managed policy files or defaults on Mac/Linux. |
| [`README.md`](README.md) | Any | Documentation and usage examples. |

---

## 🔄 Keeping Your Extensions Updated

Whenever you install new extensions in your browser and want to sync them:

**On Windows:**
```powershell
.\export.ps1 -Browser Brave
git commit -am "Update extensions list"
# git push (when ready)
```

**On Mac/Linux:**
```bash
./export.sh
git commit -am "Update extensions list"
# git push (when ready)
```

---

## ⚙️ Advanced CLI Options

### Interactive vs Explicit in local clone:
```powershell
# Prompt interactively:
.\install.ps1

# Target a specific browser:
.\install.ps1 -Browser Brave

# Open store pages as tabs instead of managed policy:
.\install.ps1 -Browser Brave -OpenTabs

# Clean up / remove policy for a specific browser:
.\uninstall.ps1 -Browser Brave
```
