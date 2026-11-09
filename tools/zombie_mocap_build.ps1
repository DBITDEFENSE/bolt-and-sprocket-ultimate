param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$Blender
)
$ErrorActionPreference = 'Stop'
$zombieProject = Split-Path -Parent $PSScriptRoot
$zombieLogDir = Join-Path $zombieProject '.mocap_work/zombies'
New-Item -ItemType Directory -Path $zombieLogDir -Force | Out-Null

& $Blender --background --factory-startup --python-exit-code 1 --python (Join-Path $PSScriptRoot 'blender/zombie_anim_batch.py') -- --root $zombieProject
if ($LASTEXITCODE -ne 0) { throw 'Blender zombie conversion failed' }

# Keep the engine's verbose import progress in local logs.
$ErrorActionPreference = 'Continue' # Windows PowerShell treats native stderr warnings as errors.
& $Godot --headless --audio-driver Dummy --path $zombieProject --import *> (Join-Path $zombieLogDir 'godot_import.log')
if ($LASTEXITCODE -ne 0) { throw 'Initial Godot import failed; inspect .mocap_work/zombies/godot_import.log' }
& $Godot --headless --audio-driver Dummy --path $zombieProject res://tools/zombie_mocap_check.tscn -- --prepare-imports
if ($LASTEXITCODE -ne 0) { throw 'Zombie import preset setup failed' }
& $Godot --headless --audio-driver Dummy --path $zombieProject --import *> (Join-Path $zombieLogDir 'godot_presets.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot preset import failed; inspect .mocap_work/zombies/godot_presets.log' }
& $Godot --headless --audio-driver Dummy --path $zombieProject res://tools/zombie_mocap_check.tscn
if ($LASTEXITCODE -ne 0) { throw 'Zombie GLB checks failed' }
