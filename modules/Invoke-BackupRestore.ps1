#
# WinForge v1.1 - modules/Invoke-BackupRestore.ps1
# Dot-sourced by WinForge.ps1
# Exports: Show-BackupRestoreMenu
#

Set-StrictMode -Version 2.0

# ================================================================
# KAYIT DEFTERI YEDEGI
# ================================================================

function New-WFRegistryBackup {
    <#
    .SYNOPSIS
        Belirtilen registry yolunu .reg dosyasina disa aktar.
        Kullanici yolu el ile girer.
    #>

    Write-Host ''
    Write-Host '  Registry Yedekleme' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'
    Write-Host '  Ornek: HKEY_CURRENT_USER\Software\MyApp' -ForegroundColor DarkGray
    Write-Host '  Ornek: HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows' -ForegroundColor DarkGray
    Write-Host ''

    $rawPath = Read-Host '  Yedeklenecek registry yolu (bos birak = iptal)'
    $rawPath = $rawPath.Trim()
    if ($rawPath -eq '') {
        Write-WFStatus -Message 'Iptal edildi.' -Type Info
        return
    }

    # Yol guvenligi: sadece HKEY_ ile baslayan kabul
    if ($rawPath -notmatch '^HKEY_(CURRENT_USER|LOCAL_MACHINE|USERS|CLASSES_ROOT|CURRENT_CONFIG)\\') {
        Write-WFStatus -Message 'Gecersiz registry yolu. HKEY_ ile baslamali.' -Type Error
        return
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    # Dosya adi icin: yolun son parcasini kullan, ozel karakterleri temizle
    $keyLeaf   = ($rawPath -split '\\')[-1] -replace '[^a-zA-Z0-9_-]', '_'
    $fileName  = "reg_${keyLeaf}_$timestamp.reg"
    $filePath  = Join-Path $Script:WF_BackupRegistry $fileName

    Write-Host ''
    Write-Host "  Disa aktariliyor: $rawPath" -ForegroundColor Cyan
    Write-WFLog -Message "Registry yedeği baslatildi: $rawPath -> $filePath" -Level 'INFO' -Source 'Backup'

    try {
        $output    = & reg.exe export $rawPath $filePath /y 2>&1
        $exitCode  = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-WFStatus -Message "Yedek kaydedildi: backups\registry\$fileName" -Type OK
            Write-WFLog -Message "Registry yedeği basarili: $filePath" -Level 'OK' -Source 'Backup'
        } else {
            Write-WFStatus -Message "reg.exe hatasi (Kod: $exitCode): $output" -Type Error
            Write-WFLog -Message "Registry yedeği basarisiz: $rawPath (Kod: $exitCode)" -Level 'ERROR' -Source 'Backup'
        }
    } catch {
        Write-WFStatus -Message "reg.exe calistirilamadi: $($_.Exception.Message)" -Type Error
        Write-WFLog -Message "Registry yedek istisnasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'Backup'
    }
}

# ================================================================
# TAM YEDEK
# ================================================================

function New-WFFullBackup {
    <#
    .SYNOPSIS
        backups/full/WinForge_<timestamp>/ altina tam yedek olusturur.
        Icerik: manifest.json, tweak snapshot kopyalari, winget app listesi.
    #>

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupDir = Join-Path $Script:WF_BackupFull "WinForge_$timestamp"

    Write-Host ''
    Write-Host '  Tam yedek olusturuluyor...' -ForegroundColor Cyan
    Write-WFLog -Message "Tam yedek baslatildi: $backupDir" -Level 'INFO' -Source 'Backup'

    try {
        New-Item -ItemType Directory -Path $backupDir -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-WFStatus -Message "Yedek klasoru olusturulamadi: $($_.Exception.Message)" -Type Error
        return
    }

    $manifestItems = [System.Collections.Generic.List[hashtable]]::new()
    $errors        = [System.Collections.Generic.List[string]]::new()

    # --- 1. Tweak snapshot kopyalari ---
    $snapDir = Join-Path $backupDir 'snapshots'
    New-Item -ItemType Directory -Path $snapDir -Force | Out-Null

    $snapFiles = @(Get-ChildItem -LiteralPath $Script:WF_BackupTweaks -Filter '*.json' -File -ErrorAction SilentlyContinue)
    $snapCopied = 0
    foreach ($snapFile in $snapFiles) {
        try {
            Copy-Item -LiteralPath $snapFile.FullName -Destination $snapDir -Force -ErrorAction Stop
            $snapCopied++
        } catch {
            $errors.Add("Snapshot kopyalanamadi: $($snapFile.Name)")
        }
    }
    Write-Host "  [1/3] Tweak snapshot'lari: $snapCopied dosya kopyalandi." -ForegroundColor DarkGray
    $manifestItems.Add(@{ Type='Snapshots'; Count=$snapCopied; Path='snapshots\' })

    # --- 2. winget uygulama listesi ---
    $appsFile = Join-Path $backupDir 'apps_export.json'
    if ($Script:WF_Preflight.HasWinget) {
        Write-Host '  [2/3] Uygulama listesi disa aktariliyor (winget export)...' -ForegroundColor DarkGray
        try {
            $expOut   = & winget.exe export -o $appsFile --accept-source-agreements 2>&1
            $expExit  = $LASTEXITCODE
            if ($expExit -eq 0 -and (Test-Path -LiteralPath $appsFile)) {
                $manifestItems.Add(@{ Type='AppList'; Path='apps_export.json' })
                Write-Host '         Tamam.' -ForegroundColor Green
                Write-WFLog -Message "winget export basarili: $appsFile" -Level 'OK' -Source 'Backup'
            } else {
                $errors.Add("winget export basarisiz (Kod: $expExit)")
                Write-Host "         Basarisiz (Kod: $expExit)." -ForegroundColor Yellow
                Write-WFLog -Message "winget export basarisiz: $expExit | $expOut" -Level 'WARN' -Source 'Backup'
            }
        } catch {
            $errors.Add("winget export istisnasi: $($_.Exception.Message)")
            Write-Host '         Hata.' -ForegroundColor Red
        }
    } else {
        Write-Host '  [2/3] winget bulunamadi, uygulama listesi atlanik.' -ForegroundColor DarkGray
        $errors.Add('winget bulunamadi; uygulama listesi yedeklenemedi.')
    }

    # --- 3. Manifest ---
    Write-Host '  [3/3] Manifest yaziliyor...' -ForegroundColor DarkGray

    $manifest = [ordered]@{
        Version      = '1.1'
        CreatedAt    = (Get-Date -Format 'o')
        ComputerName = $env:COMPUTERNAME
        OSBuild      = if ($null -ne $Script:WF_Preflight) { $Script:WF_Preflight.OsBuild }   else { 0 }
        OSEdition    = if ($null -ne $Script:WF_Preflight) { $Script:WF_Preflight.OsEdition } else { 'Unknown' }
        BackupType   = 'Full'
        Items        = $manifestItems.ToArray()
        Errors       = $errors.ToArray()
    }

    try {
        $manifest | ConvertTo-Json -Depth 10 | Out-File -LiteralPath (Join-Path $backupDir 'manifest.json') -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-WFStatus -Message "Manifest kaydedilemedi: $($_.Exception.Message)" -Type Error
    }

    # Sonuc
    Write-Host ''
    if ($errors.Count -eq 0) {
        Write-WFStatus -Message "Tam yedek tamamlandi: backups\full\WinForge_$timestamp\" -Type OK
        Write-WFLog -Message "Tam yedek tamamlandi: $backupDir" -Level 'OK' -Source 'Backup'
    } else {
        Write-WFStatus -Message "Yedek kismi tamamlandi ($($errors.Count) sorun): backups\full\WinForge_$timestamp\" -Type Warn
        foreach ($err in $errors) { Write-Host "  - $err" -ForegroundColor Yellow }
        Write-WFLog -Message "Tam yedek kismi tamamlandi. Sorunlar: $($errors -join ' | ')" -Level 'WARN' -Source 'Backup'
    }
}

# ================================================================
# YEDEK ENVANTERI
# ================================================================

function Get-WFBackupInventory {
    <#
    .SYNOPSIS
        Tum yedek turlerini listeler ve insan okunabilir ozet dondurur.
    #>

    $inventory = [ordered]@{
        FullBackups     = @()
        TweakSnapshots  = @()
        RegistryBackups = @()
    }

    # Tam yedekler
    if (Test-Path -LiteralPath $Script:WF_BackupFull) {
        $fullDirs = @(Get-ChildItem -LiteralPath $Script:WF_BackupFull -Directory -Filter 'WinForge_*' -ErrorAction SilentlyContinue |
                      Sort-Object LastWriteTime -Descending)
        foreach ($dir in $fullDirs) {
            $manifestPath = Join-Path $dir.FullName 'manifest.json'
            $sizeMB       = [math]::Round(
                (Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum / 1MB, 1)

            $created  = ''
            $osInfo   = ''
            $itemList = ''
            if (Test-Path -LiteralPath $manifestPath) {
                try {
                    $mf       = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    $created  = [datetime]$mf.CreatedAt
                    $osInfo   = "$($mf.OSEdition) Build $($mf.OSBuild)"
                    $itemList = ($mf.Items | ForEach-Object { "$($_.Type)($($_.Count))" }) -join ', '
                } catch {
                    Write-WFLog -Message "Manifest okunamadi: $($dir.Name) | $($_.Exception.Message)" -Level 'WARN' -Source 'Backup'
                }
            }

            $inventory.FullBackups += [ordered]@{
                Name        = $dir.Name
                Path        = $dir.FullName
                CreatedAt   = $created
                OSInfo      = $osInfo
                SizeMB      = $sizeMB
                ItemList    = $itemList
            }
        }
    }

    # Tweak snapshot'lari
    if (Test-Path -LiteralPath $Script:WF_BackupTweaks) {
        $snapFiles = @(Get-ChildItem -LiteralPath $Script:WF_BackupTweaks -Filter '*.json' -File -ErrorAction SilentlyContinue |
                       Sort-Object LastWriteTime -Descending)
        foreach ($sf in $snapFiles) {
            $inventory.TweakSnapshots += [ordered]@{
                FileName    = $sf.Name
                Path        = $sf.FullName
                ModifiedAt  = $sf.LastWriteTime
                SizeKB      = [math]::Round($sf.Length / 1KB, 1)
            }
        }
    }

    # Registry yedekleri
    if (Test-Path -LiteralPath $Script:WF_BackupRegistry) {
        $regFiles = @(Get-ChildItem -LiteralPath $Script:WF_BackupRegistry -Filter '*.reg' -File -ErrorAction SilentlyContinue |
                      Sort-Object LastWriteTime -Descending)
        foreach ($rf in $regFiles) {
            $inventory.RegistryBackups += [ordered]@{
                FileName   = $rf.Name
                Path       = $rf.FullName
                ModifiedAt = $rf.LastWriteTime
                SizeKB     = [math]::Round($rf.Length / 1KB, 1)
            }
        }
    }

    return $inventory
}

function Show-WFBackupList {
    Show-WFBanner
    Write-Host '  Yedek Envanteri' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'
    Write-Host ''

    $inv = Get-WFBackupInventory

    # --- Tam yedekler ---
    Write-Host '  TAM YEDEKLER' -ForegroundColor DarkCyan
    if ($inv.FullBackups.Count -eq 0) {
        Write-Host '    (yok)' -ForegroundColor DarkGray
    } else {
        foreach ($fb in $inv.FullBackups) {
            $dateStr = if ($fb.CreatedAt -ne '') { ([datetime]$fb.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '?' }
            Write-Host "    $($fb.Name)" -ForegroundColor White
            Write-Host "    Tarih: $dateStr  |  OS: $($fb.OSInfo)  |  Boyut: $($fb.SizeMB) MB" -ForegroundColor DarkGray
            if ($fb.ItemList -ne '') { Write-Host "    Icerik: $($fb.ItemList)" -ForegroundColor DarkGray }
            Write-Host ''
        }
    }

    # --- Tweak snapshot'lari ---
    Write-Host '  TWEAK SNAPSHOT''LARI' -ForegroundColor DarkCyan
    if ($inv.TweakSnapshots.Count -eq 0) {
        Write-Host '    (yok)' -ForegroundColor DarkGray
    } else {
        # Tweak ID'ye gore grupla (en son snapshot goster)
        $grouped = @{}
        foreach ($sn in $inv.TweakSnapshots) {
            $tweakId = ($sn.FileName -split '_')[0]
            if (-not $grouped.ContainsKey($tweakId)) {
                $grouped[$tweakId] = $sn
            }
        }
        foreach ($tweakId in ($grouped.Keys | Sort-Object)) {
            $sn      = $grouped[$tweakId]
            $dateStr = $sn.ModifiedAt.ToString('yyyy-MM-dd HH:mm')
            Write-Host "    $($tweakId.PadRight(35)) Son: $dateStr  ($($sn.SizeKB) KB)" -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host "    Toplam: $($inv.TweakSnapshots.Count) snapshot dosyasi" -ForegroundColor DarkGray
    }
    Write-Host ''

    # --- Registry yedekleri ---
    Write-Host '  REGISTRY YEDEKLERI' -ForegroundColor DarkCyan
    if ($inv.RegistryBackups.Count -eq 0) {
        Write-Host '    (yok)' -ForegroundColor DarkGray
    } else {
        foreach ($rb in $inv.RegistryBackups) {
            $dateStr = $rb.ModifiedAt.ToString('yyyy-MM-dd HH:mm')
            Write-Host "    $($rb.FileName.PadRight(45)) $dateStr  ($($rb.SizeKB) KB)" -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    Read-Host '  Geri donmek icin Enter''a basin'
}

# ================================================================
# TAM YEDEKTEN GERI YUKLE
# ================================================================

function Restore-WFFromFullBackup {
    Show-WFBanner
    Write-Host '  Tam Yedekten Geri Yukle' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'
    Write-Host ''

    $inv = Get-WFBackupInventory
    if ($inv.FullBackups.Count -eq 0) {
        Write-WFStatus -Message 'Hic tam yedek bulunamadi.' -Type Warn
        Read-Host '  Geri donmek icin Enter''a basin'
        return
    }

    # Yedekleri listele
    for ($i = 0; $i -lt $inv.FullBackups.Count; $i++) {
        $fb      = $inv.FullBackups[$i]
        $dateStr = if ($fb.CreatedAt -ne '') { ([datetime]$fb.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '?' }
        Write-Host "  [$($i+1)] $($fb.Name)" -ForegroundColor White
        Write-Host "       $dateStr  |  $($fb.OSInfo)  |  $($fb.SizeMB) MB" -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '  [0] Iptal'
    Write-Host ''

    $raw    = Read-Host '  Geri yuklenecek yedek'
    $choice = $raw.Trim()
    if ($choice -eq '0' -or $choice -eq '') { return }
    if ($choice -notmatch '^\d+$') { return }

    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $inv.FullBackups.Count) {
        Write-WFStatus -Message 'Gecersiz secim.' -Type Warn
        Start-Sleep -Seconds 1
        return
    }

    $selectedBackup = $inv.FullBackups[$idx]
    $backupDir      = $selectedBackup.Path

    # Manifest oku
    $manifestPath = Join-Path $backupDir 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-WFStatus -Message 'manifest.json bulunamadi. Yedek bozuk olabilir.' -Type Error
        Read-Host '  Devam icin Enter''a basin'
        return
    }

    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-WFStatus -Message "manifest.json okunamadi: $($_.Exception.Message)" -Type Error
        Read-Host '  Devam icin Enter''a basin'
        return
    }

    # Yedek ozeti: manifest verisini kullaniciya goster
    $mCreated = try { [datetime]$manifest.CreatedAt } catch { $selectedBackup.Name }
    Write-Host "  Makine : $($manifest.ComputerName)" -ForegroundColor DarkGray
    Write-Host "  OS     : $($manifest.OSEdition) Build $($manifest.OSBuild)" -ForegroundColor DarkGray
    Write-Host "  Tarih  : $($mCreated.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Bu yedekten ne geri yuklensin?' -ForegroundColor Cyan
    Write-Host '  [1]  Uygulama listesi (winget import)' -ForegroundColor White
    Write-Host '  [2]  Tweak snapshot bilgisini goster (manuel rollback icin)' -ForegroundColor White
    Write-Host '  [3]  Her ikisi' -ForegroundColor White
    Write-Host '  [0]  Iptal'
    Write-Host ''

    $restoreChoice = Read-WFMenuChoice -ValidChoices @('0','1','2','3') -Prompt 'Seciminiz'
    if ($restoreChoice -eq '0') { return }

    $totalOps = 0; $successOps = 0; $failedItems = [System.Collections.Generic.List[string]]::new()

    # --- Uygulama listesi geri yukleme ---
    if ($restoreChoice -eq '1' -or $restoreChoice -eq '3') {
        $totalOps++
        $appsFile = Join-Path $backupDir 'apps_export.json'

        if (-not (Test-Path -LiteralPath $appsFile)) {
            $failedItems.Add('Uygulama listesi (apps_export.json) bu yedekte yok.')
        } elseif (-not $Script:WF_Preflight.HasWinget) {
            $failedItems.Add('winget bulunamadi; uygulama listesi yuklenemez.')
        } else {
            Write-Host ''
            Write-Host '  Uygulama listesi geri yukleniyor (winget import)...' -ForegroundColor Cyan
            Write-Host '  Bu islem uzun surebilir.' -ForegroundColor DarkGray
            Write-WFLog -Message "winget import baslatildi: $appsFile" -Level 'INFO' -Source 'Restore'

            try {
                $proc = Start-Process -FilePath 'winget.exe' `
                                      -ArgumentList @('import', '-i', $appsFile,
                                                      '--accept-package-agreements',
                                                      '--accept-source-agreements',
                                                      '--ignore-unavailable') `
                                      -Wait -NoNewWindow -PassThru -ErrorAction Stop

                $impExit = $proc.ExitCode
                if ($impExit -eq 0) {
                    Write-WFStatus -Message 'Uygulama listesi geri yuklendi.' -Type OK
                    Write-WFLog -Message 'winget import basarili.' -Level 'OK' -Source 'Restore'
                    $successOps++
                } else {
                    $failedItems.Add("winget import hatali tamamlandi (Kod: $impExit). Bazi uygulamalar yuklenemeyebilir.")
                    $successOps++  # Kismi sayiyoruz; winget import kendi ozeti gosterir
                    Write-WFLog -Message "winget import bitti. Cikis: $impExit" -Level 'WARN' -Source 'Restore'
                }
            } catch {
                $failedItems.Add("winget import calistirilamadi: $($_.Exception.Message)")
                Write-WFLog -Message "winget import istisnasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'Restore'
            }
        }
    }

    # --- Tweak snapshot bilgisi ---
    if ($restoreChoice -eq '2' -or $restoreChoice -eq '3') {
        $totalOps++
        $snapDir = Join-Path $backupDir 'snapshots'
        Write-Host ''
        Write-Host '  Yedekteki Tweak Snapshot Bilgisi:' -ForegroundColor Cyan

        if (Test-Path -LiteralPath $snapDir) {
            $snaps = @(Get-ChildItem -LiteralPath $snapDir -Filter '*.json' -File -ErrorAction SilentlyContinue)
            if ($snaps.Count -eq 0) {
                Write-Host '    Bu yedekte snapshot bulunamadi.' -ForegroundColor DarkGray
            } else {
                foreach ($sf in $snaps) {
                    try {
                        $snap = Get-Content -LiteralPath $sf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                        $date = if ($snap.AppliedAt) { [datetime]$snap.AppliedAt } else { $sf.LastWriteTime }
                        Write-Host "    $($snap.TweakId.PadRight(35)) Uygulanma: $($date.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor DarkGray
                    } catch {
                        Write-Host "    $($sf.Name) (okunamadi)" -ForegroundColor DarkGray
                    }
                }
                Write-Host ''
                Write-Host '  Not: Tweak geri almak icin Windows Tweakleri > Geri Al menusunu kullanin.' -ForegroundColor Yellow
            }
            $successOps++
        } else {
            $failedItems.Add('Snapshot klasoru bu yedekte yok.')
        }
    }

    # --- Sonuc raporu ---
    Write-Host ''
    Write-WFSeparator -SepChar '-'
    Write-Host '  Geri Yukleme Sonucu' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'

    if ($failedItems.Count -eq 0) {
        Write-WFStatus -Message "Tam basari: $successOps/$totalOps islem tamamlandi." -Type OK
        Write-WFLog -Message "Geri yukleme tam basari: $successOps/$totalOps" -Level 'OK' -Source 'Restore'
    } elseif ($successOps -gt 0) {
        Write-WFStatus -Message "Kismi basari: $successOps/$totalOps islem tamamlandi." -Type Warn
        Write-Host '  Tamamlanamayan islemler:' -ForegroundColor Yellow
        foreach ($fi in $failedItems) { Write-Host "    - $fi" -ForegroundColor Yellow }
        Write-WFLog -Message "Geri yukleme kismi: $successOps/$totalOps. Sorunlar: $($failedItems -join ' | ')" -Level 'WARN' -Source 'Restore'
    } else {
        Write-WFStatus -Message 'Geri yukleme basarisiz.' -Type Error
        foreach ($fi in $failedItems) { Write-Host "    - $fi" -ForegroundColor Red }
        Write-WFLog -Message "Geri yukleme basarisiz: $($failedItems -join ' | ')" -Level 'ERROR' -Source 'Restore'
    }

    Write-Host ''
    Read-Host '  Ana menuye donmek icin Enter''a basin'
}

# ================================================================
# YEDEK SIL
# ================================================================

function Remove-WFBackupEntry {
    Show-WFBanner
    Write-Host '  Yedek Sil' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'
    Write-Host ''

    $inv = Get-WFBackupInventory

    if ($inv.FullBackups.Count -eq 0) {
        Write-WFStatus -Message 'Silinecek tam yedek bulunamadi.' -Type Warn
        Read-Host '  Geri donmek icin Enter''a basin'
        return
    }

    Write-Host '  Tam Yedekler:' -ForegroundColor DarkCyan
    for ($i = 0; $i -lt $inv.FullBackups.Count; $i++) {
        $fb      = $inv.FullBackups[$i]
        $dateStr = if ($fb.CreatedAt -ne '') { ([datetime]$fb.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '?' }
        Write-Host "  [$($i+1)] $($fb.Name)  |  $dateStr  |  $($fb.SizeMB) MB" -ForegroundColor White
    }
    Write-Host ''
    Write-Host '  [0] Iptal'
    Write-Host ''

    $raw    = Read-Host '  Silinecek yedek numarasi'
    $choice = $raw.Trim()
    if ($choice -eq '0' -or $choice -eq '') { return }
    if ($choice -notmatch '^\d+$') { return }

    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $inv.FullBackups.Count) {
        Write-WFStatus -Message 'Gecersiz secim.' -Type Warn
        Start-Sleep -Seconds 1
        return
    }

    $fb = $inv.FullBackups[$idx]
    Write-Host ''
    $confirmed = Read-WFConfirmation -Prompt "'$($fb.Name)' silinsin mi? (Geri alinamaz)"
    if (-not $confirmed) {
        Write-WFStatus -Message 'Iptal edildi.' -Type Info
        return
    }

    try {
        Remove-Item -LiteralPath $fb.Path -Recurse -Force -ErrorAction Stop
        Write-WFStatus -Message "Yedek silindi: $($fb.Name)" -Type OK
        Write-WFLog -Message "Yedek silindi: $($fb.Path)" -Level 'INFO' -Source 'Backup'
    } catch {
        Write-WFStatus -Message "Silinemedi: $($_.Exception.Message)" -Type Error
        Write-WFLog -Message "Yedek silme hatasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'Backup'
    }

    Read-Host '  Devam icin Enter''a basin'
}

# ================================================================
# ANA MENU (Export)
# ================================================================

function Show-BackupRestoreMenu {
    $running = $true

    while ($running) {
        Show-WFBanner
        Write-Host '  Yedekleme / Geri Al' -ForegroundColor Cyan
        Write-WFSeparator -SepChar '-'
        Write-Host ''
        Write-Host '  [1]  Tam Yedek Al' -ForegroundColor White
        Write-Host '  [2]  Tam Yedekten Geri Yukle' -ForegroundColor White
        Write-Host '  [3]  Registry Key Yedekle (.reg)' -ForegroundColor White
        Write-Host '  [4]  Tum Yedekleri Listele' -ForegroundColor White
        Write-Host '  [5]  Yedek Sil' -ForegroundColor White
        Write-Host ''
        Write-Host '  [0]  Ana Menu' -ForegroundColor DarkGray
        Write-Host ''

        $choice = Read-WFMenuChoice -ValidChoices @('0','1','2','3','4','5') -Prompt 'Seciminiz'

        switch ($choice) {
            '1' {
                New-WFFullBackup
                Write-Host ''
                Read-Host '  Devam icin Enter''a basin'
            }
            '2' { Restore-WFFromFullBackup }
            '3' {
                New-WFRegistryBackup
                Write-Host ''
                Read-Host '  Devam icin Enter''a basin'
            }
            '4' { Show-WFBackupList }
            '5' { Remove-WFBackupEntry }
            '0' { $running = $false }
        }
    }
}
