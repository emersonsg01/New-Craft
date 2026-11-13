@echo off
rem Servidor dedicado do New Craft (sem tela). Porta padrao 7777.
rem Uso: Servidor.bat [porta] [semente]
set VK_LOADER_LAYERS_DISABLE=~implicit~
set GODOT="F:\DOWNLOADS\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
set PORT=%1
if "%PORT%"=="" set PORT=7777
set SEED=%2
if "%SEED%"=="" (
	%GODOT% --headless --path "%~dp0." --script res://scripts/dedicated_server.gd -- --port=%PORT%
) else (
	%GODOT% --headless --path "%~dp0." --script res://scripts/dedicated_server.gd -- --port=%PORT% --seed=%SEED%
)
