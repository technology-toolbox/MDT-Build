setlocal

set SOURCE_PATH=\\TT-FS01\Products\Microsoft\SharePoint 2013\PrerequisiteInstallerFiles_SP1

REM An error occurs if %TEMP% is used to store the prerequisite files when installing
REM via the Microsoft Deployment Toolkit (presumably due to cleanup of temp files during
REM reboot)...
REM
REM set LOCAL_PATH=%TEMP%
REM
REM ...instead copy the files to a custom folder at the root of the C: drive
set LOCAL_PATH=C:\PrerequisiteInstallerFiles_SP1

robocopy "%SOURCE_PATH%" "%LOCAL_PATH%"

PrerequisiteInstaller.exe %* ^
    /SQLNCli:"%LOCAL_PATH%\sqlncli.msi" ^
    /PowerShell:"%LOCAL_PATH%\Windows6.1-KB2506143-x64.msu" ^
    /NETFX:"%LOCAL_PATH%\dotNetFx45_Full_setup.exe" ^
    /IDFX:"%LOCAL_PATH%\Windows6.1-KB974405-x64.msu" ^
    /Sync:"%LOCAL_PATH%\Synchronization.msi" ^
    /AppFabric:"%LOCAL_PATH%\WindowsServerAppFabricSetup_x64.exe" ^
    /IDFX11:"%LOCAL_PATH%\MicrosoftIdentityExtensions-64.msi" ^
    /MSIPCClient:"%LOCAL_PATH%\setup_msipc_x64.msi" ^
    /WCFDataServices:"%LOCAL_PATH%\WcfDataServices.exe" ^
    /KB2671763:"%LOCAL_PATH%\AppFabric1.1-RTM-KB2671763-x64-ENU.exe" ^
    /WCFDataServices56:"%LOCAL_PATH%\WcfDataServices-5.6.exe"
