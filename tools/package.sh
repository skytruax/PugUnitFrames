#!/usr/bin/env bash
# Builds the addon zip into dist/ (git-ignored), the way the release workflow's packager lays it
# out: one PugUnitFrames folder holding the addon and its licence. For trying a build in the game
# before there is a release:
#
#   tools/package.sh          # dist/PugUnitFrames-<version from the .toc>.zip
#
# Unzip it into World of Warcraft/_forever_/Interface/AddOns/.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(sed -n 's/^## Version: *//p' "$root/PugUnitFrames/PugUnitFrames.toc" | tr -d '\r')"
[[ -n "$version" ]] || { echo "package.sh: no version in the .toc" >&2; exit 1; }

out="$root/dist/PugUnitFrames-$version.zip"
mkdir -p "$root/dist"
python3 - "$root" "$out" <<'PY'
import os
import sys
import zipfile

root, out = sys.argv[1], sys.argv[2]
addon = os.path.join(root, "PugUnitFrames")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
    for folder, dirs, files in os.walk(addon):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(folder, name)
            archive.write(path, os.path.join("PugUnitFrames", os.path.relpath(path, addon)))
    archive.write(os.path.join(root, "LICENSE"), os.path.join("PugUnitFrames", "LICENSE"))
    print("%s: %d files" % (os.path.relpath(out, root), len(archive.namelist())))
PY
