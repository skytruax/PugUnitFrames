#!/usr/bin/env bash
# Draws the fight over pictures of your own. Each picture in a folder takes the painted city's
# place as the world behind the frames; the frames themselves are drawn by the addon's own code
# in the simulator, as in tools/sim/run.sh.
#
#   tools/sim/photos.sh [FOLDER]         # default: tools/sim/backdrops/ (git-ignored)
#   SIM_CPUSET=12-15 tools/sim/photos.sh # keep the simulator on these processors
#
# Writes tools/sim/out/photos/<name>.png (git-ignored), each with a line across its foot that
# says what it is: a composite, not a screenshot. That line is not optional. CurseForge asks for
# "a clear and visible disclaimer" on a showcase image that may misrepresent what the addon looks
# like, and a picture of the game with these frames on it is exactly what a screenshot looks like.
#
# Whose the pictures are is yours to answer before one is published: a screenshot you took is
# yours to show; anyone else's needs their leave, Blizzard's own promotional pictures included.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
folder="${1:-$here/backdrops}"
[[ -d "$folder" ]] || { echo "photos.sh: no folder $folder" >&2; exit 2; }

shopt -s nullglob nocaseglob
pictures=("$folder"/*.jpg "$folder"/*.jpeg "$folder"/*.png "$folder"/*.webp)
shopt -u nocaseglob
[[ ${#pictures[@]} -gt 0 ]] || { echo "photos.sh: no pictures (jpg, png, webp) in $folder" >&2; exit 2; }

out="${SIM_OUT:-$here/out}/photos"
mkdir -p "$out"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
source "$here/scratch.sh"

for picture in "${pictures[@]}"; do
  name="$(basename "${picture%.*}")"
  rm -rf "$work/one"; mkdir -p "$work/one"
  make_scratch "$work/one" picture "$picture" >/dev/null
  "$here/lab/run-sim.sh" -o "$work/run" --no-tests "${PICTURE_OPTIONS[@]}" --fonts "$work/one/simfonts" "$work/one/PugUnitFrames" | tail -1
  [[ -s "$work/run/screenshot.png" ]] || { echo "photos.sh: no picture for $name" >&2; exit 1; }
  python3 "$here/photo_note.py" "$work/run/screenshot.png" "$out/$name.png"
done
