# WinForge Release Packaging Script
param(
    [string]$Version = 'v1.0'
)

$rootDir = Split-Path -Parent $PSScriptRoot
$distDir = Join-Path $rootDir "dist"
$releaseDirName = "WinForge-$Version"
$releaseDir = Join-Path $distDir $releaseDirName

if (Test-Path $releaseDir) {
    Remove-Item $releaseDir -Recurse -Force
}

New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

$includePaths = @(
    "WinForge.ps1",
    "Launch-WinForge.bat",
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "KNOWN_ISSUES.md"
)

$includeDirs = @(
    "modules",
    "data",
    "docs"
)

foreach ($item in $includePaths) {
    $src = Join-Path $rootDir $item
    if (Test-Path $src) {
        Copy-Item $src -Destination $releaseDir
    }
}

foreach ($dir in $includeDirs) {
    if ($dir -eq "docs") {
        # Checkist end usera lazim degil
        $src = Join-Path $rootDir $dir
        if (Test-Path $src) {
            Copy-Item $src -Destination $releaseDir -Recurse
            $chk = Join-Path $releaseDir "docs\RELEASE_CHECKLIST.md"
            if (Test-Path $chk) { Remove-Item $chk -Force }
        }
    } else {
        $src = Join-Path $rootDir $dir
        if (Test-Path $src) {
            Copy-Item $src -Destination $releaseDir -Recurse
        }
    }
}

# Create empty directories for logs and backups
New-Item -ItemType Directory -Path (Join-Path $releaseDir "logs") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $releaseDir "logs\.keep") -Force | Out-Null

$backupsDir = Join-Path $releaseDir "backups"
New-Item -ItemType Directory -Path (Join-Path $backupsDir "registry") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $backupsDir "tweaks") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $backupsDir "full") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $backupsDir ".keep") -Force | Out-Null

# Compress
$zipPath = Join-Path $distDir "$releaseDirName.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Dosya handle'larinin tamamen bosalmasi icin temizlik
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
Start-Sleep -Milliseconds 800

try {
    Compress-Archive -Path $releaseDir -DestinationPath $zipPath -Force -ErrorAction Stop
    Write-Host 'Paketleme Tamamlandi!' -ForegroundColor Cyan
    Write-Host " Klasor: $releaseDir" -ForegroundColor White
    Write-Host " ZIp:    $zipPath" -ForegroundColor Green
}
catch {
    Write-Host ''
    Write-Host "  [HATA] Paketleme basarisiz oldu." -ForegroundColor Red
    Write-Host "  Nedeni: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  (Dosya kilitli olabilir. Bir process silinen/degistirilen dosyalari kullaniyor.)" -ForegroundColor Yellow
    exit 1
}
