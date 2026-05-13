@echo off
cd /d "%~dp0"

REM Progressive encoding with subtitles burned in
set "VIDEO_ENCODER=libx264 -crf 26 -filter_complex "[0:v]bm3d=sigma=3[v];[v][0:s:0]overlay" -preset veryslow"
set "AUDIO_ENCODER=libfdk_aac -b:a 64k"
set "OUTPUT_SUFFIX=_subs"
set "OUTPUT_EXT=.mp4"

call "%~dp0..\delivery.cmd" %*