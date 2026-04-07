# Sorun Giderme (Troubleshooting)

Bu belge karsilasabileceginiz yaygin durumlari cozmek icin hazirlanmistir.

## Winget Kaynak Sagligi (Source Health) Uyarilari
- **Hata:** Preflight sirasinda winget "Sorun Var (Failed)" donuyor.
- **Sebep:** Katalog bozulmasi veya ag filtrelemesi.
- **Cozum:** PowerShell (Admin) acin ve `winget source reset --force` girin.

## MSStore / Anlasma Sorunu (Degraded / Kisitli Durum)
- **Hata:** Winget "Kisitli (Degraded)" modda olarak gosteriliyor.
- **Anlami:** WinForge bozuk degildir. Hata yok ancak sistem sadece gizli bir onay bekliyor demektir.
- **Cozum:** Yeni bir PowerShell acarak `winget list` komutunu isleyin. Karsiniza anlasma/sozlesme sorusu cikarsa `Y` diyerek onaylayin.

## App Installer (Winget Bulunamadi) Sorunlari
- **Hata:** `winget.exe bulunamadi`.
- **Cozum:** Microsoft Store'u acin ve "App Installer"i veya Turkce sistemi ise "Uygulama Yukleyicisi"ni bulun. Guncelleyin veya kurun. Sifirdan LTSC/Server kuruyorsaniz `aka.ms/getwinget` adresinden indirebilirsiniz.

## Tweak: Erisim Engellendi (Access Denied) Hatalari
- **Hata:** Tweak uygularken loglarda `Registry anahtari uretilemedi (Erisim Engellendi)`.
- **Sebep:** Bazi uretici spesifik veya donanimsal guc planlari, ayrica Defender ayarlari (Tamper Protection) kilitli olabilir.
- **Cozum:** Defender gercek zamanli koruma kapatilacaksa, oncesinde Windows Guvenlik sekmesinden (Windows Security) **Tamper Protection** elle kapali duruma getirilmelidir. Ayrica UAC onayiyla yonetici (Admin) oldugunuzdan emin olun.

## Sanal Makine (VM) Sorunlari
- **Sebep:** VM icerisinde hazirda bekletme (Hibernation) gibi donanimsal guc ozellikleri veya GameDVR aktif edilmemis olabilir. Bu yuzden kapatma tweakleri hata (Desteklenmiyor / Bulunamadi) doner. Cok ciddiye almaniz gerekmeyen uyarilardir.

## Log Dosyasini Okumak
Gecmis ve o anki islemler `logs/` klasorunde tarih sirasina gore saklanir. Sorun durumunda once bu klasore gidip ilgili tarihli Text (Log) dosyasinin en altindaki `ERROR` veya `WARN` satirina bakin. Bircok hata sebebi burada net sekilde yazar.
