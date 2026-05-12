@echo off
setlocal enabledelayedexpansion

REM --- Force working directory to the folder where this script lives ---
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"

REM --- Generate Timestamped Log File name ---
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (set mytime=%%a-%%b)
set "VMAF_LOG=%SCRIPT_DIR%vmaf_!mydate!_!mytime!.log"

echo Starting process... 
echo Scripts and Output folder: %SCRIPT_DIR%
echo Log file: %VMAF_LOG%
echo ========================================================= > "%VMAF_LOG%"
echo ENCODING LOG - %DATE% %TIME% >> "%VMAF_LOG%"
echo ========================================================= >> "%VMAF_LOG%"

REM --- Configuration ---
if "%TARGET_SIZE%"==""      set "TARGET_SIZE=82000000"
if "%AUDIO_BITRATE%"==""    set "AUDIO_BITRATE=96000"
if "%OVERHEAD%"==""         set "OVERHEAD=10000"
if "%AUDIO_ENCODER%"==""    set "AUDIO_ENCODER=aac"
if "%OUTPUT_EXT%"==""       set "OUTPUT_EXT=.mp4"
if "%VIDEO_TIMING_OPTIONS%"=="" set "VIDEO_TIMING_OPTIONS=-copyts -copytb 1 -enc_time_base demux -fps_mode passthrough"
set "MOV_FLAGS="
set "MP4_TIMING_OPTIONS="
if /i "%OUTPUT_EXT%"==".mp4" (
    set "MOV_FLAGS=-movflags +faststart"
    set "MP4_TIMING_OPTIONS=-video_track_timescale 90000"
)

:loop
if "%~1" == "" goto end

echo.
echo [SOURCE] Processing: "%~nx1"
echo [SOURCE] Processing: "%~nx1" >> "%VMAF_LOG%"

REM --- Calculate Duration ---
set "seconds_dur="
for /f "delims=" %%a in ('ffprobe -v error -select_streams v:0 -show_entries format^=duration -of csv^=p^=0 "%~1"') do (
    for /f "tokens=1 delims=." %%b in ("%%a") do set "seconds_dur=%%b"
)
if "%seconds_dur%"=="" set seconds_dur=1
if %seconds_dur% EQU 0 set seconds_dur=1

set /a total_bitrate=TARGET_SIZE / seconds_dur
set /a video_bitrate=total_bitrate - AUDIO_BITRATE - OVERHEAD

REM --- Presets ---
for %%A in (
    "libx264|veryslow|_x264_veryslow|-x264-params open-gop=1"
    "libx265|medium|_x265_medium|-tag:v hvc1 -x265-params open-gop=1"
    "libx265|slow|_x265_slow|-tag:v hvc1 -x265-params open-gop=1"
) do (
    for /f "tokens=1,2,3,4 delims=|" %%B in ("%%~A") do (
        set "ENC=%%B"
        set "PRESET=%%C"
        set "SUFFIX=%%D"
        set "PARAMS=%%E"
        
        REM --- Set OUTFILE to the script's directory ---
        set "OUTFILE=%SCRIPT_DIR%%~n1!SUFFIX!%OUTPUT_EXT%"

        echo [STARTING] !ENC! / !PRESET!

        REM --- START TIMER ---
        set "t=!TIME: =0!"
        set /a "h=1!t:~0,2!-100, m=1!t:~3,2!-100, s=1!t:~6,2!-100"
        set /a "start_total=h*3600 + m*60 + s"

        REM --- FFmpeg Pass 1 (Temp logs created in Script Dir) ---
        ffmpeg -hide_banner -y -i "%~1" -c:v !ENC! -preset !PRESET! !PARAMS! -b:v %video_bitrate% %VIDEO_TIMING_OPTIONS% -pass 1 -passlogfile "%SCRIPT_DIR%ffmpeg2pass" -an -f null NUL
        
        REM --- FFmpeg Pass 2 ---
        ffmpeg -hide_banner -y -i "%~1" -c:v !ENC! -preset !PRESET! !PARAMS! -b:v %video_bitrate% %VIDEO_TIMING_OPTIONS% -pass 2 -passlogfile "%SCRIPT_DIR%ffmpeg2pass" %MP4_TIMING_OPTIONS% %MOV_FLAGS% -c:a %AUDIO_ENCODER% -b:a %AUDIO_BITRATE% "!OUTFILE!"

        REM --- END TIMER ---
        set "t=!TIME: =0!"
        set /a "h=1!t:~0,2!-100, m=1!t:~3,2!-100, s=1!t:~6,2!-100"
        set /a "end_total=h*3600 + m*60 + s"
        if !end_total! lss !start_total! set /a end_total+=86400
        set /a ELAPSED=end_total-start_total

        REM --- LOGGING TO FILE ---
        echo [LOGGING] Writing results to %VMAF_LOG%
        echo File: %~nx1 ^| Encoder: !ENC! ^| Preset: !PRESET! ^| Time: !ELAPSED!s >> "%VMAF_LOG%"
        
        echo [VMAF] Running ab-av1...
        ab-av1 vmaf --reference "%~1" --distorted "!OUTFILE!" --vmaf-fps 0 --vmaf-scale none >> "%VMAF_LOG%" 2>&1
        
        echo --------------------------------------------------------- >> "%VMAF_LOG%"

        REM Clean up temp pass files in Script Dir
        del /q "%SCRIPT_DIR%ffmpeg2pass-0.log" "%SCRIPT_DIR%ffmpeg2pass-0.mbtree" 2>nul
    )
)

shift
goto loop

:error
echo ERROR: Script failed at %TIME% >> "%VMAF_LOG%"
pause
exit /b 1

:end
echo.
echo =========================================================
echo All files processed.
echo Output Videos and Log are in: %SCRIPT_DIR%
echo =========================================================
pause
