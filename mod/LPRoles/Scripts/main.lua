-- LPRoles - extra roles for LOCKDOWN Protocol (UE4SS Lua mod)
-- Shérif, Recruteur, Rêveur, Fée, Médium, Ange gardien, Taupe, Traqueur, Hypnotiseur,
-- Métamorphe, Nettoyeur, Clandestin, Échangeur, Martyr, Revenant, and the Liés bond.
-- The same files go on the host's and the players' machines.
--
-- This file only starts the others and stays the same from one version to the next: the
-- update at launch replaces every script before it is loaded, except this one, which is
-- already running. The mod itself is loaded by lpr_main.lua.
local ok, update = pcall(function() return require("lpr_update").run() end)
if not ok then update = { state = "failed", detail = tostring(update) } end

local loaded, err = pcall(function() require("lpr_main")(update) end)
if not loaded then print("[LPRoles] ÉCHEC du chargement : " .. tostring(err) .. "\n") end
