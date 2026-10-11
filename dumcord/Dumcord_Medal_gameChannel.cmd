@echo off
cd /d "%~dp0"

REM Only game audio
set "AUDIO_ENCODER=aac -map 0:v -map 0:a:1"
set "OUTPUT_SUFFIX=_Dumcord_Medal"

call "Dumcord.cmd" %*