# LPRoles - mise à jour du mod depuis sa page GitHub.
# Deux façons de le lancer :
#   - double-clic sur "mettre-a-jour.bat", jeu fermé ;
#   - par le mod lui-même à chaque lancement du jeu (-FromGame), avant qu'il charge ses scripts.
# Il ne touche qu'au dossier du mod où il se trouve. Les réglages (config.txt), le journal et les
# sons que le joueur a remplacés par les siens sont gardés.
# Ce fichier est enregistré en UTF-8 avec BOM (Windows PowerShell 5.1 en a besoin pour les accents).
param(
    [switch]$FromGame,
    [string]$Source = "https://github.com/Freyzah/LPRoles/releases/latest/download",
    [string]$ModDir = $PSScriptRoot,
    [string]$GameProcess = "LockdownProtocol*"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# Fichiers que le mod écrit lui-même : jamais remplacés ni supprimés.
$Runtime = @("config.txt", "menu_guard.txt", "tablet_guard.txt", "journal.txt", "journal-ancien.txt",
             "reprise-061.txt", "update-result.txt")
$Utf8 = New-Object System.Text.UTF8Encoding($false)

# manifest.txt : "version X", "<taille> Scripts/nom.lua", "son <sha256> sounds/nom.wav"
function Read-Manifest([string]$dir) {
    $m = @{ Version = $null; Sizes = @{}; Sounds = @{} }
    $path = Join-Path $dir "manifest.txt"
    if (Test-Path -LiteralPath $path) {
        foreach ($line in [IO.File]::ReadAllLines($path, $Utf8)) {
            if ($line -match '^version (\S+)') { $m.Version = $Matches[1] }
            elseif ($line -match '^(\d+) (.+?)\s*$') { $m.Sizes[$Matches[2]] = [long]$Matches[1] }
            elseif ($line -match '^son ([0-9a-fA-F]{64}) (.+?)\s*$') { $m.Sounds[$Matches[2]] = $Matches[1].ToLower() }
        }
    }
    return $m
}

# Tous les scripts de la liste sont là, à la taille dite.
function Test-Sizes([string]$dir, $manifest) {
    if ($manifest.Sizes.Count -eq 0) { return $false }
    foreach ($name in $manifest.Sizes.Keys) {
        $f = Join-Path $dir $name
        if (-not (Test-Path -LiteralPath $f)) { return $false }
        if ((Get-Item -LiteralPath $f).Length -ne $manifest.Sizes[$name]) { return $false }
    }
    return $true
}

function Get-Sha([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() }

function As-Version([string]$text) { try { return [version]$text } catch { return $null } }

# Rend (code de sortie, ligne pour le mod, phrase pour le joueur).
function Update-Mod([string]$tmp) {
    $old = Read-Manifest $ModDir
    $shown = if ($old.Version) { $old.Version } else { "?" }

    # 1. la dernière version publiée
    $info = Join-Path $tmp "version.txt"
    Invoke-WebRequest -Uri "$Source/version.txt" -OutFile $info -UseBasicParsing -TimeoutSec 5
    $latest = $null
    $sha = $null
    foreach ($line in [IO.File]::ReadAllLines($info, $Utf8)) {
        if ($line -match '^version (\S+)') { $latest = $Matches[1] }
        elseif ($line -match '^sha256 ([0-9a-fA-F]{64}) ') { $sha = $Matches[1].ToLower() }
    }
    $vNew = As-Version $latest
    if (-not $vNew -or -not $sha) { throw "réponse inattendue de GitHub" }
    $vOld = As-Version $old.Version
    if ($vOld -and $vNew -lt $vOld) {
        return 0, "OK $shown", "LPRoles $shown : plus récent que la dernière version publiée ($latest). Rien à faire."
    }
    $repair = $false
    if ($vOld -and $vNew -eq $vOld) {
        if (Test-Sizes $ModDir $old) { return 0, "OK $shown", "LPRoles $shown : déjà à jour." }
        $repair = $true
    }
    if (-not $FromGame -and (Get-Process -Name $GameProcess -ErrorAction SilentlyContinue)) {
        return 2, "JEU", "Une version $latest est disponible. Fermez le jeu, puis relancez cette mise à jour."
    }

    # 2. l'archive, vérifiée avant de toucher au mod
    $zip = Join-Path $tmp "LPRoles.zip"
    Invoke-WebRequest -Uri "$Source/LPRoles.zip" -OutFile $zip -UseBasicParsing -TimeoutSec 60
    if ((Get-Sha $zip) -ne $sha) { throw "archive incomplète (empreinte différente de celle annoncée)" }
    $new = Join-Path $tmp "mod"
    Expand-Archive -LiteralPath $zip -DestinationPath $new
    $new = (Get-Item -LiteralPath $new).FullName
    $m = Read-Manifest $new
    if ($m.Version -ne $latest -or -not (Test-Sizes $new $m) -or
        -not (Test-Path -LiteralPath (Join-Path $new "Scripts\main.lua"))) {
        throw "archive invalide (son contenu ne correspond pas à sa liste)"
    }

    # 3. les fichiers, un par un ; la liste (manifest.txt) en dernier : si la copie s'arrête en
    #    route, le mod garde son ancien numéro et la prochaine mise à jour recommence
    $kept = @()
    foreach ($f in Get-ChildItem -LiteralPath $new -Recurse -File) {
        $rel = $f.FullName.Substring($new.Length).TrimStart('\')
        $key = $rel -replace '\\', '/'
        if ($Runtime -contains $f.Name -or $key -eq "manifest.txt") { continue }
        $target = Join-Path $ModDir $rel
        if (Test-Path -LiteralPath $target) {
            $have = Get-Sha $target
            if ($have -eq (Get-Sha $f.FullName)) { continue }
            # un son n'est remplacé que s'il est encore celui du mod : celui que le joueur a mis
            # à la place est gardé
            if ($key -like "sounds/*" -and $old.Sounds[$key] -ne $have) {
                $kept += $f.Name
                continue
            }
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        }
        Copy-Item -LiteralPath $f.FullName -Destination $target -Force
    }
    # scripts d'une ancienne version, et copies de sons que le mod refabrique tout seul
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $ModDir "Scripts") -File -Filter "*.lua") {
        if (-not (Test-Path -LiteralPath (Join-Path $new "Scripts\$($f.Name)"))) {
            Remove-Item -LiteralPath $f.FullName -Force
        }
    }
    foreach ($f in Get-ChildItem -LiteralPath $ModDir -Recurse -File -Filter "LPRoles-son-*") {
        try { Remove-Item -LiteralPath $f.FullName -Force } catch {}
    }
    Copy-Item -LiteralPath (Join-Path $new "manifest.txt") -Destination (Join-Path $ModDir "manifest.txt") -Force

    $text = if ($repair) { "LPRoles $latest : fichiers remis en état." } else { "LPRoles mis à jour : $shown -> $latest." }
    if ($kept.Count -gt 0) { $text += " Sons personnels gardés : " + ($kept -join ", ") + "." }
    return 0, "MAJ $shown $latest", $text
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("LPRoles-maj-" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $code, $result, $message = Update-Mod $tmp
} catch {
    $why = ($_.Exception.Message -replace '\s+', ' ').Trim()
    $code, $result, $message = 1, "ECHEC $why", "Mise à jour impossible : $why"
}
try { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force } } catch {}
try { [IO.File]::WriteAllText((Join-Path $ModDir "update-result.txt"), $result + "`n", $Utf8) } catch {}
if (-not $FromGame) { Write-Host $message }
exit $code
