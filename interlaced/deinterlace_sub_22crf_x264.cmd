@echo off
cd /d "%~dp0"

REM - bwdif=mode=1:parity=-1 : Double framerate; honor field-order metadata, default to TFF
REM - overlay : Burn-in the first subtitle track [0:s:0]
set "VIDEO_ENCODER=libx264 -crf 22 -preset veryslow -x264-params open-gop=1 -filter_complex "[0:v]bwdif=mode=1:parity=-1[sub];[sub][0:s:0]overlay""
set "AUDIO_ENCODER=aac -b:a 64k -af "pan=mono^|c0=FL""
set "OUTPUT_SUFFIX=_deint_sub"
set "OUTPUT_EXT=.mp4"

call "%~dp0..\delivery.cmd" %*