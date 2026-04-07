#
# WinForge v1.1 - AppCatalog.psd1
# Veri dosyasi. Kod icermez.
# Uygulama listesini degistirmek icin yalnizca bu dosyayi duzenleyin.
# Her uygulama icin:
#   Id       : winget package ID (winget search <name> ile dogrulanabilir)
#   Name     : Gosterilecek isim
#   Optional : $true = varsayilan olarak secili degil | $false = varsayilan secili
#   Notes    : Kisa aciklama (log ve menu icin)
#

@{
    Categories = @(

        @{
            Name = 'Temel Uygulamalar'
            Apps = @(
                @{ Id = '7zip.7zip'; Name = '7-Zip'; Optional = $false; Notes = 'Arsiv yonetimi' }
                @{ Id = 'voidtools.Everything'; Name = 'Everything'; Optional = $false; Notes = 'Hizli dosya arama' }
                @{ Id = 'Notepad++.Notepad++'; Name = 'Notepad++'; Optional = $false; Notes = 'Metin ve kod editoru' }
                @{ Id = 'SumatraPDF.SumatraPDF'; Name = 'SumatraPDF'; Optional = $false; Notes = 'Hafif PDF okuyucu' }
                @{ Id = 'VideoLAN.VLC'; Name = 'VLC Media Player'; Optional = $false; Notes = 'Medya oynatici' }
                @{ Id = 'Microsoft.PowerToys'; Name = 'PowerToys'; Optional = $false; Notes = 'Windows verimlilik araclari' }
                @{ Id = 'Bitwarden.Bitwarden'; Name = 'Bitwarden'; Optional = $true; Notes = 'Parola yoneticisi' }
                @{ Id = 'ShareX.ShareX'; Name = 'ShareX'; Optional = $true; Notes = 'Ekran goruntusu ve kayit' }
            )
        }

        @{
            Name = 'Tarayicilar'
            Apps = @(
                @{ Id = 'Brave.Brave'; Name = 'Brave'; Optional = $true; Notes = 'Gizlilik odakli tarayici' }
                @{ Id = 'Mozilla.Firefox'; Name = 'Firefox'; Optional = $true; Notes = 'Alternatif tarayici' }
                @{ Id = 'Google.Chrome'; Name = 'Google Chrome'; Optional = $true; Notes = 'Yaygin tarayici' }
            )
        }

        @{
            Name = 'Teknik / Yonetici Araclari'
            Apps = @(
                @{ Id = 'Microsoft.PowerShell'; Name = 'PowerShell 7'; Optional = $false; Notes = 'Modern PowerShell' }
                @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal'; Optional = $false; Notes = 'Terminal uygulamasi' }
                @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code'; Optional = $false; Notes = 'Kod editoru' }
                @{ Id = 'Git.Git'; Name = 'Git'; Optional = $false; Notes = 'Versiyon kontrol sistemi' }
                @{ Id = 'WinSCP.WinSCP'; Name = 'WinSCP'; Optional = $false; Notes = 'SCP/SFTP istemcisi' }
                @{ Id = 'PuTTY.PuTTY'; Name = 'PuTTY'; Optional = $false; Notes = 'SSH istemcisi' }
                @{ Id = 'WiresharkFoundation.Wireshark'; Name = 'Wireshark'; Optional = $true; Notes = 'Ag analizi' }
                @{ Id = 'Rufus.Rufus'; Name = 'Rufus'; Optional = $true; Notes = 'Bootable USB araci' }
                @{ Id = 'CrystalDewWorld.CrystalDiskInfo'; Name = 'CrystalDiskInfo'; Optional = $true; Notes = 'Disk sagligi izleme' }
                @{ Id = 'JAMSoftware.TreeSize.Free'; Name = 'TreeSize Free'; Optional = $true; Notes = 'Disk kullanim analizi' }
                @{ Id = 'AntibodySoftware.WizTree'; Name = 'WizTree'; Optional = $true; Notes = 'Hizli disk analizi' }
                @{ Id = 'RustDesk.RustDesk'; Name = 'RustDesk'; Optional = $true; Notes = 'Uzak erisim araci' }
            )
        }

        @{
            Name = 'Multimedya / Iletisim'
            Apps = @(
                @{ Id = 'OBSProject.OBSStudio'; Name = 'OBS Studio'; Optional = $true; Notes = 'Ekran kaydi ve yayin' }
                @{ Id = 'Discord.Discord'; Name = 'Discord'; Optional = $true; Notes = 'Iletisim uygulamasi' }
                @{ Id = 'Telegram.TelegramDesktop'; Name = 'Telegram Desktop'; Optional = $true; Notes = 'Mesajlasma uygulamasi' }
                @{ Id = 'qBittorrent.qBittorrent'; Name = 'qBittorrent'; Optional = $true; Notes = 'Torrent istemcisi' }
            )
        }
    )
}
