#!/usr/bin/env python3
r"""Best-effort Lua sanity check, for machines without luac / luajit.

    luasanity.py FILE...

Not a Lua parser. It lexes strings, comments and long brackets correctly, then reports:
  * a string that is not closed on its line, or characters such as \ $ ? that can only be
    the debris of a string that ended too early (the classic over-escaped quote),
  * ( ) { } [ ] that do not balance,
  * a missing comma between two `key = value` entries of a table (a trailing `-- comment`
    that swallowed the comma is the usual cause),
  * block keywords that do not balance (function / if / for / while / do ... end,
    repeat ... until).
A real `luac -p` is better; dot-check uses that when it is installed.
Exit status 0 = nothing found, 1 = problems.
"""
import re
import sys

OPEN = {"(": ")", "{": "}", "[": "]"}
CLOSE = {v: k for k, v in OPEN.items()}


def lex(src):
    """Yield (kind, text, line) with kind in word/op/string; comments dropped."""
    i, n, line = 0, len(src), 1
    out, problems = [], []
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
        elif c in " \t\r":
            i += 1
        elif src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                if j < 0:
                    problems.append((line, "unclosed long comment"))
                    return out, problems
                line += src.count("\n", i, j)
                i = j + len(close)
            else:
                while i < n and src[i] != "\n":
                    i += 1
        elif c in "\"'":
            q, start, j = c, line, i + 1
            while j < n and src[j] != q:
                if src[j] == "\n":
                    problems.append((start, "string is not closed on its line (over-escaped or missing quote?)"))
                    break
                if src[j] == "\\":
                    j += 1
                j += 1
            else:
                out.append(("string", src[i:j + 1], line))
                i = j + 1
                continue
            i = j
        elif c == "[" and re.match(r"\[=*\[", src[i:]):
            m = re.match(r"\[(=*)\[", src[i:])
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            if j < 0:
                problems.append((line, "unclosed long string"))
                return out, problems
            out.append(("string", "[[...]]", line))
            line += src.count("\n", i, j)
            i = j + len(close)
        elif re.match(r"[A-Za-z_]", c):
            m = re.match(r"[A-Za-z_][A-Za-z_0-9]*", src[i:])
            out.append(("word", m.group(), line))
            i += m.end()
        elif c.isdigit():
            m = re.match(r"[0-9][0-9a-zA-Z_.]*", src[i:])
            out.append(("num", m.group(), line))
            i += m.end()
        else:
            if c in "\\$?`!@" and not (c == "!" and src.startswith("!=", i)):
                # never valid Lua outside a string: usually a quote that ended a string too early
                problems.append((line, "stray '%s' outside a string (a string closed too early?)" % c))
            out.append(("op", c, line))
            i += 1
    return out, problems


VALUE_END_WORDS_NOT = {"and", "or", "not", "in", "then", "do", "else", "elseif", "return", "local",
                       "function", "if", "for", "while", "repeat", "until", "end", "nil", "true", "false"}


def missing_commas(toks):
    """Inside a table constructor: `... value` directly followed by `name =` needs a comma."""
    problems, stack = [], []
    pending_do = 0
    for i, (kind, text, line) in enumerate(toks):
        if kind == "op" and text in OPEN:
            stack.append(text)
        elif kind == "op" and text in CLOSE and stack and stack[-1] == CLOSE[text]:
            stack.pop()
        elif kind == "word":
            if text in ("function", "if"):
                stack.append(text)
            elif text in ("for", "while"):
                stack.append(text)
                pending_do += 1
            elif text == "do":
                if pending_do:
                    pending_do -= 1
                else:
                    stack.append(text)
            elif text == "repeat":
                stack.append(text)
            elif text in ("end", "until") and stack and stack[-1] in ("function", "if", "for", "while", "do", "repeat"):
                stack.pop()
        if not stack or stack[-1] != "{" or i == 0 or kind != "word" or text in VALUE_END_WORDS_NOT:
            continue
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        after = toks[i + 2] if i + 2 < len(toks) else None
        if not (nxt and nxt[:2] == ("op", "=") and not (after and after[:2] == ("op", "="))):
            continue
        pk, pt, pl = toks[i - 1]
        if (pk in ("num", "string") or (pk == "op" and pt in ")}]") or
                (pk == "word" and pt not in VALUE_END_WORDS_NOT) or (pk == "word" and pt in ("end", "nil", "true", "false"))):
            problems.append((pl, "missing ',' before '%s =' on line %d (did a trailing comment swallow it?)" % (text, line)))
    return problems


def check(path):
    src = open(path, encoding="utf-8").read()
    toks, problems = lex(src)
    stack = []
    for kind, text, line in toks:
        if kind != "op":
            continue
        if text in OPEN:
            stack.append((text, line))
        elif text in CLOSE:
            if not stack or stack[-1][0] != CLOSE[text]:
                problems.append((line, "unbalanced '%s'" % text))
                break
            stack.pop()
    else:
        if stack:
            problems.append((stack[-1][1], "'%s' is never closed" % stack[-1][0]))

    if not problems:
        problems.extend(missing_commas(toks))

    blocks, pending_do = [], 0
    for kind, text, line in toks:
        if kind != "word":
            continue
        if text in ("function", "if"):
            blocks.append((text, line))
        elif text in ("for", "while"):
            blocks.append((text, line))
            pending_do += 1
        elif text == "do":
            if pending_do:
                pending_do -= 1           # belongs to the for/while just opened
            else:
                blocks.append((text, line))
        elif text == "repeat":
            blocks.append((text, line))
        elif text == "end":
            if not blocks or blocks[-1][0] == "repeat":
                problems.append((line, "'end' without a matching block"))
                break
            blocks.pop()
        elif text == "until":
            if not blocks or blocks[-1][0] != "repeat":
                problems.append((line, "'until' without 'repeat'"))
                break
            blocks.pop()
    else:
        if blocks:
            problems.append((blocks[-1][1], "'%s' block is never closed with 'end'" % blocks[-1][0]))
    return sorted(set(problems))


def main(argv):
    bad = 0
    for path in argv[1:]:
        for line, msg in check(path):
            print("%s:%d: %s" % (path, line, msg))
            bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
