# Ilk Kullanim Rehberi (First Run)

WinForge'u ilk kez calistirirken asagidaki adimlara dikkat edin:

## 1. Zipten Cikarma ve Baslatma
Indirdiginiz `WinForge-v1.0.zip` dosyasini C:\ veya Masaustu gibi yazma izniniz olan bir klasore tam olarak cikartin. Zip icerisinden direk calistirmayin!
Araci baslatmak icin klasor icindeki **`Launch-WinForge.bat`** dosyasina cift tiklayin. Bu dosya otomatik olarak PowerShell'i uygun dizinde ve Yonetici hakki ile (UAC) baslatir.

## 2. PowerShell Yonetici ve Execution Policy
`Launch-WinForge.bat` arka planda su islemi yapar: `powershell.exe -ExecutionPolicy Bypass -NoProfile -File WinForge.ps1`. Eger bat dosyasini kullanmak istemezseniz, PowerShell'i as admin acip ayni komutu elle de yurutebilirsiniz.
_Not: Sistem genelindeki Execution Policy ayariniz kalici olarak degistirilmez, sadece bu oturum icin ByPass tanimlanir._

## 3. Ilk Acilista Beklentiler
Arac acildiginda "Invoke-PreflightCheck" modulu baslar ve sisteminizi tarar:
- Internet erisimi
- Winget varligi
- MSStore / Winget kaynak sagligi

Eger Winget kaynagi lisans/anlasma onayindan dolayi takili kalirsa, WinForge bunu algilar ve `Kisitli (Degraded)` modda yola devam eder. Bu durum kiritik degildir ve WinForge bozuldu anlamina gelmez, yalnizca onay verilene dek tam kapasite indiremeyebilir. Bekleme suresi max 5 saniyedir.

## 4. Winget ve MSStore Anlasmalari
Winget ilk kez calistirildiginda Microsoft Store sozlesmelerini kabul etmenizi ister. Ekranda uyarilar veya atlamalar gorurseniz, yeni bir powershell penceresi acip `winget list` yazin ve anlasmalari eger istenir ise (Y) tuslayip kabul edin. Arac bu durumlari kendi atlamaya ve izole etmeye ayarlidir ancak onaylanmasi saglikli uyguluma kurulumu icin en dogru olanidir.

## 5. Baslangic Icin Tavsiyeler
Ilk denemelerinizde Tweak menulerine girdiginizde sadece **[Safe]** (Guvenli) etiketli tweak'leri uygulayin. Tum tweakleri aniden uygulamak yerine aciklamalarini okuyun. Advanced ve Risky tweak'leri iyice arastirmadan once test makinesinde kontrol etmeniz veya oncesinde bir yedek olusturmaniz (Yedekleme Menusu altindan) tavsiye edilir.
