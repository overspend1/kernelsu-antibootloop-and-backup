# MMRL Integration Guide

This guide will help you set up your MMRL repository and integrate it with the MMRL app for managing your KernelSU modules.

## 🚀 Quick Setup

### Step 1: Create GitHub Repository

1. Go to [GitHub](https://github.com) and create a new repository
2. Name it something like `mmrl-repo` or `kernelsu-modules`
3. Make it **public** (required for MMRL to access it)
4. Don't initialize with README (we already have files)

### Step 2: Upload Repository Files

**Option A: Using the Setup Scripts**
1. Run `setup-repo.ps1` (PowerShell) or `setup-repo.bat` (Command Prompt)
2. Follow the prompts to enter your GitHub repository URL
3. The script will automatically push everything to GitHub

**Option B: Manual Upload**
1. Initialize git in the `mmrl-repo` folder:
   ```bash
   git init
   git branch -M main
   git add .
   git commit -m "Initial MMRL repository setup"
   ```

2. Add your GitHub repository as remote:
   ```bash
   git remote add origin https://github.com/yourusername/your-repo-name.git
   git push -u origin main
   ```

### Step 3: Enable GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** → **Pages**
3. Under **Source**, select **GitHub Actions**
4. The workflow will automatically deploy your repository

## 📱 Adding Repository to MMRL App

### Step 1: Install MMRL App

Download MMRL from:
- [GitHub Releases](https://github.com/MMRLApp/MMRL/releases)
- [F-Droid](https://f-droid.org/packages/com.dergoogler.mmrl/)

### Step 2: Add Your Repository

1. Open MMRL app
2. Tap the **hamburger menu** (☰) or go to **Settings**
3. Select **Repositories**
4. Tap **Add Repository** or the **+** button
5. Enter your repository URL:
   ```
   https://raw.githubusercontent.com/yourusername/your-repo-name/main/repo.json
   ```
6. Tap **Add** and wait for synchronization

### Step 3: Install Modules

1. Go back to the main screen
2. You should see **"Terragon Labs KernelSU Modules"** in the repository list
3. Tap on it to browse available modules
4. Find **"KernelSU Anti-Bootloop & Backup"**
5. Tap **Install** and follow the prompts
6. Reboot your device when prompted

## 🔧 Repository Management

### Adding New Modules

To add new modules to your repository:

1. Edit `modules.json`
2. Add a new module object to the `modules` array:
   ```json
   {
     "id": "your_module_id",
     "name": "Your Module Name",
     "version": "v1.0.0",
     "versionCode": 100,
     "author": "Your Name",
     "description": "Module description",
     "minApi": 33,
     "maxApi": 35,
     "zipUrl": "https://github.com/yourusername/your-module/releases/download/v1.0.0/module.zip",
     // ... other properties
   }
   ```

### Updating Module Versions

1. Update the `version` and `versionCode` in `modules.json`
2. Add a new entry to the `versions` array
3. Update the `zipUrl` to point to the new release
4. Commit and push changes

### Repository Structure

```
mmrl-repo/
├── repo.json              # Repository metadata
├── modules.json           # Module definitions
├── index.html            # Web interface (optional)
├── README.md             # Documentation
├── INTEGRATION_GUIDE.md  # This file
├── setup-repo.ps1        # PowerShell setup script
├── setup-repo.bat        # Batch setup script
└── .github/
    └── workflows/
        └── update-repo.yml # Auto-update workflow
```

## 🛠️ Troubleshooting

### Repository Not Showing in MMRL

- **Check URL**: Ensure you're using the raw GitHub URL
- **Check JSON**: Validate your JSON files using [JSONLint](https://jsonlint.com/)
- **Check Repository**: Make sure the repository is public
- **Check Network**: Ensure your device has internet access

### Module Installation Fails

- **Check Requirements**: Verify KernelSU version and Android API
- **Check Permissions**: Ensure MMRL has root access
- **Check Module**: Verify the module ZIP file is valid
- **Check Logs**: Check MMRL logs for error details

### Repository Updates Not Appearing

- **Force Refresh**: Pull down to refresh in MMRL
- **Check Timestamps**: Ensure timestamps are updated in JSON files
- **Check GitHub Actions**: Verify the workflow is running successfully
- **Clear Cache**: Clear MMRL app cache if needed

## 📚 Advanced Configuration

### Custom Module Categories

You can organize modules by adding categories:

```json
"categories": [
  "System",
  "Backup",
  "Recovery",
  "Security"
]
```

### Module Features

Highlight module features:

```json
"features": [
  "Anti-bootloop protection",
  "Comprehensive backup system",
  "WebUI interface"
]
```

### Version Tracking

Maintain version history:

```json
"versions": [
  {
    "timestamp": 1737513420,
    "version": "v1.0.0",
    "versionCode": 100,
    "zipUrl": "https://github.com/user/repo/releases/download/v1.0.0/module.zip",
    "changelog": "https://raw.githubusercontent.com/user/repo/v1.0.0/CHANGELOG.md"
  }
]
```

## 🎯 Best Practices

1. **Keep JSON Valid**: Always validate JSON before committing
2. **Use Semantic Versioning**: Follow semver for version numbers
3. **Update Timestamps**: Keep timestamps current for proper sorting
4. **Test Modules**: Always test modules before adding to repository
5. **Document Changes**: Maintain changelogs for each version
6. **Monitor Issues**: Respond to user issues promptly

## 🆘 Support

If you need help:

- **MMRL Issues**: [MMRL GitHub Issues](https://github.com/MMRLApp/MMRL/issues)
- **Module Issues**: [Your Module Repository Issues]
- **General Help**: [XDA Forums](https://forum.xda-developers.com/)

---

**Happy Modding! 🚀**