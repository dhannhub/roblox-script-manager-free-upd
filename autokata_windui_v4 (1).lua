-- =========================================================
-- ULTRA SMART AUTO KATA - WindUI Build v4
-- by danz
-- =========================================================

if game:IsLoaded() == false then
    game.Loaded:Wait()
end

if _G.DestroyDanzRunner then
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

task.wait(3)

-- =========================
-- LOAD WINDUI
-- =========================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then warn("Gagal load WindUI") return end

-- =========================
-- SERVICES
-- =========================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

-- =========================
-- WORDLIST URLS
-- =========================
local WORDLIST_URLS = {
    ["Ganas Gahar (withallcombination)"] = "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/withallcombination2.lua",
    ["Safety Anti Detek (KBBI)"]         = "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/KBBI_Final_Working.lua",
}
local activeWordlistName = "Ganas Gahar (withallcombination)"

-- =========================
-- LOAD WORDLIST
-- =========================
local kataModule = {}

local function loadWordlistFromURL(url)
    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok or not response or response == "" then
        warn("Gagal HttpGet wordlist dari: " .. url)
        return false
    end

    -- coba langsung loadstring dulu (format return {...})
    local loadFunc, err = loadstring(response)
    if loadFunc then
        local ok2, result = pcall(loadFunc)
        if ok2 and type(result) == "table" and #result > 0 then
            local seen, uniqueWords = {}, {}
            for _, word in ipairs(result) do
                local w = string.lower(tostring(word))
                if not seen[w] and #w > 1 then
                    seen[w] = true
                    table.insert(uniqueWords, w)
                end
            end
            if #uniqueWords > 0 then
                kataModule = uniqueWords
                print("Wordlist loaded (direct):", #kataModule, "kata")
                return true
            end
        end
    end

    -- fallback: ganti [] -> {} lalu loadstring
    local fixed = response:gsub("%[", "{"):gsub("%]", "}")
    local loadFunc2, err2 = loadstring(fixed)
    if not loadFunc2 then
        warn("Gagal parse wordlist: " .. tostring(err2))
        return false
    end
    local ok3, result2 = pcall(loadFunc2)
    if not ok3 or type(result2) ~= "table" or #result2 == 0 then
        warn("Wordlist bukan tabel atau kosong")
        return false
    end

    local seen, uniqueWords = {}, {}
    for _, word in ipairs(result2) do
        local w = string.lower(tostring(word))
        if not seen[w] and #w > 1 then
            seen[w] = true
            table.insert(uniqueWords, w)
        end
    end
    if #uniqueWords == 0 then
        warn("Wordlist kosong setelah filter")
        return false
    end

    kataModule = uniqueWords
    print("Wordlist loaded (fallback):", #kataModule, "kata")
    return true
end

-- load default wordlist saat startup
local wordOk = loadWordlistFromURL(WORDLIST_URLS[activeWordlistName])
if not wordOk or #kataModule == 0 then
    warn("Wordlist gagal dimuat!")
    return
end

-- =========================
-- REMOTES
-- =========================
local remotes         = ReplicatedStorage:WaitForChild("Remotes")
local MatchUI         = remotes:WaitForChild("MatchUI")
local SubmitWord      = remotes:WaitForChild("SubmitWord")
local BillboardUpdate = remotes:WaitForChild("BillboardUpdate")
local BillboardEnd    = remotes:WaitForChild("BillboardEnd")
local TypeSound       = remotes:WaitForChild("TypeSound")
local UsedWordWarn    = remotes:WaitForChild("UsedWordWarn")
local JoinTable       = remotes:WaitForChild("JoinTable")
local LeaveTable      = remotes:WaitForChild("LeaveTable")

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
    minDelay   = 350,
    maxDelay   = 650,
    aggression = 20,
    minLength  = 2,
    maxLength  = 12,
}

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
        if usedWordsDropdown and usedWordsDropdown.Refresh then
            pcall(function() usedWordsDropdown:Refresh(usedWordsList) end)
        end
    end
end

local function resetUsedWords()
    usedWords, usedWordsList = {}, {}
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
    return results
end

local function humanDelay()
    local mn, mx = config.minDelay, config.maxDelay
    if mn > mx then mn = mx end
    task.wait(math.random(mn, mx) / 1000)
end

-- =========================
-- AUTO ENGINE
-- =========================
local function startUltraAI()
    if autoRunning or not autoEnabled or not matchActive or not isMyTurn or serverLetter == "" then return end
    autoRunning = true
    humanDelay()
    local words = getSmartWords(serverLetter)
    if #words == 0 then autoRunning = false return end
    local sel = words[1]
    if config.aggression < 100 then
        local topN = math.max(1, math.floor(#words * (1 - config.aggression / 100)))
        sel = words[math.random(1, topN)]
    end
    local cur    = serverLetter
    local remain = string.sub(sel, #serverLetter + 1)
    for i = 1, #remain do
        if not matchActive or not isMyTurn then autoRunning = false return end
        cur = cur .. string.sub(remain, i, i)
        TypeSound:FireServer()
        BillboardUpdate:FireServer(cur)
        humanDelay()
    end
    humanDelay()
    SubmitWord:FireServer(sel)
    addUsedWord(sel)
    humanDelay()
    BillboardEnd:FireServer()
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
    local head      = player.Character:FindFirstChild("Head")
    if not head then return nil end
    local billboard = head:FindFirstChild("TurnBillboard")
    if not billboard then return nil end
    local textLabel = billboard:FindFirstChildOfClass("TextLabel")
    if not textLabel then return nil end
    return { Billboard = billboard, TextLabel = textLabel, LastText = "", Player = player }
end

local function setupSeatMonitoring()
    if not currentTableName then seatStates = {} tableTarget = nil return end
    local tablesFolder = Workspace:FindFirstChild("Tables")
    if not tablesFolder then warn("Folder Tables tidak ditemukan") return end
    tableTarget = tablesFolder:FindFirstChild(currentTableName)
    if not tableTarget then warn("Meja " .. currentTableName .. " tidak ditemukan") return end
    local seatsContainer = tableTarget:FindFirstChild("Seats")
    if not seatsContainer then warn("Tidak ada Seats di meja " .. currentTableName) return end
    seatStates = {}
    for _, seat in ipairs(seatsContainer:GetChildren()) do
        if seat:IsA("Seat") then
            seatStates[seat] = { Current = nil }
        end
    end
end

RunService.Heartbeat:Connect(function()
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
                    if state.Current.LastText ~= "" then addUsedWord(state.Current.LastText) end
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
    if _G.DestroyDanzRunner then
        pcall(function() _G.DestroyDanzRunner() end)
    end
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if gui then
        local o1 = gui:FindFirstChild("DanzUltra")
        if o1 then o1:Destroy() end
        local o2 = gui:FindFirstChild("DanzClean")
        if o2 then o2:Destroy() end
    end
end)

-- =========================
-- WINDOW
-- =========================
local Window = WindUI:CreateWindow({
    Title         = "Sambung-kata",
    Icon          = "zap",
    Author        = "by danz",
    Folder        = "SambungKata",
    Size          = UDim2.fromOffset(580, 490),
    Theme         = "Dark",
    Resizable     = false,
    HideSearchBar = true,
})

-- =========================
-- NOTIFY
-- =========================
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
local MainTab = Window:Tab({ Title = "Main", Icon = "home" })

-- forward declare getWordsToggle supaya bisa diakses di autoToggle callback
local getWordsToggle

-- Auto Toggle
local autoToggle
autoToggle = MainTab:Toggle({
    Title    = "Aktifkan Auto",
    Desc     = "Aktifkan mode auto play",
    Icon     = "zap",
    Value    = false,
    Callback = function(Value)
        autoEnabled = Value
        if Value then
            if getWordsToggle then getWordsToggle:Set(false) end
            notify("⚡ AUTO MODE", "Auto Dinyalakan", 3)
            startUltraAI()
        else
            notify("⚡ AUTO MODE", "Auto Dimatikan", 3)
        end
    end,
})

-- Opsi Wordlist (muncul di bawah auto toggle)
MainTab:Dropdown({
    Title    = "Opsi Wordlist",
    Desc     = "Pilih mode wordlist saat Auto aktif",
    Icon     = "database",
    Values   = {
        "Ganas Gahar (withallcombination)",
        "Safety Anti Detek (KBBI)",
    },
    Value    = activeWordlistName,
    Multi    = false,
    Callback = function(selected)
        if not selected then return end
        if selected == activeWordlistName then return end
        activeWordlistName = selected
        local url = WORDLIST_URLS[selected]
        if not url then return end

        notify("📦 WORDLIST", "Loading " .. selected .. "...", 3)

        -- load di background biar ga freeze
        task.spawn(function()
            local success = loadWordlistFromURL(url)
            if success then
                resetUsedWords()
                notify("✅ WORDLIST", "Berhasil load: " .. #kataModule .. " kata", 3)
            else
                notify("❌ WORDLIST", "Gagal load wordlist, coba lagi", 4)
            end
        end)
    end,
})

-- Aggression
MainTab:Slider({
    Title    = "Aggression",
    Desc     = "Tingkat agresivitas pemilihan kata",
    Icon     = "trending-up",
    Value    = { Min = 0, Max = 100, Default = config.aggression, Decimals = 0, Suffix = "%" },
    Callback = function(v) config.aggression = v end,
})

-- Min Delay
MainTab:Slider({
    Title    = "Min Delay (ms)",
    Desc     = "Delay minimum sebelum mengetik",
    Icon     = "timer",
    Value    = { Min = 10, Max = 500, Default = config.minDelay, Decimals = 0, Suffix = "ms" },
    Callback = function(v) config.minDelay = v end,
})

-- Max Delay
MainTab:Slider({
    Title    = "Max Delay (ms)",
    Desc     = "Delay maksimum sebelum mengetik",
    Icon     = "timer",
    Value    = { Min = 100, Max = 1000, Default = config.maxDelay, Decimals = 0, Suffix = "ms" },
    Callback = function(v) config.maxDelay = v end,
})

-- Min Word Length
MainTab:Slider({
    Title    = "Min Word Length",
    Desc     = "Panjang kata minimum",
    Icon     = "type",
    Value    = { Min = 1, Max = 2, Default = config.minLength, Decimals = 0 },
    Callback = function(v) config.minLength = v end,
})

-- Max Word Length
MainTab:Slider({
    Title    = "Max Word Length",
    Desc     = "Panjang kata maksimum",
    Icon     = "type",
    Value    = { Min = 5, Max = 20, Default = config.maxLength, Decimals = 0 },
    Callback = function(v) config.maxLength = v end,
})

-- Used Words Dropdown
usedWordsDropdown = MainTab:Dropdown({
    Title    = "Used Words",
    Desc     = "Kata-kata yang sudah dipakai",
    Icon     = "list",
    Values   = {},
    Value    = nil,
    Multi    = false,
    Callback = function() end,
})

-- Status Paragraph
local statusParagraph = MainTab:Paragraph({
    Title = "Status",
    Desc  = "Menunggu...",
})

-- Update Status
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

-- =========================================================
-- TAB 2 : SELECT WORD
-- =========================================================
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

-- Get Words Toggle
getWordsToggle = SelectTab:Toggle({
    Title    = "Get Words",
    Desc     = "Tampilkan daftar kata yang tersedia",
    Icon     = "book-open",
    Value    = false,
    Callback = function(Value)
        getWordsEnabled = Value
        if Value then
            if autoToggle then autoToggle:Set(false) end
            notify("🟢 SELECT MODE", "Get Words Dinyalakan", 3)
        else
            notify("🔴 SELECT MODE", "Get Words Dimatikan", 3)
        end
        updateWordButtons()
    end,
})

-- Max Words to Show
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

-- Word Selector Dropdown
wordDropdown = SelectTab:Dropdown({
    Title    = "Pilih Kata",
    Desc     = "Pilih kata untuk diketik",
    Icon     = "chevrons-up-down",
    Values   = {},
    Value    = nil,
    Multi    = false,
    Callback = function(option)
        selectedWord = option or nil
    end,
})

-- Submit Button
SelectTab:Button({
    Title    = "Ketik Kata Terpilih",
    Desc     = "Ketik kata yang sudah dipilih ke game",
    Icon     = "send",
    Callback = function()
        if not getWordsEnabled or not isMyTurn or not selectedWord or serverLetter == "" then return end
        local word        = selectedWord
        local currentWord = serverLetter
        local remain      = string.sub(word, #serverLetter + 1)
        for i = 1, #remain do
            if not matchActive or not isMyTurn then return end
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
    end,
})

-- =========================================================
-- TAB 3 : ABOUT
-- =========================================================
local AboutTab = Window:Tab({ Title = "About", Icon = "info" })

AboutTab:Paragraph({
    Title = "Informasi Script",
    Desc  = "Auto Kata\nVersi: 4.0\nby danz\nFitur: Auto play dengan wordlist Indonesia\n\nthanks to sazaraaax for the function dictionary",
})

AboutTab:Paragraph({
    Title = "Informasi Update",
    Desc  = "> stable on all device pc or android\n> Dual wordlist: Ganas Gahar & Safety KBBI\n> Monitoring lawan & status realtime\n> Select Word tab untuk pilih kata manual",
})

AboutTab:Paragraph({
    Title = "Cara Penggunaan",
    Desc  = "1. Pilih Opsi Wordlist di tab Main\n2. Aktifkan toggle Auto\n3. Atur delay dan agresivitas\n4. Mulai permainan\n5. Script akan otomatis menjawab",
})

AboutTab:Paragraph({
    Title = "Catatan",
    Desc  = "Pastikan koneksi stabil\nJika ada error, coba reload\nGanas Gahar = lebih banyak kata kombinasi\nSafety KBBI = kata baku, lebih susah detek",
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
            notify("🟢 WHATSAPP", "Link WhatsApp Channel berhasil disalin!", 3)
        else
            notify("🔴 WHATSAPP", "Executor tidak support clipboard", 3)
        end
    end,
})

-- =========================
-- REMOTE EVENTS
-- =========================
local function onMatchUI(cmd, value)
    if cmd == "ShowMatchUI" then
        matchActive = true
        isMyTurn    = false
        resetUsedWords()
        setupSeatMonitoring()
        updateMainStatus()
        updateWordButtons()
    elseif cmd == "HideMatchUI" then
        matchActive  = false
        isMyTurn     = false
        serverLetter = ""
        resetUsedWords()
        seatStates   = {}
        updateMainStatus()
        updateWordButtons()
    elseif cmd == "StartTurn" then
        isMyTurn = true
        if autoEnabled then
            task.spawn(function()
                task.wait(math.random(300, 500) / 1000)
                if matchActive and isMyTurn and autoEnabled then startUltraAI() end
            end)
        end
        updateMainStatus()
        updateWordButtons()
    elseif cmd == "EndTurn" then
        isMyTurn = false
        updateMainStatus()
        updateWordButtons()
    elseif cmd == "UpdateServerLetter" then
        serverLetter = value or ""
        updateMainStatus()
        updateWordButtons()
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = word or ""
    end
end

local function onUsedWarn(word)
    if word then
        addUsedWord(word)
        if autoEnabled and matchActive and isMyTurn then
            humanDelay()
            startUltraAI()
        end
    end
end

JoinTable.OnClientEvent:Connect(function(tableName)
    currentTableName = tableName
    setupSeatMonitoring()
    updateMainStatus()
end)

LeaveTable.OnClientEvent:Connect(function()
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

task.spawn(function()
    while true do
        if matchActive then updateMainStatus() end
        task.wait(0.3)
    end
end)

print("WINDUI BUILD v4 LOADED | Wordlist:", activeWordlistName, "| Total kata:", #kataModule)