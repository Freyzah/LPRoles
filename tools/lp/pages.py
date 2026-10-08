"""Shows every role's page (tablet and LPROLES tab) as the mod writes it.

A port of lpr_roletext.lua (fill, status_line, lines, segments, wrap) and of the host's
status_of (lpr_server.lua), fed with the texts of lpr_strings.lua and the settings of
lpr_config.lua (defaults, or a config.txt given as argument). Used to proofread the
descriptions without launching the game: python tools/lp/pages.py [config.txt]
Fails if a value is missing in a line ("?"), or if a page has too many lines.
"""
import io, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', '..', 'mod', 'LPRoles', 'Scripts')
def read(name): return io.open(os.path.join(D, name), encoding='utf-8').read()
src, cfg, rt = read('lpr_strings.lua'), read('lpr_config.lua'), read('lpr_roletext.lua')
tablet, menu, server = read('lpr_tablet.lua'), read('lpr_menu.lua'), read('lpr_server.lua')

STR = r'"((?:[^"\\]|\\.)*)"'
def lua_str(s): return s.replace('\\"', '"')

def block(name):
    """Text between the braces of `name = { ... }` (strings may hold braces)."""
    i = src.index(name + ' = {') + len(name) + 3
    k, depth = i + 1, 0
    while True:
        c = src[k]
        if c == '"':
            k += 1
            while src[k] != '"': k += 2 if src[k] == '\\' else 1
        elif c == '{': depth += 1
        elif c == '}':
            if depth == 0: break
            depth -= 1
        k += 1
    return src[i + 1:k]

# sentences shared by several roles: local NAME = "..." above the table
SHARED = {m.group(1): lua_str(m.group(2)) for m in re.finditer(r'^local ([A-Z_]+) = ' + STR, src, re.M)}
HOWTO = {}
for m in re.finditer(r'(\w+)\s*=\s*\{(.*?)\},', block('S.ROLE_HOWTO'), re.S):
    HOWTO[m.group(1)] = [lua_str(r[1:-1]) if r.startswith('"') else SHARED[r]
                         for r in re.findall(r'"(?:[^"\\]|\\.)*"|\b[A-Z_]+\b', m.group(2))]
def kv(name): return {k: lua_str(v) for k, v in re.findall(r'(\w+)\s*=\s*' + STR, block(name))}
RECH, STAT = kv('S.RECHARGE'), kv('S.STATUS')
ITEM = {int(k): lua_str(v) for k, v in re.findall(r'\[(\d+)\]\s*=\s*' + STR, block('S.ITEM_NAME'))}
LINK = lua_str(re.search(r'S\.LINK_LINE = ' + STR, src).group(1))
LINK_OVER = lua_str(re.search(r'S\.LINK_OVER = ' + STR, src).group(1))
TENTHS = set(re.findall(r'(\w+) = true', re.search(r'RT\.TENTHS = \{(.*?)\}', rt, re.S).group(1)))
HOST_TENTHS = set(re.findall(r'(\w+) = true', re.search(r'local TENTHS = \{(.*?)\}', server, re.S).group(1)))
ITEMS = re.findall(r'"(\w+)"', re.search(r'local ITEMS = \{(.*?)\}', cfg).group(1))
TABLET_LINES = int(re.search(r'local LINES = (\d+)', tablet).group(1))
MENU_ROWS = int(re.search(r'local HELP_ROWS = (\d+)', menu).group(1))
MENU_WIDTH = int(re.search(r'local HELP_WIDTH = (\d+)', menu).group(1))

DEF = {}
for m in re.finditer(r'\{ key = "(\w+)",\s*group = "[^"]*",\s*default = ("[^"]*"|[\w.]+)', cfg):
    v = m.group(2)
    DEF[m.group(1)] = v[1:-1] if v.startswith('"') else (v == 'true' if v in ('true', 'false') else float(v))

def load_config(path):
    c = dict(DEF)
    for line in io.open(path, encoding='utf-8'):
        m = re.match(r'^\s*(\w+)\s*=\s*(.*?)\s*$', line)
        if m and m.group(1) in c:
            d, t = c[m.group(1)], m.group(2)
            c[m.group(1)] = (t.lower() in ('true', '1', 'oui', 'on')) if isinstance(d, bool) else (float(t) if isinstance(d, float) else t)
    return c

NAMES = {1: 'Alice', 2: 'Bob'}

# ---------------------------------------------------------------- lpr_roletext.lua
def number(v): return '%d' % v if v == int(v) else ('%.1f' % v).replace('.', ',')

# the two personal keys as the pages write them (LPR_KEYS="SOURIS 4,SOURIS 5" for the longest names)
KEY, PKEY = (os.environ.get('LPR_KEYS') or 'G,B').split(',')
def fill(t, v, key=KEY, pkey=PKEY):
    def rep(m):
        k = m.group(1)
        if k == 'item': return ITEM.get(v.get(k), '?')
        if k == 'key': out = key
        elif k == 'pkey': out = pkey
        elif v.get(k) is None: out = '?'
        elif k in ('tgt', 'safe', 'link', 'exlink'): out = NAMES.get(v[k], '?').replace('*', '')
        else: out = number(v[k])
        return '*' + out + '*'
    return re.sub(r'\{(\w+)\}', rep, t)

def isset(v, k): return v.get(k) not in (None, 0)
def can_recharge(v): return isset(v, 'item') and (v.get('rmax') is None or isset(v, 'rleft'))

def status_line(role, v):
    st = STAT
    if role in ('dreamer', 'fairy'):
        if isset(v, 'act'): return fill(st['dream_on'] if role == 'dreamer' else st['fly_on'], v)
        if isset(v, 'n'): return st['charge_ready']
        return st['charge_empty'] if can_recharge(v) else st['charge_gone']
    elif role == 'medium':
        if isset(v, 'act'): return fill(st['vision_on'] + st['uses_too'], v)
    elif role == 'angel':
        if not isset(v, 'tgt'): return st['no_protege']
        return fill(st['protege_saved'] if isset(v, 'saved') else st['protege'], v)
    elif role == 'tracker':
        if isset(v, 'act'): return fill(st['track_on'] + st['uses_too'], v)
    elif role == 'mimic':
        if isset(v, 'act'): return fill(st['disguise_on'] + st['uses_too'], v)
    elif role == 'stowaway':
        if isset(v, 'act'): return fill(st['hide_on'] + st['uses_too'], v)
    elif role == 'infector':
        if isset(v, 'conv'): return fill(st['recruit_pending'], v)
        if isset(v, 'wait'): return fill(st['recruit_wait'], v)
        return fill(st['recruits'], v)
    elif role == 'sheriff':
        if isset(v, 'safe'): return fill(st['safe'], v)
        return st['no_safe'] if isset(v, 'info') else st['no_safe_info']
    elif role == 'martyr': return st['martyr_name'] if isset(v, 'reveal') else st['martyr_camp']
    elif role == 'mole': return st['mole']
    elif role == 'revenant':
        if isset(v, 'act'): return fill(st['spirit_on'], v)
        return fill(st['spirit_left'] if isset(v, 'dead') else st['spirit_later'], v)
    if v.get('m') is not None: return fill(st['uses'], v)
    return None

def lines(role, status, safe_idx=None):
    out, v = [], dict(status or {})
    if not role:
        if isset(v, 'link'): out.append(fill(LINK, v))
        if isset(v, 'exlink'): out.append(fill(LINK_OVER, v))
        return out + HOWTO['none']
    if status is None: return [STAT['waiting']]
    if safe_idx is not None and v.get('safe') is None and v.get('info') is None: v['safe'] = safe_idx + 1
    st = status_line(role, v)
    if st: out.append(st)
    if isset(v, 'link'): out.append(fill(LINK, v))
    if isset(v, 'exlink'): out.append(fill(LINK_OVER, v))
    for l in HOWTO.get(role, []):
        m = re.match(r'^([?!])(\w+) (.*)$', l)
        if m:
            if (m.group(1) == '?') == isset(v, m.group(2)): out.append(fill(m.group(3), v))
        else:
            out.append(fill(l, v))
    if isset(v, 'item'):
        if can_recharge(v):
            l = RECH['more'] if (v.get('m') or 1) > 1 else RECH['one']
            if v.get('rmax') is not None: l += RECH['limit']
            out.append(fill(l + '.', v))
            if isset(v, 'eyes'): out.append(fill(RECH['eyes'], v))
        else:
            out.append(RECH['spent'])
    return out

def orphan(word):
    """A word that must not start a row: a lone punctuation mark or a unit."""
    return re.match(r'^[:;!?]$', word) is not None or re.match(r'^[sm][.,)]*$', word) is not None

def clings(word, before):
    if re.match(r'^[:;!?]$', word): return True
    if re.match(r'^\d[.,)]*$', word) and before.endswith('SOURIS'): return True
    return re.match(r'^[sm][.,)]*$', word) is not None and re.search(r'\d$', before) is not None

def segments(line):
    out, em, i = [], False, 0
    while i < len(line):
        star = line.find('*', i)
        chunk = line[i:star if star >= 0 else len(line)]
        if not em and out and out[-1][1]:
            m = re.match(r'^[.,;)]+', chunk)
            if m:
                out[-1][0] += m.group()
                chunk = chunk[len(m.group()):]
        for w in chunk.split():
            if out and clings(w, out[-1][0]): out[-1][0] += ' ' + w
            else: out.append([w, em])
        if star < 0: break
        em = not em
        i = star + 1
    return out

def plain(l): return l.replace('*', '')

def pack(words, width, indent=''):
    out, cur = [], ''
    for w in words:
        if cur and len(cur) + 1 + len(w) > width:
            out.append(cur)
            cur = indent + w
        elif not cur: cur = w
        else: cur += ' ' + w
    if cur: out.append(cur)
    return out

SHORT = int(re.search(r'local SHORT = (\d+)', rt).group(1))

def wrap(line, width, indent=''):
    words = []
    for w in line.split():
        if words and clings(w, words[-1]): words[-1] += ' ' + w
        else: words.append(w)
    out = pack(words, width, indent)
    if len(out) > 1 and len(out[-1]) < SHORT:
        for narrower in range(width - 4, width // 2 - 1, -4):
            even = pack(words, narrower, indent)
            if len(even) > len(out): break
            out = even
            if len(out[-1]) >= SHORT: break
    return out

# ---------------------------------------------------------------- lpr_server.lua, status_of
ITEM_KEY = {'dreamer': 'dreamer_item', 'fairy': 'fairy_item', 'medium': 'medium_item', 'tracker': 'tracker_item',
            'hypnotist': 'hypno_item', 'mimic': 'mimic_item', 'cleaner': 'cleaner_item', 'stowaway': 'stowaway_item',
            'swapper': 'swapper_item', 'infector': 'infector_item'}

def status_of(role, C, P):
    """What the player's machine has after the host's message (integers, tenths, and back)."""
    g = lambda k: C[k]
    metres = lambda k: g(k) / 100
    v = {'hold': g('dream_hold_seconds'), 'aim': g('aim_hold_seconds')}
    def uses(k): v['n'], v['m'] = P.get('charges', g(k)), g(k)
    if role == 'sheriff':
        # what was really done at the start: the card given, the safe person named
        known = P.get('safe_key', 2 if g('sheriff_safe_info') else None)
        card = P.get('card', 'shown' if g('sheriff_card') else None)
        v.update(card=int(card == 'shown'), walls=int(card == 'shown' and g('sheriff_card_walls')),
                 taken=int(card == 'taken'), info=int(known is not None),
                 marker=g('sheriff_marker_seconds') if known is not None else 0,
                 safe=P.get('safe', known), imm=int(g('sheriff_immune')))
    elif role == 'infector':
        v.update(n=P.get('charges', g('infect_charges')), m=g('infect_charges'), range=metres('infect_range'),
                 ihold=g('infect_hold_seconds'), delay=g('infect_delay_seconds'), early=g('infect_min_game_seconds'),
                 imm=int(g('sheriff_immune')), wait=P.get('wait'), tgt=P.get('tgt'), conv=P.get('conv'))
    elif role == 'dreamer':
        v.update(n=P.get('charges', 1), m=1, dur=g('dream_duration'), eyes=int(g('recharge_by_eyes')), act=P.get('act'))
    elif role == 'fairy':
        v.update(n=P.get('charges', 1), m=1, dur=g('fairy_duration'),
                 ball=int(g('fairy_ball')), glow=int(g('fairy_light') and not g('fairy_ball')),
                 unseen=int(not g('fairy_light') and not g('fairy_ball')), act=P.get('act'))
    elif role == 'medium':
        uses('medium_charges'); v.update(dur=g('medium_duration'), act=P.get('act'))
    elif role == 'angel':
        v.update(range=metres('angel_range'), tgt=P.get('tgt'), saved=int(bool(P.get('saved'))))
    elif role == 'tracker':
        uses('tracker_charges'); v.update(dur=g('tracker_duration'), range=metres('tracker_range'), act=P.get('act'), tgt=P.get('tgt'))
    elif role == 'hypnotist':
        uses('hypno_charges'); v.update(dur=g('hypno_duration'), range=metres('hypno_range'))
    elif role == 'mimic':
        uses('mimic_charges'); v.update(dur=g('mimic_duration'), range=metres('mimic_range'), act=P.get('act'),
                                        keep=int(g('mimic_keep_list_color')), reach=BODY_REACH / 100)
    elif role == 'cleaner':
        uses('cleaner_charges'); v.update(range=metres('cleaner_range'), chold=g('cleaner_hold'))
    elif role == 'stowaway':
        uses('stowaway_charges'); v.update(dur=g('stowaway_duration'), range=metres('stowaway_range'), act=P.get('act'))
    elif role == 'swapper':
        uses('swapper_charges'); v.update(range=metres('swapper_range'))
    elif role == 'martyr':
        v.update(reveal=int(g('martyr_reveal') == 'name'))
    elif role == 'revenant':
        uses('revenant_charges'); v.update(dur=g('revenant_duration'), dead=int(bool(P.get('dead'))), act=P.get('act'))
        if not v['dead']: v['n'] = v['m']
    code = ITEMS.index(g(ITEM_KEY[role])) if role in ITEM_KEY else 0
    if code:
        v['item'] = code
        if g('recharge_limit') > 0:
            v['rmax'], v['rleft'] = g('recharge_limit'), max(0, g('recharge_limit') - P.get('recharges', 0))
    else:
        v.pop('eyes', None)
    if P.get('link'): v['exlink' if P.get('link_done') else 'link'] = P['link']
    wire = {k: int(x * 10 + 0.5) if k in TENTHS else int(x + 0.5)
            for k, x in v.items() if isinstance(x, (int, float))}
    return {k: (x / 10 if k in TENTHS else x) for k, x in wire.items()}

BODY_REACH = float(re.search(r'local BODY_REACH = (\d+)', server).group(1))

ROLES = ['sheriff', 'infector', 'dreamer', 'fairy', 'medium', 'angel', 'mole', 'tracker', 'hypnotist', 'mimic',
         'cleaner', 'stowaway', 'swapper', 'martyr', 'revenant']

def states_of(role):
    out = [('au départ', {})]
    if role in ('medium', 'tracker', 'mimic', 'stowaway'):
        out.append(('effet en cours', {'act': 8, 'charges': 1, 'tgt': 2}))
        out.append(('plus d\'utilisation', {'charges': 0}))
    if role in ('hypnotist', 'cleaner', 'swapper'): out.append(('plus d\'utilisation', {'charges': 0}))
    if role in ('dreamer', 'fairy'): out += [('effet en cours', {'act': 8, 'charges': 0}), ('charge vide', {'charges': 0})]
    if role == 'revenant': out += [('mort', {'dead': 1}), ('mort, se manifeste', {'dead': 1, 'act': 5, 'charges': 0}),
                                   ('mort, apparition utilisée', {'dead': 1, 'charges': 0}),
                                   ('réanimé après une apparition', {'charges': 0})]
    if role == 'sheriff': out += [('personne sûre partie de la partie', {'safe': None, 'safe_key': 9}),
                                  ('carte ramassée', {'card': 'taken'}),
                                  ('ni carte ni personne sûre', {'card': None, 'safe_key': None})]
    if role == 'angel': out += [('protégé choisi', {'tgt': 2}), ('protégé déjà sauvé', {'tgt': 2, 'saved': True})]
    if role == 'infector': out += [('début de partie', {'wait': 42}), ('recrutement fait', {'tgt': 2, 'conv': 30, 'charges': 0})]
    return out

def check(role, ls, problems, where):
    for l in ls:
        if '?' in plain(l): problems.append('%s : valeur manquante dans « %s »' % (where, plain(l)))
        if l.count('*') % 2: problems.append('%s : étoiles non appariées dans « %s »' % (where, l))
        if re.search(r'^[a-zà-ÿ(]', plain(l)): problems.append('%s : ligne qui ne commence pas une phrase « %s »' % (where, plain(l)))
        if not re.search(r'[.!]$', plain(l)) and l is not ls[0]: problems.append('%s : phrase sans point final « %s »' % (where, plain(l)))
    for l in ls[1:]:
        for w, _ in segments(l):
            if orphan(w.split()[0]): problems.append('%s : un morceau commence par « %s »' % (where, w))
    for l in ls:
        for piece in wrap(plain(l), MENU_WIDTH, '   '):
            if orphan(piece.split()[0]): problems.append('%s : une rangée du menu commence par « %s »' % (where, piece.strip()))
    if len(ls) - 1 > TABLET_LINES: problems.append('%s : %d lignes sous l\'état, %d au plus sur la tablette' % (where, len(ls) - 1, TABLET_LINES))
    rows = sum(len(wrap(plain(l), MENU_WIDTH, '   ')) for l in ls)
    if rows > MENU_ROWS: problems.append('%s : %d rangées dans le menu, %d au plus' % (where, rows, MENU_ROWS))

def show(title, ls):
    print('\n== ' + title)
    print('   [ %s ]' % plain(ls[0]))
    for l in ls[1:]:
        print('   - ' + ' | '.join(('<%s>' % w) if em else w for w, em in segments(l)))

def main():
    C = load_config(sys.argv[1]) if len(sys.argv) > 1 else dict(DEF)
    problems, pages = [], 0
    if TENTHS != HOST_TENTHS:
        problems.append('valeurs en dixièmes différentes entre l\'hôte et le joueur : %s' % sorted(TENTHS ^ HOST_TENTHS))
    for role in ROLES:
        for name, P in states_of(role):
            # the player's machine also remembers the safe person named at the announcement
            ls = lines(role, status_of(role, C, P), 1 if role == 'sheriff' else None)
            show('%s, %s' % (role.upper(), name), ls)
            check(role, ls, problems, '%s (%s)' % (role, name))
            pages += 1
    # lines that only other settings bring out
    other = dict(C, recharge_limit=2, recharge_by_eyes=True, martyr_reveal='name', fairy_light=False,
                 infect_delay_seconds=0, infect_min_game_seconds=0, sheriff_immune=False, infector_item='cod',
                 sheriff_card_walls=False, aim_hold_seconds=0)
    for role, name, P in [('dreamer', 'recharge par les yeux, limite 2', {'charges': 0, 'link': 2}),
                          ('dreamer', 'limite atteinte', {'charges': 0, 'recharges': 2}),
                          ('fairy', 'boule sans lumière', {}), ('martyr', 'nom révélé', {}),
                          ('infector', 'sans délai, avec objet', {'charges': 0}),
                          ('sheriff', 'recrutable, carte non vue à travers les murs', {}),
                          ('angel', 'choix immédiat (protégé à garder en vue : 0 s)', {})]:
        ls = lines(role, status_of(role, other, P))
        show('%s, autres réglages : %s' % (role.upper(), name), ls)
        check(role, ls, problems, '%s (%s)' % (role, name))
        pages += 1
    for name, c in [('lumière sans boule', dict(C, fairy_ball=False)),
                    ('ni boule ni lumière', dict(C, fairy_ball=False, fairy_light=False))]:
        ls = lines('fairy', status_of('fairy', c, {}))
        show('FAIRY, autres réglages : ' + name, ls)
        check('fairy', ls, problems, 'fairy (%s)' % name)
        pages += 1
    ls = lines('mimic', status_of('mimic', dict(C, mimic_keep_list_color=False), {}))
    show('MIMIC, autres réglages : couleur de la liste non gardée', ls)
    check('mimic', ls, problems, 'mimic (couleur non gardée)')
    pages += 1
    none = dict(C, dreamer_item='none')
    show('DREAMER, sans objet de recharge, charge utilisée', lines('dreamer', status_of('dreamer', none, {'charges': 0})))
    print('\n== dans le menu, les lignes longues continuent sur la rangée suivante (%d caractères)' % MENU_WIDTH)
    for l in lines('tracker', status_of('tracker', C, {'link': 2})):
        for piece in wrap(plain(l), MENU_WIDTH, '   '): print('   ' + piece)
    # every combination of the settings that change the lines, with a bond, for the worst case
    worst = 0
    for role in ROLES:
        for limit in (0, 2):
            for eyes in (False, True):
                for item in (None, 'none', 'cod'):
                    for used in (0, 2):
                        c = dict(C, recharge_limit=limit, recharge_by_eyes=eyes)
                        if item and role in ITEM_KEY: c[ITEM_KEY[role]] = item
                        for name, P in states_of(role):
                            ls = lines(role, status_of(role, c, dict(P, link=2, recharges=used)))
                            check(role, ls, problems, '%s (%s, limite %d, yeux %s, objet %s)' % (role, name, limit, eyes, item))
                            worst = max(worst, len(ls) - 1)
                            pages += 1
    print('\n== sans rôle, lié')
    for l in lines(None, {'link': 2}): print('   - ' + plain(l))
    ls = lines('angel', status_of('angel', C, {'link': 2, 'link_done': True, 'tgt': 2, 'saved': True}))
    show('ANGEL, lien rompu', ls)
    check('angel', ls, problems, 'angel (lien rompu)')
    print('\n== rôle annoncé, valeurs de l\'hôte pas encore reçues')
    for l in lines('medium', None): print('   [ %s ]' % plain(l))
    print('\n%d pages vérifiées ; au plus %d lignes sous l\'état (la tablette en montre %d)' % (pages, worst, TABLET_LINES))
    if problems:
        print('\nPROBLÈMES :')
        for p in sorted(set(problems)): print('  - ' + p)
        sys.exit(1)
    print('OK : aucune valeur manquante, toutes les lignes sont des phrases entières')

if __name__ == '__main__':
    main()
