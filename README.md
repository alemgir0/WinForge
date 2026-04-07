![Version](https://img.shields.io/badge/version-v1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-lightgrey)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)
# WinForge v1.0 — Windows Kurulum ve Bakim Araci

WinForge; yeni bir Windows kurulumu sonrasinda uygulama yuklemek, sistem ayarlarini otomatik yapilandirmak, rutin bakim islemlerini gerceklestirmek ve registry yedegini almak icin tasarlanmis, **moduler ve veri odakli** bir PowerShell 5.1 aracidır.

Amac: Tekrar eden manuel adimlari ortadan kaldirmak, degisiklikleri izlenebilir ve geri alinabilir kılmak.

---

## Desteklenen Ortam

| Gereksinim         | Deger                                              |
|--------------------|----------------------------------------------------|
| Isletim Sistemi    | Windows 10 (build 17763+) / Windows 11             |
| PowerShell         | 5.1 (yerlesik `powershell.exe`) — PS7 desteklenmez |
| Kullanici Yetkisi  | Yonetici (Administrator) — UAC otomatik istenir    |
| winget             | Uygulama kurulumu icin zorunlu                     |
| Internet           | Uygulama kurulumu icin zorunlu                     |

> **Not:** Yalnizca registry tabanli tweak'ler ve yedekleme islemleri internet baglantisi gerektirmez.

---
## Preview

![Main Menu](docs//Winforge-1.pdf)
![Tweaks](docs/Winforge-2.pdf)

## Klasor Yapisi

```
WinForge\
├── Launch-WinForge.bat       # Calistirilacak dosya (UAC ve calisma dizini yonetimi)
├── WinForge.ps1              # Ana orkestrator - modul yukler, ana dongu
├── data\
│   ├── AppCatalog.psd1       # Uygulama listesi (duzenlenebilir)
│   └── TweakCatalog.psd1    # Tweak listesi (duzenlenebilir)
└── modules\
    ├── Invoke-PreflightCheck.ps1   # Sistem on kontrolleri
    ├── Install-Applications.ps1    # Uygulama kurulum menüsü
    ├── Set-WindowsTweaks.ps1       # Registry tweak motoru
    ├── Invoke-Maintenance.ps1      # Bakim islemleri
    └── Invoke-BackupRestore.ps1    # Yedekleme / geri yukleme

# Calisma sirasinda otomatik olusturulanlar:
    logs\                     # Oturum log dosyalari (WinForge_YYYYMMDD_HHmmss.log)
    backups\
    ├── registry\             # Manuel registry yedekleri (.reg)
    ├── tweaks\               # Tweak snapshot dosyalari (.json)
    └── full\                 # Tam sistem yedek hedef klasoru
```

---

## Baslangic (Hizli Kurulum)

1. `WinForge\` klasorunu istediginiz calisabilir bir konuma Cikartin / Kopyalayin (Zip uzerinden direk calistirmayin).
2. **`Launch-WinForge.bat`** dosyasina **cift tiklayin**.
3. UAC (Yonetici ONAYI) penceresi gelirse "Evet" secin.
4. Arac acilir, on kontroller yapilir, ana menu goruntulenir.

> **Ilk Kullanim / Anlasma Notu:** WinForge, ilk acilisinda `winget` altyapisi icin bazi Microsoft Store sozlesmelerini tarar. Arac bu onaylari bypass etmeyi dener ve eger arka planda islem takilirsa WinForge "Kisitli" (Degraded) modda baslar. Bu bozuk oldugu anlamina gelmez, kullanima devam edebilirsiniz. Yalnizca saglikli bir uygulama kurulum deneyimi icin baska bir pencerede PowerShell acarak `winget list` islemeniz ve anlasmalari `(Y)` tuslayarak kabul etmeniz tavsiye edilir.

> **Guvenli Baslangic Tavsiyesi:** Tweak motorunu (Menü 2) ilk kullaniminizda, genelde sadece "[Safe]" etiketli ince ayarlari uygulamaniz sistem stabilizeliği acisindan cok daha risksizdir. Diger secenekler oncesinde mutlaka aracin kendisinden Tam Registry Yedegi almaniz onerilir.

> Dogrudan `WinForge.ps1` calistirmayin: calisma dizini yanlış ayarlaniyor ve UAC otomatik tetiklenmiyor.

---

## Ana Menu

```
  [1]  Uygulama Kurulumu
  [2]  Windows Tweakleri
  [3]  Bakim / Guncelleme
  [4]  Yedekleme / Geri Al
  [0]  Cikis
```

Menunun ustunda sistem durumu ozeti goruntulenir:

```
  [OK] Admin   [OK] Internet   [OK] winget v1.x.x
```

---

## Ozellikler (Ana Moduller)

- **Sistem On Kontrolu:** Arac her acilisinda arka planda yetki (Admin), internet baglantisi ve uygulama yukleyicisi (winget) sagligini tarar.
- **Uygulama Kurulumu:** Katalog bazli secim sunar. Secilen programlari (tarayici, temel araclar vs) tek tek otomatik kurar, halihazirda kurulu olanlari güvenle atlar.
- **Windows Tweakleri (Ince Ayarlar):** Gizlilik, performans ve kullanim kolayligi icin degisiklikler sunar. Oncesinde guvenliginiz icin mevcut ayarlarinizin bir kopyasini (snapshot) alir ve geriye almaniza olanak tanir.
- **Bakim ve Guncelleme:** Temp klasor temizligi, sistem guncellemeleri (`winget upgrade`), disk temizligi ve kaynak sorunlarini giderme gibi genel bakim islerini tek tikla yapar.
- **Yedekleme ve Geri Yukleme:** Kritik islemler oncesi tam registry yedegi almaniza ve guvenle geri donmenize olanak tanir.

## Ileri Duzey (Katalog Duzenleme)

Ileri duzey kullanicilar `data\AppCatalog.psd1` ve `data\TweakCatalog.psd1` dosyalarini Not Defteri veya baska bir metin editoru ile acarak kendi ozel kurallarini, program listelerini ve registry ayarlarini duzenleyebilir. Sablon yapisi bu dosyalardadir. 

Projenin mimarisi, Tweak listesi moduler olacak sekilde kodlanmis olup geriye donuk rollback uyumludur.

---

## Log Dosyalari

Gerceklestirilen butun islemler ve hatalar `logs/` klasoru icerisinde geriye donuk incelenebilmeniz icin tarih bazli olarak saklanmaktadir. Hatalarin temel kaynaklarini burada bulabilirsiniz.

---

## Cikis Ozeti

Cikista arac:
- Explorer yeniden baslatmasi gerekliyse sorar.
- Sistem yeniden baslama gerekiyorsa uyarir.
- Log dosya yolunu gosterir.

---

## Guvenlik Notlari

- **Tweak'leri `Risky` seviyede dikkatli uygulamamizi oneririz.** Ozellikle `Defender gercek zamanli koruma` tweaki yalnizca baska bir antivirusunuz varsa ve `Tamper Protection` kapaliysa kullanilmalidir.
- **`SupportsRollback = $false`** tweak'ler geri alinamaz. Bu isaretteki islemleri uygulamadan once `Tam Registry Yedegi` alin.
- Registry yedegi buyuk olabilir (200-800 MB). Yeterli disk alani oldugunu dogrulayin.
- Tweak snapshot'lari `backups\tweaks\` altinda `.json` formatinda saklanir; iceriklerini metin editoru ile inceleyebilirsiniz.
- WinForge, Execution Policy'yi yalnizca kendi oturumu icin `Bypass` modunda calisir; sistem genelinde degistirmez.

---

## Yaygin Sorunlar

| Sorun | Olasi Neden | Cozum |
|-------|-------------|-------|
| `winget` bulunamadi uyarisi | App Installer surumu eski veya kurulu degil | Microsoft Store > "App Installer" aratip guncelleyin |
| `winget source` hatasi | Kaynak saglik sorunu | Bakim menusunden "winget source reset" calistirin |
| Tweak `[DESTEKSIZ]` goruntulu | MinBuild/Edition sartlari saglanmiyor | Baska bir tweak secin; Windows build surum uyumsuzlugu |
| `Modul yuklenemedi` hatasi | `modules\` altindaki dosya eksik veya bozuk | Dosya butunlugunu kontrol edin, WinForge'u yeniden indirin |
| UAC sonrasi ekran acilmiyor | PowerShell Execution Policy engeli | Calisma klasorunde `Launch-WinForge.bat`'i sag tikla > Yonetici olarak calistir |
| Rollback sonrasi degisiklik yok | `SupportsRollback = $false` veya snapshot bozuk | Manuel registry yedeginden geri yukleyin |
| Log dosyasi olusmuyor | `logs\` klasoru olusturulamiyor (izin sorunu) | WinForge klasorunu Program Files disinda bir yere tasiyin |
