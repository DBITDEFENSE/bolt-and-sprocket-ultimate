@echo off
REM Play.bat: starts CLAUDE ZOMBIES at its main menu (Play / Muster / Archive / Extras / Settings).
REM No cutscene plays here: the story cutscenes play in Campaign, and Extras ^> Cutscenes replays every one.
REM The dev launcher (a button for every map, set-piece and test) is DevLauncher.bat.
REM The game writes its log to logs\game_last.log (and the usual user log folder).
cd /d "%~dp0"
if not exist logs mkdir logs
REM T-258: the renderer prepares frames on its own thread, beside the game (Map 0 round 15 on an RTX 5090: 33 -> 57 FPS,
REM 60 -> 92 with shadows off). "Play.bat safe" starts it the old way (one thread) if anything looks wrong.
set RT=--render-thread separate
if /i "%~1"=="safe" set RT=
start "" "tools\dl_godot\Godot_v4.7.2-stable_win64.exe" --path . %RT% --log-file logs\game_last.log res://gravelight/ui/main_menu.tscn
