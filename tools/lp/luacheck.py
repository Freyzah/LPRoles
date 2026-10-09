"""Small Lua 5.4 syntax checker with scope analysis (no Lua interpreter is available on this machine).

Checks: syntax, `return` placement, and every global name read or written against a whitelist,
which catches misspelled locals and functions used before their `local function` definition.

Usage: python luacheck.py <file.lua> [...]
"""
import re, sys

KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in",
            "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}

LUA_GLOBALS = {"print", "pairs", "ipairs", "type", "tostring", "tonumber", "pcall", "xpcall", "error", "require",
               "table", "string", "math", "os", "io", "debug", "next", "select", "setmetatable", "getmetatable",
               "rawget", "rawset", "rawequal", "rawlen", "assert", "utf8", "coroutine", "_G", "_VERSION",
               "collectgarbage", "load", "dofile"}
UE4SS_GLOBALS = {"RegisterHook", "UnregisterHook", "StaticFindObject", "FindFirstOf", "FindAllOf", "LoadAsset", "LoopInGameThreadWithDelay", "CancelDelayedAction",
                 "FName", "FText", "ExecuteInGameThread", "ExecuteWithDelay", "ExecuteInGameThreadWithDelay",
                 "LoopAsync", "RegisterKeyBind", "RegisterKeyBindAsync", "IsKeyBindRegistered", "Key",
                 "ModifierKey", "CreateInvalidObject", "NotifyOnNewObject", "RegisterConsoleCommandHandler",
                 "UnrealVersion", "ModRef", "EFindName", "NAME_None", "StaticConstructObject",
                 "IterateGameDirectories"}

class LuaError(Exception): pass

TOKEN_RE = re.compile(r"""
    (?P<ws>[ \t\r\n]+)
  | (?P<lcomment>--\[(?P<ceq>=*)\[)
  | (?P<comment>--[^\n]*)
  | (?P<lstring>\[(?P<seq>=*)\[)
  | (?P<number>0[xX][0-9a-fA-F]*(?:\.[0-9a-fA-F]*)?(?:[pP][+-]?\d+)?|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<string>"(?:\\.|\\\n|[^"\\\n])*"|'(?:\\.|\\\n|[^'\\\n])*')
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|<<|>>|//|::|[-+*/%^\#&~|<>=(){}\[\];:,.])
""", re.X)

def tokenize(src):
    toks, pos, line = [], 0, 1
    while pos < len(src):
        m = TOKEN_RE.match(src, pos)
        if not m: raise LuaError(f"line {line}: unexpected character {src[pos]!r}")
        kind = m.lastgroup
        text = m.group(0)
        if kind in ("lcomment", "lstring"):
            eq = m.group("ceq") if kind == "lcomment" else m.group("seq")
            close = "]" + eq + "]"
            end = src.find(close, m.end())
            if end < 0: raise LuaError(f"line {line}: unfinished long {'comment' if kind == 'lcomment' else 'string'}")
            text = src[pos:end + len(close)]
            if kind == "lstring": toks.append(("string", text, line))
            line += text.count("\n"); pos = end + len(close); continue
        if kind == "ws" or kind == "comment":
            pass
        elif kind == "name":
            toks.append(("kw" if text in KEYWORDS else "name", text, line))
        elif kind == "ceq" or kind == "seq":
            pass
        else:
            toks.append((kind, text, line))
        line += text.count("\n"); pos = m.end()
    toks.append(("eof", "<eof>", line))
    return toks

BINOPS = {"or": (1, 1), "and": (2, 2), "<": (3, 3), ">": (3, 3), "<=": (3, 3), ">=": (3, 3), "~=": (3, 3),
          "==": (3, 3), "|": (4, 4), "~": (5, 5), "&": (6, 6), "<<": (7, 7), ">>": (7, 7), "..": (9, 8),
          "+": (10, 10), "-": (10, 10), "*": (11, 11), "/": (11, 11), "//": (11, 11), "%": (11, 11),
          "^": (14, 13)}
UNARY_PRIORITY = 12

class Parser:
    def __init__(self, toks, name, extra_globals=()):
        self.t, self.i, self.name = toks, 0, name
        self.scopes = [set()]
        self.globals_ok = LUA_GLOBALS | UE4SS_GLOBALS | set(extra_globals)
        self.problems = []

    # --- token helpers
    def peek(self): return self.t[self.i]
    def text(self): return self.t[self.i][1]
    def kind(self): return self.t[self.i][0]
    def line(self): return self.t[self.i][2]
    def next(self): tok = self.t[self.i]; self.i += 1; return tok
    def check(self, s): return self.kind() in ("kw", "op") and self.text() == s
    def accept(self, s):
        if self.check(s): self.i += 1; return True
        return False
    def expect(self, s, what=None):
        if not self.accept(s):
            raise LuaError(f"line {self.line()}: expected '{s}'{' ' + what if what else ''} near '{self.text()}'")
    def name_tok(self):
        if self.kind() != "name": raise LuaError(f"line {self.line()}: expected a name near '{self.text()}'")
        return self.next()[1]

    # --- scopes
    def push(self): self.scopes.append(set())
    def pop(self): self.scopes.pop()
    def declare(self, n): self.scopes[-1].add(n)
    def use(self, n, line, write=False):
        if any(n in s for s in self.scopes) or n in self.globals_ok: return
        self.problems.append(f"line {line}: {'assignment to' if write else 'use of'} undefined global '{n}'")

    # --- grammar
    def chunk(self):
        self.block()
        if self.kind() != "eof": raise LuaError(f"line {self.line()}: unexpected '{self.text()}'")

    def block_ends(self):
        return self.kind() == "eof" or (self.kind() == "kw" and self.text() in ("end", "else", "elseif", "until"))

    def block(self):
        self.push()
        while not self.block_ends():
            if self.check("return"):
                self.next()
                if not self.block_ends() and not self.check(";"): self.explist()
                self.accept(";")
                if not self.block_ends():
                    raise LuaError(f"line {self.line()}: 'return' must be the last statement of its block (near '{self.text()}')")
                break
            self.statement()
        self.pop()

    def statement(self):
        if self.accept(";"): return
        if self.check("if"):
            self.next(); self.exp(); self.expect("then"); self.block()
            while self.accept("elseif"):
                self.exp(); self.expect("then"); self.block()
            if self.accept("else"): self.block()
            self.expect("end", "to close 'if'"); return
        if self.check("while"):
            self.next(); self.exp(); self.expect("do"); self.block(); self.expect("end", "to close 'while'"); return
        if self.check("do"):
            self.next(); self.block(); self.expect("end", "to close 'do'"); return
        if self.check("for"):
            self.next(); names = [self.name_tok()]
            if self.accept("="):
                self.exp(); self.expect(","); self.exp()
                if self.accept(","): self.exp()
            else:
                while self.accept(","): names.append(self.name_tok())
                self.expect("in"); self.explist()
            self.expect("do")
            self.push()
            for n in names: self.declare(n)
            self.block(); self.pop(); self.expect("end", "to close 'for'"); return
        if self.check("repeat"):
            self.next(); self.push();
            while not self.block_ends(): self.statement()
            self.expect("until"); self.exp(); self.pop(); return
        if self.check("function"):
            self.next(); line = self.line(); first = self.name_tok(); self.use(first, line)
            is_method = False
            while self.accept("."): self.name_tok()
            if self.accept(":"): self.name_tok(); is_method = True
            self.funcbody(is_method); return
        if self.check("local"):
            self.next()
            if self.accept("function"):
                n = self.name_tok(); self.declare(n); self.funcbody(False); return
            names = [self.name_tok()]; self.attrib()
            while self.accept(","):
                names.append(self.name_tok()); self.attrib()
            if self.accept("="): self.explist()
            for n in names: self.declare(n)
            return
        if self.check("break"): self.next(); return
        if self.check("goto"): self.next(); self.name_tok(); return
        if self.check("::"): self.next(); self.name_tok(); self.expect("::"); return
        # assignment or call
        line = self.line()
        kind, base = self.suffixedexp(assign_target=True)
        if self.check("=") or self.check(","):
            targets = [(kind, base, line)]
            while self.accept(","):
                l2 = self.line(); k2, b2 = self.suffixedexp(assign_target=True); targets.append((k2, b2, l2))
            self.expect("="); self.explist()
            for k, b, l in targets:
                if k == "name": self.use(b, l, write=True)
                elif k == "call": raise LuaError(f"line {l}: cannot assign to a function call")
            return
        if kind == "name": self.use(base, line)
        if kind != "call": raise LuaError(f"line {line}: syntax error (expression is not a statement) near '{self.text()}'")

    def attrib(self):
        if self.accept("<"): self.name_tok(); self.expect(">")

    def funcbody(self, is_method):
        self.expect("(")
        self.push()
        if is_method: self.declare("self")
        if not self.check(")"):
            while True:
                if self.accept("..."): break
                self.declare(self.name_tok())
                if not self.accept(","): break
        self.expect(")")
        self.block()
        self.pop()
        self.expect("end", "to close 'function'")

    def explist(self):
        self.exp()
        while self.accept(","): self.exp()

    def primaryexp(self, assign_target):
        if self.kind() == "name":
            line = self.line(); n = self.next()[1]
            return "name", n, line
        if self.accept("("):
            self.exp(); self.expect(")"); return "paren", None, self.line()
        raise LuaError(f"line {self.line()}: unexpected symbol near '{self.text()}'")

    def suffixedexp(self, assign_target=False):
        kind, base, line = self.primaryexp(assign_target)
        first = True
        while True:
            if self.check("."):
                if kind == "name" and first: self.use(base, line)
                self.next(); self.name_tok(); kind = "index"
            elif self.check("["):
                if kind == "name" and first: self.use(base, line)
                self.next(); self.exp(); self.expect("]"); kind = "index"
            elif self.check(":"):
                if kind == "name" and first: self.use(base, line)
                self.next(); self.name_tok(); self.callargs(); kind = "call"
            elif self.check("(") or self.check("{") or self.kind() == "string":
                if kind == "name" and first: self.use(base, line)
                self.callargs(); kind = "call"
            else:
                return kind, base
            first = False

    def callargs(self):
        if self.kind() == "string": self.next(); return
        if self.check("{"): self.table(); return
        self.expect("(")
        if not self.check(")"): self.explist()
        self.expect(")")

    def table(self):
        self.expect("{")
        while not self.check("}"):
            if self.check("["):
                self.next(); self.exp(); self.expect("]"); self.expect("="); self.exp()
            elif self.kind() == "name" and self.t[self.i + 1][1] == "=" and self.t[self.i + 1][0] == "op":
                self.next(); self.next(); self.exp()
            else:
                self.exp()
            if not (self.accept(",") or self.accept(";")): break
        self.expect("}", "to close table")

    def simpleexp(self):
        k = self.kind()
        if k in ("number", "string"): self.next(); return
        if self.check("nil") or self.check("true") or self.check("false") or self.check("..."): self.next(); return
        if self.check("{"): self.table(); return
        if self.check("function"): self.next(); self.funcbody(False); return
        line = self.line()
        kind, base = self.suffixedexp()
        if kind == "name": self.use(base, line)

    def exp(self, limit=0):
        if self.check("not") or self.check("-") or self.check("#") or self.check("~"):
            self.next(); self.exp(UNARY_PRIORITY)
        else:
            self.simpleexp()
        while self.kind() in ("kw", "op") and self.text() in BINOPS and BINOPS[self.text()][0] > limit:
            op = self.next()[1]
            self.exp(BINOPS[op][1])

MAX_LOCALS = 200     # Lua refuses a function with more local variables, a file's main body included

def top_level_locals(src):
    """How many names `local` declares in the file's main body (written at the start of a line)."""
    n = 0
    for line in src.splitlines():
        m = re.match(r"local\s+(function\s+)?([^=]*)", line)
        if not m: continue
        n += 1 if m.group(1) else len([x for x in re.sub(r"--.*", "", m.group(2)).split(",") if x.strip()])
    return n

def check_file(path, extra_globals=()):
    src = open(path, encoding="utf-8").read()
    try:
        p = Parser(tokenize(src), path, extra_globals)
        p.chunk()
        n = top_level_locals(src)
        if n > MAX_LOCALS:
            p.problems.append(f"{n} local names in the main body: Lua's limit is {MAX_LOCALS}, the file would not load")
        return p.problems
    except LuaError as e:
        return [f"SYNTAX: {e}"]

if __name__ == "__main__":
    bad = 0
    for path in sys.argv[1:]:
        probs = check_file(path)
        print(("OK   " if not probs else "FAIL ") + path)
        for pr in probs: print("     " + pr); bad += 1
    sys.exit(1 if bad else 0)
