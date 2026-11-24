#!/usr/bin/env python3
"""Runs Pug Unit Frames' tests without the game.

    pip install lupa          # Lua 5.1 embedded in Python
    python3 tools/tests/run.py [name-filter]

Two kinds of test:

  * scenarios (tests.lua): each runs in its own Lua 5.1 state. The stand-in for the client
    (wowmock.lua) is loaded, then the addon's files in .toc order, then the scenario. The
    stand-in seals values the way Blizzard documents the client does, so a scenario fails if the
    addon ever looks at one.
  * checks of the source itself, below: that only Sealed.lua calls a game function whose answer
    can be sealed, that every text has all its translations, that the .toc and the folder agree,
    and that nothing in the repository names the tools it was made with.

Exit status is non-zero if anything fails.
"""
import os
import re
import sys
import xml.etree.ElementTree as ElementTree

from lupa import lua51

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADDON = "PugUnitFrames"
ADDON_DIR = os.path.join(ROOT, ADDON)
SEALED_HOME = "Sealed.lua"  # the one file allowed to call functions whose answer can be sealed


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
        return handle.read()


def toc_files():
    """The files the .toc loads, in order, with forward slashes."""
    files = []
    for line in read(os.path.join(ADDON, ADDON + ".toc")).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(line.replace("\\", "/"))
    return files


def xml_templates(path):
    """The virtual templates an XML file declares: name -> (inherits, clicks, OnLoad source)."""
    namespace = "{http://www.blizzard.com/wow/ui/}"
    templates = {}
    for element in ElementTree.fromstring(read(path)):
        if element.get("virtual") != "true":
            continue
        on_load = element.find("%sScripts/%sOnLoad" % (namespace, namespace))
        clicks = [part.strip() for part in (element.get("registerForClicks") or "").split(",") if part.strip()]
        templates[element.get("name")] = (element.get("inherits"), clicks, on_load.text if on_load is not None else None)
    return templates


def new_state():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    globals_ = lua.globals()
    globals_.ReadFile = read
    load = lua.eval("function(src, name) return assert(loadstring(src, name))() end")
    load(read(os.path.join("tools", "tests", "wowmock.lua")), "@tools/tests/wowmock.lua")

    lua_files = []
    for name in toc_files():
        path = os.path.join(ADDON, name)
        if name.endswith(".xml"):
            for template, (inherits, clicks, on_load) in xml_templates(path).items():
                globals_.Mock.templateParents[template] = inherits
                globals_.Mock.templateScripts[template] = lua.table_from({
                    "OnLoad": on_load,
                    "registerForClicks": lua.table_from(clicks) if clicks else None,
                })
        else:
            lua_files.append(path)
    globals_.ADDON_LUA_FILES = lua.table_from(lua_files)
    load(read(os.path.join("tools", "tests", "tests.lua")), "@tools/tests/tests.lua")
    return lua


# ---------------------------------------------------------------------------
# Checks of the source
# ---------------------------------------------------------------------------
def lua_sources():
    """(file name, source) for every Lua file of the addon."""
    sources = []
    for folder, _dirs, files in os.walk(ADDON_DIR):
        for name in sorted(files):
            if name.endswith(".lua"):
                path = os.path.join(folder, name)
                sources.append((os.path.relpath(path, ADDON_DIR).replace(os.sep, "/"), read(path)))
    return sorted(sources)


def strip_comments_and_strings(source):
    """Lua source with comments and string contents blanked, so names inside them do not count."""
    out = []
    i, n = 0, len(source)
    while i < n:
        two = source[i:i + 2]
        if two == "--":
            block = re.match(r"--\[(=*)\[", source[i:])
            if block:
                end = source.find("]" + block.group(1) + "]", i)
                end = n if end < 0 else end + len(block.group(1)) + 2
            else:
                end = source.find("\n", i)
                end = n if end < 0 else end
            out.append(" " * (end - i))
            i = end
        elif source[i] in "\"'":
            quote = source[i]
            j = i + 1
            while j < n and source[j] != quote:
                j += 2 if source[j] == "\\" else 1
            out.append(quote + " " * (j - i - 1) + quote)
            i = j + 1
        elif two == "[[" or re.match(r"\[=+\[", source[i:]):
            level = re.match(r"\[(=*)\[", source[i:]).group(1)
            end = source.find("]" + level + "]", i)
            end = n if end < 0 else end + len(level) + 2
            out.append(" " * (end - i))
            i = end
        else:
            out.append(source[i])
            i += 1
    return "".join(out)


# Old functions the addon uses that Blizzard's generated documentation does not describe. Whether
# their answers can be sealed is written down nowhere, so they are kept with the ones that can.
UNDOCUMENTED = ["GetNumGroupMembers", "GetReadyCheckStatus", "UnitHasIncomingResurrection"]


def check_sealed_calls_stay_home():
    """Only Sealed.lua may call a game function whose answer can come back sealed."""
    sealed = [line.strip() for line in read(os.path.join("tools", "sealed_apis.txt")).splitlines()
              if line.strip() and not line.startswith("#")]
    assert len(sealed) > 100, "tools/sealed_apis.txt looks empty; rebuild it with tools/sealed_list.py"
    sealed += UNDOCUMENTED
    pattern = re.compile(r"(?<![\w.:])(" + "|".join(re.escape(name) for name in sorted(sealed, key=len, reverse=True)) + r")\s*\(")
    problems = []
    for name, source in lua_sources():
        if name == SEALED_HOME:
            continue
        code = strip_comments_and_strings(source)
        for number, line in enumerate(code.splitlines(), start=1):
            for match in pattern.finditer(line):
                problems.append("%s:%d calls %s" % (name, number, match.group(1)))
    assert not problems, "these belong in %s:\n      %s" % (SEALED_HOME, "\n      ".join(problems))


def texts_used():
    """Every text the addon looks up in L, including the label tables that go through L at run time."""
    used = {}
    for name, source in lua_sources():
        if name == "Locale.lua":
            continue
        for match in re.finditer(r'L\["((?:[^"\\]|\\.)*)"\]', source):
            used.setdefault(match.group(1), name)
    for name, start, end in (("Options.lua", "local SETTING_LABELS", "-- Numbers that are a share"),
                             ("Defaults.lua", "local LABELS = {", "function Defaults.Label")):
        source = dict(lua_sources())[name]
        block = source[source.index(start):source.index(end)]
        for match in re.finditer(r'= "((?:[^"\\]|\\.)*)"', block):
            used.setdefault(match.group(1), name)
    return used


def check_translations_are_complete():
    """Each language has every text, and no text nobody uses."""
    locale = dict(lua_sources())["Locale.lua"]
    used = texts_used()
    # Samples of how a number is written ("4,321", "87%") are the same in every language.
    needed = {text for text in used if re.search(r"[A-Za-z]{2}", text)}
    problems = []
    for language in ("deDE", "esES", "frFR"):
        start = locale.index("translations.%s = {" % language)
        block = locale[start:locale.index("\n}\n", start)]
        have = {match.group(1) for match in re.finditer(r'^\t\["((?:[^"\\]|\\.)*)"\] = ', block, re.M)}
        for text in sorted(needed - have):
            problems.append("%s lacks: %s   (used in %s)" % (language, text, used[text]))
        for text in sorted(have - needed):
            problems.append("%s has a text nothing uses: %s" % (language, text))
    assert not problems, "\n      ".join(problems)


def check_toc_matches_folder():
    """The .toc lists every Lua and XML file of the addon, and nothing that is not there."""
    listed = set(toc_files())
    present = set()
    for folder, _dirs, files in os.walk(ADDON_DIR):
        for name in files:
            if name.endswith((".lua", ".xml")):
                present.add(os.path.relpath(os.path.join(folder, name), ADDON_DIR).replace(os.sep, "/"))
    problems = ["listed in the .toc but missing: " + name for name in sorted(listed - present)]
    problems += ["in the folder but not in the .toc: " + name for name in sorted(present - listed)]
    assert not problems, "\n      ".join(problems)


def check_art_is_all_there():
    """Every texture the code names exists in the Art folder, and nothing in it is unused."""
    named = set()
    for _name, source in lua_sources():
        for match in re.finditer(r'ART \.\. "([\w-]+)"', source):
            named.add(match.group(1))
    icon = re.search(r"Art\\(\w+)", read(os.path.join(ADDON, ADDON + ".toc")))
    if icon:
        named.add(icon.group(1))
    present = {os.path.splitext(name)[0] for name in os.listdir(os.path.join(ADDON_DIR, "Art")) if name.endswith(".tga")}
    problems = ["named in the code but not in Art/: " + name for name in sorted(named - present)]
    problems += ["in Art/ but never used: " + name for name in sorted(present - named)]
    assert not problems, "\n      ".join(problems)


def check_fonts_are_all_there():
    """Every font file the code names ships in Fonts/ with its licence beside it, and no other does."""
    named = set()
    for _name, source in lua_sources():
        for match in re.finditer(r'FONTS \.\. "([\w.-]+)"', source):
            named.add(match.group(1))
    folder = os.path.join(ADDON_DIR, "Fonts")
    present = {name for name in os.listdir(folder) if name.lower().endswith((".ttf", ".otf"))}
    problems = ["named in the code but not in Fonts/: " + name for name in sorted(named - present)]
    problems += ["in Fonts/ but never used: " + name for name in sorted(present - named)]
    for name in sorted(present):
        licence = name.split("-")[0] + "-LICENSE.txt"
        if not os.path.exists(os.path.join(folder, licence)):
            problems.append("%s ships without its licence (%s)" % (name, licence))
    assert named, "the code names no font, so this check has stopped checking"
    assert not problems, "\n      ".join(problems)


def check_events_exist():
    """Every event the addon listens for is one the Forever client sends."""
    reference = os.path.join("tools", "sim", "lab", "dl-wowless-wowf-data", "events.yaml")
    if not os.path.exists(os.path.join(ROOT, reference)):
        raise Skipped("the client's event list has not been fetched (tools/sim/lab/build-image.sh does that)")
    known = set(re.findall(r"^([A-Z][A-Z0-9_]+):", read(reference), re.M))
    not_events = {"ANCHOR_BOTTOMRIGHT"}  # a tooltip anchor, not an event
    problems = []
    for name, source in lua_sources():
        for match in re.finditer(r'"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)"', source):
            if match.group(1) not in known and match.group(1) not in not_events:
                problems.append("%s names %s, which the client does not send" % (name, match.group(1)))
    assert not problems, "\n      ".join(problems)


class Skipped(Exception):
    """A check that could not be made here; said out loud, never counted as a pass."""


def check_no_tool_names():
    """Nothing published says which tools it was written with."""
    words = re.compile("|".join(("clau" + "de", "anthro" + "pic", "co-" + "authored", "chat" + "gpt", "open" + "ai")), re.I)
    problems = []
    for folder, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in (".git", "out", "dl-wowless-wowf-data", "__pycache__", "dist", ".release")]
        for name in files:
            path = os.path.join(folder, name)
            relative = os.path.relpath(path, ROOT)
            if relative.replace(os.sep, "/") == "tools/sim/lab/meta/sim-api-surface.txt":
                continue  # a list of the simulator's function names, not our words
            try:
                with open(path, encoding="utf-8") as handle:
                    text = handle.read()
            except UnicodeDecodeError:
                continue
            for number, line in enumerate(text.splitlines(), start=1):
                if words.search(line):
                    problems.append("%s:%d" % (relative, number))
    assert not problems, "\n      ".join(problems)


CHECKS = [
    ("source: only Sealed.lua reads values that can be sealed", check_sealed_calls_stay_home),
    ("source: every text has all its translations", check_translations_are_complete),
    ("source: the .toc and the folder agree", check_toc_matches_folder),
    ("source: the art the code names is the art that ships", check_art_is_all_there),
    ("source: the font the code names ships, with its licence", check_fonts_are_all_there),
    ("source: every event listened for is one the client sends", check_events_exist),
    ("source: nothing names the tools it was made with", check_no_tool_names),
]


def main():
    wanted = sys.argv[1] if len(sys.argv) > 1 else ""
    failed = ran = skipped = 0

    for name, check in CHECKS:
        if wanted not in name:
            continue
        ran += 1
        try:
            check()
            print("ok    " + name)
        except Skipped as why:
            skipped += 1
            print("SKIP  " + name)
            print("      " + str(why))
        except AssertionError as problem:
            failed += 1
            print("FAIL  " + name)
            print("      " + str(problem))

    names = [test.name for test in new_state().globals().TESTS.values()]
    for index, name in enumerate(names, start=1):
        if wanted not in name:
            continue
        ran += 1
        lua = new_state()
        run = lua.eval("""function(index)
            local ok, err = xpcall(TESTS[index].fn, function(e) return debug.traceback(tostring(e), 2) end)
            if ok and #Mock.luaErrors > 0 then
                ok, err = false, "the addon reported an error to the game:\\n" .. table.concat(Mock.luaErrors, "\\n")
            end
            return ok, err
        end""")
        ok, err = run(index)
        if ok:
            print("ok    " + name)
        else:
            failed += 1
            print("FAIL  " + name)
            print("      " + str(err).replace("\n", "\n      "))
    print("\n%d run, %d failed, %d skipped" % (ran, failed, skipped))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
