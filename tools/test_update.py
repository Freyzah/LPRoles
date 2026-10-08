"""Tests mod/LPRoles/update.ps1 against a local web server standing in for the GitHub release page.

Usage: python tools/test_update.py     (Windows; nothing outside a test folder in %TEMP% is touched)
"""
import functools, hashlib, http.server, io, os, shutil, subprocess, sys, threading, time, zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SRC = os.path.join(ROOT, 'mod', 'LPRoles')
# a short path (Windows refuses a working folder past 258 characters), with spaces and an accent
WORK = os.path.join(os.environ['TEMP'], 'lpr-test é', 'LOCKDOWN Protocol')
SERVE = os.path.join(WORK, 'serveur')
MOD = os.path.join(WORK, 'jeu', 'ue4ss', 'Mods', 'LPRoles')
PORT = 8765
fails = []

def sha(p): return hashlib.sha256(open(p, 'rb').read()).hexdigest()
def check(name, cond, detail=''):
    print('  %s %s %s' % ('ok  ' if cond else 'FAUX', name, detail if not cond else ''))
    if not cond: fails.append(name)

def tree(d):
    out = {}
    for base, _, fs in os.walk(d):
        for f in fs:
            p = os.path.join(base, f)
            out[os.path.relpath(p, d).replace(os.sep, '/')] = sha(p)
    return out

def publish(version, changes=None, corrupt=False):
    """Builds a release in SERVE from the sources, as tools/deploy.py --release-assets does, but with the
    version number and some files changed."""
    stage = os.path.join(WORK, 'etape')
    shutil.rmtree(stage, ignore_errors=True)
    shutil.copytree(SRC, stage)
    for rel, data in (changes or {}).items():
        open(os.path.join(stage, rel), 'wb').write(data)
    # manifest as deploy.py writes it
    lines = ['version ' + version]
    for n in sorted(os.listdir(os.path.join(stage, 'Scripts'))):
        if n.endswith('.lua'): lines.append('%d Scripts/%s' % (os.path.getsize(os.path.join(stage, 'Scripts', n)), n))
    for n in sorted(os.listdir(os.path.join(stage, 'sounds'))):
        lines.append('son %s sounds/%s' % (sha(os.path.join(stage, 'sounds', n)), n))
    io.open(os.path.join(stage, 'manifest.txt'), 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
    shutil.rmtree(SERVE, ignore_errors=True); os.makedirs(SERVE)
    z = os.path.join(SERVE, 'LPRoles.zip')
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
        for base, _, fs in os.walk(stage):
            for f in fs:
                p = os.path.join(base, f)
                zf.write(p, os.path.relpath(p, stage).replace(os.sep, '/'))
    digest = sha(z)
    if corrupt: open(z, 'ab').write(b'xx')
    io.open(os.path.join(SERVE, 'version.txt'), 'w', encoding='utf-8', newline='\n').write('version %s\nsha256 %s LPRoles.zip\n' % (version, digest))
    return tree(stage)

def run(*extra, source=None):
    t = time.time()
    # the real game may be running while these tests are: the script is given a process name
    # that matches nothing, except where the test itself names one
    if '-GameProcess' not in extra: extra += ('-GameProcess', 'aucun-jeu-pendant-les-essais')
    r = subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File',
                        os.path.join(MOD, 'update.ps1'), '-Source', source or 'http://127.0.0.1:%d' % PORT] + list(extra),
                       capture_output=True, text=True, encoding='cp850', errors='replace')
    res = os.path.join(MOD, 'update-result.txt')
    line = io.open(res, encoding='utf-8').read().strip() if os.path.exists(res) else None
    return r.returncode, line, (r.stdout + r.stderr).strip(), time.time() - t

class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass

shutil.rmtree(os.path.dirname(WORK), ignore_errors=True)
os.makedirs(SERVE)
srv = http.server.ThreadingHTTPServer(('127.0.0.1', PORT), functools.partial(Quiet, directory=SERVE))
threading.Thread(target=srv.serve_forever, daemon=True).start()

# ---- an installation as the players have it today: 0.8.15, manifest without sound checksums
shutil.copytree(SRC, MOD)
io.open(os.path.join(MOD, 'manifest.txt'), 'w', encoding='utf-8', newline='\n').write(
    'version 0.8.15\n' + ''.join('%d Scripts/%s\n' % (os.path.getsize(os.path.join(MOD, 'Scripts', n)), n)
                                 for n in sorted(os.listdir(os.path.join(MOD, 'Scripts')))))
io.open(os.path.join(MOD, 'config.txt'), 'w', encoding='utf-8').write('power_key = mouse4\n')
io.open(os.path.join(MOD, 'journal.txt'), 'w', encoding='utf-8').write('hier\n')
io.open(os.path.join(MOD, 'Scripts', 'lpr_ancien.lua'), 'w').write('-- old\n')
open(os.path.join(MOD, 'sounds', 'LPRoles-son-abc-50b.wav'), 'wb').write(b'copie')
open(os.path.join(MOD, 'sounds', 'consume.wav'), 'wb').write(b'RIFF le son du joueur')
open(os.path.join(MOD, 'Scripts', 'lpr_net.lua'), 'ab').write(b'-- ancien\n')
io.open(os.path.join(MOD, 'manifest.txt'), 'a', encoding='utf-8').write('')
# its manifest must describe it (sizes), as an honest 0.8.15 would
ls = ['version 0.8.15'] + ['%d Scripts/%s' % (os.path.getsize(os.path.join(MOD, 'Scripts', n)), n)
                           for n in sorted(os.listdir(os.path.join(MOD, 'Scripts'))) if n != 'lpr_ancien.lua']
io.open(os.path.join(MOD, 'manifest.txt'), 'w', encoding='utf-8', newline='\n').write('\n'.join(ls) + '\n')

print('A. 0.8.15 -> 0.9.0 (lancé comme par le jeu)')
want = publish('0.9.0')
code, line, out, dt = run('-FromGame')
have = tree(MOD)
check('code 0 et « MAJ 0.8.15 0.9.0 »', code == 0 and line == 'MAJ 0.8.15 0.9.0', repr((code, line, out)))
check('rien d\'affiché (mode jeu)', out == '', repr(out))
check('scripts, outils et liste identiques à la version publiée',
      all(have.get(k) == v for k, v in want.items() if not k.startswith('sounds/')), [k for k, v in want.items() if have.get(k) != v])
check('réglages et journal gardés', io.open(os.path.join(MOD, 'config.txt')).read() == 'power_key = mouse4\n' and 'journal.txt' in have)
check('son du joueur gardé', open(os.path.join(MOD, 'sounds', 'consume.wav'), 'rb').read() == b'RIFF le son du joueur')
check('ancien script et copie de son supprimés', 'Scripts/lpr_ancien.lua' not in have and 'sounds/LPRoles-son-abc-50b.wav' not in have)
print('   (%.1f s)' % dt)

print('B. relancé : rien à faire')
before = tree(MOD)
code, line, out, dt = run()
check('code 0 et « OK 0.9.0 »', code == 0 and line == 'OK 0.9.0', repr((code, line, out)))
after = tree(MOD); after.pop('update-result.txt', None); before.pop('update-result.txt', None)
check('aucun fichier changé', before == after)
print('   message :', out, '(%.1f s)' % dt)

print('C. 0.9.1 : un son du mod change, un script aussi')
want = publish('0.9.1', {'sounds/fairy.wav': b'RIFF nouveau vol', 'Scripts/lpr_net.lua': b'-- neuf\n'})
code, line, out, dt = run()
have = tree(MOD)
check('« MAJ 0.9.0 0.9.1 »', line == 'MAJ 0.9.0 0.9.1', repr((code, line, out)))
check('son du mod remplacé', have['sounds/fairy.wav'] == want['sounds/fairy.wav'])
check('son du joueur encore gardé, et dit', open(os.path.join(MOD, 'sounds', 'consume.wav'), 'rb').read() == b'RIFF le son du joueur' and 'consume.wav' in out, out)
check('script remplacé, liste à jour', have['Scripts/lpr_net.lua'] == want['Scripts/lpr_net.lua'] and have['manifest.txt'] == want['manifest.txt'])
print('   message :', out)

print('D. archive abîmée en route (0.9.2)')
publish('0.9.2', {'Scripts/lpr_net.lua': b'-- encore\n'}, corrupt=True)
before = tree(MOD)
code, line, out, dt = run()
after = tree(MOD); after.pop('update-result.txt', None); before.pop('update-result.txt', None)
check('code 1 et « ECHEC ... »', code == 1 and line.startswith('ECHEC '), repr((code, line)))
check('aucun fichier changé', before == after)
print('   message :', out)

print('E. version publiée plus ancienne que celle installée')
publish('0.8.0')
before = tree(MOD)
code, line, out, dt = run()
after = tree(MOD); after.pop('update-result.txt', None); before.pop('update-result.txt', None)
check('« OK 0.9.1 », rien de changé', line == 'OK 0.9.1' and before == after, repr((code, line)))
print('   message :', out)

print('F. même version mais un script abîmé : remise en état')
want = publish('0.9.1', {'sounds/fairy.wav': b'RIFF nouveau vol', 'Scripts/lpr_net.lua': b'-- neuf\n'})
open(os.path.join(MOD, 'Scripts', 'lpr_game.lua'), 'ab').write(b'x')
code, line, out, dt = run()
have = tree(MOD)
check('« MAJ 0.9.1 0.9.1 » et script rétabli', line == 'MAJ 0.9.1 0.9.1' and have['Scripts/lpr_game.lua'] == want['Scripts/lpr_game.lua'], repr((code, line)))
print('   message :', out)

print('G. le jeu tourne et la mise à jour est lancée à la main')
publish('0.9.3', {'Scripts/lpr_net.lua': b'-- 093\n'})
before = tree(MOD)
code, line, out, dt = run('-GameProcess', 'powershell')        # this very process stands in for the game
after = tree(MOD); after.pop('update-result.txt', None); before.pop('update-result.txt', None)
check('code 2, « JEU », rien de changé', code == 2 and line == 'JEU' and before == after, repr((code, line)))
print('   message :', out)

print('H. pas de réseau / page absente')
code, line, out, dt = run(source='http://127.0.0.1:9')
check('code 1 et « ECHEC ... » (%.1f s)' % dt, code == 1 and line.startswith('ECHEC ') and dt < 12, repr((code, line, dt)))
code, line, out, dt2 = run(source='http://127.0.0.1:%d/absent' % PORT)
check('page absente : « ECHEC ... » (%.1f s)' % dt2, code == 1 and line.startswith('ECHEC '), repr((code, line)))
print('   message :', out)

print('I. la commande exacte du mod (cmd /c, chemin relatif, sans fenêtre)')
cwd = os.path.join(WORK, 'jeu')
os.remove(os.path.join(MOD, 'update-result.txt'))
cmd = ('powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
       + 'ue4ss\\Mods\\LPRoles' + '\\update.ps1" -FromGame -Source http://127.0.0.1:%d' % PORT)
t = time.time(); rc = subprocess.run(cmd, shell=True, cwd=cwd).returncode; dt = time.time() - t
line = io.open(os.path.join(MOD, 'update-result.txt'), encoding='utf-8').read().strip()
check('« MAJ 0.9.1 0.9.3 » (%.1f s)' % dt, rc == 0 and line == 'MAJ 0.9.1 0.9.3', repr((rc, line)))
cmd_abs = cmd.replace('ue4ss\\Mods\\LPRoles', MOD)
t = time.time(); rc = subprocess.run(cmd_abs, shell=True, cwd=ROOT).returncode; dt = time.time() - t
line = io.open(os.path.join(MOD, 'update-result.txt'), encoding='utf-8').read().strip()
check('chemin complet avec espaces et accent : « OK 0.9.3 » (%.1f s)' % dt, rc == 0 and line == 'OK 0.9.3', repr((rc, line)))

srv.shutdown()
left = [d for d in os.listdir(os.environ.get('TEMP', '.')) if d.startswith('LPRoles-maj-')]
check('aucun dossier temporaire laissé', not left, left)
shutil.rmtree(os.path.dirname(WORK), ignore_errors=True)
print('\nRÉSULTAT :', 'TOUT EST BON' if not fails else '%d ÉCHEC(S) : %s' % (len(fails), fails))
sys.exit(1 if fails else 0)
