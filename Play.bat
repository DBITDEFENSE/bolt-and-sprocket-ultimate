@echo off
REM Launches the dev launcher: a button for every playable thing (CLAUDE ZOMBIES maps, boss tests,
REM Bolt ^& Sprocket planets, the Update 08 / 09 tests: relief squads, Ledger Lager, the online lobby, a local
REM two-window test lobby, the local web build, the rebuilt Totenhafen and Fernflug acts, the new main menu, the
REM Update 10 set-pieces: spring tide, Letzte Fahrt with bots, the sailing finale, PAUL, the Slender, the air raid,
REM the wing walk, the dust storm, the terminator),
REM a skip-to-round field, god mode, and the bot squad. The full game menu (TERMS ^& CONDITIONS hub) is one
REM button away. Pass --menu to go straight to the hub instead.
cd /d "%~dp0"
if /I "%~1"=="--menu" (
	start "" "tools\dl_godot\Godot_v4.7.2-stable_win64.exe" --path .
) else (
	start "" "tools\dl_godot\Godot_v4.7.2-stable_win64.exe" --path . res://ui/dev_launcher.tscn
)
