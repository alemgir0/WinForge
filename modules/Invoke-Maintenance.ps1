#
# WinForge v1.1 - modules/Invoke-Maintenance.ps1
# Dot-sourced by WinForge.ps1
# Exports: Show-MaintenanceMenu
#
# KAPSAMLI TEMIZLIK POLITIKASI:
# - Prefetch temizlenmez (Windows boot performansini etkiler)
# - SoftwareDistribution\Download temizlenmez (aktif WU sureci bozulabilir)
# - Yalnizca $env:TEMP ve $env:SystemRoot\Temp hedeflenir
# - SFC/DISM kullanici onayiyla calisir
#

Set-StrictMode -Version 2.0

# ================================================================
# GOREV: Gecici Dosya Temizligi
# ================================================================

function Clear-WFTempFiles {
    $targets = @(
        [ordered]@{ Label = 'Kullanici Temp'; Path = $env:TEMP }
        [ordered]@{ Label = 'Sistem Temp';    Path = "$env:SystemRoot\Temp" }
    )

    $olderThanDays = 7
    $cutoff        = (Get-Date).AddDays(-$olderThanDays)
    $totalFreed    = [long]0
    $totalDeleted  = 0
    $totalErrors   = 0

    Write-Host ''
    Write-Host "  $olderThanDays gunden eski gecici dosyalar hedefleniyor..." -ForegroundColor DarkGray
    Write-Host ''

    foreach ($target in $targets) {
        if (-not (Test-Path -LiteralPath $target.Path)) {
            Write-Host "  $($target.Label): Dizin bulunamadi, atlaniyor." -ForegroundColor DarkGray
            continue
        }

        Write-Host "  $($target.Label): $($target.Path)" -ForegroundColor Cyan

        try {
            $files = Get-ChildItem -LiteralPath $target.Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                     Where-Object { $_.LastWriteTime -lt $cutoff }

            $fileCount = @($files).Count
            if ($fileCount -eq 0) {
                Write-Host '    Silinecek dosya bulunamadi.' -ForegroundColor DarkGray
                continue
            }

            Write-Host "    $fileCount dosya bulundu, siliniyor..." -ForegroundColor DarkGray

            foreach ($file in $files) {
                try {
                    $size = $file.Length
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    $totalFreed   += $size
                    $totalDeleted++
                } catch {
                    $totalErrors++
                    Write-WFLog -Message "Temp silme hatasi: $($file.FullName) - $($_.Exception.Message)" -Level 'WARN' -Source 'Maintenance'
                }
            }

            $freedMB = [math]::Round($totalFreed / 1MB, 1)
            Write-Host "    Tamamlandi. Silinen: $totalDeleted dosya / Kazanilan: $freedMB MB" -ForegroundColor Green

        } catch {
            Write-WFLog -Message "Clear-WFTempFiles hatasi ($($target.Path)): $($_.Exception.Message)" -Level 'ERROR' -Source 'Maintenance'
            Write-Host "    Hata: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($totalErrors -gt 0) {
        Write-Host "  Not: $totalErrors dosya kullanimda oldugu icin silinemedi (normal)." -ForegroundColor DarkGray
        Write-WFLog -Message "Temp temizlik: $totalDeleted silindi, $totalErrors atlanik, $([math]::Round($totalFreed/1MB,1)) MB kazanildi." -Level 'INFO' -Source 'Maintenance'
    }
}

# ================================================================
# GOREV: Uygulama Guncelleme (winget)
# ================================================================

function Update-WFWingetApps {
    if (-not $Script:WF_Preflight.HasWinget) {
        Write-WFStatus -Message 'winget bulunamadi. Guncelleme yapilamiyor.' -Type Warn
        return
    }

    Write-Host ''
    Write-Host '  Tum uygulamalar guncelleniyor (winget upgrade --all)...' -ForegroundColor Cyan
    Write-Host '  Bu islem uygulamalarin sayisina gore uzun surebilir.' -ForegroundColor DarkGray
    Write-Host ''
    Write-WFLog -Message 'winget upgrade --all baslatildi.' -Level 'INFO' -Source 'Maintenance'

    try {
        # winget upgrade --all dogrudan konsola yazar; -NoNewWindow ile ayni pencerede calisir
        $proc = Start-Process -FilePath 'winget.exe' `
                              -ArgumentList @('upgrade', '--all', '--silent',
                                              '--accept-package-agreements',
                                              '--accept-source-agreements',
                                              '--disable-interactivity') `
                              -Wait -NoNewWindow -PassThru -ErrorAction Stop

        $exitCode = $proc.ExitCode
        if ($exitCode -eq 0) {
            Write-Host ''
            Write-WFStatus -Message 'Uygulama guncellemesi tamamlandi.' -Type OK
            Write-WFLog -Message "winget upgrade --all tamamlandi. Cikis: $exitCode" -Level 'OK' -Source 'Maintenance'
        } else {
            Write-Host ''
            Write-WFStatus -Message "Guncelleme bazi hatayla bitti. Cikis kodu: $exitCode" -Type Warn
            Write-WFLog -Message "winget upgrade --all bitti. Cikis: $exitCode" -Level 'WARN' -Source 'Maintenance'
        }
    } catch {
        Write-WFStatus -Message "winget calistirilamadi: $($_.Exception.Message)" -Type Error
        Write-WFLog -Message "winget upgrade istisnasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'Maintenance'
    }
}

# ================================================================
# GOREV: Disk Temizleme
# ================================================================

function Invoke-WFDiskCleanup {
    Write-Host ''
    Write-Host '  Windows Disk Temizleme aracı baslatiliyor...' -ForegroundColor Cyan
    Write-Host '  Not: Onceden /sageset:1 yapilmamissa minimal temizlik yapar.' -ForegroundColor DarkGray
    Write-Host ''
    Write-WFLog -Message 'cleanmgr.exe /sagerun:1 baslatildi.' -Level 'INFO' -Source 'Maintenance'

    try {
        $proc = Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:1' `
                              -Wait -PassThru -ErrorAction Stop

        Write-WFLog -Message "cleanmgr.exe tamamlandi. Cikis: $($proc.ExitCode)" -Level 'INFO' -Source 'Maintenance'
        Write-WFStatus -Message 'Disk Temizleme tamamlandi.' -Type OK
    } catch {
        Write-WFStatus -Message "cleanmgr.exe calistirilamadi: $($_.Exception.Message)" -Type Error
        Write-WFLog -Message "cleanmgr.exe istisnasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'Maintenance'
    }
}

# ================================================================
# GOREV: Sistem Dosyasi Kontrolu (SFC)
# ================================================================

function Invoke-WFSFC {
    Write-Host ''
    Write-Host '  System File Checker baslatiliyor (sfc /scannow)...' -ForegroundColor Cyan
    Write-Host '  Bu islem 10-20 dakika surebilir. Lutfen bekleyin.' -ForegroundColor DarkGray
    Write-Host ''
    Write-WFLog -Message 'sfc /scannow baslatildi.' -Level 'INFO' -Source 'Maintenance'

    try {
        # SFC konsola dogrudan yazar; -NoNewWindow ile ayni pencerede gorunur
        $proc = Start-Process -FilePath 'sfc.exe' -ArgumentList '/scannow' `
                              -Wait -NoNewWindow -PassThru -ErrorAction Stop

        $exitCode = $proc.ExitCode
        Write-Host ''
        Write-WFLog -Message "sfc /scannow tamamlandi. Cikis: $exitCode" -Level 'INFO' -Source 'Maintenance'

        if ($exitCode -eq 0) {
            Write-WFStatus -Message 'SFC taramasi tamamlandi.' -Type OK
        } else {
            Write-WFStatus -Message "SFC hata kodu: $exitCode. Ayrintili log: $env:SystemRoot\Logs\CBS\CBS.log" -Type Warn
        }
        Write-Host '  Detayli log: %SystemRoot%\Logs\CBS\CBS.log' -ForegroundColor DarkGray
    } catch {
        Write-WFStatus -Message "sfc.exe calistirilamadi: $($_.Exception.Message)" -Type Error
        Write-WFLog -Message "sfc.exe istisnasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'Maintenance'
    }
}

# ================================================================
# GOREV: DISM Onarimi
# ================================================================

function Invoke-WFDISM {
    Write-Host ''
    Write-Host '  DISM sistem onarimi baslatiliyor...' -ForegroundColor Cyan
    Write-Host '  DISM /Online /Cleanup-Image /RestoreHealth' -ForegroundColor DarkGray
    Write-Host '  Bu islem 15-30 dakika surebilir. Internet gerektirebilir.' -ForegroundColor DarkGray
    Write-Host ''
    Write-WFLog -Message 'DISM RestoreHealth baslatildi.' -Level 'INFO' -Source 'Maintenance'

    try {
        $proc = Start-Process -FilePath 'DISM.exe' `
                              -ArgumentList @('/Online', '/Cleanup-Image', '/RestoreHealth') `
                              -Wait -NoNewWindow -PassThru -ErrorAction Stop

        $exitCode = $proc.ExitCode
        Write-Host ''
        Write-WFLog -Message "DISM tamamlandi. Cikis: $exitCode" -Level 'INFO' -Source 'Maintenance'

        if ($exitCode -eq 0) {
            Write-WFStatus -Message 'DISM onarimi basariyla tamamlandi.' -Type OK
        } elseif ($exitCode -eq 3010) {
            Write-WFStatus -Message 'DISM tamamlandi. Yeniden baslatma onerilir.' -Type Warn
            $Script:WF_RebootRecommended = $true
        } else {
            Write-WFStatus -Message "DISM hata kodu: $exitCode" -Type Error
        }
    } catch {
        Write-WFStatus -Message "DISM.exe calistirilamadi: $($_.Exception.Message)" -Type Error
        Write-WFLog -Message "DISM istisnasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'Maintenance'
    }
}

# ================================================================
# GOREV: Eski WinForge Loglarini Temizle
# ================================================================

function Clear-WFOldLogs {
    $maxAgeDays = 30
    $cutoff     = (Get-Date).AddDays(-$maxAgeDays)
    $deleted    = 0

    try {
        $oldLogs = Get-ChildItem -LiteralPath $Script:WF_LogDir -Filter 'WinForge_*.log' -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.LastWriteTime -lt $cutoff }

        foreach ($logFile in $oldLogs) {
            # Aktif oturum logu silinmez
            if ($logFile.FullName -eq $Script:WF_LogFile) { continue }
            try {
                Remove-Item -LiteralPath $logFile.FullName -Force -ErrorAction Stop
                $deleted++
                Write-WFLog -Message "Eski log silindi: $($logFile.Name)" -Level 'INFO' -Source 'Maintenance'
            } catch {
                Write-WFLog -Message "Log silinemedi: $($logFile.Name) - $($_.Exception.Message)" -Level 'WARN' -Source 'Maintenance'
            }
        }

        Write-WFStatus -Message "$deleted eski log dosyasi silindi ($maxAgeDays gun+)." -Type OK
    } catch {
        Write-WFStatus -Message "Log temizleme hatasi: $($_.Exception.Message)" -Type Error
    }
}

# ================================================================
# ANA MENU (Export)
# ================================================================

function Show-MaintenanceMenu {
    $running = $true

    while ($running) {
        Show-WFBanner
        Write-Host '  Bakim / Guncelleme' -ForegroundColor Cyan
        Write-WFSeparator -SepChar '-'
        Write-Host ''
        Write-Host '  [1]  Gecici Dosyalari Temizle' -ForegroundColor White
        Write-Host '  [2]  Uygulamalari Guncelle (winget)' -ForegroundColor White
        Write-Host '  [3]  Disk Temizleme (cleanmgr)' -ForegroundColor White
        Write-Host '  [4]  Sistem Dosyasi Kontrolu (SFC)' -ForegroundColor White
        Write-Host '  [5]  Sistem Onarimi (DISM)' -ForegroundColor White
        Write-Host '  [6]  Eski WinForge Loglarini Temizle' -ForegroundColor White
        Write-Host ''
        Write-Host '  [A]  Guvenli gorevleri calistir (1 + 6)' -ForegroundColor DarkCyan
        Write-Host ''
        Write-Host '  [0]  Ana Menu' -ForegroundColor DarkGray
        Write-Host ''

        $raw    = Read-Host '  Seciminiz'
        $choice = $raw.Trim().ToUpper()

        switch ($choice) {
            '1' {
                Clear-WFTempFiles
                Write-Host ''
                Read-Host '  Devam icin Enter''a basin'
            }
            '2' {
                if (-not $Script:WF_Preflight.HasWinget) {
                    Write-WFStatus -Message 'winget bulunamadi.' -Type Warn
                    Start-Sleep -Seconds 2
                } else {
                    Update-WFWingetApps
                    Write-Host ''
                    Read-Host '  Devam icin Enter''a basin'
                }
            }
            '3' {
                Invoke-WFDiskCleanup
                Write-Host ''
                Read-Host '  Devam icin Enter''a basin'
            }
            '4' {
                if (-not $Script:WF_Preflight.IsAdmin) {
                    Write-WFStatus -Message 'SFC icin admin yetkisi gerekiyor.' -Type Warn
                    Start-Sleep -Seconds 2
                } else {
                    Invoke-WFSFC
                    Write-Host ''
                    Read-Host '  Devam icin Enter''a basin'
                }
            }
            '5' {
                if (-not $Script:WF_Preflight.IsAdmin) {
                    Write-WFStatus -Message 'DISM icin admin yetkisi gerekiyor.' -Type Warn
                    Start-Sleep -Seconds 2
                } else {
                    $confirmed = Read-WFConfirmation -Prompt 'DISM RestoreHealth baslatilsin mi? (Internet gerektirebilir)'
                    if ($confirmed) {
                        Invoke-WFDISM
                        Write-Host ''
                        Read-Host '  Devam icin Enter''a basin'
                    }
                }
            }
            '6' {
                Clear-WFOldLogs
                Write-Host ''
                Read-Host '  Devam icin Enter''a basin'
            }
            'A' {
                Write-Host ''
                Write-Host '  Guvenli bakim gorevleri calistiriliyor...' -ForegroundColor Cyan
                Clear-WFTempFiles
                Write-Host ''
                Clear-WFOldLogs
                Write-Host ''
                Read-Host '  Tamamlandi. Devam icin Enter''a basin'
            }
            '0' { $running = $false }
            default {
                Write-WFStatus -Message 'Gecersiz secim.' -Type Warn
                Start-Sleep -Milliseconds 600
            }
        }
    }
}
