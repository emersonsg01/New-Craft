@echo off
rem Inicia o New Craft.
rem VK_LOADER_LAYERS_DISABLE desliga, so para este jogo, as camadas Vulkan injetadas por
rem outros programas (ReShade, overlay do GOG Galaxy, OBS). O ReShade instalado nesta maquina
rem falha ao carregar e deixa a Godot travada antes de abrir a janela.
set VK_LOADER_LAYERS_DISABLE=~implicit~
set GODOT="F:\DOWNLOADS\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
start "" %GODOT% --path "%~dp0."
