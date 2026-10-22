"""Checks the banners of the mod (lpr_strings.lua, and each random event's M.TEXT in lpr_evm_*.lua)
against the width the game's banner can show.

A banner longer than the width is cut into several, shown one after the other: a cut that leaves a
"%" or a single word alone on the last one reads badly. This tool writes every banner with typical
values (a player's name, a number, an item, a key, a sector, a weapon, a time) and cuts it the way the
mod does (U.wrap in lpr_util.lua, ported below). It fails when:
  - a banner that carries no player's name does not fit in one piece (unless listed in LONG below:
    messages for the host, read at leisure);
  - any piece is very short, or made of signs only;
  - a random event's notice (the line at the top of the screen, `n = true` in M.TEXT: one line only,
    never cut) does not fit in the width with the longest name, as a notice writes it (cut to
    EV.NOTICE_NAME characters, lpr_ev.lua);
  - an event's text is malformed: a kind of value the mod does not know, not as many values as
    "%s", a colour that is not one of S.COLOR (also checked for M.LINES and M.RECAP);
  - an event's text (M.TEXT, M.LINES, M.RECAP) holds a sign the banner font is not known to have
    ("→", "…", "×"), or the word "bâtiment" (the game takes place in a spaceship: "vaisseau").

Usage: python banners.py [--all]      (--all: every banner, not only those cut in several)
"""
import glob, io, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', '..', 'mod', 'LPRoles', 'Scripts')
def read(name): return io.open(os.path.join(D, name), encoding='utf-8').read()
strings, client, game, ev = read('lpr_strings.lua'), read('lpr_client.lua'), read('lpr_game.lua'), read('lpr_ev.lua')

WIDTH = int(re.search(r'G\.BANNER_WIDTH = (\d+)', game).group(1))
NOTICE_NAME = int(re.search(r'EV\.NOTICE_NAME = (\d+)', ev).group(1))
SHORT = 6                      # a piece under this many characters is a leftover
# Not banners (menu texts, lines of the role page), or made of several banners on purpose.
NOT_BANNERS = {'MENU_TAB', 'MENU_ROLE', 'MENU_NO_ROLE', 'MENU_HOST_ONLY', 'MENU_SECTION', 'MENU_ROLES', 'LINK_LINE', 'LINK_OVER'}
LONG = {'HOST_SHORT', 'MENU_TAB_OFF', 'TABLET_OFF', 'VERSION_DIFF', 'INSTALL_BROKEN', 'DIAG_BACK'}

def lua_text(s):
    """A Lua string's content: the escapes the mod's texts use."""
    s = re.sub(r'\\u\{([0-9A-Fa-f]+)\}', lambda m: chr(int(m.group(1), 16)), s)
    return s.replace('\\"', '"').replace('\\n', '\n')

# What each "%s" / "%d" stands for: the message table of lpr_client.lua says it for the messages
# the host sends; the others are listed here.
KINDS = dict(re.findall(r'(\w+) = \{ "\w+", "(\w+)"', re.search(r'local MSG = \{(.*?)\n\}', client, re.S).group(1)))
KINDS.update(SAFE_PERSON='name', USE_HINT='pkey', MOD_ACK='version', VERSION_DIFF='version', UPDATED='version',
             DIAG_OK='version', DIAG_BACK='version')
ITEMS = re.findall(r'"([^"]+)"', re.search(r'S\.ITEM_SHORT = \{(.*?)\n\}', strings, re.S).group(1))
ROLES = re.findall(r'=\s*"([^"]+)"', re.search(r'S\.ROLE_NAME = \{(.*?)\n\}', strings, re.S).group(1))
def block_after(src, start):
    """The text between the braces that open at src[start] (strings and comments may hold braces)."""
    depth, k = 0, start
    while k < len(src):
        c = src[k]
        if c == '"':
            k += 1
            while src[k] != '"': k += 2 if src[k] == '\\' else 1
        elif c == '-' and src[k:k + 2] == '--':
            while k < len(src) and src[k] != '\n': k += 1
            continue
        elif c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: return src[start + 1:k]
        k += 1
    return ''

def table_values(name):
    m = re.search(name + r'\s*=\s*\{', strings)
    return [lua_text(v) for v in re.findall(r'"((?:[^"\\]|\\.)*)"', block_after(strings, m.end() - 1))]
SECTORS, ROOMS = table_values(r'S\.SECTOR'), table_values(r'S\.ROOM')
WEAPONS, WEAPONS_LOW = table_values(r'S\.WEAPON'), table_values(r'S\.WEAPON_LOW')
COLORS = set(re.findall(r'^\s*(\w+)\s*=\s*\{', re.search(r'S\.COLOR = \{(.*?)\n\}', strings, re.S).group(1), re.M))
NAMES = ['Lea', 'NomDeJoueur1', 'UnPseudoVraimentLong']
SAMPLES = {'name': NAMES, 'item': [max(ITEMS, key=len)], 'num': ['5', '60'],
           'pkey': ['B', 'SOURIS 5'], 'plant': ['G3M'], 'version': ['0.11.10'], None: ['5', '180'],
           'role+name': None}
# The kinds of value of the random events' texts (lpr_ev.lua EV.KINDS, written by lpr_recap.lua R.arg).
EVENT_SAMPLES = {'name': NAMES, 'names': [', '.join(NAMES[:i]) for i in (1, 2, 3)], 'num': ['5', '180'],
                 'clock': ['0:30', '10:00'], 'sector': [max(SECTORS, key=len)], 'sector_low': [max(ROOMS, key=len)],
                 'room': [max(ROOMS, key=len)], 'weapon': [max(WEAPONS, key=len)], 'key': ['B', 'SOURIS 5']}
NAMED = {'name', 'names'}
NUMERIC = {'name', 'num', 'clock', 'sector', 'sector_low', 'room', 'weapon'}
# Never in an event's text: signs the banner font may lack (named here: a Windows console cannot
# print them), and the wrong setting (a spaceship).
EVENT_BANNED_SIGNS = {'→': 'U+2192 flèche', '…': 'U+2026 points de suspension', '×': 'U+00D7 signe fois'}
EVENT_BANNED_WORD = re.compile(r'b[âa]timent', re.I)

def length(s): return len(s)

def words_of(text):
    """Words as Lua's %S+ cuts them: at plain spaces only (a non-breaking space ties two words)."""
    return [w for w in re.split(r'[ \t\n\r\f\v]+', text) if w]

def wrap(text, width):
    """U.wrap of lpr_util.lua."""
    words = []
    for word in words_of(text):
        prev = words[-1] if words else None
        if prev and (re.match(r'^[%:;!?)]+$', word) or (re.match(r'^[A-Za-z][.)]*$', word) and re.search(r'\d$', prev))
                     or (re.match(r'^\d+$', word) and prev.endswith('SOURIS'))):
            words[-1] = prev + ' ' + word
        else:
            words.append(word)
    def fill(limit):
        lines, line = [], None
        for w in words:
            if line is not None and len(line) + 1 + len(w) <= limit: line += ' ' + w
            else:
                if line is not None: lines.append(line)
                line = w
        if line is not None: lines.append(line)
        return lines
    best = fill(width)
    if len(best) <= 1: return best
    total = len(' '.join(words))
    for limit in range(math.ceil(total / len(best)), width):
        lines = fill(limit)
        if len(lines) <= len(best): return lines
    return best

def banners():
    out = [(n, t) for n, t in re.findall(r'^S\.([A-Z_]+)\s*=\s*"((?:[^"\\]|\\.)*)"', strings, re.M) if n not in NOT_BANNERS]
    block = re.search(r'S\.ROLE_BANNER = \{(.*?)\n\}', strings, re.S).group(1)
    for role, lines in re.findall(r'(\w+)\s*=\s*\{([^}]*)\}', block):
        for i, l in enumerate(re.findall(r'"([^"]*)"', lines)): out.append(('ROLE_BANNER.%s.%d' % (role, i + 1), l))
    return out

def filled(name, text):
    """The banner with each set of typical values: (text, carries a player's name)."""
    kind = KINDS.get(name)
    text = text.replace('%%', '\0')
    if kind == 'role+name':
        vals = [(max(ROLES, key=len), n) for n in SAMPLES['name']]
        return [(text.replace('%s', a, 1).replace('%s', b, 1).replace('\0', '%'), True) for a, b in vals]
    out = []
    for v in SAMPLES.get(kind, SAMPLES[None]) if ('%s' in text or '%d' in text) else ['']:
        t = re.sub(r'%d', v if v.isdigit() else '180', text).replace('%s', v).replace('\0', '%')
        out.append((t, kind == 'name'))
    return out

# ---------------------------------------------------------------- the random events' modules
def entries(src, field):
    """M.<field> = { KEY = { "fmt", "kind", ..., c = "...", n = true }, ... } as
    { KEY: (fmt, [kinds], colour, notice) }."""
    m = re.search(r'M\.' + field + r'\s*=\s*\{', src)
    if not m: return {}
    body = block_after(src, m.end() - 1)
    out = {}
    for e in re.finditer(r'(\w+)\s*=\s*\{', body):
        inner = block_after(body, e.end() - 1)
        inner_nc = re.sub(r'--[^\n]*', '', inner)
        keyed = dict(re.findall(r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|\w+)', inner_nc))
        plain = re.sub(r'\w+\s*=\s*("(?:[^"\\]|\\.)*"|\w+)', '', inner_nc)
        texts = [lua_text(s) for s in re.findall(r'"((?:[^"\\]|\\.)*)"', plain)]
        if not texts: continue
        colour = keyed.get('c', '').strip('"') or None
        out[e.group(1)] = (texts[0], texts[1:], colour, keyed.get('n') == 'true')
    return out

def formats(fmt):
    return len(re.findall(r'%[sd]', fmt.replace('%%', '')))

def event_texts(problems):
    """Every module's banners and notices, filled with typical values: (name, text, named, notice)."""
    out = []
    for path in sorted(glob.glob(os.path.join(D, 'lpr_evm_*.lua'))):
        src = io.open(path, encoding='utf-8').read()
        mod = os.path.basename(path)[8:-4]
        for field in ('TEXT', 'LINES', 'RECAP'):
            for key, (fmt, kinds, colour, notice) in entries(src, field).items():
                name = '%s.%s.%s' % (mod, field, key)
                for sign, sign_name in EVENT_BANNED_SIGNS.items():
                    if sign in fmt: problems.append('%s : signe interdit (%s, police du jeu) dans « %s »' % (name, sign_name, fmt))
                if EVENT_BANNED_WORD.search(fmt): problems.append('%s : « bâtiment » : le jeu se passe dans un vaisseau, dans « %s »' % (name, fmt))
                bad = [k for k in kinds if k not in EVENT_SAMPLES]
                if bad: problems.append('%s : type de valeur inconnu %s' % (name, bad)); continue
                if formats(fmt) != len(kinds): problems.append('%s : %d valeurs pour %d « %%s »' % (name, len(kinds), formats(fmt)))
                if colour and colour not in COLORS: problems.append('%s : couleur inconnue « %s »' % (name, colour))
                if field == 'RECAP':
                    if not re.match(r'^ev_%s(_[a-z0-9_]+)?$' % re.escape(mod), key): problems.append('%s : nom de récapitulatif (ev_%s...)' % (name, mod))
                    if len(kinds) > 2 or any(k not in NUMERIC for k in kinds): problems.append('%s : deux nombres au plus (nom, nombre, chrono, secteur, arme)' % name)
                if field != 'TEXT': continue
                rounds = max([len(EVENT_SAMPLES[k]) for k in kinds] or [1])
                for i in range(rounds):
                    vals = []
                    for k in kinds:
                        v = EVENT_SAMPLES[k][min(i, len(EVENT_SAMPLES[k]) - 1)]
                        if notice and k in NAMED: v = ', '.join(n[:NOTICE_NAME] for n in v.split(', '))
                        vals.append(v)
                    t = fmt.replace('%%', '\0')
                    for v in vals: t = re.sub(r'%[sd]', lambda _m, v=v: v, t, count=1)
                    out.append((name, t.replace('\0', '%'), any(k in NAMED for k in kinds), notice))
    return out

def main():
    # a sign the console cannot write (a "→" in a module's text) is shown as "?" instead of stopping the tool
    if hasattr(sys.stdout, 'reconfigure'): sys.stdout.reconfigure(errors='replace')
    show_all = '--all' in sys.argv
    problems, cut, count = [], 0, 0
    texts = [(name, t, named, False) for name, text in banners() for t, named in filled(name, text)]
    texts += event_texts(problems)
    notices = 0
    for name, t, named, notice in texts:
        count += 1
        if notice:
            notices += 1
            if show_all: print('%-24s %2d car. (avis) %s' % (name, length(t), t))
            if length(t) > WIDTH: problems.append('%s : avis de %d caractères (une seule ligne de %d) : « %s »' % (name, length(t), WIDTH, t))
            continue
        lines = wrap(t, WIDTH)
        too_long = [l for l in lines if length(l) > WIDTH]
        leftovers = [l for l in lines if len(lines) > 1 and (length(l) < SHORT or not re.search(r'\w', l))]
        if len(lines) > 1: cut += 1
        if show_all or len(lines) > 1:
            print('%-24s %2d car. %s' % (name, length(t), '  |  '.join(lines)))
        if too_long: problems.append('%s : un mot ne tient pas dans la largeur : « %s »' % (name, too_long[0]))
        if leftovers: problems.append('%s : morceau trop court « %s » dans « %s »' % (name, leftovers[0], t))
        if len(lines) > 1 and not named and name not in LONG and KINDS.get(name) != 'role+name':
            problems.append('%s : %d caractères, %d bandeaux à la suite pour « %s »' % (name, length(t), len(lines), t))
    print('\n%d bandeaux écrits (largeur %d caractères), %d coupés en plusieurs ; %d avis du haut' % (count - notices, WIDTH, cut, notices))
    if problems:
        print('\nPROBLÈMES :')
        for p in sorted(set(problems)): print('  - ' + p)
        sys.exit(1)
    print('OK : aucun bandeau sans nom de joueur n\'est coupé, aucun morceau n\'est un reste, chaque avis tient sur sa ligne')

if __name__ == '__main__':
    main()
