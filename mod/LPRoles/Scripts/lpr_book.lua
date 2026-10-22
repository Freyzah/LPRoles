-- LPRoles - the encyclopedia of the roles, on the lobby's tutorial screen, the same for everyone.
-- The left and right arrows of the tutorial computer (its own buttons, pushed by anyone) turn the
-- pages: the host picks the page and every machine with the mod shows it on the big screen
-- ("BOOKPAGE role number total"): the role's name, its camp, whether the host switched it on, and
-- how it works with the host's settings (the host sends them: "BOOK role values"). In the game
-- these arrows move a tutorial video ten seconds forward or back: with the mod they turn the
-- pages, and a video playing stops (the game's own idle screen, for everyone). Starting a video
-- with the computer's other buttons puts the game's screen back.
-- The game never writes these two texts itself (the computer's title, the big screen's text):
-- the mod puts back what they said when a video starts, when a game begins, or when the widgets
-- go away.
local U = require("lpr_util")
local G = require("lpr_game")
local S = require("lpr_strings")
local RT = require("lpr_roletext")

local BK = {}

local PC = "/Game/Other/Tutos/PC_tuto.PC_tuto_C"
local SCREEN = "/Game/Other/Tutos/Tutorial_Screen.Tutorial_Screen_C"
local SCREEN_W = "/Game/Other/Tutos/W_TutoScreeWorld.W_TutoScreeWorld_C"
-- the computer's two arrows (its buttons Left and Right), as the game names their events
local ARROW = { [-1] = "BndEvt__PC_tuto_Button Left_K2Node_ComponentBoundEvent_5_Button Push__DelegateSignature",
                [1] = "BndEvt__PC_tuto_Button Right_K2Node_ComponentBoundEvent_4_Button Push__DelegateSignature" }
local WIDTH = 46                   -- characters on a line of the big screen, before the font is made to fit

local pages = {}                   -- role id -> values sent by the host
local want = nil                   -- the page the host shows: { id, n, total }; nil: the game's own screen
local book = nil                   -- the widgets in use and what they showed before: see open_book
local logged_size = false
local per_point = nil              -- a letter's width and a line's height for a font size of 1, once measured

local UNACCENTED = { ["É"] = "E", ["È"] = "E", ["Ê"] = "E", ["À"] = "A", ["Â"] = "A", ["Î"] = "I", ["Ô"] = "O",
                     ["Û"] = "U", ["Ç"] = "C" }
local function sort_key(id)
    local name = id == "linked" and S.BOOK.linked_title or (S.ROLE_NAME[id] or id)
    return (name:gsub("[\195][\128-\191]", function(c) return UNACCENTED[c] or c end))
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

-- The tutorial computer of the lobby and its big screen.
local function find_screen()
    for _, pc in ipairs(FindAllOf("PC_tuto_C") or {}) do
        local screen = U.valid(pc) and U.get(pc, "World Screen", nil) or nil
        if U.valid(screen) then return pc, screen end
    end
    local screen = FindFirstOf("Tutorial_Screen_C")
    return nil, U.valid(screen) and screen or nil
end

-- The length of the longest line of a text (in characters), and its number of lines.
local function line_sizes(text)
    local longest, count = 0, 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        count = count + 1
        longest = math.max(longest, U.length(line))
    end
    return longest, count
end

-- The widgets of the screen, and what they show now (put back when the book closes).
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
    -- The screen's font is made for one big word ("TUTORIALS"): a page needs a smaller one, set
    -- from what that word takes now (width of a letter, height of a line) and from the size of
    -- the screen's picture. The game's own size is put back when the book closes.
    pcall(function() b.font_size = b.text.Font.Size end)
    pcall(function()
        -- the size the text takes now: without the prepass, the size it had when last drawn
        pcall(function() b.text:ForceLayoutPrepass() end)
        local size = b.text:GetDesiredSize()
        local longest, count = line_sizes(b.text_was or "")
        if longest > 0 and size.X > 0 and size.Y > 0 then
            b.cw, b.lh = (size.X + 0.0) / longest, (size.Y + 0.0) / count
        end
    end)
    -- a measure that cannot be right (the size of another text), or none: the last good one, or a guess
    if b.font_size and b.font_size > 0 then
        local cw, lh = b.cw and b.cw / b.font_size, b.lh and b.lh / b.font_size
        if cw and cw > 0.2 and cw < 3 and lh > 0.5 and lh < 4 then
            per_point = { cw = cw, lh = lh }
        else
            local m = per_point or { cw = 0.8, lh = 1.4 }
            b.cw, b.lh = m.cw * b.font_size, m.lh * b.font_size
        end
    end
    pcall(function()
        local draw = U.get(U.get(screen, "Widget", nil), "DrawSize", nil)
        if draw.X > 0 and draw.Y > 0 then b.area = { X = draw.X * 0.92, Y = draw.Y * 0.88 } end
    end)
    if not b.area and b.cw then b.area = { X = 22 * b.cw, Y = 7 * b.lh } end      -- what the first try showed
    book = b
    U.log("Encyclopédie ouverte (texte de l'écran : %s ; titre de l'ordinateur : %s ; police %s, lettre %s x %s, place %s)",
        b.text_was and ("« " .. b.text_was .. " »") or "illisible", b.head_was and ("« " .. b.head_was .. " »") or "aucun",
        tostring(b.font_size), b.cw and string.format("%.0f", b.cw) or "?", b.lh and string.format("%.0f", b.lh) or "?",
        b.area and string.format("%.0f x %.0f", b.area.X, b.area.Y) or "?")
    return true
end

local function set_font_size(b, size)
    if not size or size == b.size_set then return end
    local ok = pcall(function()
        local f = b.text.Font
        f.Size = size
        b.text:SetFont(b.text.Font)
    end)
    b.size_set = ok and size or b.size_set
end

-- The font size at which the page fits on the screen (never larger than the game's own).
local function fit(b, text)
    if not (b.font_size and b.cw and b.lh and b.area) then return end
    local longest, count = line_sizes(text)
    longest = math.max(1, longest)
    local scale = math.min(1, b.area.X / (longest * b.cw), b.area.Y / (count * b.lh))
    set_font_size(b, math.max(6, math.floor(b.font_size * scale)))
end

-- game_moved: the game has just shown a video, its own state of the screen stays.
local function close_book(game_moved)
    local b = book
    book = nil
    if not b then return end
    if b.text_was then G.text_call(b.text, "SetText", b.text_was) end
    if b.size_set and b.font_size then set_font_size(b, b.font_size) end
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
    for _, p in ipairs(RT.wrap(B.camp[v.camp or 0] or B.camp[0], WIDTH, "")) do lines[#lines + 1] = p end
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
    for _, p in ipairs(RT.wrap(B.arrows, WIDTH, "")) do lines[#lines + 1] = p end
    return table.concat(lines, "\n")
end

local function render()
    local b = book
    if not b or not want then return end
    local text = page_text(want.id)
    fit(b, text)
    G.text_call(b.text, "SetText", text)
    set_visible(b.text, 0)                      -- 0: visible, 2: hidden
    set_visible(b.black, 0)
    set_visible(b.image, 2)                     -- a video stopped behind stays out of sight
    if U.valid(b.head) then G.text_call(b.head, "SetText", string.format(S.BOOK.head, want.n, want.total)) end
    redraw(b)
    if not logged_size then
        logged_size = true
        U.log("Encyclopédie : police de la page %s (celle du jeu : %s)", tostring(b.size_set), tostring(b.font_size))
    end
end

-- The page the host wants, on this machine's screen (false: not there yet, the lobby is loading).
local function show()
    if not want then return true end
    if not book then
        local pc, screen = find_screen()
        if not open_book(pc, screen) then return false end
    end
    render()
    return true
end

-- The game's own screen again (a game begins, another host).
function BK.close()
    want = nil
    if book then close_book(false) end
end

-- The host's "BOOKPAGE role number total" ("BOOKPAGE -": the game's own screen).
function BK.on_page(id, n, total)
    if type(id) ~= "string" or id == "" or id == "-" then return BK.close() end
    want = { id = id, n = tonumber(n) or 0, total = tonumber(total) or 0 }
    show()
end

-- The host's "BOOK role values".
function BK.on_book(role, text)
    if type(role) ~= "string" or role == "" then return end
    pages[role] = RT.parse(text)
    if book and want and want.id == role then render() end
end

-- A new host: its pages come again.
function BK.reset()
    BK.close()
    pages = {}
end

local last_tick = 0
local function tick(now)
    if not want or now - last_tick < 0.5 then return end
    last_tick = now
    local b = book
    if not b then return show() end
    -- the widgets went away (another level): shown again when they come back, if still wanted
    if not U.valid(b.text) then
        book = nil
        return
    end
    -- the game hid the screen's text (a video started) and the hook did not say so
    if visibility(b.text) == 2 then
        want = nil
        return close_book(true)
    end
    -- a video the game plays late under the page (one still opening when the arrow was pushed):
    -- paused again on this machine; on the host, stopped for everyone (players without the mod too)
    pcall(function()
        local mp = U.get(b.sw, "MediaPlayer", nil)
        if not (U.valid(mp) and mp:IsPlaying()) then return end
        if G.is_host() and U.valid(b.screen) then
            U.tcall(b.screen, "Waiting Video")
        else
            mp:Pause()
        end
    end)
end

-- ---------------------------------------------------------------- host
-- What the host side lends (lpr_server.lua): each_player, tell, the game's state table (active)
-- and pages() (the pages sent to the players: { { role id, values }, ... }). A player's record
-- has book_sig once its pages were sent (lpr_server.lua, send_books).
local env = nil
local host = { page = nil, last = nil, msg = { "-" }, sig = "-", gm = nil, stopped_at = nil, screen = nil }

-- Another lobby hosted (a new game mode): there, the game's own screen until an arrow is pushed
-- (the page shown last still comes back first).
local function host_session()
    local gm = G.gm()
    local addr = U.valid(gm) and gm:GetAddress() or nil
    if addr ~= host.gm then
        host.gm, host.page, host.msg, host.sig, host.stopped_at, host.screen = addr, nil, { "-" }, "-", nil, nil
    end
end

-- The page shown to every machine with the mod, sent again to those that do not have it yet
-- (a player who has just come, a new page), after the pages themselves. A player never told
-- anything needs no "-".
function BK.host_sync()
    if not env then return end
    host_session()
    -- a video playing under the page on the host (one still opening when it was stopped plays
    -- once open): stopped again for everyone, players without the mod too
    if host.page and U.valid(host.screen) and not env.game.active then
        local ok, playing = pcall(function()
            return U.get(U.get(host.screen, "Screen", nil), "MediaPlayer", nil):IsPlaying()
        end)
        if ok and playing then
            U.tcall(host.screen, "Waiting Video")
            U.log("Encyclopédie : vidéo qui jouait sous la page, arrêtée")
        end
    end
    env.each_player(function(P)
        if P.modded and P.book_sig and P.page_sig ~= host.sig then
            local first = P.page_sig == nil
            P.page_sig = host.sig
            if host.page or not first then env.tell(P, "BOOKPAGE", table.unpack(host.msg)) end
        end
    end)
end

-- Page `id` (number n of total) for everyone; nil: the game's own screen.
local function host_show(id, n, total)
    if not env then return end
    host.page = id
    if id then
        host.last = id
        host.msg = { id, n, total }
    else
        host.msg = { "-" }
    end
    host.sig = table.concat(host.msg, ".")
    BK.host_sync()
end

-- A game begins: the screen is the game's again (the page shown last comes back first next time).
function BK.host_close()
    if host.page then host_show(nil) end
end

-- Stops the video for everyone (the game's idle screen), and again a little later while the page
-- is still shown: a video still opening on some machine starts by itself once open, whatever was
-- asked before. A video started on purpose goes through Show Video(true), which takes the page away.
local function stop_video(screen)
    if not U.valid(screen) then return end
    host.screen = screen
    U.tcall(screen, "Waiting Video")
    for _, delay in ipairs({ 0.6, 1.5, 3 }) do
        U.after(delay, "encyclopédie : vidéo arrêtée", function()
            if host.page and env and G.is_host() and not env.game.active and U.valid(screen) then
                U.tcall(screen, "Waiting Video")
            end
        end)
    end
end

local function host_ids()
    local ids = {}
    for _, p in ipairs(env.pages() or {}) do ids[#ids + 1] = p[1] end
    table.sort(ids, function(a, b) return sort_key(a) < sort_key(b) end)
    return ids
end

-- One of the computer's arrows was pushed (dir: 1 right, -1 left), by `source`.
local function on_arrow(dir, pc, source)
    if not env or not G.is_host() or env.game.active then return end
    host_session()
    local ids = host_ids()
    if #ids == 0 then return end
    local at = 0
    for k, id in ipairs(ids) do
        if id == (host.page or host.last) then at = k end
    end
    if at == 0 then
        at = dir > 0 and 1 or #ids
    elseif host.page then
        at = (at - 1 + dir) % #ids + 1
    end                                         -- closed: the page shown last comes back first
    -- a video playing (or paused) stops for everyone, the way the game itself goes back to its idle screen
    local screen = U.valid(pc) and U.get(pc, "World Screen", nil) or nil
    if U.valid(screen) then host.screen = screen end
    if U.valid(screen) and not U.get(screen, "Waiting", true) then
        host.stopped_at = U.now()
        stop_video(screen)
    end
    host_show(ids[at], at, #ids)
    U.log("Encyclopédie : %s montre %s (%d/%d)", U.valid(source) and G.player_name(source) or "?", ids[at], at, #ids)
end

function BK.setup(e)
    env = e
    for dir, fname in pairs(ARROW) do
        U.hook(PC .. ":" .. fname, function(ctx, source)
            local ok, who = pcall(function() return source:get() end)
            on_arrow(dir, ctx:get(), ok and who or nil)
        end)
    end
    -- The right arrow 10 s or less before the end of a video: the game's own jump reaches the end,
    -- and the game has just started the next video (which closed the page): stopped again, page back.
    U.hook(PC .. ":Video End", function(ctx)
        if not (env and G.is_host() and not env.game.active) then return end
        if host.page or not host.last or not host.stopped_at or U.now() - host.stopped_at > 2 then return end
        host.stopped_at = nil
        local pc = ctx:get()
        local screen = U.valid(pc) and U.get(pc, "World Screen", nil) or nil
        local ids = host_ids()
        for k, id in ipairs(ids) do
            if id == host.last then
                stop_video(screen)              -- first: the page then opens on the game's idle screen
                host_show(id, k, #ids)
                return U.log("Encyclopédie : la vidéo suivante, lancée par le saut à la fin, est arrêtée")
            end
        end
    end)
    -- The game plays a video late under the page (a player's arrival catches the screen up a tenth
    -- of a second after it was stopped): stopped again for everyone. Every video started on purpose
    -- goes through Set Video, whose Show Video(true) has already put the game's screen back.
    U.hook(SCREEN .. ":Play Video", function(ctx)
        if not (host.page and env and G.is_host() and not env.game.active) then return end
        stop_video(ctx:get())
        U.log("Encyclopédie : vidéo relancée par le jeu sous la page, arrêtée")
    end)
end

-- ---------------------------------------------------------------- every machine
function BK.install()
    U.hook(SCREEN_W .. ":Show Video", function(ctx, flag)
        local ok, shown = pcall(function() return flag:get() end)
        if not (ok and shown == true) then return end
        -- a video starts: the game's screen, on every machine (each one hears it), and for the host
        local b = book
        local w = ctx:get()
        if b and U.valid(w) and U.valid(b.sw) and w:GetAddress() == b.sw:GetAddress() then
            want = nil
            close_book(true)
        elseif not b then
            want = nil
        end
        if host.page and G.is_host() then host_show(nil) end
    end)
    U.every_tick("encyclopédie", tick)
end

return BK
