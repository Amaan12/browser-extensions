# 🚀 Browser Extensions Sync & Auto-Installer

Automate exporting and installing your browser extensions on any new PC or browser with a single terminal command.

Supports **Brave** (default), **Google Chrome**, and **Microsoft Edge** on Windows.

---

## ⚡ Quick Start (Installing on a New PC)

### Option A: One-Liner (No Git clone needed)
Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/<YOUR_GITHUB_USERNAME>/brave-extensions-sync/main/install.ps1 | iex
```

### Option B: Clone & Run
```powershell
git clone https://github.com/<YOUR_GITHUB_USERNAME>/brave-extensions-sync.git
cd brave-extensions-sync
.\install.ps1
```

*When you launch Brave, it will automatically download and install every extension in the list silently.*

---

## 🛠️ Repository Contents

| File | Description |
| :--- | :--- |
| [`extensions.json`](extensions.json) | The list of extension IDs, human-readable names, and Web Store URLs. |
| [`export.ps1`](export.ps1) | Automatically extracts installed extensions from your current Brave browser and updates `extensions.json`. |
| [`install.ps1`](install.ps1) | Configures the browser's `ExtensionInstallForcelist` policy so extensions auto-install on launch. |
| [`uninstall.ps1`](uninstall.ps1) | Cleans up the registry policy if you wish to remove the managed extension rules. |

---

## 📤 How to Push This to Your GitHub

1. Create a new repository on GitHub (e.g. `brave-extensions-sync`).
2. In this folder, initialize and push:

```bash
git init
git add .
git commit -m "Initial commit of extension sync scripts"
git branch -M main
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/brave-extensions-sync.git
git push -u origin main
```

---

## 🔄 Updating Your List When You Add Extensions

Whenever you install new extensions in Brave on your daily machine:

```powershell
# 1. Re-export your current extensions
.\export.ps1

# 2. Commit and push to GitHub
git commit -am "Update extensions list"
git push
```

---

## ⚙️ Advanced Options for `install.ps1`

### 1. Target Chrome or Edge instead of Brave:
```powershell
.\install.ps1 -Browser Chrome
# or
.\install.ps1 -Browser Edge
```

### 2. Open all store links in tabs instead of registry policy:
If you prefer standard installations that you can freely turn on/off without policy management:
```powershell
.\install.ps1 -OpenTabs
```

### 3. Clean up / Remove Policies:
```powershell
.\uninstall.ps1
```
