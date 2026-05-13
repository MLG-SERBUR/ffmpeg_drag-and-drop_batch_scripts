@echo off
cd /d "%~dp0"

REM Progressive encoding
set "VIDEO_ENCODER=libx264 -crf 20 -preset veryslow"
set "AUDIO_ENCODER=aac -b:a 192k"
set "OUTPUT_SUFFIX="
set "OUTPUT_EXT=.mp4"

call "%~dp0..\delivery.cmd" %*