# Synthesizes a batch of SSML jobs to WAV files with the Windows OneCore voices (David, Mark, Zira) via the
# WinRT Windows.Media.SpeechSynthesis API, falling back to System.Speech for voices it can see. Driven by
# gravelight/tools_src/gen_vo.py; not meant to be run by hand.
#
# File output only: WinRT synthesis produces a stream (it has no device output at all) and the System.Speech
# fallback uses SetOutputToWaveFile. Nothing here ever plays through the speakers.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File gen_vo_tts.ps1 -Jobs jobs.json -Result result.json
#   jobs.json:   [{"id": "...", "voice": "Mark", "ssml": "<speak ...>", "wav": "C:\\...\\x.wav"}, ...]
#   result.json: {"ok": ["id", ...], "failed": {"id": "reason", ...}, "engine": "winrt|sapi"}
param(
    [Parameter(Mandatory = $true)][string]$Jobs,
    [Parameter(Mandatory = $true)][string]$Result
)

$ErrorActionPreference = "Stop"
# (a different name from the [string] parameter: assigning to $Jobs would coerce the objects to a string)
$jobList = Get-Content -Raw -Encoding UTF8 $Jobs | ConvertFrom-Json
if ($jobList -isnot [array]) { $jobList = @($jobList) }
$ok = New-Object System.Collections.Generic.List[string]
$failed = @{}
$engine = "winrt"

$winrt = $false
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
    $script:asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
            $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    $winrt = $true
} catch {
    $engine = "sapi"
}

function Await($WinRtTask, $ResultType) {
    $asTask = $script:asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

$synths = @{}
function Get-WinRtSynth([string]$voiceName) {
    if ($synths.ContainsKey($voiceName)) { return $synths[$voiceName] }
    $s = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
    $v = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.DisplayName -like "*$voiceName*" } | Select-Object -First 1
    if ($null -eq $v) { throw "voice '$voiceName' not installed (OneCore)" }
    $s.Voice = $v
    $synths[$voiceName] = $s
    return $s
}

$sapi = $null
function Get-Sapi() {
    if ($null -eq $script:sapi) {
        Add-Type -AssemblyName System.Speech
        $script:sapi = New-Object System.Speech.Synthesis.SpeechSynthesizer
    }
    return $script:sapi
}

function Synth-WinRt($job) {
    $s = Get-WinRtSynth $job.voice
    $stream = Await ($s.SynthesizeSsmlToStreamAsync($job.ssml)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
    $size = [uint32]$stream.Size
    if ($size -lt 100) { throw "empty stream" }
    $dr = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
    $null = Await ($dr.LoadAsync($size)) ([uint32])
    $bytes = New-Object byte[] $size
    $dr.ReadBytes($bytes)
    $dr.Dispose()
    $stream.Dispose()
    [IO.File]::WriteAllBytes($job.wav, $bytes)
}

function Synth-Sapi($job) {
    $s = Get-Sapi
    $v = $s.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Name -like "*$($job.voice)*" } | Select-Object -First 1
    if ($null -eq $v) { throw "voice '$($job.voice)' not installed (SAPI)" }
    $s.SelectVoice($v.VoiceInfo.Name)
    $s.SetOutputToWaveFile($job.wav)
    try { $s.SpeakSsml($job.ssml) } finally { $s.SetOutputToNull() }
}

foreach ($job in $jobList) {
    $dir = Split-Path -Parent $job.wav
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $done = $false
    if ($winrt) {
        try { Synth-WinRt $job; $done = $true } catch { $err = $_.Exception.Message }
    }
    if (-not $done) {
        try { Synth-Sapi $job; $done = $true; $engine = "mixed" } catch { $err = "$err / $($_.Exception.Message)" }
    }
    if ($done) { $ok.Add([string]$job.id) } else { $failed[[string]$job.id] = [string]$err; Write-Output "FAILED $($job.id): $err" }
}

$out = @{ ok = $ok; failed = $failed; engine = $engine }
$json = $out | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText($Result, $json, (New-Object System.Text.UTF8Encoding $false))
