REM Generic compression script. Uses SVT-AV1 codec by default.

if not defined VIDEO_ENCODER    set "VIDEO_ENCODER=libsvtav1 -crf 37 -preset 4"
if not defined AUDIO_ENCODER    set "AUDIO_ENCODER=copy"
if not defined OUTPUT_SUFFIX    set "OUTPUT_SUFFIX=_av1"
if not defined OUTPUT_DIR       set "OUTPUT_DIR="

:loop
REM Check if we have no more files to process
if "%~1"=="" goto :end

echo.
echo =========================================================
echo Processing: "%~nx1"
echo =========================================================

REM "%~n1" gives just the filename (no extension)
REM "%~x1" gives just the extension (.mp4, .mkv, etc)
REM use "%~dp1%~n1_av1%~x1" to save in the same directory as the source file
REM use "%~n1_av1%~x1" to save in script directory

REM If OUTPUT_EXT not defined, use the original file's extension (%~x1).
set "FINAL_EXT=%OUTPUT_EXT%"
if "%FINAL_EXT%"=="" set "FINAL_EXT=%~x1"

echo Output: "%~n1%OUTPUT_SUFFIX%%FINAL_EXT%"

REM Determine output directory: use OUTPUT_DIR if set, otherwise use source file's directory
if "%OUTPUT_DIR%"=="" (
    set "OUTPUT_PATH=%~dp1"
) else (
    set "OUTPUT_PATH=%OUTPUT_DIR%"
)

set "MOV_FLAGS="
if /i "%FINAL_EXT%"==".mp4" set "MOV_FLAGS=-movflags +faststart"

ffmpeg.exe -hide_banner -y %INPUT_OPTIONS% -i "%~1" -map_metadata 0 ^
-c:v %VIDEO_ENCODER% ^
-c:a %AUDIO_ENCODER% ^
%MOV_FLAGS% ^
"%OUTPUT_PATH%%~n1%OUTPUT_SUFFIX%%FINAL_EXT%"

if %errorlevel% neq 0 goto :error

REM COPY MODIFIED DATE FROM SOURCE TO DESTINATION
REM echo Copying timestamp...
REM powershell -Command "(Get-Item '%OUTPUT_PATH%%~n1%OUTPUT_SUFFIX%%FINAL_EXT%').LastWriteTime = (Get-Item '%~1').LastWriteTime"

echo [SUCCESS] "%~nx1" finished.

shift
goto :loop

:error
color 0c
echo.
echo #########################################################
echo CRITICAL ERROR DETECTED!
echo Encoding failed on file: "%~nx1"
echo Process stopped.
echo #########################################################
pause
exit /b 1

:end
echo.
echo =========================================================
echo All files processed successfully.
echo =========================================================
pause
exit /b 0