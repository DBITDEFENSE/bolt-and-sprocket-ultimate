@echo off
REM Play.bat: starts CLAUDE ZOMBIES at its main menu (Play / Muster / Archive / Extras / Settings).
REM No cutscene plays here: the story cutscenes play in Campaign, and Extras ^> Cutscenes replays every one.
REM The dev launcher (a button for every map, set-piece and test) is DevLauncher.bat.
REM The game writes its log to logs\game_last.log (and the usual user log folder).
cd /d "%~dp0"
if not exist logs mkdir logs
start "" "tools\dl_godot\Godot_v4.7.2-stable_win64.exe" --path . --log-file logs\game_last.log res://gravelight/ui/main_menu.tscn
