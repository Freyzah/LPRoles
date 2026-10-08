"""Minimal reader for Unreal Engine IoStore containers (.utoc/.ucas), enough to pull
package chunks out of LOCKDOWN Protocol for static analysis."""
import ctypes, os, struct

import gamedir
PAKS = gamedir.paks()      # the game folder is a local setting (see gamedir.py)
HERE = os.path.dirname(os.path.abspath(__file__))
OODLE = os.environ.get("LP_OODLE", os.path.join(os.environ.get("LOCALAPPDATA", ""), "Temp", "lp", "oodle-data-shared.dll"))  # copy kept on a short path (Windows path limit)

_oodle = None
def oodle_decompress(buf, raw_len):
    global _oodle
    if _oodle is None:
        _oodle = ctypes.CDLL(os.path.abspath(OODLE))
        _oodle.OodleLZ_Decompress.restype = ctypes.c_ssize_t
        _oodle.OodleLZ_Decompress.argtypes = [ctypes.c_char_p, ctypes.c_ssize_t, ctypes.c_char_p, ctypes.c_ssize_t,
            ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_ssize_t, ctypes.c_void_p,
            ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ssize_t, ctypes.c_int]
    out = ctypes.create_string_buffer(raw_len)
    n = _oodle.OodleLZ_Decompress(buf, len(buf), out, raw_len, 1, 0, 0, None, 0, None, None, None, 0, 3)
    if n != raw_len:
        raise RuntimeError(f"oodle: got {n}, expected {raw_len}")
    return out.raw

class Reader:
    def __init__(self, data, pos=0):
        self.d = data; self.p = pos
    def u8(self):  v = self.d[self.p]; self.p += 1; return v
    def u16(self): v = struct.unpack_from('<H', self.d, self.p)[0]; self.p += 2; return v
    def i16(self): v = struct.unpack_from('<h', self.d, self.p)[0]; self.p += 2; return v
    def u32(self): v = struct.unpack_from('<I', self.d, self.p)[0]; self.p += 4; return v
    def i32(self): v = struct.unpack_from('<i', self.d, self.p)[0]; self.p += 4; return v
    def u64(self): v = struct.unpack_from('<Q', self.d, self.p)[0]; self.p += 8; return v
    def i64(self): v = struct.unpack_from('<q', self.d, self.p)[0]; self.p += 8; return v
    def f32(self): v = struct.unpack_from('<f', self.d, self.p)[0]; self.p += 4; return v
    def f64(self): v = struct.unpack_from('<d', self.d, self.p)[0]; self.p += 8; return v
    def raw(self, n): v = self.d[self.p:self.p+n]; self.p += n; return v
    def fstring(self):
        n = self.i32()
        if n == 0: return ""
        if n < 0:
            s = self.raw(-n*2).decode('utf-16-le'); return s.rstrip('\0')
        return self.raw(n).decode('latin-1').rstrip('\0')

def load_name_batch(r):
    """FNameEntrySerialized batch as used by zen packages and the global script objects."""
    num = r.u32()
    if num == 0: return []
    r.u32()            # string bytes
    r.u64()            # hash version
    r.p += 8 * num     # hashes
    hdrs = [(r.u8(), r.u8()) for _ in range(num)]
    names = []
    for b0, b1 in hdrs:
        utf16 = b0 & 0x80; ln = ((b0 & 0x7f) << 8) | b1
        if utf16:
            if r.p & 1: r.p += 1
            names.append(r.raw(ln*2).decode('utf-16-le'))
        else:
            names.append(r.raw(ln).decode('latin-1'))
    return names

class Container:
    def __init__(self, name):
        self.name = name
        toc = open(os.path.join(PAKS, name + ".utoc"), 'rb').read()
        self.cas = open(os.path.join(PAKS, name + ".ucas"), 'rb')
        r = Reader(toc)
        assert r.raw(16) == b"-==--==--==--==-"
        self.version = r.u8(); r.p += 3
        hdr_size = r.u32(); n = self.n = r.u32()
        nblocks = r.u32(); r.u32(); nmeth = r.u32(); methlen = r.u32()
        self.block_size = r.u32(); dir_size = r.u32(); r.u32(); r.u64(); r.p += 16
        self.flags = r.u8(); r.p += 3
        nseeds = r.u32(); r.u64(); nnoph = r.u32()
        r.p = hdr_size
        self.chunk_ids = [r.raw(12) for _ in range(n)]
        self.offlen = []
        for _ in range(n):
            b = r.raw(10)
            self.offlen.append((int.from_bytes(b[:5], 'big'), int.from_bytes(b[5:], 'big')))
        r.p += 4 * nseeds + 4 * nnoph
        self.blocks = []
        for _ in range(nblocks):
            b = r.raw(12)
            self.blocks.append((int.from_bytes(b[0:5], 'little'), int.from_bytes(b[5:8], 'little'),
                                int.from_bytes(b[8:11], 'little'), b[11]))
        self.methods = [r.raw(methlen).rstrip(b'\0').decode() for _ in range(nmeth)]
        assert not (self.flags & 4), "signed containers not handled"
        self.files = {}
        if self.flags & 8 and dir_size:
            d = Reader(toc, r.p)
            self.mount = d.fstring()
            dirs = [(d.u32(), d.u32(), d.u32(), d.u32()) for _ in range(d.u32())]
            files = [(d.u32(), d.u32(), d.u32()) for _ in range(d.u32())]
            strs = [d.fstring() for _ in range(d.u32())]
            NONE = 0xFFFFFFFF
            def walk(di, path):
                name, child, sib, f = dirs[di]
                p = path + (strs[name] + "/" if name != NONE else "")
                while f != NONE:
                    fn, nxt, user = files[f]
                    self.files[p + strs[fn]] = user
                    f = nxt
                c = child
                while c != NONE:
                    walk(c, p); c = dirs[c][2]
            walk(0, self.mount.replace("../../../", ""))

    def read_chunk(self, idx):
        off, ln = self.offlen[idx]
        bs = self.block_size
        first = off // bs; last = (off + ln - 1) // bs if ln else first
        out = bytearray()
        for bi in range(first, last + 1):
            boff, csz, usz, meth = self.blocks[bi]
            self.cas.seek(boff)
            raw = self.cas.read(csz)
            if meth == 0: out += raw[:usz]
            else:
                assert self.methods[meth - 1] == "Oodle", self.methods[meth - 1]
                out += oodle_decompress(raw, usz)
        s = off - first * bs
        return bytes(out[s:s + ln])

    def read_file(self, path):
        return self.read_chunk(self.files[path])

if __name__ == "__main__":
    c = Container("LockdownProtocol-Windows")
    print("version", c.version, "entries", c.n, "methods", c.methods, "files", len(c.files))
    p = "LockdownProtocol/Content/Gameplay/E_PlayerRole.uasset"
    d = c.read_file(p)
    print(p, len(d)); print(d[:96].hex())
    import collections
    print(collections.Counter(os.path.splitext(k)[1] for k in c.files).most_common(8))
    g = Container("global")
    print("global entries", g.n, [(cid.hex(), ol) for cid, ol in zip(g.chunk_ids, g.offlen)])
