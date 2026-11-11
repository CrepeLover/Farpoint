@echo off
rem Starts Farpoint with the saved settings and no settings window (for launching from Steam / SteamVR in the headset).
rem Run "Play Farpoint.bat" on the desktop to change controls, resolution or FOV; its choices are saved.
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0pc-vr\launch-farpoint.ps1" -NoGui
