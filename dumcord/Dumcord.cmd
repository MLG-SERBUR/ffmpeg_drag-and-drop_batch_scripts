@echo off
REM 2 pass encoding with 20MB dumcord limit

if "%TARGET_SIZE_BYTES%"=="" set "TARGET_SIZE_BYTES=20400000"
if "%TARGET_SIZE%"==""      set "TARGET_SIZE=164000000"
if "%AUDIO_BITRATE%"==""    set "AUDIO_BITRATE=96000"
if "%OVERHEAD%"==""         set "OVERHEAD=10000"
if "%DUMCORD_OUTPUT_DIR%"=="" set "DUMCORD_OUTPUT_DIR=D:\Dumcord_Output"
if "%COPY_TO_CLIPBOARD%"=="" set "COPY_TO_CLIPBOARD=1"
if "%AUTO_OPEN_EXPLORER%"=="" set "AUTO_OPEN_EXPLORER=1"
if "%USE_SOURCE_FOLDER_OUTPUT%"=="" set "USE_SOURCE_FOLDER_OUTPUT=0"
REM if "%VIDEO_ENCODER%"==""    set "VIDEO_ENCODER=libx264 -preset veryslow -x264-params open-gop=1"
REM iOS requires -tag:v hvc1
if "%VIDEO_ENCODER%"==""    set "VIDEO_ENCODER=libx265 -preset medium -tag:v hvc1 -x265-params open-gop=1"
if "%AUDIO_ENCODER%"==""    set "AUDIO_ENCODER=aac -map 0:v -map 0:a:0"
if "%OUTPUT_SUFFIX%"==""    set "OUTPUT_SUFFIX=_dumcord"
if "%OUTPUT_EXT%"==""       set "OUTPUT_EXT=.mp4"
if "%VIDEO_TIMING_OPTIONS%"=="" set "VIDEO_TIMING_OPTIONS=-copyts -copytb 1 -enc_time_base demux -fps_mode passthrough"
set "MOV_FLAGS="
set "MP4_TIMING_OPTIONS="
if /i "%OUTPUT_EXT%"==".mp4" (
    set "MOV_FLAGS=-movflags +faststart"
    set "MP4_TIMING_OPTIONS=-video_track_timescale 90000"
)
REM set "VIDEO_FILTERS=-filter:v "crop=in_h:in_h:(in_w-out_w)/2:(in_h-out_h)/2:0""

if not exist "%DUMCORD_OUTPUT_DIR%" mkdir "%DUMCORD_OUTPUT_DIR%"

:loop
REM Check if we have no more files to process
if "%~1"=="" goto :end

echo.
echo =========================================================
echo Processing: "%~nx1"
echo Encoder: %VIDEO_ENCODER%
echo =========================================================

REM GET DURATION
REM using CSV output to avoid "=" character issues
@REM set "seconds="
@REM for /f "delims=" %%a in ('ffprobe -v error -select_streams v:0 -show_entries format^=duration -of csv^=p^=0 "%~1"') do (
@REM     for /f "tokens=1 delims=." %%b in ("%%a") do set "seconds=%%b"
@REM )

@REM if "%seconds%"=="" set seconds=1
@REM if %seconds% EQU 0 set seconds=1

@REM echo Duration: ~%seconds% seconds.

REM GET EXACT DURATION (including decimals)
for /f "delims=" %%a in ('ffprobe -v error -select_streams v:0 -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%~1"') do set "seconds=%%a"

if "%seconds%"=="" set seconds=1
echo Exact Duration: %seconds% seconds.

REM Use PowerShell to handle the floating-point math accurately
REM Formula: ((TargetBytes * 8) / DurationInSeconds) - AudioBitrate
for /f %%A in ('powershell -NoProfile -Command "[math]::Floor(((%TARGET_SIZE_BYTES% * 8) / %seconds%) - %AUDIO_BITRATE%)"') do set "video_bitrate=%%A"

@REM set /a total_bitrate=TARGET_SIZE / seconds
@REM set /a video_bitrate=total_bitrate - AUDIO_BITRATE - OVERHEAD

echo Target Video Bitrate: %video_bitrate%
echo Audio Bitrate: %AUDIO_BITRATE%
if defined VIDEO_FILTERS echo Filters Applied: %VIDEO_FILTERS%
if /i "%USE_SOURCE_FOLDER_OUTPUT%"=="1" (
    set "OUTPUT_FILE=%~dpn1%OUTPUT_SUFFIX%%OUTPUT_EXT%"
) else (
    set "OUTPUT_FILE=%DUMCORD_OUTPUT_DIR%\%~n1%OUTPUT_SUFFIX%%OUTPUT_EXT%"
)
echo Output File: %OUTPUT_FILE%
echo.

del /q "%DUMCORD_OUTPUT_DIR%\ffmpeg2pass-0.log" "%DUMCORD_OUTPUT_DIR%\ffmpeg2pass-0.mbtree" 2>nul

echo --- Running Pass 1 ---
ffmpeg -hide_banner -y -i "%~1" ^
-c:v %VIDEO_ENCODER% -b:v %video_bitrate% %VIDEO_TIMING_OPTIONS% ^
%VIDEO_FILTERS% %VIDEO_FILTERS_P1% ^
-pass 1 -passlogfile "%DUMCORD_OUTPUT_DIR%\ffmpeg2pass" ^
-an -f null NUL

if %errorlevel% neq 0 goto :error

echo.
echo --- Running Pass 2 ---
ffmpeg -hide_banner -y -i "%~1" ^
-c:v %VIDEO_ENCODER% -b:v %video_bitrate% %VIDEO_TIMING_OPTIONS% ^
%VIDEO_FILTERS% %VIDEO_FILTERS_P2% ^
-pass 2 -passlogfile "%DUMCORD_OUTPUT_DIR%\ffmpeg2pass" ^
%MP4_TIMING_OPTIONS% ^
%MOV_FLAGS% ^
-c:a %AUDIO_ENCODER% -b:a %AUDIO_BITRATE% "%OUTPUT_FILE%"

if %errorlevel% neq 0 goto :error

del /q "%DUMCORD_OUTPUT_DIR%\ffmpeg2pass-0.log" "%DUMCORD_OUTPUT_DIR%\ffmpeg2pass-0.mbtree" 2>nul

if /i "%COPY_TO_CLIPBOARD%"=="1" (
    powershell -NoProfile -Command "Set-Clipboard -Value '%OUTPUT_FILE%'"
    echo Clipboard updated with: %OUTPUT_FILE%
)

REM Track last output for explorer at end
set "LAST_OUTPUT_FILE=%OUTPUT_FILE%"

echo [SUCCESS] "%~nx1" finished.
echo.

REM Shift to next file
shift
goto :loop

:error
color 0c
echo.
echo #########################################################
echo CRITICAL ERROR DETECTED!
echo Encoding failed on file: "%~nx1"
echo #########################################################
del /q "%DUMCORD_OUTPUT_DIR%\ffmpeg2pass-0.log" "%DUMCORD_OUTPUT_DIR%\ffmpeg2pass-0.mbtree" 2>nul
pause
exit /b 1

:end
echo.
echo =========================================================
echo All files processed successfully.
echo =========================================================

if /i "%AUTO_OPEN_EXPLORER%"=="1" if defined LAST_OUTPUT_FILE (
    explorer.exe /select,"%LAST_OUTPUT_FILE%"
)

pause
exit /b 0
