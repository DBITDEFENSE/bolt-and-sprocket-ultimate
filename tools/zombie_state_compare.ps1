param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string[]]$Cases = @('swipe_l','swipe_r','death_sit','death_back')
)
$ErrorActionPreference = 'Continue'
$zombieProject = Split-Path -Parent $PSScriptRoot
$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
foreach ($case in $Cases) {
    if ($case -notin @('swipe_l','swipe_r','death_sit','death_back')) { throw 'Unknown state case' }
    foreach ($version in @('before','after')) {
        $folder = Join-Path $zombieProject "docs/captures/$version/mocap/states/$case"
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        $captureArgs = @("--case=$case", "--out=$folder", '--capture')
        if ($version -eq 'before') { $captureArgs += '--legacy-zombies' }
        & $Godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --fixed-fps 60 --path $zombieProject res://tools/zombie_state_check.tscn -- @captureArgs *> "$folder/run.log"
        if ($LASTEXITCODE -ne 0) { throw "Capture failed: $version $case" }
        if (Select-String -LiteralPath "$folder/run.log" -Pattern 'SCRIPT ERROR:|^ERROR:|ObjectDB instances leaked|resources still in use' -Quiet) { throw "Engine error in $folder/run.log" }
        $report = Get-Content -LiteralPath "$folder/state.json" -Raw | ConvertFrom-Json
        if ($report.failures.Count -gt 0) { throw 'State acceptance failed' }
        & $ffmpeg -hide_banner -loglevel error -y -framerate 12 -i "$folder/frame_%05d.png" -frames:v 72 -c:v libx264 -pix_fmt yuv420p "$folder.mp4"
        if ($LASTEXITCODE -ne 0) { throw 'Video encoding failed' }
    }
    $before = Join-Path $zombieProject "docs/captures/before/mocap/states/$case.mp4"
    $after = Join-Path $zombieProject "docs/captures/after/mocap/states/$case.mp4"
    $compare = Join-Path $zombieProject "docs/captures/after/mocap/states/${case}_comparison.mp4"
    & $ffmpeg -hide_banner -loglevel error -y -i $before -i $after -filter_complex '[0:v][1:v]hstack=inputs=2' -c:v libx264 -pix_fmt yuv420p $compare
    if ($LASTEXITCODE -ne 0) { throw 'Comparison encoding failed' }
    Write-Output "ZOMBIE_STATE_COMPARE $case complete"
}
