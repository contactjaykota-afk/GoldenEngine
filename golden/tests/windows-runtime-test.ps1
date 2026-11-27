# Golden Engine — Windows runtime test (run on a GitHub-hosted windows-2022 runner).
#
# Each route is a separate launch. Input is generated INSIDE the game by golden.dev.AutoTest
# (GOLDEN_AUTOTEST=<route>): GitHub-hosted Windows runners do not deliver OS keyboard input to games.
$env:GALLIUM_DRIVER = 'llvmpipe'
function Run-Route([string]$route, [int]$seconds) {
  $script:log = Join-Path $Out "game-$route.log"
  $env:GOLDEN_AUTOTEST = $route
  $script:proc = Start-Process -FilePath (Join-Path $Bin 'Funkin.exe') -WorkingDirectory $Bin -PassThru `
    -RedirectStandardOutput $script:log -RedirectStandardError (Join-Path $Out "game-$route-stderr.log")
  return $script:proc
}

# Route "mods": title -> main menu (keyboard) -> Mod Manager -> Esc back
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

# Route "play": title -> main menu -> Bopeebo (with the Lua test mod enabled)
$p = Run-Route 'play'
Record 'freeplay_opens' (Wait-For 'AUTOTEST  main menu reached' 240) '(route play reached the main menu)'
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
$results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'results.json')
$failed = @($results.Keys | Where-Object { -not $results[$_].ok })
Write-Host "`n$($results.Count - $failed.Count) passed, $($failed.Count) failed"
exit 0   # individual checks are evaluated by the workflow steps
