# 🤖 Automation Guide: GitHub Workflows + MMRL Integration

This guide explains the complete automated system for releasing KernelSU modules and maintaining an MMRL repository.

## 🏗️ System Overview

The repository now includes a fully automated CI/CD pipeline that:

1. **Automatically creates releases** when you push a git tag
2. **Builds module ZIP files** with proper versioning
3. **Updates the MMRL repository** with new module information
4. **Deploys to GitHub Pages** for fast MMRL access
5. **Provides users with automatic updates** via the MMRL app

## 🚀 How to Create a Release

### Method 1: Using the PowerShell Script (Recommended)

```powershell
# Create a new release
./create-release.ps1 -Version "v1.1.0"

# Force release even with uncommitted changes
./create-release.ps1 -Version "v1.1.0" -Force
```

### Method 2: Manual Git Tags

```bash
# Update module.prop manually if needed
# Then create and push a tag
git tag v1.1.0
git push origin v1.1.0
```

### Method 3: GitHub Web Interface

1. Go to your repository on GitHub
2. Click **Releases** → **Create a new release**
3. Choose **Create new tag** and enter version (e.g., `v1.1.0`)
4. Fill in release details and click **Publish release**

## 🔄 What Happens Automatically

### When You Create a Release:

1. **Release Workflow Triggers** (`.github/workflows/release.yml`)
   - Updates `module.prop` with the new version
   - Creates a ZIP file from the module directory
   - Generates a changelog from git commits
   - Creates a GitHub release with the ZIP attached
   - Triggers the MMRL update workflow

2. **MMRL Update Workflow Triggers** (`.github/workflows/update-mmrl.yml`)
   - Fetches the latest release information
   - Updates `mmrl-repo/repo.json` with new timestamp
   - Updates `mmrl-repo/modules.json` with new version info
   - Validates JSON files for MMRL compatibility
   - Commits and pushes the updated MMRL repository

3. **GitHub Pages Deployment**
   - The MMRL repository files are automatically deployed
   - Users can access the repository via the GitHub Pages URL

## 📱 MMRL Repository Details

### Repository URL for MMRL App:
```
https://raw.githubusercontent.com/overspend1/overmodules/master/mmrl-repo/repo.json
```

### What Users See:
- **Repository Name:** "Terragon Labs KernelSU Modules"
- **Available Modules:** KernelSU Anti-Bootloop & Backup
- **Automatic Updates:** When you release new versions
- **Direct Download:** Links to GitHub releases

## 🛠️ Workflow Configuration

### Release Workflow Features:
- ✅ Automatic version detection from git tags
- ✅ Module ZIP building with proper naming
- ✅ Changelog generation from git commits
- ✅ Multiple file attachment to releases
- ✅ Manual trigger support via GitHub Actions UI

### MMRL Update Workflow Features:
- ✅ Triggered by releases, manual dispatch, or daily schedule
- ✅ Automatic version and download URL detection
- ✅ JSON validation to prevent MMRL compatibility issues
- ✅ Fallback to current version if no releases exist
- ✅ Proper timestamp management for MMRL sync

## 🔧 Customization Options

### Adding New Modules:

1. Create a new module directory (e.g., `my_new_module/`)
2. Update `.github/workflows/release.yml` to include the new module
3. Update `.github/workflows/update-mmrl.yml` to add the module to `modules.json`
4. Test with a new release

### Changing Repository Information:

1. Update `mmrl-repo/repo.json` for repository metadata
2. Update workflow files to change URLs and paths
3. Update `README.md` with new information

### Modifying Release Process:

1. Edit `.github/workflows/release.yml` for release customization
2. Edit `create-release.ps1` for script improvements
3. Test changes with a new release

## 🐛 Troubleshooting

### Common Issues:

1. **Workflow Fails:**
   - Check GitHub Actions logs
   - Verify JSON syntax in MMRL files
   - Ensure proper file permissions

2. **MMRL Not Updating:**
   - Verify the repository URL in MMRL app
   - Check if GitHub Pages is enabled
   - Wait for workflow completion (can take 2-5 minutes)

3. **Release Creation Fails:**
   - Ensure you have push permissions
   - Check if the tag already exists
   - Verify `module.prop` file exists and is valid

### Debug Commands:

```bash
# Check workflow status
gh run list

# View specific workflow run
gh run view <run-id>

# Check repository status
git status
git log --oneline -5

# Validate JSON files
python -m json.tool mmrl-repo/repo.json
python -m json.tool mmrl-repo/modules.json
```

## 📊 Monitoring

### GitHub Actions:
- **URL:** https://github.com/overspend1/overmodules/actions
- **Monitor:** Release and MMRL update workflows
- **Logs:** Available for 90 days

### MMRL Repository:
- **Live URL:** https://raw.githubusercontent.com/overspend1/overmodules/master/mmrl-repo/repo.json
- **Validation:** JSON files are automatically validated
- **Updates:** Happen within 2-5 minutes of release creation

## 🎯 Best Practices

1. **Always test modules** before creating releases
2. **Use semantic versioning** (v1.0.0, v1.1.0, v2.0.0)
3. **Write descriptive commit messages** for better changelogs
4. **Monitor GitHub Actions** after creating releases
5. **Keep module.prop updated** with accurate information
6. **Test MMRL integration** after major changes

## 🔮 Future Enhancements

- **Multi-module support** in a single repository
- **Automated testing** before releases
- **Discord/Telegram notifications** for new releases
- **Download statistics** tracking
- **Beta/Alpha release channels**

---

**The automation is now complete!** 🎉

Users can add your MMRL repository and get automatic updates whenever you create new releases.