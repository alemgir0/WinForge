# WinForge V2 Yol Haritasi (Roadmap)

V1.1 surumu ile motor altyapisi saglamlastirilmis ve kullanici testleri tamamlanmistir. V2 surumleri asagidaki bilesenleri iceren genis capli otomasyonlara odaklanacaktir.

## Onerilen Siralama ve Hedefler

### 1. Preset System (Hazir Sablonlar) - Erken V2
**Amac:** Kullanicinin oyun (Gaming), ofis (Office), veya gelistirici (Developer) gibi sablonlari secerek, uygulamalari ve tweakleri topluca ve on tanimli risk ayarlariyla bir defada uygulayabilmesi.

### 2. Silent Mode (Sessiz Kurulum) - Erken V2
**Amac:** `WinForge.ps1 -Profile Dev -Silent` gibi parametrelerle, menuleri atlayip direkt secilen preset'in kullanici mudehalesi olmadan (SIEM araclari veya sifir temas deployment'lar icin) calistirilabilmesi.

### 3. Plugin System (Eklenti Destegi) - Ileri V2
**Amac:** Cekirdek motorlara dokunmadan `plugins/` klasoru icine atilacak PowerShell betikleriyle araca yenilik katma (ornek: GPU surucusu cekme eklentisi veya ozel W11 de-bloat eklentisi). Bu yapi aracin boyutunu moduler ve ufak tutmasini saglar.

### 4. Remote Execution (Uzaktan Yönetim) - Ileri V2
**Amac:** Bir merkez makineden agdaki diger makinelere WinForge `Silent` komutlarini WinRM veya Psexec ile iletebilme. Kucuk isletme AD ortamlari icin faydali olacaktir.
