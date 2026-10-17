# 🌐 Universal Browser Extension Sync & Auto-Installer

Automate exporting and installing your browser extensions on **any PC** (Windows, macOS, Linux) and **any Chromium browser** (Brave, Google Chrome, Microsoft Edge, Vivaldi, Opera) with a single terminal command.

Your 16 current extensions are already exported and saved in [`extensions.json`](extensions.json).

---

## ⚡ Quick Start: 1-Command Install on a New PC

### 🪟 On Any Windows PC (PowerShell)
Run this single command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/<YOUR_GITHUB_USER>/<REPO>/main/install.ps1 | iex
```

*Or if you clone the repo:*
```powershell
git clone https://github.com/<YOUR_GITHUB_USER>/<REPO>.git
cd <REPO>
.\install.ps1
```

### 🍎 On macOS or 🐧 Linux (Terminal)
Run this single command in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/<YOUR_GITHUB_USER>/<REPO>/main/install.sh | bash
```

*Or if you clone the repo:*
```bash
git clone https://github.com/<YOUR_GITHUB_USER>/<REPO>.git
cd <REPO>
chmod +x install.sh
./install.sh
```

---

## 💡 How It Works
Chromium browsers (Brave, Chrome, Edge, Vivaldi, Opera) share the same underlying architecture and extension IDs.

When you run `install.ps1` (or `install.sh`), it:
1. **Auto-detects** all installed browsers on that PC.
2. Applies the `ExtensionInstallForcelist` enterprise policy.
3. Next time you launch Brave or any other browser, it **automatically, silently downloads and installs all extensions from the Chrome Web Store**.

---

## 📁 Repository Structure

| File | Target OS | Description |
| :--- | :--- | :--- |
| [`extensions.json`](extensions.json) | Any | Unified list of extension IDs, names, and Web Store URLs. |
| [`install.ps1`](install.ps1) | Windows | Auto-detects browsers and installs all extensions silently via registry policy. |
| [`install.sh`](install.sh) | macOS / Linux | Configures managed policies across macOS / Linux browsers. |
| [`export.ps1`](export.ps1) | Windows | Scans your browser profiles and updates `extensions.json` when you add new extensions. |
| [`export.sh`](export.sh) | macOS / Linux | Linux/Mac equivalent to extract extensions into `extensions.json`. |
| [`uninstall.ps1`](uninstall.ps1) | Windows | Cleans up the policy from Windows Registry if you want manual control back. |
| [`uninstall.sh`](uninstall.sh) | macOS / Linux | Cleans up the policy files or defaults on macOS/Linux. |

---

## 🔄 Keeping Your Extensions in Sync

Whenever you add or change extensions in Brave or another browser on your main machine:

**On Windows:**
```powershell
.\export.ps1
git commit -am "Update extensions list"
git push
```

**On Mac/Linux:**
```bash
./export.sh
git commit -am "Update extensions list"
git push
```

---

## ⚙️ Advanced CLI Options

### 1. Target a specific browser instead of all detected:
- **Windows:**
  ```powershell
  .\install.ps1 -Browser Brave
  .\install.ps1 -Browser Chrome
  .\install.ps1 -Browser Edge
  ```
- **Mac / Linux:**
  ```bash
  ./install.sh --browser brave
  ./install.sh --browser chrome
  ```

### 2. Open store pages in tabs instead of enterprise policy:
If you don't want managed policies and just want tabs opened side-by-side so you can click "Add to browser":
- **Windows:** `.\install.ps1 -OpenTabs`
- **Mac / Linux:** `./install.sh --open-tabs`

### 3. Remove / Reset Policies:
- **Windows:** `.\uninstall.ps1`
- **Mac / Linux:** `./uninstall.sh`
