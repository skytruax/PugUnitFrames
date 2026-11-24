#!/usr/bin/env bash
# Renders the fight of tests/sim/screenshot.lua moment by moment in the simulator and joins the
# pictures into the moving demo of the README and the store page: docs/demo.gif.
#
#   tools/sim/demo.sh                    # about half a minute a moment
#   SIM_CPUSET=12-15 tools/sim/demo.sh   # keep the simulator on these processors
#
# Every moment is the addon's own code drawing in a fresh simulator; nothing is drawn by hand.
# Needs what tools/sim/run.sh needs for its picture (Pillow, numpy, and once the network).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
MOMENTS=5

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
source "$here/scratch.sh"
make_scratch "$work" picture

out="${SIM_OUT:-$here/out}/demo"
mkdir -p "$out"
pictures=()
for step in $(seq 1 "$MOMENTS"); do
  { echo "PugUnitFramesSimStep = $step"; cat "$here/tests/sim/screenshot.lua"; } > "$work/moment-$step.lua"
  "$here/lab/run-sim.sh" -o "$out/$step" --no-tests "${PICTURE_OPTIONS[@]}" --fonts "$work/simfonts" \
    --scenario "$work/moment-$step.lua" "$work/PugUnitFrames" | tail -2
  [[ -s "$out/$step/screenshot.png" ]] || { echo "demo.sh: moment $step has no picture, see $out/$step" >&2; exit 1; }
  pictures+=("$out/$step/screenshot.png")
done

python3 "$here/demo_gif.py" "$root/docs/demo.gif" "${pictures[@]}"
