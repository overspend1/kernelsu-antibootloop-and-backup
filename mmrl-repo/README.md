# Terragon Labs MMRL Repository

This is an MMRL (Magisk Module Repository List) repository containing KernelSU modules developed by Terragon Labs.

## Available Modules

### KernelSU Anti-Bootloop & Backup

**Advanced KernelSU module combining anti-bootloop protection with comprehensive backup and restoration capabilities.**

#### Features:
- 🛡️ **Anti-bootloop protection** with automatic recovery mechanisms
- 💾 **Comprehensive backup system** with encrypted storage
- 🌐 **WebUI interface** for easy management
- 🔒 **Encrypted backups** with hybrid RSA+AES encryption
- 🔄 **Multi-stage recovery** with escalating intervention levels
- 📱 **OverlayFS integration** leveraging KernelSU's kernel-level capabilities
- 🔘 **Hardware button recovery** using volume buttons for emergency access
- 📱 **Progressive Web App** with Material Design interface

#### Requirements:
- Android API 33-35
- KernelSU v0.7.0+ (version code 10940+)
- ARM64 architecture

#### Installation:
1. Add this repository to MMRL app
2. Search for "KernelSU Anti-Bootloop & Backup"
3. Install the module
4. Reboot your device
5. Access the WebUI through KernelSU manager or browser

## How to Add This Repository to MMRL

1. Open MMRL app
2. Go to **Settings** → **Repositories**
3. Tap **Add Repository**
4. Enter the repository URL:
   ```
   https://raw.githubusercontent.com/terragon-labs/mmrl-repo/main/repo.json
   ```
5. Tap **Add** and wait for the repository to sync

## Repository Structure

```
mmrl-repo/
├── repo.json      # Repository metadata
├── modules.json   # Module definitions
└── README.md      # This file
```

## Support

- **Issues**: [GitHub Issues](https://github.com/terragon-labs/kernelsu-antibootloop-backup/issues)
- **Discussions**: [GitHub Discussions](https://github.com/terragon-labs/kernelsu-antibootloop-backup/discussions)
- **Donations**: [GitHub Sponsors](https://github.com/sponsors/terragon-labs)

## License

MIT License - see individual module repositories for specific licensing information.

---

**Terragon Labs** - Advanced Android System Modifications