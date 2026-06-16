@echo off
REM Single-pass encoding with Medal game audio (second audio stream only)
REM Uses delivery.cmd pattern

cd /d "%~dp0"

set "VIDEO_ENCODER=copy"
set "AUDIO_ENCODER=copy -map 0:v -map 0:a:1"
set "OUTPUT_SUFFIX=_gameAudio"

call "..\delivery.cmd" %*