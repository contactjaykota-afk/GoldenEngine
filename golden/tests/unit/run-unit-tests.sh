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
exit $status
