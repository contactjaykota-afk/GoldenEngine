# Golden Engine — Windows runtime test (run on a GitHub-hosted windows-2022 runner).
#
# Launches the REAL packaged Funkin.exe with Mesa's software OpenGL (the runner has no GPU), drives it
# with keyboard input, and records each check in results.json (read by separate workflow steps so each
# check is visible as its own pass/fail). Also saves screenshots and the game's stdout log.
#
# Usage: windows-runtime-test.ps1 -Bin <folder with Funkin.exe> -Out <results folder>
param([Parameter(Mandatory = $true)][string]$Bin, [Parameter(Mandatory = $true)][string]$Out)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$shell = New-Object -ComObject WScript.Shell
$log = Join-Path $Out 'game-stdout.log'
$err = Join-Path $Out 'game-stderr.log'
$results = [ordered]@{}

function Save-Shot([string]$name) {
  try {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save((Join-Path $Out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    # Mean brightness on a coarse grid, to detect an all-black frame.
    $sum = 0; $n = 0
    for ($x = 0; $x -lt $b.Width; $x += 40) { for ($y = 0; $y -lt $b.Height; $y += 40) { $c = $bmp.GetPixel($x, $y); $sum += ($c.R + $c.G + $c.B) / 3; $n++ } }
    $g.Dispose(); $bmp.Dispose()
    return [math]::Round($sum / [math]::Max($n, 1), 1)
  } catch { Write-Host "screenshot failed: $_"; return -1 }
}
function Log-Text { if (Test-Path $log) { return (Get-Content $log -Raw -ErrorAction SilentlyContinue) } return '' }
function Wait-For([string]$pattern, [int]$seconds) {
  $end = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $end) { if ((Log-Text) -match $pattern) { return $true }; Start-Sleep -Milliseconds 500 }
  return $false
}
function Send([string]$keys) {
  $null = $shell.AppActivate($script:proc.Id)
  Start-Sleep -Milliseconds 300
  [System.Windows.Forms.SendKeys]::SendWait($keys)
  Start-Sleep -Milliseconds 500
}
function Record([string]$name, [bool]$ok, [string]$detail = '') {
  $results[$name] = @{ ok = $ok; detail = $detail }
  Write-Host ("{0}  {1} {2}" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $name, $detail)
}

# Package contents
$required = @('Funkin.exe', 'assets', 'manifest', 'assets\golden\mod-template\starter\README.md', 'assets\images\mainmenu\mods.png', 'README.txt', 'MODDING.md')
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $Bin $_)) })
Record 'package_contents' ($missing.Count -eq 0) ("missing: " + ($missing -join ', '))
$dlls = @(Get-ChildItem -Path $Bin -Filter *.dll | ForEach-Object Name)
Write-Host "DLLs in package: $($dlls -join ', ')"

# Launch
$env:GALLIUM_DRIVER = 'llvmpipe'
$script:proc = Start-Process -FilePath (Join-Path $Bin 'Funkin.exe') -WorkingDirectory $Bin -PassThru `
  -RedirectStandardOutput $log -RedirectStandardError $err
Start-Sleep -Seconds 5
Record 'process_started' (-not $proc.HasExited) "pid $($proc.Id)"

Record 'golden_engine_started' (Wait-For 'Golden Engine 0\.1\.0' 90) ''
Record 'reached_title' (Wait-For 'TitleState' 180) ''
Record 'renderer_detected' (Wait-For 'GL renderer:' 5) (([regex]::Match((Log-Text), 'GL renderer: [^\r\n]*')).Value)
Start-Sleep -Seconds 20
$m = Save-Shot '01-title'
Record 'title_not_black' ($m -gt 12) "mean=$m"

Send '{ENTER}'; Start-Sleep -Seconds 2; Send '{ENTER}'
Record 'main_menu' (Wait-For 'EnteringMainMenu' 30) ''
Start-Sleep -Seconds 3
$m = Save-Shot '02-main-menu'
Record 'main_menu_not_black' ($m -gt 12) "mean=$m"

Send '{DOWN}'; Send '{DOWN}'; Send '{ENTER}'
Record 'mod_manager_opens' (Wait-For 'Mod Manager opened' 30) ''
Start-Sleep -Seconds 2
$m = Save-Shot '03-mod-manager'
Send '{ESC}'
Record 'back_to_main_menu' (Wait-For '(?s)Mod Manager opened.*EnteringMainMenu' 30) ''

Start-Sleep -Seconds 3
Send '{UP}'; Send '{ENTER}'   # menu remembers "mods" (index 2) -> freeplay is index 1
Record 'freeplay_opens' (Wait-For 'EnteringFreeplay' 30) ''
Start-Sleep -Seconds 4
Send '{DOWN}'; Send '{ENTER}'
Record 'song_started' (Wait-For 'started song at' 90) ''
Start-Sleep -Seconds 6
$m = Save-Shot '04-gameplay'
Record 'gameplay_not_black' ($m -gt 12) "mean=$m"

Start-Sleep -Seconds 5
Record 'still_running' (-not $proc.HasExited) ''
$text = Log-Text
$crash = ([regex]::Matches($text, '(?i)(uncaught|null object reference|critical error)')).Count - ([regex]::Matches($text, '(?i)Enabling .*(uncaught|critical error)')).Count
Record 'no_uncaught_errors' ($crash -le 0) "count=$crash"
if (Test-Path (Join-Path $Bin 'logs')) { Copy-Item -Recurse (Join-Path $Bin 'logs') (Join-Path $Out 'crash-logs') }

if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
$results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'results.json')
$failed = @($results.Keys | Where-Object { -not $results[$_].ok })
Write-Host "`n$($results.Count - $failed.Count) passed, $($failed.Count) failed"
exit 0   # individual checks are evaluated by the workflow steps
