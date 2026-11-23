#!/usr/bin/env bash
# Loads Free Unit Frames next to Blizzard's real Forever interface code in the wow-ui-sim
# simulator (https://github.com/Osso/wow-ui-sim), runs tools/sim/tests against it, and takes a
# screenshot.
#
#   tools/sim/lab/build-image.sh     # once: fetch the simulator and build its Docker image
#   tools/sim/run.sh                 # a few seconds; logs in tools/sim/out/
#   tools/sim/run.sh --no-screenshot # any option of lab/run-sim.sh can be passed through
#   SIM_CPUSET=12-15 tools/sim/run.sh  # keep the simulator on these processors
#
# The picture needs Pillow and numpy (tools/sim/scene_art.py) and, the first time, the network:
# the game's icons for the scene come from a public mirror into tools/.icon-cache/.
#
# Everything runs in throw-away containers with no network. This script only makes a scratch copy
# of the addon with the test files added (scratch.sh), so the folder you ship stays free of them.
# The scratch copy also loads shims.lua first: stand-ins for the few client functions the
# simulator lacks. tools/sim/demo.sh renders the moving demo.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
source "$here/scratch.sh"

# The picture: see scratch.sh for what the simulator has to be handed for one.
picture=()
wants_picture=picture
for argument in "$@"; do [[ "$argument" == "--no-screenshot" ]] && wants_picture=""; done
make_scratch "$work" "$wants_picture"
[[ -n "$wants_picture" ]] && picture=("${PICTURE_OPTIONS[@]}" --fonts "$work/simfonts")

out="${SIM_OUT:-$here/out}"
mkdir -p "$out"
status=0
"$here/lab/run-sim.sh" -o "$out" "${picture[@]}" "$@" "$work/FreeUnitFrames" || status=$?

# Keep the latest picture of a passing run where the README shows it.
if [[ $status -eq 0 && -s "$out/screenshot.png" ]]; then
  cp "$out/screenshot.png" "$root/docs/sim-screenshot.png"
fi
exit "$status"
