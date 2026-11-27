#!/usr/bin/env bash
# Golden Engine — install every hmm.json dependency into the local .haxelib repo using only GitHub.
# For environments where lib.haxe.org / haxelib-files.haxe.org are unreachable (e.g. restricted CI or
# sandboxes). "git" deps are cloned at their pinned commit; "haxelib" deps are fetched from the
# library's GitHub repository at the matching release tag (mapping below).
# Usage (repo root): golden/scripts/setup-deps-git.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
[ -d .haxelib ] || haxelib --never newrepo >/dev/null 2>&1 || mkdir -p .haxelib
REPO="$PWD/.haxelib"

declare -A GH=(
  [extension-androidtools]=https://github.com/MAJigsaw77/extension-androidtools
  [dox]=https://github.com/HaxeFoundation/dox
  [format]=https://github.com/HaxeFoundation/format
  [svg]=https://github.com/openfl/svg
  [tink_core]=https://github.com/haxetink/tink_core
  [hxdiscord_rpc]=https://github.com/MAJigsaw77/hxdiscord_rpc
  [hxgamemode]=https://github.com/MAJigsaw77/hxgamemode
  [hxp]=https://github.com/openfl/hxp
  [hxvlc]=https://github.com/MAJigsaw77/hxvlc
  [jsonpatch]=https://github.com/EliteMasterEric/jsonpatch
  [jsonpath]=https://github.com/EliteMasterEric/jsonpath
)

install_git() { # name url ref   (haxelib stores "a.b" as "a,b")
  local name=${1//./,} url=$2 ref=$3; local dir="$REPO/$name/git"
  if [ -d "$dir/.git" ] && [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$ref" ]; then echo "ok   $name"; return; fi
  rm -rf "$dir"; mkdir -p "$dir"
  git -C "$dir" init -q && git -C "$dir" remote add origin "$url"
  git -C "$dir" fetch -q --depth 1 origin "$ref" && git -C "$dir" checkout -q FETCH_HEAD
  git -C "$dir" submodule update -q --init --recursive --depth 1 || git -C "$dir" submodule update -q --init --recursive
  printf git > "$REPO/$name/.current"; echo "git  $name@${ref:0:8}"
}

install_tag() { # name version
  local name=${1//./,} ver=$2 url=${GH[$1]:-}; local dir="$REPO/$name/${2//./,}"
  [ -z "$url" ] && { echo "SKIP $name (no GitHub mapping)"; return; }
  if [ -f "$dir/haxelib.json" ]; then echo "ok   $name"; return; fi
  rm -rf "$dir"; local tmp; tmp=$(mktemp -d)
  local t; for t in "$ver" "v$ver"; do
    if git clone -q --depth 1 --branch "$t" "$url" "$tmp/src" 2>/dev/null; then break; fi
  done
  if [ ! -d "$tmp/src" ]; then
    # No release tag: use the newest commit whose haxelib.json declares this version.
    git clone -q "$url" "$tmp/src" || { echo "FAIL $name $ver (clone)"; return 0; }
    local c found=""
    for c in $(git -C "$tmp/src" rev-list HEAD | head -3000); do
      if git -C "$tmp/src" show "$c:haxelib.json" 2>/dev/null | python3 -c "import json,sys; sys.exit(0 if json.load(sys.stdin).get('version')=='$ver' else 1)" 2>/dev/null; then found=$c; break; fi
    done
    [ -n "$found" ] || { echo "FAIL $name $ver (no commit declares this version)"; return 0; }
    git -C "$tmp/src" checkout -q "$found"
  fi
  # Native sources some libraries keep in submodules (hxgamemode, hxdiscord_rpc); test-only ones are skipped.
  git -C "$tmp/src" submodule update -q --init --depth 1 -- $(git -C "$tmp/src" config -f .gitmodules --get-regexp path 2>/dev/null | awk '$2 !~ /^test/ {print $2}') 2>/dev/null || true
  # haxelib.json may live in a subfolder (e.g. haxelib/)
  local root="$tmp/src"; [ -f "$root/haxelib.json" ] || root=$(dirname "$(find "$tmp/src" -maxdepth 3 -name haxelib.json | head -1)")
  mkdir -p "$(dirname "$dir")"; cp -r "$root" "$dir"; rm -rf "$dir/.git" "$tmp"
  find "$dir" -name .git -prune -exec rm -rf {} + 2>/dev/null || true
  printf '%s' "$ver" > "$REPO/$name/.current"; echo "tag  $name@$ver"
}

python3 - <<'PY' > /tmp/ge-deps.txt
import json
for d in json.load(open('hmm.json'))['dependencies']:
    print(d['type'], d['name'], d.get('ref') or d.get('version'), d.get('url',''))
PY
pids=()
while read -r type name ref url; do
  if [ "$type" = git ]; then install_git "$name" "$url" "$ref" & else install_tag "$name" "$ref" & fi
  pids+=($!)
  if [ ${#pids[@]} -ge 6 ]; then wait "${pids[0]}"; pids=("${pids[@]:1}"); fi
done < /tmp/ge-deps.txt
wait
haxelib list
