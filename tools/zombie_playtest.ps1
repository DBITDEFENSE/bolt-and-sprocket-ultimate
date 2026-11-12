param(
    [ValidateSet('Game','Gallery')][string]$Mode = 'Game',
    [string]$Godot = '',
    [switch]$HeadlessCheck,
    [switch]$Sound
)
$ErrorActionPreference = 'Stop'
$zombieProject = Split-Path -Parent $PSScriptRoot
$config = Get-Content -LiteralPath (Join-Path $zombieProject 'data/gravelight/zombie_mocap.json') -Raw | ConvertFrom-Json
$manifestPath = Join-Path $zombieProject 'assets/zombies/anims/mocap_manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw 'The licensed animation bank is not built in this checkout. Run tools/zombie_mocap_build.ps1 using the owner-supplied Starter pack first.'
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
foreach ($clip in $config.clips) {
    $entry = $manifest.clips.PSObject.Properties[$clip.name]
    if ($null -eq $entry -or -not (Test-Path -LiteralPath (Join-Path $zombieProject "assets/zombies/anims/$($entry.Value.file)"))) {
        throw "Missing converted clip: $($clip.name). Re-run tools/zombie_mocap_build.ps1."
    }
}
if (-not $Godot) {
    $common = & git -C $zombieProject rev-parse --path-format=absolute --git-common-dir
    if ($LASTEXITCODE -ne 0) { throw 'Cannot locate the shared repository tool directory.' }
    $mainCheckout = Split-Path -Parent $common
    $candidates = @($env:GODOT_W, (Join-Path $zombieProject 'tools/dl_godot/Godot_v4.7.2-stable_win64.exe'), (Join-Path $mainCheckout 'tools/dl_godot/Godot_v4.7.2-stable_win64.exe'))
    $Godot = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) { throw 'Pass -Godot with the path to your installed Godot executable; this launcher installs nothing.' }
$zombieLogs = Join-Path $zombieProject '.mocap_work/zombies'
New-Item -ItemType Directory -Force -Path $zombieLogs | Out-Null
$log = Join-Path $zombieLogs "playtest_$($Mode.ToLower()).log"
$scene = if ($Mode -eq 'Gallery') { 'res://tools/zombie_gallery.tscn' } else { 'res://gravelight/ui/main_menu.tscn' }
if ($HeadlessCheck -and $Mode -eq 'Game') { $scene = 'res://tools/zombie_playtest_check.tscn' }
$launchArgs = @('--path', $zombieProject, '--log-file', $log, $scene)
if (-not $Sound) { $launchArgs += @('--audio-driver', 'Dummy') }
if ($HeadlessCheck) {
    $launchArgs += @('--headless', '--quit-after', '900')
} else {
    $launchArgs += @('--position', '80,80', '--resolution', '1280x720')
}
if ($Mode -eq 'Gallery') {
    $seconds = if ($HeadlessCheck) { '3' } else { '600' }
    $launchArgs += @('--', '--horde', '--full-rate', '--near-player', "--seconds=$seconds", '--out=res://.mocap_work/zombies/playtest_gallery')
}
Write-Output "Zombie playtest: $Mode | $($config.clips.Count) licensed clips | $zombieProject"
# Windows GUI executables return immediately when invoked with &, even headless.
$quotedArgs = ($launchArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
if ($HeadlessCheck) {
    Set-Content -LiteralPath $log -Value ''
    $checkProcess = Start-Process -FilePath $Godot -ArgumentList $quotedArgs -WorkingDirectory $zombieProject -WindowStyle Hidden -Wait -PassThru
    $result = $checkProcess.ExitCode
    Get-Content -LiteralPath $log
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|SHADER ERROR:|^ERROR:' -Quiet) { $result = 1 }
    if ($Mode -eq 'Game' -and -not (Select-String -LiteralPath $log -Pattern 'ZOMBIE_PLAYTEST_CHECK.*PASS' -Quiet)) { $result = 1 }
    if ($Mode -eq 'Gallery' -and -not (Select-String -LiteralPath $log -Pattern '\[zombie_gallery\]' -Quiet)) { $result = 1 }
    exit $result
}
# The caller explicitly starts an interactive playtest, so this window is visible.
$process = Start-Process -FilePath $Godot -ArgumentList $quotedArgs -WorkingDirectory $zombieProject -WindowStyle Normal -PassThru
@{ pid = $process.Id; project = $zombieProject; mode = $Mode; log = $log } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $zombieLogs 'playtest_process.json')
Write-Output "Opened PID $($process.Id). Log: $log"
