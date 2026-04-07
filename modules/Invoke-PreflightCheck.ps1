#
# WinForge v1.1 - modules/Invoke-PreflightCheck.ps1
# Dot-sourced by WinForge.ps1
#
# Exports : Invoke-PreflightCheck
# Returns : Ordered hashtable with IsAdmin, OsBuild, OsEdition,
#           HasInternet, HasWinget, WingetVersion, SourceHealthy,
#           Issues, Remediation
#
# Not: Bu modul WinForge.ps1 tarafindan dot-source edilir.
# Write-WFLog ve Write-WFStatus o dosyada tanimlidir.
#

Set-StrictMode -Version 2.0

# ----------------------------------------------------------------
# YARDIMCI: OS build ve edition bilgisi
# ----------------------------------------------------------------
function Get-WFOsInfo {
    <#
    .SYNOPSIS
        Mevcut Windows build numarasini ve surum kimligini doner.
        OsEdition degeri TweakCatalog SupportedEditions ile uyumlu olmali:
        'Pro', 'Home', 'Enterprise', 'Education'
    #>
    $buildNum = 0
    $edition  = 'Unknown'

    try {
        $regPath  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $regData  = Get-ItemProperty -LiteralPath $regPath -ErrorAction Stop

        # Build numarasi: CurrentBuildNumber + UBR (Update Build Revision)
        $buildNum   = [int]$regData.CurrentBuildNumber
        $editionRaw = [string]$regData.EditionID

        $edition = switch -Wildcard ($editionRaw) {
            'Professional*' { 'Pro'          }
            'Enterprise*'   { 'Enterprise'   }
            'Education*'    { 'Education'    }
            'Home*'         { 'Home'         }
            default         { $editionRaw    }
        }
    } catch {
        Write-WFLog -Message "Get-WFOsInfo hatasi: $($_.Exception.Message)" -Level 'WARN' -Source 'Preflight'
    }

    return [ordered]@{
        Build   = $buildNum
        Edition = $edition
    }
}

# ----------------------------------------------------------------
# YARDIMCI: Admin yetkisi kontrolu
# ----------------------------------------------------------------
function Test-WFAdminElevation {
    <#
    .SYNOPSIS $true donerse mevcut process admin olarak calisiyordur.#>
    try {
        $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        Write-WFLog -Message "Test-WFAdminElevation hatasi: $($_.Exception.Message)" -Level 'WARN' -Source 'Preflight'
        return $false
    }
}

# ----------------------------------------------------------------
# YARDIMCI: Internet erisimi
# Not: Aracin tamami internet gerektirmez; bu bilgi guncel durum.
# ----------------------------------------------------------------
function Test-WFInternetAccess {
    <#
    .SYNOPSIS
        DNS cozumlemesiyle internet erisimini test eder.
        ICMP kullanmaz (guvenlik duvarlari tarafindan engellenebilir).
    #>
    try {
        $null = [System.Net.Dns]::GetHostEntry('dns.google')
        return $true
    } catch {
        # Ikinci deneme: alternatif host
        try {
            $null = [System.Net.Dns]::GetHostEntry('one.one.one.one')
            return $true
        } catch {
            return $false
        }
    }
}

# ----------------------------------------------------------------
# YARDIMCI: Zaman asimli dis process cagirici
# ----------------------------------------------------------------
function Invoke-WFProcessWithTimeout {
    param(
        [string]$FilePath,
        [string]$ArgumentList,
        [int]$TimeoutMs = 5000
    )

    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName = $FilePath
    $procInfo.Arguments = $ArgumentList
    $procInfo.RedirectStandardOutput = $true
    $procInfo.RedirectStandardError = $true
    $procInfo.UseShellExecute = $false
    $procInfo.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo

    try {
        [void]$proc.Start()
        $exited = $proc.WaitForExit($TimeoutMs)
        if (-not $exited) {
            try { $proc.Kill() } catch {}
            return @{ ExitCode = -1; Output = ""; TimedOut = $true }
        }

        $out = $proc.StandardOutput.ReadToEnd()
        $err = $proc.StandardError.ReadToEnd()
        $fullOut = $out + "`n" + $err

        return @{ ExitCode = $proc.ExitCode; Output = $fullOut; TimedOut = $false }
    } catch {
        return @{ ExitCode = -1; Output = $_.Exception.Message; TimedOut = $false }
    } finally {
        if ($null -ne $proc) {
            $proc.Dispose()
        }
    }
}

# ----------------------------------------------------------------
# YARDIMCI: winget varlik ve surum
# ----------------------------------------------------------------
function Test-WFWingetPresence {
    <#
    .SYNOPSIS
        winget.exe'nin PATH'te olup olmadigini kontrol eder.
        Bulursa surumunu de doner.
    #>
    $cmd = Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        return [ordered]@{ Found = $false; Version = 'N/A' }
    }

    $versionStr = 'unknown'
    try {
        $runResult = Invoke-WFProcessWithTimeout -FilePath "winget.exe" -ArgumentList "--version" -TimeoutMs 3000
        if ($runResult.TimedOut) {
            Write-WFLog -Message "winget --version timeout (3s). Process execution was stopped." -Level 'WARN' -Source 'Preflight'
        }
        elseif ($runResult.ExitCode -eq 0) {
            $parsedOutput = ($runResult.Output -split "\r?\n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
            if ($null -ne $parsedOutput) {
                $versionStr = $parsedOutput.Trim()
            }
        }
    } catch {
        Write-WFLog -Message "winget --version cagrilamadi: $($_.Exception.Message)" -Level 'WARN' -Source 'Preflight'
    }

    return [ordered]@{ Found = $true; Version = $versionStr }
}

# ----------------------------------------------------------------
# YARDIMCI: winget kaynak sagligi
# ----------------------------------------------------------------
function Test-WFWingetSourceHealth {
    <#
    .SYNOPSIS
        winget source list ciktisini inceleyerek kaynak sagligini kontrol eder.
        Hizli olmasi icin yalnizca 'source list' kullanir; search yapmaz.
    #>
    $result = [ordered]@{
        Healthy     = $true
        Degraded    = $false
        Issues      = @()
        Remediation = @()
    }

    try {
        $runResult = Invoke-WFProcessWithTimeout -FilePath "winget.exe" -ArgumentList "source list" -TimeoutMs 5000
        
        if ($runResult.TimedOut) {
            Write-WFLog -Message "winget source list timeout (5s). Source health marked as degraded after timeout." -Level 'WARN' -Source 'Preflight'
            $result.Healthy = $true
            $result.Degraded = $true
            $result.Issues += "winget 'source list' surecinde zaman asimi oldu."
            $result.Remediation += "Gerekirse terminalde 'winget list' komutunu calistirip istenen sozlesme onayini verin."
            return $result
        }

        $srcExit = $runResult.ExitCode
        $outStr  = $runResult.Output

        if ($srcExit -ne 0) {
            if ($srcExit -eq -1978335230 -or $outStr -match 'agreement|yanit vermiyor|terms of transaction') {
                $result.Healthy  = $true
                $result.Degraded = $true
                $result.Issues  += "winget 'source list' basarisiz (kod: $srcExit). Anlasma onayi gerekebilir."
                $result.Remediation += "Gerekirse terminalde 'winget list' komutunu calistirip istenen sozlesme onayini verin."
                return $result
            }

            $result.Healthy = $false
            $result.Issues += "winget kaynak listesi alinamadi (kod: $srcExit)."
            $result.Remediation += 'PowerShell (Admin) icinde calistirin: winget source reset --force'
            $result.Remediation += 'Cozum yoksa: Microsoft Store > App Installer guncelleyin.'
            return $result
        }

        # Cikis kodu 0. 'winget' ana kaynak satiri var mi?
        if ($outStr -match '(?m)^\s*winget\s') {
            $result.Healthy = $true
            $result.Degraded = $false
            return $result
        }

        # Kodu 0 olmasina ragmen liste bos ise veya beklendik format degilse
        if ($outStr -match 'agreement|yanit vermiyor|terms of transaction') {
            $result.Healthy  = $true
            $result.Degraded = $true
            $result.Issues  += "winget kaynak onayi gerekebilir."
            $result.Remediation += "Gerekirse terminalde 'winget list' komutunu calistirip istenen sozlesme onayini verin."
            return $result
        }

        $result.Healthy = $false
        $result.Issues += "winget ana kaynak bulunamadi veya yanit vermedi."
        $result.Remediation += 'PowerShell (Admin) icinde calistirin: winget source reset --force'
        $result.Remediation += 'Cozum yoksa: winget source add --name winget --type Microsoft.PreIndexed.Package https://cdn.winget.microsoft.com/cache'
        
    } catch {
        $result.Healthy = $false
        $result.Issues += "winget source list calistirilamadi: $($_.Exception.Message)"
        $result.Remediation += 'App Installer kurulumunu kontrol edin veya Microsoft Store uzerinden guncelleyin.'
    }

    return $result
}

# ----------------------------------------------------------------
# ANA FONKSIYON: Invoke-PreflightCheck
# ----------------------------------------------------------------
function Invoke-PreflightCheck {
    <#
    .SYNOPSIS
        Sistem hazirlik kontrollerini yapar ve yapilandirilmis bir
        sonuc nesnesi doner.

    .OUTPUTS
        [ordered] hashtable:
          IsAdmin       - [bool]   Admin olarak mi caisliyoruz?
          OsBuild       - [int]    Windows build numarasi (ornek: 22631)
          OsEdition     - [string] 'Pro', 'Home', 'Enterprise', 'Education', ...
          HasInternet   - [bool]   DNS cozumlemesi basarili mi?
          HasWinget     - [bool]   winget.exe bulunabildi mi?
          WingetVersion - [string] winget surumu (ornek: 'v1.7.10861')
          SourceHealthy - [bool]   winget kaynak saglikli mi?
          Issues        - [string[]] Kullaniciya gosterilecek kisadosyalar
          Remediation   - [string[]] Cozum onerileri
    #>

    $issues      = [System.Collections.Generic.List[string]]::new()
    $remediation = [System.Collections.Generic.List[string]]::new()

    # -- Admin kontrolu --------------------------------------------------
    Write-Host '  Admin yetkisi kontrol ediliyor...' -ForegroundColor DarkGray -NoNewline
    $isAdmin = Test-WFAdminElevation
    if ($isAdmin) {
        Write-Host '  [TAMAM]' -ForegroundColor Green
    } else {
        Write-Host '  [!!] Admin degil' -ForegroundColor Yellow
        # Admin olmadan devam edilebilir; HKCU tweakleri calisir ama HKLM islemler basarisiz olur
        $issues.Add('Admin yetkisi bulunamadi. HKLM tweakleri ve RequiresAdmin=true islemleri CALISMAYCAK.')
        $remediation.Add('Lutfen Launch-WinForge.bat uzerinden baslatip UAC penceresinde "Evet" secin.')
    }

    # -- OS bilgisi -------------------------------------------------------
    Write-Host '  Isletim sistemi algilaniyor...' -ForegroundColor DarkGray -NoNewline
    $osInfo = Get-WFOsInfo
    Write-Host "  Build $($osInfo.Build) / $($osInfo.Edition)" -ForegroundColor DarkGray

    if ($osInfo.Build -lt 17763) {
        $issues.Add("Windows build $($osInfo.Build) desteklenmeyebilir. Minimum: 17763 (Win10 1809).")
    }

    # -- Internet kontrolu ------------------------------------------------
    Write-Host '  Internet baglantisi kontrol ediliyor...' -ForegroundColor DarkGray -NoNewline
    $hasInternet = Test-WFInternetAccess
    if ($hasInternet) {
        Write-Host '  [TAMAM]' -ForegroundColor Green
    } else {
        Write-Host '  [--] Erisim yok' -ForegroundColor Yellow
        # Uyarisi yok; internet olmadan da tweak ve bakim calisabilir
        # Sadece winget source update ve uygulama kurulumu etkilenir
    }

    # -- winget kontrolu --------------------------------------------------
    Write-Host '  winget kontrol ediliyor...' -ForegroundColor DarkGray -NoNewline
    $wingetResult = Test-WFWingetPresence
    $hasWinget    = $wingetResult.Found
    $wingetVer    = $wingetResult.Version

    if ($hasWinget) {
        Write-Host "  [TAMAM] $wingetVer" -ForegroundColor Green
    } else {
        Write-Host '  [!!] Bulunamadi' -ForegroundColor Yellow
        $issues.Add('winget bulunamadi. Uygulama Kurulumu ve App Guncelleme kullanilamiyor.')
        $remediation.Add('Microsoft Store > App Installer uygulamasini acan ve guncelleyin.')
        $remediation.Add('Veya: https://aka.ms/getwinget adresinden manuel kurulum yapabilirsiniz.')
    }

    # -- winget kaynak sagligi (yalnizca winget varsa) --------------------
    $sourceHealthy = $false
    if ($hasWinget) {
        Write-Host '  winget kaynak sagligi kontrol ediliyor...' -ForegroundColor DarkGray -NoNewline
        $srcResult     = Test-WFWingetSourceHealth
        $sourceHealthy = $srcResult.Healthy

        if ($sourceHealthy) {
            if ($srcResult.Degraded) {
                Write-Host '  [!] Kisitli (msstore sozlesmesi gerekebilir)' -ForegroundColor Yellow
            } else {
                Write-Host '  [TAMAM]' -ForegroundColor Green
            }
        } else {
            Write-Host '  [!!] Sorun var' -ForegroundColor Yellow
        }

        if ($srcResult.Issues.Count -gt 0) {
            foreach ($srcIssue in $srcResult.Issues) {
                $issues.Add($srcIssue)
            }
            foreach ($srcFix in $srcResult.Remediation) {
                $remediation.Add($srcFix)
            }
        }
    }

    # -- Sonuc nesnesini dondur ------------------------------------------
    $preflight = [ordered]@{
        IsAdmin       = $isAdmin
        OsBuild       = [int]$osInfo.Build
        OsEdition     = [string]$osInfo.Edition
        HasInternet   = $hasInternet
        HasWinget     = $hasWinget
        WingetVersion = $wingetVer
        SourceHealthy = $sourceHealthy
        Issues        = $issues.ToArray()
        Remediation   = $remediation.ToArray()
    }

    Write-Host ''

    # Remediation onerilerini goster (varsa)
    if ($remediation.Count -gt 0) {
        Write-Host '  Onerileri okuyun:' -ForegroundColor Yellow
        foreach ($fix in $remediation) {
            Write-Host "    - $fix" -ForegroundColor White
        }
        Write-Host ''
    }

    return $preflight
}
