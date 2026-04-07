@echo off
title WinForge v1.0
mode con: cols=100 lines=32
chcp 65001 >nul 2>&1
setlocal

:: ================================================================
:: WinForge v1.0 - Launch-WinForge.bat
:: Cift tikla baslat. Admin degilse UAC yukseltme ister.
:: Admin ise dogrudan WinForge.ps1 baslatir.
:: ================================================================

:: Tam PowerShell yolu - PATH bagimliligini ortadan kaldirir
set "WF_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

:: Admin kontrolu
net session >nul 2>&1
if %errorLevel% equ 0 goto :IsAdmin

:: ----------------------------------------------------------------
:: Admin degil: UAC ile bu dosyayi yeniden calistir (tek seferlik)
:: -WorkingDirectory ile calisma dizini korunur
:: ----------------------------------------------------------------
echo.
echo  WinForge: Admin yetkisi gerekiyor, UAC istegi gonderiliyor...
echo.

"%WF_PS%" -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'" 2>nul
if %errorLevel% neq 0 (
    echo  HATA: UAC istegi reddedildi veya basarisiz oldu.
    echo  Lutfen WinForge klasorunu sag tiklayip "Yonetici olarak calistir" ile baslatin.
    echo.
    pause
    exit /b 1
)

:: Yukseltilmemis eski pencereyi kapat (cift pencere olusturmaz)
exit /b 0

:: ----------------------------------------------------------------
:: Admin: calisma dizinini ayarla, WinForge.ps1 calistir
:: ----------------------------------------------------------------
:IsAdmin
pushd "%~dp0"
"%WF_PS%" -NoProfile -ExecutionPolicy Bypass -File "WinForge.ps1"
set "WF_EXIT=%errorLevel%"
popd

:: Yalnizca hatayla cikissa bildir ve dur
if %WF_EXIT% neq 0 (
    echo.
    echo  WinForge beklenmedik sekilde kapandi. Cikis kodu: %WF_EXIT%
    echo  Detaylar icin logs\ klasorune bakin.
    echo.
    pause
)

endlocal
