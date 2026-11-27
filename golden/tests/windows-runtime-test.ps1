# Golden Engine — Windows runtime test (run on a GitHub-hosted windows-2022 runner).
#
# Launches the REAL packaged Funkin.exe with Mesa's software OpenGL (the runner has no GPU). The runner
# does not deliver OS keyboard input to games, so input is generated INSIDE the game by golden.dev.AutoTest
# (environment variable GOLDEN_AUTOTEST=<route>), which dispatches real OpenFL keyboard events.
# Each route is a separate launch. Every check goes into results.json; the workflow turns each into
# its own step. Screenshots and the game logs are saved next to it.
#
# Usage: windows-runtime-test.ps1 -Bin <folder with Funkin.exe> -Out <results folder>
param([Parameter(Mandatory = $true)][string]$Bin, [Parameter(Mandatory = $true)][string]$Out)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$results = [ordered]@{}
$script:log = Join-Path $Out 'game.log'

function Save-Shot([string]$name) {
  try {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save((Join-Path $Out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $sum = 0; $n = 0
    for ($x = 0; $x -lt $b.Width; $x += 40) { for ($y = 0; $y -lt $b.Height; $y += 40) { $c = $bmp.GetPixel($x, $y); $sum += ($c.R + $c.G + $c.B) / 3; $n++ } }
    $g.Dispose(); $bmp.Dispose()
    return [math]::Round($sum / [math]::Max($n, 1), 1)
  } catch { Write-Host "screenshot failed: $_"; return -1 }
}
# Game log text with ANSI colour codes removed (the game's logger colours its labels).
function Log-Text { if (Test-Path $script:log) { return ((Get-Content $script:log -Raw -ErrorAction SilentlyContinue) -replace "\x1b\[[0-9;]*m", '') } return '' }
function Wait-For([string]$pattern, [int]$seconds) {
  $end = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $end) { if ((Log-Text) -match $pattern) { return $true }; Start-Sleep -Milliseconds 500 }
  return $false
}
function Record([string]$name, [bool]$ok, [string]$detail = '') {
  $results[$name] = @{ ok = $ok; detail = $detail }
  Write-Host ("{0}  {1} {2}" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $name, $detail)
}
function Run-Route([string]$route) {
  $script:log = Join-Path $Out "game-$route.log"
  $env:GOLDEN_AUTOTEST = $route
  return Start-Process -FilePath (Join-Path $Bin 'Funkin.exe') -WorkingDirectory $Bin -PassThru `
    -RedirectStandardOutput $script:log -RedirectStandardError (Join-Path $Out "game-$route-stderr.log")
}

# --- Package contents -------------------------------------------------------------------------
$required = @('Funkin.exe', 'assets', 'manifest', 'assets\golden\mod-template\starter\README.md', 'assets\images\mainmenu\mods.png', 'README.txt', 'MODDING.md')
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $Bin $_)) })
Record 'package_contents' ($missing.Count -eq 0) ("missing: " + ($missing -join ', '))
Write-Host "DLLs in package: $((Get-ChildItem -Path $Bin -Filter *.dll | ForEach-Object Name) -join ', ')"

# A throw-away test mod with a Lua script (removed at the end; the release zip never contains it).
$testMod = Join-Path $Bin 'mods\zz-windows-test'
New-Item -ItemType Directory -Force -Path (Join-Path $testMod 'scripts\lua') | Out-Null
'{"title":"Windows Test","api_version":"0.8.7","mod_version":"1.0.0"}' | Set-Content -Encoding ascii (Join-Path $testMod '_polymod_meta.json')
'function onCreate() print("LUAT windows lua ok song=" .. tostring(getSongName())) end' | Set-Content -Encoding ascii (Join-Path $testMod 'scripts\lua\wintest.lua')
$env:GALLIUM_DRIVER = 'llvmpipe'

# --- Route "mods": title -> main menu (keys) -> Mod Manager -> Esc -> still on the main menu -------
$p = Run-Route 'mods'
Start-Sleep -Seconds 5
Record 'process_started' (-not $p.HasExited) "pid $($p.Id)"
Record 'golden_engine_started' (Wait-For 'Golden Engine 0\.1\.0' 90) ''
Record 'reached_title' (Wait-For 'TitleState' 180) ''
Record 'renderer_detected' (Wait-For 'GL renderer:' 5) (([regex]::Match((Log-Text), 'GL renderer: [^\r\n]*')).Value)
Start-Sleep -Seconds 15
$m = Save-Shot '01-title'
Record 'title_not_black' ($m -gt 12) "mean=$m"
Record 'main_menu' (Wait-For 'AUTOTEST  main menu reached' 60) ''
Start-Sleep -Seconds 2
$m = Save-Shot '02-main-menu'
Record 'main_menu_not_black' ($m -gt 12) "mean=$m"
Record 'mod_manager_opens' (Wait-For 'Mod Manager opened' 40) ''
Start-Sleep -Seconds 1
$null = Save-Shot '03-mod-manager'
Record 'back_to_main_menu' (Wait-For 'AUTOTEST  back at main menu' 40) ''
Record 'mods_route_done' (Wait-For 'AUTOTEST  done' 30) ''
$modsText = Log-Text
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
Start-Sleep -Seconds 2

# --- Route "play": title -> main menu -> Bopeebo plays (Lua test mod enabled) --------------------
$p = Run-Route 'play'
Record 'play_route_main_menu' (Wait-For 'AUTOTEST  main menu reached' 240) ''
Record 'song_started' (Wait-For 'started song at' 120) ''
Record 'lua_runs_on_windows' (Wait-For 'LUAT windows lua ok song=bopeebo' 30) ''
Start-Sleep -Seconds 5
$m = Save-Shot '04-gameplay'
Record 'gameplay_not_black' ($m -gt 12) "mean=$m"
Record 'play_route_done' (Wait-For 'AUTOTEST  done' 40) ''
Record 'still_running' (-not $p.HasExited) ''

$text = $modsText + (Log-Text)
$crash = ([regex]::Matches($text, '(?i)(uncaught|null object reference|critical error)')).Count - ([regex]::Matches($text, '(?i)Enabling .*(uncaught|critical error)')).Count
Record 'no_uncaught_errors' ($crash -le 0) "count=$crash"
$autotestFail = ([regex]::Matches($text, 'AUTOTEST  FAILED[^\r\n]*') | ForEach-Object Value) -join ' | '
Record 'no_autotest_failures' ($autotestFail -eq '') $autotestFail

if (Test-Path (Join-Path $Bin 'logs')) { Copy-Item -Recurse (Join-Path $Bin 'logs') (Join-Path $Out 'crash-logs') }
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
Start-Sleep -Seconds 1
Remove-Item -Recurse -Force $testMod -ErrorAction SilentlyContinue
# Echo the important game log lines into the CI output (artifacts need a login to download).
foreach ($f in Get-ChildItem $Out -Filter 'game-*.log') {
  Write-Host "----- $($f.Name) (key lines) -----"
  Get-Content $f.FullName | Select-String -Pattern 'GOLDEN|AUTOTEST|State transition|started song|ERROR|rror|WARN|audio|Audio|OpenAL|TitleState' | Select-Object -First 80 | ForEach-Object { Write-Host $_.Line }
  Write-Host "----- last lines -----"
  Get-Content $f.FullName -Tail 15 | ForEach-Object { Write-Host $_ }
}
$results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'results.json')
$failed = @($results.Keys | Where-Object { -not $results[$_].ok })
Write-Host "`n$($results.Count - $failed.Count) passed, $($failed.Count) failed"
exit 0   # individual checks are evaluated by the workflow steps
