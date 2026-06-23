@echo off
cd /d "%~dp0"

REM Only game audio
set "AUDIO_ENCODER=copy -map 0:v -map 0:a:1"
set "AUDIO_BITRATE=196000"
set "OUTPUT_SUFFIX=_Dumcord_Medal"

call "Dumcord.cmd" %*