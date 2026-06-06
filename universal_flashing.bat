@echo off
:: ==========================================================
::   AUTOMATIC ADMIN PRIVILEGE ELEVATION ROUTINE
:: ==========================================================
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :AdminTarget
) else (
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\uac_v10.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\uac_v10.vbs"
    "%temp%\uac_v10.vbs"
    del "%temp%\uac_v10.vbs"
    exit /b
)

:AdminTarget
cls
echo ======================================================================
echo             Welcome to the Windows vhdx flasher v1.0
echo ======================================================================
echo  This tool is useful for flashing a windows image to a vhdx for
echo  hyper v or simply just booting from the vhdx. We also support vhd.
echo  Supports all windows editions from vista and onwards (also supports 
echo  windows server equivalents).
echo ======================================================================
echo.

:: Mode Selection Field
echo Are you using this to slipstream drivers or flash a windows iso and slipstream drivers?
echo  Flash a Windows ISO and slipstream drivers (Full Suite)
echo  Slipstream drivers only (Target an existing OS on a VHDX)
echo.
set /p ModeChoice="Select an option (1 or 2): "
echo.

if "%ModeChoice%" neq "1" if "%ModeChoice%" neq "2" (
    echo [ERROR] Invalid selection. Please restart the script and enter 1 or 2.
    pause
    exit /b
)

:: Common Step: Target VHD/VHDX letter selection
:GetVHDX
set /p VHDXLetter="Enter your mounted VHDX target drive letter (e.g., V): "
set VHDXLetter=%VHDXLetter::=%
set VHDXLetter=%VHDXLetter:\=%

if not exist %VHDXLetter%:\ (
    echo [ERROR] Drive %VHDXLetter%: does not appear to be mounted or valid.
    echo.
    goto :GetVHDX
)
echo Target locked to drive %VHDXLetter%:
echo.

:: Branch logic based on user choice
if "%ModeChoice%" == "2" goto :DriverOnlyEngine

:: ======================================================================
:: OPTION 1: FULL SUITE (FLASH IMAGE SYSTEM)
:: ======================================================================
:GetISO
set /p ISOLetter="Enter your mounted ISO source drive letter (e.g., E): "
set ISOLetter=%ISOLetter::=%
set ISOLetter=%ISOLetter:\=%

if not exist %ISOLetter%:\sources\install.wim (
    if not exist %ISOLetter%:\sources\install.esd (
        echo [ERROR] Could not find install.wim or install.esd on drive %ISOLetter%:.
        echo Check the drive letter and ensure the ISO is mounted.
        echo.
        goto :GetISO
    )
)
echo Source media detected on drive %ISOLetter%:
echo.

set Extension=wim
if exist %ISOLetter%:\sources\install.esd set Extension=esd

echo ======================================================================
echo             SCANNING SOURCE MEDIA FOR AVAILABLE INDEXES               
echo ======================================================================
dism /Get-WimInfo /WimFile:%ISOLetter%:\sources\install.%Extension%
echo ======================================================================
echo.

set /p TargetIndex="Enter the INDEX number you want to deploy from the list: "
echo.

echo ======================================================================
echo   STARTING DEPLOYMENT: Extracting Index %TargetIndex% to drive %VHDXLetter%:
echo ======================================================================
echo.
dism /Apply-Image /ImageFile:%ISOLetter%:\sources\install.%Extension% /Index:%TargetIndex% /ApplyDir:%VHDXLetter%:\

if %errorLevel% neq 0 (
    echo.
    echo [ERROR] DISM deployment failed. Check your index or drive constraints.
    pause
    exit /b
)
echo.
echo Image extraction finished successfully.
echo.

:: Toggled Choice for Option 1
echo ======================================================================
echo                   OFFLINE DRIVER SERVICING ENGINE                     
echo ======================================================================
set /p InjectChoice="Do you want to inject hardware drivers into this image? (Y/N): "

if /i "%InjectChoice%" neq "Y" (
    echo Skipping driver injection.
    goto :DoneSequence
)

:: ======================================================================
:: DRIVER INJECTION CORE SUBROUTINE
:: ======================================================================
:DriverOnlyEngine
echo.
:GetDriverFolder
set /p DriverPath="Enter the FULL path to your driver directory (e.g., C:\DriversFolder): "

if not exist "%DriverPath%" (
    echo [ERROR] The directory "%DriverPath%" does not exist. Check your spelling.
    echo.
    goto :GetDriverFolder
)

echo.
echo Force-slipstreaming drivers from "%DriverPath%" recursively...
echo This will scan all subfolders and inject valid inf packages...
echo.
dism /Image:%VHDXLetter%:\ /Add-Driver /Driver:"%DriverPath%" /Recurse

if %errorLevel% neq 0 (
    echo.
    echo [WARNING] Driver servicing finished, but some packages failed or skipped.
) else (
    echo Drivers successfully integrated into the system image layers.
)

:DoneSequence
echo.
echo ======================================================================
echo   ALL OPERATIONS COMPLETE!
echo ======================================================================
echo  1. Drive %VHDXLetter%: contains your fully prepared operating system.
echo  2. Remember to create the boot files!
echo  3. Thanks for using the tool!
echo ======================================================================
echo.
pause
