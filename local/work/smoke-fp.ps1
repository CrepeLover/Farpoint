# Smoke / A-B test for Farpoint PC VR (2026-11-10). Runs one emulator build in a separate test install
# (C:\Games\Farpoint-test) with launch-farpoint.ps1's environment and config edits, but on the
# virtual headset (SHADPS4_OPENXR=0: SteamVR is not started), muted, with an input script; takes
# window pictures, closes the window, and summarizes into C:\Games\farpoint-work\runs\<stamp>-<Tag>\.
# The real install's pc-vr folder is only read. Like the launcher it puts the eye-<EyeWidth>.pak
# resolution profile in the game's paks folder as pakchunk99-PCVR_P.pak (the launcher's own
# managed override, rewritten at every launch).
# usage: smoke-fp.ps1 -Tag name [-Exe path] [-Seconds 150] [-Script file] [-EyeWidth 1536] [-Env @{}]
param([Parameter(Mandatory = $true)][string]$Tag,
      [string]$Exe = 'C:\Games\Farpoint\pc-vr\shadps4.exe',
      [int]$Seconds = 150,
      # (us-support has src/input/scripted_input.cpp but nothing starts it; only the ssuvr branch does. So '' :
      # a Farpoint run is boot to the title without input, the same for every build.)
      [string]$Script = '',
      [int]$EyeWidth = 1536,
      [string]$Shots = '40,80,140',
      [hashtable]$Env = @{})
$ErrorActionPreference = 'Stop'
$real = 'C:\Games\Farpoint'
$game = Join-Path $real 'games\CUSA04179\eboot.bin'
$test = 'C:\Games\Farpoint-test'; $pcvr = Join-Path $test 'pc-vr'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path 'C:\Games\farpoint-work\runs' "$stamp-$Tag"
New-Item -ItemType Directory -Force $out | Out-Null
if (Get-Process shadps4 -ErrorAction SilentlyContinue) { throw 'shadps4.exe is already running; not starting another.' }
if (Get-Process vrserver, vrcompositor -ErrorAction SilentlyContinue) { throw 'SteamVR is running (someone may be in the headset); not testing now.' }
function Sha256([string]$path) {
    $sha = [System.Security.Cryptography.SHA256]::Create(); $file = [System.IO.File]::OpenRead($path)
    try { return (($sha.ComputeHash($file) | ForEach-Object { $_.ToString('X2') }) -join '') } finally { $file.Dispose(); $sha.Dispose() }
}

# --- test install: exe under test, a fresh user folder with the launcher's config edits ----------------
if (Test-Path (Join-Path $pcvr 'user')) { Remove-Item -LiteralPath (Join-Path $pcvr 'user') -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $pcvr 'user\log') | Out-Null
# The emulator asks a modal "Save Migration" question whenever it creates user 1000's home folder,
# even with nothing to migrate (user_manager.cpp, upstream too). Folders made beforehand = "Do nothing".
foreach ($id in 1000..1003) { foreach ($sub in 'savedata', 'trophy', 'inputs') {
    New-Item -ItemType Directory -Force (Join-Path $pcvr "user\home\$id\$sub") | Out-Null } }
Copy-Item -LiteralPath $Exe -Destination (Join-Path $pcvr 'shadps4.exe') -Force
$config = Get-Content (Join-Path $real 'pc-vr\user\config.json') -Raw | ConvertFrom-Json
$config.General | Add-Member -NotePropertyName redzone_patches -NotePropertyValue $true -Force
$extra = if ($EyeWidth -ge 3456) { 8192 } elseif ($EyeWidth -ge 3072) { 6144 } elseif ($EyeWidth -ge 2160) { 4096 } elseif ($EyeWidth -ge 1536) { 2048 } else { 0 }
$config.General.extra_dmem_in_mbytes = [Math]::Max([int]$config.General.extra_dmem_in_mbytes, $extra)
$config.Input.use_special_pad = $true; $config.Input.special_pad_class = 9
if (-not $config.PSObject.Properties['Network'] -or $null -eq $config.Network) { $config | Add-Member -NotePropertyName Network -NotePropertyValue ([pscustomobject]@{}) -Force }
$config.Network | Add-Member -NotePropertyName connected_to_network -NotePropertyValue $false -Force
$config.Network | Add-Member -NotePropertyName shad_net_enabled -NotePropertyValue $false -Force
foreach ($name in @('connected_to_network', 'shad_net_enabled')) { if ($config.General.PSObject.Properties[$name]) { $config.General.$name = $false } }
$config | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $pcvr 'user\config.json') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $real "pc-vr\resolution-profiles\eye-$EyeWidth.pak") `
          -Destination (Join-Path (Split-Path $game -Parent) 'refuge\content\paks\pakchunk99-PCVR_P.pak') -Force

# --- environment: launch-farpoint.ps1's, with the virtual headset instead of OpenXR ----------------------
$e = [ordered]@{
    SHADPS4_OPENXR = '0'; SHADPS4_VR = '1'; SDL_AUDIO_DRIVER = 'dummy'
    SHADPS4_VR_FOV = '100'; SHADPS4_VR_FOV_OF = 'headset'; SHADPS4_VR_FOV_SYMMETRIC = '1'
    SHADPS4_XR_WAIT = '0'; SHADPS4_XR_PAUSE = '0'; SHADPS4_XR_GAMEPAD_LAYOUT = '1'; SHADPS4_XR_SWAP_CIRCLE_R3 = '1'
    SHADPS4_XR_SWAP_GRIPS = '1'; SHADPS4_XR_PAD_HAND = 'right'; SHADPS4_XR_TOGGLE_L3 = '1'; SHADPS4_GPU_WAIT_TIMING = '1'
    SHADPS4_SUBMIT_BATCH_SIZE = '32'; SHADPS4_ALLOCATION_TRACE = '1'; SHADPS4_TEXTURE_SOURCE_CAPTURE = ''
    SHADPS4_XR_PAD_PITCH = '-20'; SHADPS4_XR_PAD_OFFSET = '0,0,-0.1778'; SHADPS4_VR_WINDOW_FPS = '30'
    SHADPS4_FARPOINT_OFFLINE_SCORE = '1'; SHADPS4_FARPOINT_EYE_WIDTH = ''
    SHADPS4_TITLE_RESOLUTION = 'title'; SHADPS4_TITLE_EYE_WIDTH = ''; SHADPS4_VR_PACE = '1'; SHADPS4_VR_FPS_CAP = ''
    SHADPS4_INPUT_SCRIPT = ''; SHADPS4_LIVE_INPUT = ''; SHADPS4_XR_TEST_PRESS = ''; SHADPS4_XR_TEST_TURN = ''
}
if ($Script) { $e['SHADPS4_INPUT_SCRIPT'] = (Resolve-Path -LiteralPath $Script).Path }
foreach ($k in $Env.Keys) { $e[$k] = [string]$Env[$k] }
($e.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) | Set-Content (Join-Path $out 'env.txt')
@("Tag=$Tag", "Exe=$Exe", "ExeSHA256=$(Sha256 $Exe)", "EyeWidth=$EyeWidth", "Script=$Script", "Seconds=$Seconds",
  "Started=$(Get-Date -Format o)") | Set-Content (Join-Path $out 'run-info.txt')
$prev = @{}; foreach ($k in $e.Keys) { $prev[$k] = [Environment]::GetEnvironmentVariable($k, 'Process') }
foreach ($k in $e.Keys) { [Environment]::SetEnvironmentVariable($k, $(if ($e[$k] -eq '') { $null } else { $e[$k] }), 'Process') }
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class FpW { [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rr, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags); }
'@
function Shot([System.Diagnostics.Process]$p, [string]$file) {
    $p.Refresh(); $h = $p.MainWindowHandle
    if ($h -eq [IntPtr]::Zero) { return $false }
    $r = New-Object FpW+R; [FpW]::GetWindowRect($h, [ref]$r) | Out-Null
    $w = $r.Rr - $r.L; $hh = $r.B - $r.T
    if ($w -le 50 -or $hh -le 50) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $hh
    $gr = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $gr.GetHdc()
    $ok = [FpW]::PrintWindow($h, $hdc, 2); $gr.ReleaseHdc($hdc)
    if (-not $ok) { $gr.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size) }
    $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $gr.Dispose(); $bmp.Dispose()
    return $true
}
$t0 = Get-Date
try {
    $p = Start-Process -FilePath (Join-Path $pcvr 'shadps4.exe') -ArgumentList @('-g', "`"$game`"") -WorkingDirectory $pcvr -PassThru `
        -RedirectStandardOutput (Join-Path $out 'stdout.txt') -RedirectStandardError (Join-Path $out 'stderr.txt')
} finally { foreach ($k in $prev.Keys) { [Environment]::SetEnvironmentVariable($k, $prev[$k], 'Process') } }
"game pid $($p.Id) for ${Seconds}s -> $out"
$marks = @($Shots -split ',' | ForEach-Object { [int]$_.Trim() }) | Sort-Object -Unique; $taken = @()
while (-not $p.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt $Seconds) {
    Start-Sleep -Seconds 2
    $el = [int]((Get-Date) - $t0).TotalSeconds
    foreach ($m in $marks) { if ($el -ge $m -and $taken -notcontains $m) { $taken += $m; [void](Shot $p (Join-Path $out "shot-$m.png")) } }
}
if ($p.HasExited) { $result = "exited by itself after $([int]((Get-Date) - $t0).TotalSeconds)s, code $($p.ExitCode)" }
else {
    [void]$p.CloseMainWindow()
    if (-not $p.WaitForExit(30000)) { Stop-Process -Id $p.Id -Force; Start-Sleep 2; $result = 'did not close; killed' }
    else { $result = "closed after the run, code $($p.ExitCode)" }
}

# --- summarize ------------------------------------------------------------------------------------
Get-ChildItem -LiteralPath (Join-Path $pcvr 'user\log') -File -ErrorAction SilentlyContinue | Copy-Item -Destination $out
$log = Join-Path $out 'shad_log.txt'
$lines = if (Test-Path $log) { Get-Content -LiteralPath $log } else { @() }
$sum = @("RESULT: $result | log lines $($lines.Count) | $out")
function Marker([string]$name, [string]$pattern) {
    $hits = @($lines | Select-String -Pattern $pattern)
    $first = if ($hits.Count) { ($hits[0].Line -replace '^\[[^\]]*\] <\w+> \([^)]*\) \S+ ', '') } else { '' }
    return ('{0,-22} {1,6}  {2}' -f $name, $hits.Count, $first.Substring(0, [Math]::Min(170, $first.Length)))
}
$sum += '--- feature markers (count, first) ---'
$sum += Marker 'virtual headset' 'virtual headset connected = true|Virtual headset connected'
$sum += Marker 'US tracker ABI' "Farpoint's 144-byte tracker"
$sum += Marker 'AF16' 'Anisotropic filtering raised'
$sum += Marker 'MLAA' 'Headset pictures: MLAA'
$sum += Marker 'redzone patches' '(?i)redzone'
$sum += Marker 'headset fps' 'headset frames so far'
$fps = @($lines | Select-String -Pattern 'headset frames so far, ([\d.]+) per second' | ForEach-Object { [double]$_.Matches[0].Groups[1].Value })
if ($fps.Count) { $m = $fps | Measure-Object -Average -Minimum -Maximum; $sum += ('headset fps: n {0} avg {1:N1} min {2:N1} max {3:N1}' -f $m.Count, $m.Average, $m.Minimum, $m.Maximum) }
$crit = @($lines | Where-Object { $_ -match '<Critical>' })
$err = @($lines | Where-Object { $_ -match '<Error>' })
$sum += "--- Critical: $($crit.Count) ---"; $sum += ($crit | Select-Object -First 20)
$sum += "--- Error: $($err.Count) (distinct, numbers folded) ---"
$sum += ($err | ForEach-Object { ($_ -replace '^\[[^\]]*\] <Error> \([^)]*\) ', '') -replace '0x[0-9a-fA-F]+', 'X' -replace '\d+', 'N' } |
         Group-Object | Sort-Object Count -Descending | Select-Object -First 25 | ForEach-Object { '{0,6} {1}' -f $_.Count, $_.Name })
$sum += '--- last 12 lines ---'; $sum += ($lines | Select-Object -Last 12)
$sum | Set-Content (Join-Path $out 'summary.txt')
$sum
