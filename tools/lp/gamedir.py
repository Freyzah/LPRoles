"""Where the game is installed on this machine: the folder that holds "LockdownProtocol" (the one with
Binaries and Content inside).

Read from the LPROLES_GAME environment variable, else from the first line of tools/dossier-du-jeu.txt, a
local file that is not in the repository.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
LOCAL = os.path.normpath(os.path.join(HERE, "..", "dossier-du-jeu.txt"))

def root():
    path = os.environ.get("LPROLES_GAME", "").strip()
    if not path and os.path.exists(LOCAL):
        with open(LOCAL, encoding="utf-8-sig") as f:
            path = f.readline().strip()
    if not path:
        raise SystemExit("Dossier du jeu inconnu : l'écrire sur la première ligne de " + LOCAL +
                         " (ou dans la variable LPROLES_GAME).")
    if not os.path.isdir(os.path.join(path, "LockdownProtocol")):
        raise SystemExit("Dossier du jeu introuvable : " + path)
    return path

def win64():
    return os.path.join(root(), "LockdownProtocol", "Binaries", "Win64")

def paks():
    return os.path.join(root(), "LockdownProtocol", "Content", "Paks")
