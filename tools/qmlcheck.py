#!/usr/bin/env python3
"""Static checker for the Quickshell QML in this repo.

    qmlcheck.py DIR [--known FILE] [--quiet]

Why it exists: Quickshell refuses to start when ANY file fails to parse (no bar, no menu, no
notifications), and `Expected token ':'` style errors only show up after the old shell has
already been stopped. This catches the common ones first. It is NOT a full QML parser - for that
use qmllint / Quickshell itself - but it understands the shape of a QML file well enough to find:

  error   brackets that do not balance, a member that is neither `name: value` nor `Type { }`
          (the "Expected token ':'" family), stray tokens, duplicate `id`s, properties called
          on<Capital> (QML treats them as signal handlers), `import qs.x` for a directory that
          does not exist, Colors.foo / Style.foo / Singleton.foo that is not defined
  warn    a Type that is neither a file of this repo nor in the known Qt/Quickshell type list
          (usually a typo, sometimes just a type the list does not know yet)

Exit status: 0 = no errors (warnings allowed), 1 = errors.
"""
import re
import sys
import pathlib

# ---------------------------------------------------------------------------------- tokenizer

TOKEN_RE = re.compile(r"""
    (?P<ws>[ \t\r\f]+)
  | (?P<nl>\n)
  | (?P<lc>//[^\n]*)
  | (?P<bc>/\*.*?\*/)
  | (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`)
  | (?P<num>\d[\w.]*)
  | (?P<id>[A-Za-z_$][\w$]*)
  | (?P<op>\.\.\.|===|!==|=>|\?\.|\?\?|==|!=|<=|>=|&&|\|\||\+\+|--|\+=|-=|\*=|/=|<<|>>|[-+*/%<>=!&|^~?:.,;(){}\[\]@])
""", re.X | re.S)


class Tok:
    __slots__ = ("kind", "text", "line", "col")

    def __init__(self, kind, text, line, col):
        self.kind, self.text, self.line, self.col = kind, text, line, col


REGEX_RE = re.compile(r"/(?:\\.|\[(?:\\.|[^\]\\\n])*\]|[^/\\\n\[])+/[a-z]*")
REGEX_AFTER = {"(", ",", "=", ":", "[", "{", "}", ";", "!", "&", "|", "?", "+", "-", "*", "%", "<", ">",
               "=>", "&&", "||", "??", "==", "!=", "===", "!==", "<=", ">=", "return", "typeof", "case",
               "in", "of", "void", "delete", "new", "throw"}


def tokenize(src):
    toks, line, line_start, pos = [], 1, 0, 0
    problems = []
    while pos < len(src):
        m = TOKEN_RE.match(src, pos)
        if not m:
            problems.append((line, pos - line_start + 1, "unexpected character %r" % src[pos]))
            pos += 1
            continue
        kind, text = m.lastgroup, m.group()
        if kind == "op" and text == "/" and (not toks or toks[-1].text in REGEX_AFTER):
            rm = REGEX_RE.match(src, pos)
            if rm:
                toks.append(Tok("str", rm.group(), line, pos - line_start + 1))
                pos = rm.end()
                continue
        col = pos - line_start + 1
        if kind in ("nl", "bc", "str", "lc"):
            nls = text.count("\n")
        else:
            nls = 0
        if kind in ("id", "num", "op", "str"):
            toks.append(Tok(kind, text, line, col))
        if kind == "nl":
            line += 1
            line_start = m.end()
        elif nls:
            line += nls
            line_start = pos + text.rfind("\n") + 1
        pos = m.end()
    return toks, problems


# ---------------------------------------------------------------------------------- parser

BINOPS = {"+", "-", "*", "/", "%", "?", ":", ",", ".", "?.", "??", "&&", "||", "==", "!=", "===",
          "!==", "<", ">", "<=", ">=", "=>", "=", "!", "&", "|", "^", "~", "<<", ">>",
          "in", "of", "typeof", "instanceof", "new", "void", "delete"}
LEADING_OPS = {"?", ":", ".", "?.", "+", "-", "*", "/", "%", "&&", "||", "??", "==", "!=", "===",
               "!==", "<", ">", "<=", ">=", ",", ")", "]", "=>", "=", "&", "|", "^", "instanceof", "in"}
MODIFIERS = {"default", "readonly", "required"}


class Fail(Exception):
    pass


class Parser:
    def __init__(self, toks, path):
        self.t = toks
        self.i = 0
        self.path = path
        self.errors = []          # (line, col, message)
        self.ids = []             # (name, line)
        self.types = []           # (name, line, col)
        self.props = []           # (name, line, col)
        self.imports = []         # (kind, text, line)

    # -- helpers
    def peek(self, k=0):
        j = self.i + k
        return self.t[j] if j < len(self.t) else None

    def next(self):
        tok = self.peek()
        self.i += 1
        return tok

    def fail(self, tok, msg):
        if tok is None:
            last = self.t[-1] if self.t else None
            line, col = (last.line, last.col) if last else (1, 1)
            raise Fail((line, col, msg + " (unexpected end of file)"))
        raise Fail((tok.line, tok.col, msg))

    def expect(self, text, what=None):
        tok = self.peek()
        if tok is None or tok.text != text:
            self.fail(tok, "expected '%s'%s" % (text, (" " + what) if what else ""))
        return self.next()

    def skip_balanced(self):
        """At an opening bracket: consume through its match."""
        pairs = {"(": ")", "[": "]", "{": "}"}
        stack = []
        while True:
            tok = self.next()
            if tok is None:
                self.fail(None, "unclosed bracket")
            if tok.text in pairs and tok.kind == "op":
                stack.append((pairs[tok.text], tok))
            elif tok.text in (")", "]", "}") and tok.kind == "op":
                if not stack or stack[-1][0] != tok.text:
                    self.fail(tok, "unbalanced '%s'" % tok.text)
                stack.pop()
                if not stack:
                    return

    # -- document
    def parse_document(self):
        while True:
            tok = self.peek()
            if tok is not None and tok.kind == "id" and tok.text in ("pragma", "import"):
                line = tok.line
                self.next()
                parts = []
                while self.peek() is not None and self.peek().line == line:
                    parts.append(self.next())
                if tok.text == "import":
                    self.imports.append((parts, line))
            else:
                break
        if self.peek() is None:
            self.fail(None, "no root object")
        self.parse_object_def()
        if self.peek() is not None:
            self.fail(self.peek(), "unexpected '%s' after the root object" % self.peek().text)

    def dotted(self):
        tok = self.peek()
        if tok is None or tok.kind != "id":
            self.fail(tok, "expected a name")
        parts = [self.next()]
        while self.peek() is not None and self.peek().text == "." and self.peek(1) is not None and self.peek(1).kind == "id":
            self.next()
            parts.append(self.next())
        return parts

    def parse_object_def(self):
        parts = self.dotted()
        name = ".".join(p.text for p in parts)
        self.types.append((name, parts[0].line, parts[0].col))
        if self.peek() is not None and self.peek().text == "on" and self.peek(1) is not None and self.peek(1).kind == "id":
            self.next()
            self.dotted()
        self.expect("{", "after '%s'" % name)
        self.parse_body()

    def parse_body(self):
        while True:
            tok = self.peek()
            if tok is None:
                self.fail(None, "missing '}'")
            if tok.text == "}":
                self.next()
                return
            if tok.text == ";":
                self.next()
                continue
            self.parse_member()

    # -- members
    def parse_member(self):
        tok = self.peek()
        if tok.kind != "id":
            self.fail(tok, "unexpected '%s' (expected a property, a child object or a function)" % tok.text)
        w = tok.text
        nxt = self.peek(1)

        if w == "id" and nxt is not None and nxt.text == ":":
            self.next(); self.next()
            name = self.peek()
            if name is None or name.kind != "id":
                self.fail(name, "expected a name after 'id:'")
            self.next()
            self.ids.append((name.text, name.line))
            return
        is_binding = nxt is not None and nxt.text == ":"
        if (w in MODIFIERS or w == "property") and not is_binding:
            return self.parse_property()
        if w == "signal" and not is_binding:
            self.next()
            self.dotted()
            if self.peek() is not None and self.peek().text == "(":
                self.skip_balanced()
            return
        if w == "function" and not is_binding:
            self.next()
            self.dotted()
            self.expect("(", "after the function name")
            self.i -= 1
            self.skip_balanced()
            if self.peek() is not None and self.peek().text == ":":
                self.next()
                self.dotted()
            if self.peek() is None or self.peek().text != "{":
                self.fail(self.peek(), "expected '{' for the function body")
            self.skip_balanced()
            return
        if w == "component" and not is_binding and nxt is not None and nxt.kind == "id":
            self.next(); self.next()
            self.expect(":", "after the component name")
            self.parse_object_def()
            return
        if w == "enum" and not is_binding and nxt is not None and nxt.kind == "id":
            self.next(); self.next()
            self.skip_balanced() if self.peek() is not None and self.peek().text == "{" else None
            return

        parts = self.dotted()
        name = ".".join(p.text for p in parts)
        after = self.peek()
        if after is not None and after.text == ":":
            self.next()
            self.parse_value()
        elif after is not None and after.text == "{":
            # a child object (Rectangle { }) or a grouped property (anchors { })
            self.next()
            self.types.append((name, parts[0].line, parts[0].col))
            self.parse_body()
        elif after is not None and after.text == "on" and self.peek(1) is not None and self.peek(1).kind == "id":
            self.next()
            self.dotted()
            self.types.append((name, parts[0].line, parts[0].col))
            self.expect("{", "after 'on <property>'")
            self.parse_body()
        else:
            # the classic "Expected token ':'"
            self.fail(after if after is not None else tok,
                      "expected ':' after '%s' (or '{' if it is a child object)" % name)

    def parse_property(self):
        while self.peek() is not None and self.peek().text in MODIFIERS:
            self.next()
        self.expect("property")
        ty = self.peek()
        if ty is None or ty.kind != "id":
            self.fail(ty, "expected a type after 'property'")
        self.next()
        if self.peek() is not None and self.peek().text == "<":
            self.skip_angle()
        name = self.peek()
        if name is None or name.kind != "id":
            self.fail(name, "expected a property name")
        self.next()
        # alias: `property alias foo: a.b` - 'alias' was taken as the type, so name is next
        self.props.append((name.text, name.line, name.col))
        if self.peek() is not None and self.peek().text == ":":
            self.next()
            self.parse_value()

    def skip_angle(self):
        depth = 0
        while True:
            tok = self.next()
            if tok is None:
                self.fail(None, "unclosed '<'")
            if tok.text == "<":
                depth += 1
            elif tok.text == ">":
                depth -= 1
                if depth == 0:
                    return

    # -- values
    def parse_value(self):
        tok = self.peek()
        if tok is None:
            self.fail(None, "missing value")
        if tok.text == "{":
            self.skip_balanced()           # a JS block: `onClicked: { ... }`
            return
        if tok.kind == "id" and tok.text[0].isupper():
            # `contentItem: Rectangle { ... }` vs an expression such as `Colors.primary`
            j = self.i
            self.next()
            while self.peek() is not None and self.peek().text == "." and self.peek(1) is not None and self.peek(1).kind == "id":
                self.next(); self.next()
            is_obj = self.peek() is not None and self.peek().text in ("{",) and self.peek().line >= tok.line
            is_on = self.peek() is not None and self.peek().text == "on" and self.peek(1) is not None and self.peek(1).kind == "id"
            self.i = j
            if is_obj or is_on:
                self.parse_object_def()
                return
        self.parse_expression()

    def parse_expression(self):
        depth = 0
        prev = None
        while True:
            tok = self.peek()
            if tok is None:
                break
            if depth == 0:
                if tok.text == ";" or tok.text == "}":
                    break
                if prev is not None and tok.line > prev.line:
                    if prev.text not in BINOPS and tok.text not in LEADING_OPS:
                        break
            if tok.kind == "op" and tok.text in "([{":
                depth += 1
            elif tok.kind == "op" and tok.text in ")]}":
                depth -= 1
                if depth < 0:
                    self.fail(tok, "unbalanced '%s'" % tok.text)
            prev = self.next()
        if depth != 0:
            self.fail(None, "unclosed bracket in a value")
        if prev is None:
            self.fail(self.peek(), "missing value after ':'")


# ---------------------------------------------------------------------------------- checks

OBJECT_MEMBERS = {"objectName", "destroy", "parent", "children", "data", "toString", "valueOf",
                  "objectNameChanged", "destroyed", "deleteLater"}


def singleton_members(path):
    src = path.read_text()
    toks, _ = tokenize(src)
    p = Parser(toks, path)
    try:
        p.parse_document()
    except Fail:
        pass
    names = {n for n, _, _ in p.props}
    for m in re.finditer(r"\bfunction\s+(\w+)", src):
        names.add(m.group(1))
    for m in re.finditer(r"\bsignal\s+(\w+)", src):
        names.add(m.group(1))
    # every `property foo` also has a `fooChanged` signal
    names |= {n + "Changed" for n in list(names)}
    return names | OBJECT_MEMBERS


def check_tree(root, known_types):
    root = pathlib.Path(root)
    files = sorted(root.rglob("*.qml"))
    problems = []          # (severity, path, line, col, message)

    local_types = {f.stem for f in files}
    dirs = {d.name for d in root.iterdir() if d.is_dir()}
    singletons = {}
    for f in files:
        head = f.read_text()[:400]
        if "pragma Singleton" in head:
            singletons[f.stem] = f

    members = {name: singleton_members(path) for name, path in singletons.items()}

    for f in files:
        rel = f.relative_to(root)
        src = f.read_text()
        toks, tok_problems = tokenize(src)
        for line, col, msg in tok_problems:
            problems.append(("error", rel, line, col, msg))
        p = Parser(toks, rel)
        try:
            p.parse_document()
        except Fail as e:
            line, col, msg = e.args[0]
            problems.append(("error", rel, line, col, msg))
            continue                      # the rest of the checks need a clean parse

        seen = {}
        for name, line in p.ids:
            if name in seen:
                problems.append(("error", rel, line, 1, "duplicate id '%s' (first used on line %d)" % (name, seen[name])))
            seen.setdefault(name, line)

        for name, line, col in p.props:
            if re.match(r"^on[A-Z]", name):
                problems.append(("error", rel, line, col,
                                 "property '%s': QML treats on<Capital> names as signal handlers "
                                 "(\"Cannot assign a value to a signal\") - rename it" % name))

        for parts, line in p.imports:
            text = "".join(t.text for t in parts)
            m = re.match(r"qs\.(\w+)", text)
            if m and m.group(1) not in dirs:
                problems.append(("error", rel, line, 1, "import qs.%s: no such directory in this config" % m.group(1)))
            m = re.match(r'"([^"]+)"', parts[0].text) if parts else None
            if parts and parts[0].kind == "str":
                target = f.parent / parts[0].text.strip("\"'")
                if not target.exists():
                    problems.append(("error", rel, line, 1, "import %s: file not found" % parts[0].text))

        for name, line, col in p.types:
            base = name.split(".")[0]
            if not base[0].isupper():
                continue                          # grouped property such as `anchors { }`
            if base in local_types or base in known_types or name in known_types:
                continue
            problems.append(("warn", rel, line, col, "unknown type '%s' (typo, a missing import, or a type missing from tools/qml-known-types.txt)" % name))

        stripped = re.sub(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', '""', re.sub(r"//[^\n]*|/\*.*?\*/", "", src, flags=re.S))
        for sname, names in members.items():
            if f.stem == sname:
                continue
            for m in re.finditer(r"(?<![\w.])" + re.escape(sname) + r"\.(\w+)", stripped):
                if m.group(1) not in names:
                    line = stripped.count("\n", 0, m.start()) + 1
                    problems.append(("error", rel, line, 1, "%s.%s is not defined in %s" % (sname, m.group(1), singletons[sname].relative_to(root))))
    return problems, len(files)


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    quiet = "--quiet" in argv
    known_file = None
    if "--known" in argv:
        known_file = argv[argv.index("--known") + 1]
        args = [a for a in args if a != known_file]
    if not args:
        print(__doc__)
        return 2
    known = set()
    kf = pathlib.Path(known_file) if known_file else pathlib.Path(__file__).with_name("qml-known-types.txt")
    if kf.exists():
        known = {l.strip() for l in kf.read_text().splitlines() if l.strip() and not l.startswith("#")}
    if "--list-types" in argv:
        # helper used to (re)generate qml-known-types.txt from a tree known to load
        root = pathlib.Path(args[0])
        local = {f.stem for f in root.rglob("*.qml")}
        out = set()
        for f in root.rglob("*.qml"):
            toks, _ = tokenize(f.read_text())
            p = Parser(toks, f)
            try:
                p.parse_document()
            except Fail:
                continue
            for name, _, _ in p.types:
                if name[0].isupper() and name.split(".")[0] not in local:
                    out.add(name)
        print("\n".join(sorted(out)))
        return 0
    problems, n = check_tree(args[0], known)
    errors = [x for x in problems if x[0] == "error"]
    warns = [x for x in problems if x[0] == "warn"]
    for sev, path, line, col, msg in sorted(problems, key=lambda x: (x[0] != "error", str(x[1]), x[2])):
        if sev == "warn" and quiet:
            continue
        print("%s:%d:%d: %s: %s" % (path, line, col, sev, msg))
    print("qml: %d file(s), %d error(s), %d warning(s)" % (n, len(errors), len(warns)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
