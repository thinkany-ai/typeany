#!/bin/bash
# Makes a built TypeAny.app self-contained: copies librime, its plugins (lua, predict, …) and
# their Homebrew dependencies into Contents/Frameworks, and rewrites every load path to @rpath.
# Release builds need this — users don't have Homebrew's librime, and hardened runtime refuses
# libraries that aren't signed with our team ID (release.sh re-signs everything afterwards).
#
#   ./scripts/bundle-libs.sh .build/TypeAny.app
#
# librime finds plugins next to itself (<dir of librime>/rime-plugins), so they go into
# Contents/Frameworks/rime-plugins.
set -euo pipefail

APP="${1:?usage: $0 path/to/TypeAny.app}"
BREW_PREFIX="$(brew --prefix)"

python3 - "$APP" "$BREW_PREFIX" <<'PY'
import os, shutil, subprocess, sys

app, prefix = sys.argv[1], sys.argv[2]
exe = os.path.join(app, "Contents/MacOS/TypeAny")
fw = os.path.join(app, "Contents/Frameworks")
plugin_dir = os.path.join(fw, "rime-plugins")
brew_plugins = os.path.realpath(os.path.join(prefix, "lib/rime-plugins"))

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout

def references(binary):
    """Install names of the libraries `binary` links against (first line is the file itself)."""
    lines = run("otool", "-L", binary).splitlines()[1:]
    return [l.split()[0] for l in lines]

def is_external(ref):
    return ref.startswith((prefix, "/usr/local", "@rpath/", "@loader_path/"))

def resolve(ref):
    """Real path of a referenced Homebrew library."""
    if ref.startswith(("@rpath/", "@loader_path/")):
        ref = os.path.join(prefix, "lib", os.path.basename(ref))
    return os.path.realpath(ref)

def install_id(path):
    out = run("otool", "-D", path).splitlines()
    return os.path.basename(out[1]) if len(out) > 1 else os.path.basename(path)

# Walk the dependency graph from the executable and every plugin
roots = [exe] + [os.path.join(brew_plugins, f) for f in sorted(os.listdir(brew_plugins)) if f.endswith(".dylib")]
names = {}    # real path → file name in the bundle
queue = list(roots[1:])
for ref in references(exe):
    if is_external(ref):
        queue.append(resolve(ref))
while queue:
    real = os.path.realpath(queue.pop())
    if real in names:
        continue
    names[real] = os.path.basename(real) if real.startswith(brew_plugins) else install_id(real)
    queue += [resolve(r) for r in references(real) if is_external(r)]

os.makedirs(plugin_dir, exist_ok=True)
copied = {}
for real, name in names.items():
    dest = os.path.join(plugin_dir if real.startswith(brew_plugins) else fw, name)
    shutil.copyfile(real, dest)
    os.chmod(dest, 0o755)
    copied[real] = dest

def rpaths(binary):
    out = run("otool", "-l", binary).splitlines()
    return [out[i + 2].split()[1] for i, l in enumerate(out) if "LC_RPATH" in l]

def relink(binary, own_rpath):
    for ref in references(binary):
        if is_external(ref):
            real = resolve(ref)
            if real in names:
                run("install_name_tool", "-change", ref, "@rpath/" + names[real], binary)
    for rp in rpaths(binary):
        if rp.startswith((prefix, "/usr/local")):
            run("install_name_tool", "-delete_rpath", rp, binary)
    if own_rpath not in rpaths(binary):
        run("install_name_tool", "-add_rpath", own_rpath, binary)

for real, dest in copied.items():
    if os.path.dirname(dest) == plugin_dir:
        run("install_name_tool", "-id", "@rpath/rime-plugins/" + names[real], dest)
        relink(dest, "@loader_path/..")
    else:
        run("install_name_tool", "-id", "@rpath/" + names[real], dest)
        relink(dest, "@loader_path")
relink(exe, "@executable_path/../Frameworks")

# Nothing may still point into Homebrew
leftovers = [f"{b}: {r}" for b in [exe] + list(copied.values()) for r in references(b)
             if r.startswith((prefix, "/usr/local"))]
if leftovers:
    sys.exit("still linked to Homebrew:\n" + "\n".join(leftovers))
print(f"Bundled {len(copied)} libraries into {fw}")
PY
