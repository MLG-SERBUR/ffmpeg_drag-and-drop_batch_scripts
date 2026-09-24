@echo off
cd /d "%~dp0"

REM - bwdif=mode=1:parity=-1 : Double framerate; honor field-order metadata, default to TFF
set "VIDEO_ENCODER=libx264 -crf 22 -preset veryslow -x264-params open-gop=1 -vf "bwdif=mode=1:parity=-1""
set "AUDIO_ENCODER=aac -b:a 96k -af "pan=mono^|c0=FL""
set "OUTPUT_SUFFIX=_deint"
set "OUTPUT_EXT=.mp4"

call "%~dp0..\delivery.cmd" %*