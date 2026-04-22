@echo off
REM 2 pass encoding with 10MB dumcord limit

REM --- CLIPBOARD CHECK ---
REM If a file is dragged and dropped, skip to standard processing
if not "%~1"=="" goto :init

echo No file provided via drag-and-drop. Checking clipboard...
set "TEMP_LIST=%TEMP%\clipboard_files_%RANDOM%.txt"

REM PowerShell safely writes any copied file paths into a temporary text file
set "PS_CMD=$c = Get-Clipboard -Format FileDropList -EA SilentlyContinue; if (-not $c) { $t = Get-Clipboard -Raw -EA SilentlyContinue; if ($t) { $t = $t.Trim().Replace([char]34, ''); try { if (Test-Path -LiteralPath $t -PathType Leaf -EA Stop) { $c = @(Get-Item -LiteralPath $t) } } catch {} } }; if ($c) {[System.IO.File]::WriteAllLines($env:TEMP_LIST, [string[]]($c | ForEach-Object { $_.FullName })) } else { Write-Host -ForegroundColor Yellow 'No valid file found in clipboard!'; Write-Host 'Please copy a file (Ctrl+C) in Explorer or drag and drop a file onto this script.'; [void](Read-Host 'Press Enter to exit') }"

powershell -NoProfile -Command "%PS_CMD%"

REM If the temp file wasn't created, nothing was in the clipboard. Safely exit.
if not exist "%TEMP_LIST%" exit /b

REM Read the text file line-by-line and process each file perfectly, ignoring spaces
for /f "usebackq delims=" %%A in ("%TEMP_LIST%") do (
    call :process_file "%%~A"
)

del "%TEMP_LIST%" 2>nul
echo.
echo =========================================================
echo All clipboard files processed successfully.
echo =========================================================
pause
exit /b
REM ------------------------------------

:init
:loop
if "%~1"=="" goto :end
call :process_file "%~1"
shift
goto :loop

:end
echo.
echo =========================================================
echo All files processed successfully.
echo =========================================================
pause
exit /b 0

REM =========================================================
REM THE ACTUAL ENCODING LOGIC
REM =========================================================
:process_file
set "FILE=%~1"
REM Skip if empty
if "%FILE%"=="" exit /b

if "%TARGET_SIZE%"==""      set "TARGET_SIZE=82000000"
if "%AUDIO_BITRATE%"==""    set "AUDIO_BITRATE=96000"
if "%OVERHEAD%"==""         set "OVERHEAD=10000"
REM if "%VIDEO_ENCODER%"==""    set "VIDEO_ENCODER=libx264 -preset veryslow -x264-params open-gop=1"
REM iOS requires -tag:v hvc1
if "%VIDEO_ENCODER%"==""    set "VIDEO_ENCODER=libx265 -preset medium -tag:v hvc1 -x265-params open-gop=1"
if "%AUDIO_ENCODER%"==""    set "AUDIO_ENCODER=aac"
if "%OUTPUT_SUFFIX%"==""    set "OUTPUT_SUFFIX=_dumcord"
if "%OUTPUT_EXT%"==""       set "OUTPUT_EXT=.mp4"
set "MOV_FLAGS="
if /i "%OUTPUT_EXT%"==".mp4" set "MOV_FLAGS=-movflags +faststart"
REM set "VIDEO_FILTERS=-filter:v "crop=in_h:in_h:(in_w-out_w)/2:(in_h-out_h)/2:0""

echo.
echo =========================================================
echo Processing: "%~nx1"
echo Encoder: %VIDEO_ENCODER%
echo =========================================================

REM GET DURATION
set "seconds="
for /f "delims=" %%a in ('ffprobe -v error -select_streams v:0 -show_entries format^=duration -of csv^=p^=0 "%FILE%"') do (
    for /f "tokens=1 delims=." %%b in ("%%a") do set "seconds=%%b"
)

if "%seconds%"=="" set seconds=1
if %seconds% EQU 0 set seconds=1

echo Duration: ~%seconds% seconds.

set /a total_bitrate=TARGET_SIZE / seconds
set /a video_bitrate=total_bitrate - AUDIO_BITRATE - OVERHEAD

echo Target Video Bitrate: %video_bitrate%
echo Audio Bitrate: %AUDIO_BITRATE%
if defined VIDEO_FILTERS echo Filters Applied: %VIDEO_FILTERS%
echo.

echo --- Running Pass 1 ---
ffmpeg -hide_banner -y -i "%FILE%" ^
-c:v %VIDEO_ENCODER% -b:v %video_bitrate% ^
%VIDEO_FILTERS% %VIDEO_FILTERS_P1% ^
-pass 1 -passlogfile "ffmpeg2pass" ^
-an -f null NUL

if %errorlevel% neq 0 goto :error

echo.
echo --- Running Pass 2 ---
ffmpeg -hide_banner -y -i "%FILE%" ^
-c:v %VIDEO_ENCODER% -b:v %video_bitrate% ^
%VIDEO_FILTERS% %VIDEO_FILTERS_P2% ^
-pass 2 -passlogfile "ffmpeg2pass" ^
%MOV_FLAGS% ^
-c:a %AUDIO_ENCODER% -b:a %AUDIO_BITRATE% "%~dpn1%OUTPUT_SUFFIX%%OUTPUT_EXT%"

if %errorlevel% neq 0 goto :error

del /q "ffmpeg2pass-0.log" "ffmpeg2pass-0.mbtree" 2>nul

echo [SUCCESS] "%~nx1" finished.
echo.
exit /b 0

:error
color 0c
echo.
echo #########################################################
echo CRITICAL ERROR DETECTED!
echo Encoding failed on file: "%~nx1"
echo #########################################################
del /q "ffmpeg2pass-0.log" "ffmpeg2pass-0.mbtree" 2>nul
pause
exit /b 1