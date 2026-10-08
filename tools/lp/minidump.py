"""Reads a Windows minidump (.dmp) enough to say where a crash happened.

python tools/lp/minidump.py [-n depth] <file.dmp> [more.dmp ...]
Prints the exception (code, address, module + offset, kind of access for an access violation)
and a rough call stack of the crashing thread: every value on its stack that points right
after a call instruction of a loaded module (checked in the module's file on disk when it is
still the same build), as module + offset, with the nearest exported name when there is one.
No symbols: a name is only the closest export below the address, so "Name+0x12" is likely
right and "Name+0x3f00" only says which part of the file it is.
Offsets inside UE4SS.dll can then be given to pe_funcs.py.
"""
import struct, sys, os, bisect

CODES = {0xC0000005: "violation d'accès", 0xC00000FD: 'débordement de pile', 0xE06D7363: 'exception C++',
         0x80000003: "point d'arrêt (erreur fatale du moteur)", 0xC0000409: 'arrêt forcé (fail fast)',
         0xC000001D: 'instruction illégale', 0xC0000374: 'tas corrompu', 0xC0000017: 'plus de mémoire',
         0xC000012D: 'limite de mémoire engagée atteinte', 0xC0000094: 'division par zéro'}

def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]
def u64(b, o): return struct.unpack_from('<Q', b, o)[0]


class Image:
    """A module's file on disk: sections, exports, and the bytes before an address."""
    cache = {}

    def __init__(self, path, stamp):
        self.ok, self.names, self.rvas = False, [], []
        try:
            self.f = open(path, 'rb')
        except OSError:
            return
        f = self.f
        head = f.read(0x1000)
        pe = u32(head, 0x3c)
        if pe + 0x200 > len(head):
            f.seek(0); head = f.read(pe + 0x1000)
        if u32(head, pe + 8) != stamp:
            return                                   # another build than the one that crashed
        nsec, optsz = u16(head, pe + 6), u16(head, pe + 20)
        opt = pe + 24
        self.secs = []
        for i in range(nsec):
            o = opt + optsz + i * 40
            vsize, va, rsize, raw = struct.unpack_from('<IIII', head, o + 8)
            self.secs.append((va, max(vsize, rsize), raw, rsize, u32(head, o + 36)))
        self.ok = True
        exp_rva, exp_size = struct.unpack_from('<II', head, opt + 112)
        if exp_rva:
            e = self.read(exp_rva, 40)
            if e:
                nfun, nnames = u32(e, 20), u32(e, 24)
                funs = self.read(u32(e, 28), 4 * nfun) or b''
                names = self.read(u32(e, 32), 4 * nnames) or b''
                ords = self.read(u32(e, 36), 2 * nnames) or b''
                found = []
                for i in range(min(nnames, len(names) // 4)):
                    s = self.read(u32(names, 4 * i), 96) or b''
                    k = u16(ords, 2 * i)
                    if 4 * k + 4 <= len(funs):
                        found.append((u32(funs, 4 * k), s.split(b'\0')[0].decode('ascii', 'replace')))
                found.sort()
                self.rvas = [r for r, _ in found]
                self.names = [n for _, n in found]

    def read(self, rva, size):
        for va, vs, raw, rs, _ in self.secs:
            if va <= rva < va + vs:
                off = rva - va
                if off >= rs: return None
                self.f.seek(raw + off)
                return self.f.read(min(size, rs - off))
        return None

    def code(self, rva):
        for va, vs, raw, rs, flags in self.secs:
            if va <= rva < va + vs: return bool(flags & 0x20000000)
        return False

    def after_call(self, rva):
        if rva < 8 or not self.code(rva): return False
        b = self.read(rva - 7, 7)
        if not b or len(b) < 7: return False
        if b[2] == 0xE8: return True                                   # call rel32
        if b[5] == 0xFF and (b[6] & 0x38) == 0x10 and (b[6] & 0xC7) != 0x05 and (b[6] & 0xC0) != 0x40 and (b[6] & 0xC0) != 0x80: return True   # call reg / [reg]
        if b[4] == 0xFF and (b[5] & 0xF8) in (0x50, 0x10): return True   # call [reg+d8] (or SIB)
        if b[1] == 0xFF and (b[2] & 0xC7) in (0x15, 0x90, 0x91, 0x92, 0x93, 0x95, 0x96, 0x97): return True  # call [rip+d32] / [reg+d32]
        if b[0] == 0xFF and b[1] == 0x94: return True                  # call [sib+d32]
        if b[3] == 0xFF and b[4] == 0x54: return True                  # call [sib+d8]
        if b[4] in (0x41, 0x48, 0x49) and b[5] == 0xFF and (b[6] & 0x38) == 0x10: return True
        return False

    def name(self, rva):
        i = bisect.bisect_right(self.rvas, rva) - 1
        if i < 0: return ''
        return '%s+0x%x' % (self.names[i], rva - self.rvas[i])

    @classmethod
    def get(cls, path, stamp):
        key = (path.lower(), stamp)
        if key not in cls.cache: cls.cache[key] = cls(path, stamp)
        return cls.cache[key]


def read(path, depth):
    f = open(path, 'rb')
    head = f.read(32)
    assert head[:4] == b'MDMP', 'pas un minidump'
    nstreams, dir_rva = u32(head, 8), u32(head, 12)
    f.seek(dir_rva)
    d = f.read(12 * nstreams)
    streams = {}
    for i in range(nstreams):
        t, size, rva = struct.unpack_from('<III', d, 12 * i)
        streams[t] = (size, rva)
    def at(rva, size):
        f.seek(rva)
        return f.read(size)
    mods = []
    if 4 in streams:
        size, rva = streams[4]
        b = at(rva, size)
        for i in range(u32(b, 0)):
            o = 4 + 108 * i
            base, msize, stamp, name_rva = u64(b, o), u32(b, o + 8), u32(b, o + 16), u32(b, o + 20)
            name = at(name_rva + 4, u32(at(name_rva, 4), 0)).decode('utf-16-le', 'replace')
            mods.append((base, msize, name, stamp))
    def where(addr):
        for base, msize, name, stamp in mods:
            if base <= addr < base + msize: return name, addr - base, stamp
        return None, addr, 0
    # memory of a full dump (the stack is then not stored with the thread)
    big = []
    if 9 in streams:
        size, rva = streams[9]
        b = at(rva, 16)
        n, pos = u64(b, 0), u64(b, 8)
        b = at(rva + 16, 16 * n)
        for i in range(n):
            start, dsize = u64(b, 16 * i), u64(b, 16 * i + 8)
            big.append((start, dsize, pos)); pos += dsize
    if 5 in streams:                                 # or listed apart, range by range
        size, rva = streams[5]
        b = at(rva, size)
        for i in range(u32(b, 0)):
            o = 4 + 16 * i
            big.append((u64(b, o), u32(b, o + 8), u32(b, o + 12)))
    def memory(addr, size):
        for start, dsize, pos in big:
            if start <= addr < start + dsize:
                return at(pos + addr - start, min(size, start + dsize - addr))
        return b''
    out = {'file': os.path.basename(path), 'size': os.path.getsize(path), 'modules': mods}
    if 6 not in streams:
        out['exception'] = None
        return out, where
    size, rva = streams[6]
    b = at(rva, size)
    tid, code = u32(b, 0), u32(b, 8)
    addr, nparams = u64(b, 24), u32(b, 32)
    params = [u64(b, 40 + 8 * i) for i in range(min(nparams, 15))]
    ctx_size, ctx_rva = u32(b, 160), u32(b, 164)
    ctx = at(ctx_rva, ctx_size) if ctx_size >= 0x100 else b''
    rsp, rip = (u64(ctx, 0x98), u64(ctx, 0xF8)) if ctx else (0, 0)
    out.update(exception=code, address=addr, params=params, thread=tid, rip=rip, rsp=rsp, threads=0)
    stack, start = b'', 0
    if 3 in streams:
        size, rva = streams[3]
        b = at(rva, size)
        out['threads'] = u32(b, 0)
        for i in range(u32(b, 0)):
            o = 4 + 48 * i
            if u32(b, o) != tid: continue
            start, ssize, srva = u64(b, o + 24), u32(b, o + 32), u32(b, o + 36)
            stack = at(srva, ssize) if srva else memory(start, ssize)
    frames = []
    if stack:
        off = rsp - start if start <= rsp < start + len(stack) else 0
        off -= off % 8
        for p in range(off, len(stack) - 7, 8):
            v = u64(stack, p)
            name, rel, stamp = where(v)
            if not name: continue
            img = Image.get(name, stamp)
            if img.ok:
                if not img.after_call(rel): continue
                frames.append((os.path.basename(name), rel, img.name(rel)))
            else:
                frames.append((os.path.basename(name), rel, '(fichier différent ou absent : non vérifié)'))
            if len(frames) >= depth: break
    out['frames'] = frames
    out['stack'] = (start, len(stack))
    return out, where


def main():
    args = sys.argv[1:]
    depth = 60
    if args and args[0] == '-n':
        depth = int(args[1]); args = args[2:]
    for path in args:
        out, where = read(path, depth)
        print('== %s (%d Mo, %d modules)' % (out['file'], out['size'] // 2**20, len(out['modules'])))
        if out.get('exception') is None:
            print("   pas d'exception enregistrée")
            continue
        code = out['exception']
        name, rel, stamp = where(out['address'])
        img = Image.get(name, stamp) if name else None
        print('   exception 0x%08X (%s) à %s + 0x%x  %s' % (code, CODES.get(code, '?'), os.path.basename(name or '?'), rel,
                                                       img.name(rel) if img and img.ok else ''))
        p = out['params']
        if code == 0xC0000005 and len(p) >= 2:
            print("   %s à l'adresse 0x%x" % ({0: 'lecture', 1: 'écriture', 8: 'exécution'}.get(p[0], '?'), p[1]))
        elif p:
            print('   paramètres :', ' '.join('0x%x' % x for x in p[:5]))
        print('   fil %d (parmi %d), pile lue : %d octets' % (out['thread'], out['threads'], out['stack'][1]))
        for name, rel, label in out['frames']:
            print('     %-38s + 0x%-9x %s' % (name, rel, label))
        mods = [os.path.basename(m[2]).lower() for m in out['modules']]
        print('   modules notables :', ', '.join(m for m in mods if m in ('ue4ss.dll', 'dwmapi.dll', 'gameoverlayrenderer64.dll',
              'discordhook64.dll', 'nvwgf2umx.dll', 'steam_api64.dll', 'rtsshooks64.dll', 'graphics-hook64.dll', 'owclient.dll')))

if __name__ == '__main__':
    main()
