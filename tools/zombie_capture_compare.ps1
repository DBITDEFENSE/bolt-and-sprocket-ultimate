param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string[]]$Tiers = @('shamble','walk','jog','run','sprint','crawl')
)
$ErrorActionPreference = 'Continue' # Native stderr warnings must not hide the real exit code.
$zombieProject = Split-Path -Parent $PSScriptRoot
$zombieLogs = Join-Path $zombieProject '.mocap_work/zombies'
New-Item -ItemType Directory -Force -Path $zombieLogs | Out-Null
$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
foreach ($tier in $Tiers) {
    if ($tier -notin @('shamble','walk','jog','run','sprint','crawl')) { throw 'Unknown tier' }
    foreach ($version in @('before','after')) {
        $out = "res://docs/captures/$version/mocap_compare/$tier"
        $captureArgs = @('--horde','--full-rate','--count=1',"--tier=$tier",'--kit=soldier','--follow','--capture','--frames','--seconds=6',"--out=$out")
        if ($version -eq 'before') { $captureArgs += '--legacy-zombies' }
        & $Godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --fixed-fps 60 --path $zombieProject res://tools/zombie_gallery.tscn -- @captureArgs *> (Join-Path $zombieLogs "capture_${version}_${tier}.log")
        if ($LASTEXITCODE -ne 0) { throw "Capture failed: $version $tier" }
        $folder = Join-Path $zombieProject "docs/captures/$version/mocap_compare/$tier"
        if (-not (Test-Path -LiteralPath (Join-Path $folder 'horde.json'))) { throw 'Capture has no completion report' }
        & $ffmpeg -hide_banner -loglevel error -y -framerate 12 -i (Join-Path $folder 'horde_frame_%04d.png') -vf 'scale=1280:720' -c:v libx264 -pix_fmt yuv420p "$folder.mp4"
        if ($LASTEXITCODE -ne 0) { throw 'Video encoding failed' }
    }
    $before = Join-Path $zombieProject "docs/captures/before/mocap_compare/$tier.mp4"
    $after = Join-Path $zombieProject "docs/captures/after/mocap_compare/$tier.mp4"
    $compare = Join-Path $zombieProject "docs/captures/after/mocap_compare/${tier}_comparison.mp4"
    $filter = '[0:v][1:v]hstack=inputs=2' # Labels are captured in the gallery; no OS font dependency.
    & $ffmpeg -hide_banner -loglevel error -y -i $before -i $after -filter_complex $filter -c:v libx264 -pix_fmt yuv420p $compare
    if ($LASTEXITCODE -ne 0) { throw 'Comparison encoding failed' }
    Write-Output "ZOMBIE_COMPARE $tier complete"
}
