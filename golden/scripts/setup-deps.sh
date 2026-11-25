#!/usr/bin/env bash
# Golden Engine — install the Haxe library dependencies pinned in hmm.json.
# Mirrors upstream .github/actions/setup-haxe, plus a workaround: lib.haxe.org now redirects
# downloads to haxelib-files.haxe.org, which haxelib 4.1 does not follow, so haxelib-hosted
# libraries are fetched with curl first. Requires Haxe 4.3.7 on PATH and git.
# Usage (from the repository root, Linux/macOS or Git Bash on Windows):  golden/scripts/setup-deps.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

haxelib --never --global install haxelib 4.1.0 || true
haxelib --global set haxelib 4.1.0 || true
haxelib --never --global git haxelib https://github.com/FunkinCrew/haxelib.git funkin-patches --skip-dependencies
haxelib --never --global git hmm https://github.com/FunkinCrew/hmm funkin-patches
haxelib --global fixrepo || true
[ -d .haxelib ] || haxelib --never newrepo

dl="$(mktemp -d)"
PYCODE="import json
for d in json.load(open('hmm.json'))['dependencies']:
    if d['type'] == 'haxelib': print(d['name'], d['version'])"
(python3 -c "$PYCODE" 2>/dev/null || python -c "$PYCODE") > "$dl/list.txt"
while read -r name ver; do
  [ -z "$name" ] && continue
  zip="$dl/$name-${ver//./,}.zip"
  curl -sSfL -o "$zip" "https://haxelib-files.haxe.org/files/3.0/$name-${ver//./,}.zip"
  haxelib install "$zip" --skip-dependencies --quiet --never
done < "$dl/list.txt"

haxelib --global run hmm install -q
(cd .haxelib/hxcpp/git/tools/hxcpp && haxe compile.hxml)
haxelib list | sed 's/^/  /'
echo "Dependencies installed."
