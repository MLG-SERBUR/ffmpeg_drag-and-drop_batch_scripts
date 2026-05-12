@echo off
title 10MB Opus Audio Compressor

:: Check if a file was dropped
if "%~1"=="" (
    echo Please drag and drop one or more audio files onto this .bat file.
    pause
    exit /b
)

:: Loop through all dragged-and-dropped files
:loop
if "%~1"=="" goto end
call :process_file "%~1"
shift
goto loop

:: Subroutine to process each file
:process_file
set "INPUT=%~1"
set "OUTPUT=%~dpn1_10MB.opus"

echo ---------------------------------------------------
echo Processing: "%INPUT%"

:: 1. Use ffprobe to get the exact duration in seconds
set "DURATION="
for /f "delims=" %%I in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%INPUT%"') do set "DURATION=%%I"

if "%DURATION%"=="" (
    echo Error: Could not read duration for "%INPUT%". Ensure ffprobe is accessible.
    exit /b
)

:: 2. Use PowerShell to do the math (76000 / Duration) to target 9.5MB
for /f "delims=" %%B in ('powershell -NoProfile -Command "[math]::Floor(76000 / %DURATION%)"') do set "BITRATE=%%B"

:: 3. Safeguards: Cap bitrate at 256k (max needed) and 8k (absolute minimum)
if %BITRATE% GTR 256 (
    set "BITRATE=256"
    echo Note: File is short. Capping bitrate at 256 kbps ^(Max transparent quality^).
)
if %BITRATE% LSS 8 (
    set "BITRATE=8"
    echo Warning: File is extremely long! Quality will be very low at 8 kbps.
)

echo Duration: %DURATION% seconds
echo Calculated Bitrate: %BITRATE% kbps
echo.
echo Compressing... Please wait...

:: 4. Run FFmpeg
ffmpeg -y -i "%INPUT%" -c:a libopus -b:a %BITRATE%k -compression_level 10 -vbr on -ar 48000 "%OUTPUT%"

echo Done! Saved as: "%OUTPUT%"
exit /b

:end
echo ---------------------------------------------------
echo All files processed successfully!
pause