# Waits until no game emulator is running (so the compile can't cost frames in the headset),
# builds Farpoint (build-farpoint.cmd), then installs the new exe into C:\Games\Farpoint\pc-vr
# once Farpoint itself isn't running. Keeps the replaced exe as shadps4-before-<time>.exe.
param([string]$Note = 'Local build')
$ErrorActionPreference = 'Stop'
$work = 'C:\Games\farpoint-work'
$installed = 'C:\Games\Farpoint\pc-vr\shadps4.exe'
$built = 'C:\Games\Farpoint-src\build\win-us\shadps4.exe'

while (Get-Process shadps4 -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 15 }
"build started $(Get-Date)"
cmd /c "$work\build-farpoint.cmd" > "$work\build-last.log" 2>&1
if ($LASTEXITCODE -ne 0) { "BUILD FAILED (exit $LASTEXITCODE), see $work\build-last.log"; Get-Content "$work\build-last.log" -Tail 30; exit 1 }
"build finished $(Get-Date)"

while (Get-Process shadps4 -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\Games\Farpoint\*' }) { Start-Sleep -Seconds 15 }
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
Copy-Item $installed "$work\shadps4-before-$stamp.exe" -Force
Copy-Item $built $installed -Force
$hash = (Get-FileHash $installed).Hash.ToLower()
foreach ($b in 'C:\Games\Farpoint\pc-vr\BUILD.txt', 'C:\Games\Farpoint\BUILD.txt') {
    if (Test-Path $b) { Add-Content $b -Value "`r`n$Note`r`nLocal executable SHA256: $hash" }
}
"installed $hash at $(Get-Date); previous exe kept as $work\shadps4-before-$stamp.exe"
