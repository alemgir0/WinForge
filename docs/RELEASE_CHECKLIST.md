# V1.1 Sürüm Çıkış Kontrol Listesi

Bu liste yeni release zip'i paylasilmadan once test edilmelidir.

- [ ] **Baslatma Testi:** `Launch-WinForge.bat` sorunsuz powershell'e atiyor ve UAC istiyor mu?
- [ ] **Preflight:** Internet kapali/acik durumlarinda arac kilitlenmeden devam ediyor mu? Timeout'lar tepki veriyor mu?
- [ ] **App Install:** Katalog `AppCatalog.psd1` sorunsuz yukleniyor, arayuzden 1 adet optional uygulama sorunsuz secilip yuklenebiliyor mu?
- [ ] **Tweak Engine (Safe):** 1 adet risksiz tweak secilip basariyla (TAMAM) uygulaniyor mu?
- [ ] **Tweak Rollback:** Uygulanan tweak sorunsuz sekilde Rollback menusunden `[1]` basilarak eski haline (Snapshot uzerinden) getirilebiliyor mu?
- [ ] **Bakim:** Temp temizleyici ve `winget upgrade` calisiyor mu?
- [ ] **Loglama:** Oturum sonunda `logs\` dizinine zaman damgali olarak log yansitilmis mi?
- [ ] **Zip Package:** Olusturulan zip klasoru (`WinForge-v1.1.zip`), bos `logs` ve `backups` klasoru barindiriyor ve test kalintilari icermiyor mu?
