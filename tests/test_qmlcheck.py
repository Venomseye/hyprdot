#!/usr/bin/env python3
"""Fault-injection test for tools/qmlcheck.py.

  1. the real tree must produce no errors (no false positives), and
  2. each deliberately broken copy must produce the expected error (no false negatives).

    python3 tests/test_qmlcheck.py
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHECK = ROOT / "tools" / "qmlcheck.py"
TREE = ROOT / "config" / "quickshell"


def run(tree):
    r = subprocess.run([sys.executable, str(CHECK), str(tree)], capture_output=True, text=True)
    return r.returncode, r.stdout


def mutate(tmp, rel, fn):
    p = tmp / rel
    s = p.read_text()
    new = fn(s)
    assert new != s, "mutation did not change %s" % rel
    p.write_text(new)


# name, file, mutation, regex the output must match, severity expected ("error" or "warn")
CASES = [
    ("missing colon (the 'Expected token :' family)", "quick/Tile.qml",
     lambda s: s.replace("radius: 10", "radius 10", 1), r"expected ':' after 'radius'", "error"),
    ("unknown Colors member", "quick/Tile.qml",
     lambda s: s.replace("Colors.primaryContainerOn", "Colors.primaryContainerOnn", 1), r"Colors\.primaryContainerOnn is not defined", "error"),
    ("unknown singleton member", "bar/Media.qml",
     lambda s: s.replace("NowPlaying.togglePlaying()", "NowPlaying.togglePlayin()", 1), r"NowPlaying\.togglePlayin is not defined", "error"),
    ("missing closing brace", "bar/BarIcon.qml",
     lambda s: s.rstrip()[:-1], r"missing '\}'|unexpected end of file", "error"),
    ("stray text inside an object", "bar/BarIcon.qml",
     lambda s: s.replace("    horizontalAlignment", "    garbage here\n    horizontalAlignment", 1), r"expected ':' after 'garbage'|unexpected", "error"),
    ("duplicate id", "bar/MediaButton.qml",
     lambda s: s.replace("id: area", "id: root", 1), r"duplicate id 'root'", "error"),
    ("property named on<Capital> (old Colors.qml bug)", "theme/Colors.qml",
     lambda s: s.replace("property color primary:", "property color onPrimary:", 1), r"on<Capital>", "error"),
    ("import of a directory that does not exist", "bar/Media.qml",
     lambda s: s.replace("import qs.theme", "import qs.nothere", 1), r"import qs\.nothere", "error"),
    ("unbalanced parenthesis in an expression", "bar/Media.qml",
     lambda s: s.replace("Math.max(0,", "Math.max(0,,", 1) if False else s.replace("readonly property int pillHeight: Style.barHeight - 8", "readonly property int pillHeight: (Style.barHeight - 8", 1), r"unclosed bracket|missing '\}'|unbalanced|unexpected end", "error"),
    ("misspelt type", "bar/MediaButton.qml",
     lambda s: s.replace("MouseArea {", "MouseAria {", 1), r"unknown type 'MouseAria'", "warn"),
]


def regression_guards():
    """Bugs that were found by hand and that a structural checker cannot see."""
    bad = []
    import re as _re
    menu = _re.sub(r"//[^\n]*", "", (TREE / "menu" / "MenuPanel.qml").read_text())   # comments may quote the bug
    if "=== item.modelData.node" in menu or "=== modelData.node" in menu:
        bad.append("menu/MenuPanel.qml compares object identity with modelData.node: a JS-array model hands out "
                   "COPIES, so the comparison is always false (the 'press again to confirm' hint never showed). "
                   "Compare a title/key instead.")
    if "item.confirming" not in menu:
        bad.append("menu/MenuPanel.qml lost the confirming state of the power rows")
    return bad


def main():
    for msg in regression_guards():
        print("FAIL  regression guard: " + msg)
        return 1
    print("ok     regression guards (menu confirm state compares by title, not by object identity)")
    code, out = run(TREE)
    failures = []
    if code != 0:
        failures.append("the real tree has errors (false positives):\n" + out)
    for name, rel, fn, pattern, sev in CASES:
        with tempfile.TemporaryDirectory() as d:
            tmp = pathlib.Path(d) / "quickshell"
            shutil.copytree(TREE, tmp)
            try:
                mutate(tmp, rel, fn)
            except AssertionError as e:
                failures.append("%s: test setup is stale (%s)" % (name, e))
                continue
            code, out = run(tmp)
            hit = [l for l in out.splitlines() if re.search(pattern, l) and (": %s:" % sev) in l]
            ok = bool(hit) and (code == 1 if sev == "error" else code == 0)
            print("%-6s %s" % ("ok" if ok else "FAIL", name))
            if not ok:
                failures.append("%s: expected a %s matching /%s/, got:\n%s" % (name, sev, pattern, out))
    if failures:
        print("\n" + "\n".join(failures))
        return 1
    print("\nall %d fault cases detected, real tree clean" % len(CASES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
