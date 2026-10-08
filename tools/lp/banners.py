"""Checks the banners of the mod (lpr_strings.lua) against the width the game's banner can show.

A banner longer than the width is cut into several, shown one after the other: a cut that leaves a
"%" or a single word alone on the last one reads badly. This tool writes every banner with typical
values (a player's name, a number, an item, a key) and cuts it the way the mod does (U.wrap in
lpr_util.lua, ported below). It fails when:
  - a banner that carries no player's name does not fit in one piece (unless listed in LONG below:
    messages for the host, read at leisure);
  - any piece is very short, or made of signs only.

Usage: python banners.py [--all]      (--all: every banner, not only those cut in several)
"""
import io, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', '..', 'mod', 'LPRoles', 'Scripts')
def read(name): return io.open(os.path.join(D, name), encoding='utf-8').read()
strings, client, game = read('lpr_strings.lua'), read('lpr_client.lua'), read('lpr_game.lua')

WIDTH = int(re.search(r'G\.BANNER_WIDTH = (\d+)', game).group(1))
SHORT = 6                      # a piece under this many characters is a leftover
# Not banners (menu texts, lines of the role page), or made of several banners on purpose.
NOT_BANNERS = {'MENU_TAB', 'MENU_ROLE', 'MENU_NO_ROLE', 'MENU_HOST_ONLY', 'MENU_SECTION', 'MENU_ROLES', 'LINK_LINE', 'LINK_OVER'}
LONG = {'HOST_SHORT', 'MENU_TAB_OFF', 'TABLET_OFF', 'VERSION_DIFF', 'INSTALL_BROKEN', 'DIAG_BACK'}

# What each "%s" / "%d" stands for: the message table of lpr_client.lua says it for the messages
# the host sends; the others are listed here.
KINDS = dict(re.findall(r'(\w+) = \{ "\w+", "(\w+)"', re.search(r'local MSG = \{(.*?)\n\}', client, re.S).group(1)))
KINDS.update(SAFE_PERSON='name', USE_HINT='pkey', MOD_ACK='version', VERSION_DIFF='version', UPDATED='version',
             DIAG_OK='version', DIAG_BACK='version', REVEAL='role+name', REVEAL_LINK='name')
ITEMS = re.findall(r'"([^"]+)"', re.search(r'S\.ITEM_SHORT = \{(.*?)\n\}', strings, re.S).group(1))
ROLES = re.findall(r'=\s*"([^"]+)"', re.search(r'S\.ROLE_NAME = \{(.*?)\n\}', strings, re.S).group(1))
SAMPLES = {'name': ['Lea', 'NomDeJoueur1', 'UnPseudoVraimentLong'], 'item': [max(ITEMS, key=len)], 'num': ['5', '60'],
           'pkey': ['B', 'SOURIS 5'], 'plant': ['G3M'], 'version': ['0.11.10'], None: ['5', '180'],
           'role+name': None}

def length(s): return len(s)

def wrap(text, width):
    """U.wrap of lpr_util.lua."""
    words = []
    for word in text.split():
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

def main():
    show_all = '--all' in sys.argv
    problems, cut, count = [], 0, 0
    for name, text in banners():
        for t, named in filled(name, text):
            count += 1
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
    print('\n%d bandeaux écrits (largeur %d caractères), %d coupés en plusieurs' % (count, WIDTH, cut))
    if problems:
        print('\nPROBLÈMES :')
        for p in sorted(set(problems)): print('  - ' + p)
        sys.exit(1)
    print('OK : aucun bandeau sans nom de joueur n\'est coupé, aucun morceau n\'est un reste')

if __name__ == '__main__':
    main()
