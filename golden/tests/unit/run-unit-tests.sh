#!/usr/bin/env bash
# Golden Engine — pure-Haxe unit tests (run with the Haxe interpreter; no game build needed).
# Only engine-independent Golden code is tested here; it is copied into a temporary class path so
# the game's global import.hx (which needs Flixel) is not involved.
set -eu
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/golden"
cp -r "$ROOT/source/golden/charting" "$ROOT/source/golden/studio" "$TMP/golden/"
rm -f "$TMP/golden/studio/"*State.hx "$TMP/golden/studio/"*Panel.hx  # engine-dependent files
status=0
for t in MidiTest HighlightTest; do
  echo "== $t"
  haxe -cp "$TMP" -cp "$ROOT/golden/tests/unit" -main "$t" --interp || status=1
done
# PowerShell scripts used by CI must at least parse (skipped where pwsh is not installed).
if command -v pwsh >/dev/null; then
  for ps in "$ROOT"/golden/tests/*.ps1; do
    pwsh -NoProfile -Command "\$e=\$null; [System.Management.Automation.Language.Parser]::ParseFile('$ps',[ref]\$null,[ref]\$e) | Out-Null; if (\$e.Count) { \$e | % { \$_.ToString() }; exit 1 }" && echo "PASS  $(basename "$ps") parses" || { echo "FAIL  $(basename "$ps") does not parse"; status=1; }
  done
fi
exit $status
