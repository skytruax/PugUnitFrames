#!/usr/bin/env python3
"""Lists every game function whose answer can come back sealed ("secret") for an addon.

    python3 -I tools/sealed_list.py /path/to/Blizzard_APIDocumentationGenerated > tools/sealed_apis.txt

The source is Blizzard's own generated API documentation (github.com/Gethe/wow-ui-source, branch
`forever`): a function is listed if its entry carries SecretReturns, any SecretWhen... or
SecretIn... flag, or has a return value marked ConditionalSecret. The files are read as text and
nothing in them is run. Widget methods (functions of a script object, not of the global table or
a C_ namespace) are left out: those are reads of state the addon itself put on a widget.

tools/tests/run.py uses the list to check that only FreeUnitFrames/Sealed.lua calls any of them.
"""
import os
import re
import sys

SECRET_FLAG = re.compile(r"^\t\t\t(SecretReturns|SecretWhen\w+|SecretIn\w+|SecretOn\w+) = true,", re.M)
CONDITIONAL = re.compile(r"ConditionalSecret(Contents)? = true")


def main():
    docs = sys.argv[1]
    names = set()
    for filename in sorted(os.listdir(docs)):
        if not filename.endswith(".lua"):
            continue
        with open(os.path.join(docs, filename), encoding="utf-8") as handle:
            text = handle.read()
        if re.search(r'^\tType = "ScriptObject"', text, re.M):
            continue
        namespace = re.search(r'^\tNamespace = "([^"]*)"', text, re.M)
        prefix = namespace.group(1) + "." if namespace and namespace.group(1) else ""
        functions = re.search(r"^\tFunctions =\n\t\{\n(.*?)^\t\},", text, re.S | re.M)
        if not functions:
            continue
        for block in re.split(r"^\t\t\{\n", functions.group(1), flags=re.M)[1:]:
            name = re.search(r'^\t\t\tName = "([^"]+)"', block, re.M)
            if not name:
                continue
            returns = block.split("Returns =", 1)[1] if "Returns =" in block else ""
            if SECRET_FLAG.search(block) or CONDITIONAL.search(returns):
                names.add(prefix + name.group(1))
    print("# Game functions whose answer can be sealed for an addon. Made by tools/sealed_list.py from")
    print("# Blizzard's generated API documentation; do not edit by hand.")
    for name in sorted(names):
        print(name)


if __name__ == "__main__":
    main()
