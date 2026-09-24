@echo off
cd /d "%~dp0"

set "VIDEO_ENCODER=libx264 -crf 16 -preset veryslow -x264-params open-gop=1:tff=1 -vf setfield=tff -flags +ilme+ildct -tune film"
set "OUTPUT_SUFFIX=_film"
set "OUTPUT_DIR=W:\Video"

call "%~dp0..\delivery.cmd" %*