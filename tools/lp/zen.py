"""Zen (IoStore) package header parsing for UE 5.5 + object reference resolution."""
import os, pickle, struct
from iostore import Container, Reader, load_name_batch

CACHE = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Temp", "lp", "index.pkl")
NULL = 0xFFFFFFFFFFFFFFFF

class Export:
    __slots__ = ("idx", "name", "outer", "cls", "sup", "tmpl", "hash", "flags", "size", "cooked_off", "off")

class Package:
    def __init__(self, data, path=""):
        self.data = data; self.path = path
        r = Reader(data)
        self.has_ver = r.u32(); self.header_size = r.u32()
        name_idx, name_num = r.u32(), r.u32()
        self.pkg_flags = r.u32(); self.cooked_header_size = r.u32()
        (self.o_hashes, self.o_imports, self.o_exports, self.o_bundles,
         self.o_dephdr, self.o_depent, self.o_impnames) = struct.unpack_from('<7i', data, r.p); r.p += 28
        if self.has_ver:
            raise NotImplementedError("versioning info")
        self.names = load_name_batch(r)
        self.name = self.mapped(name_idx, name_num)
        r.p = self.o_hashes
        self.pub_hashes = [r.u64() for _ in range((self.o_imports - self.o_hashes) // 8)]
        self.imports = [r.u64() for _ in range((self.o_exports - self.o_imports) // 8)]
        self.exports = []
        for i in range((self.o_bundles - self.o_exports) // 72):
            e = Export(); e.idx = i
            e.cooked_off = r.u64(); e.size = r.u64()
            e.name = self.mapped(r.u32(), r.u32())
            e.outer, e.cls, e.sup, e.tmpl, e.hash = r.u64(), r.u64(), r.u64(), r.u64(), r.u64()
            e.flags = r.u32(); r.p += 4
            self.exports.append(e)
        cur = self.header_size
        for _ in range((self.o_dephdr - self.o_bundles) // 8):
            li, cmd = r.u32(), r.u32()
            if cmd == 1:
                self.exports[li].off = cur; cur += self.exports[li].size
        r.p = self.o_impnames
        try:
            nm = load_name_batch(r)
            self.imp_pkgs = [n + (f"_{r.i32() - 1}" if False else "") for n in nm]
        except Exception:
            self.imp_pkgs = []

    def mapped(self, idx, num):
        n = self.names[idx & 0x3FFFFFFF]
        return n if num == 0 else f"{n}_{num - 1}"

    def fname(self, r):
        return self.mapped(r.u32(), r.u32())

    def export_path(self, e):
        parts = [e.name]
        o = e.outer
        while o != NULL and (o >> 62) == 0:
            e = self.exports[o & 0xFFFFFFFF]; parts.append(e.name); o = e.outer
        return ".".join(reversed(parts))

    def export_data(self, e):
        return self.data[e.off:e.off + e.size]

class Game:
    """All packages of the game + global script objects, with an on-disk cache of the index."""
    def __init__(self):
        self.c = Container("LockdownProtocol-Windows")
        self.script = {}
        g = Container("global")
        r = Reader(g.read_chunk(0))
        names = load_name_batch(r)
        ents = []
        for _ in range(r.i32()):
            ni, nn = r.u32(), r.u32()
            n = names[ni & 0x3FFFFFFF] + ("" if nn == 0 else f"_{nn-1}")
            ents.append((n, r.u64(), r.u64(), r.u64()))
        byidx = {gi: (n, o) for n, gi, o, _ in ents}
        for n, gi, o, _ in ents:
            parts = [n]
            while o != NULL and o in byidx:
                pn, o = byidx[o]; parts.append(pn)
            parts.reverse()
            self.script[gi] = parts[0] + ("." + ".".join(parts[1:]) if len(parts) > 1 else "")
        self.pkg_files = {p: i for p, i in self.c.files.items() if p.endswith((".uasset", ".umap"))}
        self._pk = {}
        if os.path.exists(CACHE):
            self.pub = pickle.load(open(CACHE, "rb"))
        else:
            self.pub = {}
            for p in self.pkg_files:
                try:
                    k = self.load(p)
                except Exception as ex:
                    print("ERR", p, ex); continue
                d = self.pub.setdefault(k.name.lower(), {})
                for e in k.exports:
                    if e.hash: d[e.hash] = k.export_path(e)
                self._pk.pop(p, None)
            pickle.dump(self.pub, open(CACHE, "wb"))

    def load(self, path):
        if path not in self._pk:
            self._pk[path] = Package(self.c.read_chunk(self.pkg_files[path]), path)
        return self._pk[path]

    def find(self, short):
        """Find package file paths whose asset name matches `short` (case-insensitive)."""
        s = short.lower()
        return [p for p in self.pkg_files if os.path.splitext(os.path.basename(p))[0].lower() == s]

    def obj(self, pkg, v):
        """Resolve an FPackageObjectIndex."""
        if v == NULL: return "None"
        t = v >> 62
        if t == 0: return pkg.export_path(pkg.exports[v & 0xFFFFFFFF])
        if t == 1: return self.script.get(v, f"script:{v:016x}")
        pi = (v >> 32) & 0x3FFFFFFF; hi = v & 0xFFFFFFFF
        pn = pkg.imp_pkgs[pi] if pi < len(pkg.imp_pkgs) else f"pkg#{pi}"
        h = pkg.pub_hashes[hi] if hi < len(pkg.pub_hashes) else None
        en = self.pub.get(pn.lower(), {}).get(h)
        return f"{pn}.{en}" if en else f"{pn}.<{h:016x}>" if h is not None else pn

    def ref(self, pkg, i):
        """Resolve a serialized FPackageIndex (int32) found in export data."""
        if i == 0: return "None"
        if i > 0:
            return pkg.export_path(pkg.exports[i - 1]) if i - 1 < len(pkg.exports) else f"export#{i}"
        j = -i - 1
        return self.obj(pkg, pkg.imports[j]) if j < len(pkg.imports) else f"import#{j}"

if __name__ == "__main__":
    import sys
    g = Game()
    print("script objects", len(g.script), "packages indexed", len(g.pub))
    for short in sys.argv[1:] or ["E_PlayerRole"]:
        for p in g.find(short):
            k = g.load(p)
            print("==", p, "name", k.name, "size", len(k.data), "hdr", k.header_size)
            print("names:", k.names)
            print("imported packages:", k.imp_pkgs)
            for i, v in enumerate(k.imports): print(f"  import[{i}] {g.obj(k, v)}")
            for e in k.exports:
                print(f"  export[{e.idx}] {k.export_path(e)} : {g.obj(k, e.cls)} super={g.obj(k, e.sup)} tmpl={g.obj(k, e.tmpl)} off={e.off} size={e.size} flags={e.flags:#x} (cooked chk {e.cooked_off - k.cooked_header_size + k.header_size})")
