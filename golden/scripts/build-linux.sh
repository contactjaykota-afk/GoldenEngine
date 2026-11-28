#!/usr/bin/env bash
# Golden Engine — Linux release build that FAILS when Haxe reports errors (lime's exit code does not).
cd "$(dirname "$0")/../.."
export PATH=/opt/haxe:$PATH HAXE_STD_PATH=${HAXE_STD_PATH:-/opt/haxe/std}
LOG=${BUILD_LOG:-/tmp/golden-build.log}
haxelib run lime build linux -release "$@" > "$LOG" 2>&1
if sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -qE '^ ?ERROR|Error:|error:'; then
  sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -E -A6 '^ ?ERROR|Error:|error:' | head -80
  echo "BUILD FAILED (log: $LOG)"; exit 1
fi
echo "BUILD OK"; tail -3 "$LOG"
