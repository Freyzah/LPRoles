-- LPRoles - the encyclopedia of the roles, on the lobby's tutorial screen.
-- In the lobby, near the tutorial computer or its big screen, the power key shows the next role
-- and the "consume" key the one before: its name, its camp, whether the host switched it on,
-- and how it works with the host's settings (the host sends them: "BOOK role values"). Each
-- player turns the pages on their own machine only: the game's videos, shared by everyone and
-- driven by the host, are left alone.
-- The game never writes these two texts itself (the computer's title, the big screen's text):
-- the mod puts back what they said when the player walks away, when a video starts, when a game
-- begins, or when the widgets go away.
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local S = require("lpr_strings")
local RT = require("lpr_roletext")

local BK = {}

local SCREEN_W = "/Game/Other/Tutos/W_TutoScreeWorld.W_TutoScreeWorld_C"
local NEAR, FAR = 800, 1000        -- cm: the keys turn the pages within NEAR; the page closes beyond FAR
local WIDTH = 46                   -- characters on a line of the big screen (to be adjusted in game)

local pages = {}                   -- role id -> values sent by the host
local order = {}                   -- role ids, by name
local cur = 0                      -- page shown (index in order), 0: none yet
local book = nil                   -- the widgets in use and what they showed before: see open_book
local logged_size = false

local UNACCENTED = { ["É"] = "E", ["È"] = "E", ["Ê"] = "E", ["À"] = "A", ["Â"] = "A", ["Î"] = "I", ["Ô"] = "O",
                     ["Û"] = "U", ["Ç"] = "C" }
local function sort_key(id)
    local name = id == "linked" and S.BOOK.linked_title or (S.ROLE_NAME[id] or id)
    return (name:gsub("[\195][\128-\191]", function(c) return UNACCENTED[c] or c end))
end

local function nearest(class, from)
    local best, best_d = nil, nil
    for _, a in ipairs(FindAllOf(class) or {}) do
        local at = U.valid(a) and G.location(a) or nil
        if at then
            local d = U.dist(from, at)
            if not best_d or d < best_d then best, best_d = a, d end
        end
    end
    return best, best_d
end

-- In the lobby: the local character is neither employee, dissident nor dead for the game.
local function in_lobby(mec)
    return mec ~= nil and G.role_of(mec) < G.ROLE_EMPLOYEE
end

local function read_text(tb)
    if not U.valid(tb) then return nil end
    local ok, s = pcall(function() return U.get(tb, "Text", nil):ToString() end)
    return (ok and type(s) == "string") and s or nil
end

local function visibility(w)
    if not U.valid(w) then return nil end
    local ok, v = pcall(function() return w:GetVisibility() end)
    return ok and v or nil
end

local function set_visible(w, v)
    if U.valid(w) and v ~= nil then pcall(function() w:SetVisibility(v) end) end
end

local function redraw(b)
    for _, owner in ipairs({ b.pc, b.screen }) do
        local comp = U.valid(owner) and U.get(owner, "Widget", nil) or nil
        if U.valid(comp) then pcall(function() comp:RequestRenderUpdate() end) end
    end
end

-- The widgets near the player, and what they show now (put back when the book closes).
local function open_book(pc, screen)
    local pcw = U.valid(pc) and U.get(pc, "PC Screen", nil) or nil
    local sw = U.valid(screen) and U.get(screen, "Screen", nil) or nil
    local text = U.valid(sw) and U.get(sw, "Text_Tutorial", nil) or nil
    if not U.valid(text) then return false end
    local b = { pc = pc, screen = screen, sw = sw, text = text,
                black = U.get(sw, "BlackScreen", nil), image = U.get(sw, "Video_Image", nil),
                head = U.valid(pcw) and U.get(pcw, "HeadText", nil) or nil }
    b.text_was, b.head_was = read_text(b.text), read_text(b.head)
    b.vis = { text = visibility(b.text), black = visibility(b.black), image = visibility(b.image) }
    book = b
    U.log("Encyclopédie ouverte (texte de l'écran : %s ; titre de l'ordinateur : %s)",
        b.text_was and ("« " .. b.text_was .. " »") or "illisible", b.head_was and ("« " .. b.head_was .. " »") or "aucun")
    return true
end

-- game_moved: the game has just shown a video, its own state of the screen stays.
local function close_book(game_moved)
    local b = book
    book, cur = nil, 0
    if not b then return end
    if b.text_was then G.text_call(b.text, "SetText", b.text_was) end
    if b.head_was and U.valid(b.head) then G.text_call(b.head, "SetText", b.head_was) end
    if not game_moved then
        set_visible(b.text, b.vis.text)
        set_visible(b.black, b.vis.black)
    end
    set_visible(b.image, b.vis.image)          -- never changed by the game
    redraw(b)
    U.log("Encyclopédie fermée%s", game_moved and " (une vidéo commence)" or "")
end

local function page_text(role)
    local v = pages[role] or {}
    local B = S.BOOK
    local lines = { role == "linked" and B.linked_title or (S.ROLE_NAME[role] or role) }
    lines[#lines + 1] = B.camp[v.camp or 0] or B.camp[0]
    if (v.mod or 1) == 0 then
        lines[#lines + 1] = B.mod_off
    elseif (v.on or 0) == 1 then
        lines[#lines + 1] = string.format(B.on, v.min or 0)
    else
        lines[#lines + 1] = B.off
    end
    lines[#lines + 1] = ""
    local howto = role == "linked" and { B.linked[1], B.linked_mode[v.lmode or 0] or B.linked_mode[0], B.linked[2] }
        or RT.howto(role, v)
    for _, l in ipairs(howto) do
        local pieces = RT.wrap("- " .. RT.plain(l), WIDTH, "  ")
        for _, p in ipairs(pieces) do lines[#lines + 1] = p end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = (B.keys:gsub("{pkey}", C.format("power_key")):gsub("{key}", C.format("use_key")))
    return table.concat(lines, "\n")
end

local function render()
    local b = book
    if not b or cur == 0 then return end
    G.text_call(b.text, "SetText", page_text(order[cur]))
    set_visible(b.text, 0)                      -- 0: visible, 2: hidden
    set_visible(b.black, 0)
    set_visible(b.image, 2)                     -- a video playing behind stays out of sight
    if U.valid(b.head) then G.text_call(b.head, "SetText", string.format(S.BOOK.head, cur, #order)) end
    b.rev = C.revision                          -- the page names this player's keys
    redraw(b)
    if not logged_size then
        logged_size = true
        pcall(function()
            local size = b.text:GetDesiredSize()
            U.log("Encyclopédie : texte de l'écran %.0f x %.0f", size.X + 0.0, size.Y + 0.0)
        end)
    end
end

-- One of the two keys was pressed (dir: 1 next, -1 previous). true when the encyclopedia took it.
function BK.turn(dir)
    if #order == 0 then return false end
    local mec = G.local_mec()
    if not in_lobby(mec) then return false end
    local menu = U.get(mec, "New Menu", nil)
    if U.valid(menu) and U.get(menu, "Menu Open", false) then return false end
    if U.get(mec, "On Tablet", false) then return false end
    if not book then
        local at = G.location(mec)
        if not at then return false end
        local pc, d_pc = nearest("PC_tuto_C", at)
        local screen = U.valid(pc) and U.get(pc, "World Screen", nil) or nil
        local d_screen
        if U.valid(screen) then
            local s_at = G.location(screen)
            d_screen = s_at and U.dist(at, s_at) or nil
        else
            screen, d_screen = nearest("Tutorial_Screen_C", at)
        end
        local d = math.min(d_pc or math.huge, d_screen or math.huge)
        if d > NEAR or not open_book(pc, screen) then return false end
    end
    if cur == 0 then
        cur = dir > 0 and 1 or #order
    else
        cur = ((cur - 1 + dir) % #order) + 1
    end
    render()
    return true
end

function BK.close()
    if book then close_book(false) end
end

-- The host's "BOOK role values".
function BK.on_book(role, text)
    if type(role) ~= "string" or role == "" then return end
    if not pages[role] then
        order[#order + 1] = role
        table.sort(order, function(a, b) return sort_key(a) < sort_key(b) end)
    end
    pages[role] = RT.parse(text)
    if book and order[cur] == role then render() end
end

-- A new host: its pages come again.
function BK.reset()
    BK.close()
    pages, order = {}, {}
end

local last_tick = 0
local function tick(now)
    if not book or now - last_tick < 0.5 then return end
    last_tick = now
    local b = book
    local mec = G.local_mec()
    local at = mec and G.location(mec) or nil
    local s_at = U.valid(b.screen) and G.location(b.screen) or nil
    local p_at = U.valid(b.pc) and G.location(b.pc) or nil
    local d = math.min(s_at and at and U.dist(at, s_at) or math.huge, p_at and at and U.dist(at, p_at) or math.huge)
    if not U.valid(b.text) or not in_lobby(mec) or d > FAR then
        return close_book(false)
    end
    -- the game hid the screen's text (a video started) and the hook did not say so
    if visibility(b.text) == 2 then return close_book(true) end
    if b.rev ~= C.revision then render() end
end

function BK.install()
    U.hook(SCREEN_W .. ":Show Video", function(ctx, flag)
        local b = book
        if not b then return end
        local w = ctx:get()
        local ok, shown = pcall(function() return flag:get() end)
        if ok and shown == true and U.valid(w) and U.valid(b.sw) and w:GetAddress() == b.sw:GetAddress() then
            close_book(true)
        end
    end)
    U.every_tick("encyclopédie", tick)
end

return BK
