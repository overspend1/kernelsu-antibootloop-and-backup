# KernelSU Anti-Bootloop & Backup Module

[![Release](https://img.shields.io/github/v/release/overspend1/kernelsu-antibootloop-and-backup?style=for-the-badge)](https://github.com/overspend1/kernelsu-antibootloop-and-backup/releases/latest)
[![License](https://img.shields.io/github/license/overspend1/kernelsu-antibootloop-and-backup?style=for-the-badge)](LICENSE)
[![MMRL](https://img.shields.io/badge/MMRL-Compatible-blue?style=for-the-badge)](https://github.com/DerGoogler/MMRL)
[![KernelSU](https://img.shields.io/badge/KernelSU-v0.7.0+-green?style=for-the-badge)](https://kernelsu.org)

**Advanced KernelSU module combining anti-bootloop protection with comprehensive backup and restoration capabilities.**

## 🚀 Quick Install via MMRL

1. **Add Repository to MMRL:**
   ```
   https://raw.githubusercontent.com/overspend1/kernelsu-antibootloop-and-backup/master/mmrl-repo/repo.json
   ```

2. **Install the Module:**
   - Open MMRL app
   - Go to **Repositories** → **KernelSU Modules**
   - Find **KernelSU Anti-Bootloop & Backup**
   - Tap **Install**

## ✨ Features

- 🛡️ **Anti-bootloop protection** with automatic recovery mechanisms
- 💾 **Comprehensive backup system** with encrypted storage
- 🌐 **WebUI interface** for easy management
- 🔒 **Encrypted backups** with hybrid RSA+AES encryption
- 🔄 **Multi-stage recovery** with escalating intervention levels
- 📱 **OverlayFS integration** leveraging KernelSU's kernel-level capabilities
- 🔘 **Hardware button recovery** using volume buttons for emergency access
- 📱 **Progressive Web App** with Material Design interface

## 📋 Requirements

- **Android API:** 33-35 (Android 13-15)
- **KernelSU:** v0.7.0+ (version code 10940+)
- **Architecture:** ARM64
- **Root Manager:** KernelSU (Magisk not supported)

## 🔧 Manual Installation

1. Download the latest release ZIP from [Releases](https://github.com/overspend1/kernelsu-antibootloop-and-backup/releases/latest)
2. Install via KernelSU Manager:
   - Open KernelSU Manager
   - Go to **Modules** tab
   - Tap **Install from storage**
   - Select the downloaded ZIP file
3. Reboot your device
4. Access WebUI through KernelSU manager

## 🏗️ Development & Releases

This repository uses automated GitHub Actions workflows for releases and MMRL integration:

### 🤖 Automated Release Process

1. **Create Release:**
   ```bash
   # Using the provided script
   ./create-release.ps1 -Version "v1.1.0"
   
   # Or manually create a git tag
   git tag v1.1.0
   git push origin v1.1.0
   ```

2. **What Happens Automatically:**
   - GitHub Actions builds the module ZIP
   - Creates a GitHub release with changelog
   - Updates MMRL repository files
   - Deploys to GitHub Pages
   - Users get automatic updates via MMRL

### 📦 Repository Structure

```
├── .github/workflows/          # GitHub Actions workflows
│   ├── release.yml            # Automated release creation
│   └── update-mmrl.yml        # MMRL repository updates
├── kernelsu_antibootloop_backup/  # Main module directory
│   ├── META-INF/              # Module metadata
│   ├── scripts/               # Installation scripts
│   ├── webroot/               # WebUI files
│   ├── module.prop            # Module properties
│   └── ...
├── mmrl-repo/                 # MMRL repository files
│   ├── repo.json             # Repository metadata
│   ├── modules.json          # Module listings
│   └── README.md             # Repository documentation
├── create-release.ps1         # Release creation script
└── README.md                 # This file
```

## 🌐 MMRL Repository

This repository automatically maintains an MMRL-compatible repository at:

**Repository URL:** `https://raw.githubusercontent.com/overspend1/kernelsu-antibootloop-and-backup/master/mmrl-repo/repo.json`

### Features:
- ✅ Automatic updates when new releases are created
- ✅ Proper version tracking and changelog integration
- ✅ GitHub Pages deployment for fast access
- ✅ JSON validation to ensure compatibility

## 🛠️ Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Test thoroughly
5. Commit: `git commit -m 'Add amazing feature'`
6. Push: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Support

- **Issues:** [GitHub Issues](https://github.com/overspend1/kernelsu-antibootloop-and-backup/issues)
- **Discussions:** [GitHub Discussions](https://github.com/overspend1/kernelsu-antibootloop-and-backup/discussions)
- **Donations:** [GitHub Sponsors](https://github.com/sponsors/overspend1)

## 🏷️ Version History

- **v1.0.0** - Initial release with anti-bootloop protection and backup system

---

Advanced Android System Modifications