@echo off
REM Windows batch equivalent of start.sh for FarmerFred NES project

setlocal enabledelayedexpansion

REM Set project variables
set ROOT_DIR=%~dp0
set PROJECT_NAME=FarmerFred
set PROJECT_DIR=%ROOT_DIR%


REM Set SDK directory explicitly (edit this path if your SDK is elsewhere)
set SDK_DIR=%ROOT_DIR%..\- SDK -\nesasm

REM Optionally allow override by first argument or NES_SDK env
if not "%1"=="" if not "%1"=="watch" set SDK_DIR=%1
if not "%NES_SDK%"=="" set SDK_DIR=%NES_SDK% 

REM Fail if SDK directory does not exist
if not exist "%SDK_DIR%" (
  echo Error: SDK directory not found: %SDK_DIR%
  exit /b 5
)

if not exist "%PROJECT_DIR%" (
  echo Error: project directory not found: %PROJECT_DIR%
  exit /b 3
)
if not exist "%SDK_DIR%" (
  echo Error: SDK directory not found. Provide path as first arg or set NES_SDK env.
  exit /b 5
)

REM Prefer asm6, then asm6f, then NESASM3
set EXE=
if exist "%SDK_DIR%\asm6.exe" set EXE=%SDK_DIR%\asm6.exe
if "%EXE%"=="" if exist "%SDK_DIR%\asm6f.exe" set EXE=%SDK_DIR%\asm6f.exe
if "%EXE%"=="" if exist "%SDK_DIR%\NESASM3.exe" set EXE=%SDK_DIR%\NESASM3.exe
if "%EXE%"=="" if exist "%SDK_DIR%\build\nesasm.exe" set EXE=%SDK_DIR%\build\nesasm.exe

if "%EXE%"=="" (
  echo Error: no assembler available in %SDK_DIR%
  exit /b 6
)

cd /d "%PROJECT_DIR%"
if not exist "main.asm" (
  echo Error: main.asm not found in %PROJECT_DIR%
  exit /b 4
)

REM Palette conversion
if exist "pal\palettes.pal" (
  echo Converting pal\palettes.pal -> pal\palettes.asm
  python tools\convert_palette.py
)

REM Map conversion
if exist "map\level_001.map" (
  echo Converting map\level_001.map -> map\level_001.asm
  python tools\convert_map.py
)

REM Assemble
echo Assembling...
"%EXE%" main.asm "%ROOT_DIR%%PROJECT_NAME%.nes"

REM Move debug symbols if produced
if exist "main.fns" move /Y "main.fns" "%ROOT_DIR%\%PROJECT_NAME%.fns"

REM Open .nes file
if exist "%ROOT_DIR%\%PROJECT_NAME%.nes" start "" "%ROOT_DIR%\%PROJECT_NAME%.nes"

echo Build complete. Outputs (if produced): %ROOT_DIR%\%PROJECT_NAME%.nes %ROOT_DIR%\%PROJECT_NAME%.fns


REM === Watch mode ===
REM Set WATCH=1 to enable, or pass 'watch' as first arg
set WATCH=0
if "%1"=="watch" set WATCH=1
if "%WATCH%"=="1" goto watch_loop

goto :eof

:watch_loop
echo [Watch mode enabled: monitoring .asm and .chr files for changes]
REM Initial build
call :build
REM Store initial timestamps
call :get_file_times
set "LAST_TIMES=%FILE_TIMES%"

:watch_repeat
timeout /t 2 >nul
call :get_file_times
if not "%FILE_TIMES%"=="%LAST_TIMES%" (
  echo [Change detected — rebuilding...]
  set "LAST_TIMES=%FILE_TIMES%"
  call :build
)
goto watch_repeat

:get_file_times
REM Concatenate timestamps of all .asm and .chr files
setlocal enabledelayedexpansion
set "FILE_TIMES="
for %%F in (*.asm asm\*.asm asm\*.chr) do (
  for %%T in (%%~tF) do set "FILE_TIMES=!FILE_TIMES! %%T"
)
endlocal & set "FILE_TIMES=%FILE_TIMES%"
goto :eof

:build
REM Palette conversion
if exist "pal\palettes.pal" (
  echo Converting pal\palettes.pal -> pal\palettes.asm
  python tools\convert_palette.py
)

REM Map conversion
if exist "map\level_001.map" (
  echo Converting map\level_001.map -> map\level_001.asm
  python tools\convert_map.py
)

REM Assemble
echo Assembling...
"%EXE%" main.asm "%ROOT_DIR%%PROJECT_NAME%.nes"

REM Move debug symbols if produced
if exist "main.fns" move /Y "main.fns" "%ROOT_DIR%\%PROJECT_NAME%.fns"

REM Open .nes file
if exist "%ROOT_DIR%\%PROJECT_NAME%.nes" start "" "%ROOT_DIR%\%PROJECT_NAME%.nes"

echo Build complete. Outputs (if produced): %ROOT_DIR%\%PROJECT_NAME%.nes %ROOT_DIR%\%PROJECT_NAME%.fns
goto :eof

endlocal
