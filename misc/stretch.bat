@echo off
setlocal

:: Prompt user for the target framerate
echo =========================================================
set /p TARGET_FPS="Enter desired TARGET framerate (e.g., 60, 30, 24): "
if "%TARGET_FPS%"=="" set "TARGET_FPS=60"

:: Set your output directory here
set "OUTPUT_DIR=D:\Dumcord_Output"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: ------------------------------------------------------------------
:: Create a temporary PowerShell script to handle complex decimal math
:: ------------------------------------------------------------------
set "PS_HELPER=%temp%\calc_tempo.ps1"
echo $src = $args[0] -split '/' > "%PS_HELPER%"
echo $s = [double]$src[0] >> "%PS_HELPER%"
echo if ($src.Count -gt 1) { $s = $s / [double]$src[1] } >> "%PS_HELPER%"
echo $t = [double]$args[1] >> "%PS_HELPER%"
echo $scale = $s / $t >> "%PS_HELPER%"
echo $tempo = 1.0 / $scale >> "%PS_HELPER%"
echo $chain = "" >> "%PS_HELPER%"
echo while ($tempo -lt 0.5) { $chain += "atempo=0.5,"; $tempo /= 0.5 } >> "%PS_HELPER%"
echo while ($tempo -gt 100.0) { $chain += "atempo=100.0,"; $tempo /= 100.0 } >> "%PS_HELPER%"
echo $chain += "atempo=" + [math]::Round($tempo, 6) >> "%PS_HELPER%"
echo Write-Output "$([math]::Round($scale, 6))|$chain" >> "%PS_HELPER%"
:: ------------------------------------------------------------------

:loop
REM Check if we have no more files to process
if "%~1"=="" goto :end

call :process_file "%~1"

shift
goto :loop

:process_file
echo.
echo =========================================================
echo Processing: "%~nx1"
echo =========================================================

REM 1. Get the original framerate using ffprobe
for /f "delims=" %%A in ('ffprobe -v error -select_streams v:0 -show_entries stream^=r_frame_rate -of default^=noprint_wrappers^=1:nokey^=1 "%~1"') do set "SOURCE_FPS=%%A"

if "%SOURCE_FPS%"=="" (
    echo Error: Could not determine framerate for "%~nx1". Skipping...
    exit /b 1
)

REM 2. Run the PowerShell helper to calculate itsscale and the audio filter string
for /f "tokens=1,2 delims=|" %%A in ('powershell -ExecutionPolicy Bypass -File "%PS_HELPER%" "%SOURCE_FPS%" "%TARGET_FPS%"') do (
    set "ITSSCALE=%%A"
    set "ATEMPO=%%B"
)

REM 3. Set Output File Name
set "OUTPUT_PATH=%OUTPUT_DIR%\%~n1_%TARGET_FPS%fps.mp4"

echo Source FPS: %SOURCE_FPS%
echo Target FPS: %TARGET_FPS%
echo Video Scale: %ITSSCALE%
echo Audio Filter: %ATEMPO%
echo Output: "%OUTPUT_PATH%"
echo.

REM 4. Run the FFmpeg command using your specific flags
ffmpeg.exe -hide_banner -itsscale %ITSSCALE% -i "%~1" ^
-map 0:0 -c:0 copy ^
-map 0:1 -filter:1 "%ATEMPO%" -c:1 aac -b:1 192k ^
-map_metadata 0 -movflags use_metadata_tags -movflags +faststart ^
-default_mode infer_no_subs -ignore_unknown -f mp4 -y "%OUTPUT_PATH%"

if %errorlevel% neq 0 goto :error

echo [SUCCESS] "%~nx1" finished.
exit /b 0

:error
color 0c
echo.
echo #########################################################
echo CRITICAL ERROR DETECTED!
echo Encoding failed on file: "%~nx1"
echo Process stopped.
echo #########################################################
pause
exit

:end
REM Clean up the temporary PowerShell file
if exist "%PS_HELPER%" del "%PS_HELPER%"

echo.
echo =========================================================
echo All files processed successfully.
echo =========================================================
pause
exit /b 0