@echo off
REM Launches the dev launcher: a button for every playable thing (GRAVELIGHT maps, boss tests,
REM Bolt ^& Sprocket planets), a skip-to-round field, god mode, and the bot squad. The full game menu
REM (TERMS ^& CONDITIONS hub) is one button away. Pass --menu to go straight to the hub instead.
cd /d "%~dp0"
if /I "%~1"=="--menu" (
	start "" "tools\dl_godot\Godot_v4.7.2-stable_win64.exe" --path .
) else (
	start "" "tools\dl_godot\Godot_v4.7.2-stable_win64.exe" --path . res://ui/dev_launcher.tscn
)
