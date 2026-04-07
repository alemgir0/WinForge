#
# WinForge v1.1 - modules/Set-WindowsTweaks.ps1
# Dot-sourced by WinForge.ps1
# Exports: Show-TweakMenu
#

Set-StrictMode -Version 2.0

# ================================================================
# REGISTRY YARDIMCILARI
# ================================================================

function Get-WFRegistryValue {
    # Property = '' -> (Default) deger hedeflenir
    param([string]$Path, [string]$Property)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{ KeyExists = $false; ValueExists = $false; Value = $null; ValueType = $null }
    }

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop

        if ($Property -eq '') {
            # (Default) deger: .GetValue($null) kullan - en guvenilir yontem
            $val = $item.GetValue($null)
            return [ordered]@{
                KeyExists   = $true
                ValueExists = ($null -ne $val)
                Value       = $val
                ValueType   = 'String'
            }
        }

        # Deger var mi kontrol
        $allNames = @($item.GetValueNames())
        if ($Property -notin $allNames) {
            return [ordered]@{ KeyExists = $true; ValueExists = $false; Value = $null; ValueType = $null }
        }

        $val = $item.GetValue($Property)
        $kindStr = $item.GetValueKind($Property).ToString()
        return [ordered]@{ KeyExists = $true; ValueExists = $true; Value = $val; ValueType = $kindStr }

    }
    catch {
        Write-WFLog -Message "Get-WFRegistryValue hatasi [$Path] [$Property]: $($_.Exception.Message)" -Level 'WARN' -Source 'TweakEngine'
        return [ordered]@{ KeyExists = $true; ValueExists = $false; Value = $null; ValueType = $null }
    }
}

function Set-WFRegistryValue {
    param([string]$Path, [string]$Property, [string]$ValueType, $Value)

    # Key yoksa olustur (tum ara duzeyler dahil)
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        catch [System.UnauthorizedAccessException] {
            throw "Registry anahtari olusturulamadi (Erisim Engellendi): $Path"
        }
        catch {
            throw "Registry anahtari olusturulamadi: $($_.Exception.Message)"
        }
    }

    if ($Property -eq '') {
        try {
            Set-ItemProperty -LiteralPath $Path -Name '(default)' -Value $Value -ErrorAction Stop
        }
        catch [System.UnauthorizedAccessException] {
            throw "Registry varsayilan degeri yazilamadi (Erisim Engellendi): $Path"
        }
        catch {
            throw "Registry varsayilan degeri yazilamadi: $($_.Exception.Message)"
        }
        return
    }

    $typeMap = @{
        'DWord'        = 'DWord'
        'QWord'        = 'QWord'
        'String'       = 'String'
        'ExpandString' = 'ExpandString'
        'Binary'       = 'Binary'
        'MultiString'  = 'MultiString'
    }
    $regType = if ($typeMap.ContainsKey($ValueType)) { $typeMap[$ValueType] } else { 'String' }
    
    try {
        New-ItemProperty -LiteralPath $Path -Name $Property -Value $Value -PropertyType $regType -Force -ErrorAction Stop | Out-Null
    }
    catch [System.UnauthorizedAccessException] {
        throw "Registry degeri yazilamadi (Erisim Engellendi): $Path\$Property"
    }
    catch {
        throw "Registry degeri yazilamadi: $($_.Exception.Message)"
    }
}

function Remove-WFRegistryValue {
    param([string]$Path, [string]$Property)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    try {
        $propName = if ($Property -eq '') { '(default)' } else { $Property }
        Remove-ItemProperty -LiteralPath $Path -Name $propName -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-WFLog -Message "Remove-WFRegistryValue hatasi [$Path]: $($_.Exception.Message)" -Level 'WARN' -Source 'TweakEngine'
    }
}

function Remove-WFRegistryKeyTree {
    # DeleteKeyIfCreated rollback: key agacini sil, sonra bos GUID ust anahtari temizle
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        Write-WFLog -Message "Key agaci silindi: $Path" -Level 'INFO' -Source 'TweakEngine'
    }

    # Eger ust anahtar GUID formundaysa ve bossaldin
    $parentPath = Split-Path -LiteralPath $Path -Parent
    if (-not (Test-Path -LiteralPath $parentPath)) { return }

    $parentLeaf = Split-Path -Leaf $parentPath
    $guidPattern = '^\{[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}$'
    if ($parentLeaf -notmatch $guidPattern) { return }

    try {
        $parentItem = Get-Item -LiteralPath $parentPath -ErrorAction SilentlyContinue
        if ($null -eq $parentItem) { return }
        $valNames = @($parentItem.GetValueNames())
        $subNames = @($parentItem.GetSubKeyNames())
        if ($valNames.Count -eq 0 -and $subNames.Count -eq 0) {
            Remove-Item -LiteralPath $parentPath -Force -ErrorAction SilentlyContinue
            Write-WFLog -Message "Bos GUID key temizlendi: $parentPath" -Level 'INFO' -Source 'TweakEngine'
        }
    }
    catch {
        Write-WFLog -Message "Ust key temizleme hatasi: $($_.Exception.Message)" -Level 'WARN' -Source 'TweakEngine'
    }
}

# ================================================================
# KATALOG
# ================================================================

function Get-WFTweakCatalog {
    $path = Join-Path $Script:WF_DataDir 'TweakCatalog.psd1'
    if (-not (Test-Path -LiteralPath $path)) {
        Write-WFLog -Message "TweakCatalog.psd1 bulunamadi: $path" -Level 'ERROR' -Source 'TweakEngine'
        return $null
    }
    try {
        $content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        return ([scriptblock]::Create($content)).Invoke()[0]
    }
    catch {
        Write-WFLog -Message "TweakCatalog.psd1 yuklenemedi: $($_.Exception.Message)" -Level 'ERROR' -Source 'TweakEngine'
        return $null
    }
}

# ================================================================
# UYGULANABILIRLIK VE UYUM KONTROLU
# ================================================================

function Test-WFTweakApplicable {
    param($Tweak)

    # Preflight hazir degilse varsayilan degerleri kullan
    $build = if ($null -ne $Script:WF_Preflight) { [int]$Script:WF_Preflight.OsBuild }   else { 0 }
    $edition = if ($null -ne $Script:WF_Preflight) { $Script:WF_Preflight.OsEdition }       else { 'Unknown' }
    $isAdmin = if ($null -ne $Script:WF_Preflight) { [bool]$Script:WF_Preflight.IsAdmin }   else { $false }

    if ($build -lt $Tweak.MinBuild) {
        return [ordered]@{ Applicable = $false; Reason = "Bu sistemde desteklenmeyebilir" }
    }
    if ($build -gt $Tweak.MaxBuild) {
        return [ordered]@{ Applicable = $false; Reason = "Bu sistemde desteklenmeyebilir" }
    }
    if ($Tweak.SupportedEditions.Count -gt 0 -and $edition -notin $Tweak.SupportedEditions) {
        return [ordered]@{ Applicable = $false; Reason = "Bu sistemde desteklenmeyebilir" }
    }
    if ($Tweak.RequiresAdmin -and -not $isAdmin) {
        return [ordered]@{ Applicable = $false; Reason = 'Admin yetkisi gerekiyor' }
    }
    return [ordered]@{ Applicable = $true; Reason = '' }
}

function Get-WFTweakComplianceStatus {
    # Donusu: 'Applied' | 'NotApplied' | 'PartiallyApplied' | 'Unsupported'
    param($Tweak)

    $appl = Test-WFTweakApplicable -Tweak $Tweak
    if (-not $appl.Applicable) { return 'Unsupported' }

    $compliant = 0
    foreach ($action in $Tweak.Actions) {
        $actionType = if ($null -ne $action.Type) { $action.Type } else { 'Registry' }
        if ($actionType -eq 'Powercfg') {
            try {
                $out = & powercfg.exe /getactivescheme 2>&1
                if ($out -match $action.DesiredValue -or $out -match 'High performance|Yüksek performans') { $compliant++ }
            }
            catch { }
            continue
        }

        $reg = Get-WFRegistryValue -Path $action.Path -Property $action.Property
        if ($reg.ValueExists) {
            $match = switch ($action.ValueType) {
                'DWord' { [int]$reg.Value -eq [int]$action.DesiredValue }
                'QWord' { [long]$reg.Value -eq [long]$action.DesiredValue }
                default { "$($reg.Value)" -eq "$($action.DesiredValue)" }
            }
            if ($match) { $compliant++ }
        }
    }

    $total = $Tweak.Actions.Count
    if ($compliant -eq $total) { return 'Applied' }
    if ($compliant -eq 0) { return 'NotApplied' }
    return 'PartiallyApplied'
}

# ================================================================
# SNAPSHOT
# ================================================================

function Get-WFTweakSnapshotData {
    # Disk'e yazmadan once hafizada snapshot verisi olusturur
    param($Tweak)

    $actionSnaps = @()
    $idx = 0

    foreach ($action in $Tweak.Actions) {
        $actionType = if ($null -ne $action.Type) { $action.Type } else { 'Registry' }
        if ($actionType -eq 'Powercfg') {
            $actionSnaps += @{
                Index        = $idx
                Type         = 'Powercfg'
                DesiredValue = $action.DesiredValue
                Applied      = $false
            }
            $idx++
            continue
        }

        $reg = Get-WFRegistryValue -Path $action.Path -Property $action.Property
        $actionSnaps += @{
            Index             = $idx
            Path              = $action.Path
            Property          = $action.Property
            IsDefaultValue    = ($action.Property -eq '')
            KeyExisted        = $reg.KeyExists
            ValueExisted      = $reg.ValueExists
            PreviousValue     = $reg.Value
            PreviousValueType = $reg.ValueType
            DesiredValue      = $action.DesiredValue
            RevertMode        = $action.RevertMode
            DefaultValue      = $action.DefaultValue
            Applied           = $false
        }
        $idx++
    }

    return [ordered]@{
        TweakId      = $Tweak.Id
        TweakName    = $Tweak.Name
        AppliedAt    = (Get-Date -Format 'o')
        ComputerName = $env:COMPUTERNAME
        OSBuild      = if ($null -ne $Script:WF_Preflight) { $Script:WF_Preflight.OsBuild } else { 0 }
        Actions      = $actionSnaps
    }
}

function Save-WFSnapshotToDisk {
    param([hashtable]$SnapshotData)

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fileName = "$($SnapshotData.TweakId)_$stamp.json"
    $filePath = Join-Path $Script:WF_BackupTweaks $fileName

    try {
        $SnapshotData | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $filePath -Encoding UTF8 -ErrorAction Stop
        Write-WFLog -Message "Snapshot kaydedildi: $fileName" -Level 'INFO' -Source 'TweakEngine'
        return $filePath
    }
    catch {
        Write-WFLog -Message "Snapshot kaydedilemedi: $($_.Exception.Message)" -Level 'ERROR' -Source 'TweakEngine'
        return $null
    }
}

function Get-WFLatestSnapshotFile {
    param([string]$TweakId)

    $files = Get-ChildItem -LiteralPath $Script:WF_BackupTweaks -Filter "$TweakId`_*.json" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

    if ($null -eq $files -or @($files).Count -eq 0) { return $null }
    return @($files)[0].FullName
}

# ================================================================
# TWEAK UYGULAMA
# ================================================================

function Set-WFSingleTweak {
    # Donusu: ordered @{ Result; Reason }
    # Result: 'Success' | 'Partial' | 'Failed' | 'Skipped' | 'AlreadyApplied'
    param($Tweak)

    $appl = Test-WFTweakApplicable -Tweak $Tweak
    if (-not $appl.Applicable) {
        Write-WFLog -Message "[$($Tweak.Id)] Atlanik: $($appl.Reason)" -Level 'WARN' -Source 'TweakEngine'
        return [ordered]@{ Result = 'Skipped'; Reason = $appl.Reason }
    }

    $status = Get-WFTweakComplianceStatus -Tweak $Tweak
    if ($status -eq 'Applied') {
        $hasPowerCfg = ($Tweak.Actions | Where-Object { if ($null -ne $_.Type) { $_.Type -eq 'Powercfg' } else { $false } }).Count -gt 0
        $msg = if ($hasPowerCfg) { 'Zaten aktif' } else { 'Zaten uygulanmis' }
        Write-WFLog -Message "[$($Tweak.Id)] $msg, atlaniyor." -Level 'INFO' -Source 'TweakEngine'
        return [ordered]@{ Result = 'AlreadyApplied'; Reason = $msg }
    }

    # Snapshot hazirla (hafizada)
    $snapData = Get-WFTweakSnapshotData -Tweak $Tweak

    # Her action'u uygula
    $succeeded = 0
    $failedIdxs = [System.Collections.Generic.List[int]]::new()
    $lastErrorReason = 'Bilinmeyen Hata'

    for ($i = 0; $i -lt $Tweak.Actions.Count; $i++) {
        $action = $Tweak.Actions[$i]
        $actionType = if ($null -ne $action.Type) { $action.Type } else { 'Registry' }

        try {
            if ($actionType -eq 'Powercfg') {
                $checkOut = & powercfg.exe /l 2>&1
                $activeArgs = $action.Arguments
                
                if ($checkOut -notmatch $action.DesiredValue) {
                    $dupOut = & powercfg.exe -duplicatescheme $action.DesiredValue 2>&1
                    if ($dupOut -match '([0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
                        $newGuid = $matches[1]
                        $activeArgs = "/setactive $newGuid"
                    } else {
                        throw "Guc plani desteklenmiyor veya uretilemedi."
                    }
                }
                
                $proc = Start-Process -FilePath "powercfg.exe" -ArgumentList $activeArgs -Wait -PassThru -WindowStyle Hidden
                if ($proc.ExitCode -ne 0) {
                    throw "Komut calistirilamadi (Kod: $($proc.ExitCode))"
                }

                $snapData.Actions[$i].Applied = $true
                $succeeded++
                Write-WFLog -Message "[$($Tweak.Id)] Action $i uygulandi: Powercfg $activeArgs" -Level 'INFO' -Source 'TweakEngine'
            }
            else {
                Set-WFRegistryValue -Path $action.Path -Property $action.Property -ValueType $action.ValueType -Value $action.DesiredValue
                $snapData.Actions[$i].Applied = $true
                $succeeded++
                Write-WFLog -Message "[$($Tweak.Id)] Action $i uygulandi: $($action.Path) [$($action.Property)]=$($action.DesiredValue)" -Level 'INFO' -Source 'TweakEngine'
            }
        }
        catch {
            $failedIdxs.Add($i)
            $excMsg = $_.Exception.Message
            
            $targetStr = if ($actionType -eq 'Powercfg') { "powercfg $($action.Arguments)" } else { "$($action.Path)\$($action.Property)" }
            Write-WFLog -Message "[$($Tweak.Id)] Action $i ($actionType) failed at '$targetStr': $excMsg" -Level 'ERROR' -Source 'TweakEngine'

            if ($excMsg -match 'Registry anahtari olusturulamadi|Registry anahtari yazilamadi') {
                $lastErrorReason = if ($excMsg -match 'Erisim Engellendi') { 'Yonetici yetkisi gerekli' } else { 'Registry anahtari olusturulamadi' }
            }
            elseif ($excMsg -match 'Registry degeri yazilamadi|Registry varsayilan degeri yazilamadi') {
                $lastErrorReason = if ($excMsg -match 'Erisim Engellendi') { 'Yonetici yetkisi gerekli' } else { 'Registry degeri ayarlanamadi' }
            }
            elseif ($excMsg -match 'Komut calistirilamadi') {
                $lastErrorReason = 'Komut calistirilamadi'
            }
            elseif ($excMsg -match 'desteklenmiyor|bulunamadi') {
                $lastErrorReason = 'Bu ayar sisteminizde desteklenmeyebilir'
            }
            else {
                $lastErrorReason = "Islem basarisiz"
            }
        }
    }

    # Snapshot disk'e yaz (uygulama sonuclariyla)
    Save-WFSnapshotToDisk -SnapshotData $snapData | Out-Null

    # Oturum bayraklari
    if ($Tweak.RequiresExplorerRestart -and $succeeded -gt 0) { $Script:WF_ExplorerRestartNeeded = $true }
    if ($Tweak.RequiresReboot -and $succeeded -gt 0) { $Script:WF_RebootRecommended = $true }

    if ($failedIdxs.Count -eq 0) {
        Write-WFLog -Message "[$($Tweak.Id)] Tum actionlar basarili." -Level 'OK' -Source 'TweakEngine'
        return [ordered]@{ Result = 'Success'; Reason = '' }
    }
    elseif ($succeeded -gt 0) {
        Write-WFLog -Message "[$($Tweak.Id)] Kismi basari. Basarili olmayan action indexleri: $($failedIdxs -join ',')" -Level 'WARN' -Source 'TweakEngine'
        return [ordered]@{ Result = 'Partial'; Reason = "$succeeded/$($Tweak.Actions.Count) tamamlandi ($lastErrorReason)" }
    }
    else {
        Write-WFLog -Message "[$($Tweak.Id)] Hic action uygulanamadi." -Level 'ERROR' -Source 'TweakEngine'
        return [ordered]@{ Result = 'Failed'; Reason = $lastErrorReason }
    }
}

# ================================================================
# ROLLBACK
# ================================================================

function Undo-WFSingleTweak {
    # Snapshot'tan gercek eski durumu geri yukler.
    # Snapshot yoksa katalog DefaultValue fallback'i kullanilir.
    # Donusu: ordered @{ Result; Reason; ItemsReverted; ItemsFailed }
    param($Tweak)

    if (-not $Tweak.SupportsRollback) {
        return [ordered]@{ Result = 'NoRollback'; Reason = 'Bu tweak icin geri alma desteklenmiyor'; ItemsReverted = 0; ItemsFailed = 0 }
    }

    $snapFile = Get-WFLatestSnapshotFile -TweakId $Tweak.Id

    # --- Snapshot varsa: gercek onceki durumu geri al ---
    if ($null -ne $snapFile) {
        Write-WFLog -Message "[$($Tweak.Id)] Snapshot bulundu: $snapFile" -Level 'INFO' -Source 'TweakEngine'

        try {
            $snapRaw = Get-Content -LiteralPath $snapFile -Raw -Encoding UTF8 -ErrorAction Stop
            $snap = $snapRaw | ConvertFrom-Json
        }
        catch {
            Write-WFLog -Message "[$($Tweak.Id)] Snapshot okunamadi: $($_.Exception.Message)" -Level 'ERROR' -Source 'TweakEngine'
            return [ordered]@{ Result = 'Failed'; Reason = 'Snapshot okunamadi'; ItemsReverted = 0; ItemsFailed = 0 }
        }

        $reverted = 0
        $failed = 0

        foreach ($actionSnap in $snap.Actions) {
            if (-not $actionSnap.Applied) {
                Write-WFLog -Message "[$($Tweak.Id)] Action $($actionSnap.Index) hic uygulanmamis, atlaniyor." -Level 'INFO' -Source 'TweakEngine'
                continue
            }

            try {
                switch ($actionSnap.RevertMode) {
                    'RestorePrevious' {
                        if (-not $actionSnap.ValueExisted) {
                            # Tweak oncesi bu deger yoktu -> sil
                            Remove-WFRegistryValue -Path $actionSnap.Path -Property $actionSnap.Property
                            Write-WFLog -Message "[$($Tweak.Id)] RestorePrevious: deger silindi (onceden yoktu)." -Level 'INFO' -Source 'TweakEngine'
                        }
                        else {
                            # Onceki gercek degeri yaz
                            $prevType = if ($null -ne $actionSnap.PreviousValueType) { $actionSnap.PreviousValueType } else { 'String' }
                            Set-WFRegistryValue -Path $actionSnap.Path -Property $actionSnap.Property -ValueType $prevType -Value $actionSnap.PreviousValue
                            Write-WFLog -Message "[$($Tweak.Id)] RestorePrevious: $($actionSnap.Property) = $($actionSnap.PreviousValue)" -Level 'INFO' -Source 'TweakEngine'
                        }
                    }
                    'UseDefaultValue' {
                        if ($null -ne $actionSnap.DefaultValue) {
                            # ValueType: snapshot'ta PreviousValueType'tan al; yoksa catalog'dan
                            $defType = if ($null -ne $actionSnap.PreviousValueType) { $actionSnap.PreviousValueType } else { 'DWord' }
                            Set-WFRegistryValue -Path $actionSnap.Path -Property $actionSnap.Property -ValueType $defType -Value $actionSnap.DefaultValue
                            Write-WFLog -Message "[$($Tweak.Id)] UseDefaultValue: $($actionSnap.Property) = $($actionSnap.DefaultValue)" -Level 'INFO' -Source 'TweakEngine'
                        }
                        else {
                            Remove-WFRegistryValue -Path $actionSnap.Path -Property $actionSnap.Property
                            Write-WFLog -Message "[$($Tweak.Id)] UseDefaultValue: DefaultValue $null, deger silindi." -Level 'INFO' -Source 'TweakEngine'
                        }
                    }
                    'DeleteValue' {
                        Remove-WFRegistryValue -Path $actionSnap.Path -Property $actionSnap.Property
                        Write-WFLog -Message "[$($Tweak.Id)] DeleteValue: $($actionSnap.Property) silindi." -Level 'INFO' -Source 'TweakEngine'
                    }
                    'DeleteKeyIfCreated' {
                        if (-not $actionSnap.KeyExisted) {
                            Remove-WFRegistryKeyTree -Path $actionSnap.Path
                            Write-WFLog -Message "[$($Tweak.Id)] DeleteKeyIfCreated: $($actionSnap.Path) silindi." -Level 'INFO' -Source 'TweakEngine'
                        }
                        else {
                            # Key onceden vardi; sadece degeri sil, key'i biraK
                            Remove-WFRegistryValue -Path $actionSnap.Path -Property $actionSnap.Property
                            Write-WFLog -Message "[$($Tweak.Id)] DeleteKeyIfCreated->fallback DeleteValue: key onceden vardi." -Level 'INFO' -Source 'TweakEngine'
                        }
                    }
                    default {
                        Write-WFLog -Message "[$($Tweak.Id)] Bilinmeyen RevertMode: $($actionSnap.RevertMode)" -Level 'WARN' -Source 'TweakEngine'
                    }
                }
                $reverted++
            }
            catch {
                $failed++
                Write-WFLog -Message "[$($Tweak.Id)] Rollback action $($actionSnap.Index) hatasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'TweakEngine'
            }
        }

        # Rollback sonrasi session bayraklari
        if ($Tweak.RequiresExplorerRestart -and $reverted -gt 0) { $Script:WF_ExplorerRestartNeeded = $true }
        if ($Tweak.RequiresReboot -and $reverted -gt 0) { $Script:WF_RebootRecommended = $true }

        if ($failed -eq 0) {
            return [ordered]@{ Result = 'Success'; Reason = ''; ItemsReverted = $reverted; ItemsFailed = 0 }
        }
        elseif ($reverted -gt 0) {
            return [ordered]@{ Result = 'Partial'; Reason = "$reverted geri alindi, $failed basarisiz"; ItemsReverted = $reverted; ItemsFailed = $failed }
        }
        else {
            return [ordered]@{ Result = 'Failed'; Reason = 'Hic bir islem geri alinamadi'; ItemsReverted = 0; ItemsFailed = $failed }
        }
    }

    # --- Snapshot yok: DefaultValue fallback (son care) ---
    Write-WFLog -Message "[$($Tweak.Id)] Snapshot bulunamadi. DefaultValue fallback kullaniliyor." -Level 'WARN' -Source 'TweakEngine'

    $reverted = 0
    $failed = 0

    foreach ($action in $Tweak.Actions) {
        try {
            if ($action.RevertMode -eq 'DeleteValue' -or $action.RevertMode -eq 'DeleteKeyIfCreated') {
                Remove-WFRegistryValue -Path $action.Path -Property $action.Property
            }
            elseif ($null -ne $action.DefaultValue) {
                Set-WFRegistryValue -Path $action.Path -Property $action.Property -ValueType $action.ValueType -Value $action.DefaultValue
            }
            else {
                Remove-WFRegistryValue -Path $action.Path -Property $action.Property
            }
            $reverted++
        }
        catch {
            $failed++
            Write-WFLog -Message "[$($Tweak.Id)] Fallback rollback hatasi: $($_.Exception.Message)" -Level 'ERROR' -Source 'TweakEngine'
        }
    }

    $resultStr = if ($failed -eq 0) { 'Success' } elseif ($reverted -gt 0) { 'Partial' } else { 'Failed' }
    return [ordered]@{ Result = $resultStr; Reason = "Snapshot yok, varsayilan degerler kullanildi"; ItemsReverted = $reverted; ItemsFailed = $failed }
}

# ================================================================
# TWEAK SECIM / UYGULAMA MENUSU
# ================================================================

function Show-WFTweaksByRisk {
    param(
        [string]$RiskLevel,
        [array]$Tweaks
    )

    # Bu risk seviyesindeki tweakler
    $levelTweaks = @($Tweaks | Where-Object { $_.RiskLevel -eq $RiskLevel })
    if ($levelTweaks.Count -eq 0) {
        Write-WFStatus -Message "Bu seviyede tweak tanimlanmamis." -Type Warn
        Start-Sleep -Seconds 1
        return
    }

    # Risky ozel: her tweak icin cift onay; toggle listesi kullanma
    if ($RiskLevel -eq 'Risky') {
        Show-WFRiskyTweakMenu -Tweaks $levelTweaks
        return
    }

    # Safe/Advanced: toggle tabanli secim
    # Baslangic secimi: EnabledByDefault ve NotApplied olanlar
    $selected = @()
    foreach ($tw in $levelTweaks) {
        $appl = Test-WFTweakApplicable -Tweak $tw
        $status = if ($appl.Applicable) { Get-WFTweakComplianceStatus -Tweak $tw } else { 'Unsupported' }
        $pre = $tw.EnabledByDefault -and $status -eq 'NotApplied'
        $selected += $pre
    }

    $exiting = $false
    while (-not $exiting) {
        Show-WFBanner
        $levelLabel = if ($RiskLevel -eq 'Advanced') { '!! Advanced Tweakler !!' } else { 'Safe Tweakler' }
        Write-Host "  $levelLabel" -ForegroundColor Cyan

        if ($RiskLevel -eq 'Advanced') {
            Write-Host '  UYARI: Bu tweakler ileri duzeydir. Uygulamadan once aciklamalari okuyun.' -ForegroundColor Yellow
        }
        Write-WFSeparator -SepChar '-'
        Write-Host '  Numara girerek sec/kaldir. Bos Enter = uygula.' -ForegroundColor DarkGray
        Write-Host ''

        for ($i = 0; $i -lt $levelTweaks.Count; $i++) {
            $tw = $levelTweaks[$i]
            $appl = Test-WFTweakApplicable -Tweak $tw
            $status = if ($appl.Applicable) { Get-WFTweakComplianceStatus -Tweak $tw } else { 'Unsupported' }

            $mark = if ($selected[$i]) { 'X' } else { ' ' }
            $num = "[$($i+1)]".PadLeft(4)

            $rollbackNote = if (-not $tw.SupportsRollback) { ' [GERI ALINAMAZ]' } else { '' }
            $rebootNote = if ($tw.RequiresReboot) { ' [yeniden baslatma]' } else { '' }

            $displayName = if ($tw.Name.Length -gt 45) { $tw.Name.Substring(0, 42) + '...' } else { $tw.Name }

            switch ($status) {
                'Applied' {
                    Write-Host "  $num [$mark] $displayName$rollbackNote" -ForegroundColor DarkGray
                    Write-Host "       $(' ' * 5) [UYGULANMIS]$rebootNote" -ForegroundColor Green 
                }
                'PartiallyApplied' {
                    Write-Host "  $num [$mark] $displayName$rollbackNote" -ForegroundColor Yellow
                    Write-Host "       $(' ' * 5) [KISMI]$rebootNote" -ForegroundColor Yellow 
                }
                'Unsupported' { Write-Host "  $num [ ] $displayName [DESTEKSIZ: $($appl.Reason)]" -ForegroundColor DarkGray }
                default { Write-Host "  $num [$mark] $displayName$rollbackNote$rebootNote" }
            }
        }

        Write-Host ''
        Write-Host '  [A] Tumunu sec    [N] Hicbirini secme    [0] Geri' -ForegroundColor DarkGray
        Write-Host ''

        $raw = Read-Host '  Secim'
        $choice = $raw.Trim().ToUpper()

        if ($choice -eq '0' -or $choice -eq 'G') {
            $exiting = $true
        }
        elseif ($choice -eq 'A') {
            for ($i = 0; $i -lt $levelTweaks.Count; $i++) {
                $appl = Test-WFTweakApplicable -Tweak $levelTweaks[$i]
                if ($appl.Applicable) { $selected[$i] = $true }
            }
        }
        elseif ($choice -eq 'N') {
            $selected = @($false) * $levelTweaks.Count
        }
        elseif ($choice -eq '') {
            # Uygula
            $toApply = @()
            for ($i = 0; $i -lt $levelTweaks.Count; $i++) {
                if ($selected[$i]) { $toApply += $levelTweaks[$i] }
            }
            if ($toApply.Count -eq 0) {
                Write-WFStatus -Message 'Hicbir tweak secili degil.' -Type Warn
                Start-Sleep -Seconds 1
            }
            else {
                $confirmed = Read-WFConfirmation -Prompt "$($toApply.Count) tweak uygulansin mi?"
                if ($confirmed) {
                    Write-Host ''
                    $ok = 0; $skip = 0; $fail = 0
                    foreach ($tw in $toApply) {
                        Write-Host "  Uygulanıyor: $($tw.Name)..." -ForegroundColor Cyan -NoNewline
                        $res = Set-WFSingleTweak -Tweak $tw
                        switch ($res.Result) {
                            'Success' { Write-Host ' [TAMAM]'           -ForegroundColor Green; $ok++ }
                            'AlreadyApplied' { Write-Host " [ATLANDI: $($res.Reason)]" -ForegroundColor DarkGray; $skip++ }
                            'Skipped' { Write-Host " [ATLANDI: $($res.Reason)]" -ForegroundColor DarkGray; $skip++ }
                            'Partial' { Write-Host " [KISMI: $($res.Reason)]"   -ForegroundColor Yellow; $ok++ }
                            default { Write-Host " [HATA: $($res.Reason)]"    -ForegroundColor Red; $fail++ }
                        }
                    }
                    Write-Host ''
                    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkGray
                    Write-Host '    Sonuc Ozeti' -ForegroundColor Cyan
                    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkGray
                    Write-Host -Object '    Basarili : ' -NoNewline -ForegroundColor DarkGray
                    Write-Host -Object $ok -ForegroundColor Green
                    Write-Host -Object '    Atlandi  : ' -NoNewline -ForegroundColor DarkGray
                    Write-Host -Object $skip -ForegroundColor Yellow
                    Write-Host -Object '    Basarisiz: ' -NoNewline -ForegroundColor DarkGray
                    Write-Host -Object $fail -ForegroundColor Red
                    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkGray
                    Write-Host '    Detay icin log dosyasini inceleyin.' -ForegroundColor DarkGray
                    Write-Host ''
                    Read-Host '  Devam icin Enter''a basin'
                    $exiting = $true
                }
            }
        }
        elseif ($choice -match '^\d+$') {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $levelTweaks.Count) {
                $appl = Test-WFTweakApplicable -Tweak $levelTweaks[$idx]
                if ($appl.Applicable) {
                    $selected[$idx] = -not $selected[$idx]
                }
                else {
                    Write-WFStatus -Message "Bu tweak sisteminizde desteklenmiyor: $($appl.Reason)" -Type Warn
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}

function Show-WFRiskyTweakMenu {
    # Risky tweakler: her biri icin ayri cift onay
    param([array]$Tweaks)

    Show-WFBanner
    Write-Host '  !! RISKY TWEAKLER !!' -ForegroundColor Red
    Write-WFSeparator -SepChar '-'
    Write-Host '  Bu ayarlar sisteminizi olumsuz etkileyebilir.' -ForegroundColor Yellow
    Write-Host '  Her tweak icin cift onay istenir.' -ForegroundColor Yellow
    Write-Host ''

    for ($i = 0; $i -lt $Tweaks.Count; $i++) {
        $tw = $Tweaks[$i]
        $appl = Test-WFTweakApplicable -Tweak $tw
        $status = if ($appl.Applicable) { Get-WFTweakComplianceStatus -Tweak $tw } else { 'Unsupported' }

        $rollNote = if (-not $tw.SupportsRollback) { ' [GERI ALINAMAZ]' } else { '' }
        $num = "[$($i+1)]".PadLeft(4)
        $displayName = if ($tw.Name.Length -gt 45) { $tw.Name.Substring(0, 42) + '...' } else { $tw.Name }

        switch ($status) {
            'Applied' { Write-Host "  $num $displayName$rollNote [UYGULANMIS]" -ForegroundColor DarkGray }
            'Unsupported' { Write-Host "  $num $displayName [DESTEKSIZ: $($appl.Reason)]" -ForegroundColor DarkGray }
            default { Write-Host "  $num $displayName$rollNote" -ForegroundColor Red }
        }
    }

    Write-Host ''
    Write-Host '  [0] Geri'
    Write-Host ''

    $raw = Read-Host '  Uygulamak istediginiz tweakin numarasini girin'
    $choice = $raw.Trim()
    if ($choice -eq '0' -or $choice -eq '') { return }

    if ($choice -notmatch '^\d+$') { return }
    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $Tweaks.Count) {
        Write-WFStatus -Message 'Gecersiz numara.' -Type Warn
        Start-Sleep -Seconds 1
        return
    }

    $tw = $Tweaks[$idx]
    $appl = Test-WFTweakApplicable -Tweak $tw
    if (-not $appl.Applicable) {
        Write-WFStatus -Message "Bu tweak uygulanamaz: $($appl.Reason)" -Type Warn
        Start-Sleep -Seconds 2
        return
    }

    Write-Host ''
    Write-Host '  ================================================================' -ForegroundColor Red
    Write-Host "  $($tw.Name)" -ForegroundColor Red
    Write-Host "  $($tw.Description)" -ForegroundColor Yellow
    if (-not $tw.SupportsRollback) {
        Write-Host '  !! BU TWEAK GERI ALINAMAZ !!' -ForegroundColor Red
    }
    Write-Host '  ================================================================' -ForegroundColor Red

    # Cift onay (Read-WFDoubleConfirmation WinForge.ps1'de tanimli)
    $confirmed = Read-WFDoubleConfirmation -ActionDescription $tw.Description
    if (-not $confirmed) {
        Write-WFStatus -Message 'Iptal edildi.' -Type Info
        Start-Sleep -Seconds 1
        return
    }

    Write-Host ''
    Write-Host "  Uygulanıyor: $($tw.Name)..." -ForegroundColor Cyan -NoNewline
    $res = Set-WFSingleTweak -Tweak $tw
    switch ($res.Result) {
        'Success' { Write-Host ' [TAMAM]' -ForegroundColor Green }
        'Partial' { Write-Host " [KISMI: $($res.Reason)]" -ForegroundColor Yellow }
        default { Write-Host " [HATA: $($res.Reason)]" -ForegroundColor Red }
    }
    Write-Host ''
    Read-Host '  Devam icin Enter''a basin'
}

# ================================================================
# TWEAK DURUMU
# ================================================================

function Show-WFTweakStatus {
    param([array]$Tweaks)

    Show-WFBanner
    Write-Host '  Tweak Durumu' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'
    Write-Host ''

    $nameW = 32; $riskW = 10; $statusW = 18; $rbW = 14

    Write-Host ("  " + "Tweak".PadRight($nameW) + "Risk".PadRight($riskW) + "Durum".PadRight($statusW) + "Geri Alma") -ForegroundColor DarkCyan
    Write-Host ("  " + ("-" * ($nameW + $riskW + $statusW + $rbW))) -ForegroundColor DarkGray

    foreach ($tw in $Tweaks) {
        $appl = Test-WFTweakApplicable -Tweak $tw
        $status = if ($appl.Applicable) { Get-WFTweakComplianceStatus -Tweak $tw } else { 'Unsupported' }
        $rbLabel = if ($tw.SupportsRollback) { '[X]' } else { '[ ] GERI ALINAMAZ' }

        $statusDisplay = switch ($status) {
            'Applied' { '[UYGULANMIS]' }
            'NotApplied' { '[Uygulanmamis]' }
            'PartiallyApplied' { '[KISMI]' }
            'Unsupported' { '[DESTEKSIZ]' }
            default { $status }
        }

        $nameShort = if ($tw.Name.Length -gt $nameW - 1) { $tw.Name.Substring(0, $nameW - 2) + '>' } else { $tw.Name.PadRight($nameW) }
        $riskStr = $tw.RiskLevel.PadRight($riskW)
        $statusStr = $statusDisplay.PadRight($statusW)

        $color = switch ($status) {
            'Applied' { 'Green' }
            'NotApplied' { 'White' }
            'PartiallyApplied' { 'Yellow' }
            'Unsupported' { 'DarkGray' }
            default { 'White' }
        }
        Write-Host ("  $nameShort$riskStr$statusStr$rbLabel") -ForegroundColor $color
    }

    Write-Host ''
    Read-Host '  Geri donmek icin Enter''a basin'
}

# ================================================================
# ROLLBACK MENUSU
# ================================================================

function Show-WFRollbackMenu {
    param([array]$Tweaks)

    Show-WFBanner
    Write-Host '  Rollback - Tweak Geri Al' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'
    Write-Host ''

    # Snapshot dosyasi olan tweakler
    $rollbackable = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($tw in $Tweaks) {
        if (-not $tw.SupportsRollback) { continue }
        $snapFile = Get-WFLatestSnapshotFile -TweakId $tw.Id
        $rollbackable.Add(@{
                Tweak    = $tw
                SnapFile = $snapFile
                HasSnap  = ($null -ne $snapFile)
            })
    }

    if ($rollbackable.Count -eq 0) {
        Write-WFStatus -Message 'Geri alinabilir tweak bulunamadi.' -Type Warn
        Read-Host '  Geri donmek icin Enter''a basin'
        return
    }

    for ($i = 0; $i -lt $rollbackable.Count; $i++) {
        $entry = $rollbackable[$i]
        $tw = $entry.Tweak
        $num = "[$($i+1)]".PadLeft(4)

        if ($entry.HasSnap) {
            $snapDate = (Get-Item -LiteralPath $entry.SnapFile).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            $status = Get-WFTweakComplianceStatus -Tweak $tw
            $statusLbl = switch ($status) {
                'Applied' { '[UYGULANMIS - geri alinabilir]' }
                default { "[Durum: $status]" }
            }
            Write-Host "  $num $($tw.Name)" -ForegroundColor White
            Write-Host "       Snapshot: $snapDate  $statusLbl" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  $num $($tw.Name)" -ForegroundColor DarkGray
            Write-Host '       [Snapshot yok - varsayilan deger fallback kullanilir]' -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    Write-Host '  [0] Geri'
    Write-Host ''

    $raw = Read-Host '  Geri almak istediginiz tweakin numarasi'
    $choice = $raw.Trim()
    if ($choice -eq '0' -or $choice -eq '') { return }
    if ($choice -notmatch '^\d+$') { return }

    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $rollbackable.Count) {
        Write-WFStatus -Message 'Gecersiz numara.' -Type Warn
        Start-Sleep -Seconds 1
        return
    }

    $entry = $rollbackable[$idx]
    $tw = $entry.Tweak

    Write-Host ''
    $msg = if ($entry.HasSnap) { "'$($tw.Name)' tweaki geri alinsin mi?" } else { "'$($tw.Name)' tweaki snapshot yok, varsayilan degerlerle geri alinsin mi?" }
    $confirmed = Read-WFConfirmation -Prompt $msg
    if (-not $confirmed) {
        Write-WFStatus -Message 'Iptal edildi.' -Type Info
        Start-Sleep -Seconds 1
        return
    }

    Write-Host ''
    Write-Host "  Geri aliniyor: $($tw.Name)..." -ForegroundColor Cyan -NoNewline
    $res = Undo-WFSingleTweak -Tweak $tw
    switch ($res.Result) {
        'Success' { Write-Host " [TAMAM] ($($res.ItemsReverted) islem)" -ForegroundColor Green }
        'Partial' { Write-Host " [KISMI] $($res.Reason)" -ForegroundColor Yellow }
        'NoRollback' { Write-Host ' [DESTEKSIZ]' -ForegroundColor Red }
        default { Write-Host " [HATA] $($res.Reason)" -ForegroundColor Red }
    }
    Write-Host ''
    Read-Host '  Devam icin Enter''a basin'
}

# ================================================================
# ANA MENU (Export)
# ================================================================

function Show-TweakMenu {
    $catalog = Get-WFTweakCatalog
    if ($null -eq $catalog) {
        Show-WFBanner
        Write-WFStatus -Message 'TweakCatalog.psd1 yuklenemedi. data\ klasorunu kontrol edin.' -Type Error
        Read-Host '  Geri donmek icin Enter''a basin'
        return
    }

    $allTweaks = @($catalog.Tweaks)

    $running = $true
    while ($running) {
        Show-WFBanner
        Write-Host '  Windows Tweakleri' -ForegroundColor Cyan
        Write-WFSeparator -SepChar '-'
        Write-Host ''
        Write-Host '  [1]  Safe Tweakler       (onerilen)' -ForegroundColor White
        Write-Host '  [2]  Advanced Tweakler   (dikkatli kullan)' -ForegroundColor Yellow
        Write-Host '  [3]  Risky Tweakler      (cift onay gerekli)' -ForegroundColor Red
        Write-Host '  [4]  Tweak Durumu' -ForegroundColor White
        Write-Host '  [5]  Geri Al (Rollback)' -ForegroundColor White
        Write-Host ''
        Write-Host '  [0]  Ana Menu' -ForegroundColor DarkGray
        Write-Host ''

        $choice = Read-WFMenuChoice -ValidChoices @('0', '1', '2', '3', '4', '5') -Prompt 'Seciminiz'

        switch ($choice) {
            '1' { Show-WFTweaksByRisk -RiskLevel 'Safe'     -Tweaks $allTweaks }
            '2' { Show-WFTweaksByRisk -RiskLevel 'Advanced' -Tweaks $allTweaks }
            '3' { Show-WFTweaksByRisk -RiskLevel 'Risky'    -Tweaks $allTweaks }
            '4' { Show-WFTweakStatus  -Tweaks $allTweaks }
            '5' { Show-WFRollbackMenu -Tweaks $allTweaks }
            '0' { $running = $false }
        }
    }
}
