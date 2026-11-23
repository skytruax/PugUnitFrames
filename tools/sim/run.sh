#!/usr/bin/env bash
# Loads Free Unit Frames next to Blizzard's real Forever interface code in the wow-ui-sim
# simulator (https://github.com/Osso/wow-ui-sim), runs tools/sim/tests against it, and takes a
# screenshot.
#
#   tools/sim/lab/build-image.sh     # once: fetch the simulator and build its Docker image
#   tools/sim/run.sh                 # a few seconds; logs in tools/sim/out/
#   tools/sim/run.sh --no-screenshot # any option of lab/run-sim.sh can be passed through
#
# Everything runs in throw-away containers with no network. This script only makes a scratch copy
# of the addon with the test files added, so the folder you ship stays free of them. The scratch
# copy also loads shims.lua first: stand-ins for the few client functions the simulator lacks.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -r "$root/FreeUnitFrames" "$work/FreeUnitFrames"
cp -r "$here/tests" "$work/FreeUnitFrames/tests"
cp "$here/shims.lua" "$work/FreeUnitFrames/SimShims.lua"
# The shims go in front of the addon's first file.
sed -i '0,/^Locale\.lua/s//SimShims.lua\nLocale.lua/' "$work/FreeUnitFrames/FreeUnitFrames.toc"
grep -q '^SimShims\.lua' "$work/FreeUnitFrames/FreeUnitFrames.toc" || { echo "run.sh: could not add the shims to the scratch TOC" >&2; exit 2; }

out="${SIM_OUT:-$here/out}"
mkdir -p "$out"
status=0
# The picture is cut down to where the frames are; a --crop of your own overrides that.
"$here/lab/run-sim.sh" -o "$out" --crop 1090x480+150+410 "$@" "$work/FreeUnitFrames" || status=$?

# Keep the latest picture of a passing run where the README shows it.
if [[ $status -eq 0 && -s "$out/screenshot.png" ]]; then
  cp "$out/screenshot.png" "$root/docs/sim-screenshot.png"
fi
exit "$status"
