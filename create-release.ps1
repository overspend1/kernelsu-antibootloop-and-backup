#!/usr/bin/env pwsh
# Script to create a GitHub release for the KernelSU Anti-Bootloop & Backup module

param(
    [string]$Version = "v1.0.0",
    [switch]$Force
)

Write-Host "🚀 Creating GitHub release for KernelSU Anti-Bootloop & Backup module" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Cyan

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Error "This script must be run from the root of the git repository"
    exit 1
}

# Check if git is available
try {
    git --version | Out-Null
} catch {
    Write-Error "Git is not installed or not in PATH"
    exit 1
}

# Check for uncommitted changes
$gitStatus = git status --porcelain
if ($gitStatus -and -not $Force) {
    Write-Warning "You have uncommitted changes:"
    Write-Host $gitStatus
    $response = Read-Host "Do you want to continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Aborted by user" -ForegroundColor Yellow
        exit 0
    }
}

# Update module.prop with new version
Write-Host "📝 Updating module.prop with version $Version..." -ForegroundColor Blue

$modulePropPath = "kernelsu_antibootloop_backup/module.prop"
if (Test-Path $modulePropPath) {
    $versionCode = $Version -replace 'v', '' -replace '\.', ''
    
    $content = Get-Content $modulePropPath
    $content = $content -replace '^version=.*', "version=$Version"
    $content = $content -replace '^versionCode=.*', "versionCode=$versionCode"
    $content | Set-Content $modulePropPath
    
    Write-Host "✅ Updated module.prop" -ForegroundColor Green
} else {
    Write-Warning "module.prop not found at $modulePropPath"
}

# Commit changes if any
if (git status --porcelain) {
    Write-Host "📦 Committing version update..." -ForegroundColor Blue
    git add .
    git commit -m "🔖 Bump version to $Version"
    Write-Host "✅ Changes committed" -ForegroundColor Green
}

# Create and push tag
Write-Host "🏷️ Creating git tag $Version..." -ForegroundColor Blue
try {
    git tag $Version
    git push origin $Version
    Write-Host "✅ Tag $Version created and pushed" -ForegroundColor Green
} catch {
    Write-Error "Failed to create or push tag: $_"
    exit 1
}

Write-Host ""
Write-Host "🎉 Release process initiated!" -ForegroundColor Green
Write-Host "📋 What happens next:" -ForegroundColor Cyan
Write-Host "   1. GitHub Actions will automatically create a release" -ForegroundColor White
Write-Host "   2. The module ZIP will be built and attached to the release" -ForegroundColor White
Write-Host "   3. The MMRL repository will be updated automatically" -ForegroundColor White
Write-Host "   4. Users can install the module via MMRL app" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Monitor the progress at:" -ForegroundColor Cyan
Write-Host "   https://github.com/overspend1/overmodules/actions" -ForegroundColor Blue
Write-Host ""
Write-Host "📱 MMRL Repository URL:" -ForegroundColor Cyan
Write-Host "   https://raw.githubusercontent.com/overspend1/overmodules/master/mmrl-repo/repo.json" -ForegroundColor Blue