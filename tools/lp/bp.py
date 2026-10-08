"""Blueprint dumper: variables, functions and disassembled Kismet bytecode for cooked UE 5.5 zen packages.

Usage:  python bp.py <AssetName> [...]      -> prints the dump
        python bp.py --all <outdir>         -> dumps every package that contains script
"""
import os, struct, sys
from iostore import Reader
from zen import Game, NULL

FUNC_FLAGS = {0x1: "Final", 0x4: "AuthorityOnly", 0x8: "Cosmetic", 0x40: "Net", 0x80: "Reliable", 0x200: "Exec",
              0x400: "Native", 0x800: "Event", 0x2000: "Static", 0x4000: "Multicast", 0x8000: "Ubergraph",
              0x10000: "MulticastDelegate", 0x100000: "Delegate", 0x200000: "Server", 0x1000000: "Client",
              0x4000000: "BlueprintCallable", 0x8000000: "BlueprintEvent", 0x10000000: "Pure", 0x40000000: "Const"}
PROP_FLAGS = {0x20: "Net", 0x100000000: "RepNotify", 0x1: "Edit", 0x0001000000000000: "ExposeOnSpawn",
              0x01000000: "SaveGame", 0x2000: "Transient", 0x4000: "Config"}
PARM, OUTPARM, RETPARM, REFPARM = 0x80, 0x100, 0x400, 0x08000000
REP_COND = {0: "", 1: "InitialOnly", 2: "OwnerOnly", 3: "SkipOwner", 4: "SimulatedOnly", 5: "AutonomousOnly",
            6: "SimulatedOrPhysics", 7: "InitialOrOwner", 8: "Custom", 9: "ReplayOrOwner", 10: "ReplayOnly",
            11: "SimulatedOnlyNoReplay", 12: "SimulatedOrPhysicsNoReplay", 13: "SkipReplay", 15: "Never", 16: "NetGroup"}

def short(path):
    """/Game/Gameplay/GM.GM_C.Foo -> GM_C.Foo ; /Script/Engine.Actor.K2_DestroyActor -> Actor.K2_DestroyActor"""
    if path in ("None", ""): return path
    p = path.split("/")[-1]
    parts = p.split(".")
    return ".".join(parts[1:]) if len(parts) > 1 else p

class XR(Reader):
    def __init__(self, data, pkg, game, pos=0):
        super().__init__(data, pos); self.pkg = pkg; self.game = game
    def name(self): return self.pkg.mapped(self.u32(), self.u32())
    def ref(self): return self.game.ref(self.pkg, self.i32())

class ParseError(Exception): pass

def read_property(r, type_name=None):
    t = type_name or r.name()
    p = {"type": t, "name": r.name()}
    r.u32()                                   # object flags
    p["dim"] = r.i32(); p["size"] = r.i32(); p["flags"] = r.u64(); r.u16()
    p["repnotify"] = r.name(); p["repcond"] = r.u8()
    if p["dim"] < 0 or p["dim"] > 4096 or p["size"] < 0 or p["size"] > 1 << 24:
        raise ParseError(f"bad property header for {p['name']}")
    if t == "BoolProperty": r.p += 6
    elif t in ("ByteProperty",): p["of"] = r.ref()
    elif t == "EnumProperty":
        p["of"] = r.ref(); p["inner"] = read_property(r)
    elif t in ("ObjectProperty", "WeakObjectProperty", "LazyObjectProperty", "SoftObjectProperty", "ObjectPtrProperty"):
        p["of"] = r.ref()
    elif t in ("ClassProperty", "SoftClassProperty", "ClassPtrProperty"):
        r.ref(); p["of"] = r.ref()
    elif t == "InterfaceProperty": p["of"] = r.ref()
    elif t == "StructProperty": p["of"] = r.ref()
    elif t in ("ArrayProperty", "SetProperty", "OptionalProperty"): p["inner"] = read_property(r)
    elif t == "MapProperty": p["key"] = read_property(r); p["inner"] = read_property(r)
    elif t in ("DelegateProperty", "MulticastDelegateProperty", "MulticastInlineDelegateProperty",
               "MulticastSparseDelegateProperty"): p["of"] = r.ref()
    elif t == "FieldPathProperty": p["of"] = r.name()
    elif t in ("IntProperty", "FloatProperty", "DoubleProperty", "StrProperty", "NameProperty", "TextProperty",
               "Int64Property", "Int16Property", "Int8Property", "UInt16Property", "UInt32Property", "UInt64Property",
               "Utf8StrProperty", "AnsiStrProperty", "VerseStringProperty"): pass
    else: raise ParseError(f"unknown property type {t!r}")
    return p

def type_str(p):
    t = p["type"].replace("Property", "")
    if t in ("Array", "Set", "Optional"): return f"{t}<{type_str(p['inner'])}>"
    if t == "Map": return f"Map<{type_str(p['key'])}, {type_str(p['inner'])}>"
    if t == "Enum": return f"enum {short(p['of'])}"
    if t == "Byte": return f"enum {short(p['of'])}" if p.get("of") not in (None, "None") else "byte"
    if t == "Struct": return short(p["of"])
    if t in ("Object", "WeakObject", "SoftObject", "LazyObject", "Interface", "ObjectPtr"):
        return short(p["of"]) + {"Object": "*", "ObjectPtr": "*"}.get(t, f" ({t})")
    if t in ("Class", "SoftClass"): return f"{t}<{short(p['of'])}>"
    if "Delegate" in t: return f"{t}<{short(p['of'])}>"
    return t.lower()

def flag_str(v, table):
    return " ".join(n for b, n in table.items() if v & b)

def read_struct(r):
    s = {"super": r.ref()}
    n = r.i32()
    if n < 0 or n > 5000: raise ParseError("children count")
    s["children"] = [r.i32() for _ in range(n)]
    n = r.i32()
    if n < 0 or n > 5000: raise ParseError("property count")
    s["props"] = [read_property(r) for _ in range(n)]
    s["bufsize"] = r.i32(); ser = r.i32()
    if s["bufsize"] < 0 or ser < 0 or ser > len(r.d) - r.p: raise ParseError("script size")
    s["script_at"] = r.p; s["script_len"] = ser
    r.p += ser
    return s

def read_function(pkg, game, e):
    r = XR(pkg.data, pkg, game, pkg.header_size + e.cooked_off)
    end = r.p + e.size
    if r.raw(6) != b"\x00\x01\x00\x00\x00\x00": raise ParseError("function preamble")
    s = read_struct(r)
    s["fflags"] = r.u32()
    if s["fflags"] & 0x40: r.i16()
    r.i32(); r.i32()
    if r.p != end: raise ParseError(f"function trailing {end - r.p}")
    return s

def find_class_struct(pkg, game, e, func_exports):
    """A class export starts with unversioned properties we cannot decode without mappings:
    scan for the offset where the UStruct part parses cleanly up to a plausible UClass tail."""
    base = pkg.header_size + e.cooked_off
    end = base + e.size
    fset = set(func_exports)
    for off in range(base + 2, end - 20):
        r = XR(pkg.data, pkg, game, off)
        try:
            sup = r.i32()
            if sup == 0 or sup > len(pkg.exports) or -sup > len(pkg.imports): continue
            n = struct.unpack_from('<i', pkg.data, r.p)[0]
            if n < 0 or n > len(pkg.exports): continue
            kids = struct.unpack_from(f'<{n}i', pkg.data, r.p + 4)
            if any((c - 1) not in fset for c in kids): continue
            r.p = off
            s = read_struct(r)
            # UClass tail: FuncMap count must equal number of child functions
            if r.i32() != n: continue
            s["end"] = r.p
            return s
        except (ParseError, struct.error, IndexError, UnicodeDecodeError):
            continue
    return None

# ---------------------------------------------------------------- Kismet disassembler
class Dis:
    def __init__(self, pkg, game, start, length):
        self.r = XR(pkg.data, pkg, game, start); self.end = start + length; self.mem = 0

    def u8(self):  self.mem += 1; return self.r.u8()
    def u16(self): self.mem += 2; return self.r.u16()
    def u32(self): self.mem += 4; return self.r.u32()
    def i32(self): self.mem += 4; return self.r.i32()
    def obj(self): self.mem += 8; return self.r.ref()
    def fname(self): self.mem += 12; return self.r.name()
    def prop(self):
        self.mem += 8
        n = self.r.i32()
        if n < 0 or n > 16: raise ParseError("field path")
        names = [self.r.name() for _ in range(n)]
        self.r.i32()
        return ".".join(names) if names else "None"
    def cstr(self):
        s = bytearray()
        while True:
            c = self.u8()
            if c == 0: break
            s.append(c)
        return s.decode("latin-1")
    def wstr(self):
        s = []
        while True:
            c = self.u16()
            if c == 0: break
            s.append(chr(c))
        return "".join(s)

    def args(self, terminator=0x16):
        out = []
        while True:
            if self.r.d[self.r.p] == terminator:
                self.u8(); return out
            out.append(self.expr())

    def call(self, name):
        return f"{name}({', '.join(self.args())})"

    def expr(self):
        t = self.u8()
        if t == 0x00: return self.prop()
        if t == 0x01: return "self." + self.prop()
        if t == 0x02: return "default." + self.prop()
        if t == 0x04: return "return " + self.expr()
        if t == 0x06: return f"goto {self.u32():#06x}"
        if t == 0x07:
            o = self.u32(); return f"if not ({self.expr()}) goto {o:#06x}"
        if t == 0x09:
            self.u16(); self.u8(); return f"assert({self.expr()})"
        if t == 0x0B: return "nothing"
        if t == 0x0C: self.i32(); return "nothing"
        if t == 0x0F:
            self.prop(); v = self.expr(); return f"{v} = {self.expr()}"
        if t == 0x11:
            p = self.prop(); return f"bit({p}, {self.u8()})"
        if t in (0x12, 0x19, 0x1A):
            o = self.expr(); self.u32(); self.prop(); inner = self.expr()
            if inner.startswith("self."): inner = inner[5:]
            if o.startswith("Default__Kismet") or o in ("Default__GameplayStatics",): return inner
            return f"{o}.{inner}"
        if t == 0x13:
            c = self.obj(); return f"metacast<{short(c)}>({self.expr()})"
        if t in (0x14, 0x5F, 0x60, 0x43, 0x44):
            v = self.expr(); return f"{v} = {self.expr()}"
        if t == 0x15: return "<endparmvalue>"
        if t == 0x16: return "<endparms>"
        if t == 0x17: return "self"
        if t == 0x18:
            self.u32(); return self.expr()
        if t in (0x1B, 0x45): return self.call(self.fname())
        if t in (0x1C, 0x46): return self.call(short(self.obj()).split(".")[-1])
        if t == 0x68:
            n = short(self.obj()).replace("KismetArrayLibrary.", "").replace("KismetMathLibrary.", "").replace("KismetSystemLibrary.", "").replace("GameplayStatics.", "").replace("KismetStringLibrary.", "").replace("KismetTextLibrary.", "")
            return self.call(n)
        if t == 0x1D: return str(self.i32())
        if t == 0x1E:
            self.mem += 4; return f"{self.r.f32():g}"
        if t == 0x1F: return repr(self.cstr())
        if t == 0x20: return short(self.obj())
        if t == 0x21: return f"'{self.fname()}'"
        if t == 0x22:
            self.mem += 24; return "Rot(%g,%g,%g)" % (self.r.f64(), self.r.f64(), self.r.f64())
        if t == 0x23:
            self.mem += 24; return "Vec(%g,%g,%g)" % (self.r.f64(), self.r.f64(), self.r.f64())
        if t == 0x24: return str(self.u8())
        if t == 0x25: return "0"
        if t == 0x26: return "1"
        if t == 0x27: return "true"
        if t == 0x28: return "false"
        if t == 0x29:
            k = self.u8()
            if k == 0: return 'Text("")'
            if k == 1:
                s = self.expr(); self.expr(); self.expr(); return f"Text({s})"
            if k in (2, 3): return f"Text({self.expr()})"
            if k == 4:
                self.obj(); a = self.expr(); return f"TextFromTable({a}, {self.expr()})"
            return "Text(None)"
        if t == 0x2A: return "None"
        if t == 0x2B:
            self.mem += 80; self.r.p += 80; return "Transform(...)"
        if t == 0x2C: return str(self.u8())
        if t == 0x2D: return "NoInterface"
        if t in (0x2E, 0x52, 0x54, 0x55):
            c = self.obj(); return f"cast<{short(c)}>({self.expr()})"
        if t == 0x2F:
            s = self.obj(); self.i32(); return f"{short(s)}{{{', '.join(self.args(0x30))}}}"
        if t == 0x31:
            a = self.expr(); return f"{a} = [{', '.join(self.args(0x32))}]"
        if t == 0x33: return "prop:" + self.prop()
        if t == 0x34: return repr(self.wstr())
        if t in (0x35, 0x36):
            self.mem += 8; return str(self.r.i64())
        if t == 0x37:
            self.mem += 8; return f"{self.r.f64():g}"
        if t == 0x38:
            c = self.u8(); return f"conv{c:#x}({self.expr()})"
        if t == 0x39:
            a = self.expr(); self.i32(); return f"{a} = set[{', '.join(self.args(0x3A))}]"
        if t == 0x3B:
            a = self.expr(); self.i32(); return f"{a} = map[{', '.join(self.args(0x3C))}]"
        if t == 0x3D:
            self.prop(); self.i32(); return f"set[{', '.join(self.args(0x3E))}]"
        if t == 0x3F:
            self.prop(); self.prop(); self.i32(); return f"map[{', '.join(self.args(0x40))}]"
        if t == 0x41:
            self.mem += 12; return "Vec3f(%g,%g,%g)" % (self.r.f32(), self.r.f32(), self.r.f32())
        if t == 0x42:
            p = self.prop(); return f"{self.expr()}.{p}"
        if t == 0x48: return self.prop()
        if t == 0x4B: return f"delegate('{self.fname()}')"
        if t == 0x4C: return f"push {self.u32():#06x}"
        if t == 0x4D: return "pop"
        if t == 0x4E: return f"goto computed({self.expr()})"
        if t == 0x4F: return f"if not ({self.expr()}) pop"
        if t == 0x50: return "<breakpoint>"
        if t == 0x51: return self.expr()
        if t == 0x53: return "<end>"
        if t in (0x5A, 0x5E): return "<trace>"
        if t == 0x5B: return f"skipoffset({self.u32():#06x})"
        if t == 0x5C:
            d = self.expr(); return f"{d} += {self.expr()}"
        if t == 0x5D: return f"{self.expr()}.clear()"
        if t == 0x61:
            n = self.fname(); d = self.expr(); return f"{d} = bind({self.expr()}, '{n}')"
        if t == 0x62:
            d = self.expr(); return f"{d} -= {self.expr()}"
        if t == 0x63:
            self.obj(); a = self.args(); return f"{a[0]}.broadcast({', '.join(a[1:])})"
        if t == 0x64:
            p = self.prop(); return f"frame.{p} = {self.expr()}"
        if t == 0x65:
            self.prop(); self.i32(); return f"[{', '.join(self.args(0x66))}]"
        if t == 0x67: return f"soft({self.expr()})"
        if t == 0x69:
            n = self.u16(); self.u32(); idx = self.expr(); cases = []
            for _ in range(n):
                c = self.expr(); self.u32(); cases.append(f"{c}: {self.expr()}")
            return f"switch({idx}){{{', '.join(cases)}, default: {self.expr()}}}"
        if t == 0x6A:
            self.u8(); return "<instr>"
        if t == 0x6B:
            a = self.expr(); return f"{a}[{self.expr()}]"
        if t == 0x6C: return "sparse." + self.prop()
        if t == 0x6D: return f"fieldpath({self.expr()})"
        if t == 0x70:
            self.i32(); self.u32(); return "<rtfm-transact>"
        if t == 0x71:
            self.i32(); self.u8(); return "<rtfm-stop>"
        if t == 0x72: return f"rtfm_abort_if_not({self.expr()})"
        raise ParseError(f"unknown opcode {t:#x} at disk {self.r.p - 1:#x}")

    def statements(self):
        out = []
        while self.r.p < self.end:
            at = self.mem
            try:
                s = self.expr()
            except (ParseError, IndexError, struct.error, UnicodeDecodeError) as ex:
                out.append((at, f"!! disassembly stopped: {ex}")); break
            if s == "<end>": break
            if s in ("<trace>", "nothing", "<breakpoint>"): continue
            out.append((at, s))
        return out

# ---------------------------------------------------------------- dump
def prop_line(p):
    extra = flag_str(p["flags"], PROP_FLAGS)
    if p["repcond"]: extra += f" cond={REP_COND.get(p['repcond'], p['repcond'])}"
    if p["repnotify"] != "None": extra += f" notify={p['repnotify']}"
    return f"{type_str(p)} {p['name']}" + (f"   [{extra.strip()}]" if extra.strip() else "")

def signature(name, s):
    params, rets, local = [], [], []
    for p in s["props"]:
        f = p["flags"]
        if f & RETPARM: rets.append(type_str(p))
        elif f & PARM:
            params.append(("out " if f & OUTPARM and not f & REFPARM else "") + f"{type_str(p)} {p['name']}")
        else: local.append(p)
    sig = f"{name}({', '.join(params)})" + (f" -> {', '.join(rets)}" if rets else "")
    fl = flag_str(s["fflags"], FUNC_FLAGS)
    return sig + (f"   [{fl}]" if fl else ""), local

def dump_package(game, path, with_code=True, out=None):
    pkg = game.load(path)
    w = (lambda *a: print(*a, file=out)) if out else print
    funcs = [e for e in pkg.exports if game.obj(pkg, e.cls) == "/Script/CoreUObject.Function"]
    fidx = [e.idx for e in funcs]
    classes = [e for e in pkg.exports if game.obj(pkg, e.cls).endswith("BlueprintGeneratedClass")]
    w(f"######## {pkg.name}")
    for c in classes:
        w(f"\nclass {c.name} : {short(game.obj(pkg, c.sup))}")
        s = find_class_struct(pkg, game, c, fidx)
        if s is None:
            w("  !! could not locate class layout"); continue
        w("  -- variables")
        for p in s["props"]: w("    " + prop_line(p))
    comps = [e for e in pkg.exports if e not in funcs and e not in classes]
    if comps:
        w("\n  -- other exports (components, templates, default object)")
        for e in comps: w(f"    {pkg.export_path(e)} : {short(game.obj(pkg, e.cls))}")
    for e in funcs:
        try:
            s = read_function(pkg, game, e)
        except (ParseError, struct.error, IndexError, UnicodeDecodeError) as ex:
            w(f"\n  function {e.name}  !! {ex}"); continue
        sig, local = signature(e.name, s)
        sup = game.obj(pkg, e.sup)
        w(f"\n  function {sig}" + (f"   overrides {short(sup)}" if sup != "None" else ""))
        if with_code:
            for at, st in Dis(pkg, game, s["script_at"], s["script_len"]).statements():
                w(f"    {at:04x}: {st}")
    return pkg

if __name__ == "__main__":
    g = Game()
    if sys.argv[1:2] == ["--all"]:
        outdir = sys.argv[2]; os.makedirs(outdir, exist_ok=True)
        n = 0
        for path in sorted(g.pkg_files):
            try:
                pkg = g.load(path)
                if not any(g.obj(pkg, e.cls) == "/Script/CoreUObject.Function" for e in pkg.exports):
                    g._pk.pop(path, None); continue
                rel = path.replace("LockdownProtocol/Content/", "").replace("/", "__").rsplit(".", 1)[0]
                with open(os.path.join(outdir, rel + ".txt"), "w", encoding="utf-8") as f:
                    dump_package(g, path, out=f)
                n += 1
            except Exception as ex:
                print("ERR", path, repr(ex))
            g._pk.pop(path, None)
        print("dumped", n, "packages")
    else:
        for a in sys.argv[1:]:
            for p in g.find(a): dump_package(g, p)
