@echo off
REM 2 pass encoding with 10MB dumcord limit

if "%TARGET_SIZE%"==""      set "TARGET_SIZE=82000000"
if "%AUDIO_BITRATE%"==""    set "AUDIO_BITRATE=0"
if "%OVERHEAD%"==""         set "OVERHEAD=10000"
REM if "%VIDEO_ENCODER%"==""    set "VIDEO_ENCODER=libx264 -preset veryslow -x264-params open-gop=1"
REM iOS requires -tag:v hvc1
if "%VIDEO_ENCODER%"==""    set "VIDEO_ENCODER=libx265 -preset medium -tag:v hvc1 -x265-params open-gop=1"
if "%AUDIO_ENCODER%"==""    set "AUDIO_ENCODER=aac"
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
set "seconds="
for /f "delims=" %%a in ('ffprobe -v error -select_streams v:0 -show_entries format^=duration -of csv^=p^=0 "%~1"') do (
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
ffmpeg -hide_banner -y -i "%~1" ^
-c:v %VIDEO_ENCODER% -b:v %video_bitrate% %VIDEO_TIMING_OPTIONS% ^
%VIDEO_FILTERS% %VIDEO_FILTERS_P1% ^
-pass 1 -passlogfile "ffmpeg2pass" ^
-an -f null NUL

if %errorlevel% neq 0 goto :error

echo.
echo --- Running Pass 2 ---
ffmpeg -hide_banner -y -i "%~1" ^
-c:v %VIDEO_ENCODER% -b:v %video_bitrate% %VIDEO_TIMING_OPTIONS% ^
%VIDEO_FILTERS% %VIDEO_FILTERS_P2% ^
-pass 2 -passlogfile "ffmpeg2pass" ^
%MP4_TIMING_OPTIONS% ^
%MOV_FLAGS% ^
-an "%~n1%OUTPUT_SUFFIX%%OUTPUT_EXT%"

if %errorlevel% neq 0 goto :error

del /q "ffmpeg2pass-0.log" "ffmpeg2pass-0.mbtree" 2>nul

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
del /q "ffmpeg2pass-0.log" "ffmpeg2pass-0.mbtree" 2>nul
pause
exit /b 1

:end
echo.
echo =========================================================
echo All files processed successfully.
echo =========================================================
pause
exit /b 0
