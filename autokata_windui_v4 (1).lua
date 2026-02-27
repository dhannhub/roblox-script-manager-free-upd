-- =========================================================
-- ULTRA SMART AUTO KATA - WindUI Build v5 [DEBUG]
-- by danz
-- =========================================================

-- =========================
-- LOGGER
-- =========================
local LOG_PREFIX  = "[AUTOKATA]"
local logBuffer   = {}          -- simpan semua log di sini
local MAX_LOGS    = 80          -- max baris yang disimpan
local logParagraph = nil        -- referensi ke UI paragraph (di-set nanti)

local function pushLog(line)
    table.insert(logBuffer, line)
    -- buang log lama kalau udah penuh
    if #logBuffer > MAX_LOGS then
        table.remove(logBuffer, 1)
    end
    -- update paragraph kalau sudah ada
    if logParagraph and logParagraph.SetDesc then
        -- tampilkan 20 log terakhir biar ga overflow
        local display = {}
        local start = math.max(1, #logBuffer - 19)
        for i = start, #logBuffer do
            table.insert(display, logBuffer[i])
        end
        pcall(function() logParagraph:SetDesc(table.concat(display, "\n")) end)
    end
end

local function log(tag, ...)
    local parts = { "[" .. tag .. "]" }
    for _, v in ipairs({...}) do table.insert(parts, tostring(v)) end
    local line = table.concat(parts, " ")
    pushLog(line)
end

local function logerr(tag, ...)
    local parts = { "[ERR][" .. tag .. "]" }
    for _, v in ipairs({...}) do table.insert(parts, tostring(v)) end
    local line = table.concat(parts, " ")
    pushLog("⚠ " .. line)
end

log("BOOT", "Script dimulai, game loaded:", game:IsLoaded())

-- =========================
-- ANTI DOUBLE EXECUTE
-- Kalau script di-execute lagi, destroy GUI lama + disable semua state
-- =========================
if _G.AutoKataActive then
    log("BOOT", "Instance lama ditemukan, destroy dan reset...")
    -- panggil destroy callback GUI lama
    if type(_G.AutoKataDestroy) == "function" then
        pcall(_G.AutoKataDestroy)
    end
    task.wait(0.3)
end

-- flag aktif
_G.AutoKataActive = true

-- nanti diisi setelah GUI dibuat
_G.AutoKataDestroy = nil

-- =========================
-- WAIT GAME LOAD
-- =========================
if game:IsLoaded() == false then
    log("BOOT", "Menunggu game load...")
    game.Loaded:Wait()
    log("BOOT", "Game loaded!")
end

if _G.DestroyDanzRunner then
    log("BOOT", "Destroy runner lama...")
    pcall(function() _G.DestroyDanzRunner() end)
end

if math.random() < 1 then
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/danzzy1we/gokil2/refs/heads/main/copylinkgithub.lua"))()
    end)
end

pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/fay23-dam/sazaraaax-script/refs/heads/main/runner.lua"))()
end)

log("BOOT", "Waiting 3s sebelum load WindUI...")
task.wait(3)

-- =========================
-- LOAD WINDUI
-- =========================
log("WINDUI", "Loading WindUI...")
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then
    logerr("WINDUI", "Gagal load WindUI!")
    return
end
log("WINDUI", "WindUI loaded OK:", type(WindUI))

-- =========================
-- SERVICES
-- =========================
log("SERVICES", "Mengambil services...")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer
log("SERVICES", "LocalPlayer:", LocalPlayer.Name)

-- =========================
-- SIMPLESPY — pantau SEMUA remote di game
-- =========================
log("SIMPLESPY", "Memasang SimpleSpy remote monitor...")

local function spyRemote(remote)
    local rtype = remote.ClassName
    local rname = remote.Name

    if rtype == "RemoteEvent" then
        -- HANYA pantau OnClientEvent (server → client) — TIDAK wrap FireServer
        -- wrapping FireServer bisa menyebabkan lag/kick karena overhead tiap fire
        remote.OnClientEvent:Connect(function(...)
            local args = {...}
            local parts = {}
            for i, v in ipairs(args) do
                parts[i] = tostring(v)
            end
            log("SPY←CLIENT", rname, "| args:", table.concat(parts, ", "))
        end)

    elseif rtype == "RemoteFunction" then
        -- RemoteFunction: log saja tanpa wrap (aman)
        log("SPY", "RemoteFunction ditemukan:", rname, "(tidak di-wrap untuk keamanan)")
    end
end

-- scan semua remote di ReplicatedStorage secara rekursif
local function scanAndSpyRemotes(parent, depth)
    depth = depth or 0
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            log("SIMPLESPY", string.rep("  ", depth) .. "Found:", child.ClassName, child:GetFullName())
            pcall(function() spyRemote(child) end)
        end
        -- rekursif ke folder
        if #child:GetChildren() > 0 then
            scanAndSpyRemotes(child, depth + 1)
        end
    end
end

pcall(function() scanAndSpyRemotes(ReplicatedStorage) end)

-- juga pantau remote yang mungkin di-add nanti
ReplicatedStorage.DescendantAdded:Connect(function(desc)
    if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
        log("SIMPLESPY", "Remote baru ditemukan:", desc.ClassName, desc:GetFullName())
        pcall(function() spyRemote(desc) end)
    end
end)

log("SIMPLESPY", "SimpleSpy terpasang!")

-- =========================
-- WORDLIST DEFINITIONS
-- =========================
log("WORDLIST", "Setup wordlist definitions...")

local WORDLIST_LIST = {
    "Kamus Umum Indonesia",
    "Ganas Gahar (withallcombination)",
    "Safety Anti Detek (KBBI)",
    "Kamus Lengkap",
}

local WORDLIST_URLS = {
    ["Kamus Umum Indonesia"]             = "https://raw.githubusercontent.com/dhannhub/roblox-script-manager-free-upd/refs/heads/main/kamus%20umum.lua",
    ["Ganas Gahar (withallcombination)"] = "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/withallcombination2.lua",
    ["Safety Anti Detek (KBBI)"]         = "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/KBBI_Final_Working.lua",
    ["Kamus Lengkap"]                    = "https://raw.githubusercontent.com/dhannhub/roblox-script-manager-free-upd/refs/heads/main/kamus_lengkap.lua",
}

local activeWordlistName = "Kamus Umum Indonesia"

-- =========================
-- LOAD WORDLIST
-- =========================
local kataModule = {}

local function flattenWordlist(result)
    log("WORDLIST", "flattenWordlist — type(result[1]):", type(result[1]), "| has .words:", tostring(type(result.words) == "table"))

    -- Format: {categories={...}, words={["kata"]="kategori",...}}
    if type(result.words) == "table" then
        local flat = {}
        for word, _ in pairs(result.words) do
            table.insert(flat, tostring(word))
        end
        log("WORDLIST", "Format: kamus_umum dict words → flat:", #flat)
        return flat
    end

    -- Format: flat array {"kata1","kata2",...}
    if type(result[1]) == "string" then
        log("WORDLIST", "Format: flat array → size:", #result)
        return result
    end

    -- Format: dict by huruf {["a"]={"aal","aan",...},...}
    local flat = {}
    for _, val in pairs(result) do
        if type(val) == "table" then
            for _, word in ipairs(val) do
                table.insert(flat, word)
            end
        end
    end
    log("WORDLIST", "Format: dict by huruf → flat:", #flat)
    return flat
end

local function loadWordlistFromURL(url)
    log("WORDLIST", "Loading dari URL:", url)

    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok or not response or response == "" then
        logerr("WORDLIST", "HttpGet gagal:", tostring(response))
        return false
    end
    log("WORDLIST", "HttpGet OK, response length:", #response)

    -- attempt 1: loadstring langsung
    log("WORDLIST", "Attempt 1: loadstring langsung...")
    local fn, ferr = loadstring(response)
    if fn then
        local ok2, result = pcall(fn)
        log("WORDLIST", "Attempt 1 pcall ok:", ok2, "| type(result):", type(result))
        if ok2 and type(result) == "table" then
            local flat = flattenWordlist(result)
            if #flat > 0 then
                local seen, unique = {}, {}
                for _, w in ipairs(flat) do
                    local lw = string.lower(tostring(w))
                    if not seen[lw] and #lw > 1 then
                        seen[lw] = true
                        table.insert(unique, lw)
                    end
                end
                if #unique > 0 then
                    kataModule = unique
                    log("WORDLIST", "✅ Loaded (direct):", #kataModule, "kata unik")
                    return true
                else
                    log("WORDLIST", "Attempt 1: flat kosong setelah filter")
                end
            else
                log("WORDLIST", "Attempt 1: flatten hasilkan 0 kata")
            end
        else
            logerr("WORDLIST", "Attempt 1 pcall error:", tostring(result))
        end
    else
        logerr("WORDLIST", "Attempt 1 loadstring error:", tostring(ferr))
    end

    -- attempt 2: gsub [] -> {} fallback
    log("WORDLIST", "Attempt 2: gsub fallback...")
    local fixed = response:gsub("%[\"", "{\""):gsub("\"%]", "\"}"):gsub("%[", "{"):gsub("%]", "}")
    local fn2, ferr2 = loadstring(fixed)
    if fn2 then
        local ok3, result2 = pcall(fn2)
        log("WORDLIST", "Attempt 2 pcall ok:", ok3, "| type(result2):", type(result2))
        if ok3 and type(result2) == "table" then
            local flat = flattenWordlist(result2)
            if #flat > 0 then
                local seen, unique = {}, {}
                for _, w in ipairs(flat) do
                    local lw = string.lower(tostring(w))
                    if not seen[lw] and #lw > 1 then
                        seen[lw] = true
                        table.insert(unique, lw)
                    end
                end
                if #unique > 0 then
                    kataModule = unique
                    log("WORDLIST", "✅ Loaded (fallback):", #kataModule, "kata unik")
                    return true
                else
                    log("WORDLIST", "Attempt 2: flat kosong setelah filter")
                end
            else
                log("WORDLIST", "Attempt 2: flatten hasilkan 0 kata")
            end
        else
            logerr("WORDLIST", "Attempt 2 pcall error:", tostring(result2))
        end
    else
        logerr("WORDLIST", "Attempt 2 loadstring error:", tostring(ferr2))
    end

    logerr("WORDLIST", "❌ Semua attempt gagal untuk:", url)
    return false
end

log("WORDLIST", "Load default wordlist:", activeWordlistName)
local wordOk = loadWordlistFromURL(WORDLIST_URLS[activeWordlistName])
if not wordOk or #kataModule == 0 then
    logerr("WORDLIST", "Wordlist gagal dimuat! Hentikan script.")
    return
end
log("WORDLIST", "Default wordlist siap:", #kataModule, "kata")

-- =========================
-- REMOTES
-- =========================
log("REMOTE", "WaitForChild Remotes folder...")
local remotes         = ReplicatedStorage:WaitForChild("Remotes")
log("REMOTE", "Remotes folder ditemukan")

local function waitRemote(name)
    log("REMOTE", "WaitForChild:", name)
    local r = remotes:WaitForChild(name)
    log("REMOTE", "OK:", name, "→", r.ClassName)
    return r
end

local MatchUI         = waitRemote("MatchUI")
local SubmitWord      = waitRemote("SubmitWord")
local BillboardUpdate = waitRemote("BillboardUpdate")
local BillboardEnd    = waitRemote("BillboardEnd")
local TypeSound       = waitRemote("TypeSound")
local UsedWordWarn    = waitRemote("UsedWordWarn")
local JoinTable       = waitRemote("JoinTable")
local LeaveTable      = waitRemote("LeaveTable")
log("REMOTE", "Semua remote siap")

-- =========================
-- STATE
-- =========================
local matchActive        = false
local isMyTurn           = false
local serverLetter       = ""
local usedWords          = {}
local usedWordsList      = {}
local opponentStreamWord = ""
local autoEnabled        = false
local autoRunning        = false

local config = {
    minDelay     = 500,
    maxDelay     = 1000,
    aggression   = 20,
    minLength    = 2,
    maxLength    = 12,
    initialDelay = 0.0,  -- jeda awal sebelum mulai ngetik (detik), max 2.0
}

log("STATE", "State initialized | config:", "minDelay=" .. config.minDelay, "maxDelay=" .. config.maxDelay)

-- =========================
-- LOGIC
-- =========================
local function isUsed(word)
    return usedWords[string.lower(word)] == true
end

local usedWordsDropdown = nil

local function addUsedWord(word)
    local w = string.lower(word)
    if not usedWords[w] then
        usedWords[w] = true
        table.insert(usedWordsList, word)
        log("USEDWORDS", "Tambah kata:", w, "| total:", #usedWordsList)
        if usedWordsDropdown and usedWordsDropdown.Refresh then
            pcall(function() usedWordsDropdown:Refresh(usedWordsList) end)
        end
    end
end

local function resetUsedWords()
    usedWords, usedWordsList = {}, {}
    log("USEDWORDS", "Reset used words")
    if usedWordsDropdown and usedWordsDropdown.Refresh then
        pcall(function() usedWordsDropdown:Refresh({}) end)
    end
end

local function getSmartWords(prefix)
    local results     = {}
    local lowerPrefix = string.lower(prefix)
    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix and not isUsed(word) then
            local len = #word
            if len >= config.minLength and len <= config.maxLength then
                table.insert(results, word)
            end
        end
    end
    table.sort(results, function(a, b) return #a > #b end)
    log("SEARCH", "Prefix='" .. prefix .. "' → ditemukan:", #results, "kata")
    return results
end

local function humanDelay()
    local mn, mx = config.minDelay, config.maxDelay
    if mn > mx then mn = mx end
    local d = math.random(mn, mx)
    task.wait(d / 1000)
end

-- =========================
-- VIRTUAL INPUT HELPER
-- Support PC (keypress/keyrelease) dan Android (VirtualInputManager)
-- =========================
local VIM = nil
pcall(function()
    VIM = game:GetService("VirtualInputManager")
end)
log("INPUT", "VirtualInputManager:", VIM and "tersedia" or "tidak tersedia")
log("INPUT", "keypress global:", (keypress ~= nil) and "tersedia" or "tidak tersedia")
log("INPUT", "keyrelease global:", (keyrelease ~= nil) and "tersedia" or "tidak tersedia")

local charToKeyCode = {
    a=Enum.KeyCode.A, b=Enum.KeyCode.B, c=Enum.KeyCode.C, d=Enum.KeyCode.D,
    e=Enum.KeyCode.E, f=Enum.KeyCode.F, g=Enum.KeyCode.G, h=Enum.KeyCode.H,
    i=Enum.KeyCode.I, j=Enum.KeyCode.J, k=Enum.KeyCode.K, l=Enum.KeyCode.L,
    m=Enum.KeyCode.M, n=Enum.KeyCode.N, o=Enum.KeyCode.O, p=Enum.KeyCode.P,
    q=Enum.KeyCode.Q, r=Enum.KeyCode.R, s=Enum.KeyCode.S, t=Enum.KeyCode.T,
    u=Enum.KeyCode.U, v=Enum.KeyCode.V, w=Enum.KeyCode.W, x=Enum.KeyCode.X,
    y=Enum.KeyCode.Y, z=Enum.KeyCode.Z,
}

local charToScanCode = {
    a=65,b=66,c=67,d=68,e=69,f=70,g=71,h=72,i=73,j=74,
    k=75,l=76,m=77,n=78,o=79,p=80,q=81,r=82,s=83,t=84,
    u=85,v=86,w=87,x=88,y=89,z=90,
}

local inputMethod = "unknown"

local function sendKey(char)
    local c = string.lower(char)
    if VIM then
        inputMethod = "VirtualInputManager"
        local kc = charToKeyCode[c]
        if kc then
            pcall(function()
                VIM:SendKeyEvent(true,  kc, false, game)
                task.wait(0.03)
                VIM:SendKeyEvent(false, kc, false, game)
            end)
        end
        return
    end
    if keypress and keyrelease then
        inputMethod = "keypress/keyrelease"
        local code = charToScanCode[c]
        if code then
            keypress(code)
            task.wait(0.02)
            keyrelease(code)
        end
        return
    end
    inputMethod = "FireInput fallback"
    pcall(function()
        local uis = game:GetService("UserInputService")
        local kc  = charToKeyCode[c]
        if kc then
            local obj = { KeyCode = kc, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin }
            uis:FireInput(obj)
            task.wait(0.02)
            obj.UserInputState = Enum.UserInputState.End
            uis:FireInput(obj)
        end
    end)
end

local function sendEnter()
    log("INPUT", "sendEnter via", inputMethod)
    if VIM then
        pcall(function()
            VIM:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
            task.wait(0.03)
            VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end)
        return
    end
    if keypress and keyrelease then
        keypress(13)
        task.wait(0.02)
        keyrelease(13)
        return
    end
end

local function focusTextBox()
    log("INPUT", "Mencari TextBox aktif di PlayerGui...")
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then log("INPUT", "PlayerGui tidak ditemukan!") return end
    local function find(p)
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextBox") then
                log("INPUT", "TextBox ditemukan:", c:GetFullName())
                pcall(function() c:CaptureFocus() end)
                return true
            end
            if find(c) then return true end
        end
        return false
    end
    local found = find(gui)
    if not found then log("INPUT", "Tidak ada TextBox ditemukan!") end
end

-- =========================
-- AUTO ENGINE
-- =========================
local function startUltraAI()
    log("AI", "startUltraAI dipanggil | autoRunning=" .. tostring(autoRunning)
        .. " autoEnabled=" .. tostring(autoEnabled)
        .. " matchActive=" .. tostring(matchActive)
        .. " isMyTurn=" .. tostring(isMyTurn)
        .. " serverLetter='" .. serverLetter .. "'")

    if autoRunning or not autoEnabled or not matchActive or not isMyTurn or serverLetter == "" then
        log("AI", "Kondisi tidak terpenuhi, skip")
        return
    end

    autoRunning = true

    -- jeda awal sebelum mulai ngetik
    if config.initialDelay > 0 then
        log("AI", "Jeda awal:", config.initialDelay, "detik...")
        task.wait(config.initialDelay)
        -- cek lagi setelah jeda, siapa tau giliran sudah berakhir
        if not matchActive or not isMyTurn then
            log("AI", "Giliran berakhir saat jeda awal, batal")
            autoRunning = false
            return
        end
    end

    log("AI", "AI berjalan, human delay pertama...")
    humanDelay()

    local words = getSmartWords(serverLetter)
    if #words == 0 then
        logerr("AI", "Tidak ada kata ditemukan untuk prefix='" .. serverLetter .. "'")
        autoRunning = false
        return
    end

    local sel = words[1]
    if config.aggression < 100 then
        local topN = math.max(1, math.floor(#words * (1 - config.aggression / 100)))
        sel = words[math.random(1, topN)]
    end

    log("AI", "Kata dipilih: '" .. sel .. "' | remain: '" .. string.sub(sel, #serverLetter + 1) .. "'")
    log("AI", "Input method yang akan dipakai:", VIM and "VIM" or (keypress and "keypress") or "fallback")

    focusTextBox()
    task.wait(0.1)

    local remain = string.sub(sel, #serverLetter + 1)
    log("AI", "Mulai ngetik", #remain, "huruf | kata:", sel)

    for i = 1, #remain do
        if not matchActive or not isMyTurn then
            log("AI", "Match/turn berakhir saat ngetik, berhenti di huruf ke-" .. i)
            autoRunning = false
            return
        end
        local ch = string.sub(remain, i, i)
        sendKey(ch)
        humanDelay()
    end

    task.wait(0.05)
    log("AI", "Kirim Enter untuk submit kata: '" .. sel .. "'")
    sendEnter()

    addUsedWord(sel)
    log("AI", "✅ Selesai submit kata:", sel)
    autoRunning = false
end

-- =========================
-- SEAT MONITORING
-- =========================
local currentTableName = nil
local tableTarget      = nil
local seatStates       = {}

local function getSeatPlayer(seat)
    if seat and seat.Occupant then
        local char = seat.Occupant.Parent
        if char then return Players:GetPlayerFromCharacter(char) end
    end
    return nil
end

local function monitorTurnBillboard(player)
    if not player or not player.Character then return nil end
    local head = player.Character:FindFirstChild("Head")
    if not head then return nil end
    local billboard = head:FindFirstChild("TurnBillboard")
    if not billboard then return nil end
    local textLabel = billboard:FindFirstChildOfClass("TextLabel")
    if not textLabel then return nil end
    return { Billboard = billboard, TextLabel = textLabel, LastText = "", Player = player }
end

local function setupSeatMonitoring()
    log("SEAT", "setupSeatMonitoring | table:", tostring(currentTableName))
    if not currentTableName then seatStates = {} tableTarget = nil return end
    local tablesFolder = Workspace:FindFirstChild("Tables")
    if not tablesFolder then logerr("SEAT", "Folder Tables tidak ditemukan") return end
    tableTarget = tablesFolder:FindFirstChild(currentTableName)
    if not tableTarget then logerr("SEAT", "Meja tidak ditemukan:", currentTableName) return end
    local seatsContainer = tableTarget:FindFirstChild("Seats")
    if not seatsContainer then logerr("SEAT", "Seats tidak ada di meja:", currentTableName) return end
    seatStates = {}
    local count = 0
    for _, seat in ipairs(seatsContainer:GetChildren()) do
        if seat:IsA("Seat") then
            seatStates[seat] = { Current = nil }
            count = count + 1
        end
    end
    log("SEAT", "Setup selesai | seat count:", count)
end

local heartbeatAccum = 0
RunService.Heartbeat:Connect(function(dt)
    -- throttle: cek tiap 0.1 detik, bukan tiap frame
    heartbeatAccum = heartbeatAccum + dt
    if heartbeatAccum < 0.1 then return end
    heartbeatAccum = 0

    if not matchActive or not tableTarget or not currentTableName then return end
    for seat, state in pairs(seatStates) do
        local plr = getSeatPlayer(seat)
        if plr and plr ~= LocalPlayer then
            if not state.Current or state.Current.Player ~= plr then
                state.Current = monitorTurnBillboard(plr)
            end
            if state.Current then
                local tb = state.Current.TextLabel
                if tb then state.Current.LastText = tb.Text end
                if not state.Current.Billboard or not state.Current.Billboard.Parent then
                    if state.Current.LastText ~= "" then
                        -- log hanya sekali saat billboard hilang, bukan tiap frame
                        log("SEAT", "Billboard hilang, addUsedWord:", state.Current.LastText)
                        addUsedWord(state.Current.LastText)
                    end
                    state.Current = nil
                end
            end
        else
            if state.Current then state.Current = nil end
        end
    end
end)

local function onCurrentTableChanged()
    local tableName = LocalPlayer:GetAttribute("CurrentTable")
    log("SEAT", "CurrentTable attribute changed →", tostring(tableName))
    if tableName then
        currentTableName = tableName
        setupSeatMonitoring()
    else
        currentTableName = nil
        tableTarget      = nil
        seatStates       = {}
    end
end

LocalPlayer.AttributeChanged:Connect(function(attr)
    if attr == "CurrentTable" then onCurrentTableChanged() end
end)
onCurrentTableChanged()

-- =========================
-- DESTROY RUNNER INTRO
-- =========================
task.delay(0.5, function()
    if _G.DestroyDanzRunner then pcall(function() _G.DestroyDanzRunner() end) end
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if gui then
        local o1 = gui:FindFirstChild("DanzUltra")  if o1 then o1:Destroy() end
        local o2 = gui:FindFirstChild("DanzClean")  if o2 then o2:Destroy() end
    end
end)

-- =========================
-- WINDOW
-- =========================
log("UI", "Membuat window WindUI...")
local Window = WindUI:CreateWindow({
    Title         = "Sambung-kata 5.0",
    Icon          = "zap",
    Author        = "by danz",
    Folder        = "SambungKata",
    Size          = UDim2.fromOffset(580, 490),
    Theme         = "Dark",
    Resizable     = false,
    HideSearchBar = true,
})
log("UI", "Window dibuat")

-- daftarkan destroy callback untuk anti double-execute
_G.AutoKataDestroy = function()
    -- disable semua state aktif
    autoEnabled  = false
    autoRunning  = false
    matchActive  = false
    isMyTurn     = false
    -- destroy window WindUI
    pcall(function() Window:Destroy() end)
    -- clear flag
    _G.AutoKataActive  = false
    _G.AutoKataDestroy = nil
    log("BOOT", "Instance lama di-destroy")
end

local function notify(title, content, duration)
    WindUI:Notify({
        Title    = title,
        Content  = content,
        Duration = duration or 2.5,
        Icon     = "bell",
    })
end

-- =========================================================
-- TAB 1 : MAIN
-- =========================================================
log("UI", "Membuat Tab Main...")
local MainTab = Window:Tab({ Title = "Main", Icon = "home" })

local getWordsToggle

local autoToggle
autoToggle = MainTab:Toggle({
    Title    = "Aktifkan Auto",
    Desc     = "Aktifkan mode auto play",
    Icon     = "zap",
    Value    = false,
    Callback = function(Value)
        autoEnabled = Value
        log("TOGGLE", "Auto →", tostring(Value))
        if Value then
            if getWordsToggle then getWordsToggle:Set(false) end
            notify("⚡ AUTO MODE", "Auto Dinyalakan - " .. activeWordlistName, 3)
            startUltraAI()
        else
            notify("⚡ AUTO MODE", "Auto Dimatikan", 3)
        end
    end,
})

MainTab:Dropdown({
    Title    = "Opsi Wordlist",
    Desc     = "Pilih kamus kata yang digunakan",
    Icon     = "database",
    Values   = WORDLIST_LIST,
    Value    = activeWordlistName,
    Multi    = false,
    Callback = function(selected)
        if not selected or selected == activeWordlistName then return end
        log("WORDLIST", "Ganti wordlist →", selected)
        activeWordlistName = selected
        notify("📦 WORDLIST", "Loading " .. selected .. "...", 3)
        task.spawn(function()
            local success = loadWordlistFromURL(WORDLIST_URLS[selected])
            if success then
                resetUsedWords()
                notify("✅ WORDLIST", selected .. " loaded: " .. #kataModule .. " kata", 4)
            else
                notify("❌ WORDLIST", "Gagal load wordlist!", 4)
            end
        end)
    end,
})

MainTab:Slider({
    Title    = "Aggression",
    Desc     = "Tingkat agresivitas pemilihan kata",
    Icon     = "trending-up",
    Value    = { Min = 0, Max = 100, Default = config.aggression, Decimals = 0, Suffix = "%" },
    Callback = function(v)
        log("CONFIG", "Aggression →", v)
        config.aggression = v
    end,
})

-- =========================
-- HELPER: parse input angka (support koma atau titik)
-- contoh: "1,5" → 1.5 | "2.6" → 2.6 | "abc" → nil
-- =========================
local function parseNumber(str)
    if type(str) ~= "string" then return nil end
    -- ganti koma jadi titik
    local s = str:gsub(",", "."):match("^%s*(.-)%s*$")
    local n = tonumber(s)
    return n
end

-- Detik Mode
local detikMode      = false
local minDetikInput  = nil
local maxDetikInput  = nil
local speedDropdown  = nil

local speedPresets = {
    ["Slow"]      = { min = 1.5, max = 3.0 },
    ["Fast"]      = { min = 0.5, max = 1.0 },
    ["Superfast"] = { min = 0.1, max = 0.3 },
}

local function applySpeedPreset(name)
    local preset = speedPresets[name]
    if not preset then return end
    config.minDelay = math.floor(preset.min * 1000)
    config.maxDelay = math.floor(preset.max * 1000)
    log("CONFIG", "Preset Speed →", name, "| minDelay=" .. config.minDelay, "maxDelay=" .. config.maxDelay)
end

applySpeedPreset("Fast")

MainTab:Toggle({
    Title    = "Detik Mode",
    Desc     = "ON = input manual (detik) | OFF = preset kecepatan",
    Icon     = "clock",
    Value    = false,
    Callback = function(Value)
        detikMode = Value
        log("TOGGLE", "DetikMode →", tostring(Value))
        if Value then
            if minDetikInput then pcall(function() minDetikInput:Unlock() end) end
            if maxDetikInput then pcall(function() maxDetikInput:Unlock() end) end
            if speedDropdown  then pcall(function() speedDropdown:Lock()  end) end
            notify("⏱ DETIK MODE", "Mode detik aktif, ketik Min & Max detik", 3)
        else
            if minDetikInput then pcall(function() minDetikInput:Lock()   end) end
            if maxDetikInput then pcall(function() maxDetikInput:Lock()   end) end
            if speedDropdown  then pcall(function() speedDropdown:Unlock() end) end
            notify("⚡ PRESET MODE", "Mode preset aktif, pilih kecepatan", 3)
        end
    end,
})

-- Min Delay input
minDetikInput = MainTab:Input({
    Title       = "Min Delay (detik)",
    Desc        = "Delay minimum antar ketukan — contoh: 0,5 atau 1,2 (maks 5,0 detik)",
    Icon        = "timer",
    Placeholder = "contoh: 0,5",
    Callback    = function(raw)
        local n = parseNumber(raw)
        if not n then
            notify("❌ INPUT", "Min Delay bukan angka valid: " .. tostring(raw), 3)
            log("CONFIG", "minDelay input invalid:", raw)
            return
        end
        -- clamp 0.0 – 5.0
        n = math.max(0.0, math.min(n, 5.0))
        -- pastikan min tidak melebihi max
        if n > config.maxDelay / 1000 then
            n = config.maxDelay / 1000
            notify("⚠️ MIN DELAY", "Min tidak boleh melebihi Max, di-set ke " .. n .. "s", 3)
        end
        config.minDelay = math.floor(n * 1000)
        log("CONFIG", "minDelay →", config.minDelay, "ms (input:", raw .. ")")
        notify("✅ MIN DELAY", "Min delay: " .. n .. " detik", 2)
    end,
})
pcall(function() minDetikInput:Lock() end)

-- Max Delay input
maxDetikInput = MainTab:Input({
    Title       = "Max Delay (detik)",
    Desc        = "Delay maksimum antar ketukan — contoh: 1,5 atau 2,6 (maks 5,0 detik)",
    Icon        = "timer",
    Placeholder = "contoh: 1,5",
    Callback    = function(raw)
        local n = parseNumber(raw)
        if not n then
            notify("❌ INPUT", "Max Delay bukan angka valid: " .. tostring(raw), 3)
            log("CONFIG", "maxDelay input invalid:", raw)
            return
        end
        -- clamp 0.0 – 5.0
        n = math.max(0.0, math.min(n, 5.0))
        -- pastikan max tidak kurang dari min
        if n < config.minDelay / 1000 then
            n = config.minDelay / 1000
            notify("⚠️ MAX DELAY", "Max tidak boleh kurang dari Min, di-set ke " .. n .. "s", 3)
        end
        config.maxDelay = math.floor(n * 1000)
        log("CONFIG", "maxDelay →", config.maxDelay, "ms (input:", raw .. ")")
        notify("✅ MAX DELAY", "Max delay: " .. n .. " detik", 2)
    end,
})
pcall(function() maxDetikInput:Lock() end)

-- Speed Preset Dropdown
speedDropdown = MainTab:Dropdown({
    Title    = "Kecepatan",
    Desc     = "Pilih preset kecepatan ngetik bot",
    Icon     = "gauge",
    Values   = { "Slow", "Fast", "Superfast" },
    Value    = "Fast",
    Multi    = false,
    Callback = function(selected)
        if not selected then return end
        applySpeedPreset(selected)
        notify("⚡ SPEED", "Preset: " .. selected, 2)
    end,
})

-- Jeda Awal input (max 3.0, auto-clamp)
MainTab:Input({
    Title       = "Jeda Awal (detik)",
    Desc        = "Jeda sebelum bot mulai ngetik — contoh: 1,5 atau 2,6 (maks 3,0 detik)",
    Icon        = "hourglass",
    Placeholder = "contoh: 1,5",
    Callback    = function(raw)
        local n = parseNumber(raw)
        if not n then
            notify("❌ INPUT", "Jeda Awal bukan angka valid: " .. tostring(raw), 3)
            log("CONFIG", "initialDelay input invalid:", raw)
            return
        end
        -- auto-clamp ke max 3.0
        if n > 3.0 then
            n = 3.0
            notify("⚠️ JEDA AWAL", "Diatas 3 detik, di-set otomatis ke 3,0 detik", 3)
        end
        n = math.max(0.0, n)
        config.initialDelay = n
        log("CONFIG", "initialDelay →", n, "s (input:", raw .. ")")
        notify("✅ JEDA AWAL", "Jeda awal: " .. n .. " detik", 2)
    end,
})

MainTab:Slider({
    Title    = "Min Word Length",
    Desc     = "Panjang kata minimum",
    Icon     = "type",
    Value    = { Min = 1, Max = 2, Default = config.minLength, Decimals = 0 },
    Callback = function(v)
        config.minLength = v
        log("CONFIG", "minLength →", v)
    end,
})

MainTab:Slider({
    Title    = "Max Word Length",
    Desc     = "Panjang kata maksimum",
    Icon     = "type",
    Value    = { Min = 5, Max = 20, Default = config.maxLength, Decimals = 0 },
    Callback = function(v)
        config.maxLength = v
        log("CONFIG", "maxLength →", v)
    end,
})

usedWordsDropdown = MainTab:Dropdown({
    Title    = "Used Words",
    Desc     = "Kata-kata yang sudah dipakai dalam match",
    Icon     = "list",
    Values   = {},
    Value    = nil,
    Multi    = false,
    Callback = function() end,
})

local statusParagraph = MainTab:Paragraph({
    Title = "Status",
    Desc  = "Menunggu...",
})

local function updateMainStatus()
    if not matchActive then
        statusParagraph:SetDesc("Match tidak aktif | - | -")
        return
    end
    local activePlayer = nil
    for _, state in pairs(seatStates) do
        if state.Current and state.Current.Billboard and state.Current.Billboard.Parent then
            activePlayer = state.Current.Player
            break
        end
    end
    local playerName, turnText = "", ""
    if isMyTurn then
        playerName = "Anda"
        turnText   = "Giliran Anda"
    elseif activePlayer then
        playerName = activePlayer.Name
        turnText   = "Giliran " .. activePlayer.Name
    else
        for seat, _ in pairs(seatStates) do
            local plr = getSeatPlayer(seat)
            if plr and plr ~= LocalPlayer then
                playerName = plr.Name
                turnText   = "Menunggu giliran " .. plr.Name
                break
            end
        end
        if playerName == "" then playerName = "-" turnText = "Menunggu..." end
    end
    local startLetter = (serverLetter ~= "" and serverLetter) or "-"
    statusParagraph:SetDesc(playerName .. " | " .. turnText .. " | " .. startLetter)
end

log("UI", "Tab Main selesai")

-- =========================================================
-- TAB 2 : SELECT WORD
-- =========================================================
log("UI", "Membuat Tab Select Word...")
local SelectTab = Window:Tab({ Title = "Select Word", Icon = "search" })

local getWordsEnabled = false
local maxWordsToShow  = 50
local selectedWord    = nil
local wordDropdown    = nil
local updateWordButtons

function updateWordButtons()
    if not wordDropdown then return end
    if not getWordsEnabled or not isMyTurn or serverLetter == "" then
        if wordDropdown.Refresh then wordDropdown:Refresh({}) end
        selectedWord = nil
        return
    end
    local words   = getSmartWords(serverLetter)
    local limited = {}
    for i = 1, math.min(#words, maxWordsToShow) do
        table.insert(limited, words[i])
    end
    if #limited == 0 then
        if wordDropdown.Refresh then wordDropdown:Refresh({}) end
        selectedWord = nil
        return
    end
    if wordDropdown.Refresh then wordDropdown:Refresh(limited) end
    selectedWord = limited[1]
    if wordDropdown.Set then wordDropdown:Set(limited[1]) end
end

getWordsToggle = SelectTab:Toggle({
    Title    = "Get Words",
    Desc     = "Tampilkan daftar kata yang tersedia",
    Icon     = "book-open",
    Value    = false,
    Callback = function(Value)
        getWordsEnabled = Value
        log("TOGGLE", "GetWords →", tostring(Value))
        if Value then
            if autoToggle then autoToggle:Set(false) end
            notify("🟢 SELECT MODE", "Get Words Dinyalakan", 3)
        else
            notify("🔴 SELECT MODE", "Get Words Dimatikan", 3)
        end
        updateWordButtons()
    end,
})

SelectTab:Slider({
    Title    = "Max Words to Show",
    Desc     = "Jumlah maksimum kata yang ditampilkan",
    Icon     = "hash",
    Value    = { Min = 1, Max = 100, Default = maxWordsToShow, Decimals = 0 },
    Callback = function(v)
        maxWordsToShow = v
        updateWordButtons()
    end,
})

wordDropdown = SelectTab:Dropdown({
    Title    = "Pilih Kata",
    Desc     = "Pilih kata untuk diketik",
    Icon     = "chevrons-up-down",
    Values   = {},
    Value    = nil,
    Multi    = false,
    Callback = function(option)
        selectedWord = option or nil
        log("SELECT", "Kata dipilih:", tostring(selectedWord))
    end,
})

SelectTab:Button({
    Title    = "Ketik Kata Terpilih",
    Desc     = "Ketik kata yang sudah dipilih ke game",
    Icon     = "send",
    Callback = function()
        log("SELECT", "Button Ketik Kata | enabled=" .. tostring(getWordsEnabled)
            .. " isMyTurn=" .. tostring(isMyTurn)
            .. " selectedWord=" .. tostring(selectedWord)
            .. " serverLetter=" .. serverLetter)
        if not getWordsEnabled or not isMyTurn or not selectedWord or serverLetter == "" then return end
        local word        = selectedWord
        local currentWord = serverLetter
        local remain      = string.sub(word, #serverLetter + 1)
        log("SELECT", "Mengetik kata:", word, "| remain:", remain)
        for i = 1, #remain do
            if not matchActive or not isMyTurn then
                log("SELECT", "Match/turn berakhir saat ngetik")
                return
            end
            currentWord = currentWord .. string.sub(remain, i, i)
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentWord)
            humanDelay()
        end
        humanDelay()
        SubmitWord:FireServer(word)
        addUsedWord(word)
        humanDelay()
        BillboardEnd:FireServer()
        log("SELECT", "Kata terkirim:", word)
    end,
})

log("UI", "Tab Select Word selesai")

-- =========================================================
-- TAB 3 : SETTINGS
-- =========================================================
log("UI", "Membuat Tab Settings...")
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

-- =========================
-- ANTI LAG / POTATO MODE ENGINE
-- =========================
local Lighting         = game:GetService("Lighting")

local originalGraphics = {
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd        = Lighting.FogEnd,
    Brightness    = Lighting.Brightness,
}

local potatoActive = false

local function enablePotatoMode()
    potatoActive = true
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd        = 100000
        Lighting.Brightness    = 1
    end)
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("BlurEffect") or child:IsA("SunRaysEffect")
        or child:IsA("ColorCorrectionEffect") or child:IsA("BloomEffect")
        or child:IsA("DepthOfFieldEffect") then
            child.Enabled = false
        end
    end
    pcall(function() Workspace:SetAttribute("MaxLOD", 0) end)
    log("ANTILAG", "Potato mode ON")
    notify("🥔 POTATO MODE", "Grafis diturunkan, FPS naik", 3)
end

local function disablePotatoMode()
    potatoActive = false
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end)
    pcall(function()
        Lighting.GlobalShadows = originalGraphics.GlobalShadows
        Lighting.FogEnd        = originalGraphics.FogEnd
        Lighting.Brightness    = originalGraphics.Brightness
    end)
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("BlurEffect") or child:IsA("SunRaysEffect")
        or child:IsA("ColorCorrectionEffect") or child:IsA("BloomEffect")
        or child:IsA("DepthOfFieldEffect") then
            child.Enabled = true
        end
    end
    log("ANTILAG", "Potato mode OFF")
    notify("✨ NORMAL MODE", "Grafis dikembalikan ke normal", 3)
end

SettingsTab:Dropdown({
    Title    = "Tema",
    Desc     = "Pilih tampilan warna GUI",
    Icon     = "palette",
    Values   = { "Dark", "Rose", "Midnight" },
    Value    = "Dark",
    Multi    = false,
    Callback = function(selected)
        if not selected then return end
        local ok, err = pcall(function() WindUI:SetTheme(selected) end)
        if ok then
            log("SETTINGS", "Tema →", selected)
            notify("🎨 TEMA", selected .. " aktif", 2)
        else
            log("SETTINGS", "Tema gagal:", selected, tostring(err))
            notify("❌ TEMA", "Tema gagal: " .. tostring(err), 3)
        end
    end,
})

SettingsTab:Paragraph({ Title = "Anti Lag", Desc = "Turunkan grafis untuk FPS lebih stabil" })

SettingsTab:Toggle({
    Title    = "Potato Mode",
    Desc     = "Turunkan semua grafis ke minimum — FPS naik, lag berkurang",
    Icon     = "cpu",
    Value    = false,
    Callback = function(Value)
        if Value then
            enablePotatoMode()
        else
            disablePotatoMode()
        end
    end,
})

SettingsTab:Paragraph({ Title = "Server", Desc = "Kelola server game" })

SettingsTab:Button({
    Title    = "Hop Server",
    Desc     = "Pindah ke server lain secara acak",
    Icon     = "shuffle",
    Callback = function()
        log("SETTINGS", "Hop Server ditekan")
        notify("🔀 HOP", "Mencari server lain...", 3)
        task.spawn(function()
            local placeId = game.PlaceId
            local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
            log("SETTINGS", "Fetch server list:", url)
            local ok, servers = pcall(function() return game:HttpGet(url) end)
            if not ok or not servers then
                logerr("SETTINGS", "Gagal ambil server list")
                notify("❌ HOP", "Gagal ambil daftar server", 3)
                return
            end
            log("SETTINGS", "Server list response length:", #servers)
            local ok2, data = pcall(function() return game:GetService("HttpService"):JSONDecode(servers) end)
            if not ok2 or not data or not data.data then
                logerr("SETTINGS", "Gagal parse JSON server list")
                notify("❌ HOP", "Gagal parse data server", 3)
                return
            end
            log("SETTINGS", "Server list count:", #data.data)
            local currentJobId = game.JobId
            local found = nil
            for _, s in ipairs(data.data) do
                if s.id ~= currentJobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                    found = s.id
                    break
                end
            end
            if found then
                log("SETTINGS", "Server ditemukan:", found, "| Teleport...")
                notify("✅ HOP", "Pindah server...", 2)
                task.wait(1)
                TeleportService:TeleportToPlaceInstance(placeId, found, LocalPlayer)
            else
                log("SETTINGS", "Tidak ada server lain tersedia")
                notify("❌ HOP", "Tidak ada server lain tersedia", 3)
            end
        end)
    end,
})

SettingsTab:Button({
    Title    = "Rejoin",
    Desc     = "Masuk ulang ke server yang sama",
    Icon     = "refresh-cw",
    Callback = function()
        log("SETTINGS", "Rejoin ditekan | PlaceId:", game.PlaceId)
        notify("🔄 REJOIN", "Rejoining...", 2)
        task.wait(0.8)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end,
})

SettingsTab:Button({
    Title    = "Copy Job ID",
    Desc     = "Salin Job ID server saat ini ke clipboard",
    Icon     = "copy",
    Callback = function()
        local jobId = tostring(game.JobId)
        log("SETTINGS", "Copy Job ID:", jobId)
        if setclipboard then
            setclipboard(jobId)
            notify("📋 JOB ID", "Job ID disalin: " .. jobId, 4)
        else
            notify("❌ JOB ID", "Executor tidak support clipboard", 3)
        end
    end,
})

SettingsTab:Button({
    Title    = "Paste Job ID & Join",
    Desc     = "Tempel Job ID dari clipboard lalu join server tersebut",
    Icon     = "log-in",
    Callback = function()
        log("SETTINGS", "Paste Job ID ditekan")
        local jobId = ""
        if getclipboard then
            local ok, clip = pcall(getclipboard)
            log("SETTINGS", "getclipboard ok:", ok, "| value:", tostring(clip))
            if ok and type(clip) == "string" then
                jobId = clip:match("^%s*(.-)%s*$")
            end
        else
            log("SETTINGS", "getclipboard tidak tersedia")
        end
        if jobId == "" then
            notify("❌ PASTE JOB ID", "Clipboard kosong atau tidak support", 4)
            return
        end
        local isValid = jobId:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
        if not isValid then
            logerr("SETTINGS", "Format Job ID tidak valid:", jobId)
            notify("❌ PASTE JOB ID", "Format Job ID tidak valid: " .. jobId, 4)
            return
        end
        log("SETTINGS", "Teleport ke Job ID:", jobId)
        notify("🚀 JOIN", "Joining Job ID: " .. jobId, 3)
        task.wait(0.8)
        local ok2, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
        end)
        if not ok2 then
            logerr("SETTINGS", "Teleport gagal:", err)
            notify("❌ JOIN GAGAL", tostring(err), 4)
        end
    end,
})

log("UI", "Tab Settings selesai")

-- setelah settings tab, pasang anti-lag engine
-- =========================
-- ANTI LAG / POTATO MODE
-- Turunin settings grafis Roblox secara legal lewat API resmi
-- =========================
-- =========================================================
-- TAB 4 : LOGS
-- =========================================================
log("UI", "Membuat Tab Logs...")
local LogsTab = Window:Tab({ Title = "Logs", Icon = "terminal" })

LogsTab:Paragraph({
    Title = "Info",
    Desc  = "Log realtime dari semua proses script.\nTampil 20 baris terakhir.",
})

-- ini yang diupdate realtime oleh pushLog()
logParagraph = LogsTab:Paragraph({
    Title = "Output",
    Desc  = "(menunggu log...)",
})

LogsTab:Button({
    Title    = "Clear Logs",
    Desc     = "Hapus semua log yang tampil",
    Icon     = "trash-2",
    Callback = function()
        logBuffer = {}
        pcall(function() logParagraph:SetDesc("(log dibersihkan)") end)
        log("LOGS", "Log dibersihkan oleh user")
    end,
})

LogsTab:Button({
    Title    = "Copy Logs ke Clipboard",
    Desc     = "Salin semua log ke clipboard",
    Icon     = "copy",
    Callback = function()
        if setclipboard then
            setclipboard(table.concat(logBuffer, "\n"))
            notify("📋 LOGS", "Semua log disalin ke clipboard", 3)
        else
            notify("❌ LOGS", "Executor tidak support clipboard", 3)
        end
    end,
})

log("UI", "Tab Logs selesai")

-- auto clear logs tiap 1 detik
task.spawn(function()
    while _G.AutoKataActive do
        task.wait(1)
        logBuffer = {}
        if logParagraph and logParagraph.SetDesc then
            pcall(function() logParagraph:SetDesc("(auto cleared)") end)
        end
    end
end)

-- =========================================================
-- TAB 5 : SCRIPT (ScriptBlox Search)
-- =========================================================
log("UI", "Membuat Tab Script...")
local ScriptTab = Window:Tab({ Title = "Script", Icon = "code" })

-- state search
local scriptResults    = {}   -- list hasil search: {title, game, key, verified, patched, script}
local scriptSelected   = nil  -- index script yang dipilih
local scriptResultDrop = nil
local scriptInfoPara   = nil
local HttpService      = game:GetService("HttpService")

local SCRIPTBLOX_SEARCH = "https://scriptblox.com/api/script/search?q="
local SCRIPTBLOX_FETCH  = "https://scriptblox.com/api/script/fetch?mode=free&max=20"

local function buildResultLabels()
    local labels = {}
    for i, s in ipairs(scriptResults) do
        local tag = ""
        if s.verified then tag = tag .. "✅" end
        if s.key      then tag = tag .. "🔑" end
        if s.patched  then tag = tag .. "❌" end
        local gameName = (s.game and s.game.name) or "Universal"
        labels[i] = i .. ". " .. s.title .. " | " .. gameName .. " " .. tag
    end
    return labels
end

local function updateScriptInfo()
    if not scriptInfoPara or not scriptSelected then return end
    local s = scriptResults[scriptSelected]
    if not s then return end
    local gameName = (s.game and s.game.name) or "Universal"
    local info = "📌 " .. s.title
        .. "\n🎮 Game: " .. gameName
        .. "\n✅ Verified: " .. tostring(s.verified)
        .. "\n🔑 Key: " .. tostring(s.key)
        .. "\n❌ Patched: " .. tostring(s.patched)
    pcall(function() scriptInfoPara:SetDesc(info) end)
end

-- Search Input
ScriptTab:Input({
    Title       = "Cari Script",
    Desc        = "Ketik nama game atau script lalu tekan Enter",
    Icon        = "search",
    Placeholder = "contoh: Blox Fruits, Arsenal, ...",
    Callback    = function(query)
        if not query or query == "" then return end
        log("SCRIPT", "Search:", query)
        notify("🔍 SEARCH", "Mencari: " .. query, 2)
        task.spawn(function()
            local url = SCRIPTBLOX_SEARCH .. HttpService:UrlEncode(query) .. "&max=20&mode=free"
            local ok, raw = pcall(function() return game:HttpGet(url) end)
            if not ok or not raw or raw == "" then
                logerr("SCRIPT", "HttpGet gagal:", tostring(raw))
                notify("❌ SEARCH", "Gagal ambil hasil", 3)
                return
            end
            local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if not ok2 or not data or not data.result then
                logerr("SCRIPT", "JSON decode gagal")
                notify("❌ SEARCH", "Gagal parse hasil", 3)
                return
            end
            scriptResults = data.result.scripts or {}
            log("SCRIPT", "Hasil:", #scriptResults, "script ditemukan")
            if #scriptResults == 0 then
                notify("🔍 SEARCH", "Tidak ada hasil untuk: " .. query, 3)
                if scriptResultDrop then pcall(function() scriptResultDrop:Refresh({}) end) end
                return
            end
            local labels = buildResultLabels()
            if scriptResultDrop then
                pcall(function() scriptResultDrop:Refresh(labels) end)
                pcall(function() scriptResultDrop:Set(labels[1]) end)
            end
            scriptSelected = 1
            updateScriptInfo()
            notify("✅ SEARCH", #scriptResults .. " script ditemukan", 3)
        end)
    end,
})

-- Trending button
ScriptTab:Button({
    Title    = "Lihat Trending",
    Desc     = "Tampilkan script trending dari ScriptBlox",
    Icon     = "trending-up",
    Callback = function()
        log("SCRIPT", "Load trending scripts")
        notify("🔥 TRENDING", "Mengambil trending...", 2)
        task.spawn(function()
            local ok, raw = pcall(function()
                return game:HttpGet("https://scriptblox.com/api/script/trending")
            end)
            if not ok or not raw or raw == "" then
                notify("❌ TRENDING", "Gagal ambil trending", 3) return
            end
            local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if not ok2 or not data or not data.result then
                notify("❌ TRENDING", "Gagal parse JSON", 3) return
            end
            scriptResults = data.result.scripts or {}
            log("SCRIPT", "Trending:", #scriptResults, "script")
            if #scriptResults == 0 then
                notify("🔥 TRENDING", "Tidak ada data trending", 3) return
            end
            local labels = buildResultLabels()
            if scriptResultDrop then
                pcall(function() scriptResultDrop:Refresh(labels) end)
                pcall(function() scriptResultDrop:Set(labels[1]) end)
            end
            scriptSelected = 1
            updateScriptInfo()
            notify("🔥 TRENDING", #scriptResults .. " trending script", 3)
        end)
    end,
})

-- Dropdown hasil
scriptResultDrop = ScriptTab:Dropdown({
    Title    = "Hasil Pencarian",
    Desc     = "Pilih script dari hasil search",
    Icon     = "list",
    Values   = {},
    Value    = nil,
    Multi    = false,
    Callback = function(selected)
        if not selected then return end
        -- parse index dari label "1. Title | Game"
        local idx = tonumber(selected:match("^(%d+)%."))
        if idx and scriptResults[idx] then
            scriptSelected = idx
            updateScriptInfo()
            log("SCRIPT", "Pilih script:", scriptResults[idx].title)
        end
    end,
})

-- Info script
scriptInfoPara = ScriptTab:Paragraph({
    Title = "Info Script",
    Desc  = "(belum ada script dipilih)",
})

-- Execute
ScriptTab:Button({
    Title    = "Execute Script",
    Desc     = "Jalankan script yang dipilih",
    Icon     = "play",
    Callback = function()
        if not scriptSelected or not scriptResults[scriptSelected] then
            notify("❌ EXECUTE", "Pilih script dulu", 3) return
        end
        local s = scriptResults[scriptSelected]
        if s.patched then
            notify("❌ EXECUTE", "Script ini sudah patched!", 3) return
        end
        if s.key then
            notify("⚠️ KEY", "Script ini memerlukan key — copy dulu", 3)
        end
        local code = s.script
        if not code or code == "" then
            notify("❌ EXECUTE", "Script kosong / tidak tersedia", 3) return
        end
        log("SCRIPT", "Execute:", s.title)
        notify("▶️ EXECUTE", "Menjalankan: " .. s.title, 3)
        task.spawn(function()
            local ok, err = pcall(function()
                loadstring(code)()
            end)
            if not ok then
                logerr("SCRIPT", "Execute error:", tostring(err))
                notify("❌ ERROR", tostring(err):sub(1, 60), 5)
            else
                log("SCRIPT", "Execute sukses:", s.title)
                notify("✅ DONE", s.title .. " berhasil dijalankan", 3)
            end
        end)
    end,
})

-- Copy Script
ScriptTab:Button({
    Title    = "Copy Script",
    Desc     = "Salin kode script ke clipboard",
    Icon     = "copy",
    Callback = function()
        if not scriptSelected or not scriptResults[scriptSelected] then
            notify("❌ COPY", "Pilih script dulu", 3) return
        end
        local code = scriptResults[scriptSelected].script
        if not code or code == "" then
            notify("❌ COPY", "Script kosong", 3) return
        end
        if setclipboard then
            setclipboard(code)
            notify("📋 COPY", "Script disalin ke clipboard", 3)
        else
            notify("❌ COPY", "Executor tidak support clipboard", 3)
        end
    end,
})

ScriptTab:Paragraph({
    Title = "Powered by ScriptBlox.com",
    Desc  = "Database script komunitas Roblox terbesar",
})

log("UI", "Tab Script selesai")
log("UI", "Membuat Tab About...")
local AboutTab = Window:Tab({ Title = "About", Icon = "info" })

AboutTab:Paragraph({
    Title = "Informasi Script",
    Desc  = "Auto Kata\nVersi: 5.0 [DEBUG]\nby danz\nFitur: Auto play, 4 kamus kata, settings server\nTiktok Owner: @stevenhellnah",
})

AboutTab:Paragraph({
    Title = "Kamus Tersedia",
    Desc  = "1. Kamus Umum Indonesia (default)\n2. Ganas Gahar - withallcombination\n3. Safety Anti Detek - KBBI Final\n4. Kamus Lengkap - dhann",
})

AboutTab:Paragraph({
    Title = "Informasi Update",
    Desc  = "> 4 opsi kamus kata\n> Detik Mode: custom delay atau preset speed\n> Preset: Slow / Fast / Superfast\n> Full debug log di output console\n> SimpleSpy remote monitor aktif",
})

AboutTab:Paragraph({
    Title = "Cara Penggunaan",
    Desc  = "1. Pilih Opsi Wordlist di tab Main\n2. Aktifkan toggle Auto\n3. Atur delay dan agresivitas\n4. Mulai permainan\n5. Script akan otomatis menjawab",
})

AboutTab:Paragraph({
    Title = "Catatan",
    Desc  = "Buka Developer Console (F9) untuk lihat log\nSimpleSpy memantau semua remote otomatis\nPaste Job ID butuh executor support getclipboard",
})

local discordLink = "https://discord.gg/bT4GmSFFWt"
local waLink      = "https://www.whatsapp.com/channel/0029VbCBSBOCRs1pRNYpPN0r"

AboutTab:Button({
    Title    = "Copy Discord Invite",
    Desc     = "Salin link Discord ke clipboard",
    Icon     = "link",
    Callback = function()
        if setclipboard then
            setclipboard(discordLink)
            notify("🟢 DISCORD", "Link Discord berhasil disalin!", 3)
        else
            notify("🔴 DISCORD", "Executor tidak support clipboard", 3)
        end
    end,
})

AboutTab:Button({
    Title    = "Copy WhatsApp Channel",
    Desc     = "Salin link WhatsApp Channel ke clipboard",
    Icon     = "link",
    Callback = function()
        if setclipboard then
            setclipboard(waLink)
            notify("🟢 WHATSAPP", "Link WhatsApp berhasil disalin!", 3)
        else
            notify("🔴 WHATSAPP", "Executor tidak support clipboard", 3)
        end
    end,
})

log("UI", "Tab About selesai")
log("UI", "Semua tab dibuat ✅")

-- =========================
-- REMOTE EVENTS
-- =========================
log("REMOTE", "Memasang handler remote events...")

local function onMatchUI(cmd, value)
    log("REMOTE", "MatchUI event | cmd:", tostring(cmd), "| value:", tostring(value))
    if cmd == "ShowMatchUI" then
        matchActive = true
        isMyTurn    = false
        log("MATCH", "Match dimulai")
        resetUsedWords()
        setupSeatMonitoring()
        updateMainStatus()
        updateWordButtons()
    elseif cmd == "HideMatchUI" then
        matchActive  = false
        isMyTurn     = false
        serverLetter = ""
        log("MATCH", "Match berakhir/disembunyikan")
        resetUsedWords()
        seatStates   = {}
        updateMainStatus()
        updateWordButtons()
    elseif cmd == "StartTurn" then
        isMyTurn = true
        log("MATCH", "Giliran SAYA dimulai | serverLetter:", serverLetter, "| auto:", tostring(autoEnabled))
        if autoEnabled then
            task.spawn(function()
                local delay = math.random(300, 500) / 1000
                log("AI", "Spawn AI dengan delay:", delay, "s")
                task.wait(delay)
                if matchActive and isMyTurn and autoEnabled then
                    startUltraAI()
                else
                    log("AI", "Kondisi tidak valid setelah delay, skip AI")
                end
            end)
        end
        updateMainStatus()
        updateWordButtons()
    elseif cmd == "EndTurn" then
        isMyTurn = false
        log("MATCH", "Giliran berakhir")
        updateMainStatus()
        updateWordButtons()
    elseif cmd == "UpdateServerLetter" then
        serverLetter = value or ""
        log("MATCH", "ServerLetter update →", serverLetter)
        updateMainStatus()
        updateWordButtons()
    end
end

local function onBillboard(word)
    log("BILLBOARD", "BillboardUpdate | word:", tostring(word), "| isMyTurn:", tostring(isMyTurn))
    if matchActive and not isMyTurn then
        opponentStreamWord = word or ""
    end
end

local function onUsedWarn(word)
    log("USEDWARN", "UsedWordWarn | word:", tostring(word))
    if word then
        addUsedWord(word)
        if autoEnabled and matchActive and isMyTurn then
            log("USEDWARN", "Kata sudah dipakai, retry AI...")
            humanDelay()
            startUltraAI()
        end
    end
end

JoinTable.OnClientEvent:Connect(function(tableName)
    log("TABLE", "JoinTable | tableName:", tostring(tableName))
    currentTableName = tableName
    setupSeatMonitoring()
    updateMainStatus()
end)

LeaveTable.OnClientEvent:Connect(function()
    log("TABLE", "LeaveTable")
    currentTableName = nil
    matchActive      = false
    isMyTurn         = false
    serverLetter     = ""
    resetUsedWords()
    seatStates       = {}
    updateMainStatus()
end)

MatchUI.OnClientEvent:Connect(onMatchUI)
BillboardUpdate.OnClientEvent:Connect(onBillboard)
UsedWordWarn.OnClientEvent:Connect(onUsedWarn)

log("REMOTE", "Semua remote handler terpasang ✅")

task.spawn(function()
    while true do
        if matchActive then updateMainStatus() end
        task.wait(0.3)
    end
end)

log("BOOT", "====================================================")
log("BOOT", "✅ WINDUI BUILD v5 [DEBUG] LOADED SUCCESSFULLY")
log("BOOT", "Wordlist:", activeWordlistName, "| Kata:", #kataModule)
log("BOOT", "Input method: VIM=" .. tostring(VIM ~= nil)
    .. " | keypress=" .. tostring(keypress ~= nil))
log("BOOT", "====================================================")
