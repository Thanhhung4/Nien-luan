@echo off
setlocal

REM Enables adb reverse tcp:8091 -> tcp:8091 for a connected device.
REM Optional: pass device id as first arg, e.g. enable_adb_reverse_8091.bat R58R31X31MJ

set DEVICE_ID=%1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0enable_adb_reverse_8091.ps1" -DeviceId %DEVICE_ID%

endlocal
