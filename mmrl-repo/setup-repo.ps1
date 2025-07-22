# MMRL Repository Setup Script
# This script initializes the Git repository and pushes to GitHub

Write-Host "🚀 Setting up MMRL Repository..." -ForegroundColor Cyan

# Check if git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Git is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Git from https://git-scm.com/" -ForegroundColor Yellow
    exit 1
}

# Initialize git repository if not already initialized
if (-not (Test-Path ".git")) {
    Write-Host "📁 Initializing Git repository..." -ForegroundColor Yellow
    git init
    git branch -M main
} else {
    Write-Host "✅ Git repository already initialized" -ForegroundColor Green
}

# Add all files
Write-Host "📝 Adding files to Git..." -ForegroundColor Yellow
git add .

# Commit files
Write-Host "💾 Committing files..." -ForegroundColor Yellow
git commit -m "🎉 Initial MMRL repository setup with KernelSU Anti-Bootloop & Backup module"

# Ask for GitHub repository URL
Write-Host ""
Write-Host "🔗 GitHub Repository Setup" -ForegroundColor Cyan
Write-Host "Please create a new repository on GitHub first, then provide the URL below."
Write-Host "Example: https://github.com/yourusername/mmrl-repo.git" -ForegroundColor Gray
Write-Host ""

$repoUrl = Read-Host "Enter your GitHub repository URL"

if ($repoUrl) {
    Write-Host "🌐 Adding remote origin..." -ForegroundColor Yellow
    git remote add origin $repoUrl
    
    Write-Host "⬆️ Pushing to GitHub..." -ForegroundColor Yellow
    git push -u origin main
    
    Write-Host ""
    Write-Host "✅ Repository setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Enable GitHub Pages in your repository settings" -ForegroundColor White
    Write-Host "2. Set source to 'GitHub Actions' in Pages settings" -ForegroundColor White
    Write-Host "3. Your MMRL repository will be available at:" -ForegroundColor White
    Write-Host "   $($repoUrl.Replace('.git', '').Replace('github.com', 'raw.githubusercontent.com'))/main/repo.json" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🎯 Add this URL to MMRL app:" -ForegroundColor Cyan
    Write-Host "   $($repoUrl.Replace('.git', '').Replace('github.com', 'raw.githubusercontent.com'))/main/repo.json" -ForegroundColor Green
} else {
    Write-Host "⚠️ No repository URL provided. You can add it later with:" -ForegroundColor Yellow
    Write-Host "   git remote add origin <your-repo-url>" -ForegroundColor Gray
    Write-Host "   git push -u origin main" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🎉 MMRL Repository is ready!" -ForegroundColor Green
Pause