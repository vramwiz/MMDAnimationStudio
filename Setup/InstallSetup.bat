@echo off
setlocal

set "ERRORFLAG=0"
set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "SRC_PLUGIN=C:\ProgramData\aviutl2\Plugin\MMD"
set "SRC_SCRIPT=C:\ProgramData\aviutl2\Script\MMD"
set "PACKAGE_DIR=%SCRIPT_DIR%Package"
set "DST_PLUGIN=%PACKAGE_DIR%\Plugin"
set "DST_SCRIPT=%PACKAGE_DIR%\Script"
set "DST_LEARNING=%PACKAGE_DIR%\Learning"
set "OUTPUT_ZIP=%SCRIPT_DIR%MMDAnimationStudio.zip"

for /f "tokens=3 delims=' " %%A in ('findstr MMD_ANIMATION_STUDIO_VERSION "%ROOT_DIR%\Version.inc"') do set "VERSION=%%A"
if "%VERSION%"=="" (
    echo Failed to read Version.inc.
    set "ERRORFLAG=1"
    goto :END
)

echo MMDAnimationStudio distribution version: %VERSION%
if /I not "%~1"=="/Y" (
    choice /c YN /m "Create distribution ZIP"
    if errorlevel 2 goto :CANCEL
)

if exist "%PACKAGE_DIR%" rmdir /s /q "%PACKAGE_DIR%"
mkdir "%DST_PLUGIN%"
mkdir "%DST_SCRIPT%"
mkdir "%DST_LEARNING%"

for %%F in (
    MMDAnimationStudio.aux2
    MMD_Model_Filter.auf2
    MMD_Accessory_Filter.auf2
    MMD_Face_Filter.auf2
    MMD_Serif_Draw_Filter.auf2
    sk4d.dll
) do call :COPY_REQUIRED "%SRC_PLUGIN%\%%F" "%DST_PLUGIN%\%%F"

for %%F in (
    @MMD_Script.obj2
    MMD_Module.mod2
) do call :COPY_REQUIRED "%SRC_SCRIPT%\%%F" "%DST_SCRIPT%\%%F"

call :COPY_REQUIRED "%ROOT_DIR%\README.md" "%PACKAGE_DIR%\README.md"
call :COPY_REQUIRED "%ROOT_DIR%\Learning\MMD_POSE_LEARNING.md" "%DST_LEARNING%\MMD_POSE_LEARNING.md"
call :COPY_REQUIRED "%ROOT_DIR%\Learning\confirmed-poses.json" "%DST_LEARNING%\confirmed-poses.json"

if not "%ERRORFLAG%"=="0" goto :END

if exist "%OUTPUT_ZIP%" del /f /q "%OUTPUT_ZIP%"
if exist "%OUTPUT_ZIP%" (
    echo Cannot replace the existing ZIP: %OUTPUT_ZIP%
    set "ERRORFLAG=1"
    goto :END
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; Compress-Archive -Path '%PACKAGE_DIR%\*' -DestinationPath '%OUTPUT_ZIP%'"
if errorlevel 1 set "ERRORFLAG=1"
if not exist "%OUTPUT_ZIP%" set "ERRORFLAG=1"
goto :END

:COPY_REQUIRED
if not exist "%~1" (
    echo Missing: %~1
    set "ERRORFLAG=1"
    exit /b
)
copy /Y "%~1" "%~2" >nul
if errorlevel 1 (
    echo Copy failed: %~1
    set "ERRORFLAG=1"
)
exit /b

:CANCEL
echo Distribution ZIP creation cancelled.
echo.
if /I not "%~1"=="/Y" pause
endlocal
exit /b

:END
if "%ERRORFLAG%"=="0" (
    echo Distribution ZIP created: %OUTPUT_ZIP%
) else (
    echo Distribution ZIP creation failed.
)
echo.
if /I not "%~1"=="/Y" pause
endlocal
