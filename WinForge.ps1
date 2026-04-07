#Requires -Version 5.1
<#
.SYNOPSIS
    WinForge v1.0 - Windows Kurulum ve Bakim Araci

.DESCRIPTION
    Moduler, veri odakli Windows kurulum ve yapilandirma araci.
    Uygulama kurulumu, sistem tweakleri, bakim islemleri ve
    yedekleme/geri yukleme ozellikleri sunar.

    Gereksinimler: Windows 10/11, PowerShell 5.1, Admin hakki
    Baslangic: Launch-WinForge.bat (dogrudan calistirmayin)
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

# ASCII-safe konsol ciktisi
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ================================================================
# YOLLAR
# ================================================================
$Script:WF_Root = $PSScriptRoot
$Script:WF_DataDir = Join-Path $Script:WF_Root 'data'
$Script:WF_ModuleDir = Join-Path $Script:WF_Root 'modules'
$Script:WF_LogDir = Join-Path $Script:WF_Root 'logs'
$Script:WF_BackupDir = Join-Path $Script:WF_Root 'backups'
$Script:WF_BackupRegistry = Join-Path $Script:WF_BackupDir 'registry'
$Script:WF_BackupTweaks = Join-Path $Script:WF_BackupDir 'tweaks'
$Script:WF_BackupFull = Join-Path $Script:WF_BackupDir 'full'

# ================================================================
# OTURUM DURUM ISARET DEGISKENLERI
# (Moduller tarafindan $Script: scope uzerinden okunup yazilir)
# ================================================================
$Script:WF_ExplorerRestartNeeded = $false
$Script:WF_RebootRecommended = $false
$Script:WF_LogFile = $null
$Script:WF_Preflight = $null

# ================================================================
# CALISMA DIZINLERINI OLUSTUR
# ================================================================
$Script:WF_RuntimeDirs = @(
    $Script:WF_LogDir
    $Script:WF_BackupRegistry
    $Script:WF_BackupTweaks
    $Script:WF_BackupFull
)

foreach ($runtimeDir in $Script:WF_RuntimeDirs) {
    if (-not (Test-Path -LiteralPath $runtimeDir)) {
        try {
            New-Item -ItemType Directory -Path $runtimeDir -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Host "  [HATA] Dizin olusturulamadi: $runtimeDir" -ForegroundColor Red
        }
    }
}

# ================================================================
# LOG OTURUMU BASLAT
# ================================================================
$sessionStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Script:WF_SessionStart = Get-Date
$Script:WF_LogFile = Join-Path $Script:WF_LogDir "WinForge_$sessionStamp.log"

# ================================================================
# PAYLASILAN YARDIMCI FONKSIYONLAR
# Moduller dot-source ile bu scope'ta calistiginden
# burada tanimlanan fonksiyonlar tum modullerde kullanilabilir.
# ================================================================

function Write-WFLog {
    <#
    .SYNOPSIS Oturum log dosyasina timestamped satir yazar.#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'FATAL')]
        [string]$Level = 'INFO',

        [string]$Source = 'Main'
    )

    if ($null -eq $Script:WF_LogFile) { return }

    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $levelPad = $Level.PadRight(5)
    $line = "[$ts] [$levelPad] [$Source] $Message"

    try {
        Add-Content -Path $Script:WF_LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Log hatasi hicbir zaman kaskad hata uretmez
    }
}

function Write-WFStatus {
    <#
    .SYNOPSIS Kullaniciya renkli durum mesaji gosterir.#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Info', 'OK', 'Warn', 'Error', 'Fatal')]
        [string]$Type = 'Info'
    )

    switch ($Type) {
        'OK' { Write-Host "  [TAMAM]  $Message" -ForegroundColor Green }
        'Warn' { Write-Host "  [UYARI]  $Message" -ForegroundColor Yellow }
        'Error' { Write-Host "  [HATA]   $Message" -ForegroundColor Red }
        'Fatal' { Write-Host "  [KRITIK] $Message" -ForegroundColor Red }
        default { Write-Host "  [>>]     $Message" -ForegroundColor Cyan }
    }
}

function Write-WFSeparator {
    <#
    .SYNOPSIS ASCII ayirici cizgi yazdirir.#>
    [CmdletBinding()]
    param(
        [char]$SepChar = '=',
        [int]$Width = 62
    )
    Write-Host ($SepChar.ToString() * $Width)
}

function Show-WFBanner {
    <#
    .SYNOPSIS Uygulama basligini gosterir.#>
    Clear-Host
    Write-Host '  __      ___       ____                 ' -ForegroundColor Cyan
    Write-Host '  \ \    / (_)_ _  |  __|__ _ _ __ _ ___ ' -ForegroundColor Cyan
    Write-Host '   \ \/\/ /| | '' \ |  _// _ \ ''_/ _` / -_)' -ForegroundColor Cyan
    Write-Host '    \_/\_/ |_|_||_||_|  \___/_| \__, \___|' -ForegroundColor Cyan
    Write-Host '                                |___/    ' -ForegroundColor Cyan
    Write-Host ''
    Write-WFSeparator
    Write-Host '  WinForge v1.0  -  Windows Kurulum ve Bakim Araci' -ForegroundColor Cyan
    Write-Host '  Hedef: Windows 10/11  |  Motor: PowerShell 5.1'   -ForegroundColor DarkCyan
    Write-WFSeparator
    Write-Host ''
}


function Read-WFMenuChoice {
    <#
    .SYNOPSIS Meni secimi okur; gecersiz giri tekrar ister.#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ValidChoices,

        [string]$Prompt = 'Seciminiz'
    )

    $selectedChoice = $null
    do {
        Write-Host ''
        $raw = Read-Host "  $Prompt"
        $selectedChoice = $raw.Trim()

        if ($selectedChoice -notin $ValidChoices) {
            Write-WFStatus -Message 'Gecersiz secim. Lutfen tekrar girin.' -Type Warn
        }
    } while ($selectedChoice -notin $ValidChoices)

    return $selectedChoice
}

function Read-WFConfirmation {
    <#
    .SYNOPSIS E/H onay sorusu sorar; $true/$false doner.#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    $raw = Read-Host "  $Prompt [E/H]"
    $raw = $raw.Trim()
    return ($raw -eq 'E' -or $raw -eq 'e')
}

function Read-WFDoubleConfirmation {
    <#
    .SYNOPSIS Cok riskli islemler icin iki kademeli onay sorusu.
               Ikisi de 'E' olmadikca $false doner.#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActionDescription
    )

    Write-Host ''
    Write-Host '  !! DIKKAT: Riskli Islem !!' -ForegroundColor Red
    Write-Host "  $ActionDescription" -ForegroundColor Yellow
    Write-Host ''

    $first = Read-WFConfirmation -Prompt 'Devam etmek istediginizden emin misiniz?'
    if (-not $first) { return $false }

    Write-Host ''
    Write-Host '  Son onay:' -ForegroundColor Red
    $second = Read-WFConfirmation -Prompt 'Bu islemi geri alamayabilirsiniz. Kesinlikle devam?'
    return $second
}

function Format-WFTable {
    <#
    .SYNOPSIS Hashtable dizisini ASCII tablosu olarak gosterir.
    .PARAMETER Rows  @(@{Col1='val'; Col2='val'}) formatinda dizi.
    .PARAMETER Headers Gosterilecek sutun adlari (dizi).
    .PARAMETER Widths Sutun genislikleri (int dizisi, Headers ile ayni uzunlukta).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Rows,

        [Parameter(Mandatory = $true)]
        [string[]]$Headers,

        [Parameter(Mandatory = $true)]
        [int[]]$Widths
    )

    # Baslik satiri
    $headerLine = '  '
    for ($colIdx = 0; $colIdx -lt $Headers.Count; $colIdx++) {
        $headerLine += $Headers[$colIdx].PadRight($Widths[$colIdx]) + '  '
    }
    Write-Host $headerLine -ForegroundColor DarkCyan

    # Ayirici
    $sepLine = '  ' + ('-' * ($Widths | Measure-Object -Sum).Sum + $Widths.Count * 2)
    Write-Host $sepLine -ForegroundColor DarkGray

    # Veri satirlari
    foreach ($row in $Rows) {
        $dataLine = '  '
        for ($colIdx = 0; $colIdx -lt $Headers.Count; $colIdx++) {
            $cellVal = [string]$row[$Headers[$colIdx]]
            $cellVal = if ($cellVal.Length -gt $Widths[$colIdx]) {
                $cellVal.Substring(0, $Widths[$colIdx] - 1) + '>'
            }
            else {
                $cellVal.PadRight($Widths[$colIdx])
            }
            $dataLine += $cellVal + '  '
        }
        Write-Host $dataLine
    }
}

# ================================================================
# LOG: OTURUM ACILISI
# ================================================================
$Script:WF_CurrentAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

Write-WFLog -Message '================================================' -Level 'INFO'
Write-WFLog -Message 'WinForge v1.0 oturumu basliyor.' -Level 'INFO'
Write-WFLog -Message "OS        : $([System.Environment]::OSVersion.VersionString)" -Level 'INFO'
Write-WFLog -Message "Build     : $([System.Environment]::OSVersion.Version.Build)" -Level 'INFO'
Write-WFLog -Message "PS        : $($PSVersionTable.PSVersion)" -Level 'INFO'
Write-WFLog -Message "Admin     : $($Script:WF_CurrentAdmin)" -Level 'INFO'
Write-WFLog -Message "Kullanici : $env:USERNAME" -Level 'INFO'
Write-WFLog -Message "Makine    : $env:COMPUTERNAME" -Level 'INFO'
Write-WFLog -Message "Log       : $Script:WF_LogFile" -Level 'INFO'
Write-WFLog -Message '================================================' -Level 'INFO'

# ================================================================
# MODULLERI YUKLE (dot-source)
# Siralama onemli: preflight en once yuklenmeli
# ================================================================
$Script:WF_ModuleOrder = @(
    'Invoke-PreflightCheck.ps1'
    'Install-Applications.ps1'
    'Set-WindowsTweaks.ps1'
    'Invoke-Maintenance.ps1'
    'Invoke-BackupRestore.ps1'
)

$Script:WF_LoadErrors = @()

foreach ($modFile in $Script:WF_ModuleOrder) {
    $modPath = Join-Path $Script:WF_ModuleDir $modFile
    if (Test-Path -LiteralPath $modPath) {
        try {
            . ([scriptblock]::Create([System.IO.File]::ReadAllText($modPath, [System.Text.Encoding]::UTF8)))
            Write-WFLog -Message "Modul yuklendi: $modFile" -Level 'INFO' -Source 'Loader'
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-WFLog -Message "Modul yuklenemedi: $modFile | $errMsg" -Level 'ERROR' -Source 'Loader'
            $Script:WF_LoadErrors += $modFile
        }
    }
    else {
        Write-WFLog -Message "Modul bulunamadi: $modPath" -Level 'ERROR' -Source 'Loader'
        $Script:WF_LoadErrors += $modFile
    }
}

# ================================================================
# MODUL YUKLEME HATASI VARSA KULLANICIYA BILDIR
# Arac yine de calisir; sadece etkilenen modul kullanilmaz.
# ================================================================
if ($Script:WF_LoadErrors.Count -gt 0) {
    Show-WFBanner
    Write-Host '  Bazi moduller yuklenemedi:' -ForegroundColor Red
    foreach ($failedMod in $Script:WF_LoadErrors) {
        Write-WFStatus -Message $failedMod -Type Error
    }
    Write-Host ''
    Write-Host '  modules\ klasorunu kontrol edin.' -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Devam etmek icin Enter''a basin'
}

# ================================================================
# PREFLIGHT
# ================================================================
Show-WFBanner
Write-Host '  Sistem kontrolleri yapiliyor...' -ForegroundColor DarkCyan
Write-Host ''

# Invoke-PreflightCheck modulu tarafindan tanimlanmis olmasi lazim
if (Get-Command -Name 'Invoke-PreflightCheck' -ErrorAction SilentlyContinue) {
    $Script:WF_Preflight = Invoke-PreflightCheck

    # Preflight bulgularini logla
    Write-WFLog -Message "Preflight - Admin     : $($Script:WF_Preflight.IsAdmin)"      -Level 'INFO' -Source 'Preflight'
    Write-WFLog -Message "Preflight - Internet  : $($Script:WF_Preflight.HasInternet)"   -Level 'INFO' -Source 'Preflight'
    Write-WFLog -Message "Preflight - winget    : $($Script:WF_Preflight.HasWinget)"     -Level 'INFO' -Source 'Preflight'
    Write-WFLog -Message "Preflight - WingetVer : $($Script:WF_Preflight.WingetVersion)" -Level 'INFO' -Source 'Preflight'
    Write-WFLog -Message "Preflight - Kaynak    : $($Script:WF_Preflight.SourceHealthy)" -Level 'INFO' -Source 'Preflight'

    foreach ($issue in $Script:WF_Preflight.Issues) {
        Write-WFStatus -Message $issue -Type Warn
        Write-WFLog -Message "Preflight sorunu: $issue" -Level 'WARN' -Source 'Preflight'
    }

    if ($Script:WF_Preflight.Issues.Count -gt 0) {
        Write-Host ''
        Read-Host '  Devam etmek icin Enter''a basin'
    }
}
else {
    # Preflight modulu yuklenemedi; minimal geri donus degeri olustur
    Write-WFLog -Message 'Invoke-PreflightCheck tanimli degil. Varsayilan preflight objesi kullaniliyor.' -Level 'WARN' -Source 'Main'
    $Script:WF_Preflight = [ordered]@{
        IsAdmin       = $Script:WF_CurrentAdmin
        HasInternet   = $false
        HasWinget     = $false
        WingetVersion = 'bilinmiyor'
        SourceHealthy = $false
        Issues        = @('Preflight modulu yuklenemedi.')
    }
}

# ================================================================
# ANA MENU GOSTERIMI
# ================================================================
function Show-WFMainMenu {
    Show-WFBanner

    # Durum ozeti
    $adminText = if ($Script:WF_Preflight.IsAdmin) { '[OK] Admin' } else { '[!!] Admin Degil' }
    $netText = if ($Script:WF_Preflight.HasInternet) { '[OK] Internet' } else { '[--] Cevrimdisi' }
    $wingetText = if ($Script:WF_Preflight.HasWinget) {
        "[OK] winget $($Script:WF_Preflight.WingetVersion)"
    }
    else {
        '[!!] winget Yok'
    }

    $adminStr = $adminText.PadRight(20)
    $netStr   = $netText.PadRight(20)
    Write-Host "  $adminStr $netStr $wingetText" -ForegroundColor DarkGray

    if (-not $Script:WF_Preflight.SourceHealthy) {
        Write-Host '  [!!] winget kaynak sagligi sorunu var - Bakimda giderebilirsiniz' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-WFSeparator -SepChar '-'
    Write-Host ''
    Write-Host '  [1]  Uygulama Kurulumu'    -ForegroundColor White
    Write-Host '  [2]  Windows Tweakleri'    -ForegroundColor White
    Write-Host '  [3]  Bakim / Guncelleme'   -ForegroundColor White
    Write-Host '  [4]  Yedekleme / Geri Al'  -ForegroundColor White
    Write-Host ''
    Write-Host '  [0]  Cikis'                -ForegroundColor DarkGray
    Write-Host ''
}

# ================================================================
# CIKIS ISLEMLERI
# ================================================================
function Invoke-WFExit {
    Write-Host ''
    Write-WFSeparator -SepChar '='
    Write-Host '  Oturum Ozeti' -ForegroundColor Cyan
    Write-WFSeparator -SepChar '-'
    Write-Host ''

    # Explorer restart durumu
    if ($Script:WF_ExplorerRestartNeeded) {
        Write-Host '  [BEKLIYOR]  Explorer yeniden baslatmasi gerekiyor.' -ForegroundColor Yellow
    }
    else {
        Write-Host '  [TAMAM]     Explorer yeniden baslatmasi gerekmiyor.' -ForegroundColor DarkGray
    }

    # Sistem reboot durumu
    if ($Script:WF_RebootRecommended) {
        Write-Host '  [BEKLIYOR]  Sistem yeniden baslama onerilir.'        -ForegroundColor Yellow
    }
    else {
        Write-Host '  [TAMAM]     Sistem yeniden baslama gerekmiyor.'      -ForegroundColor DarkGray
    }

    # Log dosyasi ve Sure
    if ($null -ne $Script:WF_LogFile) {
        $logLeaf = Split-Path -Leaf $Script:WF_LogFile
        Write-Host "  [LOG]       logs\$logLeaf" -ForegroundColor DarkGray
    }
    
    $span = (Get-Date) - $Script:WF_SessionStart
    Write-Host "  [SURE]      Oturum suresi: $([math]::Round($span.TotalSeconds)) saniye." -ForegroundColor DarkGray

    Write-Host ''
    Write-WFSeparator -SepChar '-'

    # Explorer restart eylemi
    if ($Script:WF_ExplorerRestartNeeded) {
        Write-Host ''
        $doRestart = Read-WFConfirmation -Prompt "Explorer'i simdi yeniden baslat?"
        if ($doRestart) {
            Write-WFStatus -Message 'Explorer yeniden baslatiliyor...' -Type Info
            Write-WFLog -Message 'Kullanici Explorer restart istedi.' -Level 'INFO' -Source 'Main'
            try {
                Stop-Process -Name 'explorer' -Force -ErrorAction Stop
                Start-Sleep -Seconds 2
                Start-Process 'explorer.exe'
                Write-WFStatus -Message 'Explorer yeniden baslatildi.' -Type OK
                Write-WFLog -Message 'explorer.exe basariyla yeniden baslatildi.' -Level 'OK' -Source 'Main'
            }
            catch {
                Write-WFStatus -Message "Explorer restart basarisiz: $($_.Exception.Message)" -Type Warn
                Write-WFLog -Message "Explorer restart basarisiz: $($_.Exception.Message)" -Level 'WARN' -Source 'Main'
            }
        }
        else {
            Write-WFLog -Message 'Explorer restart kullanici tarafindan ertelendi.' -Level 'INFO' -Source 'Main'
        }
    }

    # Reboot onerisi
    if ($Script:WF_RebootRecommended) {
        Write-Host ''
        Write-Host '  !! Bilgisayarinizi en kisa surede yeniden baslatmaniz onerilir.' -ForegroundColor Yellow
        Write-WFLog -Message 'Oturum yeniden baslatma onerisiyle kapandi.' -Level 'WARN' -Source 'Main'
    }

    Write-Host ''
    Write-WFLog -Message 'WinForge oturumu tamamlandi.' -Level 'INFO' -Source 'Main'
    Write-Host '  WinForge sonlandi.' -ForegroundColor DarkCyan
    Write-Host ''
}

# ================================================================
# ANA DONGU
# ================================================================
function Invoke-WFMainLoop {
    $running = $true

    while ($running) {
        Show-WFMainMenu
        $choice = Read-WFMenuChoice -ValidChoices @('0', '1', '2', '3', '4') -Prompt 'Seciminiz'

        switch ($choice) {
            '1' {
                # Uygulama Kurulumu - winget zorunlu
                if (-not $Script:WF_Preflight.HasWinget) {
                    Show-WFBanner
                    Write-Host ''
                    Write-WFStatus -Message 'winget bulunamadi. Uygulama kurulumu kullanilamiyor.' -Type Warn
                    Write-Host ''
                    Write-Host '  Nasil duzeltilir:' -ForegroundColor Yellow
                    Write-Host '  1. Microsoft Store uygulamasini acin.' -ForegroundColor White
                    Write-Host '  2. "App Installer" aratip uygulamayi guncelleyin.' -ForegroundColor White
                    Write-Host '  3. WinForge''u yeniden baslatin.' -ForegroundColor White
                    Write-Host ''
                    Read-Host '  Ana menuye donmek icin Enter''a basin'
                }
                elseif (Get-Command -Name 'Show-AppInstallMenu' -ErrorAction SilentlyContinue) {
                    Show-AppInstallMenu
                }
                else {
                    Write-WFStatus -Message 'Uygulama kurulum modulu yuklenemedi.' -Type Error
                    Write-WFLog -Message 'Show-AppInstallMenu cagrilamadi: modul tanimli degil.' -Level 'ERROR' -Source 'Main'
                    Read-Host '  Devam etmek icin Enter''a basin'
                }
            }

            '2' {
                # Windows Tweakleri
                if (Get-Command -Name 'Show-TweakMenu' -ErrorAction SilentlyContinue) {
                    Show-TweakMenu
                }
                else {
                    Write-WFStatus -Message 'Tweak modulu yuklenemedi.' -Type Error
                    Write-WFLog -Message 'Show-TweakMenu cagrilamadi: modul tanimli degil.' -Level 'ERROR' -Source 'Main'
                    Read-Host '  Devam etmek icin Enter''a basin'
                }
            }

            '3' {
                # Bakim / Guncelleme
                if (Get-Command -Name 'Show-MaintenanceMenu' -ErrorAction SilentlyContinue) {
                    Show-MaintenanceMenu
                }
                else {
                    Write-WFStatus -Message 'Bakim modulu yuklenemedi.' -Type Error
                    Write-WFLog -Message 'Show-MaintenanceMenu cagrilamadi: modul tanimli degil.' -Level 'ERROR' -Source 'Main'
                    Read-Host '  Devam etmek icin Enter''a basin'
                }
            }

            '4' {
                # Yedekleme / Geri Al
                if (Get-Command -Name 'Show-BackupRestoreMenu' -ErrorAction SilentlyContinue) {
                    Show-BackupRestoreMenu
                }
                else {
                    Write-WFStatus -Message 'Yedekleme modulu yuklenemedi.' -Type Error
                    Write-WFLog -Message 'Show-BackupRestoreMenu cagrilamadi: modul tanimli degil.' -Level 'ERROR' -Source 'Main'
                    Read-Host '  Devam etmek icin Enter''a basin'
                }
            }

            '0' { $running = $false }
        }
    }
}

# ================================================================
# BASLATMA
# try/catch: beklenmedik hata durumunda log + kullanici bildirimi
# finally  : her zaman Invoke-WFExit calisir
# ================================================================
try {
    Invoke-WFMainLoop
}
catch {
    $crashMsg = $_.Exception.Message
    $crashStack = $_.ScriptStackTrace

    Write-WFLog -Message "BEKLENMEDIK HATA: $crashMsg"   -Level 'FATAL' -Source 'Main'
    Write-WFLog -Message "Stack trace: $crashStack"       -Level 'FATAL' -Source 'Main'

    Write-Host ''
    Write-Host '  ================================================================' -ForegroundColor Red
    Write-Host '  WinForge beklenmedik bir hatayla karsilasti.' -ForegroundColor Red
    Write-Host "  Hata: $crashMsg" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Lutfen asagidaki log dosyasini inceleyin:' -ForegroundColor DarkGray
    Write-Host "  $Script:WF_LogFile" -ForegroundColor DarkCyan
    Write-Host '  ================================================================' -ForegroundColor Red
    Write-Host ''
    Read-Host '  Kapatmak icin Enter''a basin'
}
finally {
    Invoke-WFExit
}
