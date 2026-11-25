#!/usr/bin/env python3
"""Test fixture: instantiate the starter template the same way the in-game wizard does.
Usage: make_test_mod.py <mods_dir> <folder> <display name>"""
import json, os, re, shutil, sys

TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mod-template", "starter")
TEXT_EXT = {".json", ".xml", ".hxc", ".md", ".txt", ".lua", ".frag"}

def mod_class(folder):
    parts = re.split(r"[^A-Za-z0-9]+", folder)
    s = "".join(p[:1].upper() + p[1:] for p in parts if p)
    return s if s and s[0].isalpha() else "Mod" + s

def main(mods, folder, name):
    dest = os.path.join(mods, folder)
    if os.path.exists(dest):
        sys.exit(f"refusing to overwrite {dest}")
    rep = {"__MODID__": folder, "__MODCLASS__": mod_class(folder), "__MODNAME__": name}
    for root, _, files in os.walk(TEMPLATE):
        for f in files:
            src = os.path.join(root, f)
            rel = os.path.relpath(src, TEMPLATE)
            for k, v in rep.items():
                rel = rel.replace(k, v)
            out = os.path.join(dest, rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            if os.path.splitext(f)[1] in TEXT_EXT:
                t = open(src, encoding="utf-8").read()
                for k, v in rep.items():
                    t = t.replace(k, v)
                open(out, "w", encoding="utf-8").write(t)
            else:
                shutil.copyfile(src, out)
    json.dump({"title": name, "description": "Test mod", "contributors": [{"name": "Golden Engine tests"}],
               "api_version": "0.8.7", "mod_version": "1.0.0", "license": "CC0-1.0"},
              open(os.path.join(dest, "_polymod_meta.json"), "w"), indent=2)
    # Test-only content so the test can see whether this mod's data registered (not part of the template).
    os.makedirs(os.path.join(dest, "data", "levels"), exist_ok=True)
    json.dump({"version": "1.0.2", "name": name, "titleAsset": "storymenu/titles/week1", "background": "#F9CF51",
               "visible": True, "props": [], "songs": []},
              open(os.path.join(dest, "data", "levels", f"{folder}-week.json"), "w"), indent=2)
    print("created", dest)

if __name__ == "__main__":
    main(*sys.argv[1:4])
