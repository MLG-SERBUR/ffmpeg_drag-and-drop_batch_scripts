@echo off
cd /d "%~dp0"

REM Left crop 90px in
set "VIDEO_ENCODER=libsvtav1 -crf 37 -preset 4 -vf "crop=iw-90:ih:90:0""
set "OUTPUT_SUFFIX=_crop_90"

call "%~dp0..\delivery.cmd" %*
