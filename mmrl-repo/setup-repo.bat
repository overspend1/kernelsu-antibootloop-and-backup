@echo off
echo.
echo 🚀 Setting up MMRL Repository...
echo.

REM Check if git is installed
git --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Git is not installed or not in PATH
    echo Please install Git from https://git-scm.com/
    pause
    exit /b 1
)

REM Initialize git repository if not already initialized
if not exist ".git" (
    echo 📁 Initializing Git repository...
    git init
    git branch -M main
) else (
    echo ✅ Git repository already initialized
)

REM Add all files
echo 📝 Adding files to Git...
git add .

REM Commit files
echo 💾 Committing files...
git commit -m "🎉 Initial MMRL repository setup with KernelSU Anti-Bootloop & Backup module"

echo.
echo 🔗 GitHub Repository Setup
echo Please create a new repository on GitHub first, then provide the URL below.
echo Example: https://github.com/yourusername/mmrl-repo.git
echo.

set /p repoUrl="Enter your GitHub repository URL: "

if not "%repoUrl%"=="" (
    echo 🌐 Adding remote origin...
    git remote add origin %repoUrl%
    
    echo ⬆️ Pushing to GitHub...
    git push -u origin main
    
    echo.
    echo ✅ Repository setup complete!
    echo.
    echo 📋 Next Steps:
    echo 1. Enable GitHub Pages in your repository settings
    echo 2. Set source to 'GitHub Actions' in Pages settings
    echo 3. Your MMRL repository will be available at:
    echo    %repoUrl:.git=%/raw/main/repo.json
    echo.
    echo 🎯 Add this URL to MMRL app:
    echo    %repoUrl:.git=%/raw/main/repo.json
) else (
    echo ⚠️ No repository URL provided. You can add it later with:
    echo    git remote add origin ^<your-repo-url^>
    echo    git push -u origin main
)

echo.
echo 🎉 MMRL Repository is ready!
pause