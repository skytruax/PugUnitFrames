#!/usr/bin/env bash
# Opens the target's menu the way Blizzard's controller mode does, in the simulator, and checks
# that it stays open with Pug Unit Frames loaded (tools/sim/menu/01_menu.lua says why it would
# not, were the game's target frame simply hidden).
#
#   tools/sim/menu.sh
#   SIM_CPUSET=12-15 tools/sim/menu.sh
#
# It runs apart from tools/sim/run.sh. Opening a menu from a test makes Blizzard's own gamepad
# navigation helper log two errors in the simulator: it insists on being called by the game's
# own code, which a test is not, and the simulator tells it of an attribute being cleared, which
# the game does not. They are Blizzard's code about Blizzard's code and happen with no addon
# loaded as well, so this run allows errors logged while the test runs; run.sh does not.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
source "$here/scratch.sh"
make_scratch "$work"
rm -f "$work/PugUnitFrames/tests/"*.lua
cp "$here/menu/"*.lua "$work/PugUnitFrames/tests/"

out="${SIM_OUT:-$here/out}/menu"
mkdir -p "$out"
"$here/lab/run-sim.sh" -o "$out" --no-screenshot --allow-test-lua-errors "$@" "$work/PugUnitFrames"
