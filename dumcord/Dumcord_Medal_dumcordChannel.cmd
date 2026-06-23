@echo off
cd /d "%~dp0"

REM Only dumcord audio
set "AUDIO_ENCODER=copy -map 0:v -map 0:a:2"
set "AUDIO_BITRATE=162000"
set "OUTPUT_SUFFIX=_Dumcord_Medal"

call "Dumcord.cmd" %*