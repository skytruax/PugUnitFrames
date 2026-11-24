# Sourced by run.sh and demo.sh: makes the scratch copy of the addon the simulator loads.
#
#   make_scratch DIR [picture [BACKDROP]]
#
# DIR/PugUnitFrames is the addon with the simulator's test files added and shims.lua loaded in
# front of its first file, so the folder you ship stays free of both. With "picture", scene_art.py
# also puts in what a picture needs and the simulator lacks (the game's icons for the scene's
# spells, its raid marks, a painted city) and fills DIR/simfonts with the addon's own font under
# the names the simulator looks for; tests/sim/screenshot.lua sets the scene. BACKDROP, a picture
# of your own, takes the painted city's place as the world behind the frames.
make_scratch() {
  local work="$1" picture="${2:-}" backdrop="${3:-}"
  local sim root
  sim="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root="$(cd "$sim/../.." && pwd)"
  cp -r "$root/PugUnitFrames" "$work/PugUnitFrames"
  cp -r "$sim/tests" "$work/PugUnitFrames/tests"
  cp "$sim/shims.lua" "$work/PugUnitFrames/SimShims.lua"
  sed -i '0,/^Locale\.lua/s//SimShims.lua\nLocale.lua/' "$work/PugUnitFrames/PugUnitFrames.toc"
  grep -q '^SimShims\.lua' "$work/PugUnitFrames/PugUnitFrames.toc" || { echo "scratch.sh: could not add the shims to the scratch TOC" >&2; return 2; }
  if [[ "$picture" == "picture" ]]; then
    if [[ -n "$backdrop" ]]; then
      python3 "$sim/scene_art.py" "$work/PugUnitFrames/tests/sim/art" "$work/simfonts" "$backdrop"
    else
      python3 "$sim/scene_art.py" "$work/PugUnitFrames/tests/sim/art" "$work/simfonts"
    fi
    echo "SimArt.lua" >> "$work/PugUnitFrames/PugUnitFrames.toc"
  fi
}

# What every picture is drawn with: a 960 x 540 screen at two pixels to the unit.
PICTURE_OPTIONS=(--size 1920x1080 --ui-scale 2)
