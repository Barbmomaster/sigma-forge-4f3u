--[[
    ============================================================================
    KvaplScript v6.3 - Cameraman Tower Defense Ultimate Suite (PC & Mobile)
    Discord:  https://discord.gg/ehm5KCjR6
    Telegram: https://t.me/TTKvapl
    Data Sources (Updated Nov 19, 2026):
      - Vaulted Values X / Cameraman TD (https://cameramantowerdefense.com/values)
      - Game.Guide CTD Value List (https://www.game.guide/cameraman-tower-defense-value-list)
    ============================================================================
    What is new in v6.2:
    1. Device selection after the loading screen: 2 buttons "Phone" and "PC".
       - PC: classic full-size interface (760x500) + top HUD.
       - Phone: compact adaptive Mobile UI (auto-scale to the phone screen,
         convenient draggable "Kvapl" button to open/close without a keyboard
         and a compact top HUD).
    2. FULLY Reworked Auto-accept of incoming trade requests (AutoAcceptRequest):
       - Finds trade pop-up notifications even if the text says "wants to trade" /
         "invited you" / localized variants;
       - Searches for Accept / Decline buttons by text, icon and attributes;
       - Triple universal clicker (firesignal + getconnections + VirtualInputManager)
         - works even on mobile executors.
    3. AUTO-ANALYZER of trade slots, tooltips and reliable request auto-accept.
    Launch flow: 1) Loading screen (7 sec) -> 2) Device choice (Phone / PC) -> 3) Main loop.
    ============================================================================
]]


local S = {
    Players          = game:GetService("Players"),
    TweenService     = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    RunService       = game:GetService("RunService"),
    Workspace        = game:GetService("Workspace"),
    Lighting         = game:GetService("Lighting"),
    HttpService      = game:GetService("HttpService"),
    GuiService       = game:GetService("GuiService"),
}

local LocalPlayer = S.Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local DISCORD_LINK  = "https://discord.gg/ehm5KCjR6"
local TELEGRAM_LINK = "https://t.me/TTKvapl"
local UI_NAME       = "KvaplScriptUI_v6_3"

local UI    = {}
local State = {
    IsRunning          = true,
    IsMobileMode       = false,
    IsProfileConnected = false,
    MyOffer            = {},
    PartnerOffer       = {},
    MyExtraGems        = 0,
    PartnerExtraGems   = 0,
    LastTradeDiff      = 0,
    ActiveConnections  = {},
    PriceBadgeCache    = {},
    HookedTooltips     = {},
    HoverSlotMap       = {},
    HoverSignMap       = {},
    SavedMaterials     = {},
    SavedAtmospheres   = {},
    OriginalSkybox     = nil,
    SkyboxDomeModel    = nil,
    SkyboxRenderConn   = nil,
    DescendantConn     = nil,
    TeleportHooked     = false,
    SettingToggles     = {},
    PresetSkyIdx       = 1,
    PickerSignedMode   = false,
    PickerSignerName   = "KAPTOXA274",
    LastClickTimes     = {},
}
local Fn = {}

local function getTopGuiParent()
    if typeof(gethui) == "function" then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and coreGui then
        local testOk = pcall(function() local _ = coreGui.Name end)
        if testOk then return coreGui end
    end
    return PlayerGui
end

local GuiParent = getTopGuiParent()

do
    local oldNames = {
        "KvaplScriptUI", "KvaplScriptUI_v2", "KvaplScriptUI_v3",
        "KvaplScriptUI_v4", "KvaplScriptUI_v5", "KvaplScriptUI_v6",
        "KvaplScriptUI_v6_1", UI_NAME
    }
    for _, parentCandidate in ipairs({ GuiParent, PlayerGui }) do
        pcall(function()
            for _, oldName in ipairs(oldNames) do
                if parentCandidate:FindFirstChild(oldName) then
                    parentCandidate[oldName]:Destroy()
                end
            end
        end)
    end
    pcall(function()
        if S.Workspace:FindFirstChild("KvaplCameraSkybox") then
            S.Workspace.KvaplCameraSkybox:Destroy()
        end
    end)
end

-- ============================================================================
-- LANGUAGE PACKS (Ru / Ukraine / English)
-- ============================================================================
local Translations = {
    Ru = {
        tabHome       = "🏠 Home",
        tabTrade      = "⚖️ \u{0422}\u{0440}\u{0435}\u{0439}\u{0434}",
        tabValues     = "💎 \u{041F}\u{0440}\u{0430}\u{0439}\u{0441}-\u{043B}\u{0438}\u{0441}\u{0442}",
        tabSettings   = "⚙️ \u{041D}\u{0430}\u{0441}\u{0442}\u{0440}\u{043E}\u{0439}\u{043A}\u{0438}",
        connectBtn    = "🔌 Connect (\u{041F}\u{043E}\u{0434}\u{043A}\u{043B}\u{044E}\u{0447}\u{0438}\u{0442}\u{044C} \u{043F}\u{0440}\u{043E}\u{0444}\u{0438}\u{043B}\u{044C})",
        connectedBtn  = "✅ \u{041F}\u{0440}\u{043E}\u{0444}\u{0438}\u{043B}\u{044C} \u{043F}\u{043E}\u{0434}\u{043A}\u{043B}\u{044E}\u{0447}\u{0451}\u{043D} (\u{041E}\u{0431}\u{043D}\u{043E}\u{0432}\u{0438}\u{0442}\u{044C} \u{0434}\u{0430}\u{043D}\u{043D}\u{044B}\u{0435})",
        displayName   = "\u{041D}\u{0438}\u{043A}\u{043D}\u{0435}\u{0439}\u{043C}",
        userName      = "\u{042E}\u{0437}\u{0435}\u{0440}\u{043D}\u{0435}\u{0439}\u{043C}",
        gemsCount     = "💎 \u{0413}\u{0435}\u{043C}\u{044B} (Gems)",
        coinsCount    = "🪙 \u{041C}\u{043E}\u{043D}\u{0435}\u{0442}\u{044B} (Coins)",
        winsCount     = "🏆 \u{041F}\u{043E}\u{0431}\u{0435}\u{0434}\u{044B} (Wins)",
        legCount      = "⭐ Legendary (\u{041B}\u{0435}\u{0433}\u{0435}\u{043D}\u{0434}\u{0430}\u{0440}\u{043D}\u{044B}\u{0435})",
        mythCount     = "🔥 Mythic (\u{041C}\u{0438}\u{0444}\u{0438}\u{0447}\u{0435}\u{0441}\u{043A}\u{0438}\u{0435})",
        godlyCount    = "⚡ Godly (\u{0413}\u{043E}\u{0434}\u{043B}\u{0438})",
        exclCount     = "👑 Exclusive (\u{042D}\u{043A}\u{0441}\u{043A}\u{043B}\u{044E}\u{0437}\u{0438}\u{0432}\u{043D}\u{044B}\u{0435})",
        notConnected  = "\u{041D}\u{0430}\u{0436}\u{043C}\u{0438}\u{0442}\u{0435} \u{043A}\u{043D}\u{043E}\u{043F}\u{043A}\u{0443} «Connect», \u{0447}\u{0442}\u{043E}\u{0431}\u{044B} \u{0437}\u{0430}\u{0433}\u{0440}\u{0443}\u{0437}\u{0438}\u{0442}\u{044C} \u{0430}\u{0432}\u{0430}\u{0442}\u{0430}\u{0440}\u{043A}\u{0443}, \u{0433}\u{0435}\u{043C}\u{044B}, \u{043C}\u{043E}\u{043D}\u{0435}\u{0442}\u{044B}, \u{043F}\u{043E}\u{0431}\u{0435}\u{0434}\u{044B} \u{0438} \u{044E}\u{043D}\u{0438}\u{0442}\u{043E}\u{0432}.",
        myOffer       = "📤 \u{041C}\u{043E}\u{0451} \u{043F}\u{0440}\u{0435}\u{0434}\u{043B}\u{043E}\u{0436}\u{0435}\u{043D}\u{0438}\u{0435} (\u{042F} \u{0434}\u{0430}\u{044E})",
        partnerOffer  = "📥 \u{041F}\u{0440}\u{0435}\u{0434}\u{043B}\u{043E}\u{0436}\u{0435}\u{043D}\u{0438}\u{0435} \u{0438}\u{0433}\u{0440}\u{043E}\u{043A}\u{0430} (\u{041C}\u{043D}\u{0435} \u{0434}\u{0430}\u{044E}\u{0442})",
        addManual     = "➕ \u{0414}\u{043E}\u{0431}\u{0430}\u{0432}\u{0438}\u{0442}\u{044C} \u{0432}\u{0440}\u{0443}\u{0447}\u{043D}\u{0443}\u{044E}",
        sumLabel      = "\u{0421}\u{0443}\u{043C}\u{043C}\u{0430}: ",
        clearBtn      = "\u{0421}\u{0431}\u{0440}\u{043E}\u{0441}",
        waitTrade     = "⚖️ \u{041E}\u{0416}\u{0418}\u{0414}\u{0410}\u{041D}\u{0418}\u{0415} \u{0422}\u{0420}\u{0415}\u{0419}\u{0414}\u{0410} — \u{041E}\u{0442}\u{043A}\u{0440}\u{043E}\u{0439}\u{0442}\u{0435} \u{043E}\u{0431}\u{043C}\u{0435}\u{043D} \u{0438}\u{043B}\u{0438} \u{0434}\u{043E}\u{0431}\u{0430}\u{0432}\u{044C}\u{0442}\u{0435} \u{044E}\u{043D}\u{0438}\u{0442}\u{043E}\u{0432}",
        winTrade      = "✅ WIN (\u{0412}\u{042B}\u{0418}\u{0413}\u{0420}\u{042B}\u{0428}): +%s \u{0432} \u{0432}\u{0430}\u{0448}\u{0443} \u{043F}\u{043E}\u{043B}\u{044C}\u{0437}\u{0443}!",
        loseTrade     = "❌ LOSE (\u{041F}\u{0420}\u{041E}\u{0418}\u{0413}\u{0420}\u{042B}\u{0428}): %s (\u{0432}\u{044B} \u{0432} \u{043C}\u{0438}\u{043D}\u{0443}\u{0441}\u{0435})",
        fairTrade     = "⚖️ FAIR (\u{0420}\u{0410}\u{0412}\u{041D}\u{042B}\u{0419} \u{0422}\u{0420}\u{0415}\u{0419}\u{0414}) — \u{0420}\u{0430}\u{0437}\u{043D}\u{0438}\u{0446}\u{0430}: 0 💎",
        youGive       = "\u{0412}\u{044B} \u{0434}\u{0430}\u{0451}\u{0442}\u{0435}: %s   |   \u{0412}\u{0430}\u{043C} \u{0434}\u{0430}\u{044E}\u{0442}: %s",
        langTitle     = "🌐 1. \u{0421}\u{043C}\u{0435}\u{043D}\u{0430} \u{044F}\u{0437}\u{044B}\u{043A}\u{0430} (Language)",
        langDesc      = "\u{0412}\u{044B}\u{0431}\u{0435}\u{0440}\u{0438}\u{0442}\u{0435} \u{044F}\u{0437}\u{044B}\u{043A} \u{0438}\u{043D}\u{0442}\u{0435}\u{0440}\u{0444}\u{0435}\u{0439}\u{0441}\u{0430}: English, Ukraine (\u{0423}\u{043A}\u{0440}\u{0430}\u{0457}\u{043D}\u{0441}\u{044C}\u{043A}\u{0430}) \u{0438}\u{043B}\u{0438} Ru (\u{0420}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}\u{0439})",
        autoReqTitle  = "📨 \u{0410}\u{0432}\u{0442}\u{043E}-\u{043F}\u{0440}\u{0438}\u{043D}\u{044F}\u{0442}\u{0438}\u{0435} \u{0437}\u{0430}\u{043F}\u{0440}\u{043E}\u{0441}\u{0430} \u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}",
        autoReqDesc   = "\u{041C}\u{043E}\u{043C}\u{0435}\u{043D}\u{0442}\u{0430}\u{043B}\u{044C}\u{043D}\u{043E} \u{043F}\u{0440}\u{0438}\u{043D}\u{0438}\u{043C}\u{0430}\u{0435}\u{0442} \u{0432}\u{0445}\u{043E}\u{0434}\u{044F}\u{0449}\u{0438}\u{0435} \u{0437}\u{0430}\u{043F}\u{0440}\u{043E}\u{0441}\u{044B} \u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434} (Popup / Notification / ✓)",
        autoAccTitle  = "🤝 \u{0410}\u{0432}\u{0442}\u{043E}-\u{043F}\u{0440}\u{0438}\u{043D}\u{044F}\u{0442}\u{0438}\u{0435} \u{0432}\u{043D}\u{0443}\u{0442}\u{0440}\u{0438} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}\u{0430} (Accept / Ready)",
        autoAccDesc   = "\u{041C}\u{043E}\u{043C}\u{0435}\u{043D}\u{0442}\u{0430}\u{043B}\u{044C}\u{043D}\u{043E} \u{043D}\u{0430}\u{0436}\u{0438}\u{043C}\u{0430}\u{0435}\u{0442} \u{043A}\u{043D}\u{043E}\u{043F}\u{043A}\u{0443} \u{043F}\u{043E}\u{0434}\u{0442}\u{0432}\u{0435}\u{0440}\u{0436}\u{0434}\u{0435}\u{043D}\u{0438}\u{044F} \u{0432} \u{043E}\u{0442}\u{043A}\u{0440}\u{044B}\u{0442}\u{043E}\u{043C} \u{043E}\u{043A}\u{043D}\u{0435} \u{043E}\u{0431}\u{043C}\u{0435}\u{043D}\u{0430}",
        safeAccTitle  = "🛡️ \u{0417}\u{0430}\u{0449}\u{0438}\u{0442}\u{0430} \u{0410}\u{0432}\u{0442}\u{043E}-\u{043F}\u{0440}\u{0438}\u{043D}\u{044F}\u{0442}\u{0438}\u{044F} (\u{041D}\u{0435} \u{043F}\u{0440}\u{0438}\u{043D}\u{0438}\u{043C}\u{0430}\u{0442}\u{044C} LOSE)",
        safeAccDesc   = "\u{0411}\u{043B}\u{043E}\u{043A}\u{0438}\u{0440}\u{0443}\u{0435}\u{0442} \u{0430}\u{0432}\u{0442}\u{043E}-\u{043F}\u{043E}\u{0434}\u{0442}\u{0432}\u{0435}\u{0440}\u{0436}\u{0434}\u{0435}\u{043D}\u{0438}\u{0435}, \u{0435}\u{0441}\u{043B}\u{0438} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434} \u{0443}\u{0445}\u{043E}\u{0434}\u{0438}\u{0442} \u{0432} \u{043C}\u{0438}\u{043D}\u{0443}\u{0441} \u{0434}\u{043B}\u{044F} \u{0432}\u{0430}\u{0441}",
        autoScanTitle = "🤖 \u{0410}\u{0432}\u{0442}\u{043E}-\u{0430}\u{043D}\u{0430}\u{043B}\u{0438}\u{0437} \u{043E}\u{043A}\u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}\u{0430}",
        autoScanDesc  = "\u{0410}\u{0432}\u{0442}\u{043E}\u{043C}\u{0430}\u{0442}\u{0438}\u{0447}\u{0435}\u{0441}\u{043A}\u{0438} \u{0441}\u{0447}\u{0438}\u{0442}\u{044B}\u{0432}\u{0430}\u{0435}\u{0442} \u{044E}\u{043D}\u{0438}\u{0442}\u{043E}\u{0432} (\u{0432}\u{043A}\u{043B}\u{044E}\u{0447}\u{0430}\u{044F} Signed \u{0438} \u{043D}\u{0438}\u{043A} \u{043F}\u{043E}\u{0434}\u{043F}\u{0438}\u{0441}\u{0430}\u{043D}\u{0442}\u{0430}) \u{0438} \u{0433}\u{0435}\u{043C}\u{044B}",
        gameOptTitle  = "🚀 \u{041E}\u{043F}\u{0442}\u{0438}\u{043C}\u{0438}\u{0437}\u{0430}\u{0446}\u{0438}\u{044F} \u{0438}\u{0433}\u{0440}\u{044B} (FPS Boost — \u{0443}\u{0431}\u{0440}\u{0430}\u{0442}\u{044C} \u{043C}\u{0430}\u{0442}\u{0435}\u{0440}\u{0438}\u{0430}\u{043B}\u{044B})",
        gameOptDesc   = "\u{0423}\u{0431}\u{0438}\u{0440}\u{0430}\u{0435}\u{0442} \u{043C}\u{0430}\u{0442}\u{0435}\u{0440}\u{0438}\u{0430}\u{043B}\u{044B} \u{043A}\u{0430}\u{0440}\u{0442}\u{044B} (SmoothPlastic), \u{0442}\u{0435}\u{043D}\u{0438}, \u{0434}\u{0435}\u{043A}\u{0430}\u{043B}\u{0438} \u{0438} \u{0447}\u{0430}\u{0441}\u{0442}\u{0438}\u{0446}\u{044B}",
        scrOptTitle   = "⚡ \u{041E}\u{043F}\u{0442}\u{0438}\u{043C}\u{0438}\u{0437}\u{0430}\u{0446}\u{0438}\u{044F} \u{0441}\u{043A}\u{0440}\u{0438}\u{043F}\u{0442}\u{0430} (\u{041A}\u{044D}\u{0448}\u{0438}\u{0440}\u{043E}\u{0432}\u{0430}\u{043D}\u{0438}\u{0435} \u{0441}\u{043B}\u{043E}\u{0442}\u{043E}\u{0432})",
        scrOptDesc    = "\u{0421}\u{043D}\u{0438}\u{0436}\u{0430}\u{0435}\u{0442} \u{043D}\u{0430}\u{0433}\u{0440}\u{0443}\u{0437}\u{043A}\u{0443} \u{043D}\u{0430} \u{043F}\u{0440}\u{043E}\u{0446}\u{0435}\u{0441}\u{0441}\u{043E}\u{0440} \u{0438} \u{043A}\u{044D}\u{0448}\u{0438}\u{0440}\u{0443}\u{0435}\u{0442} \u{043F}\u{0440}\u{043E}\u{0432}\u{0435}\u{0440}\u{0435}\u{043D}\u{043D}\u{044B}\u{0435} \u{0441}\u{043B}\u{043E}\u{0442}\u{044B} \u{0438}\u{043D}\u{0432}\u{0435}\u{043D}\u{0442}\u{0430}\u{0440}\u{044F}",
        autoExecTitle = "🔄 Auto-Execute (\u{0410}\u{0432}\u{0442}\u{043E}-\u{0437}\u{0430}\u{043F}\u{0443}\u{0441}\u{043A} \u{043F}\u{0440}\u{0438} \u{043F}\u{0435}\u{0440}\u{0435}\u{0445}\u{043E}\u{0434}\u{0435} \u{0432} \u{0422}\u{0440}\u{0435}\u{0439}\u{0434} \u{041F}\u{043B}\u{0430}\u{0437}\u{0443} / \u{041B}\u{043E}\u{0431}\u{0431}\u{0438})",
        autoExecDesc  = "\u{0410}\u{0432}\u{0442}\u{043E}\u{043C}\u{0430}\u{0442}\u{0438}\u{0447}\u{0435}\u{0441}\u{043A}\u{0438} \u{043F}\u{0435}\u{0440}\u{0435}\u{0437}\u{0430}\u{043F}\u{0443}\u{0441}\u{043A}\u{0430}\u{0435}\u{0442} \u{0441}\u{043A}\u{0440}\u{0438}\u{043F}\u{0442} \u{0447}\u{0435}\u{0440}\u{0435}\u{0437} queue_on_teleport \u{043F}\u{0440}\u{0438} \u{0441}\u{043C}\u{0435}\u{043D}\u{0435} \u{0441}\u{0435}\u{0440}\u{0432}\u{0435}\u{0440}\u{0430}",
        signerTitle   = "✍️ \u{0411}\u{043E}\u{043D}\u{0443}\u{0441}\u{044B} Signed \u{043F}\u{043E} \u{043D}\u{0438}\u{043A}\u{0443} (\u{043D}\u{0430}\u{043F}\u{0440}\u{0438}\u{043C}\u{0435}\u{0440}: KAPTOXA274 = +110%)",
        signerAddBtn  = "➕ \u{0421}\u{043E}\u{0445}\u{0440}\u{0430}\u{043D}\u{0438}\u{0442}\u{044C} %",
        skyboxTitle   = "🌌 \u{0421}\u{043C}\u{0435}\u{043D}\u{0430} Skybox (\u{0424}\u{0430}\u{0439}\u{043B} \u{0432} \u{043F}\u{0430}\u{043F}\u{043A}\u{0435} workspace, URL-\u{0441}\u{0441}\u{044B}\u{043B}\u{043A}\u{0430} \u{0438}\u{043B}\u{0438} ID)",
        skyboxApplyPC = "📂 \u{0421} \u{041F}\u{041A} (\u{0418}\u{0437} workspace)",
        skyboxApplyID = "🌌 \u{041F}\u{0440}\u{0438}\u{043C}\u{0435}\u{043D}\u{0438}\u{0442}\u{044C} ID/\u{041F}\u{0440}\u{0435}\u{0441}\u{0435}\u{0442}",
        skyboxReset   = "\u{0421}\u{0431}\u{0440}\u{043E}\u{0441}",
        cfgTitle      = "📋 Config Loader (\u{041A}\u{043E}\u{043F}\u{0438}\u{0440}\u{043E}\u{0432}\u{0430}\u{0442}\u{044C} / \u{0412}\u{0441}\u{0442}\u{0430}\u{0432}\u{0438}\u{0442}\u{044C} \u{043A}\u{043E}\u{043D}\u{0444}\u{0438}\u{0433}, \u{0446}\u{0435}\u{043D}\u{044B} \u{0438} \u{0431}\u{043E}\u{043D}\u{0443}\u{0441}\u{044B} Signed)",
        cfgCopy       = "📤 \u{0421}\u{043A}\u{043E}\u{043F}\u{0438}\u{0440}\u{043E}\u{0432}\u{0430}\u{0442}\u{044C} \u{043A}\u{043E}\u{043D}\u{0444}\u{0438}\u{0433}",
        cfgLoad       = "📥 \u{0412}\u{0441}\u{0442}\u{0430}\u{0432}\u{0438}\u{0442}\u{044C} / \u{041F}\u{0440}\u{0438}\u{043C}\u{0435}\u{043D}\u{0438}\u{0442}\u{044C}",
        reloadBtn     = "🔄 Reload Script (\u{041F}\u{0435}\u{0440}\u{0435}\u{0437}\u{0430}\u{043F}\u{0443}\u{0441}\u{0442}\u{0438}\u{0442}\u{044C} \u{0441}\u{043A}\u{0440}\u{0438}\u{043F}\u{0442})",
        unloadBtn     = "🛑 Unload Script (\u{0412}\u{044B}\u{043A}\u{043B}\u{044E}\u{0447}\u{0438}\u{0442}\u{044C} \u{043F}\u{043E}\u{043B}\u{043D}\u{043E}\u{0441}\u{0442}\u{044C}\u{044E})",
        enabled       = "\u{0412}\u{041A}\u{041B}\u{042E}\u{0427}\u{0415}\u{041D}\u{041E}",
        disabled      = "\u{0412}\u{042B}\u{041A}\u{041B}\u{042E}\u{0427}\u{0415}\u{041D}\u{041E}",
        copied        = "✅ \u{0421}\u{043A}\u{043E}\u{043F}\u{0438}\u{0440}\u{043E}\u{0432}\u{0430}\u{043D}\u{043E}!",
        loadingTitle  = "⚡ \u{0417}\u{0430}\u{0433}\u{0440}\u{0443}\u{0437}\u{043A}\u{0430} KvaplScript v6.3...",
        loadingSub    = "\u{0417}\u{0430}\u{0433}\u{0440}\u{0443}\u{0437}\u{043A}\u{0430} \u{0431}\u{0430}\u{0437}\u{044B} \u{0446}\u{0435}\u{043D}, Signed-\u{0431}\u{043E}\u{043D}\u{0443}\u{0441}\u{043E}\u{0432} \u{0438} \u{043C}\u{043E}\u{0434}\u{0443}\u{043B}\u{0435}\u{0439} \u{041F}\u{041A} / \u{0422}\u{0435}\u{043B}\u{0435}\u{0444}\u{043E}\u{043D}...",
        valuePrefix   = "💎 \u{0426}\u{0435}\u{043D}\u{0430}: ",
        metaFmt       = "📊 \u{0421}\u{043F}\u{0440}\u{043E}\u{0441}: %s | \u{0421}\u{0442}\u{0430}\u{0431}\u{0438}\u{043B}\u{044C}\u{043D}\u{043E}\u{0441}\u{0442}\u{044C}: %s",
        deviceTitle   = "\u{0412}\u{044B}\u{0431}\u{0435}\u{0440}\u{0438}\u{0442}\u{0435} \u{0432}\u{0430}\u{0448}\u{0435} \u{0443}\u{0441}\u{0442}\u{0440}\u{043E}\u{0439}\u{0441}\u{0442}\u{0432}\u{043E}",
        deviceSub     = "\u{0418}\u{043D}\u{0442}\u{0435}\u{0440}\u{0444}\u{0435}\u{0439}\u{0441} \u{0430}\u{0432}\u{0442}\u{043E}\u{043C}\u{0430}\u{0442}\u{0438}\u{0447}\u{0435}\u{0441}\u{043A}\u{0438} \u{043F}\u{043E}\u{0434}\u{0441}\u{0442}\u{0440}\u{043E}\u{0438}\u{0442}\u{0441}\u{044F} \u{043F}\u{043E}\u{0434} \u{0440}\u{0430}\u{0437}\u{043C}\u{0435}\u{0440} \u{044D}\u{043A}\u{0440}\u{0430}\u{043D}\u{0430}",
        btnPhone      = "📱 \u{0422}\u{0435}\u{043B}\u{0435}\u{0444}\u{043E}\u{043D}\n(\u{041A}\u{043E}\u{043C}\u{043F}\u{0430}\u{043A}\u{0442}\u{043D}\u{044B}\u{0439} UI)",
        btnPC         = "🖥️ \u{041F}\u{041A}\n(\u{041F}\u{043E}\u{043B}\u{043D}\u{044B}\u{0439} UI)",
    },
    Ukraine = {
        tabHome       = "🏠 Home",
        tabTrade      = "⚖️ \u{0422}\u{0440}\u{0435}\u{0439}\u{0434}",
        tabValues     = "💎 \u{041F}\u{0440}\u{0430}\u{0439}\u{0441}-\u{043B}\u{0438}\u{0441}\u{0442}",
        tabSettings   = "⚙️ \u{041D}\u{0430}\u{043B}\u{0430}\u{0448}\u{0442}\u{0443}\u{0432}\u{0430}\u{043D}\u{043D}\u{044F}",
        connectBtn    = "🔌 Connect (\u{041F}\u{0456}\u{0434}\u{043A}\u{043B}\u{044E}\u{0447}\u{0438}\u{0442}\u{0438} \u{043F}\u{0440}\u{043E}\u{0444}\u{0456}\u{043B}\u{044C})",
        connectedBtn  = "✅ \u{041F}\u{0440}\u{043E}\u{0444}\u{0456}\u{043B}\u{044C} \u{043F}\u{0456}\u{0434}\u{043A}\u{043B}\u{044E}\u{0447}\u{0435}\u{043D}\u{043E} (\u{041E}\u{043D}\u{043E}\u{0432}\u{0438}\u{0442}\u{0438} \u{0434}\u{0430}\u{043D}\u{0456})",
        displayName   = "\u{041D}\u{0456}\u{043A}\u{043D}\u{0435}\u{0439}\u{043C}",
        userName      = "\u{042E}\u{0437}\u{0435}\u{0440}\u{043D}\u{0435}\u{0439}\u{043C}",
        gemsCount     = "💎 \u{0413}\u{0435}\u{043C}\u{0438} (Gems)",
        coinsCount    = "🪙 \u{041C}\u{043E}\u{043D}\u{0435}\u{0442}\u{0438} (Coins)",
        winsCount     = "🏆 \u{041F}\u{0435}\u{0440}\u{0435}\u{043C}\u{043E}\u{0433}\u{0438} (Wins)",
        legCount      = "⭐ Legendary (\u{041B}\u{0435}\u{0433}\u{0435}\u{043D}\u{0434}\u{0430}\u{0440}\u{043D}\u{0456})",
        mythCount     = "🔥 Mythic (\u{041C}\u{0456}\u{0444}\u{0456}\u{0447}\u{043D}\u{0456})",
        godlyCount    = "⚡ Godly (\u{0413}\u{043E}\u{0434}\u{043B}\u{0456})",
        exclCount     = "👑 Exclusive (\u{0415}\u{043A}\u{0441}\u{043A}\u{043B}\u{044E}\u{0437}\u{0438}\u{0432}\u{043D}\u{0456})",
        notConnected  = "\u{041D}\u{0430}\u{0442}\u{0438}\u{0441}\u{043D}\u{0456}\u{0442}\u{044C} \u{043A}\u{043D}\u{043E}\u{043F}\u{043A}\u{0443} «Connect», \u{0449}\u{043E}\u{0431} \u{0437}\u{0430}\u{0432}\u{0430}\u{043D}\u{0442}\u{0430}\u{0436}\u{0438}\u{0442}\u{0438} \u{0430}\u{0432}\u{0430}\u{0442}\u{0430}\u{0440}\u{043A}\u{0443}, \u{0433}\u{0435}\u{043C}\u{0438}, \u{043C}\u{043E}\u{043D}\u{0435}\u{0442}\u{0438}, \u{043F}\u{0435}\u{0440}\u{0435}\u{043C}\u{043E}\u{0433}\u{0438} \u{0442}\u{0430} \u{044E}\u{043D}\u{0456}\u{0442}\u{0456}\u{0432}.",
        myOffer       = "📤 \u{041C}\u{043E}\u{044F} \u{043F}\u{0440}\u{043E}\u{043F}\u{043E}\u{0437}\u{0438}\u{0446}\u{0456}\u{044F} (\u{042F} \u{0434}\u{0430}\u{044E})",
        partnerOffer  = "📥 \u{041F}\u{0440}\u{043E}\u{043F}\u{043E}\u{0437}\u{0438}\u{0446}\u{0456}\u{044F} \u{0433}\u{0440}\u{0430}\u{0432}\u{0446}\u{044F} (\u{041C}\u{0435}\u{043D}\u{0456} \u{0434}\u{0430}\u{044E}\u{0442}\u{044C})",
        addManual     = "➕ \u{0414}\u{043E}\u{0434}\u{0430}\u{0442}\u{0438} \u{0432}\u{0440}\u{0443}\u{0447}\u{043D}\u{0443}",
        sumLabel      = "\u{0421}\u{0443}\u{043C}\u{0430}: ",
        clearBtn      = "\u{0421}\u{043A}\u{0438}\u{043D}\u{0443}\u{0442}\u{0438}",
        waitTrade     = "⚖️ \u{041E}\u{0427}\u{0406}\u{041A}\u{0423}\u{0412}\u{0410}\u{041D}\u{041D}\u{042F} \u{0422}\u{0420}\u{0415}\u{0419}\u{0414}\u{0423} — \u{0412}\u{0456}\u{0434}\u{043A}\u{0440}\u{0438}\u{0439}\u{0442}\u{0435} \u{043E}\u{0431}\u{043C}\u{0456}\u{043D} \u{0430}\u{0431}\u{043E} \u{0434}\u{043E}\u{0434}\u{0430}\u{0439}\u{0442}\u{0435} \u{044E}\u{043D}\u{0456}\u{0442}\u{0456}\u{0432}",
        winTrade      = "✅ WIN (\u{0412}\u{0418}\u{0413}\u{0420}\u{0410}\u{0428}): +%s \u{043D}\u{0430} \u{0432}\u{0430}\u{0448}\u{0443} \u{043A}\u{043E}\u{0440}\u{0438}\u{0441}\u{0442}\u{044C}!",
        loseTrade     = "❌ LOSE (\u{041F}\u{0420}\u{041E}\u{0413}\u{0420}\u{0410}\u{0428}): %s (\u{0432}\u{0438} \u{0432} \u{043C}\u{0456}\u{043D}\u{0443}\u{0441}\u{0456})",
        fairTrade     = "⚖️ FAIR (\u{0420}\u{0406}\u{0412}\u{041D}\u{0418}\u{0419} \u{0422}\u{0420}\u{0415}\u{0419}\u{0414}) — \u{0420}\u{0456}\u{0437}\u{043D}\u{0438}\u{0446}\u{044F}: 0 💎",
        youGive       = "\u{0412}\u{0438} \u{0434}\u{0430}\u{0454}\u{0442}\u{0435}: %s   |   \u{0412}\u{0430}\u{043C} \u{0434}\u{0430}\u{044E}\u{0442}\u{044C}: %s",
        langTitle     = "🌐 1. \u{0417}\u{043C}\u{0456}\u{043D}\u{0430} \u{043C}\u{043E}\u{0432}\u{0438} (Language)",
        langDesc      = "\u{041E}\u{0431}\u{0435}\u{0440}\u{0456}\u{0442}\u{044C} \u{043C}\u{043E}\u{0432}\u{0443} \u{0456}\u{043D}\u{0442}\u{0435}\u{0440}\u{0444}\u{0435}\u{0439}\u{0441}\u{0443}: English, Ukraine (\u{0423}\u{043A}\u{0440}\u{0430}\u{0457}\u{043D}\u{0441}\u{044C}\u{043A}\u{0430}) \u{0430}\u{0431}\u{043E} Ru (\u{0420}\u{043E}\u{0441}\u{0456}\u{0439}\u{0441}\u{044C}\u{043A}\u{0430})",
        autoReqTitle  = "📨 \u{0410}\u{0432}\u{0442}\u{043E}-\u{043F}\u{0440}\u{0438}\u{0439}\u{043D}\u{044F}\u{0442}\u{0442}\u{044F} \u{0437}\u{0430}\u{043F}\u{0438}\u{0442}\u{0443} \u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}",
        autoReqDesc   = "\u{041C}\u{0438}\u{0442}\u{0442}\u{0454}\u{0432}\u{043E} \u{043F}\u{0440}\u{0438}\u{0439}\u{043C}\u{0430}\u{0454} \u{0432}\u{0445}\u{0456}\u{0434}\u{043D}\u{0456} \u{0437}\u{0430}\u{043F}\u{0438}\u{0442}\u{0438} \u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434} (Popup / Notification / ✓)",
        autoAccTitle  = "🤝 \u{0410}\u{0432}\u{0442}\u{043E}-\u{043F}\u{0440}\u{0438}\u{0439}\u{043D}\u{044F}\u{0442}\u{0442}\u{044F} \u{0432}\u{0441}\u{0435}\u{0440}\u{0435}\u{0434}\u{0438}\u{043D}\u{0456} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}\u{0443} (Accept / Ready)",
        autoAccDesc   = "\u{041C}\u{0438}\u{0442}\u{0442}\u{0454}\u{0432}\u{043E} \u{043D}\u{0430}\u{0442}\u{0438}\u{0441}\u{043A}\u{0430}\u{0454} \u{043A}\u{043D}\u{043E}\u{043F}\u{043A}\u{0443} \u{043F}\u{0456}\u{0434}\u{0442}\u{0432}\u{0435}\u{0440}\u{0434}\u{0436}\u{0435}\u{043D}\u{043D}\u{044F} \u{0443} \u{0432}\u{0456}\u{0434}\u{043A}\u{0440}\u{0438}\u{0442}\u{043E}\u{043C}\u{0443} \u{0432}\u{0456}\u{043A}\u{043D}\u{0456} \u{043E}\u{0431}\u{043C}\u{0456}\u{043D}\u{0443}",
        safeAccTitle  = "🛡️ \u{0417}\u{0430}\u{0445}\u{0438}\u{0441}\u{0442} \u{0410}\u{0432}\u{0442}\u{043E}-\u{043F}\u{0440}\u{0438}\u{0439}\u{043D}\u{044F}\u{0442}\u{0442}\u{044F} (\u{041D}\u{0435} \u{043F}\u{0440}\u{0438}\u{0439}\u{043C}\u{0430}\u{0442}\u{0438} LOSE)",
        safeAccDesc   = "\u{0411}\u{043B}\u{043E}\u{043A}\u{0443}\u{0454} \u{0430}\u{0432}\u{0442}\u{043E}-\u{043F}\u{0456}\u{0434}\u{0442}\u{0432}\u{0435}\u{0440}\u{0434}\u{0436}\u{0435}\u{043D}\u{043D}\u{044F}, \u{044F}\u{043A}\u{0449}\u{043E} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434} \u{043D}\u{0435}\u{0432}\u{0438}\u{0433}\u{0456}\u{0434}\u{043D}\u{0438}\u{0439} \u{0434}\u{043B}\u{044F} \u{0432}\u{0430}\u{0441}",
        autoScanTitle = "🤖 \u{0410}\u{0432}\u{0442}\u{043E}-\u{0430}\u{043D}\u{0430}\u{043B}\u{0456}\u{0437} \u{0432}\u{0456}\u{043A}\u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}\u{0443}",
        autoScanDesc  = "\u{0410}\u{0432}\u{0442}\u{043E}\u{043C}\u{0430}\u{0442}\u{0438}\u{0447}\u{043D}\u{043E} \u{0437}\u{0447}\u{0438}\u{0442}\u{0443}\u{0454} \u{044E}\u{043D}\u{0456}\u{0442}\u{0456}\u{0432} (\u{0432}\u{043A}\u{043B}\u{044E}\u{0447}\u{043D}\u{043E} \u{0437} Signed) \u{0456} \u{0433}\u{0435}\u{043C}\u{0438} \u{043E}\u{0431}\u{043E}\u{0445} \u{0441}\u{0442}\u{043E}\u{0440}\u{0456}\u{043D}",
        gameOptTitle  = "🚀 \u{041E}\u{043F}\u{0442}\u{0438}\u{043C}\u{0456}\u{0437}\u{0430}\u{0446}\u{0456}\u{044F} \u{0433}\u{0440}\u{0438} (FPS Boost — \u{043F}\u{0440}\u{0438}\u{0431}\u{0440}\u{0430}\u{0442}\u{0438} \u{043C}\u{0430}\u{0442}\u{0435}\u{0440}\u{0456}\u{0430}\u{043B}\u{0438})",
        gameOptDesc   = "\u{0417}\u{0430}\u{043C}\u{0456}\u{043D}\u{044E}\u{0454} \u{043C}\u{0430}\u{0442}\u{0435}\u{0440}\u{0456}\u{0430}\u{043B}\u{0438} \u{043A}\u{0430}\u{0440}\u{0442}\u{0438} \u{043D}\u{0430} SmoothPlastic, \u{0432}\u{0438}\u{043C}\u{0438}\u{043A}\u{0430}\u{0454} \u{0442}\u{0456}\u{043D}\u{0456} \u{0442}\u{0430} \u{0447}\u{0430}\u{0441}\u{0442}\u{0438}\u{043D}\u{043A}\u{0438}",
        scrOptTitle   = "⚡ \u{041E}\u{043F}\u{0442}\u{0438}\u{043C}\u{0456}\u{0437}\u{0430}\u{0446}\u{0456}\u{044F} \u{0441}\u{043A}\u{0440}\u{0438}\u{043F}\u{0442}\u{0430} (\u{041A}\u{0435}\u{0448}\u{0443}\u{0432}\u{0430}\u{043D}\u{043D}\u{044F} \u{0441}\u{043B}\u{043E}\u{0442}\u{0456}\u{0432})",
        scrOptDesc    = "\u{0417}\u{043C}\u{0435}\u{043D}\u{0448}\u{0443}\u{0454} \u{043D}\u{0430}\u{0432}\u{0430}\u{043D}\u{0442}\u{0430}\u{0436}\u{0435}\u{043D}\u{043D}\u{044F} \u{0442}\u{0430} \u{043A}\u{0435}\u{0448}\u{0443}\u{0454} \u{043F}\u{0435}\u{0440}\u{0435}\u{0432}\u{0456}\u{0440}\u{0435}\u{043D}\u{0456} \u{0441}\u{043B}\u{043E}\u{0442}\u{0438} \u{0456}\u{043D}\u{0432}\u{0435}\u{043D}\u{0442}\u{0430}\u{0440}\u{044E}",
        autoExecTitle = "🔄 Auto-Execute (\u{0410}\u{0432}\u{0442}\u{043E}-\u{0437}\u{0430}\u{043F}\u{0443}\u{0441}\u{043A} \u{043F}\u{0440}\u{0438} \u{043F}\u{0435}\u{0440}\u{0435}\u{0445}\u{043E}\u{0434}\u{0456} \u{043D}\u{0430} \u{0422}\u{0440}\u{0435}\u{0439}\u{0434} \u{041F}\u{043B}\u{0430}\u{0437}\u{0443} / \u{041B}\u{043E}\u{0431}\u{0456})",
        autoExecDesc  = "\u{0410}\u{0432}\u{0442}\u{043E}\u{043C}\u{0430}\u{0442}\u{0438}\u{0447}\u{043D}\u{043E} \u{043F}\u{0435}\u{0440}\u{0435}\u{0437}\u{0430}\u{043F}\u{0443}\u{0441}\u{043A}\u{0430}\u{0454} \u{0441}\u{043A}\u{0440}\u{0438}\u{043F}\u{0442} \u{0447}\u{0435}\u{0440}\u{0435}\u{0437} queue_on_teleport \u{043F}\u{0440}\u{0438} \u{0437}\u{043C}\u{0456}\u{043D}\u{0456} \u{0441}\u{0435}\u{0440}\u{0432}\u{0435}\u{0440}\u{0430}",
        signerTitle   = "✍️ \u{0411}\u{043E}\u{043D}\u{0443}\u{0441}\u{0438} Signed \u{0437}\u{0430} \u{043D}\u{0456}\u{043A}\u{043E}\u{043C} (\u{043D}\u{0430}\u{043F}\u{0440}\u{0438}\u{043A}\u{043B}\u{0430}\u{0434}: KAPTOXA274 = +110%)",
        signerAddBtn  = "➕ \u{0417}\u{0431}\u{0435}\u{0440}\u{0435}\u{0433}\u{0442}\u{0438} %",
        skyboxTitle   = "🌌 \u{0417}\u{043C}\u{0456}\u{043D}\u{0430} Skybox (\u{0424}\u{0430}\u{0439}\u{043B} \u{0443} \u{043F}\u{0430}\u{043F}\u{0446}\u{0456} workspace, URL \u{0430}\u{0431}\u{043E} ID)",
        skyboxApplyPC = "📂 \u{0417} \u{041F}\u{041A} (\u{0406}\u{0437} workspace)",
        skyboxApplyID = "🌌 \u{0417}\u{0430}\u{0441}\u{0442}\u{043E}\u{0441}\u{0443}\u{0432}\u{0430}\u{0442}\u{0438} ID/\u{041F}\u{0440}\u{0435}\u{0441}\u{0435}\u{0442}",
        skyboxReset   = "\u{0421}\u{043A}\u{0438}\u{043D}\u{0443}\u{0442}\u{0438}",
        cfgTitle      = "📋 Config Loader (\u{0421}\u{043A}\u{043E}\u{043F}\u{0456}\u{044E}\u{0432}\u{0430}\u{0442}\u{0438} / \u{0412}\u{0441}\u{0442}\u{0430}\u{0432}\u{0438}\u{0442}\u{0438} \u{043A}\u{043E}\u{043D}\u{0444}\u{0456}\u{0433}, \u{0446}\u{0456}\u{043D}\u{0438} \u{0442}\u{0430} Signed)",
        cfgCopy       = "📤 \u{0421}\u{043A}\u{043E}\u{043F}\u{0456}\u{044E}\u{0432}\u{0430}\u{0442}\u{0438} \u{043A}\u{043E}\u{043D}\u{0444}\u{0456}\u{0433}",
        cfgLoad       = "📥 \u{0412}\u{0441}\u{0442}\u{0430}\u{0432}\u{0438}\u{0442}\u{0438} / \u{0417}\u{0430}\u{0441}\u{0442}\u{043E}\u{0441}\u{0443}\u{0432}\u{0430}\u{0442}\u{0438}",
        reloadBtn     = "🔄 Reload Script (\u{041F}\u{0435}\u{0440}\u{0435}\u{0437}\u{0430}\u{043F}\u{0443}\u{0441}\u{0442}\u{0438}\u{0442}\u{0438} \u{0441}\u{043A}\u{0440}\u{0438}\u{043F}\u{0442})",
        unloadBtn     = "🛑 Unload Script (\u{0412}\u{0438}\u{043C}\u{043A}\u{043D}\u{0443}\u{0442}\u{0438} \u{043F}\u{043E}\u{0432}\u{043D}\u{0456}\u{0441}\u{0442}\u{044E})",
        enabled       = "\u{0423}\u{0412}\u{0406}\u{041C}\u{041A}\u{041D}\u{0415}\u{041D}\u{041E}",
        disabled      = "\u{0412}\u{0418}\u{041C}\u{041A}\u{041D}\u{0415}\u{041D}\u{041E}",
        copied        = "✅ \u{0421}\u{043A}\u{043E}\u{043F}\u{0456}\u{0439}\u{043E}\u{0432}\u{0430}\u{043D}\u{043E}!",
        loadingTitle  = "⚡ \u{0417}\u{0430}\u{0432}\u{0430}\u{043D}\u{0442}\u{0430}\u{0436}\u{0435}\u{043D}\u{043D}\u{044F} KvaplScript v6.3...",
        loadingSub    = "\u{0417}\u{0430}\u{0432}\u{0430}\u{043D}\u{0442}\u{0430}\u{0436}\u{0435}\u{043D}\u{043D}\u{044F} \u{0431}\u{0430}\u{0437}\u{0438} \u{0446}\u{0456}\u{043D}, Signed-\u{0431}\u{043E}\u{043D}\u{0443}\u{0441}\u{0456}\u{0432} \u{0442}\u{0430} \u{043C}\u{043E}\u{0434}\u{0443}\u{043B}\u{0456}\u{0432} \u{041F}\u{041A} / \u{0422}\u{0435}\u{043B}\u{0435}\u{0444}\u{043E}\u{043D}...",
        valuePrefix   = "💎 \u{0426}\u{0456}\u{043D}\u{0430}: ",
        metaFmt       = "📊 \u{041F}\u{043E}\u{043F}\u{0438}\u{0442}: %s | \u{0421}\u{0442}\u{0430}\u{0431}\u{0456}\u{043B}\u{044C}\u{043D}\u{0456}\u{0441}\u{0442}\u{044C}: %s",
        deviceTitle   = "\u{041E}\u{0431}\u{0435}\u{0440}\u{0456}\u{0442}\u{044C} \u{0432}\u{0430}\u{0448} \u{043F}\u{0440}\u{0438}\u{0441}\u{0442}\u{0440}\u{0456}\u{0439}",
        deviceSub     = "\u{0406}\u{043D}\u{0442}\u{0435}\u{0440}\u{0444}\u{0435}\u{0439}\u{0441} \u{0430}\u{0432}\u{0442}\u{043E}\u{043C}\u{0430}\u{0442}\u{0438}\u{0447}\u{043D}\u{043E} \u{043F}\u{0456}\u{0434}\u{043B}\u{0430}\u{0448}\u{0442}\u{0443}\u{0454}\u{0442}\u{044C}\u{0441}\u{044F} \u{043F}\u{0456}\u{0434} \u{0440}\u{043E}\u{0437}\u{043C}\u{0456}\u{0440} \u{0435}\u{043A}\u{0440}\u{0430}\u{043D}\u{0443}",
        btnPhone      = "📱 \u{0422}\u{0435}\u{043B}\u{0435}\u{0444}\u{043E}\u{043D}\n(\u{041A}\u{043E}\u{043C}\u{043F}\u{0430}\u{043A}\u{0442}\u{043D}\u{0438}\u{0439} UI)",
        btnPC         = "🖥️ \u{041F}\u{041A}\n(\u{041F}\u{043E}\u{0432}\u{043D}\u{0438}\u{0439} UI)",
    },
    English = {
        tabHome       = "🏠 Home",
        tabTrade      = "⚖️ Trade",
        tabValues     = "💎 Value List",
        tabSettings   = "⚙️ Settings",
        connectBtn    = "🔌 Connect Profile",
        connectedBtn  = "✅ Profile Connected (Refresh Stats)",
        displayName   = "Display Name",
        userName      = "Username",
        gemsCount     = "💎 Gems",
        coinsCount    = "🪙 Coins",
        winsCount     = "🏆 Wins",
        legCount      = "⭐ Legendary Units",
        mythCount     = "🔥 Mythic Units",
        godlyCount    = "⚡ Godly Units",
        exclCount     = "👑 Exclusive Units",
        notConnected  = "Click 'Connect Profile' to load your avatar, Gems, Coins, Wins, and Inventory unit counts.",
        myOffer       = "📤 My Offer (You Give)",
        partnerOffer  = "📥 Partner Offer (You Get)",
        addManual     = "➕ Add Unit Manually",
        sumLabel      = "Total: ",
        clearBtn      = "Clear",
        waitTrade     = "⚖️ WAITING FOR TRADE — Open trade window or add units",
        winTrade      = "✅ WIN (PROFIT): +%s in your favor!",
        loseTrade     = "❌ LOSE (OVERPAY): %s (you lose value)",
        fairTrade     = "⚖️ FAIR TRADE — Difference: 0 💎",
        youGive       = "You Give: %s   |   You Get: %s",
        langTitle     = "🌐 1. Language Selection",
        langDesc      = "Switch interface language between English, Ukraine, and Ru",
        autoReqTitle  = "📨 Auto-Accept Trade Requests",
        autoReqDesc   = "Instantly accepts incoming trade invite popups (Popup / Notification / ✓)",
        autoAccTitle  = "🤝 Auto-Accept Trade Window (Accept / Ready)",
        autoAccDesc   = "Instantly clicks Accept / Ready / Confirm inside the active trade window",
        safeAccTitle  = "🛡️ Safe Auto-Accept (Block LOSE Trades)",
        safeAccDesc   = "Prevents auto-accepting if the trade is calculated as a LOSE",
        autoScanTitle = "🤖 Auto-Analyze Trade Window",
        autoScanDesc  = "Automatically detects units (including Signed & signer bonus) and gems",
        gameOptTitle  = "🚀 Game Optimization (FPS Boost — Remove Materials)",
        gameOptDesc   = "Converts map parts to SmoothPlastic, disables shadows, decals, and heavy particles",
        scrOptTitle   = "⚡ Script Optimization (Slot Caching & Light UI)",
        scrOptDesc    = "Lowers scan frequency and caches inventory slots for maximum FPS",
        autoExecTitle = "🔄 Auto-Execute (Persist Across Trade Plaza / Lobby)",
        autoExecDesc  = "Automatically re-runs KvaplScript via queue_on_teleport when teleporting",
        signerTitle   = "✍️ Signed Bonus % by Signer (e.g. KAPTOXA274 = +110%)",
        signerAddBtn  = "➕ Save %",
        skyboxTitle   = "🌌 Custom Skybox (Workspace File, Image URL, or Asset ID)",
        skyboxApplyPC = "📂 From PC (Workspace)",
        skyboxApplyID = "🌌 Apply ID / Preset",
        skyboxReset   = "Reset",
        cfgTitle      = "📋 Config Loader (Copy / Paste Config, Prices & Signer Bonuses)",
        cfgCopy       = "📤 Copy Config JSON",
        cfgLoad       = "📥 Load / Apply JSON",
        reloadBtn     = "🔄 Reload Script",
        unloadBtn     = "🛑 Unload Script Completely",
        enabled       = "ENABLED",
        disabled      = "DISABLED",
        copied        = "✅ Copied!",
        loadingTitle  = "⚡ Loading KvaplScript v6.3...",
        loadingSub    = "Loading updated values, Signed bonuses, and PC / Mobile UI...",
        valuePrefix   = "💎 Value: ",
        metaFmt       = "📊 Demand: %s | Stability: %s",
        deviceTitle   = "Select Your Device",
        deviceSub     = "The interface will adapt automatically to your screen size",
        btnPhone      = "📱 Phone\n(Compact Mobile UI)",
        btnPC         = "🖥️ PC\n(Full Desktop UI)",
    }
}

local Config = {
    Language           = "Ru",
    AutoAcceptRequest  = false,
    AutoAcceptTrade    = false,
    SafeAutoAccept     = true,
    AutoScanTrade      = true,
    GameOptimization   = false,
    ScriptOptimization = false,
    AutoExecute        = false,
    SkyboxInput        = "",
    ScanInterval       = 0.5,
    CustomPrices       = {},
    DefaultSignBonus   = 35,
    SignerBonuses      = {
        -- Aligators Games developers (DevSigned)
        ["aibat303e"]     = 150,
        ["iop_dev"]       = 150,
        ["devsigned"]     = 150,
        ["aligator"]      = 120,
        -- Partners and YouTubers of Cameraman Tower Defense
        ["kaptoxa274"]    = 110,
        ["kvapl"]         = 100,
        ["bumroblox"]     = 65,
        ["bumrobloxviet"] = 65,
        ["mininoobyt"]    = 60,
        ["mininoob"]      = 60,
        ["mnoobgames"]    = 60,
        ["kozy"]          = 55,
        ["cozy"]          = 55,
        ["youtuber"]      = 40,
    },
}

local function T(key)
    local langTable = Translations[Config.Language] or Translations.Ru
    return langTable[key] or Translations.Ru[key] or key
end

-- ============================================================================
-- UNIT PRICE DATABASE (NOVEMBER 2026) - ALLIANCE CAKE = 15,500 GEMS
-- ============================================================================
local UnitDatabase = {
    ["Pharaoh Cameraman"]              = { value = 23000, rarity = "Godly",     demand = "8/10",   trend = "Dropping",          category = "Unit" },
    ["Alliance Cake"]                  = { value = 15500, rarity = "Exclusive", demand = "8/10",   trend = "Overpaid",          category = "Unit" },
    ["Spider TV"]                      = { value = 15000, rarity = "Exclusive", demand = "8/10",   trend = "Overpaid / Stable", category = "Unit" },
    ["Engineer Cameraman"]             = { value = 7650,  rarity = "Exclusive", demand = "8.5/10", trend = "Stable",            category = "Unit" },
    ["Chaos Cameraman"]                = { value = 6900,  rarity = "Godly",     demand = "7/10",   trend = "Stable",            category = "Unit" },
    ["Upgraded Titan TV Man"]          = { value = 3500,  rarity = "Godly",     demand = "7.5/10", trend = "Stable",            category = "Unit" },
    ["Upgraded Titan Cameraman"]       = { value = 3100,  rarity = "Godly",     demand = "6/10",   trend = "Fluctuating",       category = "Unit" },
    ["Baker Titan Speakerman"]         = { value = 2500,  rarity = "Exclusive", demand = "6/10",   trend = "Dropping",          category = "Unit" },
    ["Executioner TV Man"]             = { value = 2200,  rarity = "Mythic",    demand = "8/10",   trend = "Stable",            category = "Unit" },
    ["Hacked Cameraman"]               = { value = 1500,  rarity = "Exclusive", demand = "7/10",   trend = "Unstable",          category = "Unit" },
    ["Reinforced Titan Cameraman"]     = { value = 1100,  rarity = "Mythic",    demand = "4/10",   trend = "Dropping",          category = "Unit" },
    ["Reinforced Titan Speakerman"]    = { value = 700,   rarity = "Mythic",    demand = "5/10",   trend = "Slowly Dropping",   category = "Unit" },
    ["Vampire Cameraman"]              = { value = 510,   rarity = "Exclusive", demand = "2/10",   trend = "Dropping",          category = "Unit" },
    ["Prototype Duo"]                  = { value = 500,   rarity = "Mythic",    demand = "4/10",   trend = "Fluctuating",       category = "Unit" },
    ["Headless TV Man"]                = { value = 400,   rarity = "Mythic",    demand = "2/10",   trend = "Dropping",          category = "Unit" },
    ["Jetpack Cameraman"]              = { value = 350,   rarity = "Exclusive", demand = "3/10",   trend = "Fluctuating",       category = "Unit" },
    ["Large Scientist Cameraman"]      = { value = 350,   rarity = "Exclusive", demand = "5/10",   trend = "Stable",            category = "Unit" },
    ["Camera Attack Helicopter"]       = { value = 255,   rarity = "Exclusive", demand = "3/10",   trend = "Dropping",          category = "Unit" },
    ["CinemaMan Titan"]                = { value = 220,   rarity = "Mythic",    demand = "5.5/10", trend = "Unwanted",          category = "Unit" },
    ["Large Laser Cameraman"]          = { value = 220,   rarity = "Mythic",    demand = "4/10",   trend = "Unwanted",          category = "Unit" },
    ["Upgraded Brute Prototype"]       = { value = 220,   rarity = "Mythic",    demand = "3.5/10", trend = "Unwanted",          category = "Unit" },
    ["Glitch Plungerman"]              = { value = 190,   rarity = "Mythic",    demand = "4.5/10", trend = "Unwanted",          category = "Unit" },
    ["TV Woman"]                       = { value = 190,   rarity = "Mythic",    demand = "2/10",   trend = "Unwanted",          category = "Unit" },
    ["Upgraded Videotapper Prototype"] = { value = 160,   rarity = "Mythic",    demand = "3/10",   trend = "Unwanted",          category = "Unit" },
    ["Scientist Cameraman"]            = { value = 125,   rarity = "Exclusive", demand = "6/10",   trend = "Overpaid",          category = "Unit" },
    ["Upgraded Titan Speakerman"]      = { value = 80,    rarity = "Mythic",    demand = "2.9/10", trend = "Slowly Dropping",   category = "Unit" },
    ["Chocolate TV Man"]               = { value = 65,    rarity = "Mythic",    demand = "3/10",   trend = "Stable",            category = "Unit" },
    ["Camera Strider"]                 = { value = 65,    rarity = "Legendary", demand = "2/10",   trend = "Stable",            category = "Unit" },
    ["Camera Spider"]                  = { value = 15,    rarity = "Exclusive", demand = "2/10",   trend = "Stable",            category = "Unit" },
    ["Dark Speakerman"]                = { value = 11,    rarity = "Legendary", demand = "2/10",   trend = "Stable",            category = "Unit" },
    ["Speaker Helicopter"]             = { value = 11,    rarity = "Legendary", demand = "1.5/10", trend = "Stable",            category = "Unit" },
    ["Pumpkin Farmer"]                 = { value = 10,    rarity = "Exclusive", demand = "3/10",   trend = "Stable",            category = "Unit" },
    ["Camera Repair Drone"]            = { value = 3,     rarity = "Exclusive", demand = "4/10",   trend = "Stable",            category = "Unit" },
    ["SpeakerWoman"]                   = { value = 3,     rarity = "Legendary", demand = "1.5/10", trend = "Unstable",          category = "Unit" },
    ["Dragon Cameraman"]               = { value = 2,     rarity = "Legendary", demand = "1/10",   trend = "Slowly Dropping",   category = "Unit" },
    ["Laser Cameraman Car"]            = { value = 2,     rarity = "Legendary", demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Ninja Cameraman"]                = { value = 2,     rarity = "Legendary", demand = "1.8/10", trend = "Stable",            category = "Unit" },
    ["Titan Cameraman"]                = { value = 2,     rarity = "Legendary", demand = "1.5/10", trend = "Stable",            category = "Unit" },
    ["Titan TV Man"]                   = { value = 2,     rarity = "Legendary", demand = "1.5/10", trend = "Stable",            category = "Unit" },
    ["Titan Speakerman"]               = { value = 1,     rarity = "Legendary", demand = "1/10",   trend = "Stable",            category = "Unit" },

    ["x2 Candy"]                       = { value = 2350,  rarity = "Gamepass",  demand = "6.5/10", trend = "Overpaid",          category = "Gamepass" },
    ["Premium Pass"]                   = { value = 1900,  rarity = "Gamepass",  demand = "7.5/10", trend = "Overpaid",          category = "Gamepass" },
    ["2x Money"]                       = { value = 1550,  rarity = "Gamepass",  demand = "7/10",   trend = "Overpaid",          category = "Gamepass" },
    ["2x Lucky"]                       = { value = 1550,  rarity = "Gamepass",  demand = "7/10",   trend = "Stable",            category = "Gamepass" },
    ["2X Speed"]                       = { value = 1050,  rarity = "Gamepass",  demand = "7/10",   trend = "Stable",            category = "Gamepass" },

    ["Scientist Crate"]                = { value = 500,   rarity = "Crate",     demand = "7/10",   trend = "Stable",            category = "Crate" },
    ["Sand Coffin Crate"]              = { value = 265,   rarity = "Crate",     demand = "3/10",   trend = "Unstable",          category = "Crate" },
    ["Party Crate"]                    = { value = 80,    rarity = "Crate",     demand = "7/10",   trend = "Stable",            category = "Crate" },
    ["Spider Crate"]                   = { value = 70,    rarity = "Crate",     demand = "4.5/10", trend = "Stable",            category = "Crate" },
    ["Halloween Crate"]                = { value = 30,    rarity = "Crate",     demand = "3.5/10", trend = "Stable",            category = "Crate" },
    ["Woman Crate"]                    = { value = 5,     rarity = "Crate",     demand = "1.8/10", trend = "Stable",            category = "Crate" },

    ["Balloon Speakerman"]             = { value = 0,     rarity = "Rare",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Mummy Cameraman"]                = { value = 0,     rarity = "Epic",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Rocket Cameraman"]               = { value = 0,     rarity = "Epic",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Werewolf Speakerman"]            = { value = 0,     rarity = "Epic",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Speaker Spider"]                 = { value = 0,     rarity = "Rare",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Large TV Man"]                   = { value = 0,     rarity = "Epic",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Camera Helicopter"]              = { value = 0,     rarity = "Epic",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Large Cameraman"]                = { value = 0,     rarity = "Rare",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Large Speakerman"]               = { value = 0,     rarity = "Rare",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Dark Camerawoman"]               = { value = 0,     rarity = "Rare",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Speakerman"]                     = { value = 0,     rarity = "Common",    demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Popcorn Cameraman"]              = { value = 0,     rarity = "Rare",      demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Brown Cameraman"]                = { value = 0,     rarity = "Common",    demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Car Speakerman"]                 = { value = 0,     rarity = "Common",    demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Clown Speakerman"]               = { value = 0,     rarity = "Common",    demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["Cameraman"]                      = { value = 0,     rarity = "Common",    demand = "1/10",   trend = "Stable",            category = "Unit" },
    ["TV Man"]                         = { value = 0,     rarity = "Rare",      demand = "1/10",   trend = "Stable",            category = "Unit" },
}

local UnitAliases = {
    ["tv spider"]                       = "Spider TV",
    ["spider tv"]                       = "Spider TV",
    ["\u{043F}\u{0430}\u{0443}\u{043A} \u{0442}\u{0432}"]                         = "Spider TV",
    ["\u{0442}\u{0432} \u{043F}\u{0430}\u{0443}\u{043A}"]                         = "Spider TV",
    ["\u{0442}\u{043E}\u{0440}\u{0442} \u{0430}\u{043B}\u{044C}\u{044F}\u{043D}\u{0441}\u{0430}"]                    = "Alliance Cake",
    ["\u{0430}\u{043B}\u{044C}\u{044F}\u{043D}\u{0441} \u{043A}\u{0435}\u{0439}\u{043A}"]                     = "Alliance Cake",
    ["\u{043F}\u{0435}\u{043A}\u{0430}\u{0440}\u{044C} \u{0442}\u{0438}\u{0442}\u{0430}\u{043D} \u{0441}\u{043F}\u{0438}\u{043A}\u{0435}\u{0440}\u{043C}\u{0435}\u{043D}"]          = "Baker Titan Speakerman",
    ["\u{0448}\u{043E}\u{043A}\u{043E}\u{043B}\u{0430}\u{0434}\u{043D}\u{044B}\u{0439} \u{0442}\u{0432} \u{043C}\u{0435}\u{043D}"]               = "Chocolate TV Man",
    ["chocolate tv man"]                = "Chocolate TV Man",
    ["party cake crate"]                = "Party Crate",
    ["\u{0444}\u{0430}\u{0440}\u{0430}\u{043E}\u{043D}"]                          = "Pharaoh Cameraman",
    ["\u{0444}\u{0430}\u{0440}\u{0430}\u{043E}\u{043D} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]                = "Pharaoh Cameraman",
    ["\u{0438}\u{043D}\u{0436}\u{0435}\u{043D}\u{0435}\u{0440}"]                         = "Engineer Cameraman",
    ["\u{0438}\u{043D}\u{0436}\u{0435}\u{043D}\u{0435}\u{0440} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]               = "Engineer Cameraman",
    ["\u{0445}\u{0430}\u{043E}\u{0441} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]                  = "Chaos Cameraman",
    ["\u{0431}\u{043E}\u{043B}\u{044C}\u{0448}\u{043E}\u{0439} \u{0443}\u{0447}\u{0451}\u{043D}\u{044B}\u{0439}"]                  = "Large Scientist Cameraman",
    ["\u{0431}\u{043E}\u{043B}\u{044C}\u{0448}\u{043E}\u{0439} \u{0443}\u{0447}\u{0435}\u{043D}\u{044B}\u{0439}"]                  = "Large Scientist Cameraman",
    ["\u{0432}\u{0435}\u{043B}\u{0438}\u{043A}\u{0438}\u{0439} \u{0432}\u{0447}\u{0435}\u{043D}\u{0438}\u{0439}"]                  = "Large Scientist Cameraman",
    ["\u{0431}\u{043E}\u{043B}\u{044C}\u{0448}\u{043E}\u{0439} \u{0443}\u{0447}\u{0451}\u{043D}\u{044B}\u{0439} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]        = "Large Scientist Cameraman",
    ["\u{0431}\u{043E}\u{043B}\u{044C}\u{0448}\u{043E}\u{0439} \u{0443}\u{0447}\u{0435}\u{043D}\u{044B}\u{0439} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]        = "Large Scientist Cameraman",
    ["large scientist"]                 = "Large Scientist Cameraman",
    ["\u{0443}\u{0447}\u{0451}\u{043D}\u{044B}\u{0439} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]                = "Scientist Cameraman",
    ["\u{0443}\u{0447}\u{0435}\u{043D}\u{044B}\u{0439} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]                = "Scientist Cameraman",
    ["\u{0434}\u{0436}\u{0435}\u{0442}\u{043F}\u{0430}\u{043A} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]               = "Jetpack Cameraman",
    ["\u{0431}\u{0435}\u{0437}\u{0433}\u{043E}\u{043B}\u{043E}\u{0432}\u{044B}\u{0439} \u{0442}\u{0432} \u{043C}\u{0435}\u{043D}"]               = "Headless TV Man",
    ["\u{043F}\u{0430}\u{043B}\u{0430}\u{0447} \u{0442}\u{0432} \u{043C}\u{0435}\u{043D}"]                    = "Executioner TV Man",
    ["\u{0445}\u{0430}\u{043A}\u{0435}\u{0440} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]                 = "Hacked Cameraman",
    ["\u{0432}\u{0430}\u{043C}\u{043F}\u{0438}\u{0440} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]                = "Vampire Cameraman",
    ["\u{043F}\u{0440}\u{043E}\u{0442}\u{043E}\u{0442}\u{0438}\u{043F} \u{0434}\u{0443}\u{043E}"]                    = "Prototype Duo",
    ["prototypes duo"]                  = "Prototype Duo",
    ["titan cinemaman"]                 = "CinemaMan Titan",
    ["cinemaman titan"]                 = "CinemaMan Titan",
    ["\u{0442}\u{0438}\u{0442}\u{0430}\u{043D} \u{0441}\u{0438}\u{043D}\u{0435}\u{043C}\u{0430}\u{043C}\u{0435}\u{043D}"]                 = "CinemaMan Titan",
    ["large prototype titan"]           = "Upgraded Brute Prototype",
    ["upgraded brute prototype"]        = "Upgraded Brute Prototype",
    ["upgrade brute prototype"]         = "Upgraded Brute Prototype",
    ["glitch cameraman"]                = "Glitch Plungerman",
    ["glitch plungerman"]               = "Glitch Plungerman",
    ["\u{0433}\u{043B}\u{0438}\u{0442}\u{0447} \u{0432}\u{0430}\u{043D}\u{0442}\u{0443}\u{0437}\u{043C}\u{0435}\u{043D}"]                 = "Glitch Plungerman",
    ["\u{0433}\u{043B}\u{0438}\u{0442}\u{0447} \u{043A}\u{0430}\u{043C}\u{0435}\u{0440}\u{0430}\u{043C}\u{0435}\u{043D}"]                 = "Glitch Plungerman",
    ["videotaper titan"]                = "Upgraded Videotapper Prototype",
    ["upgraded videotapper prototype"]  = "Upgraded Videotapper Prototype",
    ["double coins"]                    = "2x Money",
    ["2x coins"]                        = "2x Money",
    ["double luck"]                     = "2x Lucky",
    ["double candy"]                    = "x2 Candy",
    ["2x candy"]                        = "x2 Candy",
    ["x2 speed"]                        = "2X Speed",
    ["2x speed"]                        = "2X Speed",
    ["utcm"]                            = "Upgraded Titan Cameraman",
    ["utc"]                             = "Upgraded Titan Cameraman",
    ["uttvm"]                           = "Upgraded Titan TV Man",
    ["utsm"]                            = "Upgraded Titan Speakerman",
}

local Colors = {
    BgPrimary     = Color3.fromRGB(14, 16, 24),
    BgSecondary   = Color3.fromRGB(22, 25, 38),
    BgCard        = Color3.fromRGB(31, 35, 52),
    Accent        = Color3.fromRGB(99, 102, 241),
    Discord       = Color3.fromRGB(88, 101, 242),
    Telegram      = Color3.fromRGB(0, 136, 204),
    TextPrimary   = Color3.fromRGB(245, 247, 250),
    TextMuted     = Color3.fromRGB(156, 163, 175),
    WinGreen      = Color3.fromRGB(34, 197, 94),
    FairYellow    = Color3.fromRGB(234, 179, 8),
    LoseRed       = Color3.fromRGB(239, 68, 68),
    GemCyan       = Color3.fromRGB(56, 189, 248),
    CoinGold      = Color3.fromRGB(250, 204, 21),
    WinOrange     = Color3.fromRGB(251, 146, 60),
    SignGold      = Color3.fromRGB(253, 224, 71),
}

local SortedItems = {}
local SearchKeys  = {}
local IgnoredPartNames = {
    ["head"] = true, ["torso"] = true, ["humanoidrootpart"] = true, ["humanoid"] = true,
    ["left arm"] = true, ["right arm"] = true, ["left leg"] = true, ["right leg"] = true,
    ["worldmodel"] = true, ["camera"] = true, ["handle"] = true, ["animator"] = true,
    ["template"] = true, ["slot"] = true, ["frame"] = true, ["scrollingframe"] = true,
}

-- ============================================================================
-- HELPER FUNCTIONS AND SIGNED CALCULATION
-- ============================================================================
function Fn.trackConn(conn)
    table.insert(State.ActiveConnections, conn)
    return conn
end

function Fn.formatNumber(amount)
    local num = tonumber(amount) or 0
    local sign = num < 0 and "-" or ""
    local absVal = math.abs(num)
    local intPart = math.floor(absVal)
    local fracPart = absVal - intPart
    local formatted = tostring(intPart)
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    if fracPart > 0.001 then
        local fracStr = string.gsub(string.format("%.2f", fracPart), "^0", "")
        fracStr = string.gsub(fracStr, "0+$", "")
        formatted = formatted .. fracStr
    end
    return sign .. formatted
end

function Fn.formatGems(amount)
    return Fn.formatNumber(amount) .. " 💎"
end

function Fn.getSignerBonusPercent(signerName)
    if type(signerName) ~= "string" or signerName == "" then
        return Config.DefaultSignBonus
    end
    local low = string.lower(string.gsub(signerName, "^%s*(.-)%s*$", "%1"))
    if Config.SignerBonuses[low] then return Config.SignerBonuses[low] end
    for key, pct in pairs(Config.SignerBonuses) do
        if string.find(low, key, 1, true) then return pct end
    end
    return Config.DefaultSignBonus
end

function Fn.computeSignedPrice(baseValue, signerName)
    local pct = Fn.getSignerBonusPercent(signerName)
    if baseValue <= 0 then
        return math.max(5, math.floor(pct / 10)), pct
    end
    return math.floor(baseValue * (1 + (pct / 100))), pct
end

function Fn.rebuildSortedItems()
    table.clear(SortedItems)
    for name, data in pairs(UnitDatabase) do
        table.insert(SortedItems, {
            name = name, value = data.value, rarity = data.rarity,
            demand = data.demand, trend = data.trend, category = data.category
        })
    end
    table.sort(SortedItems, function(a, b)
        if a.value == b.value then return a.name < b.name end
        return a.value > b.value
    end)
end

function Fn.rebuildSearchKeys()
    table.clear(SearchKeys)
    for k, _ in pairs(UnitDatabase) do
        table.insert(SearchKeys, { key = string.lower(k), canonical = k })
    end
    for alias, target in pairs(UnitAliases) do
        if UnitDatabase[target] then
            table.insert(SearchKeys, { key = string.lower(alias), canonical = target })
        end
    end
    table.sort(SearchKeys, function(a, b) return #a.key > #b.key end)
end

Fn.rebuildSortedItems()
Fn.rebuildSearchKeys()

function Fn.findUnitData(rawText)
    if type(rawText) ~= "string" or rawText == "" then return nil, nil end
    local clean = string.gsub(rawText, "^%s*(.-)%s*$", "%1")
    if #clean < 3 or #clean > 75 then return nil, nil end
    if string.match(clean, "^[%$%d%s,%./%+%-xX💎kK]+$") then return nil, nil end

    local stripped = string.gsub(clean, "%[?[Dd]ev[Ss]igned%]?%s*", "")
    stripped = string.gsub(stripped, "%[?[Ss]igned%]?%s*", "")
    local lowerClean = string.lower(stripped)
    if IgnoredPartNames[lowerClean] then return nil, nil end

    if UnitDatabase[stripped] then return stripped, UnitDatabase[stripped] end
    if UnitAliases[lowerClean] then
        local canonical = UnitAliases[lowerClean]
        return canonical, UnitDatabase[canonical]
    end
    for _, entry in ipairs(SearchKeys) do
        if lowerClean == entry.key then return entry.canonical, UnitDatabase[entry.canonical] end
    end
    for _, entry in ipairs(SearchKeys) do
        local startIdx, endIdx = string.find(lowerClean, entry.key, 1, true)
        if startIdx then
            local prevChar = startIdx > 1 and string.sub(lowerClean, startIdx - 1, startIdx - 1) or " "
            local nextChar = endIdx < #lowerClean and string.sub(lowerClean, endIdx + 1, endIdx + 1) or " "
            if not string.match(prevChar, "[%a\u{0410}-\u{042F}\u{0430}-\u{044F}\u{0406}\u{0456}\u{0407}\u{0457}\u{0404}\u{0454}]") and not string.match(nextChar, "[%a\u{0410}-\u{042F}\u{0430}-\u{044F}\u{0406}\u{0456}\u{0407}\u{0457}\u{0404}\u{0454}]") then
                return entry.canonical, UnitDatabase[entry.canonical]
            end
        end
    end
    return nil, nil
end

local function extractSignerFromString(rawText)
    if type(rawText) ~= "string" or rawText == "" then return nil end
    local clean = string.gsub(rawText, "^%s*(.-)%s*$", "%1")
    local low = string.lower(clean)

    -- Explicitly filter out unsigned units ("Not Signed", "Unsigned", "None")
    if string.find(low, "not signed", 1, true) or string.find(low, "unsigned", 1, true)
        or string.find(low, "\u{0431}\u{0435}\u{0437} \u{043F}\u{043E}\u{0434}\u{043F}\u{0438}\u{0441}", 1, true) or low == "none" or low == "false" then
        return nil
    end

    local byName = string.match(clean, "[Ss]igned%s+[Bb]y%s*[:%-]?%s*@?([%w_%-]+)")
        or string.match(clean, "[Ss]igned%s*[:%-]%s*@?([%w_%-]+)")
        or string.match(clean, "[\u{041F}\u{043F}]\u{043E}\u{0434}\u{043F}\u{0438}\u{0441}[\u{0430}-\u{044F}\u{0410}-\u{042F}]*%s*[:%-]?%s*@?([%w_%-]+)")
    if byName and byName ~= "" then
        local lb = string.lower(byName)
        if lb ~= "none" and lb ~= "nil" and lb ~= "false" and lb ~= "no" then
            return byName
        end
    end

    -- Look for known signers only if the line mentions a signature or the nickname stands alone
    local hasSignWord = string.find(low, "signed", 1, true) or string.find(low, "\u{043F}\u{043E}\u{0434}\u{043F}\u{0438}\u{0441}", 1, true) or string.find(low, "✍️", 1, true)
    for knownSigner, _ in pairs(Config.SignerBonuses) do
        if #knownSigner >= 4 and (low == knownSigner or (hasSignWord and string.find(low, knownSigner, 1, true))) then
            return knownSigner
        end
    end

    if string.find(low, "devsigned", 1, true) then return "DevSigned" end
    if hasSignWord then return "Partner" end
    return nil
end

function Fn.detectSlotSigner(slotFrame)
    if not slotFrame then return false, nil end
    if State.HoverSignMap[slotFrame] then return true, State.HoverSignMap[slotFrame] end

    -- 1. Slot attribute check (only non-empty and not "none"/"false")
    for attrName, attrVal in pairs(slotFrame:GetAttributes()) do
        if string.find(string.lower(attrName), "sign", 1, true) then
            if type(attrVal) == "string" then
                local lv = string.lower(string.gsub(attrVal, "^%s*(.-)%s*$", "%1"))
                if lv ~= "" and lv ~= "none" and lv ~= "false" and lv ~= "nil" and lv ~= "0" then
                    return true, attrVal
                end
            elseif attrVal == true then
                return true, "Partner"
            end
        end
    end

    -- 2. Name of the slot itself
    local fromSlotName = extractSignerFromString(slotFrame.Name)
    if fromSlotName then return true, fromSlotName end

    -- 3. Only VISIBLE text labels, non-empty StringValue/BoolValue or a really displayed signature icon
    local foundGenericSign = false
    for _, desc in ipairs(slotFrame:GetDescendants()) do
        if desc.Name ~= "KvaplPriceTag" and desc.Name ~= "KvaplMetaTag" then
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible and desc.TextTransparency < 0.95 then
                local s = extractSignerFromString(desc.Text)
                if s then
                    if s ~= "Partner" then return true, s end
                    foundGenericSign = true
                end
            elseif desc:IsA("StringValue") and string.find(string.lower(desc.Name), "sign", 1, true) then
                local lv = string.lower(string.gsub(desc.Value or "", "^%s*(.-)%s*$", "%1"))
                if lv ~= "" and lv ~= "none" and lv ~= "false" and lv ~= "nil" then
                    return true, desc.Value
                end
            elseif desc:IsA("BoolValue") and string.find(string.lower(desc.Name), "sign", 1, true) and desc.Value == true then
                foundGenericSign = true
            elseif desc:IsA("ImageLabel") and desc.Visible and desc.Image ~= "" and desc.ImageTransparency < 0.9 then
                local dn = string.lower(desc.Name)
                if dn == "signed" or dn == "signicon" or dn == "signature" or dn == "signedicon" or dn == "signbadge" then
                    foundGenericSign = true
                end
            end
        end
    end
    if foundGenericSign then return true, "Partner" end
    return false, nil
end

function Fn.copyToClipboard(textToCopy, buttonInstance, defaultText)
    if typeof(setclipboard) == "function" then
        pcall(setclipboard, textToCopy)
    elseif typeof(toclipboard) == "function" then
        pcall(toclipboard, textToCopy)
    end
    if buttonInstance and buttonInstance.Parent then
        buttonInstance.Text = T("copied")
        task.delay(2, function()
            if buttonInstance and buttonInstance.Parent then buttonInstance.Text = defaultText end
        end)
    end
end

function Fn.makeDraggable(dragHandle, targetFrame)
    local dragging, dragInput, dragStart, startPos
    Fn.trackConn(dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end))
    Fn.trackConn(dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    Fn.trackConn(S.UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

-- ============================================================================
-- SCREENGUI, LOADING SCREEN AND DEVICE CHOICE (PHONE / PC)
-- ============================================================================
UI.ScreenGui = Instance.new("ScreenGui")
UI.ScreenGui.Name = UI_NAME
UI.ScreenGui.ResetOnSpawn = false
UI.ScreenGui.IgnoreGuiInset = true
UI.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
UI.ScreenGui.DisplayOrder = 2147483647
UI.ScreenGui.Parent = GuiParent

-- Apply layout for Phone (compact and handy) or for PC (full)
function Fn.applyDeviceLayout(isMobile)
    State.IsMobileMode = isMobile
    if isMobile then
        -- Auto-fit the scale to the phone screen width and height
        local cam = S.Workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
        local scaleX = (vp.X * 0.88) / 760
        local scaleY = (vp.Y * 0.78) / 500
        local targetScale = math.clamp(math.min(scaleX, scaleY), 0.45, 0.78)

        UI.MainScale.Scale = targetScale
        UI.MainFrame.Position = UDim2.new(0.5, -math.floor(380 * targetScale), 0.5, -math.floor(230 * targetScale) + 14)

        -- Compact top HUD for phone
        UI.HudScale.Scale = math.clamp(targetScale + 0.12, 0.58, 0.82)
        UI.LiveHud.Position = UDim2.new(0.5, -math.floor(295 * UI.HudScale.Scale), 0, 6)
        UI.ToggleMainBtn.Text = "📊 \u{041C}\u{0435}\u{043D}\u{044E}"

        -- Show the convenient floating "Kvapl" button to open/hide with a finger
        UI.MobileFloatBtn.Visible = true
    else
        UI.MainScale.Scale = 1
        UI.MainFrame.Position = UDim2.new(0.5, -380, 0.5, -230)

        UI.HudScale.Scale = 1
        UI.LiveHud.Position = UDim2.new(0.5, -295, 0, 10)
        UI.ToggleMainBtn.Text = "📊 \u{041C}\u{0435}\u{043D}\u{044E} [RShift]"

        UI.MobileFloatBtn.Visible = false
    end
end

-- Two-button choice window after loading: Phone / PC
function Fn.showDeviceSelector(onChosen)
    local Selector = Instance.new("Frame")
    Selector.Name = "DeviceSelectOverlay"
    Selector.Size = UDim2.new(0, 400, 0, 195)
    Selector.Position = UDim2.new(0.5, -200, 0.5, -97)
    Selector.BackgroundColor3 = Colors.BgPrimary
    Selector.BorderSizePixel = 0
    Selector.ZIndex = 16000
    Selector.Parent = UI.ScreenGui
    Instance.new("UICorner", Selector).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", Selector)
    st.Color = Colors.Accent st.Thickness = 2

    -- Adaptive scale of the choice window on very small screens
    local cam = S.Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1000, 600)
    if vp.X < 500 then
        local sc = Instance.new("UIScale", Selector)
        sc.Scale = math.clamp((vp.X * 0.9) / 400, 0.65, 1)
    end

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -24, 0, 30)
    Title.Position = UDim2.new(0, 12, 0, 16)
    Title.BackgroundTransparency = 1
    Title.Text = "⚡ KvaplScript — " .. T("deviceTitle")
    Title.TextColor3 = Colors.TextPrimary
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 17
    Title.ZIndex = 16001
    Title.Parent = Selector

    local Sub = Instance.new("TextLabel")
    Sub.Size = UDim2.new(1, -24, 0, 20)
    Sub.Position = UDim2.new(0, 12, 0, 48)
    Sub.BackgroundTransparency = 1
    Sub.Text = T("deviceSub")
    Sub.TextColor3 = Colors.TextMuted
    Sub.Font = Enum.Font.GothamMedium
    Sub.TextSize = 12
    Sub.ZIndex = 16001
    Sub.Parent = Selector

    local PhoneBtn = Instance.new("TextButton")
    PhoneBtn.Size = UDim2.new(0.45, 0, 0, 86)
    PhoneBtn.Position = UDim2.new(0.04, 0, 0, 84)
    PhoneBtn.BackgroundColor3 = Colors.WinGreen
    PhoneBtn.Text = T("btnPhone")
    PhoneBtn.TextColor3 = Colors.TextPrimary
    PhoneBtn.Font = Enum.Font.GothamBold
    PhoneBtn.TextSize = 14
    PhoneBtn.ZIndex = 16002
    PhoneBtn.Parent = Selector
    Instance.new("UICorner", PhoneBtn).CornerRadius = UDim.new(0, 10)

    local PCBtn = Instance.new("TextButton")
    PCBtn.Size = UDim2.new(0.45, 0, 0, 86)
    PCBtn.Position = UDim2.new(0.51, 0, 0, 84)
    PCBtn.BackgroundColor3 = Colors.Accent
    PCBtn.Text = T("btnPC")
    PCBtn.TextColor3 = Colors.TextPrimary
    PCBtn.Font = Enum.Font.GothamBold
    PCBtn.TextSize = 14
    PCBtn.ZIndex = 16002
    PCBtn.Parent = Selector
    Instance.new("UICorner", PCBtn).CornerRadius = UDim.new(0, 10)

    PhoneBtn.MouseButton1Click:Connect(function()
        Selector:Destroy()
        Fn.applyDeviceLayout(true)
        if onChosen then onChosen(true) end
    end)

    PCBtn.MouseButton1Click:Connect(function()
        Selector:Destroy()
        Fn.applyDeviceLayout(false)
        if onChosen then onChosen(false) end
    end)
end

function Fn.playLoadingScreen(durationSeconds, onComplete)
    local LoadOverlay = Instance.new("Frame")
    LoadOverlay.Name = "LoadingOverlay"
    LoadOverlay.Size = UDim2.new(0, 460, 0, 245)
    LoadOverlay.Position = UDim2.new(0.5, -230, 0.5, -122)
    LoadOverlay.BackgroundColor3 = Colors.BgPrimary
    LoadOverlay.BorderSizePixel = 0
    LoadOverlay.ZIndex = 15000
    LoadOverlay.Parent = UI.ScreenGui
    Instance.new("UICorner", LoadOverlay).CornerRadius = UDim.new(0, 14)
    local s1 = Instance.new("UIStroke", LoadOverlay)
    s1.Color = Colors.Accent s1.Thickness = 2

    local cam = S.Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1000, 600)
    if vp.X < 520 then
        local sc = Instance.new("UIScale", LoadOverlay)
        sc.Scale = math.clamp((vp.X * 0.9) / 460, 0.65, 1)
    end

    local LoadHeader = Instance.new("TextLabel")
    LoadHeader.Size = UDim2.new(1, -24, 0, 32)
    LoadHeader.Position = UDim2.new(0, 12, 0, 16)
    LoadHeader.BackgroundTransparency = 1
    LoadHeader.Text = T("loadingTitle")
    LoadHeader.TextColor3 = Colors.TextPrimary
    LoadHeader.Font = Enum.Font.GothamBold
    LoadHeader.TextSize = 19
    LoadHeader.ZIndex = 15001
    LoadHeader.Parent = LoadOverlay

    local LoadSub = Instance.new("TextLabel")
    LoadSub.Size = UDim2.new(1, -32, 0, 22)
    LoadSub.Position = UDim2.new(0, 16, 0, 50)
    LoadSub.BackgroundTransparency = 1
    LoadSub.Text = T("loadingSub")
    LoadSub.TextColor3 = Colors.TextMuted
    LoadSub.Font = Enum.Font.GothamMedium
    LoadSub.TextSize = 11
    LoadSub.ZIndex = 15001
    LoadSub.Parent = LoadOverlay

    local BarBg = Instance.new("Frame")
    BarBg.Size = UDim2.new(1, -48, 0, 18)
    BarBg.Position = UDim2.new(0, 24, 0, 86)
    BarBg.BackgroundColor3 = Colors.BgCard
    BarBg.BorderSizePixel = 0
    BarBg.ZIndex = 15001
    BarBg.Parent = LoadOverlay
    Instance.new("UICorner", BarBg).CornerRadius = UDim.new(0, 9)

    local BarFill = Instance.new("Frame")
    BarFill.Size = UDim2.new(0, 0, 1, 0)
    BarFill.BackgroundColor3 = Colors.Accent
    BarFill.BorderSizePixel = 0
    BarFill.ZIndex = 15002
    BarFill.Parent = BarBg
    Instance.new("UICorner", BarFill).CornerRadius = UDim.new(0, 9)

    local PercentLbl = Instance.new("TextLabel")
    PercentLbl.Size = UDim2.new(1, 0, 0, 20)
    PercentLbl.Position = UDim2.new(0, 0, 0, 110)
    PercentLbl.BackgroundTransparency = 1
    PercentLbl.Text = "0%"
    PercentLbl.TextColor3 = Colors.GemCyan
    PercentLbl.Font = Enum.Font.GothamBold
    PercentLbl.TextSize = 13
    PercentLbl.ZIndex = 15001
    PercentLbl.Parent = LoadOverlay

    local SocialInfo = Instance.new("TextLabel")
    SocialInfo.Size = UDim2.new(1, -24, 0, 20)
    SocialInfo.Position = UDim2.new(0, 12, 0, 138)
    SocialInfo.BackgroundTransparency = 1
    SocialInfo.Text = "\u{041E}\u{0444}\u{0438}\u{0446}\u{0438}\u{0430}\u{043B}\u{044C}\u{043D}\u{044B}\u{0435} \u{0441}\u{0441}\u{044B}\u{043B}\u{043A}\u{0438} KvaplScript (\u{043D}\u{0430}\u{0436}\u{043C}\u{0438}\u{0442}\u{0435}, \u{0447}\u{0442}\u{043E}\u{0431}\u{044B} \u{0441}\u{043A}\u{043E}\u{043F}\u{0438}\u{0440}\u{043E}\u{0432}\u{0430}\u{0442}\u{044C}):"
    SocialInfo.TextColor3 = Colors.TextMuted
    SocialInfo.Font = Enum.Font.Gotham
    SocialInfo.TextSize = 11
    SocialInfo.ZIndex = 15001
    SocialInfo.Parent = LoadOverlay

    local LoadDiscordBtn = Instance.new("TextButton")
    LoadDiscordBtn.Size = UDim2.new(0.46, 0, 0, 36)
    LoadDiscordBtn.Position = UDim2.new(0.03, 0, 0, 166)
    LoadDiscordBtn.BackgroundColor3 = Colors.Discord
    LoadDiscordBtn.Text = "🔗 Discord: ehm5KCjR6"
    LoadDiscordBtn.TextColor3 = Colors.TextPrimary
    LoadDiscordBtn.Font = Enum.Font.GothamBold
    LoadDiscordBtn.TextSize = 12
    LoadDiscordBtn.ZIndex = 15002
    LoadDiscordBtn.Parent = LoadOverlay
    Instance.new("UICorner", LoadDiscordBtn).CornerRadius = UDim.new(0, 8)

    local LoadTgBtn = Instance.new("TextButton")
    LoadTgBtn.Size = UDim2.new(0.46, 0, 0, 36)
    LoadTgBtn.Position = UDim2.new(0.51, 0, 0, 166)
    LoadTgBtn.BackgroundColor3 = Colors.Telegram
    LoadTgBtn.Text = "✈️ Telegram: t.me/TTKvapl"
    LoadTgBtn.TextColor3 = Colors.TextPrimary
    LoadTgBtn.Font = Enum.Font.GothamBold
    LoadTgBtn.TextSize = 12
    LoadTgBtn.ZIndex = 15002
    LoadTgBtn.Parent = LoadOverlay
    Instance.new("UICorner", LoadTgBtn).CornerRadius = UDim.new(0, 8)

    local RawUrlsLabel = Instance.new("TextLabel")
    RawUrlsLabel.Size = UDim2.new(1, -20, 0, 20)
    RawUrlsLabel.Position = UDim2.new(0, 10, 1, -28)
    RawUrlsLabel.BackgroundTransparency = 1
    RawUrlsLabel.Text = DISCORD_LINK .. "   |   " .. TELEGRAM_LINK
    RawUrlsLabel.TextColor3 = Colors.TextPrimary
    RawUrlsLabel.Font = Enum.Font.GothamMedium
    RawUrlsLabel.TextSize = 11
    RawUrlsLabel.ZIndex = 15001
    RawUrlsLabel.Parent = LoadOverlay

    LoadDiscordBtn.MouseButton1Click:Connect(function() Fn.copyToClipboard(DISCORD_LINK, LoadDiscordBtn, "🔗 Discord: ehm5KCjR6") end)
    LoadTgBtn.MouseButton1Click:Connect(function() Fn.copyToClipboard(TELEGRAM_LINK, LoadTgBtn, "✈️ Telegram: t.me/TTKvapl") end)

    task.spawn(function()
        local steps = 80
        local stepTime = durationSeconds / steps
        for i = 1, steps do
            if not State.IsRunning or not LoadOverlay.Parent then return end
            local ratio = i / steps
            BarFill.Size = UDim2.new(ratio, 0, 1, 0)
            PercentLbl.Text = string.format("%d%% (%0.1f c)", math.floor(ratio * 100), durationSeconds - (i * stepTime))
            task.wait(stepTime)
        end
        if LoadOverlay and LoadOverlay.Parent then LoadOverlay:Destroy() end
        if onComplete then onComplete() end
    end)
end

-- ============================================================================
-- 1. LIVE HUD, FLOATING MOBILE BUTTON AND MAIN WINDOW
-- ============================================================================
do
    -- Floating button for phone (draggable with a finger)
    UI.MobileFloatBtn = Instance.new("TextButton")
    UI.MobileFloatBtn.Name = "MobileToggleBtn"
    UI.MobileFloatBtn.Size = UDim2.new(0, 82, 0, 36)
    UI.MobileFloatBtn.Position = UDim2.new(0, 12, 0.5, -18)
    UI.MobileFloatBtn.BackgroundColor3 = Colors.Accent
    UI.MobileFloatBtn.Text = "⚡ Kvapl"
    UI.MobileFloatBtn.TextColor3 = Colors.TextPrimary
    UI.MobileFloatBtn.Font = Enum.Font.GothamBold
    UI.MobileFloatBtn.TextSize = 13
    UI.MobileFloatBtn.Visible = false
    UI.MobileFloatBtn.ZIndex = 9500
    UI.MobileFloatBtn.Parent = UI.ScreenGui
    Instance.new("UICorner", UI.MobileFloatBtn).CornerRadius = UDim.new(0, 18)
    local mStroke = Instance.new("UIStroke", UI.MobileFloatBtn)
    mStroke.Color = Colors.GemCyan mStroke.Thickness = 1.5
    Fn.makeDraggable(UI.MobileFloatBtn, UI.MobileFloatBtn)

    UI.LiveHud = Instance.new("Frame")
    UI.LiveHud.Name = "LiveTradeHUD"
    UI.LiveHud.Size = UDim2.new(0, 590, 0, 54)
    UI.LiveHud.Position = UDim2.new(0.5, -295, 0, 10)
    UI.LiveHud.BackgroundColor3 = Colors.BgPrimary
    UI.LiveHud.BackgroundTransparency = 0.06
    UI.LiveHud.BorderSizePixel = 0
    UI.LiveHud.Visible = false
    UI.LiveHud.ZIndex = 9000
    UI.LiveHud.Parent = UI.ScreenGui
    Instance.new("UICorner", UI.LiveHud).CornerRadius = UDim.new(0, 10)

    UI.HudScale = Instance.new("UIScale", UI.LiveHud)
    UI.HudScale.Scale = 1

    UI.HudStroke = Instance.new("UIStroke", UI.LiveHud)
    UI.HudStroke.Color = Colors.Accent UI.HudStroke.Thickness = 2

    UI.HudTitle = Instance.new("TextLabel")
    UI.HudTitle.Size = UDim2.new(1, -150, 0, 24)
    UI.HudTitle.Position = UDim2.new(0, 12, 0, 4)
    UI.HudTitle.BackgroundTransparency = 1
    UI.HudTitle.Text = "⚡ KvaplScript v6.3: \u{041E}\u{0436}\u{0438}\u{0434}\u{0430}\u{043D}\u{0438}\u{0435} \u{043E}\u{043A}\u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}\u{0430}..."
    UI.HudTitle.TextColor3 = Colors.FairYellow
    UI.HudTitle.Font = Enum.Font.GothamBold
    UI.HudTitle.TextSize = 14
    UI.HudTitle.TextXAlignment = Enum.TextXAlignment.Left
    UI.HudTitle.ZIndex = 9001
    UI.HudTitle.Parent = UI.LiveHud

    UI.HudSub = Instance.new("TextLabel")
    UI.HudSub.Size = UDim2.new(1, -150, 0, 20)
    UI.HudSub.Position = UDim2.new(0, 12, 0, 28)
    UI.HudSub.BackgroundTransparency = 1
    UI.HudSub.Text = "\u{0412}\u{044B} \u{0434}\u{0430}\u{0451}\u{0442}\u{0435}: 0 💎  |  \u{0412}\u{0430}\u{043C} \u{0434}\u{0430}\u{044E}\u{0442}: 0 💎"
    UI.HudSub.TextColor3 = Colors.TextPrimary
    UI.HudSub.Font = Enum.Font.GothamMedium
    UI.HudSub.TextSize = 12
    UI.HudSub.TextXAlignment = Enum.TextXAlignment.Left
    UI.HudSub.ZIndex = 9001
    UI.HudSub.Parent = UI.LiveHud

    UI.ToggleMainBtn = Instance.new("TextButton")
    UI.ToggleMainBtn.Size = UDim2.new(0, 130, 0, 36)
    UI.ToggleMainBtn.Position = UDim2.new(1, -138, 0.5, -18)
    UI.ToggleMainBtn.BackgroundColor3 = Colors.Accent
    UI.ToggleMainBtn.Text = "📊 \u{041C}\u{0435}\u{043D}\u{044E} [RShift]"
    UI.ToggleMainBtn.TextColor3 = Colors.TextPrimary
    UI.ToggleMainBtn.Font = Enum.Font.GothamBold
    UI.ToggleMainBtn.TextSize = 12
    UI.ToggleMainBtn.ZIndex = 9002
    UI.ToggleMainBtn.Parent = UI.LiveHud
    Instance.new("UICorner", UI.ToggleMainBtn).CornerRadius = UDim.new(0, 7)

    UI.MainFrame = Instance.new("Frame")
    UI.MainFrame.Name = "MainFrame"
    UI.MainFrame.Size = UDim2.new(0, 760, 0, 500)
    UI.MainFrame.Position = UDim2.new(0.5, -380, 0.5, -230)
    UI.MainFrame.BackgroundColor3 = Colors.BgPrimary
    UI.MainFrame.BorderSizePixel = 0
    UI.MainFrame.Visible = false
    UI.MainFrame.ZIndex = 8000
    UI.MainFrame.Parent = UI.ScreenGui
    Instance.new("UICorner", UI.MainFrame).CornerRadius = UDim.new(0, 12)

    UI.MainScale = Instance.new("UIScale", UI.MainFrame)
    UI.MainScale.Scale = 1

    UI.MainStroke = Instance.new("UIStroke", UI.MainFrame)
    UI.MainStroke.Color = Colors.Accent UI.MainStroke.Thickness = 1.8

    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 44)
    Header.BackgroundColor3 = Colors.BgSecondary
    Header.BorderSizePixel = 0
    Header.ZIndex = 8001
    Header.Parent = UI.MainFrame
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 250, 1, 0)
    TitleLabel.Position = UDim2.new(0, 14, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "⚡ KvaplScript v6.3 | Camera TD"
    TitleLabel.TextColor3 = Colors.TextPrimary
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 8002
    TitleLabel.Parent = Header

    local TelegramBtn = Instance.new("TextButton")
    TelegramBtn.Size = UDim2.new(0, 155, 0, 28)
    TelegramBtn.Position = UDim2.new(1, -425, 0.5, -14)
    TelegramBtn.BackgroundColor3 = Colors.Telegram
    TelegramBtn.Text = "✈️ TG: t.me/TTKvapl"
    TelegramBtn.TextColor3 = Colors.TextPrimary
    TelegramBtn.Font = Enum.Font.GothamBold
    TelegramBtn.TextSize = 11
    TelegramBtn.ZIndex = 8002
    TelegramBtn.Parent = Header
    Instance.new("UICorner", TelegramBtn).CornerRadius = UDim.new(0, 6)

    local DiscordBtn = Instance.new("TextButton")
    DiscordBtn.Size = UDim2.new(0, 165, 0, 28)
    DiscordBtn.Position = UDim2.new(1, -262, 0.5, -14)
    DiscordBtn.BackgroundColor3 = Colors.Discord
    DiscordBtn.Text = "🔗 Discord: ehm5KCjR6"
    DiscordBtn.TextColor3 = Colors.TextPrimary
    DiscordBtn.Font = Enum.Font.GothamBold
    DiscordBtn.TextSize = 11
    DiscordBtn.ZIndex = 8002
    DiscordBtn.Parent = Header
    Instance.new("UICorner", DiscordBtn).CornerRadius = UDim.new(0, 6)

    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Size = UDim2.new(0, 32, 0, 28)
    MinimizeBtn.Position = UDim2.new(1, -86, 0.5, -14)
    MinimizeBtn.BackgroundColor3 = Colors.BgCard
    MinimizeBtn.Text = "—"
    MinimizeBtn.TextColor3 = Colors.TextPrimary
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.TextSize = 14
    MinimizeBtn.ZIndex = 8002
    MinimizeBtn.Parent = Header
    Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

    local HideBtn = Instance.new("TextButton")
    HideBtn.Size = UDim2.new(0, 38, 0, 28)
    HideBtn.Position = UDim2.new(1, -48, 0.5, -14)
    HideBtn.BackgroundColor3 = Colors.LoseRed
    HideBtn.Text = "✕"
    HideBtn.TextColor3 = Colors.TextPrimary
    HideBtn.Font = Enum.Font.GothamBold
    HideBtn.TextSize = 12
    HideBtn.ZIndex = 8002
    HideBtn.Parent = Header
    Instance.new("UICorner", HideBtn).CornerRadius = UDim.new(0, 6)

    Fn.makeDraggable(Header, UI.MainFrame)
    Fn.makeDraggable(UI.LiveHud, UI.LiveHud)

    UI.BodyFrame = Instance.new("Frame")
    UI.BodyFrame.Size = UDim2.new(1, 0, 1, -44)
    UI.BodyFrame.Position = UDim2.new(0, 0, 0, 44)
    UI.BodyFrame.BackgroundTransparency = 1
    UI.BodyFrame.ZIndex = 8001
    UI.BodyFrame.Parent = UI.MainFrame

    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -24, 0, 34)
    TabBar.Position = UDim2.new(0, 12, 0, 8)
    TabBar.BackgroundColor3 = Colors.BgSecondary
    TabBar.BorderSizePixel = 0
    TabBar.ZIndex = 8002
    TabBar.Parent = UI.BodyFrame
    Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 8)

    local function mkTab(text, posScale, isDefault)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0.25, -4, 1, -6)
        Btn.Position = UDim2.new(posScale, 2, 0, 3)
        Btn.BackgroundColor3 = isDefault and Colors.Accent or Colors.BgCard
        Btn.Text = text
        Btn.TextColor3 = isDefault and Colors.TextPrimary or Colors.TextMuted
        Btn.Font = Enum.Font.GothamBold
        Btn.TextSize = 12
        Btn.ZIndex = 8003
        Btn.Parent = TabBar
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
        return Btn
    end

    UI.HomeTabBtn     = mkTab(T("tabHome"),     0.00, true)
    UI.TradeTabBtn    = mkTab(T("tabTrade"),    0.25, false)
    UI.ValuesTabBtn   = mkTab(T("tabValues"),   0.50, false)
    UI.SettingsTabBtn = mkTab(T("tabSettings"), 0.75, false)

    local Footer = Instance.new("Frame")
    Footer.Size = UDim2.new(1, -24, 0, 30)
    Footer.Position = UDim2.new(0, 12, 1, -36)
    Footer.BackgroundColor3 = Colors.BgSecondary
    Footer.BorderSizePixel = 0
    Footer.ZIndex = 8002
    Footer.Parent = UI.BodyFrame
    Instance.new("UICorner", Footer).CornerRadius = UDim.new(0, 8)

    local FooterText = Instance.new("TextLabel")
    FooterText.Size = UDim2.new(1, -20, 1, 0)
    FooterText.Position = UDim2.new(0, 10, 0, 0)
    FooterText.BackgroundTransparency = 1
    FooterText.Text = "Discord: " .. DISCORD_LINK .. "  |  Telegram: " .. TELEGRAM_LINK .. "  |  Menu: RightShift"
    FooterText.TextColor3 = Colors.TextMuted
    FooterText.Font = Enum.Font.GothamMedium
    FooterText.TextSize = 11
    FooterText.TextXAlignment = Enum.TextXAlignment.Left
    FooterText.ZIndex = 8003
    FooterText.Parent = Footer

    DiscordBtn.MouseButton1Click:Connect(function() Fn.copyToClipboard(DISCORD_LINK, DiscordBtn, "🔗 Discord: ehm5KCjR6") end)
    TelegramBtn.MouseButton1Click:Connect(function() Fn.copyToClipboard(TELEGRAM_LINK, TelegramBtn, "✈️ TG: t.me/TTKvapl") end)

    local isMin = false
    MinimizeBtn.MouseButton1Click:Connect(function()
        isMin = not isMin
        UI.BodyFrame.Visible = not isMin
        UI.MainFrame.Size = isMin and UDim2.new(0, 760, 0, 44) or UDim2.new(0, 760, 0, 500)
    end)
    HideBtn.MouseButton1Click:Connect(function() UI.MainFrame.Visible = false end)
    UI.ToggleMainBtn.MouseButton1Click:Connect(function() UI.MainFrame.Visible = not UI.MainFrame.Visible end)
    UI.MobileFloatBtn.MouseButton1Click:Connect(function() UI.MainFrame.Visible = not UI.MainFrame.Visible end)
    Fn.trackConn(S.UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.RightShift then
            UI.MainFrame.Visible = not UI.MainFrame.Visible
        end
    end))
end

-- ============================================================================
-- TAB 0: HOME
-- ============================================================================
do
    UI.HomePage = Instance.new("Frame")
    UI.HomePage.Size = UDim2.new(1, -24, 1, -88)
    UI.HomePage.Position = UDim2.new(0, 12, 0, 48)
    UI.HomePage.BackgroundTransparency = 1
    UI.HomePage.Visible = true
    UI.HomePage.ZIndex = 8002
    UI.HomePage.Parent = UI.BodyFrame

    UI.ConnectBtn = Instance.new("TextButton")
    UI.ConnectBtn.Size = UDim2.new(1, 0, 0, 40)
    UI.ConnectBtn.BackgroundColor3 = Colors.Accent
    UI.ConnectBtn.Text = T("connectBtn")
    UI.ConnectBtn.TextColor3 = Colors.TextPrimary
    UI.ConnectBtn.Font = Enum.Font.GothamBold
    UI.ConnectBtn.TextSize = 14
    UI.ConnectBtn.ZIndex = 8003
    UI.ConnectBtn.Parent = UI.HomePage
    Instance.new("UICorner", UI.ConnectBtn).CornerRadius = UDim.new(0, 9)

    UI.HomeNotice = Instance.new("TextLabel")
    UI.HomeNotice.Size = UDim2.new(1, 0, 0, 30)
    UI.HomeNotice.Position = UDim2.new(0, 0, 0, 46)
    UI.HomeNotice.BackgroundTransparency = 1
    UI.HomeNotice.Text = T("notConnected")
    UI.HomeNotice.TextColor3 = Colors.TextMuted
    UI.HomeNotice.Font = Enum.Font.GothamMedium
    UI.HomeNotice.TextSize = 12
    UI.HomeNotice.ZIndex = 8003
    UI.HomeNotice.Parent = UI.HomePage

    UI.ProfileContainer = Instance.new("Frame")
    UI.ProfileContainer.Size = UDim2.new(1, 0, 1, -48)
    UI.ProfileContainer.Position = UDim2.new(0, 0, 0, 48)
    UI.ProfileContainer.BackgroundColor3 = Colors.BgSecondary
    UI.ProfileContainer.BorderSizePixel = 0
    UI.ProfileContainer.Visible = false
    UI.ProfileContainer.ZIndex = 8003
    UI.ProfileContainer.Parent = UI.HomePage
    Instance.new("UICorner", UI.ProfileContainer).CornerRadius = UDim.new(0, 10)

    local AvatarFrame = Instance.new("Frame")
    AvatarFrame.Size = UDim2.new(0, 122, 0, 122)
    AvatarFrame.Position = UDim2.new(0, 14, 0, 14)
    AvatarFrame.BackgroundColor3 = Colors.BgCard
    AvatarFrame.BorderSizePixel = 0
    AvatarFrame.ZIndex = 8004
    AvatarFrame.Parent = UI.ProfileContainer
    Instance.new("UICorner", AvatarFrame).CornerRadius = UDim.new(0, 12)

    UI.AvatarImg = Instance.new("ImageLabel")
    UI.AvatarImg.Size = UDim2.new(1, -8, 1, -8)
    UI.AvatarImg.Position = UDim2.new(0, 4, 0, 4)
    UI.AvatarImg.BackgroundTransparency = 1
    UI.AvatarImg.ZIndex = 8005
    UI.AvatarImg.Parent = AvatarFrame
    Instance.new("UICorner", UI.AvatarImg).CornerRadius = UDim.new(0, 10)

    local function mkStat(posX, posY, sizeW, sizeH, labelTitle, valueText, valueColor)
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(sizeW, -8, 0, sizeH)
        Card.Position = UDim2.new(posX, 0, 0, posY)
        Card.BackgroundColor3 = Colors.BgCard
        Card.BorderSizePixel = 0
        Card.ZIndex = 8004
        Card.Parent = UI.ProfileContainer
        Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 8)

        local TTitle = Instance.new("TextLabel")
        TTitle.Size = UDim2.new(1, -14, 0, 18)
        TTitle.Position = UDim2.new(0, 10, 0, 5)
        TTitle.BackgroundTransparency = 1
        TTitle.Text = labelTitle
        TTitle.TextColor3 = Colors.TextMuted
        TTitle.Font = Enum.Font.GothamMedium
        TTitle.TextSize = 11
        TTitle.TextXAlignment = Enum.TextXAlignment.Left
        TTitle.ZIndex = 8005
        TTitle.Parent = Card

        local TVal = Instance.new("TextLabel")
        TVal.Size = UDim2.new(1, -14, 0, 26)
        TVal.Position = UDim2.new(0, 10, 0, 24)
        TVal.BackgroundTransparency = 1
        TVal.Text = valueText
        TVal.TextColor3 = valueColor or Colors.TextPrimary
        TVal.Font = Enum.Font.GothamBold
        TVal.TextSize = 15
        TVal.TextXAlignment = Enum.TextXAlignment.Left
        TVal.ZIndex = 8005
        TVal.Parent = Card
        return TTitle, TVal
    end

    UI.DispNameTitle,  UI.DispNameVal  = mkStat(0.20, 14,  0.39, 56, T("displayName"), "—",     Colors.TextPrimary)
    UI.UserNameTitle,  UI.UserNameVal  = mkStat(0.59, 14,  0.40, 56, T("userName"),    "—",     Colors.Accent)
    UI.GemsStatTitle,  UI.GemsStatVal  = mkStat(0.20, 78,  0.26, 58, T("gemsCount"),   "0 💎",  Colors.GemCyan)
    UI.CoinsStatTitle, UI.CoinsStatVal = mkStat(0.46, 78,  0.27, 58, T("coinsCount"),  "0 🪙",  Colors.CoinGold)
    UI.WinsStatTitle,  UI.WinsStatVal  = mkStat(0.73, 78,  0.26, 58, T("winsCount"),   "0 🏆",  Colors.WinOrange)
    UI.LegStatTitle,   UI.LegStatVal   = mkStat(0.02, 148, 0.48, 66, T("legCount"),    "0 \u{0448}\u{0442}.", Colors.FairYellow)
    UI.MythStatTitle,  UI.MythStatVal  = mkStat(0.50, 148, 0.49, 66, T("mythCount"),   "0 \u{0448}\u{0442}.", Color3.fromRGB(239, 68, 68))
    UI.GodlyStatTitle, UI.GodlyStatVal = mkStat(0.02, 224, 0.48, 66, T("godlyCount"),  "0 \u{0448}\u{0442}.", Color3.fromRGB(168, 85, 247))
    UI.ExclStatTitle,  UI.ExclStatVal  = mkStat(0.50, 224, 0.49, 66, T("exclCount"),   "0 \u{0448}\u{0442}.", Colors.WinGreen)
end

local function parseFormattedNumber(rawStr)
    if type(rawStr) == "number" then return rawStr end
    if type(rawStr) ~= "string" then return nil end
    local clean = string.lower(string.gsub(rawStr, ",", ""))
    local numStr, suffix = string.match(clean, "([%d%.]+)%s*([km]?)")
    local n = tonumber(numStr)
    if not n then return nil end
    if suffix == "k" then n = n * 1000 end
    if suffix == "m" then n = n * 1000000 end
    return math.floor(n)
end

function Fn.detectPlayerStat(keywords, excludeKeywords)
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            local n = string.lower(v.Name)
            for _, kw in ipairs(keywords) do
                if string.find(n, kw, 1, true) then
                    local p = parseFormattedNumber(v.Value)
                    if p then return p end
                end
            end
        end
    end
    for attrName, attrVal in pairs(LocalPlayer:GetAttributes()) do
        local n = string.lower(attrName)
        for _, kw in ipairs(keywords) do
            if string.find(n, kw, 1, true) then
                local p = parseFormattedNumber(attrVal)
                if p then return p end
            end
        end
    end
    for _, desc in ipairs(LocalPlayer:GetDescendants()) do
        if desc:IsA("IntValue") or desc:IsA("NumberValue") or desc:IsA("StringValue") then
            local n = string.lower(desc.Name)
            for _, kw in ipairs(keywords) do
                if n == kw or string.find(n, kw, 1, true) then
                    local p = parseFormattedNumber(desc.Value)
                    if p then return p end
                end
            end
        end
    end
    for _, screen in ipairs(PlayerGui:GetChildren()) do
        if screen ~= UI.ScreenGui and screen:IsA("ScreenGui") and screen.Enabled then
            for _, desc in ipairs(screen:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Name ~= "KvaplPriceTag" and desc.Name ~= "KvaplMetaTag" and desc.Visible then
                    local path = string.lower(desc:GetFullName())
                    if not string.find(path, "trade") and not string.find(path, "shop")
                        and not string.find(path, "units") and not string.find(path, "inventory") then
                        local excluded = false
                        if excludeKeywords then
                            for _, bad in ipairs(excludeKeywords) do
                                if string.find(path, bad, 1, true) then excluded = true break end
                            end
                        end
                        if not excluded then
                            for _, kw in ipairs(keywords) do
                                if string.find(path, kw, 1, true) then
                                    local txt = desc.Text or ""
                                    if string.match(txt, "^%s*[%$]?[%d,%.]+%s*[kKmM]?%s*$") then
                                        local p = parseFormattedNumber(txt)
                                        if p then return p end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return 0
end

function Fn.findInventoryScrollingFrame()
    for _, screen in ipairs(PlayerGui:GetChildren()) do
        if screen ~= UI.ScreenGui and screen:IsA("ScreenGui") then
            for _, desc in ipairs(screen:GetDescendants()) do
                if desc:IsA("ScrollingFrame") and desc.Parent then
                    for _, sib in ipairs(desc.Parent:GetDescendants()) do
                        if sib:IsA("TextLabel") or sib:IsA("TextButton") then
                            local t = string.lower(sib.Text or "")
                            if string.find(t, "sell units", 1, true) or string.find(t, "unequip", 1, true) or string.match(t, "^%s*%d+%s+units") then
                                return desc
                            end
                        end
                    end
                end
            end
            for _, desc in ipairs(screen:GetDescendants()) do
                if desc:IsA("ScrollingFrame") then
                    local fn = string.lower(desc:GetFullName())
                    if (string.find(fn, "units") or string.find(fn, "inventory"))
                        and not string.find(fn, "trade") and not string.find(fn, "shop")
                        and not string.find(fn, "index") and not string.find(fn, "summon") then
                        return desc
                    end
                end
            end
        end
    end
    return nil
end

function Fn.classifyInventorySlotRarity(slot)
    if not slot:IsA("GuiObject") then return nil end
    if State.HoverSlotMap[slot] and UnitDatabase[State.HoverSlotMap[slot]] then
        return UnitDatabase[State.HoverSlotMap[slot]].rarity
    end
    for _, attrVal in pairs(slot:GetAttributes()) do
        if type(attrVal) == "string" then
            local lv = string.lower(attrVal)
            if lv == "legendary" then return "Legendary" end
            if lv == "mythic" or lv == "mythical" then return "Mythic" end
            if lv == "godly" then return "Godly" end
            if lv == "exclusive" then return "Exclusive" end
            local _, uData = Fn.findUnitData(attrVal)
            if uData and uData.rarity then return uData.rarity end
        end
    end
    local _, selfData = Fn.findUnitData(slot.Name)
    if selfData and selfData.rarity then return selfData.rarity end
    for _, desc in ipairs(slot:GetDescendants()) do
        if desc:IsA("StringValue") then
            local lv = string.lower(desc.Value)
            if lv == "legendary" then return "Legendary" end
            if lv == "mythic" or lv == "mythical" then return "Mythic" end
            if lv == "godly" then return "Godly" end
            if lv == "exclusive" then return "Exclusive" end
            local _, uData = Fn.findUnitData(desc.Value)
            if uData and uData.rarity then return uData.rarity end
        elseif desc:IsA("Model") or desc:IsA("GuiObject") then
            local _, uData = Fn.findUnitData(desc.Name)
            if uData and uData.rarity then return uData.rarity end
        end
    end
    for _, desc in ipairs(slot:GetDescendants()) do
        if desc:IsA("UIGradient") and #desc.Color.Keypoints >= 3 then return "Exclusive" end
    end
    local candidates = { slot }
    for _, d in ipairs(slot:GetDescendants()) do
        if d:IsA("Frame") or d:IsA("ImageLabel") or d:IsA("ImageButton") then table.insert(candidates, d) end
    end
    for _, elem in ipairs(candidates) do
        local col = elem:IsA("Frame") and elem.BackgroundColor3
            or ((elem:IsA("ImageLabel") or elem:IsA("ImageButton")) and elem.ImageColor3) or nil
        if col then
            local r, g, b = col.R * 255, col.G * 255, col.B * 255
            local isInvBlue = (r > 50 and r < 130 and g > 150 and b > 220)
            if not isInvBlue then
                if r >= 175 and g <= 60 and b <= 60 then return "Mythic" end
                if r >= 200 and g >= 170 and b <= 65 then return "Legendary" end
                if r >= 35 and r <= 145 and g <= 85 and b >= 130 then return "Godly" end
                if (r <= 60 and g >= 200 and b >= 200) or (r >= 220 and g >= 110 and g <= 165 and b <= 45) then return "Exclusive" end
            end
        end
    end
    return nil
end

function Fn.refreshProfileStats()
    if not State.IsProfileConnected then return end
    UI.DispNameVal.Text = LocalPlayer.DisplayName
    UI.UserNameVal.Text = "@" .. LocalPlayer.Name
    pcall(function()
        UI.AvatarImg.Image = S.Players:GetUserThumbnailAsync(
            LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150
        )
    end)
    UI.GemsStatVal.Text  = Fn.formatNumber(Fn.detectPlayerStat({ "gem", "diamond", "crystal" }, { "coin", "win" })) .. " 💎"
    UI.CoinsStatVal.Text = Fn.formatNumber(Fn.detectPlayerStat({ "coin", "money", "cash", "gold" }, { "gem", "win" })) .. " 🪙"
    UI.WinsStatVal.Text  = Fn.formatNumber(Fn.detectPlayerStat({ "win", "triumph", "victory" }, { "gem", "coin" })) .. " 🏆"

    local counts = { Legendary = 0, Mythic = 0, Godly = 0, Exclusive = 0 }
    local invScroll = Fn.findInventoryScrollingFrame()
    if invScroll then
        for _, slot in ipairs(invScroll:GetChildren()) do
            if slot:IsA("GuiObject") and slot.Visible and slot.AbsoluteSize.X > 30 then
                local rarity = Fn.classifyInventorySlotRarity(slot)
                if rarity and counts[rarity] ~= nil then counts[rarity] = counts[rarity] + 1 end
            end
        end
    end
    UI.LegStatVal.Text   = tostring(counts.Legendary) .. " \u{0448}\u{0442}."
    UI.MythStatVal.Text  = tostring(counts.Mythic) .. " \u{0448}\u{0442}."
    UI.GodlyStatVal.Text = tostring(counts.Godly) .. " \u{0448}\u{0442}."
    UI.ExclStatVal.Text  = tostring(counts.Exclusive) .. " \u{0448}\u{0442}."
end

UI.ConnectBtn.MouseButton1Click:Connect(function()
    State.IsProfileConnected = true
    UI.HomeNotice.Visible = false
    UI.ProfileContainer.Visible = true
    UI.ConnectBtn.Text = T("connectedBtn")
    UI.ConnectBtn.BackgroundColor3 = Colors.WinGreen
    Fn.refreshProfileStats()
end)

-- ============================================================================
-- TAB 1: TRADE CALCULATOR
-- ============================================================================
do
    UI.TradePage = Instance.new("Frame")
    UI.TradePage.Size = UDim2.new(1, -24, 1, -88)
    UI.TradePage.Position = UDim2.new(0, 12, 0, 48)
    UI.TradePage.BackgroundTransparency = 1
    UI.TradePage.Visible = false
    UI.TradePage.ZIndex = 8002
    UI.TradePage.Parent = UI.BodyFrame

    local ResultBanner = Instance.new("Frame")
    ResultBanner.Size = UDim2.new(1, 0, 0, 54)
    ResultBanner.BackgroundColor3 = Colors.BgSecondary
    ResultBanner.BorderSizePixel = 0
    ResultBanner.ZIndex = 8003
    ResultBanner.Parent = UI.TradePage
    Instance.new("UICorner", ResultBanner).CornerRadius = UDim.new(0, 10)

    UI.ResultStroke = Instance.new("UIStroke", ResultBanner)
    UI.ResultStroke.Color = Colors.FairYellow UI.ResultStroke.Thickness = 1.5

    UI.VerdictTitle = Instance.new("TextLabel")
    UI.VerdictTitle.Size = UDim2.new(1, -20, 0, 26)
    UI.VerdictTitle.Position = UDim2.new(0, 10, 0, 4)
    UI.VerdictTitle.BackgroundTransparency = 1
    UI.VerdictTitle.Text = T("waitTrade")
    UI.VerdictTitle.TextColor3 = Colors.FairYellow
    UI.VerdictTitle.Font = Enum.Font.GothamBold
    UI.VerdictTitle.TextSize = 15
    UI.VerdictTitle.ZIndex = 8004
    UI.VerdictTitle.Parent = ResultBanner

    UI.VerdictSub = Instance.new("TextLabel")
    UI.VerdictSub.Size = UDim2.new(1, -20, 0, 20)
    UI.VerdictSub.Position = UDim2.new(0, 10, 0, 30)
    UI.VerdictSub.BackgroundTransparency = 1
    UI.VerdictSub.Text = string.format(T("youGive"), "0 💎", "0 💎")
    UI.VerdictSub.TextColor3 = Colors.TextMuted
    UI.VerdictSub.Font = Enum.Font.GothamMedium
    UI.VerdictSub.TextSize = 12
    UI.VerdictSub.ZIndex = 8004
    UI.VerdictSub.Parent = ResultBanner

    local function mkOfferCol(titleText, posScaleX)
        local Col = Instance.new("Frame")
        Col.Size = UDim2.new(0.34, -6, 1, -60)
        Col.Position = UDim2.new(posScaleX, 0, 0, 60)
        Col.BackgroundColor3 = Colors.BgSecondary
        Col.BorderSizePixel = 0
        Col.ZIndex = 8003
        Col.Parent = UI.TradePage
        Instance.new("UICorner", Col).CornerRadius = UDim.new(0, 8)

        local ColHeader = Instance.new("TextLabel")
        ColHeader.Size = UDim2.new(1, -12, 0, 22)
        ColHeader.Position = UDim2.new(0, 8, 0, 4)
        ColHeader.BackgroundTransparency = 1
        ColHeader.Text = titleText
        ColHeader.TextColor3 = Colors.TextPrimary
        ColHeader.Font = Enum.Font.GothamBold
        ColHeader.TextSize = 12
        ColHeader.TextXAlignment = Enum.TextXAlignment.Left
        ColHeader.ZIndex = 8004
        ColHeader.Parent = Col

        local TotalLabel = Instance.new("TextLabel")
        TotalLabel.Size = UDim2.new(1, -12, 0, 18)
        TotalLabel.Position = UDim2.new(0, 8, 0, 24)
        TotalLabel.BackgroundTransparency = 1
        TotalLabel.Text = T("sumLabel") .. "0 💎"
        TotalLabel.TextColor3 = Colors.GemCyan
        TotalLabel.Font = Enum.Font.GothamBold
        TotalLabel.TextSize = 12
        TotalLabel.TextXAlignment = Enum.TextXAlignment.Left
        TotalLabel.ZIndex = 8004
        TotalLabel.Parent = Col

        local GemsInput = Instance.new("TextBox")
        GemsInput.Size = UDim2.new(0.65, -8, 0, 24)
        GemsInput.Position = UDim2.new(0, 8, 0, 44)
        GemsInput.BackgroundColor3 = Colors.BgCard
        GemsInput.PlaceholderText = "+ Gems (0)"
        GemsInput.Text = ""
        GemsInput.TextColor3 = Colors.TextPrimary
        GemsInput.PlaceholderColor3 = Colors.TextMuted
        GemsInput.Font = Enum.Font.Gotham
        GemsInput.TextSize = 11
        GemsInput.ClearTextOnFocus = false
        GemsInput.ZIndex = 8004
        GemsInput.Parent = Col
        Instance.new("UICorner", GemsInput).CornerRadius = UDim.new(0, 5)

        local ClearBtn = Instance.new("TextButton")
        ClearBtn.Size = UDim2.new(0.35, -8, 0, 24)
        ClearBtn.Position = UDim2.new(0.65, 2, 0, 44)
        ClearBtn.BackgroundColor3 = Colors.LoseRed
        ClearBtn.Text = T("clearBtn")
        ClearBtn.TextColor3 = Colors.TextPrimary
        ClearBtn.Font = Enum.Font.GothamBold
        ClearBtn.TextSize = 11
        ClearBtn.ZIndex = 8004
        ClearBtn.Parent = Col
        Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0, 5)

        local ItemScroll = Instance.new("ScrollingFrame")
        ItemScroll.Size = UDim2.new(1, -12, 1, -74)
        ItemScroll.Position = UDim2.new(0, 6, 0, 70)
        ItemScroll.BackgroundTransparency = 1
        ItemScroll.ScrollBarThickness = 4
        ItemScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        ItemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        ItemScroll.ZIndex = 8004
        ItemScroll.Parent = Col
        Instance.new("UIListLayout", ItemScroll).Padding = UDim.new(0, 4)

        return ColHeader, TotalLabel, GemsInput, ClearBtn, ItemScroll
    end

    UI.MyHeaderLbl, UI.MyTotalLabel, UI.MyGemsBox, UI.MyClearBtn, UI.MyScroll = mkOfferCol(T("myOffer"), 0)
    UI.PartnerHeaderLbl, UI.PartnerTotalLabel, UI.PartnerGemsBox, UI.PartnerClearBtn, UI.PartnerScroll = mkOfferCol(T("partnerOffer"), 0.345)

    local PickerCol = Instance.new("Frame")
    PickerCol.Size = UDim2.new(0.31, 0, 1, -60)
    PickerCol.Position = UDim2.new(0.69, 0, 0, 60)
    PickerCol.BackgroundColor3 = Colors.BgSecondary
    PickerCol.BorderSizePixel = 0
    PickerCol.ZIndex = 8003
    PickerCol.Parent = UI.TradePage
    Instance.new("UICorner", PickerCol).CornerRadius = UDim.new(0, 8)

    UI.PickerTitle = Instance.new("TextLabel")
    UI.PickerTitle.Size = UDim2.new(0.58, -6, 0, 22)
    UI.PickerTitle.Position = UDim2.new(0, 8, 0, 4)
    UI.PickerTitle.BackgroundTransparency = 1
    UI.PickerTitle.Text = T("addManual")
    UI.PickerTitle.TextColor3 = Colors.TextPrimary
    UI.PickerTitle.Font = Enum.Font.GothamBold
    UI.PickerTitle.TextSize = 11
    UI.PickerTitle.TextXAlignment = Enum.TextXAlignment.Left
    UI.PickerTitle.ZIndex = 8004
    UI.PickerTitle.Parent = PickerCol

    local SignModeBtn = Instance.new("TextButton")
    SignModeBtn.Size = UDim2.new(0.40, -6, 0, 20)
    SignModeBtn.Position = UDim2.new(0.60, 0, 0, 4)
    SignModeBtn.BackgroundColor3 = Colors.BgCard
    SignModeBtn.Text = "✍️ Sign: OFF"
    SignModeBtn.TextColor3 = Colors.TextMuted
    SignModeBtn.Font = Enum.Font.GothamBold
    SignModeBtn.TextSize = 10
    SignModeBtn.ZIndex = 8004
    SignModeBtn.Parent = PickerCol
    Instance.new("UICorner", SignModeBtn).CornerRadius = UDim.new(0, 5)

    SignModeBtn.MouseButton1Click:Connect(function()
        State.PickerSignedMode = not State.PickerSignedMode
        SignModeBtn.Text = State.PickerSignedMode and ("✍️ " .. State.PickerSignerName) or "✍️ Sign: OFF"
        SignModeBtn.BackgroundColor3 = State.PickerSignedMode and Colors.SignGold or Colors.BgCard
        SignModeBtn.TextColor3 = State.PickerSignedMode and Colors.BgPrimary or Colors.TextMuted
        Fn.populatePicker(UI.PickerSearch.Text)
    end)

    UI.PickerSearch = Instance.new("TextBox")
    UI.PickerSearch.Size = UDim2.new(1, -12, 0, 24)
    UI.PickerSearch.Position = UDim2.new(0, 6, 0, 28)
    UI.PickerSearch.BackgroundColor3 = Colors.BgCard
    UI.PickerSearch.PlaceholderText = "🔍 Search..."
    UI.PickerSearch.Text = ""
    UI.PickerSearch.TextColor3 = Colors.TextPrimary
    UI.PickerSearch.PlaceholderColor3 = Colors.TextMuted
    UI.PickerSearch.Font = Enum.Font.Gotham
    UI.PickerSearch.TextSize = 11
    UI.PickerSearch.ClearTextOnFocus = false
    UI.PickerSearch.ZIndex = 8004
    UI.PickerSearch.Parent = PickerCol
    Instance.new("UICorner", UI.PickerSearch).CornerRadius = UDim.new(0, 6)

    UI.PickerScroll = Instance.new("ScrollingFrame")
    UI.PickerScroll.Size = UDim2.new(1, -12, 1, -58)
    UI.PickerScroll.Position = UDim2.new(0, 6, 0, 54)
    UI.PickerScroll.BackgroundTransparency = 1
    UI.PickerScroll.ScrollBarThickness = 4
    UI.PickerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    UI.PickerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    UI.PickerScroll.ZIndex = 8004
    UI.PickerScroll.Parent = PickerCol
    Instance.new("UIListLayout", UI.PickerScroll).Padding = UDim.new(0, 4)
end

function Fn.recalculateTrade()
    local mySum = State.MyExtraGems
    for _, entry in ipairs(State.MyOffer) do
        local db = UnitDatabase[entry.name]
        local base = db and db.value or entry.value
        local price = entry.isSigned and select(1, Fn.computeSignedPrice(base, entry.signer)) or base
        entry.value = price
        mySum = mySum + (price * entry.count)
    end

    local partnerSum = State.PartnerExtraGems
    for _, entry in ipairs(State.PartnerOffer) do
        local db = UnitDatabase[entry.name]
        local base = db and db.value or entry.value
        local price = entry.isSigned and select(1, Fn.computeSignedPrice(base, entry.signer)) or base
        entry.value = price
        partnerSum = partnerSum + (price * entry.count)
    end

    UI.MyTotalLabel.Text = T("sumLabel") .. Fn.formatGems(mySum)
    UI.PartnerTotalLabel.Text = T("sumLabel") .. Fn.formatGems(partnerSum)

    local diff = partnerSum - mySum
    State.LastTradeDiff = diff
    local subFormatted = string.format(T("youGive"), Fn.formatGems(mySum), Fn.formatGems(partnerSum))
    UI.VerdictSub.Text = subFormatted
    UI.HudSub.Text = subFormatted

    if mySum == 0 and partnerSum == 0 then
        UI.VerdictTitle.Text = T("waitTrade")
        UI.VerdictTitle.TextColor3 = Colors.TextMuted
        UI.ResultStroke.Color = Colors.Accent
        UI.HudTitle.Text = T("waitTrade")
        UI.HudTitle.TextColor3 = Colors.FairYellow
        UI.HudStroke.Color = Colors.Accent
    elseif diff > 0 then
        local winText = string.format(T("winTrade"), Fn.formatGems(diff))
        UI.VerdictTitle.Text = winText
        UI.VerdictTitle.TextColor3 = Colors.WinGreen
        UI.ResultStroke.Color = Colors.WinGreen
        UI.HudTitle.Text = winText
        UI.HudTitle.TextColor3 = Colors.WinGreen
        UI.HudStroke.Color = Colors.WinGreen
    elseif diff < 0 then
        local loseText = string.format(T("loseTrade"), Fn.formatGems(diff))
        UI.VerdictTitle.Text = loseText
        UI.VerdictTitle.TextColor3 = Colors.LoseRed
        UI.ResultStroke.Color = Colors.LoseRed
        UI.HudTitle.Text = loseText
        UI.HudTitle.TextColor3 = Colors.LoseRed
        UI.HudStroke.Color = Colors.LoseRed
    else
        local fairText = T("fairTrade")
        UI.VerdictTitle.Text = fairText
        UI.VerdictTitle.TextColor3 = Colors.FairYellow
        UI.ResultStroke.Color = Colors.FairYellow
        UI.HudTitle.Text = fairText
        UI.HudTitle.TextColor3 = Colors.FairYellow
        UI.HudStroke.Color = Colors.FairYellow
    end
end

function Fn.renderOfferList(offerTable, scrollFrame)
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for idx, item in ipairs(offerTable) do
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -4, 0, 30)
        Row.BackgroundColor3 = Colors.BgCard
        Row.BorderSizePixel = 0
        Row.LayoutOrder = idx
        Row.ZIndex = 8005
        Row.Parent = scrollFrame
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)

        local signTag = item.isSigned and (" [" .. (item.signer or "SIGN") .. "]") or ""
        local NameText = Instance.new("TextLabel")
        NameText.Size = UDim2.new(0.58, -6, 1, 0)
        NameText.Position = UDim2.new(0, 6, 0, 0)
        NameText.BackgroundTransparency = 1
        NameText.Text = string.format("%s%s (x%d)", item.name, signTag, item.count)
        NameText.TextColor3 = item.isSigned and Colors.SignGold or Colors.TextPrimary
        NameText.Font = Enum.Font.GothamMedium
        NameText.TextSize = 11
        NameText.TextTruncate = Enum.TextTruncate.AtEnd
        NameText.TextXAlignment = Enum.TextXAlignment.Left
        NameText.ZIndex = 8006
        NameText.Parent = Row

        local PriceText = Instance.new("TextLabel")
        PriceText.Size = UDim2.new(0.30, 0, 1, 0)
        PriceText.Position = UDim2.new(0.58, 0, 0, 0)
        PriceText.BackgroundTransparency = 1
        PriceText.Text = Fn.formatGems(item.value * item.count)
        PriceText.TextColor3 = Colors.GemCyan
        PriceText.Font = Enum.Font.GothamBold
        PriceText.TextSize = 11
        PriceText.TextXAlignment = Enum.TextXAlignment.Right
        PriceText.ZIndex = 8006
        PriceText.Parent = Row

        local RemoveBtn = Instance.new("TextButton")
        RemoveBtn.Size = UDim2.new(0, 20, 0, 20)
        RemoveBtn.Position = UDim2.new(1, -24, 0.5, -10)
        RemoveBtn.BackgroundColor3 = Colors.LoseRed
        RemoveBtn.Text = "−"
        RemoveBtn.TextColor3 = Colors.TextPrimary
        RemoveBtn.Font = Enum.Font.GothamBold
        RemoveBtn.TextSize = 13
        RemoveBtn.ZIndex = 8006
        RemoveBtn.Parent = Row
        Instance.new("UICorner", RemoveBtn).CornerRadius = UDim.new(0, 4)

        RemoveBtn.MouseButton1Click:Connect(function()
            if item.count > 1 then item.count = item.count - 1 else table.remove(offerTable, idx) end
            Fn.renderOfferList(offerTable, scrollFrame)
            Fn.recalculateTrade()
        end)
    end
end

function Fn.addUnitToOffer(offerTable, scrollFrame, unitName, unitValue, qty, isSigned, signer)
    local amount = qty or 1
    for _, existing in ipairs(offerTable) do
        if existing.name == unitName and existing.isSigned == (isSigned == true) and existing.signer == signer then
            existing.count = existing.count + amount
            Fn.renderOfferList(offerTable, scrollFrame)
            Fn.recalculateTrade()
            return
        end
    end
    table.insert(offerTable, {
        name = unitName, value = unitValue, count = amount,
        isSigned = (isSigned == true), signer = signer
    })
    Fn.renderOfferList(offerTable, scrollFrame)
    Fn.recalculateTrade()
end

function Fn.populatePicker(filterText)
    for _, child in ipairs(UI.PickerScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local query = string.lower(filterText or "")
    for idx, item in ipairs(SortedItems) do
        if query == "" or string.find(string.lower(item.name), query, 1, true) then
            local Card = Instance.new("Frame")
            Card.Size = UDim2.new(1, -4, 0, 36)
            Card.BackgroundColor3 = Colors.BgCard
            Card.BorderSizePixel = 0
            Card.LayoutOrder = idx
            Card.ZIndex = 8005
            Card.Parent = UI.PickerScroll
            Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

            local activeVal = State.PickerSignedMode
                and select(1, Fn.computeSignedPrice(item.value, State.PickerSignerName))
                or item.value

            local UName = Instance.new("TextLabel")
            UName.Size = UDim2.new(1, -84, 0, 18)
            UName.Position = UDim2.new(0, 6, 0, 2)
            UName.BackgroundTransparency = 1
            UName.Text = State.PickerSignedMode and ("[S] " .. item.name) or item.name
            UName.TextColor3 = State.PickerSignedMode and Colors.SignGold or Colors.TextPrimary
            UName.Font = Enum.Font.GothamBold
            UName.TextSize = 11
            UName.TextTruncate = Enum.TextTruncate.AtEnd
            UName.TextXAlignment = Enum.TextXAlignment.Left
            UName.ZIndex = 8006
            UName.Parent = Card

            local UVal = Instance.new("TextLabel")
            UVal.Size = UDim2.new(1, -84, 0, 15)
            UVal.Position = UDim2.new(0, 6, 0, 19)
            UVal.BackgroundTransparency = 1
            UVal.Text = activeVal > 0 and Fn.formatGems(activeVal) or "N/A (0 💎)"
            UVal.TextColor3 = Colors.GemCyan
            UVal.Font = Enum.Font.Gotham
            UVal.TextSize = 10
            UVal.TextXAlignment = Enum.TextXAlignment.Left
            UVal.ZIndex = 8006
            UVal.Parent = Card

            local AddMyBtn = Instance.new("TextButton")
            AddMyBtn.Size = UDim2.new(0, 35, 0, 24)
            AddMyBtn.Position = UDim2.new(1, -76, 0.5, -12)
            AddMyBtn.BackgroundColor3 = Colors.Accent
            AddMyBtn.Text = "+\u{042F}"
            AddMyBtn.TextColor3 = Colors.TextPrimary
            AddMyBtn.Font = Enum.Font.GothamBold
            AddMyBtn.TextSize = 10
            AddMyBtn.ZIndex = 8006
            AddMyBtn.Parent = Card
            Instance.new("UICorner", AddMyBtn).CornerRadius = UDim.new(0, 5)

            local AddPartnerBtn = Instance.new("TextButton")
            AddPartnerBtn.Size = UDim2.new(0, 35, 0, 24)
            AddPartnerBtn.Position = UDim2.new(1, -38, 0.5, -12)
            AddPartnerBtn.BackgroundColor3 = Colors.WinGreen
            AddPartnerBtn.Text = "+\u{041C}\u{043D}\u{0435}"
            AddPartnerBtn.TextColor3 = Colors.TextPrimary
            AddPartnerBtn.Font = Enum.Font.GothamBold
            AddPartnerBtn.TextSize = 10
            AddPartnerBtn.ZIndex = 8006
            AddPartnerBtn.Parent = Card
            Instance.new("UICorner", AddPartnerBtn).CornerRadius = UDim.new(0, 5)

            AddMyBtn.MouseButton1Click:Connect(function()
                Fn.addUnitToOffer(State.MyOffer, UI.MyScroll, item.name, activeVal, 1, State.PickerSignedMode, State.PickerSignerName)
            end)
            AddPartnerBtn.MouseButton1Click:Connect(function()
                Fn.addUnitToOffer(State.PartnerOffer, UI.PartnerScroll, item.name, activeVal, 1, State.PickerSignedMode, State.PickerSignerName)
            end)
        end
    end
end

Fn.populatePicker("")
UI.PickerSearch:GetPropertyChangedSignal("Text"):Connect(function() Fn.populatePicker(UI.PickerSearch.Text) end)
UI.MyGemsBox:GetPropertyChangedSignal("Text"):Connect(function() State.MyExtraGems = tonumber(UI.MyGemsBox.Text) or 0 Fn.recalculateTrade() end)
UI.PartnerGemsBox:GetPropertyChangedSignal("Text"):Connect(function() State.PartnerExtraGems = tonumber(UI.PartnerGemsBox.Text) or 0 Fn.recalculateTrade() end)
UI.MyClearBtn.MouseButton1Click:Connect(function()
    table.clear(State.MyOffer) UI.MyGemsBox.Text = "" State.MyExtraGems = 0
    Fn.renderOfferList(State.MyOffer, UI.MyScroll) Fn.recalculateTrade()
end)
UI.PartnerClearBtn.MouseButton1Click:Connect(function()
    table.clear(State.PartnerOffer) UI.PartnerGemsBox.Text = "" State.PartnerExtraGems = 0
    Fn.renderOfferList(State.PartnerOffer, UI.PartnerScroll) Fn.recalculateTrade()
end)

-- ============================================================================
-- TAB 2: PRICE LIST
-- ============================================================================
do
    UI.ValuesPage = Instance.new("Frame")
    UI.ValuesPage.Size = UDim2.new(1, -24, 1, -88)
    UI.ValuesPage.Position = UDim2.new(0, 12, 0, 48)
    UI.ValuesPage.BackgroundTransparency = 1
    UI.ValuesPage.Visible = false
    UI.ValuesPage.ZIndex = 8002
    UI.ValuesPage.Parent = UI.BodyFrame

    UI.CatalogSearch = Instance.new("TextBox")
    UI.CatalogSearch.Size = UDim2.new(1, 0, 0, 30)
    UI.CatalogSearch.BackgroundColor3 = Colors.BgSecondary
    UI.CatalogSearch.PlaceholderText = "🔎 \u{041F}\u{043E}\u{0438}\u{0441}\u{043A} \u{044E}\u{043D}\u{0438}\u{0442}\u{0430} (\u{0426}\u{0435}\u{043D}\u{0430} | \u{0421}\u{043F}\u{0440}\u{043E}\u{0441} | \u{0421}\u{0442}\u{0430}\u{0431}\u{0438}\u{043B}\u{044C}\u{043D}\u{043E}\u{0441}\u{0442}\u{044C} | \u{0420}\u{0435}\u{0434}\u{0430}\u{043A}\u{0442}\u{043E}\u{0440} \u{0446}\u{0435}\u{043D}\u{044B})..."
    UI.CatalogSearch.Text = ""
    UI.CatalogSearch.TextColor3 = Colors.TextPrimary
    UI.CatalogSearch.PlaceholderColor3 = Colors.TextMuted
    UI.CatalogSearch.Font = Enum.Font.GothamMedium
    UI.CatalogSearch.TextSize = 12
    UI.CatalogSearch.ClearTextOnFocus = false
    UI.CatalogSearch.ZIndex = 8003
    UI.CatalogSearch.Parent = UI.ValuesPage
    Instance.new("UICorner", UI.CatalogSearch).CornerRadius = UDim.new(0, 8)

    UI.CatalogScroll = Instance.new("ScrollingFrame")
    UI.CatalogScroll.Size = UDim2.new(1, 0, 1, -36)
    UI.CatalogScroll.Position = UDim2.new(0, 0, 0, 36)
    UI.CatalogScroll.BackgroundColor3 = Colors.BgSecondary
    UI.CatalogScroll.BorderSizePixel = 0
    UI.CatalogScroll.ScrollBarThickness = 5
    UI.CatalogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    UI.CatalogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    UI.CatalogScroll.ZIndex = 8003
    UI.CatalogScroll.Parent = UI.ValuesPage
    Instance.new("UICorner", UI.CatalogScroll).CornerRadius = UDim.new(0, 8)
    Instance.new("UIListLayout", UI.CatalogScroll).Padding = UDim.new(0, 4)
end

function Fn.populateCatalog(filterText)
    for _, child in ipairs(UI.CatalogScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local query = string.lower(filterText or "")
    for idx, item in ipairs(SortedItems) do
        if query == "" or string.find(string.lower(item.name), query, 1, true) then
            local Row = Instance.new("Frame")
            Row.Size = UDim2.new(1, -12, 0, 34)
            Row.Position = UDim2.new(0, 6, 0, 0)
            Row.BackgroundColor3 = Colors.BgCard
            Row.BorderSizePixel = 0
            Row.LayoutOrder = idx
            Row.ZIndex = 8004
            Row.Parent = UI.CatalogScroll
            Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)

            local NameLbl = Instance.new("TextLabel")
            NameLbl.Size = UDim2.new(0.38, -10, 1, 0)
            NameLbl.Position = UDim2.new(0, 10, 0, 0)
            NameLbl.BackgroundTransparency = 1
            NameLbl.Text = string.format("[%s] %s", item.rarity or item.category, item.name)
            NameLbl.TextColor3 = Colors.TextPrimary
            NameLbl.Font = Enum.Font.GothamBold
            NameLbl.TextSize = 11
            NameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            NameLbl.TextXAlignment = Enum.TextXAlignment.Left
            NameLbl.ZIndex = 8005
            NameLbl.Parent = Row

            local ValLbl = Instance.new("TextLabel")
            ValLbl.Size = UDim2.new(0.18, 0, 1, 0)
            ValLbl.Position = UDim2.new(0.38, 0, 0, 0)
            ValLbl.BackgroundTransparency = 1
            ValLbl.Text = item.value > 0 and Fn.formatGems(item.value) or "N/A (0 💎)"
            ValLbl.TextColor3 = Colors.GemCyan
            ValLbl.Font = Enum.Font.GothamBold
            ValLbl.TextSize = 11
            ValLbl.TextXAlignment = Enum.TextXAlignment.Left
            ValLbl.ZIndex = 8005
            ValLbl.Parent = Row

            local MetaLbl = Instance.new("TextLabel")
            MetaLbl.Size = UDim2.new(0.28, 0, 1, 0)
            MetaLbl.Position = UDim2.new(0.56, 0, 0, 0)
            MetaLbl.BackgroundTransparency = 1
            MetaLbl.Text = string.format("%s | %s", item.demand, item.trend)
            MetaLbl.TextColor3 = Colors.TextMuted
            MetaLbl.Font = Enum.Font.GothamMedium
            MetaLbl.TextSize = 11
            MetaLbl.TextXAlignment = Enum.TextXAlignment.Left
            MetaLbl.ZIndex = 8005
            MetaLbl.Parent = Row

            local EditPriceBox = Instance.new("TextBox")
            EditPriceBox.Size = UDim2.new(0.15, -8, 0, 24)
            EditPriceBox.Position = UDim2.new(0.85, 0, 0.5, -12)
            EditPriceBox.BackgroundColor3 = Colors.BgSecondary
            EditPriceBox.Text = tostring(item.value)
            EditPriceBox.PlaceholderText = "\u{0426}\u{0435}\u{043D}\u{0430}"
            EditPriceBox.TextColor3 = Colors.GemCyan
            EditPriceBox.Font = Enum.Font.GothamBold
            EditPriceBox.TextSize = 11
            EditPriceBox.ClearTextOnFocus = false
            EditPriceBox.ZIndex = 8006
            EditPriceBox.Parent = Row
            Instance.new("UICorner", EditPriceBox).CornerRadius = UDim.new(0, 5)

            EditPriceBox.FocusLost:Connect(function()
                local newVal = tonumber(EditPriceBox.Text)
                if newVal and newVal >= 0 then
                    UnitDatabase[item.name].value = newVal
                    Config.CustomPrices[item.name] = newVal
                    item.value = newVal
                    ValLbl.Text = item.value > 0 and Fn.formatGems(item.value) or "N/A (0 💎)"
                    table.clear(State.PriceBadgeCache)
                    Fn.populatePicker(UI.PickerSearch.Text)
                    Fn.recalculateTrade()
                else
                    EditPriceBox.Text = tostring(item.value)
                end
            end)
        end
    end
end

Fn.populateCatalog("")
UI.CatalogSearch:GetPropertyChangedSignal("Text"):Connect(function() Fn.populateCatalog(UI.CatalogSearch.Text) end)

-- ============================================================================
-- TAB 3: SETTINGS
-- ============================================================================
function Fn.optimizePart(obj)
    local skyModel = S.Workspace:FindFirstChild("KvaplCameraSkybox")
    if obj:IsA("BasePart") and (not skyModel or not obj:IsDescendantOf(skyModel)) then
        if not State.SavedMaterials[obj] then
            State.SavedMaterials[obj] = { Material = obj.Material, Reflectance = obj.Reflectance, CastShadow = obj.CastShadow }
        end
        obj.Material = Enum.Material.SmoothPlastic
        obj.Reflectance = 0
        obj.CastShadow = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        if not State.SavedMaterials[obj] then State.SavedMaterials[obj] = { Transparency = obj.Transparency } end
        obj.Transparency = 1
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        if not State.SavedMaterials[obj] then State.SavedMaterials[obj] = { Enabled = obj.Enabled } end
        obj.Enabled = false
    end
end

function Fn.applyGameOptimization(enable)
    Config.GameOptimization = enable
    if enable then
        pcall(function()
            S.Lighting.GlobalShadows = false
            S.Lighting.FogEnd = 9e9
            for _, eff in ipairs(S.Lighting:GetChildren()) do
                if eff:IsA("PostEffect") then eff.Enabled = false end
            end
        end)
        for _, obj in ipairs(S.Workspace:GetDescendants()) do pcall(Fn.optimizePart, obj) end
        if not State.DescendantConn then
            State.DescendantConn = S.Workspace.DescendantAdded:Connect(function(newObj)
                if Config.GameOptimization then pcall(Fn.optimizePart, newObj) end
            end)
        end
    else
        if State.DescendantConn then State.DescendantConn:Disconnect() State.DescendantConn = nil end
        pcall(function() S.Lighting.GlobalShadows = true end)
        for obj, props in pairs(State.SavedMaterials) do
            if obj and obj.Parent then pcall(function() for k, v in pairs(props) do obj[k] = v end end) end
        end
        table.clear(State.SavedMaterials)
    end
end

function Fn.applyScriptOptimization(enable)
    Config.ScriptOptimization = enable
    Config.ScanInterval = enable and 1.3 or 0.5
    UI.MainStroke.Enabled = not enable
    UI.HudStroke.Thickness = enable and 1 or 2
end

function Fn.buildCameraSkyboxDome(assetTexture)
    if State.SkyboxRenderConn then State.SkyboxRenderConn:Disconnect() State.SkyboxRenderConn = nil end
    if State.SkyboxDomeModel then State.SkyboxDomeModel:Destroy() State.SkyboxDomeModel = nil end

    local Dome = Instance.new("Model")
    Dome.Name = "KvaplCameraSkybox"
    Dome.Parent = S.Workspace

    local dist = 900
    local wallConfigs = {
        { cf = CFrame.new(0, 0, -dist), size = Vector3.new(1802, 1802, 1), face = Enum.NormalId.Back },
        { cf = CFrame.new(0, 0, dist),  size = Vector3.new(1802, 1802, 1), face = Enum.NormalId.Front },
        { cf = CFrame.new(-dist, 0, 0), size = Vector3.new(1, 1802, 1802), face = Enum.NormalId.Right },
        { cf = CFrame.new(dist, 0, 0),  size = Vector3.new(1, 1802, 1802), face = Enum.NormalId.Left },
        { cf = CFrame.new(0, dist, 0),  size = Vector3.new(1802, 1, 1802), face = Enum.NormalId.Bottom },
        { cf = CFrame.new(0, -dist, 0), size = Vector3.new(1802, 1, 1802), face = Enum.NormalId.Top },
    }
    local walls = {}
    for idx, wc in ipairs(wallConfigs) do
        local w = Instance.new("Part")
        w.Name = "SkyWall_" .. idx
        w.Size = wc.size w.Anchored = true w.CanCollide = false w.CanQuery = false w.CanTouch = false
        w.CastShadow = false w.Transparency = 1 w.Parent = Dome

        local sgui = Instance.new("SurfaceGui", w)
        sgui.Face = wc.face sgui.LightInfluence = 0 sgui.Brightness = 1
        sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud sgui.PixelsPerStud = 1

        local img = Instance.new("ImageLabel", sgui)
        img.Size = UDim2.new(1, 0, 1, 0) img.BackgroundTransparency = 1
        img.Image = assetTexture img.ScaleType = Enum.ScaleType.Stretch
        table.insert(walls, { part = w, offset = wc.cf })
    end

    State.SkyboxDomeModel = Dome
    State.SkyboxRenderConn = S.RunService.RenderStepped:Connect(function()
        local cam = S.Workspace.CurrentCamera
        if cam and State.SkyboxDomeModel and State.SkyboxDomeModel.Parent then
            local camPos = CFrame.new(cam.CFrame.Position)
            for _, wEntry in ipairs(walls) do wEntry.part.CFrame = camPos * wEntry.offset end
        end
    end)
    Fn.trackConn(State.SkyboxRenderConn)
end

function Fn.resolveLocalPCImage(userInput)
    local customAssetFn = (typeof(getcustomasset) == "function" and getcustomasset)
        or (typeof(getsynasset) == "function" and getsynasset)
    if not customAssetFn then
        return nil, "\u{0412}\u{0430}\u{0448} \u{0438}\u{043D}\u{0436}\u{0435}\u{043A}\u{0442}\u{043E}\u{0440} \u{043D}\u{0435} \u{043F}\u{043E}\u{0434}\u{0434}\u{0435}\u{0440}\u{0436}\u{0438}\u{0432}\u{0430}\u{0435}\u{0442} getcustomasset (\u{0438}\u{0441}\u{043F}\u{043E}\u{043B}\u{044C}\u{0437}\u{0443}\u{0439}\u{0442}\u{0435} ID)"
    end

    local cleanInput = string.gsub(userInput or "", '^%s*"?(.-)"?%s*$', "%1")
    if string.match(string.lower(cleanInput), "^https?://") and typeof(writefile) == "function" then
        local okHttp, imgBytes = pcall(function() return game:HttpGet(cleanInput) end)
        if okHttp and imgBytes and #imgBytes > 64 then
            local tempFile = "kvapl_custom_sky.png"
            pcall(writefile, tempFile, imgBytes)
            local okAsset, assetId = pcall(customAssetFn, tempFile)
            if okAsset and assetId then return assetId, "✅ \u{0421}\u{043A}\u{0430}\u{0447}\u{0430}\u{043D}\u{043E} \u{043F}\u{043E} \u{0441}\u{0441}\u{044B}\u{043B}\u{043A}\u{0435} \u{0438} \u{043F}\u{0440}\u{0438}\u{043C}\u{0435}\u{043D}\u{0435}\u{043D}\u{043E} (" .. tempFile .. ")" end
        end
    end

    local fileNameOnly = string.match(cleanInput, "([^/\\]+)$") or cleanInput
    local candidates = {}
    if cleanInput ~= "" then
        table.insert(candidates, cleanInput)
        if fileNameOnly ~= cleanInput then table.insert(candidates, fileNameOnly) end
        if not string.find(fileNameOnly, "%.") then
            table.insert(candidates, fileNameOnly .. ".png")
            table.insert(candidates, fileNameOnly .. ".jpg")
            table.insert(candidates, fileNameOnly .. ".jpeg")
        end
    end
    if typeof(listfiles) == "function" then
        pcall(function()
            for _, fPath in ipairs(listfiles("")) do
                local lowerF = string.lower(fPath)
                if string.match(lowerF, "%.png$") or string.match(lowerF, "%.jpg$")
                    or string.match(lowerF, "%.jpeg$") or string.match(lowerF, "%.webp$") then
                    table.insert(candidates, fPath)
                    local shortF = string.match(fPath, "([^/\\]+)$")
                    if shortF then table.insert(candidates, shortF) end
                end
            end
        end)
    end

    for _, candidate in ipairs(candidates) do
        local exists = true
        if typeof(isfile) == "function" then
            local okCheck, res = pcall(isfile, candidate)
            if okCheck then exists = res end
        end
        if exists then
            local okAsset, assetUrl = pcall(customAssetFn, candidate)
            if okAsset and assetUrl and assetUrl ~= "" then
                return assetUrl, "✅ \u{0417}\u{0430}\u{0433}\u{0440}\u{0443}\u{0436}\u{0435}\u{043D} \u{0444}\u{0430}\u{0439}\u{043B} \u{0441} \u{041F}\u{041A}: " .. tostring(candidate)
            end
        end
    end
    return nil, "⚠️ \u{0424}\u{0430}\u{0439}\u{043B} \u{043D}\u{0435} \u{043D}\u{0430}\u{0439}\u{0434}\u{0435}\u{043D}! \u{041F}\u{043E}\u{043B}\u{043E}\u{0436}\u{0438}\u{0442}\u{0435} .png/.jpg \u{0432} \u{043F}\u{0430}\u{043F}\u{043A}\u{0443} workspace \u{0438}\u{043D}\u{0436}\u{0435}\u{043A}\u{0442}\u{043E}\u{0440}\u{0430} \u{0438}\u{043B}\u{0438} \u{0432}\u{0441}\u{0442}\u{0430}\u{0432}\u{044C}\u{0442}\u{0435} https-\u{0441}\u{0441}\u{044B}\u{043B}\u{043A}\u{0443}"
end

function Fn.applySkyboxAsset(finalAsset, use3DDome)
    pcall(function()
        for _, child in ipairs(S.Lighting:GetChildren()) do
            if child:IsA("Atmosphere") then
                if not State.SavedAtmospheres[child] then
                    State.SavedAtmospheres[child] = { Density = child.Density, Haze = child.Haze, Glare = child.Glare }
                end
                child.Density = 0 child.Haze = 0 child.Glare = 0
            end
        end
        local clouds = S.Workspace.Terrain and S.Workspace.Terrain:FindFirstChildOfClass("Clouds")
        if clouds then
            if not State.SavedAtmospheres[clouds] then State.SavedAtmospheres[clouds] = { Enabled = clouds.Enabled } end
            clouds.Enabled = false
        end
        local sky = S.Lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky") sky.Name = "KvaplCustomSky" sky.Parent = S.Lighting
        elseif not State.OriginalSkybox then
            State.OriginalSkybox = {
                Bk = sky.SkyboxBk, Dn = sky.SkyboxDn, Ft = sky.SkyboxFt,
                Lf = sky.SkyboxLf, Rt = sky.SkyboxRt, Up = sky.SkyboxUp,
            }
        end
        sky.SkyboxBk = finalAsset sky.SkyboxDn = finalAsset sky.SkyboxFt = finalAsset
        sky.SkyboxLf = finalAsset sky.SkyboxRt = finalAsset sky.SkyboxUp = finalAsset
    end)
    if use3DDome then Fn.buildCameraSkyboxDome(finalAsset) end
end

function Fn.resetSkybox()
    Config.SkyboxInput = ""
    if State.SkyboxRenderConn then State.SkyboxRenderConn:Disconnect() State.SkyboxRenderConn = nil end
    if State.SkyboxDomeModel then State.SkyboxDomeModel:Destroy() State.SkyboxDomeModel = nil end
    for obj, props in pairs(State.SavedAtmospheres) do
        if obj and obj.Parent then pcall(function() for k, v in pairs(props) do obj[k] = v end end) end
    end
    table.clear(State.SavedAtmospheres)
    pcall(function()
        local sky = S.Lighting:FindFirstChildOfClass("Sky")
        if sky then
            if State.OriginalSkybox then
                sky.SkyboxBk = State.OriginalSkybox.Bk sky.SkyboxDn = State.OriginalSkybox.Dn
                sky.SkyboxFt = State.OriginalSkybox.Ft sky.SkyboxLf = State.OriginalSkybox.Lf
                sky.SkyboxRt = State.OriginalSkybox.Rt sky.SkyboxUp = State.OriginalSkybox.Up
            elseif sky.Name == "KvaplCustomSky" then
                sky:Destroy()
            end
        end
    end)
end

function Fn.setupAutoExecute(enable)
    Config.AutoExecute = enable
    if enable and not State.TeleportHooked then
        State.TeleportHooked = true
        Fn.trackConn(LocalPlayer.OnTeleport:Connect(function()
            if Config.AutoExecute then
                local qFunc = (typeof(queue_on_teleport) == "function" and queue_on_teleport)
                    or (typeof(syn) == "table" and typeof(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
                    or (typeof(fluxus) == "table" and typeof(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)
                if qFunc then
                    pcall(function()
                        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("KvaplScript.lua") then
                            qFunc(readfile("KvaplScript.lua"))
                        end
                    end)
                end
            end
        end))
    end
end

do
    UI.SettingsPage = Instance.new("ScrollingFrame")
    UI.SettingsPage.Size = UDim2.new(1, -24, 1, -88)
    UI.SettingsPage.Position = UDim2.new(0, 12, 0, 48)
    UI.SettingsPage.BackgroundColor3 = Colors.BgSecondary
    UI.SettingsPage.BorderSizePixel = 0
    UI.SettingsPage.ScrollBarThickness = 5
    UI.SettingsPage.CanvasSize = UDim2.new(0, 0, 0, 0)
    UI.SettingsPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
    UI.SettingsPage.Visible = false
    UI.SettingsPage.ZIndex = 8002
    UI.SettingsPage.Parent = UI.BodyFrame
    Instance.new("UICorner", UI.SettingsPage).CornerRadius = UDim.new(0, 8)
    local sl = Instance.new("UIListLayout", UI.SettingsPage)
    sl.Padding = UDim.new(0, 8) sl.SortOrder = Enum.SortOrder.LayoutOrder
    local sp = Instance.new("UIPadding", UI.SettingsPage)
    sp.PaddingTop = UDim.new(0, 10) sp.PaddingBottom = UDim.new(0, 12)
    sp.PaddingLeft = UDim.new(0, 10) sp.PaddingRight = UDim.new(0, 10)

    local LangCard = Instance.new("Frame")
    LangCard.Size = UDim2.new(1, 0, 0, 60)
    LangCard.BackgroundColor3 = Colors.BgCard
    LangCard.BorderSizePixel = 0
    LangCard.LayoutOrder = 1
    LangCard.ZIndex = 8003
    LangCard.Parent = UI.SettingsPage
    Instance.new("UICorner", LangCard).CornerRadius = UDim.new(0, 8)

    UI.LangTitleLbl = Instance.new("TextLabel")
    UI.LangTitleLbl.Size = UDim2.new(0.55, -12, 0, 22)
    UI.LangTitleLbl.Position = UDim2.new(0, 12, 0, 6)
    UI.LangTitleLbl.BackgroundTransparency = 1
    UI.LangTitleLbl.Text = T("langTitle")
    UI.LangTitleLbl.TextColor3 = Colors.TextPrimary
    UI.LangTitleLbl.Font = Enum.Font.GothamBold
    UI.LangTitleLbl.TextSize = 13
    UI.LangTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    UI.LangTitleLbl.ZIndex = 8004
    UI.LangTitleLbl.Parent = LangCard

    UI.LangDescLbl = Instance.new("TextLabel")
    UI.LangDescLbl.Size = UDim2.new(0.55, -12, 0, 20)
    UI.LangDescLbl.Position = UDim2.new(0, 12, 0, 30)
    UI.LangDescLbl.BackgroundTransparency = 1
    UI.LangDescLbl.Text = T("langDesc")
    UI.LangDescLbl.TextColor3 = Colors.TextMuted
    UI.LangDescLbl.Font = Enum.Font.Gotham
    UI.LangDescLbl.TextSize = 11
    UI.LangDescLbl.TextXAlignment = Enum.TextXAlignment.Left
    UI.LangDescLbl.ZIndex = 8004
    UI.LangDescLbl.Parent = LangCard

    local function mkLangBtn(code, lbl, offR)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0, 86, 0, 32)
        Btn.Position = UDim2.new(1, offR, 0.5, -16)
        Btn.BackgroundColor3 = (Config.Language == code) and Colors.Accent or Colors.BgSecondary
        Btn.Text = lbl
        Btn.TextColor3 = Colors.TextPrimary
        Btn.Font = Enum.Font.GothamBold
        Btn.TextSize = 11
        Btn.ZIndex = 8004
        Btn.Parent = LangCard
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
        return Btn
    end
    UI.LangBtnEn = mkLangBtn("English", "🇬🇧 English", -282)
    UI.LangBtnUa = mkLangBtn("Ukraine", "🇺🇦 Ukraine", -190)
    UI.LangBtnRu = mkLangBtn("Ru",      "🇷🇺 Ru",      -98)

    local function mkToggle(order, titleKey, descKey, configKey, onToggle)
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, 0, 0, 56)
        Card.BackgroundColor3 = Colors.BgCard
        Card.BorderSizePixel = 0
        Card.LayoutOrder = order
        Card.ZIndex = 8003
        Card.Parent = UI.SettingsPage
        Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 8)

        local TL = Instance.new("TextLabel")
        TL.Size = UDim2.new(1, -140, 0, 22)
        TL.Position = UDim2.new(0, 12, 0, 6)
        TL.BackgroundTransparency = 1
        TL.Text = T(titleKey)
        TL.TextColor3 = Colors.TextPrimary
        TL.Font = Enum.Font.GothamBold
        TL.TextSize = 13
        TL.TextXAlignment = Enum.TextXAlignment.Left
        TL.ZIndex = 8004
        TL.Parent = Card

        local DL = Instance.new("TextLabel")
        DL.Size = UDim2.new(1, -140, 0, 20)
        DL.Position = UDim2.new(0, 12, 0, 28)
        DL.BackgroundTransparency = 1
        DL.Text = T(descKey)
        DL.TextColor3 = Colors.TextMuted
        DL.Font = Enum.Font.Gotham
        DL.TextSize = 11
        DL.TextXAlignment = Enum.TextXAlignment.Left
        DL.ZIndex = 8004
        DL.Parent = Card

        local TB = Instance.new("TextButton")
        TB.Size = UDim2.new(0, 114, 0, 32)
        TB.Position = UDim2.new(1, -124, 0.5, -16)
        TB.BackgroundColor3 = Config[configKey] and Colors.WinGreen or Colors.BgSecondary
        TB.Text = Config[configKey] and T("enabled") or T("disabled")
        TB.TextColor3 = Colors.TextPrimary
        TB.Font = Enum.Font.GothamBold
        TB.TextSize = 11
        TB.ZIndex = 8004
        TB.Parent = Card
        Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 6)

        local function sync()
            local st = Config[configKey]
            TL.Text = T(titleKey) DL.Text = T(descKey)
            TB.BackgroundColor3 = st and Colors.WinGreen or Colors.BgSecondary
            TB.Text = st and T("enabled") or T("disabled")
        end
        TB.MouseButton1Click:Connect(function()
            Config[configKey] = not Config[configKey]
            sync()
            if onToggle then onToggle(Config[configKey]) end
        end)
        table.insert(State.SettingToggles, { sync = sync })
    end

    mkToggle(2, "autoReqTitle",  "autoReqDesc",  "AutoAcceptRequest", nil)
    mkToggle(3, "autoAccTitle",  "autoAccDesc",  "AutoAcceptTrade",   nil)
    mkToggle(4, "safeAccTitle",  "safeAccDesc",  "SafeAutoAccept",    nil)
    mkToggle(5, "autoScanTitle", "autoScanDesc", "AutoScanTrade",     nil)
    mkToggle(6, "gameOptTitle",  "gameOptDesc",  "GameOptimization",  Fn.applyGameOptimization)
    mkToggle(7, "scrOptTitle",   "scrOptDesc",   "ScriptOptimization",Fn.applyScriptOptimization)
    mkToggle(8, "autoExecTitle", "autoExecDesc", "AutoExecute",       Fn.setupAutoExecute)

    -- Signed bonus editor
    local SignCard = Instance.new("Frame")
    SignCard.Size = UDim2.new(1, 0, 0, 88)
    SignCard.BackgroundColor3 = Colors.BgCard
    SignCard.BorderSizePixel = 0
    SignCard.LayoutOrder = 9
    SignCard.ZIndex = 8003
    SignCard.Parent = UI.SettingsPage
    Instance.new("UICorner", SignCard).CornerRadius = UDim.new(0, 8)

    UI.SignerTitleLbl = Instance.new("TextLabel")
    UI.SignerTitleLbl.Size = UDim2.new(1, -24, 0, 20)
    UI.SignerTitleLbl.Position = UDim2.new(0, 12, 0, 5)
    UI.SignerTitleLbl.BackgroundTransparency = 1
    UI.SignerTitleLbl.Text = T("signerTitle")
    UI.SignerTitleLbl.TextColor3 = Colors.SignGold
    UI.SignerTitleLbl.Font = Enum.Font.GothamBold
    UI.SignerTitleLbl.TextSize = 13
    UI.SignerTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    UI.SignerTitleLbl.ZIndex = 8004
    UI.SignerTitleLbl.Parent = SignCard

    local SignNameBox = Instance.new("TextBox")
    SignNameBox.Size = UDim2.new(0.42, -12, 0, 28)
    SignNameBox.Position = UDim2.new(0, 12, 0, 28)
    SignNameBox.BackgroundColor3 = Colors.BgSecondary
    SignNameBox.PlaceholderText = "\u{041D}\u{0438}\u{043A} \u{043F}\u{043E}\u{0434}\u{043F}\u{0438}\u{0441}\u{0430}\u{043D}\u{0442}\u{0430} (\u{043D}\u{0430}\u{043F}\u{0440}. KAPTOXA274)"
    SignNameBox.Text = "KAPTOXA274"
    SignNameBox.TextColor3 = Colors.TextPrimary
    SignNameBox.PlaceholderColor3 = Colors.TextMuted
    SignNameBox.Font = Enum.Font.Gotham
    SignNameBox.TextSize = 11
    SignNameBox.ClearTextOnFocus = false
    SignNameBox.ZIndex = 8004
    SignNameBox.Parent = SignCard
    Instance.new("UICorner", SignNameBox).CornerRadius = UDim.new(0, 6)

    local SignPctBox = Instance.new("TextBox")
    SignPctBox.Size = UDim2.new(0.24, -6, 0, 28)
    SignPctBox.Position = UDim2.new(0.42, 4, 0, 28)
    SignPctBox.BackgroundColor3 = Colors.BgSecondary
    SignPctBox.PlaceholderText = "+% (\u{043D}\u{0430}\u{043F}\u{0440}. 110)"
    SignPctBox.Text = "110"
    SignPctBox.TextColor3 = Colors.SignGold
    SignPctBox.PlaceholderColor3 = Colors.TextMuted
    SignPctBox.Font = Enum.Font.GothamBold
    SignPctBox.TextSize = 11
    SignPctBox.ClearTextOnFocus = false
    SignPctBox.ZIndex = 8004
    SignPctBox.Parent = SignCard
    Instance.new("UICorner", SignPctBox).CornerRadius = UDim.new(0, 6)

    UI.SignerAddBtn = Instance.new("TextButton")
    UI.SignerAddBtn.Size = UDim2.new(0.34, -14, 0, 28)
    UI.SignerAddBtn.Position = UDim2.new(0.66, 4, 0, 28)
    UI.SignerAddBtn.BackgroundColor3 = Colors.Accent
    UI.SignerAddBtn.Text = T("signerAddBtn")
    UI.SignerAddBtn.TextColor3 = Colors.TextPrimary
    UI.SignerAddBtn.Font = Enum.Font.GothamBold
    UI.SignerAddBtn.TextSize = 11
    UI.SignerAddBtn.ZIndex = 8004
    UI.SignerAddBtn.Parent = SignCard
    Instance.new("UICorner", UI.SignerAddBtn).CornerRadius = UDim.new(0, 6)

    local SignInfoLbl = Instance.new("TextLabel")
    SignInfoLbl.Size = UDim2.new(1, -24, 0, 22)
    SignInfoLbl.Position = UDim2.new(0, 12, 0, 60)
    SignInfoLbl.BackgroundTransparency = 1
    SignInfoLbl.Text = "\u{0410}\u{043A}\u{0442}\u{0438}\u{0432}\u{043D}\u{044B}\u{0435}: aibat303e/iop_dev (+150%), KAPTOXA274 (+110%), BumRoblox (+65%), MiniNoobYT (+60%), Kozy (+55%), \u{0414}\u{0440}\u{0443}\u{0433}\u{0438}\u{0435} (+35%)"
    SignInfoLbl.TextColor3 = Colors.TextMuted
    SignInfoLbl.Font = Enum.Font.GothamMedium
    SignInfoLbl.TextSize = 11
    SignInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
    SignInfoLbl.ZIndex = 8004
    SignInfoLbl.Parent = SignCard

    UI.SignerAddBtn.MouseButton1Click:Connect(function()
        local rawNick = string.gsub(SignNameBox.Text or "", "^%s*(.-)%s*$", "%1")
        local pct = tonumber(SignPctBox.Text)
        if rawNick ~= "" and pct and pct >= 0 then
            Config.SignerBonuses[string.lower(rawNick)] = pct
            State.PickerSignerName = rawNick
            SignInfoLbl.Text = string.format("✅ \u{0421}\u{043E}\u{0445}\u{0440}\u{0430}\u{043D}\u{0435}\u{043D}\u{043E}: %s (+%d%% \u{043A} \u{0431}\u{0430}\u{0437}\u{043E}\u{0432}\u{043E}\u{0439} \u{0446}\u{0435}\u{043D}\u{0435})", rawNick, pct)
            SignInfoLbl.TextColor3 = Colors.WinGreen
            table.clear(State.PriceBadgeCache)
            Fn.populatePicker(UI.PickerSearch.Text)
            Fn.recalculateTrade()
        end
    end)

    -- Skybox from PC
    local SkyCard = Instance.new("Frame")
    SkyCard.Size = UDim2.new(1, 0, 0, 96)
    SkyCard.BackgroundColor3 = Colors.BgCard
    SkyCard.BorderSizePixel = 0
    SkyCard.LayoutOrder = 10
    SkyCard.ZIndex = 8003
    SkyCard.Parent = UI.SettingsPage
    Instance.new("UICorner", SkyCard).CornerRadius = UDim.new(0, 8)

    UI.SkyTitleLbl = Instance.new("TextLabel")
    UI.SkyTitleLbl.Size = UDim2.new(1, -24, 0, 20)
    UI.SkyTitleLbl.Position = UDim2.new(0, 12, 0, 5)
    UI.SkyTitleLbl.BackgroundTransparency = 1
    UI.SkyTitleLbl.Text = T("skyboxTitle")
    UI.SkyTitleLbl.TextColor3 = Colors.TextPrimary
    UI.SkyTitleLbl.Font = Enum.Font.GothamBold
    UI.SkyTitleLbl.TextSize = 13
    UI.SkyTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    UI.SkyTitleLbl.ZIndex = 8004
    UI.SkyTitleLbl.Parent = SkyCard

    UI.SkyInputBox = Instance.new("TextBox")
    UI.SkyInputBox.Size = UDim2.new(0.42, -12, 0, 30)
    UI.SkyInputBox.Position = UDim2.new(0, 12, 0, 30)
    UI.SkyInputBox.BackgroundColor3 = Colors.BgSecondary
    UI.SkyInputBox.PlaceholderText = "\u{0418}\u{043C}\u{044F} \u{0444}\u{0430}\u{0439}\u{043B}\u{0430} \u{0432} workspace (sky.png), https-\u{0441}\u{0441}\u{044B}\u{043B}\u{043A}\u{0430} \u{0438}\u{043B}\u{0438} ID..."
    UI.SkyInputBox.Text = Config.SkyboxInput
    UI.SkyInputBox.TextColor3 = Colors.TextPrimary
    UI.SkyInputBox.PlaceholderColor3 = Colors.TextMuted
    UI.SkyInputBox.Font = Enum.Font.Gotham
    UI.SkyInputBox.TextSize = 11
    UI.SkyInputBox.ClearTextOnFocus = false
    UI.SkyInputBox.ZIndex = 8004
    UI.SkyInputBox.Parent = SkyCard
    Instance.new("UICorner", UI.SkyInputBox).CornerRadius = UDim.new(0, 6)

    UI.SkyPCBtn = Instance.new("TextButton")
    UI.SkyPCBtn.Size = UDim2.new(0.22, -6, 0, 30)
    UI.SkyPCBtn.Position = UDim2.new(0.42, 4, 0, 30)
    UI.SkyPCBtn.BackgroundColor3 = Colors.Accent
    UI.SkyPCBtn.Text = T("skyboxApplyPC")
    UI.SkyPCBtn.TextColor3 = Colors.TextPrimary
    UI.SkyPCBtn.Font = Enum.Font.GothamBold
    UI.SkyPCBtn.TextSize = 11
    UI.SkyPCBtn.ZIndex = 8004
    UI.SkyPCBtn.Parent = SkyCard
    Instance.new("UICorner", UI.SkyPCBtn).CornerRadius = UDim.new(0, 6)

    UI.SkyIDBtn = Instance.new("TextButton")
    UI.SkyIDBtn.Size = UDim2.new(0.22, -6, 0, 30)
    UI.SkyIDBtn.Position = UDim2.new(0.64, 4, 0, 30)
    UI.SkyIDBtn.BackgroundColor3 = Colors.WinGreen
    UI.SkyIDBtn.Text = T("skyboxApplyID")
    UI.SkyIDBtn.TextColor3 = Colors.TextPrimary
    UI.SkyIDBtn.Font = Enum.Font.GothamBold
    UI.SkyIDBtn.TextSize = 11
    UI.SkyIDBtn.ZIndex = 8004
    UI.SkyIDBtn.Parent = SkyCard
    Instance.new("UICorner", UI.SkyIDBtn).CornerRadius = UDim.new(0, 6)

    UI.SkyResetBtn = Instance.new("TextButton")
    UI.SkyResetBtn.Size = UDim2.new(0.14, -14, 0, 30)
    UI.SkyResetBtn.Position = UDim2.new(0.86, 4, 0, 30)
    UI.SkyResetBtn.BackgroundColor3 = Colors.LoseRed
    UI.SkyResetBtn.Text = T("skyboxReset")
    UI.SkyResetBtn.TextColor3 = Colors.TextPrimary
    UI.SkyResetBtn.Font = Enum.Font.GothamBold
    UI.SkyResetBtn.TextSize = 11
    UI.SkyResetBtn.ZIndex = 8004
    UI.SkyResetBtn.Parent = SkyCard
    Instance.new("UICorner", UI.SkyResetBtn).CornerRadius = UDim.new(0, 6)

    local SkyStatusLbl = Instance.new("TextLabel")
    SkyStatusLbl.Size = UDim2.new(1, -24, 0, 22)
    SkyStatusLbl.Position = UDim2.new(0, 12, 0, 66)
    SkyStatusLbl.BackgroundTransparency = 1
    SkyStatusLbl.Text = "💡 \u{041F}\u{043E}\u{043B}\u{043E}\u{0436}\u{0438}\u{0442}\u{0435} .png/.jpg \u{0432} \u{043F}\u{0430}\u{043F}\u{043A}\u{0443} workspace \u{0438}\u{043D}\u{0436}\u{0435}\u{043A}\u{0442}\u{043E}\u{0440}\u{0430} \u{0438}\u{043B}\u{0438} \u{0432}\u{0441}\u{0442}\u{0430}\u{0432}\u{044C}\u{0442}\u{0435} \u{043F}\u{0440}\u{044F}\u{043C}\u{0443}\u{044E} https-\u{0441}\u{0441}\u{044B}\u{043B}\u{043A}\u{0443}"
    SkyStatusLbl.TextColor3 = Colors.TextMuted
    SkyStatusLbl.Font = Enum.Font.GothamMedium
    SkyStatusLbl.TextSize = 11
    SkyStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    SkyStatusLbl.ZIndex = 8004
    SkyStatusLbl.Parent = SkyCard

    UI.SkyPCBtn.MouseButton1Click:Connect(function()
        local assetUrl, msg = Fn.resolveLocalPCImage(UI.SkyInputBox.Text)
        SkyStatusLbl.Text = msg
        if assetUrl then
            SkyStatusLbl.TextColor3 = Colors.WinGreen
            Config.SkyboxInput = UI.SkyInputBox.Text
            Fn.applySkyboxAsset(assetUrl, true)
        else
            SkyStatusLbl.TextColor3 = Colors.FairYellow
        end
    end)

    local presets = { "rbxassetid://159454299", "rbxassetid://149397692", "rbxassetid://6444884337" }
    UI.SkyIDBtn.MouseButton1Click:Connect(function()
        local raw = string.gsub(UI.SkyInputBox.Text or "", "^%s*(.-)%s*$", "%1")
        local finalId
        if raw == "" then
            finalId = presets[State.PresetSkyIdx]
            State.PresetSkyIdx = (State.PresetSkyIdx % #presets) + 1
        elseif tonumber(raw) then
            finalId = "rbxassetid://" .. raw
        elseif string.match(string.lower(raw), "^https?://") then
            local assetUrl, msg = Fn.resolveLocalPCImage(raw)
            SkyStatusLbl.Text = msg
            if assetUrl then SkyStatusLbl.TextColor3 = Colors.WinGreen Fn.applySkyboxAsset(assetUrl, true) end
            return
        else
            finalId = raw
        end
        Config.SkyboxInput = finalId
        Fn.applySkyboxAsset(finalId, true)
        SkyStatusLbl.Text = "✅ Skybox \u{043F}\u{0440}\u{0438}\u{043C}\u{0435}\u{043D}\u{0451}\u{043D}: " .. finalId
        SkyStatusLbl.TextColor3 = Colors.WinGreen
    end)

    UI.SkyResetBtn.MouseButton1Click:Connect(function()
        UI.SkyInputBox.Text = ""
        Fn.resetSkybox()
        SkyStatusLbl.Text = "🔄 \u{0421}\u{0442}\u{0430}\u{043D}\u{0434}\u{0430}\u{0440}\u{0442}\u{043D}\u{043E}\u{0435} \u{043D}\u{0435}\u{0431}\u{043E} \u{0432}\u{043E}\u{0437}\u{0432}\u{0440}\u{0430}\u{0449}\u{0435}\u{043D}\u{043E}"
        SkyStatusLbl.TextColor3 = Colors.TextMuted
    end)

    -- Config Loader
    local CfgCard = Instance.new("Frame")
    CfgCard.Size = UDim2.new(1, 0, 0, 76)
    CfgCard.BackgroundColor3 = Colors.BgCard
    CfgCard.BorderSizePixel = 0
    CfgCard.LayoutOrder = 11
    CfgCard.ZIndex = 8003
    CfgCard.Parent = UI.SettingsPage
    Instance.new("UICorner", CfgCard).CornerRadius = UDim.new(0, 8)

    UI.CfgTitleLbl = Instance.new("TextLabel")
    UI.CfgTitleLbl.Size = UDim2.new(1, -24, 0, 22)
    UI.CfgTitleLbl.Position = UDim2.new(0, 12, 0, 6)
    UI.CfgTitleLbl.BackgroundTransparency = 1
    UI.CfgTitleLbl.Text = T("cfgTitle")
    UI.CfgTitleLbl.TextColor3 = Colors.TextPrimary
    UI.CfgTitleLbl.Font = Enum.Font.GothamBold
    UI.CfgTitleLbl.TextSize = 13
    UI.CfgTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    UI.CfgTitleLbl.ZIndex = 8004
    UI.CfgTitleLbl.Parent = CfgCard

    UI.CfgInputBox = Instance.new("TextBox")
    UI.CfgInputBox.Size = UDim2.new(0.54, -12, 0, 32)
    UI.CfgInputBox.Position = UDim2.new(0, 12, 0, 34)
    UI.CfgInputBox.BackgroundColor3 = Colors.BgSecondary
    UI.CfgInputBox.PlaceholderText = '{"Language":"Ru","CustomPrices":{},"SignerBonuses":{}}'
    UI.CfgInputBox.Text = ""
    UI.CfgInputBox.TextColor3 = Colors.GemCyan
    UI.CfgInputBox.PlaceholderColor3 = Colors.TextMuted
    UI.CfgInputBox.Font = Enum.Font.Gotham
    UI.CfgInputBox.TextSize = 11
    UI.CfgInputBox.ClearTextOnFocus = false
    UI.CfgInputBox.ZIndex = 8004
    UI.CfgInputBox.Parent = CfgCard
    Instance.new("UICorner", UI.CfgInputBox).CornerRadius = UDim.new(0, 6)

    UI.CfgCopyBtn = Instance.new("TextButton")
    UI.CfgCopyBtn.Size = UDim2.new(0.23, -6, 0, 32)
    UI.CfgCopyBtn.Position = UDim2.new(0.54, 4, 0, 34)
    UI.CfgCopyBtn.BackgroundColor3 = Colors.Accent
    UI.CfgCopyBtn.Text = T("cfgCopy")
    UI.CfgCopyBtn.TextColor3 = Colors.TextPrimary
    UI.CfgCopyBtn.Font = Enum.Font.GothamBold
    UI.CfgCopyBtn.TextSize = 11
    UI.CfgCopyBtn.ZIndex = 8004
    UI.CfgCopyBtn.Parent = CfgCard
    Instance.new("UICorner", UI.CfgCopyBtn).CornerRadius = UDim.new(0, 6)

    UI.CfgLoadBtn = Instance.new("TextButton")
    UI.CfgLoadBtn.Size = UDim2.new(0.23, -14, 0, 32)
    UI.CfgLoadBtn.Position = UDim2.new(0.77, 4, 0, 34)
    UI.CfgLoadBtn.BackgroundColor3 = Colors.WinGreen
    UI.CfgLoadBtn.Text = T("cfgLoad")
    UI.CfgLoadBtn.TextColor3 = Colors.TextPrimary
    UI.CfgLoadBtn.Font = Enum.Font.GothamBold
    UI.CfgLoadBtn.TextSize = 11
    UI.CfgLoadBtn.ZIndex = 8004
    UI.CfgLoadBtn.Parent = CfgCard
    Instance.new("UICorner", UI.CfgLoadBtn).CornerRadius = UDim.new(0, 6)

    -- Reload / Unload
    local ActionRow = Instance.new("Frame")
    ActionRow.Size = UDim2.new(1, 0, 0, 44)
    ActionRow.BackgroundTransparency = 1
    ActionRow.LayoutOrder = 12
    ActionRow.ZIndex = 8003
    ActionRow.Parent = UI.SettingsPage

    UI.ReloadScriptBtn = Instance.new("TextButton")
    UI.ReloadScriptBtn.Size = UDim2.new(0.49, 0, 1, 0)
    UI.ReloadScriptBtn.BackgroundColor3 = Colors.Accent
    UI.ReloadScriptBtn.Text = T("reloadBtn")
    UI.ReloadScriptBtn.TextColor3 = Colors.TextPrimary
    UI.ReloadScriptBtn.Font = Enum.Font.GothamBold
    UI.ReloadScriptBtn.TextSize = 13
    UI.ReloadScriptBtn.ZIndex = 8004
    UI.ReloadScriptBtn.Parent = ActionRow
    Instance.new("UICorner", UI.ReloadScriptBtn).CornerRadius = UDim.new(0, 8)

    UI.UnloadScriptBtn = Instance.new("TextButton")
    UI.UnloadScriptBtn.Size = UDim2.new(0.49, 0, 1, 0)
    UI.UnloadScriptBtn.Position = UDim2.new(0.51, 0, 0, 0)
    UI.UnloadScriptBtn.BackgroundColor3 = Colors.LoseRed
    UI.UnloadScriptBtn.Text = T("unloadBtn")
    UI.UnloadScriptBtn.TextColor3 = Colors.TextPrimary
    UI.UnloadScriptBtn.Font = Enum.Font.GothamBold
    UI.UnloadScriptBtn.TextSize = 13
    UI.UnloadScriptBtn.ZIndex = 8004
    UI.UnloadScriptBtn.Parent = ActionRow
    Instance.new("UICorner", UI.UnloadScriptBtn).CornerRadius = UDim.new(0, 8)
end

function Fn.applyLanguage(langCode)
    Config.Language = langCode
    UI.LangBtnEn.BackgroundColor3 = (langCode == "English") and Colors.Accent or Colors.BgSecondary
    UI.LangBtnUa.BackgroundColor3 = (langCode == "Ukraine") and Colors.Accent or Colors.BgSecondary
    UI.LangBtnRu.BackgroundColor3 = (langCode == "Ru")      and Colors.Accent or Colors.BgSecondary

    UI.HomeTabBtn.Text     = T("tabHome")
    UI.TradeTabBtn.Text    = T("tabTrade")
    UI.ValuesTabBtn.Text   = T("tabValues")
    UI.SettingsTabBtn.Text = T("tabSettings")

    UI.ConnectBtn.Text     = State.IsProfileConnected and T("connectedBtn") or T("connectBtn")
    UI.HomeNotice.Text     = T("notConnected")
    UI.DispNameTitle.Text  = T("displayName")
    UI.UserNameTitle.Text  = T("userName")
    UI.GemsStatTitle.Text  = T("gemsCount")
    UI.CoinsStatTitle.Text = T("coinsCount")
    UI.WinsStatTitle.Text  = T("winsCount")
    UI.LegStatTitle.Text   = T("legCount")
    UI.MythStatTitle.Text  = T("mythCount")
    UI.GodlyStatTitle.Text = T("godlyCount")
    UI.ExclStatTitle.Text  = T("exclCount")

    UI.MyHeaderLbl.Text      = T("myOffer")
    UI.PartnerHeaderLbl.Text = T("partnerOffer")
    UI.PickerTitle.Text      = T("addManual")
    UI.MyClearBtn.Text       = T("clearBtn")
    UI.PartnerClearBtn.Text  = T("clearBtn")

    UI.LangTitleLbl.Text     = T("langTitle")
    UI.LangDescLbl.Text      = T("langDesc")
    UI.SignerTitleLbl.Text   = T("signerTitle")
    UI.SignerAddBtn.Text     = T("signerAddBtn")
    UI.SkyTitleLbl.Text      = T("skyboxTitle")
    UI.SkyPCBtn.Text         = T("skyboxApplyPC")
    UI.SkyIDBtn.Text         = T("skyboxApplyID")
    UI.SkyResetBtn.Text      = T("skyboxReset")
    UI.CfgTitleLbl.Text      = T("cfgTitle")
    UI.CfgCopyBtn.Text       = T("cfgCopy")
    UI.CfgLoadBtn.Text       = T("cfgLoad")
    UI.ReloadScriptBtn.Text  = T("reloadBtn")
    UI.UnloadScriptBtn.Text  = T("unloadBtn")

    for _, entry in ipairs(State.SettingToggles) do entry.sync() end
    Fn.recalculateTrade()
end

UI.LangBtnEn.MouseButton1Click:Connect(function() Fn.applyLanguage("English") end)
UI.LangBtnUa.MouseButton1Click:Connect(function() Fn.applyLanguage("Ukraine") end)
UI.LangBtnRu.MouseButton1Click:Connect(function() Fn.applyLanguage("Ru") end)

UI.CfgCopyBtn.MouseButton1Click:Connect(function()
    local ok, encoded = pcall(function() return S.HttpService:JSONEncode(Config) end)
    if ok and encoded then
        UI.CfgInputBox.Text = encoded
        Fn.copyToClipboard(encoded, UI.CfgCopyBtn, T("cfgCopy"))
    end
end)

UI.CfgLoadBtn.MouseButton1Click:Connect(function()
    local raw = UI.CfgInputBox.Text
    if not raw or raw == "" then return end
    local ok, decoded = pcall(function() return S.HttpService:JSONDecode(raw) end)
    if ok and type(decoded) == "table" then
        for k, v in pairs(decoded) do
            if Config[k] ~= nil then Config[k] = v end
        end
        if type(decoded.CustomPrices) == "table" then
            for uName, val in pairs(decoded.CustomPrices) do
                if UnitDatabase[uName] and tonumber(val) then
                    UnitDatabase[uName].value = tonumber(val)
                    Config.CustomPrices[uName] = tonumber(val)
                end
            end
        end
        if type(decoded.SignerBonuses) == "table" then
            for sName, pct in pairs(decoded.SignerBonuses) do
                if tonumber(pct) then Config.SignerBonuses[string.lower(sName)] = tonumber(pct) end
            end
        end
        Fn.rebuildSortedItems()
        table.clear(State.PriceBadgeCache)
        Fn.populateCatalog(UI.CatalogSearch.Text)
        Fn.populatePicker(UI.PickerSearch.Text)
        Fn.applyLanguage(Config.Language)
        Fn.applyGameOptimization(Config.GameOptimization)
        Fn.applyScriptOptimization(Config.ScriptOptimization)
        Fn.setupAutoExecute(Config.AutoExecute)
        if Config.SkyboxInput and Config.SkyboxInput ~= "" then
            UI.SkyInputBox.Text = Config.SkyboxInput
            Fn.applySkyboxAsset(Config.SkyboxInput, true)
        end
        UI.CfgLoadBtn.Text = "✅ OK!"
        task.delay(1.8, function()
            if UI.CfgLoadBtn and UI.CfgLoadBtn.Parent then UI.CfgLoadBtn.Text = T("cfgLoad") end
        end)
    end
end)

UI.UnloadScriptBtn.MouseButton1Click:Connect(function()
    State.IsRunning = false
    for _, conn in ipairs(State.ActiveConnections) do pcall(function() conn:Disconnect() end) end
    table.clear(State.ActiveConnections)
    Fn.applyGameOptimization(false)
    Fn.resetSkybox()
    for _, screen in ipairs(PlayerGui:GetChildren()) do
        if screen:IsA("ScreenGui") then
            for _, desc in ipairs(screen:GetDescendants()) do
                if desc.Name == "KvaplPriceTag" or desc.Name == "KvaplMetaTag" then
                    pcall(function() desc:Destroy() end)
                end
            end
        end
    end
    if UI.ScreenGui and UI.ScreenGui.Parent then UI.ScreenGui:Destroy() end
end)

UI.ReloadScriptBtn.MouseButton1Click:Connect(function()
    UI.MainFrame.Visible = false
    UI.LiveHud.Visible = false
    UI.MobileFloatBtn.Visible = false
    table.clear(State.PriceBadgeCache)
    Fn.playLoadingScreen(7, function()
        if not State.IsRunning then return end
        Fn.showDeviceSelector(function()
            if UI.ScreenGui and UI.ScreenGui.Parent then
                UI.MainFrame.Visible = true
                UI.LiveHud.Visible = true
                if State.IsProfileConnected then Fn.refreshProfileStats() end
            end
        end)
    end)
end)

do
    local pages = { UI.HomePage, UI.TradePage, UI.ValuesPage, UI.SettingsPage }
    local btns  = { UI.HomeTabBtn, UI.TradeTabBtn, UI.ValuesTabBtn, UI.SettingsTabBtn }
    local function switchTab(tp, tb)
        for _, p in ipairs(pages) do p.Visible = (p == tp) end
        for _, b in ipairs(btns) do
            b.BackgroundColor3 = (b == tb) and Colors.Accent or Colors.BgCard
            b.TextColor3 = (b == tb) and Colors.TextPrimary or Colors.TextMuted
        end
    end
    UI.HomeTabBtn.MouseButton1Click:Connect(function() switchTab(UI.HomePage, UI.HomeTabBtn) end)
    UI.TradeTabBtn.MouseButton1Click:Connect(function() switchTab(UI.TradePage, UI.TradeTabBtn) end)
    UI.ValuesTabBtn.MouseButton1Click:Connect(function() switchTab(UI.ValuesPage, UI.ValuesTabBtn) end)
    UI.SettingsTabBtn.MouseButton1Click:Connect(function() switchTab(UI.SettingsPage, UI.SettingsTabBtn) end)
end

-- ============================================================================
-- 3. SLOT AUTO-ANALYZER, TOOLTIPS AND RELIABLE REQUEST AUTO-ACCEPT
-- ============================================================================
function Fn.isGuiVisible(guiObj)
    local curr = guiObj
    while curr and curr ~= PlayerGui and curr ~= GuiParent do
        if curr:IsA("GuiObject") and not curr.Visible then return false end
        if curr:IsA("ScreenGui") and not curr.Enabled then return false end
        curr = curr.Parent
    end
    return true
end

function Fn.isTooltipFrame(frameObj)
    if not frameObj or not frameObj:IsA("GuiObject") then return false end
    for _, child in ipairs(frameObj:GetChildren()) do
        if child:IsA("TextLabel") then
            local t = string.lower(child.Text or "")
            if string.find(t, "damage:", 1, true) or string.find(t, "cooldown:", 1, true)
                or string.find(t, "dps:", 1, true) or string.find(t, "exists", 1, true) then
                return true
            end
        end
    end
    return false
end

function Fn.extractQuantity(slotInstance)
    local maxQty = 1
    for _, desc in ipairs(slotInstance:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Name ~= "KvaplPriceTag" and desc.Name ~= "KvaplMetaTag" then
            local txt = string.lower(desc.Text or "")
            local num1 = string.match(txt, "^%s*x%s*(%d+)%s*$")
                or string.match(txt, "^%s*(%d+)%s*x%s*$")
                or string.match(txt, "^%s*×%s*(%d+)%s*$")
            if num1 then
                local n = tonumber(num1)
                if n and n >= 1 and n <= 999 then maxQty = math.max(maxQty, n) end
            end
        end
    end
    return maxQty
end

function Fn.findHoveredInventorySlot()
    local invScroll = Fn.findInventoryScrollingFrame()
    if not invScroll or not Fn.isGuiVisible(invScroll) then return nil end
    local mousePos = S.UserInputService:GetMouseLocation()
    local mx, my = mousePos.X, mousePos.Y - 36
    for _, slot in ipairs(invScroll:GetChildren()) do
        if slot:IsA("GuiObject") and slot.Visible and slot.AbsoluteSize.X > 30 then
            local p, sz = slot.AbsolutePosition, slot.AbsoluteSize
            if (mx >= p.X and mx <= p.X + sz.X and my >= p.Y and my <= p.Y + sz.Y)
                or (mousePos.X >= p.X and mousePos.X <= p.X + sz.X and mousePos.Y >= p.Y and mousePos.Y <= p.Y + sz.Y) then
                return slot
            end
        end
    end
    return nil
end

local function getStabilityColor(trendText)
    local low = string.lower(trendText or "")
    if string.find(low, "overpaid", 1, true) or string.find(low, "rising", 1, true) then
        return Color3.fromRGB(74, 222, 128)
    elseif string.find(low, "dropping", 1, true) or string.find(low, "unwanted", 1, true) then
        return Color3.fromRGB(248, 113, 113)
    end
    return Color3.fromRGB(250, 204, 21)
end

function Fn.attachPriceTag(slotFrame, unitName, unitData, qty, isSigned, signerName)
    if not slotFrame or not slotFrame:IsA("GuiObject") then return end
    local count = qty or 1
    local normalTotal = unitData.value * count
    local signedUnitPrice, bonusPct = Fn.computeSignedPrice(unitData.value, signerName)
    local signedTotal = signedUnitPrice * count
    local isTooltip = Fn.isTooltipFrame(slotFrame)

    if isTooltip then
        local hoveredSlot = Fn.findHoveredInventorySlot()
        if hoveredSlot then
            State.HoverSlotMap[hoveredSlot] = unitName
            if isSigned then
                State.HoverSignMap[hoveredSlot] = signerName or "Partner"
            else
                State.HoverSignMap[hoveredSlot] = nil
            end
            Fn.attachPriceTag(hoveredSlot, unitName, unitData, Fn.extractQuantity(hoveredSlot), isSigned, signerName)
        end
    end

    local labelText
    if isTooltip then
        if unitData.value > 0 then
            if isSigned then
                local who = (signerName and signerName ~= "Partner") and (signerName .. " +" .. bonusPct .. "%") or ("+" .. bonusPct .. "%")
                labelText = string.format("%s%s (%s | %s) 💎", T("valuePrefix"), Fn.formatNumber(normalTotal), Fn.formatNumber(signedTotal), who)
            else
                labelText = string.format("%s%s 💎", T("valuePrefix"), Fn.formatNumber(normalTotal))
            end
        else
            labelText = isSigned
                and string.format("%sN/A (%s) 💎", T("valuePrefix"), Fn.formatNumber(signedTotal))
                or (T("valuePrefix") .. "N/A")
        end
    else
        if unitData.value > 0 then
            if isSigned then
                labelText = string.format("%s (%s) 💎", Fn.formatNumber(normalTotal), Fn.formatNumber(signedTotal))
            else
                labelText = Fn.formatGems(normalTotal)
            end
        else
            labelText = isSigned and string.format("0 (%s) 💎", Fn.formatNumber(signedTotal)) or "N/A"
        end
    end

    local existing = slotFrame:FindFirstChild("KvaplPriceTag")
    if existing and existing:IsA("TextLabel") then
        existing.Text = labelText
        existing.TextColor3 = isSigned and Colors.SignGold or Color3.fromRGB(0, 215, 255)
        existing.Visible = true
    else
        local Badge = Instance.new("TextLabel")
        Badge.Name = "KvaplPriceTag"
        if isTooltip then
            Badge.Size = UDim2.new(1, -8, 0, 24)
            Badge.BackgroundTransparency = 1
            Badge.Text = labelText
            Badge.TextColor3 = isSigned and Colors.SignGold or Color3.fromRGB(0, 215, 255)
            Badge.Font = Enum.Font.FredokaOne
            Badge.TextSize = isSigned and 15 or 18
            Badge.LayoutOrder = 1
            Badge.ZIndex = math.max(slotFrame.ZIndex + 10, 500)
            local Stroke = Instance.new("UIStroke", Badge)
            Stroke.Color = Color3.fromRGB(0, 0, 0) Stroke.Thickness = 1.8
        else
            Badge.Size = UDim2.new(1, -6, 0, 18)
            Badge.Position = UDim2.new(0, 3, 0, 2)
            Badge.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
            Badge.BackgroundTransparency = 0.2
            Badge.Text = labelText
            Badge.TextColor3 = isSigned and Colors.SignGold or Color3.fromRGB(56, 220, 255)
            Badge.Font = Enum.Font.FredokaOne
            Badge.TextSize = isSigned and 11 or 12
            Badge.TextScaled = isSigned
            Badge.ZIndex = math.max(slotFrame.ZIndex + 15, 500)
            Instance.new("UICorner", Badge).CornerRadius = UDim.new(0, 6)
            local Stroke = Instance.new("UIStroke", Badge)
            Stroke.Color = Color3.fromRGB(0, 0, 0) Stroke.Thickness = 1.4
        end
        Badge.Parent = slotFrame
    end

    if isTooltip then
        local metaText = string.format(T("metaFmt"), unitData.demand or "N/A", unitData.trend or "N/A")
        local metaColor = getStabilityColor(unitData.trend)
        local existingMeta = slotFrame:FindFirstChild("KvaplMetaTag")
        if existingMeta and existingMeta:IsA("TextLabel") then
            existingMeta.Text = metaText
            existingMeta.TextColor3 = metaColor
            existingMeta.Visible = true
        else
            local MetaLbl = Instance.new("TextLabel")
            MetaLbl.Name = "KvaplMetaTag"
            MetaLbl.Size = UDim2.new(1, -8, 0, 20)
            MetaLbl.BackgroundTransparency = 1
            MetaLbl.Text = metaText
            MetaLbl.TextColor3 = metaColor
            MetaLbl.Font = Enum.Font.FredokaOne
            MetaLbl.TextSize = 14
            MetaLbl.LayoutOrder = 2
            MetaLbl.ZIndex = math.max(slotFrame.ZIndex + 10, 500)
            local Stroke = Instance.new("UIStroke", MetaLbl)
            Stroke.Color = Color3.fromRGB(0, 0, 0) Stroke.Thickness = 1.5
            MetaLbl.Parent = slotFrame
        end
    end
end

function Fn.identifySlotUnit(guiObj)
    if guiObj:IsA("TextLabel") or guiObj:IsA("TextButton") then
        if guiObj.Name ~= "KvaplPriceTag" and guiObj.Name ~= "KvaplMetaTag" then
            local uName, uData = Fn.findUnitData(guiObj.Text)
            if uName and uData then
                local slotBox = (guiObj.Parent and guiObj.Parent:IsA("GuiObject")) and guiObj.Parent or guiObj
                if Fn.isTooltipFrame(slotBox) and not State.HookedTooltips[guiObj] then
                    State.HookedTooltips[guiObj] = true
                    Fn.trackConn(guiObj:GetPropertyChangedSignal("Text"):Connect(function()
                        local newName, newData = Fn.findUnitData(guiObj.Text)
                        if newName and newData then
                            task.defer(function()
                                local isSig, sigWho = Fn.detectSlotSigner(slotBox)
                                Fn.attachPriceTag(slotBox, newName, newData, 1, isSig, sigWho)
                            end)
                        else
                            if slotBox:FindFirstChild("KvaplPriceTag") then slotBox.KvaplPriceTag.Visible = false end
                            if slotBox:FindFirstChild("KvaplMetaTag") then slotBox.KvaplMetaTag.Visible = false end
                        end
                    end))
                end
                return uName, uData, slotBox
            end
        end
    end
    if guiObj:IsA("Model") then
        local uName, uData = Fn.findUnitData(guiObj.Name)
        if uName and uData then
            local vp = guiObj:FindFirstAncestorWhichIsA("ViewportFrame")
            if vp and vp.Parent and vp.Parent:IsA("GuiObject") then return uName, uData, vp.Parent end
        end
    end
    if guiObj:IsA("GuiObject") and not guiObj:IsA("ViewportFrame") and guiObj.Name ~= "KvaplPriceTag" and guiObj.Name ~= "KvaplMetaTag" then
        local uName, uData = Fn.findUnitData(guiObj.Name)
        if uName and uData then return uName, uData, guiObj end
        for _, attrName in ipairs({ "UnitName", "ItemName", "Unit", "Item", "Name", "Troop" }) do
            local attrVal = guiObj:GetAttribute(attrName)
            if type(attrVal) == "string" then
                local aName, aData = Fn.findUnitData(attrVal)
                if aName and aData then return aName, aData, guiObj end
            end
        end
    end
    if guiObj:IsA("StringValue") then
        local uName, uData = Fn.findUnitData(guiObj.Value)
        if uName and uData and guiObj.Parent and guiObj.Parent:IsA("GuiObject") then return uName, uData, guiObj.Parent end
    end
    return nil, nil, nil
end

function Fn.classifySlotAncestry(slotFrame, tradeRoot)
    local curr = slotFrame
    while curr and curr ~= tradeRoot and curr ~= PlayerGui do
        local n = string.lower(curr.Name)
        if string.find(n, "inventory") or string.find(n, "storage") or string.find(n, "backpack")
            or string.find(n, "select") or string.find(n, "unitlist") or string.find(n, "owned") then
            return "inventory"
        end
        if string.find(n, "myoffer") or string.find(n, "youroffer") or string.find(n, "selfoffer")
            or string.find(n, "player1") or string.find(n, "offer1") or string.find(n, "leftoffer")
            or n == "left" or n == "my" or n == "yours" or n == "localplayer" then
            return "my"
        end
        if string.find(n, "theiroffer") or string.find(n, "otheroffer") or string.find(n, "partner")
            or string.find(n, "player2") or string.find(n, "offer2") or string.find(n, "rightoffer")
            or string.find(n, "target") or n == "right" or n == "their" or n == "theirs" or n == "other" then
            return "partner"
        end
        curr = curr.Parent
    end
    return nil
end

function Fn.findActiveTradeRoot()
    for _, screen in ipairs(PlayerGui:GetChildren()) do
        if screen ~= UI.ScreenGui and screen:IsA("ScreenGui") and screen.Enabled then
            if screen.DisplayOrder >= UI.ScreenGui.DisplayOrder then
                UI.ScreenGui.DisplayOrder = 2147483647
            end
            local sName = string.lower(screen.Name)
            if string.find(sName, "trade") or string.find(sName, "trading") or string.find(sName, "exchange") then
                for _, child in ipairs(screen:GetChildren()) do
                    if child:IsA("GuiObject") and child.Visible and child.AbsoluteSize.X > 200 and child.AbsoluteSize.Y > 150 then
                        return child
                    end
                end
            end
            for _, desc in ipairs(screen:GetDescendants()) do
                if desc:IsA("GuiObject") and desc.Visible and desc.AbsoluteSize.X > 220 and desc.AbsoluteSize.Y > 150 then
                    local dName = string.lower(desc.Name)
                    if dName == "trade" or dName == "tradeframe" or dName == "trading"
                        or dName == "tradingframe" or dName == "tradegui" or dName == "trademain" then
                        if Fn.isGuiVisible(desc) then return desc end
                    end
                end
            end
        end
    end
    return nil
end

function Fn.extractTradeGems(tradeRoot, centerX)
    local myGems, partnerGems = 0, 0
    for _, desc in ipairs(tradeRoot:GetDescendants()) do
        if (desc:IsA("TextBox") or desc:IsA("TextLabel")) and desc.Name ~= "KvaplPriceTag" and desc.Name ~= "KvaplMetaTag" and Fn.isGuiVisible(desc) then
            local fullPath = string.lower(desc:GetFullName())
            if string.find(fullPath, "gem") or string.find(fullPath, "diamond") or string.find(fullPath, "currency") then
                local rawDigits = string.gsub(desc.Text or "", "[^%d]", "")
                local val = tonumber(rawDigits)
                if val and val > 0 and val < 100000000 then
                    local side = Fn.classifySlotAncestry(desc, tradeRoot)
                    if not side then
                        local posX = desc.AbsolutePosition.X + (desc.AbsoluteSize.X * 0.5)
                        side = (posX < centerX) and "my" or "partner"
                    end
                    if side == "my" then myGems = math.max(myGems, val)
                    elseif side == "partner" then partnerGems = math.max(partnerGems, val) end
                end
            end
        end
    end
    return myGems, partnerGems
end

-- TRIPLE UNIVERSAL CLICKER (firesignal + getconnections + VirtualInputManager)
function Fn.clickGuiButtonUniversal(btn)
    if not btn or not btn:IsA("GuiButton") or not btn.Parent then return end
    local now = os.clock()
    if State.LastClickTimes[btn] and (now - State.LastClickTimes[btn]) < 0.75 then
        return
    end
    State.LastClickTimes[btn] = now

    -- 1. firesignal
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.Activated) end)
        pcall(function() firesignal(btn.MouseButton1Up) end)
    end

    -- 2. getconnections
    if typeof(getconnections) == "function" then
        for _, sig in ipairs({ btn.MouseButton1Click, btn.Activated }) do
            pcall(function()
                for _, conn in ipairs(getconnections(sig)) do
                    if conn.Fire then conn:Fire()
                    elseif conn.Function then task.spawn(conn.Function) end
                end
            end)
        end
    end

    -- 3. VirtualInputManager (real click at button coordinates - works even on mobile executors)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local inset = S.GuiService:GetGuiInset()
        local cx = btn.AbsolutePosition.X + (btn.AbsoluteSize.X * 0.5)
        local cy = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y * 0.5) + inset.Y
        vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.03)
        vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end)
end

local AcceptKeywords  = { "accept", "ready", "confirm", "yes", "agree", "ok", "✓", "✔", "\u{043F}\u{0440}\u{0438}\u{043D}\u{044F}\u{0442}\u{044C}", "\u{0433}\u{043E}\u{0442}\u{043E}\u{0432}", "\u{043F}\u{043E}\u{0434}\u{0442}\u{0432}\u{0435}\u{0440}\u{0434}\u{0438}\u{0442}\u{044C}", "\u{0442}\u{0430}\u{043A}", "\u{0434}\u{0430}" }
local DeclineKeywords = { "decline", "cancel", "reject", "close", "no", "deny", "✕", "✖", "\u{043E}\u{0442}\u{043A}\u{043B}\u{043E}\u{043D}\u{0438}\u{0442}\u{044C}", "\u{043E}\u{0442}\u{043C}\u{0435}\u{043D}\u{0430}", "\u{0437}\u{0430}\u{043A}\u{0440}\u{044B}\u{0442}\u{044C}", "\u{043D}\u{0456}", "\u{043D}\u{0435}\u{0442}" }
local RequestPhrases  = {
    "wants to trade", "sent you a trade", "trade request", "trade invite",
    "invited you to trade", "trading with", "\u{0445}\u{043E}\u{0447}\u{0435}\u{0442} \u{043E}\u{0431}\u{043C}\u{0435}\u{043D}\u{044F}\u{0442}\u{044C}\u{0441}\u{044F}", "\u{0437}\u{0430}\u{043F}\u{0440}\u{043E}\u{0441} \u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}",
    "\u{043F}\u{0440}\u{0438}\u{0433}\u{043B}\u{0430}\u{0441}\u{0438}\u{043B} \u{0432}\u{0430}\u{0441}", "\u{0437}\u{0430}\u{043F}\u{0438}\u{0442} \u{043D}\u{0430} \u{0442}\u{0440}\u{0435}\u{0439}\u{0434}", "trade!"
}

-- Checks whether the button popup container belongs to an incoming trade request
local function isInsideTradeRequestPopup(btn)
    local curr = btn.Parent
    for _ = 1, 4 do
        if not curr or curr == PlayerGui then break end
        local cn = string.lower(curr.Name or "")
        if string.find(cn, "traderequest", 1, true) or string.find(cn, "tradeinvite", 1, true)
            or string.find(cn, "request", 1, true) or string.find(cn, "invite", 1, true)
            or string.find(cn, "notification", 1, true) or string.find(cn, "popup", 1, true) then
            -- Check whether nearby text mentions a trade
            for _, sibling in ipairs(curr:GetDescendants()) do
                if sibling:IsA("TextLabel") and sibling.Visible then
                    local st = string.lower(sibling.Text or "")
                    if string.find(st, "trade", 1, true) or string.find(st, "\u{0442}\u{0440}\u{0435}\u{0439}\u{0434}", 1, true) or string.find(st, "\u{043E}\u{0431}\u{043C}\u{0435}\u{043D}", 1, true) then
                        return true
                    end
                end
            end
        end
        -- Direct search for trade-request phrases in neighboring TextLabels
        for _, sibling in ipairs(curr:GetDescendants()) do
            if sibling:IsA("TextLabel") and sibling.Visible then
                local st = string.lower(sibling.Text or "")
                for _, phrase in ipairs(RequestPhrases) do
                    if string.find(st, phrase, 1, true) then
                        return true
                    end
                end
            end
        end
        curr = curr.Parent
    end
    return false
end

function Fn.isAcceptButton(btn, allowGreenIcon)
    if not btn:IsA("GuiButton") or not Fn.isGuiVisible(btn) then return false end
    if btn.AbsoluteSize.X < 16 or btn.AbsoluteSize.Y < 16 then return false end

    local bName = string.lower(btn.Name or "")
    local bText = ""
    if btn:IsA("TextButton") then
        bText = string.lower(btn.Text or "")
    else
        local lbl = btn:FindFirstChildWhichIsA("TextLabel", true)
        if lbl then bText = string.lower(lbl.Text or "") end
    end

    for _, bad in ipairs(DeclineKeywords) do
        if bName == bad or bText == bad or string.find(bName, bad, 1, true) or string.find(bText, bad, 1, true) then
            return false
        end
    end

    for _, word in ipairs(AcceptKeywords) do
        if bName == word or bText == word or string.find(bName, word, 1, true) or string.find(bText, word, 1, true) then
            return true
        end
    end

    -- If it is a green confirm button without text (e.g. an ImageButton with a checkmark in a popup)
    if allowGreenIcon then
        local col = btn.BackgroundColor3
        if btn:IsA("ImageButton") and btn.BackgroundTransparency > 0.8 then
            col = btn.ImageColor3
        end
        local r, g, b = col.R * 255, col.G * 255, col.B * 255
        if g >= 145 and r <= 120 and b <= 120 then
            return true
        end
    end
    return false
end

function Fn.processAutoAccepts(tradeRoot)
    for _, screen in ipairs(PlayerGui:GetChildren()) do
        if screen ~= UI.ScreenGui and screen:IsA("ScreenGui") and screen.Enabled then
            for _, desc in ipairs(screen:GetDescendants()) do
                if desc:IsA("GuiButton") and Fn.isGuiVisible(desc) then
                    local insideTrade = tradeRoot and desc:IsDescendantOf(tradeRoot)

                    -- 1. Auto-accept of an incoming trade REQUEST (fixed!)
                    if Config.AutoAcceptRequest and not insideTrade then
                        if isInsideTradeRequestPopup(desc) and Fn.isAcceptButton(desc, true) then
                            Fn.clickGuiButtonUniversal(desc)
                        end
                    end

                    -- 2. Auto-accept INSIDE the open trade
                    if Config.AutoAcceptTrade and insideTrade then
                        if Fn.isAcceptButton(desc, false) and (not Config.SafeAutoAccept or State.LastTradeDiff >= 0) then
                            Fn.clickGuiButtonUniversal(desc)
                        end
                    end
                end
            end
        end
    end
end

function Fn.performAutoScan()
    local bestSlotMatches = {}
    for _, screen in ipairs(PlayerGui:GetChildren()) do
        if screen ~= UI.ScreenGui and screen:IsA("ScreenGui") and screen.Enabled then
            for _, desc in ipairs(screen:GetDescendants()) do
                local uName, uData, slotBox = Fn.identifySlotUnit(desc)
                if uName and uData and slotBox and Fn.isGuiVisible(slotBox) then
                    local prev = bestSlotMatches[slotBox]
                    if not prev or #uName > #prev.uName then
                        bestSlotMatches[slotBox] = { uName = uName, uData = uData }
                    end
                end
            end
        end
    end

    for cachedSlot, cachedUnit in pairs(State.HoverSlotMap) do
        if cachedSlot and cachedSlot.Parent and Fn.isGuiVisible(cachedSlot) and UnitDatabase[cachedUnit] then
            if not bestSlotMatches[cachedSlot] then
                bestSlotMatches[cachedSlot] = { uName = cachedUnit, uData = UnitDatabase[cachedUnit] }
            end
        end
    end

    for slotBox, match in pairs(bestSlotMatches) do
        local qty = Fn.isTooltipFrame(slotBox) and 1 or Fn.extractQuantity(slotBox)
        local isSigned, signerName = Fn.detectSlotSigner(slotBox)
        Fn.attachPriceTag(slotBox, match.uName, match.uData, qty, isSigned, signerName)
    end

    local tradeRoot = Fn.findActiveTradeRoot()
    if Config.AutoScanTrade and tradeRoot then
        local centerX = tradeRoot.AbsolutePosition.X + (tradeRoot.AbsoluteSize.X * 0.5)
        local detectedMy, detectedPartner = {}, {}

        for slotBox, match in pairs(bestSlotMatches) do
            if slotBox:IsDescendantOf(tradeRoot) and not Fn.isTooltipFrame(slotBox) then
                local side = Fn.classifySlotAncestry(slotBox, tradeRoot)
                if side ~= "inventory" then
                    if not side then
                        local slotCenterX = slotBox.AbsolutePosition.X + (slotBox.AbsoluteSize.X * 0.5)
                        side = (slotCenterX < centerX) and "my" or "partner"
                    end
                    local qty = Fn.extractQuantity(slotBox)
                    local isSigned, signerName = Fn.detectSlotSigner(slotBox)
                    local unitVal = isSigned
                        and select(1, Fn.computeSignedPrice(match.uData.value, signerName))
                        or match.uData.value
                    local targetList = (side == "my") and detectedMy or detectedPartner

                    local merged = false
                    for _, item in ipairs(targetList) do
                        if item.name == match.uName and item.isSigned == isSigned and item.signer == signerName then
                            item.count = item.count + qty
                            merged = true
                            break
                        end
                    end
                    if not merged then
                        table.insert(targetList, {
                            name = match.uName, value = unitVal, count = qty,
                            isSigned = isSigned, signer = signerName
                        })
                    end
                end
            end
        end

        local autoMyGems, autoPartnerGems = Fn.extractTradeGems(tradeRoot, centerX)
        if #detectedMy > 0 or #detectedPartner > 0 or autoMyGems > 0 or autoPartnerGems > 0 then
            State.MyOffer = detectedMy
            State.PartnerOffer = detectedPartner
            if autoMyGems > 0 then State.MyExtraGems = autoMyGems end
            if autoPartnerGems > 0 then State.PartnerExtraGems = autoPartnerGems end
            Fn.renderOfferList(State.MyOffer, UI.MyScroll)
            Fn.renderOfferList(State.PartnerOffer, UI.PartnerScroll)
            Fn.recalculateTrade()
        end
    end

    if Config.AutoAcceptRequest or Config.AutoAcceptTrade then
        Fn.processAutoAccepts(tradeRoot)
    end
    if State.IsProfileConnected then
        Fn.refreshProfileStats()
    end
end

-- Launch: 1) Loading screen (7 sec) -> 2) Device choice (Phone / PC) -> 3) Main loop
Fn.playLoadingScreen(7, function()
    if not State.IsRunning then return end
    Fn.showDeviceSelector(function()
        if not State.IsRunning then return end
        UI.LiveHud.Visible = true
        UI.MainFrame.Visible = true

        task.spawn(function()
            while State.IsRunning and UI.ScreenGui and UI.ScreenGui.Parent do
                pcall(Fn.performAutoScan)
                task.wait(Config.ScanInterval)
            end
        end)
    end)
end)

print("[KvaplScript v6.3] \u{0417}\u{0430}\u{043F}\u{0443}\u{0449}\u{0435}\u{043D} (PC & Mobile UI)! Discord: " .. DISCORD_LINK)
