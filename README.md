# 🌐 Universal Browser Extension Auto-Installer (Additive Only)

Automate adding your browser extensions into **any PC** (Windows, macOS, Linux) for **a specific browser of your choice** (Brave, Google Chrome, Microsoft Edge, Vivaldi, or Opera).

---

## 🛡️ Safe & Additive Installation Guarantee
- **Existing extensions are ALWAYS SKIPPED:** It checks what extensions are already in your browser first. If an extension is already installed, it leaves it alone.
- **Only MISSING extensions are installed.**
- **Zero Deletion:** It **never** uninstalls, overwrites, or removes any of your existing extensions, bookmarks, passwords, or browsing data.

---

## ⚡ 1-Command Installation on a New PC

Specify your browser directly in the terminal command:

### 🪟 Windows (PowerShell)

```powershell
# For Brave:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1))) -Browser Brave

# For Google Chrome:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1))) -Browser Chrome

# For Microsoft Edge:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1))) -Browser Edge
```

*Or run interactively (it will ask you which browser you want to add extensions into):*
```powershell
irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1 | iex
```

---

### 🍎 macOS / 🐧 Linux (Terminal)

```bash
# For Brave:
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash -s -- --browser brave

# For Chrome:
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash -s -- --browser chrome
```

*Or run interactively:*
```bash
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash
```

---

## 📁 Repository Files

| File | Target OS | Description |
| :--- | :--- | :--- |
| [`extensions.json`](extensions.json) | Any | Unified list of your extension IDs, names, and store URLs. |
| [`install.ps1`](install.ps1) | Windows | Checks installed extensions, skips existing ones, and installs missing ones. |
| [`install.sh`](install.sh) | macOS / Linux | Mac/Linux equivalent: additive install for missing extensions only. |
| [`export.ps1`](export.ps1) | Windows | Scans your browser and adds any newly discovered extensions to `extensions.json`. |
| [`export.sh`](export.sh) | macOS / Linux | Mac/Linux equivalent for exporting newly added extensions. |
| [`README.md`](README.md) | Any | Documentation. |

---

## 🔄 Keeping Your List Updated

When you install a new extension on your main PC that you want included:

```powershell
# 1. Export newly installed extensions
.\export.ps1 -Browser Brave

# 2. Commit to Git (when ready to push)
git commit -am "Added new extension"
# git push
```
