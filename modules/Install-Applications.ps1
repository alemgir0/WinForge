#
# WinForge v1.1 - modules/Install-Applications.ps1
# Dot-sourced by WinForge.ps1
#
# Exports : Show-AppInstallMenu
#
# Not: Bu modul WinForge.ps1 tarafindan dot-source edilir.
# Write-WFLog, Write-WFStatus, Write-WFSeparator, Read-WFMenuChoice,
# Read-WFConfirmation, Show-WFBanner ve $Script:WF_* degiskenleri
# o dosyada tanimlidir.
#

Set-StrictMode -Version 2.0

# ================================================================
# KATALOG YUKLEYICI
# ================================================================
function Get-WFAppCatalog {
    <#
    .SYNOPSIS
        AppCatalog.psd1 dosyasini yukler ve dondurur.
        Dosya okunamazsa $null doner; cagiran taraf kontrol etmeli.
    #>
    $catalogPath = Join-Path $Script:WF_DataDir 'AppCatalog.psd1'

    if (-not (Test-Path -LiteralPath $catalogPath)) {
        Write-WFLog -Message "AppCatalog.psd1 bulunamadi: $catalogPath" -Level 'ERROR' -Source 'AppInstall'
        return $null
    }

    try {
        $content = [System.IO.File]::ReadAllText($catalogPath, [System.Text.Encoding]::UTF8)
        $catalog = ([scriptblock]::Create($content)).Invoke()[0]
        return $catalog
    }
    catch {
        Write-WFLog -Message "AppCatalog.psd1 yuklenemedi: $($_.Exception.Message)" -Level 'ERROR' -Source 'AppInstall'
        return $null
    }
}

# ================================================================
# KURULUM DURUMU KONTROLU
# Test-WFAppInstalled: exit code'a guvenilmez; stdout parse edilir.
# ================================================================
function Test-WFAppInstalled {
    <#
    .SYNOPSIS
        Bir winget paketinin kurulu olup olmadigini kontrol eder.
        Birincil kontrol: winget list stdout'unda package ID aranir.
        Ikincil kontrol: "bulunamadi" ifadesi varsa $false doner.
        Exit code yardimci sinyal olarak kullanilir, tek kaynak degildir.

    .PARAMETER Id
        winget paket ID'si (ornek: '7zip.7zip').

    .OUTPUTS [bool]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        
        [string]$Name = ''
    )

    try {
        # 1. winget check
        $listOutput = & winget.exe list --id $Id --exact --accept-source-agreements 2>&1
        $listExit = $LASTEXITCODE

        $outputLines = @($listOutput | ForEach-Object { "$_" } | Where-Object { $_ -ne '' })
        
        $idEscaped = [regex]::Escape($Id)
        $matchLines = @($outputLines | Where-Object {
            $_ -notmatch '^\s*-+\s*$' -and
            $_ -notmatch '(?i)^Name\s+Id' -and
            $_ -match $idEscaped
        })

        if ($matchLines.Count -gt 0) {
            Write-WFLog -Message "AppInstalled [$Id]: winget exact match basarili." -Level 'INFO' -Source 'AppInstall'
            return 'Installed'
        }
    }
    catch {
        Write-WFLog -Message "AppInstalled [$Id]: Winget isleme hatasi: $($_.Exception.Message)" -Level 'WARN' -Source 'AppInstall'
    }

    try {
        # 2. Registry Fallback
        $searchTerm = if ($Name) { $Name } else { ($Id -split '\.')[-1] }
        $searchEsc = [regex]::Escape($searchTerm)
        
        $regPaths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        
        $found = @(Get-ItemProperty -Path $regPaths -ErrorAction SilentlyContinue | Where-Object { 
            if ($null -ne $_ -and $null -ne $_.PSObject -and $null -ne $_.PSObject.Properties['DisplayName']) {
                $val = [string]$_.DisplayName
                $val -match $searchEsc
            } else {
                $false
            }
        })
        
        if ($found.Count -gt 0) {
            Write-WFLog -Message "AppInstalled [$Id]: Registry fallback match basarili ($searchTerm)." -Level 'INFO' -Source 'AppInstall'
            return 'Installed'
        }
    }
    catch {
        Write-WFLog -Message "AppInstalled [$Id]: Registry tarama hatasi: $($_.Exception.Message)" -Level 'WARN' -Source 'AppInstall'
    }

    # Uncertain cases
    if (Get-Variable -Name 'listExit' -ErrorAction SilentlyContinue) {
        if ($listExit -ne 0) {
            $notFoundCode = ($listExit -eq -1978335212)
            $outStr = $outputLines -join ' '
            $hasNotFoundStr = ($outStr -match 'No installed package found|Bulunamadi|Keine installierten|Aucun package|No se encontro')
            
            if (-not $notFoundCode -and -not $hasNotFoundStr) {
                Write-WFLog -Message "AppInstalled [$Id]: winget hata verdi (Exit: $listExit) ve registry'de bulunamadi, durum belirsiz." -Level 'WARN' -Source 'AppInstall'
                return 'Unknown'
            }
        }
    }

    Write-WFLog -Message "AppInstalled [$Id]: kontroller sirasinda bulunamadi." -Level 'INFO' -Source 'AppInstall'
    return 'NotInstalled'
}

# ================================================================
# TEKIL UYGULAMA KURULUMU
# ================================================================
function Install-WFSingleApp {
    <#
    .SYNOPSIS
        winget ile tek bir uygulamayi kurar.
        Savunmaci parametreler: --exact --source winget --silent
        --accept-package-agreements --accept-source-agreements --disable-interactivity

    .OUTPUTS
        Hashtable: Success, ExitCode, AlreadyInstalled, NeedsReboot, ErrorDetail
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$ExtraArgs = ''
    )

    # Standart savunmaci arguman listesi
    $wingetArgs = @(
        'install'
        '--id', $Id
        '--exact'
        '--source', 'winget'
        '--silent'
        '--accept-package-agreements'
        '--accept-source-agreements'
        '--disable-interactivity'
    )

    # Katalogda ek argumanlar tanimliysa ekle (bos stringi atla)
    if ($ExtraArgs -ne '') {
        $extraArr = $ExtraArgs -split '\s+' | Where-Object { $_ -ne '' }
        $wingetArgs = $wingetArgs + $extraArr
    }

    Write-WFLog -Message "winget install basladi: $Id" -Level 'INFO' -Source 'AppInstall'

    try {
        $installOutput = & winget.exe @wingetArgs 2>&1
        $installExit = $LASTEXITCODE

        $outLines = $installOutput | ForEach-Object { "$_" } | Where-Object { $_ -ne '' }
        $outStr = $outLines -join ' '

        # Detayli loglama
        foreach ($line in $outLines) {
            Write-WFLog -Message "  [winget] $line" -Level 'INFO' -Source 'AppInstall'
        }

        # "Zaten kurulu" tespiti: hem exit code hem stdout kontrol
        # -1978335210 (0x8A14FFE6) = already installed
        $alreadyInstalled = (
            $installExit -eq -1978335210 -or
            $outStr -match '(?i)(already installed|Bereits installiert|deja installe|ya esta instalado)'
        )

        # Reboot gerekiyor: exit 3010
        $needsReboot = ($installExit -eq 3010)

        # Basari: exit 0 veya zaten kurulu veya reboot bekleniyor
        $success = ($installExit -eq 0 -or $needsReboot -or $alreadyInstalled)

        if (-not $success) {
            Write-WFLog -Message "winget install basarisiz: $Id (Kod: $installExit)" -Level 'ERROR' -Source 'AppInstall'
        }
        else {
            $logLevel = if ($alreadyInstalled) { 'INFO' } else { 'OK' }
            Write-WFLog -Message "winget install sonuc: $Id (Kod: $installExit, ZatenKurulu: $alreadyInstalled)" -Level $logLevel -Source 'AppInstall'
        }

        return [ordered]@{
            Success          = $success
            ExitCode         = $installExit
            AlreadyInstalled = $alreadyInstalled
            NeedsReboot      = $needsReboot
            ErrorDetail      = if (-not $success) { "Kod: $installExit | $outStr" } else { '' }
        }

    }
    catch {
        $exMsg = $_.Exception.Message
        Write-WFLog -Message "winget install istisnasi: $Id | $exMsg" -Level 'ERROR' -Source 'AppInstall'
        return [ordered]@{
            Success          = $false
            ExitCode         = -1
            AlreadyInstalled = $false
            NeedsReboot      = $false
            ErrorDetail      = "Istisna: $exMsg"
        }
    }
}

# ================================================================
# TOPLU KURULUM AKISI
# ================================================================
function Start-WFBatchInstall {
    <#
    .SYNOPSIS
        Secilmis uygulama listesini sirayla kurar.
        Her adimda ilerleme gosterir; sonunda ozet tablo yazdirir.

    .PARAMETER SelectedApps
        @{Id; Name; Optional; Notes} formatinda hashtable dizisi.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$SelectedApps
    )

    if ($SelectedApps.Count -eq 0) {
        Write-WFStatus -Message 'Kurulacak uygulama secilmedi.' -Type Warn
        return
    }

    $total = $SelectedApps.Count
    $succeeded = 0
    $skipped = 0
    $failed = 0
    $failedNames = [System.Collections.Generic.List[string]]::new()

    Write-Host ''
    Write-WFSeparator -SepChar '-'
    Write-Host "  $total uygulama islenecek..." -ForegroundColor Cyan
    Write-Host ''

    for ($appIdx = 0; $appIdx -lt $total; $appIdx++) {
        $app = $SelectedApps[$appIdx]
        $appId = $app.Id
        $appName = $app.Name
        $appExtra = if ($null -ne $app.PSObject.Properties['ExtraArgs']) { $app.ExtraArgs } else { '' }
        $counter = "[$($appIdx + 1)/$total]"

        # Kurulu mu kontrol et
        Write-Host "  $counter Kontrol ediliyor: $appName..." -ForegroundColor DarkGray -NoNewline

        $status = Test-WFAppInstalled -Id $appId -Name $appName
        $alreadyOn = ($status -eq 'Installed')

        if ($alreadyOn) {
            Write-Host ''
            Write-Host "  $counter [ATLANDI]  $appName - Zaten kurulu." -ForegroundColor DarkGray
            Write-WFLog -Message "Atlandi (zaten kurulu): $appId" -Level 'INFO' -Source 'AppInstall'
            $skipped++
            continue
        }

        Write-Host ''
        Write-Host "  $counter Kuruluyor : $appName..." -ForegroundColor Cyan

        $startTime = Get-Date
        $installRes = Install-WFSingleApp -Id $appId -Name $appName -ExtraArgs $appExtra
        $elapsed = [int](New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds

        if ($installRes.Success -and -not $installRes.AlreadyInstalled) {
            $rebootNote = if ($installRes.NeedsReboot) { ' (yeniden baslama gerekiyor)' } else { '' }
            Write-Host "  $counter [TAMAM]    $appName kuruldu. (${elapsed}s)$rebootNote" -ForegroundColor Green
            $succeeded++
            if ($installRes.NeedsReboot) {
                $Script:WF_RebootRecommended = $true
            }
        }
        elseif ($installRes.AlreadyInstalled) {
            Write-Host "  $counter [ATLANDI]  $appName - Zaten kurulu (winget onayladi)." -ForegroundColor DarkGray
            $skipped++
        }
        else {
            Write-Host "  $counter [HATA]     $appName kurulamadi. (Kod: $($installRes.ExitCode))" -ForegroundColor Red
            $failed++
            $failedNames.Add($appName)
        }
    }

    # Ozet
    Write-Host ''
    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '    Kurulum Ozeti' -ForegroundColor Cyan
    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host "    Basarili : $succeeded" -ForegroundColor Green
    Write-Host "    Atlandi  : $skipped"   -ForegroundColor DarkGray
    Write-Host "    Basarisiz: $failed"    -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'DarkGray' })
    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '    Detay icin log dosyasini inceleyin.' -ForegroundColor DarkGray

    if ($failedNames.Count -gt 0) {
        Write-Host ''
        Write-Host '  Kurulamayan uygulamalar:' -ForegroundColor Yellow
        foreach ($failName in $failedNames) {
            Write-Host "    - $failName" -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host '  Ipucu: Internet baglantinizi kontrol edin veya winget kaynak sagligini.' -ForegroundColor DarkGray
        Write-Host '         Sonra Yedekleme / Bakim > winget source reset deneyin.' -ForegroundColor DarkGray
    }
    Write-WFSeparator -SepChar '-'
}

# ================================================================
# KATEGORI UYGULAMA SECIM UI
# ================================================================
function Show-WFCategoryAppsSelection {
    <#
    .SYNOPSIS
        Tek bir kategori icin toggle tabanli uygulama secim menusu.
        Kullanici secimlerini onaylarsa Start-WFBatchInstall cagrisi yapar.

    .PARAMETER Category
        AppCatalog'daki tek kategori hashtable'i (@{Name; Apps}).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Category
    )

    $catName = $Category.Name
    $apps = @($Category.Apps)

    # Secim durumu dizisi (Optional=$false olanlar on secimli)
    $selected = @()
    foreach ($catApp in $apps) {
        $selected += (-not $catApp.Optional)
    }

    $exitMenu = $false
    while (-not $exitMenu) {
        Show-WFBanner
        Write-Host "  Kategori: $catName" -ForegroundColor Cyan
        Write-WFSeparator -SepChar '-'
        Write-Host '  Numara girerek sec/kaldir. Bos Enter = uygula.' -ForegroundColor DarkGray
        Write-Host ''

        for ($i = 0; $i -lt $apps.Count; $i++) {
            $app = $apps[$i]
            $mark = if ($selected[$i]) { 'X' } else { ' ' }
            $optLabel = if ($app.Optional) { ' [opsiyonel]' } else { '' }
            $padName = $app.Name.PadRight(26)
            $num = "[$($i + 1)]".PadLeft(4)
            Write-Host "  $num [$mark] $padName $($app.Notes)$optLabel"
        }

        Write-Host ''
        Write-Host '  [A] Tumunu sec    [N] Hicbirini secme    [G] Geri' -ForegroundColor DarkGray
        Write-Host ''

        $raw = Read-Host '  Secim (numara, A, N, veya G)'
        $choice = $raw.Trim().ToUpper()

        if ($choice -eq 'G' -or $choice -eq '0') {
            $exitMenu = $true
        }
        elseif ($choice -eq 'A') {
            $selected = @($true) * $apps.Count
        }
        elseif ($choice -eq 'N') {
            $selected = @($false) * $apps.Count
        }
        elseif ($choice -eq '') {
            # Bos Enter → secilenlerle kur
            $toInstall = @()
            for ($i = 0; $i -lt $apps.Count; $i++) {
                if ($selected[$i]) { $toInstall += $apps[$i] }
            }
            if ($toInstall.Count -eq 0) {
                Write-WFStatus -Message 'Hicbir uygulama secili degil.' -Type Warn
                Start-Sleep -Seconds 1
            }
            else {
                $selCount = $toInstall.Count
                Write-Host ''
                $confirmed = Read-WFConfirmation -Prompt "$selCount uygulama kurulsun mu?"
                if ($confirmed) {
                    Start-WFBatchInstall -SelectedApps $toInstall
                    Write-Host ''
                    Read-Host '  Ana menuye donmek icin Enter''a basin'
                    $exitMenu = $true
                }
            }
        }
        elseif ($choice -match '^\d+$') {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $apps.Count) {
                $selected[$idx] = -not $selected[$idx]
            }
            else {
                Write-WFStatus -Message 'Gecersiz numara.' -Type Warn
                Start-Sleep -Milliseconds 600
            }
        }
        else {
            Write-WFStatus -Message 'Gecersiz giris.' -Type Warn
            Start-Sleep -Milliseconds 600
        }
    }
}

# ================================================================
# TUM UYGULAMALAR SECIM UI (Tum kategoriler)
# ================================================================
function Show-WFAllAppsSelection {
    <#
    .SYNOPSIS
        Tum kategorilerdeki uygulamalari duz liste olarak gosterir.
        Non-optional uygulamalar on secimli. Toggle tabanlidir.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Categories
    )

    # Tum uygulamalari duz diziye al
    $allApps = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($cat in @($Categories)) {
        foreach ($catApp in @($cat.Apps)) {
            # Kategori bilgisini de ekle (gosterim icin)
            $entry = @{
                Id        = $catApp.Id
                Name      = $catApp.Name
                Optional  = $catApp.Optional
                Notes     = $catApp.Notes
                Category  = $cat.Name
                ExtraArgs = if ($null -ne $catApp.PSObject.Properties['ExtraArgs']) { $catApp.ExtraArgs } else { '' }
            }
            $allApps.Add($entry)
        }
    }

    # Secim durumu
    $appCount = $allApps.Count
    $selected = @()
    foreach ($flatApp in $allApps) {
        $selected += (-not $flatApp.Optional)
    }

    $exitMenu = $false

    while (-not $exitMenu) {
        Show-WFBanner
        Write-Host '  Tum Uygulamalar' -ForegroundColor Cyan
        Write-WFSeparator -SepChar '-'
        Write-Host '  Numara girerek sec/kaldir. Bos Enter = uygula.' -ForegroundColor DarkGray
        Write-Host ''

        # Kategori gruplamasi ile goster
        $lastCat = ''
        for ($i = 0; $i -lt $appCount; $i++) {
            $flatApp = $allApps[$i]
            $mark = if ($selected[$i]) { 'X' } else { ' ' }
            $optLabel = if ($flatApp.Optional) { ' [opsiyonel]' } else { '' }

            # Kategori basligi degistiyse goster
            if ($flatApp.Category -ne $lastCat) {
                if ($lastCat -ne '') { Write-Host '' }
                Write-Host "  -- $($flatApp.Category) --" -ForegroundColor DarkCyan
                $lastCat = $flatApp.Category
            }

            $padName = $flatApp.Name.PadRight(26)
            $num = "[$($i + 1)]".PadLeft(5)
            Write-Host "  $num [$mark] $padName $($flatApp.Notes)$optLabel"
        }

        Write-Host ''
        Write-Host '  [A] Tumunu sec    [N] Hicbirini secme    [G] Geri' -ForegroundColor DarkGray
        Write-Host ''

        $raw = Read-Host '  Secim (numara, A, N, veya G)'
        $choice = $raw.Trim().ToUpper()

        if ($choice -eq 'G' -or $choice -eq '0') {
            $exitMenu = $true
        }
        elseif ($choice -eq 'A') {
            $selected = @($true) * $appCount
        }
        elseif ($choice -eq 'N') {
            $selected = @($false) * $appCount
        }
        elseif ($choice -eq '') {
            $toInstall = @()
            for ($i = 0; $i -lt $appCount; $i++) {
                if ($selected[$i]) { $toInstall += $allApps[$i] }
            }
            if ($toInstall.Count -eq 0) {
                Write-WFStatus -Message 'Hicbir uygulama secili degil.' -Type Warn
                Start-Sleep -Seconds 1
            }
            else {
                $selCount = $toInstall.Count
                Write-Host ''
                $confirmed = Read-WFConfirmation -Prompt "$selCount uygulama kurulsun mu?"
                if ($confirmed) {
                    Start-WFBatchInstall -SelectedApps $toInstall
                    Write-Host ''
                    Read-Host '  Ana menuye donmek icin Enter''a basin'
                    $exitMenu = $true
                }
            }
        }
        elseif ($choice -match '^\d+$') {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $appCount) {
                $selected[$idx] = -not $selected[$idx]
            }
            else {
                Write-WFStatus -Message 'Gecersiz numara.' -Type Warn
                Start-Sleep -Milliseconds 600
            }
        }
        else {
            Write-WFStatus -Message 'Gecersiz giris.' -Type Warn
            Start-Sleep -Milliseconds 600
        }
    }
}

# ================================================================
# KURULU UYGULAMA DURUMU
# ================================================================
function Show-WFInstalledStatus {
    <#
    .SYNOPSIS
        Katalogdaki tum uygulamalarin kurulum durumunu gosterir.
        Her uygulama icin winget list sorgusu yapar (yavas olabilir).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Categories
    )

    Show-WFBanner
    Write-Host '  Uygulama Kurulum Durumu' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'
    Write-Host '  (Bu islem birka saniye surebilir...)' -ForegroundColor DarkGray
    Write-Host ''

    foreach ($cat in @($Categories)) {
        Write-Host "  [$($cat.Name)]" -ForegroundColor DarkCyan

        foreach ($catApp in @($cat.Apps)) {
            Write-Host "    Kontrol: $($catApp.Name)..." -ForegroundColor DarkGray -NoNewline
            $status = Test-WFAppInstalled -Id $catApp.Id -Name $catApp.Name
            
            if ($status -eq 'Installed') {
                Write-Host "  [KURULU]" -ForegroundColor Green
            }
            elseif ($status -eq 'Unknown') {
                Write-Host "  [BELIRSIZ]" -ForegroundColor Yellow
            }
            else {
                Write-Host "  [KURULU DEGIL]" -ForegroundColor Yellow
            }
        }
        Write-Host ''
    }

    Read-Host '  Geri donmek icin Enter''a basin'
}

# ================================================================
# ANA MENU (Export edilir)
# ================================================================
function Show-AppInstallMenu {
    <#
    .SYNOPSIS
        Uygulama kurulum ana menusu.
        WinForge.ps1 tarafindan dogrudan cagirilir.
    #>

    # Katalog yukle
    $catalog = Get-WFAppCatalog
    if ($null -eq $catalog) {
        Show-WFBanner
        Write-WFStatus -Message 'AppCatalog.psd1 yuklenemedi. data\ klasorunu kontrol edin.' -Type Error
        Write-WFLog -Message 'AppCatalog.psd1 yuklenemedi; AppInstallMenu cikiyor.' -Level 'ERROR' -Source 'AppInstall'
        Read-Host '  Geri donmek icin Enter''a basin'
        return
    }

    $categories = @($catalog.Categories)

    $running = $true
    while ($running) {
        Show-WFBanner
        Write-Host '  Uygulama Kurulumu' -ForegroundColor Cyan
        Write-WFSeparator -SepChar '-'
        Write-Host ''

        # Kategori ozeti
        for ($catIdx = 0; $catIdx -lt $categories.Count; $catIdx++) {
            $cat = $categories[$catIdx]
            $appCnt = @($cat.Apps).Count
            $defCnt = @($cat.Apps | Where-Object { -not $_.Optional }).Count
            $numLabel = "[$($catIdx + 1)]".PadLeft(4)
            $padName = $cat.Name.PadRight(30)
            Write-Host "  $numLabel  $padName ($appCnt uygulama, $defCnt varsayilan secili)"
        }

        Write-Host ''
        Write-Host '  [A]   Tum uygulamalar (kategoriler arasi)'  -ForegroundColor White
        Write-Host '  [D]   Kurulum durumunu goster'              -ForegroundColor White
        Write-Host ''
        Write-Host '  [0]   Ana Menu'                             -ForegroundColor DarkGray
        Write-Host ''

        $raw = Read-Host '  Seciminiz'
        $choice = $raw.Trim().ToUpper()

        if ($choice -eq '0' -or $choice -eq 'Q') {
            $running = $false
        }
        elseif ($choice -eq 'A') {
            Show-WFAllAppsSelection -Categories $categories
        }
        elseif ($choice -eq 'D') {
            Show-WFInstalledStatus -Categories $categories
        }
        elseif ($choice -match '^\d+$') {
            $catIdx = [int]$choice - 1
            if ($catIdx -ge 0 -and $catIdx -lt $categories.Count) {
                Show-WFCategoryAppsSelection -Category $categories[$catIdx]
            }
            else {
                Write-WFStatus -Message 'Gecersiz kategori numarasi.' -Type Warn
                Start-Sleep -Milliseconds 600
            }
        }
        else {
            Write-WFStatus -Message 'Gecersiz secim.' -Type Warn
            Start-Sleep -Milliseconds 600
        }
    }
}
