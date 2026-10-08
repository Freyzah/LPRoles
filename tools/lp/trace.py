"""Follow one Blueprint event through its ubergraph and print it as a readable flow.

Usage: python trace.py <dump file stem, e.g. Character__Mec> "<Function Name>" [max_lines]
Reads the text dumps produced by bp.py (analysis/bp/*.txt).
"""
import os, re, sys

BP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "analysis", "bp")
NL = "\n"

def load(stem):
    funcs, cur = {}, None
    for line in open(os.path.join(BP, stem + ".txt"), encoding="utf-8"):
        m = re.match(r"  function (.+?)\((.*)$", line)
        if m:
            cur = m.group(1); funcs[cur] = {"sig": line.strip(), "code": []}; continue
        m = re.match(r"    ([0-9a-f]{4,}): (.*)$", line)
        if m and cur: funcs[cur]["code"].append((int(m.group(1), 16), m.group(2)))
    return funcs

def flow(code, entry, limit=400):
    """Linearise from `entry`: follow pops to pushed addresses and unconditional gotos; queue branch targets."""
    idx = {a: i for i, (a, _) in enumerate(code)}
    out, seen, queue, done_blocks = [], set(), [(entry, [])], set()
    while queue and len(out) < limit:
        start, stack = queue.pop(0)
        if start in done_blocks or start not in idx: continue
        done_blocks.add(start)
        out.append(f"  @{start:04x}:")
        i = idx[start]; stack = list(stack)
        while i < len(code) and len(out) < limit:
            a, s = code[i]
            if a in seen and a != start:
                out.append(f"      -> joins @{a:04x}"); break
            seen.add(a)
            m = re.match(r"push (0x[0-9a-f]+)$", s)
            if m: stack.append(int(m.group(1), 16)); i += 1; continue
            if s == "pop":
                if not stack: out.append("      end"); break
                t = stack.pop()
                if t not in idx or t in seen: out.append(f"      -> continues @{t:04x}"); break
                i = idx[t]; continue
            m = re.match(r"if not \((.*)\) pop$", s)
            if m:
                out.append(f"      if not ({m.group(1)}): " + (f"continue @{stack[-1]:04x}" if stack else "end"))
                if stack: queue.append((stack[-1], stack[:-1]))
                i += 1; continue
            m = re.match(r"goto (0x[0-9a-f]+)$", s)
            if m:
                t = int(m.group(1), 16)
                if t in seen or t not in idx: out.append(f"      -> loops/joins @{t:04x}"); break
                i = idx[t]; continue
            m = re.match(r"if not \((.*)\) goto (0x[0-9a-f]+)$", s)
            if m:
                t = int(m.group(2), 16)
                out.append(f"      if not ({m.group(1)}): goto @{t:04x}")
                queue.append((t, stack)); i += 1; continue
            if s.startswith("return"): out.append("      " + s); break
            out.append(f"      {s}")
            m = re.search(r"LatentActionInfo\{skipoffset\((0x[0-9a-f]+)\)", s)
            if m:
                t = int(m.group(1), 16); out.append(f"      (latent: resumes @{t:04x})"); queue.append((t, []))
            i += 1
    return out

TEMP = re.compile(r"^((?:CallFunc_|K2Node_DynamicCast_|K2Node_SwitchEnum_|K2Node_SwitchInteger_|K2Node_MakeStruct_"
                  r"|K2Node_CreateDelegate_|K2Node_Select_|K2Node_MakeArray_|Temp_)[A-Za-z0-9_]+) = (.*)$")
PURE = ("Array_Length", "Array_Contains", "Array_LastIndex", "Not_", "Boolean", "conv", "Make", "Select", "switch",
        "Equal", "NotEqual", "Less", "Greater", "Add_", "Subtract", "Multiply", "Divide", "IsValid", "Conv_",
        "cast<", "Break", "Get", "Abs", "Normal", "VSize", "Clamp", "Concat", "FTrunc", "Round", "K2_Get",
        "IsLocallyControlled", "HasAuthority", "bind(", "FClamp", "Lerp", "Max", "Min", "FMax", "FMin")

def inline(lines):
    """Fold temporaries (results of pure nodes) into the statements that use them."""
    out, pending = [], {}

    def leftovers(indent="      "):
        for k, (v, used) in pending.items():
            if not used and "(" in v and not v.startswith(PURE) and "." not in v.split("(")[0][-0:0]:
                out.append(f"{indent}{v}")
                pending[k][1] = True

    def subst(text):
        for _ in range(8):
            changed = False
            for k in sorted(pending, key=len, reverse=True):
                pat = r"(?<![A-Za-z0-9_])" + re.escape(k) + r"(?![A-Za-z0-9_])"
                if k in text and re.search(pat, text):
                    val = pending[k][0]
                    text = re.sub(pat, lambda m: val, text)
                    pending[k][1] = True; changed = True
            if not changed: break
        return text

    for raw in lines:
        indent = raw[:len(raw) - len(raw.lstrip())]; body = raw.strip()
        if body.startswith(("@", "(latent", "->")) or body == "end":
            leftovers()
            if body.startswith("@"): pending.clear()
            out.append(raw); continue
        body = subst(body)
        m = TEMP.match(body)
        if m and len(m.group(2)) < 260:
            old = pending.get(m.group(1))
            if old and not old[1] and "(" in old[0] and not old[0].startswith(PURE):
                out.append(f"{indent}{old[0]}")
            pending[m.group(1)] = [m.group(2), False]; continue
        out.append(indent + body)
    leftovers()
    return out

def show(stem, name, limit=400):
    funcs = load(stem)
    if name not in funcs:
        cands = [n for n in funcs if name.lower() in n.lower()]
        print("no exact match; candidates:", cands); return
    f = funcs[name]
    print(f["sig"])
    uber = next((n for n in funcs if n.startswith("ExecuteUbergraph")), None)
    entry = None; direct = []
    for a, s in f["code"]:
        m = re.match(r"ExecuteUbergraph_\w+\((\d+)\)", s)
        if m: entry = int(m.group(1))
        else: direct.append(f"    {s}")
    if entry is None or len(direct) > 3:
        code = f["code"]
        if code and any(re.match(r"(push|pop|goto|if not)", c) for _, c in code):
            print(NL.join(inline(flow(code, code[0][0], limit))))
        else:
            print(NL.join(inline(direct)))
    else:
        for d in direct:
            if "return nothing" not in d: print(d)
    if entry is not None and uber:
        print(f"  -- ubergraph entry {entry:#06x}")
        print(NL.join(inline(flow(funcs[uber]["code"], entry, limit))))

def dump(stem, out, names=None, limit=260, skip=()):
    import contextlib
    f = load(stem)
    path = os.path.join(BP, "..", "traces", out + ".txt")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh, contextlib.redirect_stdout(fh):
        for n in f:
            if n.startswith("ExecuteUbergraph") or "DelegateSignature" in n: continue
            if names and not any(k.lower() in n.lower() for k in names): continue
            if any(n.startswith(s) for s in skip): continue
            print("=" * 30); show(stem, n, limit)

if __name__ == "__main__":
    if sys.argv[1] == "--dump":
        dump(sys.argv[2], sys.argv[3], sys.argv[4].split(",") if len(sys.argv) > 4 and sys.argv[4] else None)
    else:
        lim = int(sys.argv[3]) if len(sys.argv) > 3 else 400
        show(sys.argv[1], sys.argv[2], lim)
