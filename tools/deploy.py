"""Installs UE4SS (official build) and the LPRoles mod into the game folder, and builds what is published.

Usage: python deploy.py            -> install UE4SS if missing, then (re)copy the mod
       python deploy.py --package  -> also build LPRoles-pour-les-joueurs.zip (UE4SS + mod) for the other players
       python deploy.py --package-only -> NOTHING is installed: only builds the archive of the version in the
                                      sources, named after it (LPRoles-<version>-pour-les-joueurs.zip). For a
                                      version prepared while the installed one must stay as it is.
       python deploy.py --release-assets <folder> [--expect <version>]
                                   -> what a GitHub release carries, built from the sources alone (the game is
                                      not needed): LPRoles.zip (the mod folder), version.txt (version and
                                      checksum, read by update.ps1) and notes.md (this version's section of
                                      CHANGELOG.md). --expect fails when the sources are another version.

The game folder is read from tools/dossier-du-jeu.txt (see lp/gamedir.py).
"""
import filecmp, hashlib, os, re, shutil, sys, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, os.path.join(HERE, "lp"))
import gamedir

GAME_WIN64 = None                  # set when the game folder is needed
UE4SS_SRC = os.path.join(HERE, "ue4ss-official")
MOD_SRC = os.path.join(ROOT, "mod", "LPRoles")

# Verified against the current game executable: the pattern occurs once and points into .data.
SIGNATURE = '''function Register()
    return "48 8D ?? ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 85 DB 74 ?? 48 8B CB FF 15 ?? ?? ?? ?? 48 8B 5C 24 60 33 C0"
end

function OnMatchFound(matchAddress)
    local movInstr = matchAddress
    local nextInstr = movInstr + 0x7
    local offset = movInstr + 0x3
    local dataMoved = nextInstr + DerefToInt32(offset)

    return dataMoved
end
'''

# Built-in UE4SS mods switched off: they add a cheat manager and a developer console.
DISABLED_BUILTINS = ("CheatManagerEnablerMod", "ConsoleCommandsMod", "ConsoleEnablerMod")

def install_ue4ss():
    dst = os.path.join(GAME_WIN64, "ue4ss")
    proxy = os.path.join(GAME_WIN64, "dwmapi.dll")
    if os.path.exists(os.path.join(dst, "UE4SS.dll")) and os.path.exists(proxy):
        print("UE4SS déjà installé :", dst)
        return
    shutil.copy2(os.path.join(UE4SS_SRC, "dwmapi.dll"), proxy)
    shutil.copytree(os.path.join(UE4SS_SRC, "ue4ss"), dst, dirs_exist_ok=True)
    sig = os.path.join(dst, "UE4SS_Signatures")
    os.makedirs(sig, exist_ok=True)
    with open(os.path.join(sig, "GUObjectArray.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(SIGNATURE)
    mods_txt = os.path.join(dst, "Mods", "mods.txt")
    lines = open(mods_txt, encoding="utf-8").read().splitlines()
    out = []
    for line in lines:
        name = line.split(":")[0].strip()
        out.append(f"{name} : 0" if name in DISABLED_BUILTINS else line)
    with open(mods_txt, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    mods_json = os.path.join(dst, "Mods", "mods.json")
    if os.path.exists(mods_json):
        import json
        data = json.load(open(mods_json, encoding="utf-8"))
        for entry in data:
            if entry.get("mod_name") in DISABLED_BUILTINS: entry["mod_enabled"] = False
        json.dump(data, open(mods_json, "w", encoding="utf-8"), indent=4)
    print("UE4SS installé :", dst)

# Files the mod writes itself in its folder: never replaced nor removed by an update.
# (update.ps1 has the same list.)
RUNTIME_FILES = {"config.txt", "menu_guard.txt", "tablet_guard.txt", "journal.txt", "journal-ancien.txt",
                 "reprise-061.txt", "update-result.txt"}

def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()

def source_version():
    for line in open(os.path.join(MOD_SRC, "Scripts", "lpr_util.lua"), encoding="utf-8"):
        if line.startswith("U.VERSION"):
            return line.split('"')[1]
    return "?"

def write_manifest():
    """manifest.txt in the mod's source: its version, the size of every script and the checksum of every
    sound. The mod compares the sizes with what is really there when it loads (a copy gone wrong is then
    told); an update compares the checksums to tell the mod's own sounds, which it may replace, from the
    ones a player put in their place. It is written again at every run of this script: a script edited
    afterwards and copied by hand, without running this script, would be reported as an incomplete
    installation."""
    scripts = os.path.join(MOD_SRC, "Scripts")
    version = source_version()
    lines = ["version " + version]
    for name in sorted(os.listdir(scripts)):
        if name.endswith(".lua"):
            lines.append(f"{os.path.getsize(os.path.join(scripts, name))} Scripts/{name}")
    sounds = os.path.join(MOD_SRC, "sounds")
    for name in sorted(os.listdir(sounds)):
        if is_generated(name): continue
        lines.append(f"son {sha256(os.path.join(sounds, name))} sounds/{name}")
    with open(os.path.join(MOD_SRC, "manifest.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    # Windows PowerShell 5.1 reads a script without BOM as ANSI: the accents of update.ps1 would break
    ps1 = open(os.path.join(MOD_SRC, "update.ps1"), "rb").read()
    if not ps1.startswith(b"\xef\xbb\xbf") and any(b > 127 for b in ps1):
        sys.exit("update.ps1 a perdu son BOM UTF-8 : le réenregistrer en « UTF-8 avec BOM ».")
    print(f"manifest.txt : version {version}, {len(lines) - 1} fichiers listés")
    return version

def is_sound(rel):
    """The "sounds" folder: a player may replace a sound by their own."""
    return rel.replace(os.sep, "/").split("/")[0] == "sounds"

def is_generated(name):
    """Sound copies the mod makes again by itself."""
    return name.startswith("LPRoles-son-")

def installed_sounds(dst):
    """Checksums of the mod's own sounds as listed by the installed manifest.txt."""
    out = {}
    path = os.path.join(dst, "manifest.txt")
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            m = re.match(r"son ([0-9a-f]{64}) (.+?)\s*$", line)
            if m: out[m.group(2)] = m.group(1)
    return out

def source_files():
    """The mod's files as published: (full path, path relative to the mod folder with /)."""
    for base, _, files in os.walk(MOD_SRC):
        for name in sorted(files):
            if name in RUNTIME_FILES or is_generated(name): continue
            full = os.path.join(base, name)
            yield full, os.path.relpath(full, MOD_SRC).replace(os.sep, "/")

def install_mod():
    """Copies the mod over the installed one, file by file: nothing is deleted first, so a file
    held open by the running game (a sound) cannot leave the mod half removed. Files of an
    older version that the source no longer has are removed afterwards; the files the mod
    writes itself are left alone, and so is a sound the player replaced by their own (one that
    is not the sound the installed version came with)."""
    dst = os.path.join(GAME_WIN64, "ue4ss", "Mods", "LPRoles")
    own = installed_sounds(dst)
    wanted, copied, locked, kept, late = set(), 0, [], [], None
    for full, key in source_files():
        rel = key.replace("/", os.sep)
        wanted.add(rel)
        target = os.path.join(dst, rel)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        if key == "manifest.txt":
            late = (full, target)                  # last: it tells what the other files are
            continue
        if os.path.exists(target) and filecmp.cmp(full, target, shallow=False): continue
        if is_sound(rel) and os.path.exists(target) and own.get(key) != sha256(target):
            kept.append(rel)                       # the player's own sound: never replaced
            continue
        try:
            shutil.copy2(full, target)
            copied += 1
        except PermissionError:
            locked.append(rel)
    for base, _, files in os.walk(dst):
        for name in files:
            rel = os.path.relpath(os.path.join(base, name), dst)
            if is_generated(name):
                try: os.remove(os.path.join(base, name))
                except PermissionError: pass       # in use by the running game: left as is
                continue
            if rel not in wanted and name not in RUNTIME_FILES and not is_sound(rel):
                try: os.remove(os.path.join(base, name))
                except PermissionError: locked.append(rel)
    if late and not (os.path.exists(late[1]) and filecmp.cmp(late[0], late[1], shallow=False)):
        shutil.copy2(*late)
        copied += 1
    print(f"Mod LPRoles installé ({len(wanted)} fichiers, {copied} remplacés) :", dst)
    if kept:
        print("Sons du jeu gardés tels quels (différents de la source) :", ", ".join(kept))
    if locked:
        print("ATTENTION, fichiers occupés (fermer le jeu puis relancer) :", ", ".join(locked))

def package(version=None):
    """One archive for the other players: UE4SS + signature + the mod, laid out from the game's
    root folder (the one with LockdownProtocol.exe), so its content is pasted there as is.
    version: named after it (an archive of a version that is not the installed one)."""
    out = os.path.join(ROOT, f"LPRoles-{version}-pour-les-joueurs.zip" if version else "LPRoles-pour-les-joueurs.zip")
    skip = {"UE4SS.log", "config.txt", "menu_guard.txt", "tablet_guard.txt"}
    prefix = "LockdownProtocol/Binaries/Win64/"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(GAME_WIN64, "dwmapi.dll"), prefix + "dwmapi.dll")
        src = os.path.join(GAME_WIN64, "ue4ss")
        mine = os.path.join(src, "Mods", "LPRoles")
        for base, _, files in os.walk(src):
            if os.path.commonpath([base, mine]) == mine: continue          # the mod comes from its source
            for name in files:
                if name in skip or name.endswith(".dmp"): continue
                full = os.path.join(base, name)
                z.write(full, prefix + "ue4ss/" + os.path.relpath(full, src).replace(os.sep, "/"))
        for full, key in source_files():
            z.write(full, prefix + "ue4ss/Mods/LPRoles/" + key)
    print(f"Archive créée ({os.path.getsize(out) // 1024} Ko) :", out)

def release_notes(version):
    """This version's section of CHANGELOG.md (from its "## <version>" title to the next one), followed by
    the sections right under it whose title says "(non publiée)": versions that were only ever installed
    here, whose changes reach the players with this one."""
    text = open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read()
    sections = re.findall(r"^## ([^\n]*)\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    at = [i for i, (title, _) in enumerate(sections) if re.match(re.escape(version) + r"\b", title)]
    if not at: sys.exit(f"CHANGELOG.md n'a pas de section « ## {version} »")
    out = [sections[at[0]][1].strip()]
    for title, body in sections[at[0] + 1:]:
        if "(non publiée)" not in title: break
        out.append("### " + title.replace("(non publiée)", "").strip() + "\n\n" + body.strip())
    return "\n\n".join(out) + "\n"

def release_assets(out, version):
    """LPRoles.zip: the mod folder as it must be on a player's machine, files at the archive's root.
    Fixed dates, so that the same sources always give the same archive and the same checksum."""
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "LPRoles.zip")
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for full, key in source_files():
            info = zipfile.ZipInfo(key, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            with open(full, "rb") as f:
                z.writestr(info, f.read())
    with open(os.path.join(out, "version.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(f"version {version}\nsha256 {sha256(path)} LPRoles.zip\n")
    with open(os.path.join(out, "notes.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(release_notes(version))
    print(f"Pour la publication ({os.path.getsize(path) // 1024} Ko) :", os.path.abspath(out))

if __name__ == "__main__":
    args = sys.argv[1:]
    if "--release-assets" in args:
        before = open(os.path.join(MOD_SRC, "manifest.txt"), "rb").read()
        version = write_manifest()
        if "--expect" in args and args[args.index("--expect") + 1] != version:
            sys.exit(f"Les sources sont en version {version}, pas {args[args.index('--expect') + 1]}")
        # on GitHub (--expect) the published files must be the committed ones, manifest.txt included
        if "--expect" in args and open(os.path.join(MOD_SRC, "manifest.txt"), "rb").read() != before:
            sys.exit("manifest.txt n'est pas à jour dans le dépôt : lancer « python tools/deploy.py » ici, "
                     "valider manifest.txt, puis refaire l'étiquette.")
        release_assets(args[args.index("--release-assets") + 1], version)
        sys.exit(0)
    GAME_WIN64 = gamedir.win64()
    version = write_manifest()
    if "--package-only" in args:
        package(version)
        print("Rien n'a été installé dans le jeu.")
        sys.exit(0)
    install_ue4ss()
    install_mod()
    if "--package" in args: package()
