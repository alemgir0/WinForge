#
# WinForge v1.1 - TweakCatalog.psd1
# Veri dosyasi. Kod icermez.
# Tweak listesini degistirmek icin yalnizca bu dosyayi duzenleyin.
#
# RiskLevel degerleri : Safe | Advanced | Risky
# Scope degerleri     : Machine (HKLM) | User (HKCU)
# RevertMode degerleri:
#   RestorePrevious    - Tweak oncesindeki gercek deger geri yazilir
#   UseDefaultValue    - Katalogdaki DefaultValue yazilir
#   DeleteValue        - Ilgili registry property silinir (key kalir)
#   DeleteKeyIfCreated - Tweak'in olusturdugu key agaci silinir
#
# NOT: SupportedEditions bos dizi (@()) = tum surumlerde gecerli
# NOT: Property = '' --> (Default) registry value hedeflenir
#

@{
    Tweaks = @(

        # ================================================================
        # SAFE TWEAKS - Guveli, geri alinabilir, varsayilan secili
        # ================================================================

        @{
            Id                      = 'DisableTelemetry'
            Name                    = 'Telemetriyi Devre Disi Birak'
            Description             = 'Windows tani bilgisi toplama seviyesini minimuma indirir'
            Category                = 'Privacy'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $true
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @('Pro', 'Enterprise', 'Education')
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
                    Property     = 'AllowTelemetry'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 1
                }
            )
        }

        @{
            Id                      = 'DisableAdvertisingId'
            Name                    = 'Reklam Kimligini Devre Disi Birak'
            Description             = 'Uygulamalarin kisisellestirilmis reklam icin kimlik kullanmasini engeller'
            Category                = 'Privacy'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $true
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
                    Property     = 'Enabled'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 1
                }
            )
        }

        @{
            Id                      = 'DisableActivityHistory'
            Name                    = 'Aktivite Gecmisini Devre Disi Birak'
            Description             = 'Windows aktivite gecmisi toplama ve paylasimini durdurur'
            Category                = 'Privacy'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $true
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
                    Property     = 'EnableActivityFeed'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 1
                }
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
                    Property     = 'PublishUserActivities'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 1
                }
            )
        }

        @{
            Id                      = 'DisableBingSearch'
            Name                    = 'Baslat Menusu Bing Aramasini Devre Disi Birak'
            # Tamamlayici: DisableWebSearch (HKLM, Advanced) ag seviyesini hedefler.
            # Bu tweak UX seviyesini hedefler: yazarken cikan web onerileri.
            # Ikisi birlikte uygulanabilir; birbirini dislamaz.
            Description             = 'Baslat menusundeki arama kutusunda yazarken cikan web onerilerini kapatir (UX katmani). Ag baglantilik icin DisableWebSearch ile tamamlanir.'
            Category                = 'UI'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $true
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $true
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
                    Property     = 'DisableSearchBoxSuggestions'
                    ValueType    = 'DWord'
                    DesiredValue = 1
                    RevertMode   = 'DeleteValue'
                    DefaultValue = $null
                }
            )
        }

        @{
            Id                      = 'ShowFileExtensions'
            Name                    = 'Dosya Uzantilarini Goster'
            Description             = 'Explorer''da her zaman dosya uzantisini gosterir'
            Category                = 'UI'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $true
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $true
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                    Property     = 'HideFileExt'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 1
                }
            )
        }

        @{
            Id                      = 'ShowHiddenFiles'
            Name                    = 'Gizli Dosyalari Goster'
            Description             = 'Explorer''da gizli dosya ve klasorleri gosterir'
            Category                = 'UI'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $true
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $true
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                    Property     = 'Hidden'
                    ValueType    = 'DWord'
                    DesiredValue = 1
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 2
                }
            )
        }

        @{
            Id                      = 'ShowSuperHiddenFiles'
            Name                    = 'Sistem Dosyalarini Goster'
            Description             = 'Korunan isletim sistemi dosyalarini Explorer''da gosterir'
            Category                = 'UI'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $true
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                    Property     = 'ShowSuperHidden'
                    ValueType    = 'DWord'
                    DesiredValue = 1
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 0
                }
            )
        }

        @{
            Id                      = 'DisableStartupDelay'
            Name                    = 'Baslangic Geciktirmesini Devre Disi Birak'
            Description             = 'Masaustu uygulamalarinin baslangicindaki yapay gecikmeyi kaldirir'
            Category                = 'Performance'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $true
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $false
            RequiresReboot          = $true
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
                    Property     = 'StartupDelayInMSec'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'DeleteKeyIfCreated'
                    DefaultValue = $null
                }
            )
        }

        @{
            Id                      = 'SetPowerHighPerformance'
            Name                    = 'Guc Planini Yuksek Performansa Al'
            Description             = 'Aktif guc planini Yuksek Performans olarak ayarlar'
            Category                = 'Performance'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $false
            Actions                 = @(
                @{
                    Type         = 'Powercfg'
                    Arguments    = '/setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
                    DesiredValue = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
                }
            )
        }

        @{
            Id                      = 'AutoEndHungTasks'
            Name                    = 'Askida Kalan Gorevleri Otomatik Sonlandir'
            Description             = 'Kapanisda yanit vermeyen uygulamalari otomatik kapatir'
            Category                = 'Performance'
            RiskLevel               = 'Safe'
            EnabledByDefault        = $true
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Control Panel\Desktop'
                    Property     = 'AutoEndTasks'
                    ValueType    = 'String'
                    DesiredValue = '1'
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = '0'
                }
            )
        }

        # ================================================================
        # ADVANCED TWEAKS - Daha cesur, dikkatli kullan
        # ================================================================

        @{
            Id                      = 'DisableLocationTracking'
            Name                    = 'Konum Izlemeyi Devre Disi Birak'
            Description             = 'Windows konum servisini sistem genelinde devre disi birakir'
            Category                = 'Privacy'
            RiskLevel               = 'Advanced'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
                    Property     = 'DisableLocation'
                    ValueType    = 'DWord'
                    DesiredValue = 1
                    RevertMode   = 'DeleteValue'
                    DefaultValue = $null
                }
            )
        }

        @{
            Id                      = 'ClassicContextMenu'
            Name                    = 'Klasik Sag Tik Menusu (Win11)'
            Description             = 'Windows 11 icin tam eski sag tik menusunu geri getirir. Sadece Windows 11 (build 22000+) uzerinde uygulanir.'
            Category                = 'UI'
            RiskLevel               = 'Advanced'
            EnabledByDefault        = $false
            MinBuild                = 22000
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $true
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
                    # OZEL DURUM: Property = '' --> (Default) registry value hedeflenir.
                    # DesiredValue = '' --> bosaltilmis (Default) value.
                    # Uygulama kodu bu durumu Property -eq '' kontroluyle yakalasin.
                    # RevertMode = DeleteKeyIfCreated: snapshot'ta KeyExisted=$false ise
                    # geri almada CLSID key agacinin tamami silinir.
                    Property     = ''
                    ValueType    = 'String'
                    DesiredValue = ''
                    RevertMode   = 'DeleteKeyIfCreated'
                    DefaultValue = $null
                }
            )
        }

        @{
            Id                      = 'DisableCortana'
            Name                    = 'Cortana''yi Devre Disi Birak'
            Description             = 'Cortana sesli asistanini devre disi birakir. Sadece Pro/Enterprise/Education surumlerinde gecerlidir.'
            Category                = 'Privacy'
            RiskLevel               = 'Advanced'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @('Pro', 'Enterprise', 'Education')
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $false
            RequiresReboot          = $true
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
                    Property     = 'AllowCortana'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'DeleteValue'
                    DefaultValue = $null
                }
            )
        }

        @{
            Id                      = 'DisableWebSearch'
            Name                    = 'Arama Cubugu Internet Baglantisinı Engelle'
            # Tamamlayici: DisableBingSearch (HKCU, Safe) UX seviyesini hedefler.
            # Bu tweak bag seviyesini hedefler: arama cubugu tamamen internete baglanamaز.
            # Sadece Pro/Enterprise/Education surumlerinde gecerlidir (policy key).
            # Ikisi birlikte uygulanabilir; birbirini dislamaz.
            Description             = 'Arama cubugunu internet baglantisindan keser (ag katmani). UX seviyesi icin DisableBingSearch ile tamamlanir. Sadece Pro/Enterprise/Education.'
            Category                = 'Privacy'
            RiskLevel               = 'Advanced'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @('Pro', 'Enterprise', 'Education')
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $true
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
                    Property     = 'DisableWebSearch'
                    ValueType    = 'DWord'
                    DesiredValue = 1
                    RevertMode   = 'DeleteValue'
                    DefaultValue = $null
                }
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
                    Property     = 'ConnectedSearchUseWeb'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'DeleteValue'
                    DefaultValue = $null
                }
            )
        }

        @{
            Id                      = 'DisableGameBar'
            Name                    = 'Xbox Game Bar''i Devre Disi Birak'
            Description             = 'Xbox Game Bar arka plan kaydini ve kaplama arayuzunu devre disi birakir'
            Category                = 'Performance'
            RiskLevel               = 'Advanced'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'User'
            RequiresAdmin           = $false
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\System\GameConfigStore'
                    Property     = 'GameDVR_Enabled'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 1
                }
                @{
                    Type         = 'Registry'
                    Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
                    Property     = 'AppCaptureEnabled'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 1
                }
            )
        }

        # ================================================================
        # RISKY TWEAKS - Dikkatli ol; sistem genelinde etki
        # ================================================================

        @{
            Id                      = 'DisableWindowsSearch'
            Name                    = 'Windows Search Indekslemeyi Devre Disi Birak'
            Description             = 'Windows Search servisini durdurur ve devre disi birakir. Baslat menusunde dosya arama calisir ama daha yavaş olabilir.'
            Category                = 'Services'
            RiskLevel               = 'Risky'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $false
            RequiresReboot          = $true
            SupportsRollback        = $true
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SYSTEM\CurrentControlSet\Services\WSearch'
                    Property     = 'Start'
                    ValueType    = 'DWord'
                    DesiredValue = 4
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 2
                }
            )
        }

        @{
            Id                      = 'DisableHibernation'
            Name                    = 'Hazirda Bekletmeyi Devre Disi Birak'
            # SupportsRollback = $false: Registry degeri geri yazilsa bile hiberfil.sys
            # powercfg /hibernate on ile ayrica etkinlestirilmesi gerekir.
            # UI'da [NO ROLLBACK] etiketi gosterilecek.
            Description             = 'Hazirda bekletme dosyasini (hiberfil.sys) siler ve ozeligi devre disi birakir. Disk alani geri kazanilir. Geri alinamaz (powercfg manuel gerektirir).'
            Category                = 'Performance'
            RiskLevel               = 'Risky'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $false
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
                    Property     = 'HibernateEnabled'
                    ValueType    = 'DWord'
                    DesiredValue = 0
                    RevertMode   = 'RestorePrevious'
                    DefaultValue = 1
                }
            )
        }

        @{
            Id                      = 'DisableWindowsDefenderRealtime'
            Name                    = '!! Defender Gercek Zamanli Korumayi Devre Disi Birak !!'
            # SupportsRollback = $false:
            # Windows Defender, Tamper Protection aktifse policy key'i yoksayar veya
            # geri yazmaya izin vermez. Registry rollback guvenilir degildir.
            # Tamper Protection once elle devre disi birakilmali. Bu otomasyon ile yapilamaz.
            # UI'da [NO ROLLBACK] + cift onay zorunlulugu uygulanacak.
            Description             = 'KRITIK UYARI: Bu islem sistemi viruslere ve kotucul yazilimlara karsi savunmasiz birakir. Yalnizca baska bir antivirusunuz kuruluysa ve Tamper Protection kapaliysa kullanin. Geri ALINAMAZ. Cift onay gerektirir.'
            Category                = 'Security'
            RiskLevel               = 'Risky'
            EnabledByDefault        = $false
            MinBuild                = 17763
            MaxBuild                = 99999
            SupportedEditions       = @()
            Scope                   = 'Machine'
            RequiresAdmin           = $true
            RequiresExplorerRestart = $false
            RequiresReboot          = $false
            SupportsRollback        = $false
            Actions                 = @(
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
                    Property     = 'DisableAntiSpyware'
                    ValueType    = 'DWord'
                    DesiredValue = 1
                    RevertMode   = 'DeleteValue'
                    DefaultValue = $null
                }
                @{
                    Type         = 'Registry'
                    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
                    Property     = 'DisableRealtimeMonitoring'
                    ValueType    = 'DWord'
                    DesiredValue = 1
                    RevertMode   = 'DeleteValue'
                    DefaultValue = $null
                }
            )
        }
    )
}
