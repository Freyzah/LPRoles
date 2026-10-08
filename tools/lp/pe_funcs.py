import struct, sys, re
path = sys.argv[1]
rvas = [int(x, 16) for x in sys.argv[2:]]
d = open(path, 'rb').read()
pe = struct.unpack_from('<I', d, 0x3c)[0]
nsec = struct.unpack_from('<H', d, pe + 6)[0]
optsz = struct.unpack_from('<H', d, pe + 20)[0]
opt = pe + 24
imagebase = struct.unpack_from('<Q', d, opt + 24)[0]
ddir = opt + 112
exc_rva, exc_size = struct.unpack_from('<II', d, ddir + 3 * 8)
secs = []
for i in range(nsec):
    o = opt + optsz + i * 40
    name = d[o:o + 8].rstrip(b'\0').decode()
    vsize, va, rsize, raw = struct.unpack_from('<IIII', d, o + 8)
    secs.append((name, va, vsize, raw, rsize))
def r2o(rva):
    for n, va, vs, raw, rs in secs:
        if va <= rva < va + max(vs, rs): return raw + rva - va
    return None
def sec_of(rva):
    for n, va, vs, raw, rs in secs:
        if va <= rva < va + max(vs, rs): return n
funcs = []
o = r2o(exc_rva)
for i in range(exc_size // 12):
    b, e, u = struct.unpack_from('<III', d, o + i * 12)
    funcs.append((b, e, u))
funcs.sort()
import bisect
starts = [f[0] for f in funcs]
def func_of(rva):
    i = bisect.bisect_right(starts, rva) - 1
    if i >= 0 and funcs[i][0] <= rva < funcs[i][1]: return funcs[i]
def read_str(rva):
    off = r2o(rva)
    if off is None: return None
    # ascii
    m = re.match(rb'[\x20-\x7e]{4,200}', d[off:off + 200])
    if m and d[off + len(m.group(0))] == 0: return 'A:' + m.group(0).decode()
    # utf-16
    s = []
    for k in range(0, 400, 2):
        c = struct.unpack_from('<H', d, off + k)[0]
        if c == 0: break
        if not (0x20 <= c < 0x7f): s = None; break
        s.append(chr(c))
    if s and len(s) >= 4: return 'W:' + ''.join(s)
    return None
def strings_in(b, e):
    out = []
    ob = r2o(b)
    code = d[ob:ob + (e - b)]
    for k in range(len(code) - 7):
        # REX.W/R LEA reg, [rip+disp32]  -> 48/4C 8D modrm(00 reg 101)
        if code[k] in (0x48, 0x4c) and code[k + 1] == 0x8d and (code[k + 2] & 0xc7) == 0x05:
            disp = struct.unpack_from('<i', code, k + 3)[0]
            tgt = b + k + 7 + disp
            if sec_of(tgt) in ('.rdata', '.data'):
                s = read_str(tgt)
                if s: out.append((b + k, s))
    return out
print('sections', [(s[0], hex(s[1]), hex(s[2])) for s in secs])
for rva in rvas:
    f = func_of(rva)
    if not f: print(hex(rva), 'no func'); continue
    print('=== rva %x in func %x-%x (+%x)' % (rva, f[0], f[1], rva - f[0]))
    ss = strings_in(f[0], f[1])
    for at, s in ss[:25]: print('   %x %s' % (at, s[:160]))
