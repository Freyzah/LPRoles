-- LPRoles - update at launch.
-- Runs "update.ps1" (the script behind "mettre-a-jour.bat") before the other scripts are
-- loaded, so that a version published since the last launch is the one this launch uses.
-- It stands alone: nothing here may load a script that the update can replace.
local Up = {}

-- The mod folder, found the way lpr_util.lua finds it (which cannot be loaded yet).
local function mod_dir()
    local candidates = {}
    local ok, dirs = pcall(IterateGameDirectories)
    if ok and type(dirs) == "table" then
        pcall(function()
            candidates[#candidates + 1] = dirs.Game.Binaries.Win64.ue4ss.Mods.LPRoles.__absolute_path
        end)
    end
    local ok2, info = pcall(debug.getinfo, 1, "S")
    if ok2 and info and info.source then
        local src = info.source:gsub("^@", "")
        candidates[#candidates + 1] = src:match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
    end
    for _, rel in ipairs({ "ue4ss/Mods/LPRoles", "Mods/LPRoles",
                           "LockdownProtocol/Binaries/Win64/ue4ss/Mods/LPRoles",
                           "../../../LockdownProtocol/Binaries/Win64/ue4ss/Mods/LPRoles" }) do
        candidates[#candidates + 1] = rel
    end
    for _, dir in ipairs(candidates) do
        if type(dir) == "string" and dir ~= "" then
            local f = io.open(dir .. "/update.ps1", "r")
            if f then
                f:close()
                return dir
            end
        end
    end
    return nil
end

-- "auto_update = false" in config.txt switches the update at launch off (the settings are
-- not loaded yet: the line is read here).
local function switched_off(dir)
    local f = io.open(dir .. "/config.txt", "r")
    if not f then return false end
    local off = false
    for line in f:lines() do
        local v = line:match("^%s*auto_update%s*=%s*(%S+)")
        if v then
            v = v:lower()
            off = v == "false" or v == "0" or v == "non" or v == "off"
        end
    end
    f:close()
    return off
end

-- What happened, for the journal and the banner: state "updated" (with from and to),
-- "current", "off" or "failed" (with detail); seconds is how long the launch waited.
function Up.run()
    local dir = mod_dir()
    if not dir then return { state = "failed", detail = "update.ps1 introuvable" } end
    if switched_off(dir) then return { state = "off" } end
    if type(os) ~= "table" or type(os.execute) ~= "function" then
        return { state = "failed", detail = "os.execute indisponible" }
    end
    local result = dir .. "/update-result.txt"
    os.remove(result)
    local started = os.clock()
    -- the game waits for the script: it answers in about a second when there is nothing new
    os.execute('powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
        .. dir:gsub("/", "\\") .. '\\update.ps1" -FromGame')
    local out = { seconds = os.clock() - started }
    local f = io.open(result, "r")
    local line = f and f:read("l") or nil
    if f then f:close() end
    if not line then
        out.state, out.detail = "failed", "pas de réponse de update.ps1"
        return out
    end
    local from, to = line:match("^MAJ (%S+) (%S+)")
    if from then
        out.state, out.from, out.to = "updated", from, to
    elseif line:match("^OK") then
        out.state = "current"
    else
        out.state, out.detail = "failed", (line:gsub("^ECHEC ", ""))
    end
    return out
end

return Up
